enum TiltDirection {
  neutral,
  left,
  right,
}

enum MotionInputMode {
  face, // Điều khiển bằng cử chỉ khuôn mặt (Nghiêng đầu, Há miệng, Quay mặt)
  hand, // Điều khiển bằng cử chỉ bàn tay (Lướt tay, Nắm tay, Giơ tay)
}

class HandData {
  final bool detected;
  final double x; // -1.0 (Trái) -> 1.0 (Phải)
  final double y; // -1.0 (Trên) -> 1.0 (Dưới)
  final double visualX; // -1.0 -> 1.0 toạ độ hiển thị màn hình preview
  final double visualY; // -1.0 -> 1.0
  final bool isFist;
  final double fistScore; // 0.0 (Xòe) -> 1.0 (Nắm)
  final bool isDownSlam; // Cú hạ tay/đập trống
  final double slamScore;
  final double wristFlex;
  final bool isOpen;

  const HandData({
    this.detected = false,
    this.x = 0.0,
    this.y = 0.0,
    this.visualX = 0.0,
    this.visualY = 0.0,
    this.isFist = false,
    this.fistScore = 0.0,
    this.isDownSlam = false,
    this.slamScore = 0.0,
    this.wristFlex = 0.0,
    this.isOpen = true,
  });

  static const initial = HandData();

  HandData copyWith({
    bool? detected,
    double? x,
    double? y,
    double? visualX,
    double? visualY,
    bool? isFist,
    double? fistScore,
    bool? isDownSlam,
    double? slamScore,
    double? wristFlex,
    bool? isOpen,
  }) {
    return HandData(
      detected: detected ?? this.detected,
      x: x ?? this.x,
      y: y ?? this.y,
      visualX: visualX ?? this.visualX,
      visualY: visualY ?? this.visualY,
      isFist: isFist ?? this.isFist,
      fistScore: fistScore ?? this.fistScore,
      isDownSlam: isDownSlam ?? this.isDownSlam,
      slamScore: slamScore ?? this.slamScore,
      wristFlex: wristFlex ?? this.wristFlex,
      isOpen: isOpen ?? this.isOpen,
    );
  }
}

class MotionState {
  final MotionInputMode inputMode;

  // ==========================
  // 1. CỬ CHỈ KHUÔN MẶT (FACE)
  // ==========================
  final double rawRoll;
  final double smoothRoll;
  final double relativeRoll;

  final double rawYaw;
  final double smoothYaw;
  final double relativeYaw;

  final double rawPitch;
  final double smoothPitch;
  final double relativePitch;

  final double smileProb;
  final double leftEyeOpen;
  final double rightEyeOpen;
  final bool isWinking;

  final double rawMouth;
  final double smoothMouth;
  final double relativeMouth;
  final bool isChomping;

  final bool faceDetected;
  final double faceVisualX; // Tọa độ trực quan tâm khuôn mặt trên màn hình preview (-1.0 -> 1.0)
  final double faceVisualY; // Tọa độ trực quan tâm khuôn mặt trên màn hình preview (-1.0 -> 1.0)

  // ==========================
  // 2. CỬ CHỈ BÀN TAY (HAND - ĐƠN TAY & DUAL HAND)
  // ==========================
  // Legacy fields (tương thích 100% với các game 1 tay cũ):
  final bool handDetected;
  final double handX; // -1.0 (Trái) -> 1.0 (Phải). 0.0 là trung tâm
  final double handY; // -1.0 (Trên) -> 1.0 (Dưới)
  final double handVisualX; // Tọa độ trực quan bàn tay trên màn hình (-1.0 -> 1.0)
  final double handVisualY; // Tọa độ trực quan bàn tay trên màn hình (-1.0 -> 1.0)
  final bool isHandFist;
  final double handWristFlex;
  final bool isChopTriggered; // Cú chặt bàn tay xuống (Karate Chop / Downward Slam)
  final double chopScore; // 0.0 -> 1.0
  final bool isHandOpen; // Xòe bàn tay
  final double handConfidence;
  final double handFistScore; // 0.0 -> 1.0

  // Dual-Hand fields (chuyên biệt cho game 2 tay):
  final int handsCount; // Số lượng bàn tay phát hiện (0, 1, 2)
  final HandData leftHand; // Bàn tay bên trái màn hình
  final HandData rightHand; // Bàn tay bên phải màn hình
  final double clapDistance; // Khoảng cách giữa 2 lòng bàn tay (0.0 -> 2.0)
  final bool isClapTriggered; // Cử chỉ Vỗ tay (Clap event)

  // ==========================
  // 3. THÔNG SỐ CHUNG
  // ==========================
  final TiltDirection tiltDirection;
  /// Giá trị điều khiển TRÁI/PHẢI thống nhất cho mọi game, cả Face lẫn Hand:
  /// -1.0 = hết cỡ TRÁI (theo góc nhìn người chơi), 0.0 = GIỮA, +1.0 = hết cỡ PHẢI.
  /// Cùng chiều với tiltDirection và thước đo trong Hiệu chỉnh. Game nên dùng giá trị này.
  final double steerX;
  final double fps;
  final int latencyMs;
  final DateTime timestamp;

