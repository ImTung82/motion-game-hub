import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:hand_landmarker/hand_landmarker.dart' as hl;
import '../motion_state.dart';
import 'motion_backend.dart';

MotionBackend createMotionBackend({
  required FaceResultCallback onFace,
  required HandResultCallback onHands,
  required int Function(MotionInputMode mode) aiRotationIndex,
}) =>
    NativeMotionBackend(onFace: onFace, onHands: onHands, aiRotationIndex: aiRotationIndex);

/// Android: camera trước + Google ML Kit (mặt) + MediaPipe Hand Landmarker (tay)
class NativeMotionBackend extends MotionBackend {
  NativeMotionBackend({required super.onFace, required super.onHands, required super.aiRotationIndex});

  CameraController? _cameraController;
  FaceDetector? _faceDetector;
  List<CameraDescription> _cameras = [];
  bool _isProcessing = false;

  // FPS & Latency (Face mode)
  double _fps = 0.0;
  int _frameCount = 0;
  DateTime _lastFrameTime = DateTime.now();

  DateTime _lastFaceFeed = DateTime.fromMillisecondsSinceEpoch(0);
  static const int _faceMinIntervalMs = 30; // ~33 FPS cho Face mode

  // ==========================================
  // HAND MODE: MediaPipe Hand Landmarker (21 điểm / bàn tay)
  // ==========================================
  hl.HandLandmarkerPlugin? _handPlugin;
  StreamSubscription<List<hl.Hand>>? _handSub;
  DateTime _lastHandFeed = DateTime.fromMillisecondsSinceEpoch(0);
  // Chống dồn hàng (backpressure): plugin đổi YUV->RGB từng pixel NGAY TRÊN luồng UI rồi mới đưa
  // MediaPipe. Gửi 30 FPS trong khi MediaPipe (CPU) chỉ xử lý ~10-20 FPS => khung bị bỏ vẫn tốn
  // chi phí đổi màu, luồng UI quá tải, máy nóng -> hạ xung -> frame camera & kết quả xếp hàng, trễ
  // tăng dần theo thời gian. Nên chỉ gửi khung mới khi khung trước đã có kết quả.
  bool _handFrameInFlight = false;
  // Chuẩn vàng ~30-33 FPS: Mượt mà hoàn hảo cho phản xạ cử chỉ, máy mạnh mát lạnh,
  // máy yếu không bị nóng máy hay tụt pin khi trẻ chơi lâu.
  static const int _handMinIntervalMs = 30; // ~33 FPS cap (ngưỡng tối ưu tốt nhất)
  static const int _handResultTimeoutMs = 200; // MediaPipe bỏ khung thì không trả kết quả -> hết hạn chờ
  double _handUprightW = 1.0;
  double _handUprightH = 1.0;

  @override
  bool get isReady => _cameraController != null && _cameraController!.value.isInitialized;

  @override
  bool get mirrored => _cameraController?.description.lensDirection == CameraLensDirection.front;

  @override
  Size? get previewSize => _cameraController?.value.previewSize;

  @override
  bool get supportsRotation => true;

  @override
  Widget buildPreview() => CameraPreview(_cameraController!);

  @override
  Future<void> start({VoidCallback? onCameraReady}) async {
    // 1. Face Detector: Tối ưu Fast Mode cho 60 FPS
    _faceDetector ??= FaceDetector(
      options: FaceDetectorOptions(
        enableContours: true,
        enableLandmarks: true,
        enableClassification: false,
        performanceMode: FaceDetectorMode.fast,
        minFaceSize: 0.05,
      ),
    );

    _cameras = await availableCameras();
    final frontCamera = _cameras.firstWhere(
      (cam) => cam.lensDirection == CameraLensDirection.front,
      orElse: () => _cameras.isNotEmpty ? _cameras.first : throw Exception('No camera found'),
    );

    // ResolutionPreset.low (240p - 360p) cung cấp FPS tối đa (30-60 FPS) và độ trễ cực thấp
    _cameraController = CameraController(
      frontCamera,
      ResolutionPreset.low,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.yuv420 : ImageFormatGroup.bgra8888,
    );

    await _cameraController!.initialize();
    onCameraReady?.call();

    await _cameraController!.startImageStream(_processCameraFrame);
  }

