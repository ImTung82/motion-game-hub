import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:ui_web' as ui_web;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;
import '../motion_state.dart';
import 'motion_backend.dart';

MotionBackend createMotionBackend({
  required FaceResultCallback onFace,
  required HandResultCallback onHands,
  required int Function(MotionInputMode mode) aiRotationIndex,
}) =>
    WebMotionBackend(onFace: onFace, onHands: onHands, aiRotationIndex: aiRotationIndex);

// window.motionBridge do web/motion/motion_bridge.js tạo ra
@JS('motionBridge')
external _MotionBridge? get _motionBridge;

extension type _MotionBridge._(JSObject _) implements JSObject {
  external JSPromise<_StartResult> start(_StartOptions options);
  external void stop();
  external void setMode(String mode);
  external web.HTMLVideoElement createPreview();
  external set onHands(JSFunction? callback);
  external set onFace(JSFunction? callback);
}

extension type _StartOptions._(JSObject _) implements JSObject {
  external factory _StartOptions({String mode});
}

extension type _StartResult._(JSObject _) implements JSObject {
  external int get width;
  external int get height;
}

/// Web: webcam + MediaPipe Tasks Vision (JS) qua web/motion/motion_bridge.js
class WebMotionBackend extends MotionBackend {
  WebMotionBackend({required super.onFace, required super.onHands, required super.aiRotationIndex});

  static const String _previewViewType = 'motion-camera-preview';
  static bool _previewRegistered = false;

  _MotionBridge? _bridge;
  Size? _videoSize;

  // FPS (Face mode)
  int _faceResultCount = 0;
  DateTime _faceFpsStart = DateTime.now();
  double _faceFps = 0.0;

  @override
  set mode(MotionInputMode value) {
    super.mode = value;
    _bridge?.setMode(_modeName(value));
  }

  static String _modeName(MotionInputMode mode) => mode == MotionInputMode.hand ? 'hand' : 'face';

  @override
  Future<void> start({VoidCallback? onCameraReady}) async {
    final bridge = await _waitForBridge();
    bridge.onHands = _handleHands.toJS;
    bridge.onFace = _handleFace.toJS;

    final result = await bridge.start(_StartOptions(mode: _modeName(mode))).toDart;
    _bridge = bridge;
    _videoSize = Size(result.width.toDouble(), result.height.toDouble());

    if (!_previewRegistered) {
      ui_web.platformViewRegistry.registerViewFactory(_previewViewType, (int viewId) => bridge.createPreview());
      _previewRegistered = true;
    }
    onCameraReady?.call();
  }

  /// motion_bridge.js là ES module (nạp hoãn) => có thể chưa sẵn sàng khi Flutter khởi động
  static Future<_MotionBridge> _waitForBridge() async {
    for (int i = 0; i < 100; i++) {
      final bridge = _motionBridge;
      if (bridge != null) return bridge;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    throw StateError('motion_bridge.js was not loaded');
  }

  @override
  Future<void> stop() async {
    _bridge?.stop();
    _bridge = null;
    _videoSize = null;
  }

  @override
  void dispose() {
    _bridge?.stop();
    _bridge = null;
  }

  @override
  bool get isReady => _bridge != null;

  @override
  bool get mirrored => true; // preview lật gương bằng CSS trong motion_bridge.js

  @override
  Size? get previewSize => _videoSize;

  @override
  bool get supportsRotation => false;

  @override
  Widget buildPreview() => const HtmlElementView(viewType: _previewViewType);

  void _handleHands(JSFloat32Array data, int count, double width, double height, double costMs) {
    final d = data.toDart;
    onHands(HandFrame(
      hands: [
        for (int i = 0; i < count; i++) [for (int j = 0; j < 21; j++) Offset(d[i * 42 + j * 2], d[i * 42 + j * 2 + 1])],
      ],
      uprightW: width,
      uprightH: height,
      latencyMs: costMs.round(),
    ));
  }

  void _handleFace(JSFloat32Array? data, double width, double height, double costMs) {
    final now = DateTime.now();
    _faceResultCount++;
    final elapsed = now.difference(_faceFpsStart).inMilliseconds;
    if (elapsed >= 1000) {
      _faceFps = _faceResultCount * 1000.0 / elapsed;
      _faceResultCount = 0;
      _faceFpsStart = now;
    }
    final fps = _faceFps > 0 ? _faceFps : 30.0;
    onFace(data == null ? null : _toFaceSample(data.toDart, width, height), costMs.round(), fps);
  }

  /// Đổi điểm mốc MediaPipe sang cùng thang đo ML Kit (Android) để dùng chung ngưỡng & logic.
  /// Thứ tự dữ liệu: 6 điểm (x, y, z) (khoé mắt 33, 263, môi trong 13, 14, trán 10, cằm 152), tâm mặt (x, y).
  static FaceSample _toFaceSample(Float32List d, double width, double height) {
    Offset point(int k) => Offset(d[k * 3] * width, d[k * 3 + 1] * height);
    // z của MediaPipe cùng thang với x (chuẩn hoá theo chiều rộng ảnh); nhỏ hơn = gần camera hơn
    double depth(int k) => d[k * 3 + 2] * width;
    final eyeA = point(0);
    final eyeB = point(1);
    final upperLip = point(2);
    final lowerLip = point(3);
    final top = point(4);
    final chin = point(5);

    // Nghiêng đầu theo quy ước ML Kit: dương = xoay NGƯỢC chiều kim đồng hồ trong ảnh (trục y hướng xuống)
    final bool aIsLeft = eyeA.dx <= eyeB.dx; // mắt bên trái ẢNH
    final eyeLeft = aIsLeft ? eyeA : eyeB;
    final eyeRight = aIsLeft ? eyeB : eyeA;
    final rawRoll = -math.atan2(eyeRight.dy - eyeLeft.dy, eyeRight.dx - eyeLeft.dx) * 180.0 / math.pi;

    // Há miệng: khoảng cách 2 môi trong / chiều cao mặt, cùng hệ số với ML Kit
    final faceH = (chin - top).distance;
    final rawMouth = faceH > 0 ? (lowerLip - upperLip).distance / faceH * 2.8 : 0.0;

    // Ngẩng/cúi: vector cằm -> trán trong không gian 3D. Cúi đầu (gật) thì trán tiến về camera (z giảm)
    // => góc âm; ngẩng lên => góc dương (cùng quy ước ML Kit headEulerAngleX)
    final double upZ = depth(4) - depth(5);
    final double upY = top.dy - chin.dy; // âm khi mặt thẳng (trán ở trên cằm)
    final double rawPitch = math.atan2(upZ, -upY) * 180.0 / math.pi;

    // Quay mặt trái/phải: vector mắt trái ẢNH -> mắt phải ẢNH theo trục z
    final double eyeZ = aIsLeft ? depth(1) - depth(0) : depth(0) - depth(1);
    final double rawYaw = math.atan2(eyeZ, eyeRight.dx - eyeLeft.dx) * 180.0 / math.pi;

    return FaceSample(
      rawRoll: rawRoll,
      rawYaw: rawYaw,
      rawPitch: rawPitch,
      rawMouth: rawMouth,
      center: Offset(d[18], d[19]),
    );
  }
}
