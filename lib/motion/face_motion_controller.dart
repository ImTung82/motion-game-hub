import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import 'backend/motion_backend.dart';
import 'backend/motion_backend_factory.dart';
import 'motion_state.dart';
import 'signal_filters.dart';

/// Bộ điều khiển cử chỉ khuôn mặt và bàn tay (Face & Hand Motion Controller)
class FaceMotionController extends ChangeNotifier {
  // Nguồn camera + AI theo nền tảng (Android: ML Kit + hand_landmarker, Web: MediaPipe JS)
  late final MotionBackend _backend = createMotionBackend(
    onFace: _onFaceResult,
    onHands: _onHandResult,
    aiRotationIndex: (mode) => mode == MotionInputMode.hand ? _aiHandRotationIndex : _aiRotationOffset,
  );

  bool _isInitialized = false;
  bool _cameraAvailable = false;
  String _statusMessage = 'Starting camera...';

  MotionInputMode _inputMode = MotionInputMode.face;
  MotionInputMode get inputMode => _inputMode;
  set inputMode(MotionInputMode mode) {
    if (_inputMode == mode) return;
    _inputMode = mode;
    _backend.mode = mode;
    calibrateNeutral();
    _savePreferences();
    notifyListeners();
  }

  // Cấu hình cử chỉ
  double _tiltThreshold = MotionDefaults.defaultTiltThreshold;
  double _tiltRelease = MotionDefaults.defaultTiltRelease;
  double _mouthOpenThreshold = MotionDefaults.defaultMouthOpenThreshold;
  double _mouthCloseThreshold = MotionDefaults.defaultMouthCloseThreshold;
  bool _invertLean = false; // Mặc định tắt switch: cơ chế mặc định đã tự động đúng chiều (nghiêng/lướt trái -> game sang trái)
  bool _showTouchControls = false;
  bool _showCameraPip = true;
  bool _showCameraStats = false; // Thanh thông số dưới khung camera trong game (mặc định ẩn)
  int _cameraRotationQuarterTurns = 0; // 0=0°, 1=90°, 2=180°, 3=270° (UI Preview)
  int _aiRotationOffset = 0; // 0=0°, 1=90°, 2=180°, 3=270° (Face AI detector)
  int _aiHandRotationIndex = 0; // 0=0°, 1=90°, 2=180°, 3=270° (MediaPipe Hand AI detector)
  int _consecutiveEmptyFrames = 0;

  // Trạng thái mốc trung tính Face
  double _neutralRoll = 0.0;
  double _baselineMouth = 0.0;
  double _neutralYaw = 0.0;
  double _neutralPitch = 0.0;

  // Bộ lọc Face. Mọi bộ lọc tính theo THỜI GIAN giữa 2 kết quả (signal_filters.dart), không theo số kết quả:
  // máy nhận diện chậm (VD 12 lần/giây trên web) không bị trễ gấp đôi, gấp ba máy nhanh.
  // Góc đầu dùng One Euro: đứng yên lọc như EMA cũ (hết rung), quay/gật nhanh thì bám ngay (hết trễ).
  final OneEuroFilter _rollFilter = OneEuroFilter.likeEma(MotionDefaults.emaAlpha, beta: 0.08);
  final OneEuroFilter _yawFilter = OneEuroFilter.likeEma(MotionDefaults.emaAlpha, beta: 0.08);
  final OneEuroFilter _pitchFilter = OneEuroFilter.likeEma(MotionDefaults.emaAlpha, beta: 0.08);
  double _smoothedRoll = 0.0;
  double _smoothedMouth = 0.0;
  double _smoothedYaw = 0.0;
  double _smoothedPitch = 0.0;
  bool _hasInitialValues = false;
  DateTime? _lastFaceSampleTime;
  double _calibSampleSec = 0.0; // thời gian đã lấy mẫu cân bằng liên tục (mặt / tay đứng yên)

  // Tự động hiệu chỉnh Hand & Face
  bool _isCalibrating = false;
  bool _hasFaceCalibratedOnce = false;
  bool _hasHandCalibratedOnce = false;
  int _calibrationFrames = 0;
  double _calibRollSum = 0.0;
  double _calibMouthSum = 0.0;
  double _calibYawSum = 0.0;
  double _calibPitchSum = 0.0;
  double _neutralHandX = 0.0;
  double _neutralHandY = 0.0;
  double _neutralPalmElevation = 0.50;
  double _calibElevationSum = 0.0;
  double _neutralHandTilt = 0.0;
  double _neutralDirX = 0.0;
  double _neutralDirY = -1.0;
  double _calibHandXSum = 0.0;
  double _calibHandYSum = 0.0;
  double _calibDirXSum = 0.0;
  double _calibDirYSum = 0.0;
  // Góc nghiêng TƯƠNG ĐỐI so với hướng tay lúc cân bằng (độ)
  final OneEuroFilter _handTiltFilter = OneEuroFilter.likeEma(0.38, beta: 0.08);
  bool _isHandSteeringActive = false; // trạng thái trễ (hysteresis) cho TRÁI/PHẢI
  double _calibElapsedSec = 0.0; // thời gian đã thử cân bằng tay (kể cả lúc tay còn rung)
  double _lastCalibX = 0.0;
  double _lastCalibY = 0.0;
  int _calibratedHandRotation = -1; // góc quét AI tại thời điểm cân bằng tay
  double _currentHandTilt = 0.0;
  // Lọc chống giật cho giá trị lái cuối cùng (handX / steerX)
  final OneEuroFilter _steerFilter = OneEuroFilter.likeEma(0.35, beta: 1.5);
  double _handDeadzone = 0.18;
  double _handSensitivity = 1.8; // Độ nhạy / Tầm lướt tay (1.2 -> 4.0)

  /// Quãng đưa tay ngang (tỉ lệ bề ngang khung hình camera) ứng với lái hết cỡ ở độ nhạy 2.0x.
  /// Web rộng hơn Android: webcam laptop / PC thường ở gần người chơi hơn camera điện thoại / tablet, nên cùng
  /// 1 cú đưa tay chiếm phần khung hình lớn hơn => cùng thông số thì web nhạy hơn hẳn. Với độ nhạy mặc định
  /// 2.4x: Android lái hết cỡ khi đưa tay ~17% khung hình, web ~23%. Thanh "Hand reach" vẫn chỉnh thêm được.
  static const double _handReach = kIsWeb ? 0.25 : 0.18;
  double _fistThreshold = 0.45; // Ngưỡng kích hoạt Nắm tay (0.20 -> 0.75)
  double _smoothedFistScore = 0.0;
  // Thời gian (giây) điều kiện nắm / xoè đã giữ liên tục: thay cho "2 khung liên tiếp" (= ~50ms ở 30 lần/giây)
  double _fistActivateHeld = 0.0;
  double _fistReleaseHeld = 0.0;
  bool _isHandFistState = false;
  double _smoothFlex = 1.0;
  final List<_HandChopSample> _chopHistory = [];
  DateTime _lastChopTime = DateTime.fromMillisecondsSinceEpoch(0);
  double _smoothChopScore = 0.0;
  bool _isSlamArmed = false;
  bool _hasSmoothFlex = false;
  final double _maxHandSpan = 65.0;
  double _currentHandSpan = 45.0;

  double get currentHandSpan => _currentHandSpan;
  double get maxHandSpan => _maxHandSpan;

  // Trạng thái theo dõi 2 bàn tay (Dual-Hand Tracking)
  final OneEuroFilter _leftXFilter = OneEuroFilter.likeEma(0.45, beta: _handPosBeta);
  final OneEuroFilter _leftYFilter = OneEuroFilter.likeEma(0.45, beta: _handPosBeta);
  double _smoothLeftFist = 0.0;
  bool _isLeftFist = false;