  @override
  Future<void> stop() async {
    try {
      if (_cameraController != null) {
        await _cameraController!.stopImageStream().catchError((_) {});
        await _cameraController!.dispose().catchError((_) {});
      }
    } catch (_) {}
    _cameraController = null;
  }

  @override
  void dispose() {
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _faceDetector?.close();
    _handSub?.cancel();
    _handPlugin?.dispose();
  }

  Future<void> _processCameraFrame(CameraImage image) async {
    if (mode == MotionInputMode.hand) {
      _feedHandFrame(image);
      return;
    }
    if (_isProcessing || _faceDetector == null) return;
    final feedNow = DateTime.now();
    if (feedNow.difference(_lastFaceFeed).inMilliseconds < _faceMinIntervalMs) return;
    _lastFaceFeed = feedNow;
    _isProcessing = true;
    final startTime = DateTime.now();

    try {
      final inputImage = _convertCameraImageToInputImage(image);
      if (inputImage == null) {
        _isProcessing = false;
        return;
      }

      final endTime = DateTime.now();
      final latency = endTime.difference(startTime).inMilliseconds;
      final instantFps = latency > 0 ? (1000.0 / latency).clamp(1.0, 60.0) : 30.0;

      _frameCount++;
      final elapsed = endTime.difference(_lastFrameTime).inMilliseconds;
      if (elapsed >= 1000) {
        _fps = (_frameCount * 1000.0) / elapsed;
        _frameCount = 0;
        _lastFrameTime = endTime;
      }

      final currentFps = _fps > 0 ? _fps : instantFps;

      final faces = await _faceDetector!.processImage(inputImage);
      if (mode != MotionInputMode.face) return; // đã đổi chế độ trong lúc chờ kết quả
      onFace(faces.isEmpty ? null : _toFaceSample(faces.first), latency, currentFps);
    } catch (e) {
      debugPrint('Error processing camera frame: $e');
    } finally {
      _isProcessing = false;
    }
  }

  // ML Kit trả toạ độ theo ảnh ĐÃ XOAY ĐỨNG => xoay 90°/270° thì đổi chỗ rộng/cao
  double _faceUprightW = 1.0;
  double _faceUprightH = 1.0;

  FaceSample _toFaceSample(Face face) {
    double rawRoll = face.headEulerAngleZ ?? 0.0;
    final leftEye = face.landmarks[FaceLandmarkType.leftEye]?.position;
    final rightEye = face.landmarks[FaceLandmarkType.rightEye]?.position;

    if (leftEye != null && rightEye != null) {
      final dx = (rightEye.x - leftEye.x).toDouble();
      final dy = (rightEye.y - leftEye.y).toDouble();
      final eyeAngle = math.atan2(dy, dx) * 180.0 / math.pi;
      if (rawRoll == 0.0) {
        rawRoll = eyeAngle;
      }
    }

    final double rawYaw = face.headEulerAngleY ?? 0.0;
    final double rawPitch = face.headEulerAngleX ?? 0.0;

    double rawMouth = 0.0;
    final upperLip = face.contours[FaceContourType.upperLipBottom];
    final lowerLip = face.contours[FaceContourType.lowerLipTop];
    if (upperLip != null && lowerLip != null && upperLip.points.isNotEmpty && lowerLip.points.isNotEmpty) {
      double uX = 0, uY = 0;
      for (final p in upperLip.points) { uX += p.x; uY += p.y; }
      uX /= upperLip.points.length;
      uY /= upperLip.points.length;

      double lX = 0, lY = 0;
      for (final p in lowerLip.points) { lX += p.x; lY += p.y; }
      lX /= lowerLip.points.length;
      lY /= lowerLip.points.length;

      final lipDist = math.sqrt((lX - uX) * (lX - uX) + (lY - uY) * (lY - uY));
      final faceH = face.boundingBox.height;
      if (faceH > 0) {
        rawMouth = (lipDist / faceH) * 2.8;
      }
    }

    if (rawMouth == 0.0) {
      final leftM = face.landmarks[FaceLandmarkType.leftMouth]?.position;
      final rightM = face.landmarks[FaceLandmarkType.rightMouth]?.position;
      final bottomM = face.landmarks[FaceLandmarkType.bottomMouth]?.position;

      if (leftM != null && rightM != null && bottomM != null) {
        final midX = (leftM.x + rightM.x) / 2.0;
        final midY = (leftM.y + rightM.y) / 2.0;
        final mouthDepth = math.sqrt((bottomM.x - midX) * (bottomM.x - midX) + (bottomM.y - midY) * (bottomM.y - midY));
        final mouthWidth = math.sqrt((rightM.x - leftM.x) * (rightM.x - leftM.x) + (rightM.y - leftM.y) * (rightM.y - leftM.y));
        if (mouthWidth > 0) {
          rawMouth = mouthDepth / mouthWidth;
        }
      }
    }

    final box = face.boundingBox;
    return FaceSample(
      rawRoll: rawRoll,
      rawYaw: rawYaw,
      rawPitch: rawPitch,
      rawMouth: rawMouth,
      center: Offset(box.center.dx / _faceUprightW, box.center.dy / _faceUprightH),
      smileProb: face.smilingProbability ?? 0.0,
      leftEyeOpen: face.leftEyeOpenProbability ?? 1.0,
      rightEyeOpen: face.rightEyeOpenProbability ?? 1.0,
    );
  }

