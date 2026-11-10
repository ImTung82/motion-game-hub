import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../motion/face_motion_controller.dart';
import '../../motion/motion_state.dart';

class CameraPipOverlay extends StatefulWidget {
  final FaceMotionController motionController;
  final VoidCallback onCalibrate;
  final double? top;
  final double? bottom;
  final double? left;
  final double? right;
  final bool showNodMode;

  const CameraPipOverlay({
    super.key,
    required this.motionController,
    required this.onCalibrate,
    this.top,
    this.bottom,
    this.left,
    this.right,
    this.showNodMode = false,
  });

  @override
  State<CameraPipOverlay> createState() => _CameraPipOverlayState();
}

class _CameraPipOverlayState extends State<CameraPipOverlay> {
  bool _isCollapsed = false;
  bool _isLargePiP = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.motionController,
      builder: (context, _) {
        final ctrl = widget.motionController;
        if (!ctrl.showCameraPip) return const SizedBox.shrink();

        final state = ctrl.state;
        final bool hasCustomPos = widget.top != null || widget.bottom != null || widget.left != null || widget.right != null;
        final double? posTop = hasCustomPos ? widget.top : 10.0;
        final double? posRight = hasCustomPos ? widget.right : 12.0;
        final double? posBottom = widget.bottom;
        final double? posLeft = widget.left;
        final bool isHandMode = ctrl.inputMode == MotionInputMode.hand;
        final bool isDetected = isHandMode ? state.handDetected : state.faceDetected;
        final bool isNodTriggered = state.isNodding;
        final bool isActionTriggered = isHandMode
        ? state.isHandFist
        : (widget.showNodMode ? isNodTriggered : state.isChomping);
        final bool isRotated90or270 = ctrl.cameraRotationQuarterTurns % 2 == 1;

        // Chuẩn tỉ lệ 16:9 Widescreen cho PiP
        final double pipWidth = _isLargePiP ? 260.0 : (isHandMode ? 210.0 : 170.0);
        final double previewHeight = pipWidth / (16.0 / 9.0);

        if (_isCollapsed) {
          return Positioned(
            top: posTop != null ? posTop + 2.0 : null,
            bottom: posBottom,
            left: posLeft,
            right: posRight,
            child: GestureDetector(
              onTap: () => setState(() => _isCollapsed = false),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: GameColors.surface.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDetected ? GameColors.neonGreen : Colors.white24,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isHandMode
                          ? (isDetected ? Icons.pan_tool : Icons.front_hand_outlined)
                          : (isDetected ? Icons.face : Icons.face_retouching_off),
                      size: 14,
                      color: isDetected ? GameColors.neonGreen : Colors.redAccent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isHandMode
                          ? (isDetected ? 'Hand OK' : 'No hand')
                          : (isDetected ? 'Face OK' : 'No face'),
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.open_in_full, size: 10, color: Colors.white70),
                  ],
                ),
              ),
            ),
          );
        }

        return Positioned(
          top: posTop,
          bottom: posBottom,
          left: posLeft,
          right: posRight,
          child: Container(
            width: pipWidth,
            decoration: BoxDecoration(
              color: GameColors.surface.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isActionTriggered
                    ? GameColors.neonGreen
                    : (state.tiltDirection != TiltDirection.neutral
                        ? GameColors.neonCyan
                        : (isDetected ? GameColors.neonCyan.withValues(alpha: 0.5) : Colors.redAccent.withValues(alpha: 0.5))),
                width: 1.6,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isActionTriggered ? GameColors.neonGreen : GameColors.neonCyan).withValues(alpha: 0.25),
                  blurRadius: 10,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    color: Colors.black45,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDetected ? GameColors.neonGreen : Colors.redAccent,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isDetected
                                  ? '${state.fps.toStringAsFixed(0)} FPS (${isHandMode ? "HAND" : "FACE"})'
                                  : (isHandMode ? 'Finding hand...' : 'Finding face...'),
                              style: const TextStyle(color: Colors.white70, fontSize: 8.5, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            // Nút ẩn/hiện thanh thông số (mặc định ẩn)
                            GestureDetector(
                              onTap: () => ctrl.showCameraStats = !ctrl.showCameraStats,
                              child: Icon(
                                Icons.insights_rounded,
                                size: 13,
                                color: ctrl.showCameraStats ? GameColors.neonGreen : Colors.white38,
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Nút chuyển kích thước PiP (Thu nhỏ / Phóng to)
                            GestureDetector(
                              onTap: () => setState(() => _isLargePiP = !_isLargePiP),
                              child: Icon(
                                _isLargePiP ? Icons.photo_size_select_small : Icons.aspect_ratio,
                                size: 13,
                                color: GameColors.neonCyan,
                              ),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: widget.onCalibrate,
                              child: const Icon(Icons.refresh, size: 14, color: GameColors.neonYellow),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () => setState(() => _isCollapsed = true),
                              child: const Icon(Icons.close_fullscreen, size: 12, color: Colors.white70),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () {
                                widget.motionController.showCameraPip = false;
                              },
                              child: const Icon(Icons.videocam_off_rounded, size: 13, color: Colors.white70),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Khung camera 16:9 Widescreen không viền đen
                  SizedBox(
                    height: previewHeight,
                    width: pipWidth,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final rawSize = ctrl.previewSize;
                        final childW = isRotated90or270
                            ? (rawSize?.height ?? constraints.maxHeight)
                            : (rawSize?.width ?? constraints.maxWidth);
                        final childH = isRotated90or270
                            ? (rawSize?.width ?? constraints.maxWidth)
                            : (rawSize?.height ?? constraints.maxHeight);

                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            // Camera Preview tràn viền 16:9
                            if (ctrl.hasPreview)
                              FittedBox(
                                fit: BoxFit.cover,
                                child: SizedBox(
                                  width: childW,
                                  height: childH,
                                  child: RotatedBox(
                                    quarterTurns: ctrl.cameraRotationQuarterTurns,
                                    child: ctrl.buildPreview(),
                                  ),
                                ),
                              )
                            else
                              Container(
                                color: Colors.black87,
                                child: const Center(
                                  child: Icon(Icons.videocam_off, color: Colors.white30, size: 24),
                                ),
                              ),

                            if (ctrl.isCalibrating)
                              Container(
                                color: Colors.black54,
                                child: const Center(
                                  child: Text(
                                    'Calibrating...',
                                    style: TextStyle(color: GameColors.neonYellow, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              )
                            else if (isHandMode && state.handDetected) ...[
                              if (state.handsCount >= 2) ...[
                                // Reticle Tay Trái (Neon Cyan)
                                if (state.leftHand.detected)
                                  Align(
                                    alignment: Alignment(state.leftHand.visualX.clamp(-1.0, 1.0), state.leftHand.visualY.clamp(-1.0, 1.0)),
                                    child: Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: state.leftHand.isFist ? GameColors.neonGreen : GameColors.neonCyan,
                                          width: 2.2,
                                        ),
                                        color: (state.leftHand.isFist ? GameColors.neonGreen : GameColors.neonCyan).withValues(alpha: 0.25),
                                      ),
                                      child: Center(
                                        child: Icon(
                                          state.leftHand.isFist ? Icons.front_hand : Icons.pan_tool,
                                          size: 16,
                                          color: state.leftHand.isFist ? GameColors.neonGreen : Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                // Reticle Tay Phải (Neon Pink)
                                if (state.rightHand.detected)
                                  Align(
                                    alignment: Alignment(state.rightHand.visualX.clamp(-1.0, 1.0), state.rightHand.visualY.clamp(-1.0, 1.0)),
                                    child: Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: state.rightHand.isFist ? GameColors.neonGreen : GameColors.neonPink,
                                          width: 2.2,
                                        ),
                                        color: (state.rightHand.isFist ? GameColors.neonGreen : GameColors.neonPink).withValues(alpha: 0.25),
                                      ),
                                      child: Center(
                                        child: Icon(
                                          state.rightHand.isFist ? Icons.front_hand : Icons.pan_tool,
                                          size: 16,
                                          color: state.rightHand.isFist ? GameColors.neonGreen : Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                // Hiệu ứng Vỗ tay (Clap flash)
                                if (state.isClapTriggered)
                                  Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: GameColors.neonYellow,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Text('👏 CLAP!', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 9)),
                                    ),
                                  ),
                              ] else ...[
                                // 1 tay duy nhất (Single Hand Reticle)
                                Align(
                                  alignment: Alignment(state.handVisualX.clamp(-1.0, 1.0), state.handVisualY.clamp(-1.0, 1.0)),
                                  child: Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: state.isHandFist ? GameColors.neonGreen : GameColors.neonCyan,
                                        width: 2.2,
                                      ),
                                      color: (state.isHandFist ? GameColors.neonGreen : GameColors.neonCyan).withValues(alpha: 0.25),
                                    ),
                                    child: Center(
                                      child: Icon(
                                        state.isHandFist ? Icons.front_hand : Icons.pan_tool,
                                        size: 18,
                                        color: state.isHandFist ? GameColors.neonGreen : Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ]
                            else if (!isHandMode && state.faceDetected)
                              Align(
                                alignment: Alignment(
                                  state.faceVisualX.clamp(-1.0, 1.0),
                                  state.faceVisualY.clamp(-1.0, 1.0),
                                ),
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: state.isChomping ? GameColors.neonGreen : GameColors.neonCyan,
                                      width: 2.0,
                                    ),
                                    color: (state.isChomping ? GameColors.neonGreen : GameColors.neonCyan).withValues(alpha: 0.2),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      state.isChomping ? Icons.sentiment_very_satisfied : Icons.face,
                                      size: 18,
                                      color: state.isChomping ? GameColors.neonGreen : Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),

                  // Thanh thông số dưới đáy (chỉ hiện khi bật nút 📊)
                  if (ctrl.showCameraStats)
                  Container(
                    padding: const EdgeInsets.all(5),
                    color: Colors.black38,
                    child: isHandMode
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  const Text('Hand position:', style: TextStyle(color: Colors.white60, fontSize: 8)),
                                  const Spacer(),
                                  Text(
                                    state.handX < -ctrl.handDeadzone
                                        ? 'LEFT (${(state.handX * 100).toInt()}%)'
                                        : (state.handX > ctrl.handDeadzone
                                            ? 'RIGHT (+${(state.handX * 100).toInt()}%)'
                                            : 'CENTER (0%)'),
                                    style: TextStyle(
                                      color: state.handX.abs() > ctrl.handDeadzone ? GameColors.neonCyan : Colors.white70,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              _buildHandBar(state.handX),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Text('Fist smash:', style: TextStyle(color: Colors.white60, fontSize: 8)),
                                  const Spacer(),
                                  Text(
                                    state.isHandFist
                                        ? 'SMASH! (FIST)'
                                        : (state.isHandOpen ? 'OPEN HAND (AIM)' : 'FIST: ${(state.handFistScore * 100).toInt()}%'),
                                    style: TextStyle(
                                      color: state.isHandFist ? GameColors.neonGreen : Colors.white70,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              _buildFistBar(state.handFistScore, state.isHandFist),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  const Text('Tilt:', style: TextStyle(color: Colors.white60, fontSize: 8)),
                                  const Spacer(),
                                  Text(
                                    state.tiltDirection == TiltDirection.left
                                        ? 'LEFT (${state.relativeRoll.toStringAsFixed(1)}°)'
                                        : (state.tiltDirection == TiltDirection.right
                                            ? 'RIGHT (${state.relativeRoll.toStringAsFixed(1)}°)'
                                            : '${state.relativeRoll.toStringAsFixed(1)}°'),
                                    style: TextStyle(
                                      color: state.tiltDirection != TiltDirection.neutral
                                          ? GameColors.neonCyan
                                          : Colors.white70,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              _buildTiltBar(state.relativeRoll, ctrl.tiltThreshold, state.tiltDirection),
                              const SizedBox(height: 4),
                              if (widget.showNodMode) ...[
                                Row(
                                  children: [
                                    const Text('Nod:', style: TextStyle(color: Colors.white60, fontSize: 8)),
                                    const Spacer(),
                                    Text(
                                      isNodTriggered
                                          ? 'NOD! (${state.relativePitch.toStringAsFixed(1)}°)'
                                          : '${state.relativePitch.toStringAsFixed(1)}°',
                                      style: TextStyle(
                                        color: isNodTriggered ? GameColors.neonGreen : Colors.white70,
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                _buildNodBar(state.relativePitch, MotionDefaults.nodTriggerDeg, isNodTriggered),
                              ] else ...[
                                Row(
                                  children: [
                                    const Text('Mouth:', style: TextStyle(color: Colors.white60, fontSize: 8)),
                                    const Spacer(),
                                    Text(
                                      '${(state.relativeMouth * 100).toInt()}%',
                                      style: TextStyle(
                                        color: state.isChomping ? GameColors.neonGreen : Colors.white70,
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                _buildMouthBar(state.relativeMouth, ctrl.mouthOpenThreshold, state.isChomping),
                              ],
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTiltBar(double roll, double threshold, TiltDirection dir) {
    final normalized = (roll / (threshold * 2.0)).clamp(-1.0, 1.0);
    return Container(
      height: 6,
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(width: 1.2, color: Colors.white30),
          Align(
            alignment: Alignment(normalized, 0),
            child: Container(
              width: 10,
              height: 6,
              decoration: BoxDecoration(
                color: dir != TiltDirection.neutral ? GameColors.neonCyan : Colors.white60,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHandBar(double handX) {
    final normalized = handX.clamp(-1.0, 1.0);
    return Container(
      height: 6,
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(width: 1.2, color: Colors.white30),
          Align(
            alignment: Alignment(normalized, 0),
            child: Container(
              width: 10,
              height: 6,
              decoration: BoxDecoration(
                color: normalized.abs() > 0.18 ? GameColors.neonCyan : Colors.white60,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFistBar(double score, bool isFist) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Container(
        height: 6,
        color: Colors.white10,
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: score.clamp(0.06, 1.0),
          child: Container(
            color: isFist ? GameColors.neonGreen : GameColors.neonYellow.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }

  Widget _buildNodBar(double pitch, double threshold, bool isNodding) {
    final double progress = (-pitch / threshold.abs()).clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Container(
        height: 6,
        color: Colors.white10,
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: progress,
          child: Container(
            color: isNodding ? GameColors.neonGreen : GameColors.neonYellow,
          ),
        ),
      ),
    );
  }

  Widget _buildMouthBar(double mouth, double threshold, bool isChomping) {
    final progress = (mouth / (threshold * 1.5)).clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Container(
        height: 6,
        color: Colors.white10,
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: progress,
          child: Container(
            color: isChomping ? GameColors.neonGreen : GameColors.neonPink,
          ),
        ),
      ),
    );
  }
}