  final OneEuroFilter _rightXFilter = OneEuroFilter.likeEma(0.45, beta: _handPosBeta);
  final OneEuroFilter _rightYFilter = OneEuroFilter.likeEma(0.45, beta: _handPosBeta);
  double _smoothRightFist = 0.0;
  bool _isRightFist = false;

  // Số nơi đang cần nhận diện 2 tay (hub 2 tay, thẻ "2 tay" trong Hiệu chỉnh). Không ai cần => chỉ tìm 1 tay:
  // MediaPipe phải chạy lại bước TÌM bàn tay mỗi khung khi số tay thấy < số tay tối đa => 1 tay nhanh gấp ~2.
  int _twoHandHolds = 0;

  /// Bắt đầu cần nhận diện 2 tay; gọi [releaseTwoHands] đúng 1 lần khi xong
  void holdTwoHands() {
    _twoHandHolds++;
    _backend.maxHands = 2;
  }

  void releaseTwoHands() {
    if (_twoHandHolds > 0) _twoHandHolds--;
    _backend.maxHands = _twoHandHolds > 0 ? 2 : 1;
  }

  bool _isClapArmed = false;
  DateTime _lastClapTime = DateTime.fromMillisecondsSinceEpoch(0);
  double _clapThreshold = 0.20;

  // Bộ chống rung (Debounce)
  int _chompDebounce = 0;
  int _tiltLeftDebounce = 0;
  int _tiltRightDebounce = 0;

  MotionState _state = MotionState.initial();

  // Getters
  MotionState get state => _state;
  bool get isInitialized => _isInitialized;
  bool get cameraAvailable => _cameraAvailable;
  String get statusMessage => _statusMessage;
  /// Camera đã mở & có hình xem trước
  bool get hasPreview => _backend.isReady;

  /// Kích thước khung hình gốc của camera (null khi chưa sẵn sàng)
  Size? get previewSize => _backend.previewSize;

  /// Có hỗ trợ xoay camera / xoay AI (Android) hay không (Web: không)
  bool get supportsRotation => _backend.supportsRotation;

  /// Hình xem trước camera (chỉ gọi khi [hasPreview])
  Widget buildPreview() => _backend.buildPreview();
  bool get isCalibrating => _isCalibrating;

  double get tiltThreshold => _tiltThreshold;
  double get mouthOpenThreshold => _mouthOpenThreshold;
  double get handSensitivity => _handSensitivity;
  set handSensitivity(double value) {
    _handSensitivity = value.clamp(1.0, 5.0);
    _savePreferences();
    notifyListeners();
  }

  double get handDeadzone => _handDeadzone;
  set handDeadzone(double value) {
    _handDeadzone = value.clamp(0.05, 0.45);
    _savePreferences();
    notifyListeners();
  }

  double get fistThreshold => _fistThreshold;
  set fistThreshold(double value) {
    _fistThreshold = value.clamp(0.20, 0.75);
    _savePreferences();
    notifyListeners();
  }

  double get clapThreshold => _clapThreshold;
  set clapThreshold(double value) {
    _clapThreshold = value.clamp(0.10, 0.45);
    _savePreferences();
    notifyListeners();
  }

  set tiltThreshold(double value) {
    _tiltThreshold = value;
    _tiltRelease = value * 0.5;
    _savePreferences();
    notifyListeners();
  }

  set mouthOpenThreshold(double value) {
    _mouthOpenThreshold = value;
    _mouthCloseThreshold = value * 0.55;
    _savePreferences();
    notifyListeners();
  }

  int get cameraRotationQuarterTurns => _cameraRotationQuarterTurns;
  int get aiRotationOffset => _inputMode == MotionInputMode.hand ? _aiHandRotationIndex : _aiRotationOffset;

  bool get invertLean => _invertLean;
  set invertLean(bool value) {
    _invertLean = value;
    _savePreferences();
    notifyListeners();
  }

  bool get showTouchControls => _showTouchControls;

  /// Chơi bằng chạm / chuột: không có camera (bị từ chối quyền, trang nhúng chặn, máy không có webcam)
  /// hoặc bật "touch buttons" trong Cài đặt. Lúc camera còn đang mở (chờ cấp quyền) thì chưa tính.
  bool get touchMode => noCamera || _showTouchControls;

  /// Đã thử mở camera nhưng không được => chỉ chơi được bằng chạm / chuột
  bool get noCamera => _isInitialized && !_cameraAvailable;
  set showTouchControls(bool value) {
    _showTouchControls = value;
    _savePreferences();
    notifyListeners();
  }

  bool get showCameraStats => _showCameraStats;
  set showCameraStats(bool value) {
    _showCameraStats = value;
    _savePreferences();
    notifyListeners();
  }

  bool get showCameraPip => _showCameraPip;
  set showCameraPip(bool value) {
    _showCameraPip = value;
    _savePreferences();
    notifyListeners();
  }

  /// Đổi trạng thái PiP camera mà KHÔNG notify (an toàn khi gọi trong initState/dispose của màn game).
  /// [persist] = true thì lưu luôn vào cài đặt.
  void setCameraPipQuietly(bool value, {bool persist = false}) {
    _showCameraPip = value;
    if (persist) _savePreferences();
  }

  double get neutralRoll => _neutralRoll;
  double get baselineMouth => _baselineMouth;
  double get neutralHandX => _neutralHandX;
  double get neutralHandY => _neutralHandY;
  double get neutralHandTilt => _neutralHandTilt;
  double get currentHandTilt => _currentHandTilt;

  FaceMotionController();

  bool _isInitializing = false;

  Future<void> retryInitialize() async {
    await _backend.stop();
    _cameraAvailable = false;
    _isInitialized = false;
    _isInitializing = false;
    _statusMessage = 'Reconnecting...';
    notifyListeners();
    await initialize();
  }

  set cameraRotationQuarterTurns(int value) {
    _cameraRotationQuarterTurns = value % 4;
    calibrateNeutral();
    notifyListeners();
  }

  void rotateCamera() {
    _cameraRotationQuarterTurns = (_cameraRotationQuarterTurns + 1) % 4;
    calibrateNeutral(); // Tự động hiệu chỉnh lại mốc trung tính theo góc hiển thị mới
    _savePreferences();
    notifyListeners();
  }

  set aiRotationOffset(int value) {
    if (_inputMode == MotionInputMode.hand) {
      _aiHandRotationIndex = value % 4;
    } else {
      _aiRotationOffset = value % 4;
    }
    notifyListeners();
  }

  void rotateAiSensor() {
    if (_inputMode == MotionInputMode.hand) {
      _aiHandRotationIndex = (_aiHandRotationIndex + 1) % 4;
    } else {
      _aiRotationOffset = (_aiRotationOffset + 1) % 4;
    }
    _savePreferences();
    notifyListeners();
  }