  void _ensureHandPlugin() {
    if (_handPlugin != null || !Platform.isAndroid) return;
    try {
      _handPlugin = hl.HandLandmarkerPlugin.create(
        numHands: 2,
        minHandDetectionConfidence: 0.5,
        delegate: hl.HandLandmarkerDelegate.gpu,
      );
      _handSub = _handPlugin!.landmarkStream.listen(_onHandResult);
      debugPrint('HandLandmarker initialized successfully with GPU delegate (numHands: 2)');
    } catch (e) {
      debugPrint('HandLandmarker GPU error, falling back to CPU: $e');
      try {
        _handPlugin = hl.HandLandmarkerPlugin.create(
          numHands: 2,
          minHandDetectionConfidence: 0.5,
          delegate: hl.HandLandmarkerDelegate.cpu,
        );
        _handSub = _handPlugin!.landmarkStream.listen(_onHandResult);
      } catch (e2) {
        debugPrint('HandLandmarker CPU error: $e2');
        _handPlugin = null;
      }
    }
  }

  void _onHandResult(List<hl.Hand> hands) {
    _handFrameInFlight = false; // cho phép gửi khung kế tiếp
    onHands(HandFrame(
      hands: [
        for (final hand in hands) [for (final p in hand.landmarks) Offset(p.x, p.y)],
      ],
      uprightW: _handUprightW,
      uprightH: _handUprightH,
      latencyMs: DateTime.now().difference(_lastHandFeed).inMilliseconds,
    ));
  }

  /// Góc xoay (độ) để ảnh sensor thành ảnh đứng cho MediaPipe Hand detector
  int _rotationDegrees() {
    final camera = _cameraController?.description;
    final sensor = camera?.sensorOrientation ?? 0;
    int device = 90;
    if (_cameraController != null) {
      switch (_cameraController!.value.deviceOrientation) {
        case DeviceOrientation.portraitUp:
          device = 0;
          break;
        case DeviceOrientation.landscapeLeft:
          device = 90;
          break;
        case DeviceOrientation.portraitDown:
          device = 180;
          break;
        case DeviceOrientation.landscapeRight:
          device = 270;
          break;
      }
    }
    final base = (camera?.lensDirection == CameraLensDirection.front)
        ? (sensor + device) % 360
        : (sensor - device + 360) % 360;
    return (base + aiRotationIndex(MotionInputMode.hand) * 90) % 360;
  }

  void _feedHandFrame(CameraImage image) {
    _ensureHandPlugin();
    final plugin = _handPlugin;
    if (plugin == null || _cameraController == null || image.planes.length < 3) return;

    final now = DateTime.now();
    final sinceLast = now.difference(_lastHandFeed).inMilliseconds;
    if (sinceLast < _handMinIntervalMs) return;
    if (_handFrameInFlight && sinceLast < _handResultTimeoutMs) return; // khung trước chưa xong
    _lastHandFeed = now;
    _handFrameInFlight = true;

    try {
      final rot = _rotationDegrees();
      final swap = rot == 90 || rot == 270;
      _handUprightW = (swap ? image.height : image.width).toDouble();
      _handUprightH = (swap ? image.width : image.height).toDouble();
      plugin.processFrame(image, rot);
    } catch (e) {
      _handFrameInFlight = false;
      debugPrint('Hand processFrame error: $e');
    }
  }