  const MotionState({
    this.inputMode = MotionInputMode.face,
    this.rawRoll = 0.0,
    this.smoothRoll = 0.0,
    this.relativeRoll = 0.0,
    this.rawYaw = 0.0,
    this.smoothYaw = 0.0,
    this.relativeYaw = 0.0,
    this.rawPitch = 0.0,
    this.smoothPitch = 0.0,
    this.relativePitch = 0.0,
    this.smileProb = 0.0,
    this.leftEyeOpen = 1.0,
    this.rightEyeOpen = 1.0,
    this.isWinking = false,
    this.rawMouth = 0.0,
    this.smoothMouth = 0.0,
    this.relativeMouth = 0.0,
    this.isChomping = false,
    this.faceDetected = false,
    this.faceVisualX = 0.0,
    this.faceVisualY = 0.0,
    this.handDetected = false,
    this.handX = 0.0,
    this.handY = 0.0,
    this.handVisualX = 0.0,
    this.handVisualY = 0.0,
    this.isHandFist = false,
    this.handWristFlex = 0.0,
    this.isChopTriggered = false,
    this.chopScore = 0.0,
    this.isHandOpen = true,
    this.handConfidence = 0.0,
    this.handFistScore = 0.0,
    this.handsCount = 0,
    this.leftHand = HandData.initial,
    this.rightHand = HandData.initial,
    this.clapDistance = 1.0,
    this.isClapTriggered = false,
    this.tiltDirection = TiltDirection.neutral,
    this.steerX = 0.0,
    this.fps = 0.0,
    this.latencyMs = 0,
    required this.timestamp,
  });

  factory MotionState.initial() => MotionState(
        timestamp: DateTime.now(),
      );

  MotionState copyWith({
    MotionInputMode? inputMode,
    double? rawRoll,
    double? smoothRoll,
    double? relativeRoll,
    double? rawYaw,
    double? smoothYaw,
    double? relativeYaw,
    double? rawPitch,
    double? smoothPitch,
    double? relativePitch,
    double? smileProb,
    double? leftEyeOpen,
    double? rightEyeOpen,
    bool? isWinking,
    double? rawMouth,
    double? smoothMouth,
    double? relativeMouth,
    bool? isChomping,
    bool? faceDetected,
    double? faceVisualX,
    double? faceVisualY,
    bool? handDetected,
    double? handX,
    double? handY,
    double? handVisualX,
    double? handVisualY,
    bool? isHandFist,
    double? handWristFlex,
    bool? isChopTriggered,
    double? chopScore,
    bool? isHandOpen,
    double? handConfidence,
    double? handFistScore,
    int? handsCount,
    HandData? leftHand,
    HandData? rightHand,
    double? clapDistance,
    bool? isClapTriggered,
    TiltDirection? tiltDirection,
    double? steerX,
    double? fps,
    int? latencyMs,
    DateTime? timestamp,
  }) {
    return MotionState(
      inputMode: inputMode ?? this.inputMode,
      rawRoll: rawRoll ?? this.rawRoll,
      smoothRoll: smoothRoll ?? this.smoothRoll,
      relativeRoll: relativeRoll ?? this.relativeRoll,
      rawYaw: rawYaw ?? this.rawYaw,
      smoothYaw: smoothYaw ?? this.smoothYaw,
      relativeYaw: relativeYaw ?? this.relativeYaw,
      rawPitch: rawPitch ?? this.rawPitch,
      smoothPitch: smoothPitch ?? this.smoothPitch,
      relativePitch: relativePitch ?? this.relativePitch,
      smileProb: smileProb ?? this.smileProb,
      leftEyeOpen: leftEyeOpen ?? this.leftEyeOpen,
      rightEyeOpen: rightEyeOpen ?? this.rightEyeOpen,
      isWinking: isWinking ?? this.isWinking,
      rawMouth: rawMouth ?? this.rawMouth,
      smoothMouth: smoothMouth ?? this.smoothMouth,
      relativeMouth: relativeMouth ?? this.relativeMouth,
      isChomping: isChomping ?? this.isChomping,
      faceDetected: faceDetected ?? this.faceDetected,
      faceVisualX: faceVisualX ?? this.faceVisualX,
      faceVisualY: faceVisualY ?? this.faceVisualY,
      handDetected: handDetected ?? this.handDetected,
      handX: handX ?? this.handX,
      handY: handY ?? this.handY,
      handVisualX: handVisualX ?? this.handVisualX,
      handVisualY: handVisualY ?? this.handVisualY,
      isHandFist: isHandFist ?? this.isHandFist,
      handWristFlex: handWristFlex ?? this.handWristFlex,
      isChopTriggered: isChopTriggered ?? this.isChopTriggered,
      chopScore: chopScore ?? this.chopScore,
      isHandOpen: isHandOpen ?? this.isHandOpen,
      handConfidence: handConfidence ?? this.handConfidence,
      handFistScore: handFistScore ?? this.handFistScore,
      handsCount: handsCount ?? this.handsCount,
      leftHand: leftHand ?? this.leftHand,
      rightHand: rightHand ?? this.rightHand,
      clapDistance: clapDistance ?? this.clapDistance,
      isClapTriggered: isClapTriggered ?? this.isClapTriggered,
      tiltDirection: tiltDirection ?? this.tiltDirection,
      steerX: steerX ?? this.steerX,
      fps: fps ?? this.fps,
      latencyMs: latencyMs ?? this.latencyMs,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