  Future<void> initialize() async {
    if (_isInitialized && _cameraAvailable) return;
    if (_isInitializing) return;
    _isInitializing = true;
    try {
      await _initCameraAndDetector();
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> _initCameraAndDetector() async {
    await _loadPreferences();

    try {
      _backend.mode = _inputMode;
      await _backend.start(onCameraReady: () {
        _cameraAvailable = true;
        _isInitialized = true;
        _statusMessage = 'Camera ready';
        _isCalibrating = false;
        _calibrationFrames = 0;
        notifyListeners();
      });
    } catch (e) {
      debugPrint('FaceMotionController Camera Error: $e');
      _cameraAvailable = false;
      _isInitialized = true;
      _statusMessage = 'Touch mode / on-screen buttons ($e)';
      notifyListeners();
    }
  }

  void _onFaceResult(FaceSample? face, int latency, double currentFps) {
    if (_inputMode != MotionInputMode.face) return;
    final endTime = DateTime.now();

    if (face == null) {
      _hasSmoothFaceVisual = false;
      _consecutiveEmptyFrames++;
      // Tự săn góc xoay AI chỉ có nghĩa khi backend xoay được ảnh (Android); web luôn đúng chiều
      if (_backend.supportsRotation && _consecutiveEmptyFrames >= 6) {
        _aiRotationOffset = (_aiRotationOffset + 1) % 4;
        _consecutiveEmptyFrames = 0;
      }

      _chompDebounce = 0;
      _tiltLeftDebounce = 0;
      _tiltRightDebounce = 0;
      _state = _state.copyWith(
        inputMode: MotionInputMode.face,
        faceDetected: false,
        handDetected: false,
        tiltDirection: TiltDirection.neutral,
        steerX: 0.0,
        isChomping: false,
        fps: currentFps,
        latencyMs: latency,
        timestamp: endTime,
      );
      notifyListeners();
      return;
    }

    _consecutiveEmptyFrames = 0;
    _processFaceMetrics(face, latency, endTime, currentFps);
  }

  // ==========================================
  // XỬ LÝ CỬ CHỈ KHUÔN MẶT (FACE MODE)
  // ==========================================
  void _processFaceMetrics(FaceSample face, int latency, DateTime timestamp, double currentFps) {
    final double dt = sampleDt(_lastFaceSampleTime, timestamp);
    _lastFaceSampleTime = timestamp;
    final rawRoll = face.rawRoll;
    final rawYaw = face.rawYaw;
    final rawPitch = face.rawPitch;
    final rawMouth = face.rawMouth;
    final smileProb = face.smileProb;
    final leftEyeOpen = face.leftEyeOpen;
    final rightEyeOpen = face.rightEyeOpen;
    final isWinking = (leftEyeOpen - rightEyeOpen).abs() > 0.5;

    _smoothedRoll = _rollFilter.filter(rawRoll, dt);
    _smoothedYaw = _yawFilter.filter(rawYaw, dt);
    _smoothedPitch = _pitchFilter.filter(rawPitch, dt);
    if (!_hasInitialValues) {
      _smoothedMouth = rawMouth;
      _hasInitialValues = true;
    } else {
      _smoothedMouth += (rawMouth - _smoothedMouth) * timedAlpha(MotionDefaults.emaAlpha, dt);
    }

    // Tự động căn mốc trung tính Face
    if (_isCalibrating || !_hasFaceCalibratedOnce) {
      _isCalibrating = true;
      _calibRollSum += _smoothedRoll;
      _calibMouthSum += _smoothedMouth;
      _calibYawSum += _smoothedYaw;
      _calibPitchSum += _smoothedPitch;
      _calibrationFrames++;
      _calibSampleSec += dt;

      // ~6 khung ở 30 lần/giây (0,2s); máy chậm thì đủ thời gian & ít nhất 3 mẫu là xong
      if (_calibrationFrames >= 6 || (_calibrationFrames >= 3 && _calibSampleSec >= 6 * kTunedSampleDt)) {
        _neutralRoll = _calibRollSum / _calibrationFrames;
        _baselineMouth = _calibMouthSum / _calibrationFrames;
        _neutralYaw = _calibYawSum / _calibrationFrames;
        _neutralPitch = _calibPitchSum / _calibrationFrames;
        _isCalibrating = false;
        _hasFaceCalibratedOnce = true;
        _calibRollSum = 0.0;
        _calibMouthSum = 0.0;
        _calibYawSum = 0.0;
        _calibPitchSum = 0.0;
        _calibrationFrames = 0;
        _calibSampleSec = 0.0;
        _savePreferences();
        notifyListeners();
      }
    } else {
      final curYawDiff = _smoothedYaw - _neutralYaw;
      final double drift = timedAlpha(0.015, dt);
      if (curYawDiff.abs() < 5.0) {
        _neutralYaw += curYawDiff * drift;
      }
      final curRollDiff = _smoothedRoll - _neutralRoll;
      if (curRollDiff.abs() < 4.0) {
        _neutralRoll += curRollDiff * drift;
      }
    }

    // Mặc định switch TẮT: sign = 1.0 (nghiêng đầu trái -> game sang trái, nghiêng phải -> sang phải)
    // Switch BẬT: sign = -1.0 (đảo chiều ngược lại)
    final sign = _invertLean ? -1.0 : 1.0;
    final relativeRoll = (_smoothedRoll - _neutralRoll) * sign;
    final relativeYaw = (_smoothedYaw - _neutralYaw) * sign;
    final relativePitch = (_smoothedPitch - _neutralPitch);
    final relativeMouth = math.max(0.0, _smoothedMouth - _baselineMouth);

    TiltDirection tilt = _state.tiltDirection;
    if (relativeRoll < -_tiltThreshold) {
      _tiltLeftDebounce++;
      _tiltRightDebounce = 0;
      if (_tiltLeftDebounce >= 1) tilt = TiltDirection.left;
    } else if (relativeRoll > _tiltThreshold) {
      _tiltRightDebounce++;
      _tiltLeftDebounce = 0;
      if (_tiltRightDebounce >= 1) tilt = TiltDirection.right;
    } else if (relativeRoll.abs() < _tiltRelease) {
      _tiltLeftDebounce = 0;
      _tiltRightDebounce = 0;
      tilt = TiltDirection.neutral;
    }

    // steerX thống nhất cho game: lấy từ góc NGHIÊNG ĐẦU (roll) - cùng nguồn với tiltDirection & thước đo,
    // nên luôn cùng chiều. Không trộn yaw vì dấu yaw không đồng nhất với roll giữa các thiết bị.
    // Vùng chết = _tiltRelease, đạt 100% ở 1.8 x ngưỡng nghiêng (khớp thước đo trong Hiệu chỉnh).
    double steerX = 0.0;
    final double rollAbs = relativeRoll.abs();
    if (rollAbs > _tiltRelease) {
      final double full = _tiltThreshold * 1.8;
      steerX = relativeRoll.sign * ((rollAbs - _tiltRelease) / (full - _tiltRelease)).clamp(0.0, 1.0);
    }

    bool isChomping = _state.isChomping;
    if (!isChomping) {
      if (relativeMouth > _mouthOpenThreshold) {
        _chompDebounce++;
        if (_chompDebounce >= 1) isChomping = true;
      } else {
        _chompDebounce = 0;
      }
    } else {
      if (relativeMouth < _mouthCloseThreshold) {
        isChomping = false;
        _chompDebounce = 0;
      }
    }

    // Vị trí khuôn mặt trên màn hình preview (cùng phép lật gương/xoay như reticle bàn tay)
    final faceScreen = _landmarkToScreen(face.center.dx, face.center.dy);
    final double faceVX = ((faceScreen.dx - 0.5) * 2.0).clamp(-1.0, 1.0);
    final double faceVY = ((faceScreen.dy - 0.5) * 2.0).clamp(-1.0, 1.0);
    if (!_hasSmoothFaceVisual) {
      _smoothFaceVisualX = faceVX;
      _smoothFaceVisualY = faceVY;
      _hasSmoothFaceVisual = true;
    } else {
      final double a = timedAlpha(0.45, dt);
      _smoothFaceVisualX += (faceVX - _smoothFaceVisualX) * a;
      _smoothFaceVisualY += (faceVY - _smoothFaceVisualY) * a;
    }

    _state = MotionState(
      inputMode: MotionInputMode.face,
      faceVisualX: _smoothFaceVisualX,
      faceVisualY: _smoothFaceVisualY,
      rawRoll: rawRoll,
      smoothRoll: _smoothedRoll,
      relativeRoll: relativeRoll,
      rawYaw: rawYaw,
      smoothYaw: _smoothedYaw,
      relativeYaw: relativeYaw,
      rawPitch: rawPitch,
      smoothPitch: _smoothedPitch,
      relativePitch: relativePitch,
      smileProb: smileProb,
      leftEyeOpen: leftEyeOpen,
      rightEyeOpen: rightEyeOpen,
      isWinking: isWinking,
      rawMouth: rawMouth,
      smoothMouth: _smoothedMouth,
      relativeMouth: relativeMouth,
      isChomping: isChomping,
      tiltDirection: tilt,
      steerX: steerX,
      faceDetected: true,
      handDetected: false,
      fps: currentFps,
      latencyMs: latency,
      timestamp: timestamp,
    );

    notifyListeners();
  }

  // ==========================================
  // HAND MODE: MediaPipe Hand Landmarker (21 điểm / bàn tay)
  // ==========================================
  bool _hasSmoothFaceVisual = false;
  double _smoothFaceVisualX = 0.0;
  double _smoothFaceVisualY = 0.0;
  int _handLostFrames = 0;
  double _handLostSec = 0.0; // tay mất liên tục bao lâu
  DateTime? _lastHandSampleTime;
  // Tâm lòng bàn tay: toạ độ màn hình (đã lật gương) trừ 0.5. One Euro: tay đứng yên hết rung, vung nhanh hết trễ.
  // beta theo đơn vị "chiều ngang khung hình / giây" (vung tay ~1-2/giây).
  static const double _handPosBeta = 5.0;
  final OneEuroFilter _handXFilter = OneEuroFilter.likeEma(0.45, beta: _handPosBeta);
  final OneEuroFilter _handYFilter = OneEuroFilter.likeEma(0.45, beta: _handPosBeta);
  double _smoothHandX = 0.0;
  double _smoothHandY = 0.0;
  int _handResultCount = 0;
  DateTime _handFpsStart = DateTime.now();
  double _handFps = 0.0;

  /// Chuyển đổi toạ độ từ cảm biến camera raw [0..1] sang toạ độ Màn hình Preview [0..1]
  /// phụ thuộc vào góc xoay _cameraRotationQuarterTurns và thuộc tính gương của camera trước.
  Offset _landmarkToScreen(double xRaw, double yRaw) {
    final double u = _backend.mirrored ? (1.0 - xRaw) : xRaw;
    final double v = yRaw;

    double x, y;
    switch (_cameraRotationQuarterTurns % 4) {
      case 0:
        x = u;
        y = v;
        break;
      case 1: // 90° clockwise
        x = 1.0 - v;
        y = u;
        break;
      case 2: // 180° clockwise
        x = 1.0 - u;
        y = 1.0 - v;
        break;
      case 3: // 270° clockwise
      default:
        x = v;
        y = 1.0 - u;
        break;
    }
    return Offset(x.clamp(0.0, 1.0), y.clamp(0.0, 1.0));
  }

  void _markHandLost() {
    _isHandFistState = false;
    _fistActivateHeld = 0.0;
    _fistReleaseHeld = 0.0;
    _smoothedFistScore = 0.0;
    _handXFilter.reset();
    _handYFilter.reset();
    _chopHistory.clear();
    _smoothChopScore = 0.0;
    _handTiltFilter.reset();
    _currentHandTilt = 0.0;
    _steerFilter.reset(0.0);
    _isHandSteeringActive = false;
    _resetDualHandFilters(left: true, right: true);
    _isClapArmed = false;
    _state = _state.copyWith(
      inputMode: MotionInputMode.hand,
      handDetected: false,
      faceDetected: false,
      isHandFist: false,
      isHandOpen: true,
      isChomping: false,
      tiltDirection: TiltDirection.neutral,
      steerX: 0.0,
      handsCount: 0,
      leftHand: HandData.initial,
      rightHand: HandData.initial,
      clapDistance: 1.0,
      isClapTriggered: false,
      fps: _handFps,
      timestamp: DateTime.now(),
    );
    notifyListeners();
  }

  void _onHandResult(HandFrame frame) {
    if (_inputMode != MotionInputMode.hand) return;
    final hands = frame.hands;

    final now = DateTime.now();
    final double dt = sampleDt(_lastHandSampleTime, now);
    _lastHandSampleTime = now;
    _handResultCount++;
    final fpsElapsed = now.difference(_handFpsStart).inMilliseconds;
    if (fpsElapsed >= 1000) {
      _handFps = _handResultCount * 1000.0 / fpsElapsed;
      _handResultCount = 0;
      _handFpsStart = now;
    }

    if (hands.isEmpty || hands.first.length < 21) {
      _handLostFrames++;
      final double lostBefore = _handLostSec;
      _handLostSec += dt;
      // Tự động săn góc xoay AI (chỉ Android: web luôn đúng chiều): chỉ khi mất tay lâu (~1.5s). Trước đây đổi
      // góc sau 0.4s khiến tay bị che thoáng qua cũng đổi hệ toạ độ -> trục trái/phải bị xoay, điều khiển loạn.
      // (Đổi góc còn bắt cân bằng lại tay => trên web từng làm tay "đơ" mỗi lần hạ tay xuống rồi giơ lên.)
      if (_backend.supportsRotation && _handLostFrames % 45 == 0) {
        _aiHandRotationIndex = (_aiHandRotationIndex + 1) % 4;
      }
      // Cho phép mất tay ~0,2s (5 khung ở 30 lần/giây) để không bị chớp
      const double lostAfterSec = 5.5 * kTunedSampleDt;
      if (_handLostSec >= lostAfterSec && (lostBefore < lostAfterSec || _state.handDetected)) {
        _markHandLost();
      }
      return;
    }

    _handLostFrames = 0;
    _handLostSec = 0.0;

    // Góc quét AI khác lúc cân bằng => hệ toạ độ landmark đã xoay, mốc cũ vô nghĩa -> cân bằng lại
    if (_hasHandCalibratedOnce && !_isCalibrating && _calibratedHandRotation != -1 &&
        _calibratedHandRotation != _aiHandRotationIndex) {
      _resetHandCalibration();
    }

    final lm = hands.first;
    final double w = frame.uprightW;
    final double h = frame.uprightH;

    // Chuyển đổi 21 điểm landmarks sang Hệ quy chiếu Màn hình Preview (Screen Coordinates)
    // Giúp Reticle và Vector cử chỉ khớp 100% với những gì người dùng thấy trên màn hình
    final screenLm = List<Offset>.generate(21, (i) => _landmarkToScreen(lm[i].dx, lm[i].dy));

    // Khoảng cách theo pixel màn hình
    double dist(int a, int b) {
      final dx = (screenLm[a].dx - screenLm[b].dx) * w;
      final dy = (screenLm[a].dy - screenLm[b].dy) * h;
      return math.sqrt(dx * dx + dy * dy);
    }

    // 1. VỊ TRÍ TÂM LÒNG BÀN TAY (Screen Coordinates)
    double screenCx = 0.0;
    double screenCy = 0.0;
    for (final i in const [0, 5, 9, 13, 17]) {
      screenCx += screenLm[i].dx;
      screenCy += screenLm[i].dy;
    }
    screenCx /= 5.0;
    screenCy /= 5.0;

    // Tọa độ màn hình: tâm = 0.0, lệch trái là âm, lệch phải là dương
    final double rawX = screenCx - 0.5; // [-0.5, +0.5]
    final double rawY = screenCy - 0.5; // [-0.5, +0.5]

    _smoothHandX = _handXFilter.filter(rawX, dt);
    _smoothHandY = _handYFilter.filter(rawY, dt);

    // Tọa độ Reticle hiển thị: khớp 100% vị trí bàn tay trên màn hình preview
    final double visualX = (_smoothHandX * 2.0).clamp(-1.0, 1.0);
    final double visualY = (_smoothHandY * 2.0).clamp(-1.0, 1.0);

    // 2. VECTOR HƯỚNG BÀN TAY TRÊN MÀN HÌNH (Hand Direction Vector):
    // Vector từ Cổ tay (0) -> Trung bình 4 khớp gốc ngón tay (5, 9, 13, 17)
    final double knuckleX = (screenLm[5].dx + screenLm[9].dx + screenLm[13].dx + screenLm[17].dx) * 0.25;
    final double knuckleY = (screenLm[5].dy + screenLm[9].dy + screenLm[13].dy + screenLm[17].dy) * 0.25;
    final double curVx = knuckleX - screenLm[0].dx;
    final double curVy = knuckleY - screenLm[0].dy;
    final double curVlen = math.sqrt(curVx * curVx + curVy * curVy);
    final double curDirX = curVlen > 0.001 ? curVx / curVlen : 0.0;
    final double curDirY = curVlen > 0.001 ? curVy / curVlen : -1.0;

    // =========================================================================
    // 2c. BẮT CỬ CHỈ HẠ TAY XUỐNG ĐẬP BÚA (DOWNWARD SLAM)
    // =========================================================================
    _chopHistory.add(_HandChopSample(now, screenCx, screenCy));
    while (_chopHistory.isNotEmpty && now.difference(_chopHistory.first.time).inMilliseconds > 280) {
      _chopHistory.removeAt(0);
    }

    // Tìm điểm cao nhất của tay (minY) trong 280ms vừa qua
    double minY = screenCy;
    DateTime minTime = now;
    double minX = screenCx;
    for (final s in _chopHistory) {
      if (s.y < minY) {
        minY = s.y;
        minTime = s.time;
        minX = s.x;
      }
    }

    final double dropY = screenCy - minY;
    final double dropX = (screenCx - minX).abs();
    final double dtChopSec = now.difference(minTime).inMilliseconds / 1000.0;

    // LÊN CÒ (ARMING): Khi tay đang ở vị trí giơ cao ngắm trứng (screenCy <= 0.60)
    // và không đang trong nhịp rơi (dropY <= 0.035)
    if (screenCy <= 0.60 && dropY <= 0.035) {
      _isSlamArmed = true;
    }

    final double rawChopScore = (dropY / 0.08).clamp(0.0, 1.0);
    _smoothChopScore += (rawChopScore - _smoothChopScore) * timedAlpha(0.70, dt);

    bool isChop = false;
    // CỬ CHỈ HẠ TAY XUỐNG ĐẬP HỢP LỆ (DOWNWARD SLAM):
    // 1. Tay đã được "lên cò" (đang ở vị trí giơ cao ngắm trứng)
    // 2. Độ rơi hạ tay xuống dứt khoát >= 0.07 (7% chiều cao khung hình preview)
    // 3. Tốc độ hạ tay dứt khoát: dtChopSec <= 0.28s với vận tốc rơi >= 0.40/s
    // 4. Hướng chuyển động rõ ràng đi xuống (dropY >= dropX * 0.60), không phải lướt ngang
    // 5. Cooldown 350ms giữa các lần đập
    if (_isSlamArmed &&
        dropY >= 0.07 &&
        dtChopSec >= 0.03 &&
        dtChopSec <= 0.28 &&
        (dropY / dtChopSec) >= 0.40 &&
        dropY >= dropX * 0.60 &&
        now.difference(_lastChopTime).inMilliseconds > 350) {
      isChop = true;
      _lastChopTime = now;
      _isSlamArmed = false; // "Hạ cò" ngay lập tức, chống đập lặp lại khi tay còn ở dưới
      _chopHistory.clear();
      _smoothChopScore = 1.0;
    }

    // 2b. ĐỘ GẬP CỔ TAY (Wrist Flex Score 0.0 -> 1.0):
    // Đo độ sụt giảm chiều cao đốt ngón tay VÀ góc gập so với mốc nghỉ tự nhiên (Neutral Baseline)
    final double palmWidth = math.max(dist(5, 17) / h, 0.05);
    final double curElevation = (screenLm[0].dy - knuckleY) / palmWidth;

    if (!_hasSmoothFlex) {
      _neutralPalmElevation = curElevation;
      _smoothFlex = 0.0;
      _hasSmoothFlex = true;
    }

    final double elevationDrop = _neutralPalmElevation - curElevation;
    final double dirDrop = curDirY - _neutralDirY;

    // Khi tay ở tư thế tự nhiên (dù cẳng tay có nghiêng 45°): flexFromElevation ~ 0, flexFromDir ~ 0 -> 0%
    // Khi gập cổ tay xuống (Photo 2): elevationDrop > 0.12, dirDrop > 0.20 -> flexScore -> 1.0 (100%)
    final double flexFromElevation = (elevationDrop / 0.14).clamp(0.0, 1.0);
    final double flexFromDir = (dirDrop / 0.28).clamp(0.0, 1.0);
    final double rawFlexScore = math.max(flexFromElevation, flexFromDir);

    // Phản hồi nhanh (0.65) để khi gập là thanh nhảy ngay tức thì
    _smoothFlex += (rawFlexScore - _smoothFlex) * timedAlpha(0.65, dt);

    // 3. TỰ ĐỘNG HIỆU CHỈNH MỐC TRUNG TÍNH (Vị trí & Vector hướng nghỉ tự nhiên)
    // Chỉ lấy mẫu khi tay ĐỨNG YÊN: tay còn đang di chuyển (vừa bấm nút xong) thì bỏ mẫu, đếm lại.
    // Dùng toạ độ raw (không qua EMA) để mốc không bị kéo lệch về vị trí cũ.
    final bool calibratingNow = _isCalibrating || !_hasHandCalibratedOnce;
    if (calibratingNow) {
      _isCalibrating = true;
      _calibElapsedSec += dt;
      // Ngưỡng "đã nhúc nhích" giữa 2 mẫu: máy nhận diện chậm thì 2 mẫu cách xa hơn, tay rung tự nhiên
      // cũng lệch nhiều hơn => nới ngưỡng theo căn bậc hai thời gian (không thì máy chậm khó cân bằng xong)
      final double moveLimit = 0.025 * math.sqrt(math.max(1.0, dt / kTunedSampleDt));
      final bool moved = _calibrationFrames > 0 &&
          ((rawX - _lastCalibX).abs() > moveLimit || (rawY - _lastCalibY).abs() > moveLimit);
      _lastCalibX = rawX;
      _lastCalibY = rawY;
      // Sau ~2s vẫn rung thì chấp nhận luôn để không kẹt ở trạng thái hiệu chỉnh
      if (moved && _calibElapsedSec < 2.0) {
        _clearCalibSums();
      }
      _calibHandXSum += rawX;
      _calibHandYSum += rawY;
      _calibDirXSum += curDirX;
      _calibDirYSum += curDirY;
      _calibElevationSum += curElevation;
      _calibrationFrames++;
      _calibSampleSec += dt;
      // 10 mẫu đứng yên (~0,33s ở 30 lần/giây); máy chậm: đứng yên đủ 0,33s & ít nhất 4 mẫu là xong
      if (_calibrationFrames >= 10 || (_calibrationFrames >= 4 && _calibSampleSec >= 10 * kTunedSampleDt)) {
        _neutralHandX = _calibHandXSum / _calibrationFrames;
        _neutralHandY = _calibHandYSum / _calibrationFrames;
        _neutralPalmElevation = _calibElevationSum / _calibrationFrames;
        final double dirLen = math.sqrt(_calibDirXSum * _calibDirXSum + _calibDirYSum * _calibDirYSum);
        if (dirLen > 0.001) {
          _neutralDirX = _calibDirXSum / dirLen;
          _neutralDirY = _calibDirYSum / dirLen;
        } else {
          _neutralDirX = 0.0;
          _neutralDirY = -1.0;
        }
        _isCalibrating = false;
        _hasHandCalibratedOnce = true;
        _calibratedHandRotation = _aiHandRotationIndex;
        _clearCalibSums();
        _calibElapsedSec = 0.0;
        // Đưa mọi bộ lọc về đúng tâm để không có "đuôi" trượt sang 1 bên sau khi cân bằng
        _smoothHandX = _neutralHandX;
        _smoothHandY = _neutralHandY;
        _handXFilter.reset(_neutralHandX);
        _handYFilter.reset(_neutralHandY);
        _handTiltFilter.reset(0.0);
        _currentHandTilt = 0.0;
        _steerFilter.reset(0.0);
        _isHandSteeringActive = false;
        _savePreferences();
        notifyListeners();
      }
    }

    // 4. TÍNH ĐỘ LỆCH VÀ ĐIỀU HƯỚNG MƯỢT MÀ (HYBRID TILT & SLIDE)
    // Cùng quy ước với Face mode: giữ nguyên dấu để nghiêng/lướt tay sang TRÁI của người chơi -> TRÁI.
    // Switch TẮT: sign = 1.0 (nghiêng/lướt trái -> TRÁI, phải -> PHẢI)
    // Switch BẬT: sign = -1.0 (đảo chiều)
    final double sign = _invertLean ? -1.0 : 1.0;

    // Tọa độ lướt tay ngang trên màn hình (Screen Reach):
    final double screenSlideX = (_smoothHandX - _neutralHandX);
    final double relativeX = screenSlideX * sign;

    // A. Góc nghiêng bàn tay TƯƠNG ĐỐI so với hướng tay lúc cân bằng.
    // Dùng atan2(cross, dot) giữa 2 vector => luôn = 0° ở tư thế đã cân bằng (dù tay tự nhiên
    // nghiêng 20°), và không bao giờ nhảy -180° <-> +180° khi tay chúc xuống / nằm ngang.
    final double relTiltRaw = _relativeHandTiltDeg(curDirX, curDirY).clamp(-55.0, 55.0);

    final double smoothHandTilt = _handTiltFilter.filter(relTiltRaw, dt);
    _currentHandTilt = smoothHandTilt * sign;

    double normTilt = 0.0;
    if (_currentHandTilt.abs() > 6.0) {
      normTilt = _currentHandTilt.sign * ((_currentHandTilt.abs() - 6.0) / 24.0).clamp(0.0, 1.0);
    }

    // Dynamic Auto-centering: chỉ bù trôi khi tay THỰC SỰ đang nghỉ (gần tâm cả vị trí lẫn góc),
    // để giữ nghiêng/lướt lâu không bị mốc "đuổi theo" làm tay tự trôi về giữa rồi lệch phía kia.
    if (!calibratingNow) {
      final double curXDiff = _smoothHandX - _neutralHandX;
      final bool atRest = curXDiff.abs() < 0.03 && smoothHandTilt.abs() < 5.0;
      if (atRest) {
        final double drift = timedAlpha(0.01, dt);
        _neutralHandX += curXDiff * drift;
        final double curYDiff = _smoothHandY - _neutralHandY;
        if (curYDiff.abs() < 0.05) {
          _neutralHandY += curYDiff * drift;
        }
        _neutralDirX += (curDirX - _neutralDirX) * drift;
        _neutralDirY += (curDirY - _neutralDirY) * drift;
        final double nlen = math.sqrt(_neutralDirX * _neutralDirX + _neutralDirY * _neutralDirY);
        if (nlen > 0.001) {
          _neutralDirX /= nlen;
          _neutralDirY /= nlen;
        }
      }
      // Tự động bù trôi mốc cổ tay thẳng khi tay đang ở trạng thái ngẩng tự nhiên (không gập)
      final double elevDiff = curElevation - _neutralPalmElevation;
      if (elevDiff.abs() < 0.05) {
        _neutralPalmElevation += elevDiff * timedAlpha(0.012, dt);
      }
    }

    // B. Chuẩn hóa vị trí đưa/lướt tay sang trái - phải (Left/Right Reach):
    double normPos = 0.0;
    if (relativeX.abs() > 0.02) {
      normPos = relativeX.sign * ((relativeX.abs() - 0.02) / _handReach).clamp(0.0, 1.0);
    }

    // C. Kết hợp thông minh (Cả đưa tay ngang lẫn nghiêng bàn tay đều đúng chiều 100%):
    double rawSteer;
    if (normPos.abs() >= normTilt.abs()) {
      rawSteer = normPos + (normTilt * 0.35 * (1.0 - normPos.abs()));
    } else {
      rawSteer = normTilt + (normPos * 0.35 * (1.0 - normTilt.abs()));
    }
    rawSteer = rawSteer.clamp(-1.0, 1.0);

    // D. Áp dụng độ nhạy người dùng cấu hình:
    final double steered = (rawSteer * (_handSensitivity / 2.0)).clamp(-1.0, 1.0);

    // E. Áp dụng Vùng chết (Soft Deadzone):
    // Trong khoảng [-deadzone, +deadzone] giữ vững 0.0 tuyệt đối (ở GIỮA hoàn toàn)
    // Ngoài khoảng deadzone tăng đều mượt mà từ 0% đến 100%
    double targetHandX = 0.0;
    if (steered.abs() > _handDeadzone) {
      final double excess = (steered.abs() - _handDeadzone) / (1.0 - _handDeadzone);
      targetHandX = (steered.sign * excess).clamp(-1.0, 1.0);
    }

    // Đang cân bằng: khoá cứng ở GIỮA, không cho nhân vật chạy lung tung theo mốc cũ
    if (calibratingNow) targetHandX = 0.0;

    // F. Bộ lọc chống giật tay (One Euro, lúc đứng yên = EMA 0.35 cũ): mượt mà như vô lăng analog
    final double filteredHandX = _steerFilter.filter(targetHandX, dt);
    final double finalHandX = filteredHandX.abs() < 0.015 ? 0.0 : filteredHandX;

    final double targetHandY = calibratingNow ? 0.0 : ((_smoothHandY - _neutralHandY) * 2.2).clamp(-1.0, 1.0);

    // 5. NẮM ĐẤM: tỉ lệ (đầu ngón -> cổ tay) / (khớp gốc ngón -> cổ tay), bất biến theo khoảng cách
    double ratioSum = 0.0;
    int ratioCount = 0;
    for (final f in const [
      [8, 5],
      [12, 9],
      [16, 13],
      [20, 17],
    ]) {
      final mcp = dist(f[1], 0);
      if (mcp > 1.0) {
        ratioSum += dist(f[0], 0) / mcp;
        ratioCount++;
      }
    }
    final double curlRatio = ratioCount > 0 ? ratioSum / ratioCount : 2.0;
    _currentHandSpan = curlRatio * 100.0;
    // xòe ~1.8-2.1 -> 0 ; nắm ~0.8-1.1 -> 1
    final double rawFist = ((1.62 - curlRatio) / (1.62 - 1.05)).clamp(0.0, 1.0);
    _smoothedFistScore += (rawFist - _smoothedFistScore) * timedAlpha(0.5, dt);

    // Chống rung: điều kiện phải giữ >= 50ms (= 2 khung liên tiếp ở 30 lần/giây). Mỗi mẫu tính bằng
    // khoảng thời gian nó đại diện => máy chậm (1 mẫu ~80ms) nắm tay là ăn ngay, không phải chờ thêm 1 mẫu.
    const double fistHoldSec = 0.05;
    final double activateThresh = _fistThreshold;
    final double releaseThresh = _fistThreshold * 0.68;
    if (!_isHandFistState) {
      if (_smoothedFistScore >= activateThresh) {
        _fistActivateHeld += dt;
        if (_fistActivateHeld >= fistHoldSec) _isHandFistState = true;
      } else {
        _fistActivateHeld = 0.0;
      }
    } else {
      if (_smoothedFistScore <= releaseThresh) {
        _fistReleaseHeld += dt;
        if (_fistReleaseHeld >= fistHoldSec) {
          _isHandFistState = false;
          _fistActivateHeld = 0.0;
          _fistReleaseHeld = 0.0;
        }
      } else {
        _fistReleaseHeld = 0.0;
      }
    }
    final bool isFist = _isHandFistState;

    // Hysteresis: vào TRÁI/PHẢI khi > 0.08, chỉ nhả về GIỮA khi < 0.03 -> không chớp trái/phải ở ranh giới
    final double steerEnter = 0.08;
    final double steerRelease = 0.03;
    if (_isHandSteeringActive) {
      if (finalHandX.abs() < steerRelease) _isHandSteeringActive = false;
    } else if (finalHandX.abs() > steerEnter) {
      _isHandSteeringActive = true;
    }
    TiltDirection tilt = TiltDirection.neutral;
    if (_isHandSteeringActive) {
      tilt = finalHandX < 0 ? TiltDirection.left : TiltDirection.right;
    }

    // =========================================================================
    // XỬ LÝ 2 BÀN TAY (DUAL HAND PROCESSING)
    // =========================================================================
    HandData leftHandData = HandData.initial;
    HandData rightHandData = HandData.initial;
    double clapDist = 1.0;
    bool isClap = false;
    final int handsCount = hands.length >= 2 ? 2 : 1;

    if (hands.length >= 2) {
      final lmA = hands[0];
      final lmB = hands[1];
      final sLmA = List<Offset>.generate(21, (i) => _landmarkToScreen(lmA[i].dx, lmA[i].dy));
      final sLmB = List<Offset>.generate(21, (i) => _landmarkToScreen(lmB[i].dx, lmB[i].dy));

      double cxA = 0.0, cyA = 0.0;
      for (final i in const [0, 5, 9, 13, 17]) {
        cxA += sLmA[i].dx;
        cyA += sLmA[i].dy;
      }
      cxA /= 5.0;
      cyA /= 5.0;

      double cxB = 0.0, cyB = 0.0;
      for (final i in const [0, 5, 9, 13, 17]) {
        cxB += sLmB[i].dx;
        cyB += sLmB[i].dy;
      }
      cxB /= 5.0;
      cyB /= 5.0;

      final bool aIsLeft = cxA < cxB;
      final sLmLeft = aIsLeft ? sLmA : sLmB;
      final sLmRight = aIsLeft ? sLmB : sLmA;
      final double leftCx = aIsLeft ? cxA : cxB;
      final double leftCy = aIsLeft ? cyA : cyB;
      final double rightCx = aIsLeft ? cxB : cxA;
      final double rightCy = aIsLeft ? cyB : cyA;

      leftHandData = _extractHandData(sLmLeft, leftCx, leftCy, w, h, dt, isLeft: true);
      rightHandData = _extractHandData(sLmRight, rightCx, rightCy, w, h, dt, isLeft: false);

      final double dx = (rightCx - leftCx);
      final double dy = (rightCy - leftCy);
      clapDist = math.sqrt(dx * dx + dy * dy);

      if (clapDist > 0.40) {
        _isClapArmed = true;
      }
      if (_isClapArmed && clapDist < _clapThreshold && now.difference(_lastClapTime).inMilliseconds > 350) {
        isClap = true;
        _isClapArmed = false;
        _lastClapTime = now;
      }
    } else {
      if (screenCx < 0.5) {
        leftHandData = _extractHandData(screenLm, screenCx, screenCy, w, h, dt, isLeft: true);
        rightHandData = HandData.initial;
        _resetDualHandFilters(right: true);
      } else {
        rightHandData = _extractHandData(screenLm, screenCx, screenCy, w, h, dt, isLeft: false);
        leftHandData = HandData.initial;
        _resetDualHandFilters(left: true);
      }
      _isClapArmed = false;
    }

    _state = MotionState(
      inputMode: MotionInputMode.hand,
      handDetected: true,
      faceDetected: false,
      handX: finalHandX,
      handY: targetHandY,
      handVisualX: visualX,
      handVisualY: visualY,
      isHandFist: isFist,
      handWristFlex: _smoothFlex,
      isChopTriggered: isChop,
      chopScore: _smoothChopScore,
      isHandOpen: !isFist,
      handConfidence: 1.0,
      handFistScore: _smoothedFistScore,
      handsCount: handsCount,
      leftHand: leftHandData,
      rightHand: rightHandData,
      clapDistance: clapDist,
      isClapTriggered: isClap,
      tiltDirection: tilt,
      steerX: finalHandX,
      relativeRoll: finalHandX * 22.0,
      relativeYaw: finalHandX * 15.0,
      relativePitch: -targetHandY * 15.0,
      isChomping: isFist,
      relativeMouth: isFist ? 0.35 : 0.0,
      fps: _handFps,
      latencyMs: frame.latencyMs,
      timestamp: now,
    );
    notifyListeners();
  }

  HandData _extractHandData(
    List<Offset> sLm,
    double screenCx,
    double screenCy,
    double w,
    double h,
    double dt, {
    required bool isLeft,
  }) {
    double dist(int a, int b) {
      final dx = (sLm[a].dx - sLm[b].dx) * w;
      final dy = (sLm[a].dy - sLm[b].dy) * h;
      return math.sqrt(dx * dx + dy * dy);
    }

    double ratioSum = 0.0;
    int ratioCount = 0;
    for (final f in const [
      [8, 5],
      [12, 9],
      [16, 13],
      [20, 17],
    ]) {
      final mcp = dist(f[1], 0);
      if (mcp > 1.0) {
        ratioSum += dist(f[0], 0) / mcp;
        ratioCount++;
      }
    }
    final double curlRatio = ratioCount > 0 ? ratioSum / ratioCount : 2.0;
    final double rawFist = ((1.62 - curlRatio) / (1.62 - 1.05)).clamp(0.0, 1.0);

    final OneEuroFilter xFilter = isLeft ? _leftXFilter : _rightXFilter;
    final OneEuroFilter yFilter = isLeft ? _leftYFilter : _rightYFilter;
    final bool fresh = !xFilter.hasValue; // tay này vừa xuất hiện lại: dùng luôn giá trị thật
    final double smoothX = xFilter.filter(screenCx - 0.5, dt);
    final double smoothY = yFilter.filter(screenCy - 0.5, dt);
    final double fistAlpha = fresh ? 1.0 : timedAlpha(0.5, dt);
    final double fistScore;

    if (isLeft) {
      _smoothLeftFist += (rawFist - _smoothLeftFist) * fistAlpha;
      fistScore = _smoothLeftFist;
      _isLeftFist = fistScore >= _fistThreshold;
    } else {
      _smoothRightFist += (rawFist - _smoothRightFist) * fistAlpha;
      fistScore = _smoothRightFist;
      _isRightFist = fistScore >= _fistThreshold;
    }

    final double visualX = (smoothX * 2.0).clamp(-1.0, 1.0);
    final double visualY = (smoothY * 2.0).clamp(-1.0, 1.0);
    final double normX = (smoothX * 2.5).clamp(-1.0, 1.0);
    final double normY = (smoothY * 2.5).clamp(-1.0, 1.0);

    return HandData(
      detected: true,
      x: normX,
      y: normY,
      visualX: visualX,
      visualY: visualY,
      isFist: isLeft ? _isLeftFist : _isRightFist,
      fistScore: fistScore,
      isOpen: fistScore < _fistThreshold * 0.7,
    );
  }

  /// Góc (độ) có dấu từ hướng tay lúc cân bằng tới hướng tay hiện tại, dương = nghiêng sang PHẢI màn hình.
  double _relativeHandTiltDeg(double dirX, double dirY) {
    final double cross = _neutralDirX * dirY - _neutralDirY * dirX;
    final double dot = _neutralDirX * dirX + _neutralDirY * dirY;
    return math.atan2(cross, dot) * 180.0 / math.pi;
  }

  /// Quên vị trí đã lọc của tay trái / phải (tay đó vừa mất): lần thấy lại dùng luôn vị trí thật
  void _resetDualHandFilters({bool left = false, bool right = false}) {
    if (left) {
      _leftXFilter.reset();
      _leftYFilter.reset();
    }
    if (right) {
      _rightXFilter.reset();
      _rightYFilter.reset();
    }
  }

  void _clearCalibSums() {
    _calibHandXSum = 0.0;
    _calibHandYSum = 0.0;
    _calibDirXSum = 0.0;
    _calibDirYSum = 0.0;
    _calibElevationSum = 0.0;
    _calibrationFrames = 0;
    _calibSampleSec = 0.0;
  }

  void _resetHandCalibration() {
    _isCalibrating = true;
    _hasHandCalibratedOnce = false;
    _calibElapsedSec = 0.0;
    _clearCalibSums();
    _hasSmoothFlex = false;
    _handTiltFilter.reset();
    _steerFilter.reset(0.0);
    _currentHandTilt = 0.0;
    _isHandSteeringActive = false;
  }

  void calibrateNeutral() {
    if (!_cameraAvailable || !_backend.isReady) {
      _isCalibrating = false;
      return;
    }
    _isCalibrating = true;
    _calibrationFrames = 0;
    _calibSampleSec = 0.0;
    if (_inputMode == MotionInputMode.hand) {
      _resetHandCalibration();
    } else {
      _hasFaceCalibratedOnce = false;
      _calibRollSum = 0.0;
      _calibMouthSum = 0.0;
      _calibYawSum = 0.0;
      _calibPitchSum = 0.0;
    }
    notifyListeners();
  }

  void simulateTilt(TiltDirection direction) {
    double relRoll = 0.0;
    if (direction == TiltDirection.left) relRoll = -20.0;
    if (direction == TiltDirection.right) relRoll = 20.0;

    _state = _state.copyWith(
      tiltDirection: direction,
      steerX: relRoll / 20.0,
      relativeRoll: relRoll,
      faceDetected: true,
      handDetected: true,
      timestamp: DateTime.now(),
    );
    notifyListeners();
  }

  void simulateChomp(bool active) {
    _state = _state.copyWith(
      isChomping: active,
      isHandFist: active,
      relativeMouth: active ? 0.28 : 0.0,
      faceDetected: true,
      handDetected: true,
      timestamp: DateTime.now(),
    );
    notifyListeners();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _neutralRoll = prefs.getDouble('neutral_roll') ?? 0.0;
    _neutralYaw = prefs.getDouble('neutral_yaw') ?? 0.0;
    _neutralPitch = prefs.getDouble('neutral_pitch') ?? 0.0;
    final savedBaseline = prefs.getDouble('baseline_mouth');
    if (savedBaseline != null && savedBaseline > 0.08) {
      _baselineMouth = savedBaseline;
    }

    _invertLean = false; // Mặc định tắt: nghiêng trái sang trái, nghiêng phải sang phải
    _showTouchControls = prefs.getBool('show_touch_controls') ?? false;
    _showCameraPip = prefs.getBool('show_camera_pip') ?? true;
    _showCameraStats = prefs.getBool('show_camera_stats') ?? false;
    _cameraRotationQuarterTurns = prefs.getInt('camera_rotation_quarter_turns') ?? 0;
    _aiRotationOffset = prefs.getInt('ai_rotation_offset') ?? 0;
    _aiHandRotationIndex = prefs.getInt('ai_hand_rotation_index') ?? 0;
    _neutralDirX = prefs.getDouble('neutral_dir_x') ?? 0.0;
    _neutralDirY = prefs.getDouble('neutral_dir_y') ?? -1.0;
    final savedMode = prefs.getString('motion_input_mode');
    if (savedMode == 'hand') {
      _inputMode = MotionInputMode.hand;
    } else {
      _inputMode = MotionInputMode.face;
    }
    _tiltThreshold = prefs.getDouble('tilt_threshold') ?? MotionDefaults.defaultTiltThreshold;
    _handDeadzone = prefs.getDouble('hand_deadzone') ?? 0.18;
    _handSensitivity = prefs.getDouble('hand_sensitivity') ?? 2.4;
    _fistThreshold = prefs.getDouble('fist_threshold') ?? 0.45;
    _clapThreshold = prefs.getDouble('clap_threshold') ?? 0.20;
    _neutralHandX = prefs.getDouble('neutral_hand_x') ?? 0.0;
    _neutralHandY = prefs.getDouble('neutral_hand_y') ?? 0.0;
    final savedTilt = prefs.getDouble('neutral_hand_tilt') ?? 0.0;
    // Nếu mốc cũ bị kẹt ở -65 độ do lỗi xoay trước đây, reset lại 0.0 để cân bằng chuẩn
    _neutralHandTilt = (savedTilt.abs() > 45.0) ? 0.0 : savedTilt;
    _mouthOpenThreshold = prefs.getDouble('mouth_threshold') ?? MotionDefaults.defaultMouthOpenThreshold;
    _tiltRelease = _tiltThreshold * 0.5;
    _mouthCloseThreshold = _mouthOpenThreshold * 0.55;

    // Đánh dấu đã cân bằng riêng biệt cho Face và Hand
    _hasFaceCalibratedOnce = prefs.containsKey('neutral_roll');
    _hasHandCalibratedOnce = prefs.containsKey('neutral_hand_tilt') && prefs.containsKey('neutral_hand_x');
    _calibratedHandRotation = _hasHandCalibratedOnce ? _aiHandRotationIndex : -1;
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('neutral_roll', _neutralRoll);
    await prefs.setDouble('neutral_yaw', _neutralYaw);
    await prefs.setDouble('neutral_pitch', _neutralPitch);
    await prefs.setDouble('baseline_mouth', _baselineMouth);
    await prefs.setDouble('hand_deadzone', _handDeadzone);
    await prefs.setDouble('hand_sensitivity', _handSensitivity);
    await prefs.setDouble('fist_threshold', _fistThreshold);
    await prefs.setDouble('clap_threshold', _clapThreshold);
    await prefs.setDouble('neutral_hand_x', _neutralHandX);
    await prefs.setDouble('neutral_hand_y', _neutralHandY);
    await prefs.setDouble('neutral_hand_tilt', _neutralHandTilt);
    await prefs.setBool('invert_lean_switch', _invertLean);
    await prefs.setBool('show_touch_controls', _showTouchControls);
    await prefs.setBool('show_camera_pip', _showCameraPip);
    await prefs.setBool('show_camera_stats', _showCameraStats);
    await prefs.setInt('camera_rotation_quarter_turns', _cameraRotationQuarterTurns);
    await prefs.setInt('ai_rotation_offset', _aiRotationOffset);
    await prefs.setInt('ai_hand_rotation_index', _aiHandRotationIndex);
    await prefs.setDouble('neutral_dir_x', _neutralDirX);
    await prefs.setDouble('neutral_dir_y', _neutralDirY);
    await prefs.setString('motion_input_mode', _inputMode == MotionInputMode.hand ? 'hand' : 'face');
    await prefs.setDouble('tilt_threshold', _tiltThreshold);
    await prefs.setDouble('mouth_threshold', _mouthOpenThreshold);
  }

  @override
  void dispose() {
    _backend.dispose();
    super.dispose();
  }
}

class _HandChopSample {
  final DateTime time;
  final double x;
  final double y;
  _HandChopSample(this.time, this.x, this.y);
}