  Uint8List _yuv420ToNv21(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final yBuffer = yPlane.bytes;
    final uBuffer = uPlane.bytes;
    final vBuffer = vPlane.bytes;

    final numPixels = width * height;
    final nv21 = Uint8List(numPixels + (numPixels ~/ 2));

    final yRowStride = yPlane.bytesPerRow;
    final yPixelStride = yPlane.bytesPerPixel ?? 1;

    // Tối ưu tốc độ cao: memcpy block (setRange)
    if (yPixelStride == 1 && yRowStride == width) {
      nv21.setRange(0, numPixels, yBuffer);
    } else {
      int idY = 0;
      for (int y = 0; y < height; y++) {
        final rowStart = y * yRowStride;
        if (yPixelStride == 1) {
          nv21.setRange(idY, idY + width, yBuffer, rowStart);
          idY += width;
        } else {
          for (int x = 0; x < width; x++) {
            nv21[idY++] = yBuffer[rowStart + x * yPixelStride];
          }
        }
      }
    }

    int idUV = numPixels;
    final uvRowStride = uPlane.bytesPerRow;
    final uvPixelStride = uPlane.bytesPerPixel ?? 2;

    for (int y = 0; y < height ~/ 2; y++) {
      final rowStart = y * uvRowStride;
      for (int x = 0; x < width ~/ 2; x++) {
        final uvIndex = rowStart + x * uvPixelStride;
        if (uvIndex < vBuffer.length && uvIndex < uBuffer.length) {
          nv21[idUV++] = vBuffer[uvIndex];
          nv21[idUV++] = uBuffer[uvIndex];
        }
      }
    }

    return nv21;
  }

  InputImage? _convertCameraImageToInputImage(CameraImage image) {
    if (_cameraController == null) return null;

    final camera = _cameraController!.description;
    final sensorOrientation = camera.sensorOrientation;

    int deviceRotationDegrees = 90;
    final devOrientation = _cameraController!.value.deviceOrientation;
    switch (devOrientation) {
      case DeviceOrientation.portraitUp:
        deviceRotationDegrees = 0;
        break;
      case DeviceOrientation.landscapeLeft:
        deviceRotationDegrees = 90;
        break;
      case DeviceOrientation.portraitDown:
        deviceRotationDegrees = 180;
        break;
      case DeviceOrientation.landscapeRight:
        deviceRotationDegrees = 270;
        break;
    }

    InputImageRotation? rotation;
    if (Platform.isAndroid) {
      int rotationCompensation;
      if (camera.lensDirection == CameraLensDirection.front) {
        rotationCompensation = (sensorOrientation + deviceRotationDegrees) % 360;
      } else {
        rotationCompensation = (sensorOrientation - deviceRotationDegrees + 360) % 360;
      }
      rotationCompensation = (rotationCompensation + aiRotationIndex(MotionInputMode.face) * 90) % 360;
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    } else {
      final comp = (sensorOrientation + aiRotationIndex(MotionInputMode.face) * 90) % 360;
      rotation = InputImageRotationValue.fromRawValue(comp);
    }

    rotation ??= InputImageRotationValue.fromRawValue(sensorOrientation) ?? InputImageRotation.rotation0deg;

    // ML Kit trả boundingBox theo ảnh ĐÃ XOAY ĐỨNG => xoay 90°/270° thì đổi chỗ rộng/cao
    final swap = rotation == InputImageRotation.rotation90deg || rotation == InputImageRotation.rotation270deg;
    _faceUprightW = (swap ? image.height : image.width).toDouble();
    _faceUprightH = (swap ? image.width : image.height).toDouble();

    Uint8List bytes;
    int bytesPerRow;

    if (image.planes.length == 1) {
      bytes = image.planes.first.bytes;
      bytesPerRow = image.planes.first.bytesPerRow;
    } else if (Platform.isAndroid && image.planes.length >= 3) {
      bytes = _yuv420ToNv21(image);
      bytesPerRow = image.width;
    } else {
      bytes = image.planes.first.bytes;
      bytesPerRow = image.planes.first.bytesPerRow;
    }

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: bytesPerRow,
      ),
    );
  }
}
