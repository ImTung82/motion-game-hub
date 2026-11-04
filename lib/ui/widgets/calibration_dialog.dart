import 'dart:math' as math;
import '../../services/sound_service.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../../motion/face_motion_controller.dart';
import '../../motion/motion_state.dart';
import 'kid_ui.dart';

enum CalibrationMode { face, singleHand, dualHand }

class CalibrationDialog extends StatefulWidget {
  final FaceMotionController controller;
  final bool initialDualHand;

  const CalibrationDialog({super.key, required this.controller, this.initialDualHand = false});

  @override
  State<CalibrationDialog> createState() => _CalibrationDialogState();
}

class _CalibrationDialogState extends State<CalibrationDialog> {
  late CalibrationMode _activeMode;
  bool _justCalibrated = false;
  bool _isCoverMode = true; // Mặc định Tràn viền (Cover) để lấp đầy 16:9, loại bỏ hoàn toàn viền đen 2 bên
  final ScrollController _settingsScroll = ScrollController();

  // Màu kẹo ngọt theo phong cách chung của app (KidColors)
  static const Color _leftHandColor = KidColors.blue;
  static const Color _rightHandColor = KidColors.pink;
  static const Color _activeColor = KidColors.green; // đã kích hoạt cử chỉ (nắm tay / há miệng / vỗ tay)
  static const Color _searchingColor = KidColors.greyDark; // chưa thấy mặt / tay

  @override
  void initState() {
    super.initState();
    if (widget.initialDualHand) {
      _activeMode = CalibrationMode.dualHand;
      widget.controller.inputMode = MotionInputMode.hand;
    } else {
      _activeMode = widget.controller.inputMode == MotionInputMode.hand ? CalibrationMode.singleHand : CalibrationMode.face;
    }
  }

  @override
  void dispose() {
    _settingsScroll.dispose();
    super.dispose();
  }

  void _triggerCalibrate() {
    SoundService.instance.playClick();
    widget.controller.calibrateNeutral();
    setState(() => _justCalibrated = true);
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _justCalibrated = false);
    });
  }

  Color _modeColor(CalibrationMode mode) => switch (mode) {
    CalibrationMode.face => KidColors.blue,
    CalibrationMode.singleHand => KidColors.orange,
    CalibrationMode.dualHand => KidColors.pink,
  };

  Color _modeColorDark(CalibrationMode mode) => switch (mode) {
    CalibrationMode.face => KidColors.blueDark,
    CalibrationMode.singleHand => KidColors.orangeDark,
    CalibrationMode.dualHand => KidColors.pinkDark,
  };

  @override
  Widget build(BuildContext context) {
    final accent = _modeColor(_activeMode);
    final accentDark = _modeColorDark(_activeMode);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 890,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.94, maxWidth: 920),
        padding: const EdgeInsets.fromLTRB(18, 12, 14, 12),
        decoration: BoxDecoration(
          color: KidColors.cream,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: accent, width: 4),
          boxShadow: [
            BoxShadow(color: accent.withValues(alpha: 0.6), offset: const Offset(0, 6)),
            const BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, 10)),
          ],
        ),
        child: DefaultTextStyle.merge(
          style: const TextStyle(color: KidColors.text),
          child: ListenableBuilder(
            listenable: widget.controller,
            builder: (context, _) {
              final ctrl = widget.controller;
              final state = ctrl.state;
              final isDualHand = _activeMode == CalibrationMode.dualHand;
              final isSingleHand = _activeMode == CalibrationMode.singleHand;
              final isDetected = isDualHand ? (state.handsCount > 0) : (isSingleHand ? state.handDetected : state.faceDetected);

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(ctrl, accent, accentDark),
                  const SizedBox(height: 10),

                  // 2 Cột: Trái (Camera 16:9) - Phải (Thước đo Live & Cấu hình độ nhạy)
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // CỘT 1: Camera + nút Cân bằng + Hướng dẫn
                        Expanded(
                          flex: 52,
                          child: LayoutBuilder(
                            builder: (context, box) {
                              // Màn thấp (điện thoại nằm ngang): thu nhỏ khung camera để nút Cân bằng luôn vừa,
                              // thẻ hướng dẫn chỉ hiện khi còn đủ chỗ
                              const double buttonBlock = 10 + 44 + 10; // khoảng cách + nút (40 + đế nổi 4)
                              const double minHelpHeight = 56;
                              final camH = math.max(0.0, math.min(box.maxWidth * 9 / 16, box.maxHeight - buttonBlock));
                              final showHelp = box.maxHeight - camH - buttonBlock >= minHelpHeight;
                              return Column(
                                children: [
                                  SizedBox(height: camH, child: _buildCameraFrame(ctrl, state)),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    child: KidButton(
                                      icon: _justCalibrated ? Icons.check_circle_rounded : Icons.center_focus_strong_rounded,
                                      label: _justCalibrated
                                          ? 'CALIBRATED!'
                                          : (isDualHand
                                                ? 'CALIBRATE (HOLD BOTH HANDS UP)'
                                                : (isSingleHand ? 'CALIBRATE (HOLD YOUR HAND STILL)' : 'CALIBRATE (LOOK STRAIGHT)')),
                                      color: _justCalibrated ? KidColors.green : KidColors.yellowDark,
                                      shadowColor: _justCalibrated ? KidColors.greenDark : KidColors.orangeDark,
                                      height: 40,
                                      onPressed: _triggerCalibrate,
                                    ),
                                  ),
                                  if (showHelp) ...[const SizedBox(height: 10), Expanded(child: _buildHelpCard(state, isDetected, accent))],
                                ],
                              );
                            },
                          ),
                        ),

                        const SizedBox(width: 14),

                        // CỘT 2: Thước đo thông số trực tiếp & Cấu hình độ nhạy
                        Expanded(
                          flex: 48,
                          child: RawScrollbar(
                            controller: _settingsScroll,
                            thumbVisibility: true,
                            thumbColor: accent.withValues(alpha: 0.55),
                            radius: const Radius.circular(8),
                            thickness: 5,
                            child: SingleChildScrollView(
                              controller: _settingsScroll,
                              padding: const EdgeInsets.only(right: 12, bottom: 6),
                              child: isDualHand
                                  ? _buildDualHandSettings(context, ctrl, state)
                                  : (isSingleHand ? _buildHandSettings(context, ctrl, state) : _buildFaceSettings(context, ctrl, state)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ==========================================
  // TIÊU ĐỀ + CHỌN CHẾ ĐỘ (Face / 1-Hand / 2-Hands) + NÚT ĐÓNG
  // ==========================================
  Widget _buildHeader(FaceMotionController ctrl, Color accent, Color accentDark) {
    final isDualHand = _activeMode == CalibrationMode.dualHand;
    final isSingleHand = _activeMode == CalibrationMode.singleHand;

    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: accent,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [BoxShadow(color: accentDark, offset: const Offset(0, 3))],
          ),
          child: Icon(
            isDualHand ? Icons.back_hand_rounded : (isSingleHand ? Icons.pan_tool_rounded : Icons.face_rounded),
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            isDualHand ? 'TWO-HAND SETUP' : (isSingleHand ? 'ONE-HAND SETUP' : 'FACE SETUP'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: accentDark, fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: 1.0),
          ),
        ),

        // Viên kẹo chọn chế độ
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: KidColors.grey.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(24)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildModeTab(
                mode: CalibrationMode.face,
                title: '🙂 FACE',
                onTap: () => setState(() {
                  _activeMode = CalibrationMode.face;
                  ctrl.inputMode = MotionInputMode.face;
                }),
              ),
              _buildModeTab(
                mode: CalibrationMode.singleHand,
                title: '✋ 1 HAND',
                onTap: () => setState(() {
                  _activeMode = CalibrationMode.singleHand;
                  ctrl.inputMode = MotionInputMode.hand;
                }),
              ),
              _buildModeTab(
                mode: CalibrationMode.dualHand,
                title: '👐 2 HANDS',
                onTap: () => setState(() {
                  _activeMode = CalibrationMode.dualHand;
                  ctrl.inputMode = MotionInputMode.hand;
                }),
              ),
            ],
          ),
        ),

        const SizedBox(width: 12),
        KidIconButton(
          icon: Icons.close_rounded,
          color: KidColors.pink,
          shadowColor: KidColors.pinkDark,
          size: 34,
          tooltip: 'Close',
          onPressed: () {
            SoundService.instance.playClick();
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }

  Widget _buildModeTab({required CalibrationMode mode, required String title, required VoidCallback onTap}) {
    final isActive = _activeMode == mode;
    final color = _modeColor(mode);
    return GestureDetector(
      onTap: () {
        if (!isActive) SoundService.instance.playClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? Colors.white : Colors.transparent, width: 2),
          boxShadow: isActive ? [BoxShadow(color: _modeColorDark(mode), offset: const Offset(0, 2.5))] : null,
        ),
        child: Text(
          title,
          style: TextStyle(color: isActive ? Colors.white : KidColors.textSoft, fontSize: 12, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  // ==========================================
  // KHUNG CAMERA 16:9 (preview + chấm theo dõi + thanh trạng thái)
  // ==========================================
  Widget _buildCameraFrame(FaceMotionController ctrl, MotionState state) {
    final hasCam = ctrl.cameraController != null && ctrl.cameraController!.value.isInitialized;
    final isDualHand = _activeMode == CalibrationMode.dualHand;
    final isSingleHand = _activeMode == CalibrationMode.singleHand;
    final isDetected = isDualHand ? (state.handsCount > 0) : (isSingleHand ? state.handDetected : state.faceDetected);
    final isActionTriggered = isDualHand
        ? (state.isClapTriggered || state.leftHand.isFist || state.rightHand.isFist)
        : (isSingleHand ? state.isHandFist : state.isChomping);
    final isRotated90or270 = ctrl.cameraRotationQuarterTurns % 2 == 1;

    // Viền khung đổi màu theo trạng thái nhận diện
    final Color statusColor = isDualHand
        ? (state.isClapTriggered
              ? KidColors.yellow
              : (state.handsCount == 2 ? _activeColor : (state.handsCount == 1 ? KidColors.orange : _searchingColor)))
        : (isActionTriggered ? _activeColor : (isDetected ? _modeColor(_activeMode) : _searchingColor));

    final String statusText = isDualHand
        ? (state.handsCount == 2
              ? 'Both hands ready! (${state.fps.toStringAsFixed(0)} FPS)'
              : (state.handsCount == 1 ? '1 hand found, need 2' : 'Looking for 2 hands...'))
        : (isDetected
              ? '${isSingleHand ? "Hand found!" : "Face found!"} (${state.fps.toStringAsFixed(0)} FPS)'
              : (isSingleHand ? 'Looking for your hand...' : 'Looking for your face...'));

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: statusColor, width: 4),
          boxShadow: [BoxShadow(color: statusColor.withValues(alpha: 0.5), offset: const Offset(0, 4))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final rawSize = ctrl.cameraController?.value.previewSize;
              final childW = isRotated90or270 ? (rawSize?.height ?? constraints.maxHeight) : (rawSize?.width ?? constraints.maxWidth);
              final childH = isRotated90or270 ? (rawSize?.width ?? constraints.maxWidth) : (rawSize?.height ?? constraints.maxHeight);

              return Stack(
                fit: StackFit.expand,
                children: [
                  // 1. Camera Preview: FittedBox(fit: BoxFit.cover) giúp lấp đầy 16:9 kể cả khi xoay 270°
                  if (hasCam)
                    ColoredBox(
                      color: Colors.black,
                      child: FittedBox(
                        fit: _isCoverMode ? BoxFit.cover : BoxFit.contain,
                        child: SizedBox(
                          width: childW,
                          height: childH,
                          child: RotatedBox(quarterTurns: ctrl.cameraRotationQuarterTurns, child: CameraPreview(ctrl.cameraController!)),
                        ),
                      ),
                    )
                  else
                    _buildNoCamera(ctrl),

                  // 2. Chấm theo dõi cử chỉ
                  if (isDualHand) ...[
                    if (state.leftHand.detected)
                      _buildHandReticle(state.leftHand.visualX, state.leftHand.visualY, state.leftHand.isFist, _leftHandColor, '👈 LEFT'),
                    if (state.rightHand.detected)
                      _buildHandReticle(
                        state.rightHand.visualX,
                        state.rightHand.visualY,
                        state.rightHand.isFist,
                        _rightHandColor,
                        'RIGHT 👉',
                      ),

                    // Khoảng cách 2 tay khi cả 2 tay cùng hiện
                    if (state.handsCount == 2)
                      Align(
                        alignment: const Alignment(0, 0.8),
                        child: _overlayChip(
                          state.clapDistance < ctrl.clapThreshold
                              ? '👏 Ready to clap! (${(state.clapDistance * 100).toInt()}%)'
                              : '👐 Hands apart: ${(state.clapDistance * 100).toInt()}%',
                          borderColor: state.clapDistance < ctrl.clapThreshold ? _activeColor : _rightHandColor,
                        ),
                      ),

                    // Hiệu ứng ăn mừng khi Vỗ tay
                    if (state.isClapTriggered)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                          decoration: BoxDecoration(
                            color: KidColors.yellow,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: const [BoxShadow(color: KidColors.orangeDark, offset: Offset(0, 4))],
                          ),
                          child: const Text(
                            '👏 CLAP! 👏',
                            style: TextStyle(color: KidColors.text, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.0),
                          ),
                        ),
                      ),
                  ] else if (isSingleHand && state.handDetected)
                    _buildHandReticle(state.handVisualX, state.handVisualY, state.isHandFist, _modeColor(_activeMode), null)
                  else if (!isSingleHand && state.faceDetected)
                    Align(
                      alignment: Alignment(state.faceVisualX.clamp(-1.0, 1.0), state.faceVisualY.clamp(-1.0, 1.0)),
                      child: _reticleCircle(
                        color: isActionTriggered ? _activeColor : _modeColor(_activeMode),
                        child: Text(isActionTriggered ? '😮' : '🙂', style: const TextStyle(fontSize: 24)),
                      ),
                    ),

                  // 3. Thanh trạng thái + nút Tràn viền + nút Xoay camera nhanh
                  Positioned(
                    top: 8,
                    left: 8,
                    right: 8,
                    child: Row(
                      children: [
                        Flexible(child: _overlayChip(statusText, dotColor: isDetected ? _activeColor : _searchingColor)),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => setState(() => _isCoverMode = !_isCoverMode),
                          child: _overlayChip(
                            _isCoverMode ? 'Fill' : 'Fit',
                            icon: _isCoverMode ? Icons.fullscreen_rounded : Icons.fullscreen_exit_rounded,
                            borderColor: _isCoverMode ? _activeColor : null,
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => setState(() => ctrl.rotateCamera()),
                          child: _overlayChip('${ctrl.cameraRotationQuarterTurns * 90}°', icon: Icons.rotate_right_rounded),
                        ),
                      ],
                    ),
                  ),

                  // 4. Lớp phủ khi đang hiệu chỉnh
                  if (ctrl.isCalibrating && hasCam)
                    Container(
                      color: KidColors.cream.withValues(alpha: 0.8),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(width: 34, height: 34, child: CircularProgressIndicator(color: KidColors.orange, strokeWidth: 4)),
                            SizedBox(height: 10),
                            Text(
                              'Hold still... calibrating ✨',
                              style: TextStyle(color: KidColors.text, fontSize: 14, fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildNoCamera(FaceMotionController ctrl) {
    return Container(
      color: KidColors.cream,
      padding: const EdgeInsets.all(12),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📷', style: TextStyle(fontSize: 30)),
            const SizedBox(height: 4),
            const Text(
              'Camera not connected',
              style: TextStyle(color: KidColors.text, fontSize: 14, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 3),
            Text(
              ctrl.statusMessage,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: KidColors.textSoft, fontSize: 10.5),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: 170,
              child: KidButton(
                icon: Icons.refresh_rounded,
                label: 'TRY AGAIN',
                color: KidColors.blue,
                shadowColor: KidColors.blueDark,
                height: 36,
                onPressed: () {
                  SoundService.instance.playClick();
                  ctrl.retryInitialize();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Chấm tròn theo dõi bàn tay (có nhãn TRÁI / PHẢI ở chế độ 2 tay)
  Widget _buildHandReticle(double vx, double vy, bool isFist, Color color, String? label) {
    final c = isFist ? _activeColor : color;
    return Align(
      alignment: Alignment(vx.clamp(-1.0, 1.0), vy.clamp(-1.0, 1.0)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(height: 3),
          ],
          _reticleCircle(
            color: c,
            child: Text(isFist ? '✊' : '✋', style: const TextStyle(fontSize: 22)),
          ),
        ],
      ),
    );
  }

  Widget _reticleCircle({required Color color, required Widget child}) {
    return Container(
      width: 50,
      height: 50,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.55),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [BoxShadow(color: color, blurRadius: 0, spreadRadius: 2)],
      ),
      child: child,
    );
  }

  /// Viên thông tin trắng nổi trên khung camera
  Widget _overlayChip(String text, {Color? dotColor, IconData? icon, Color? borderColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor ?? Colors.white, width: 2),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dotColor != null) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
            ),
            const SizedBox(width: 5),
          ],
          if (icon != null) ...[Icon(icon, size: 14, color: borderColor ?? KidColors.text), const SizedBox(width: 3)],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: KidColors.text, fontSize: 10.5, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // THẺ HƯỚNG DẪN & TÌNH TRẠNG NHẬN DIỆN
  // ==========================================
  Widget _buildHelpCard(MotionState state, bool isDetected, Color accent) {
    final isDualHand = _activeMode == CalibrationMode.dualHand;
    final isSingleHand = _activeMode == CalibrationMode.singleHand;

    final String statusText = isDualHand
        ? (state.handsCount == 2
              ? 'Both hands are in the frame'
              : (state.handsCount == 1 ? '1 hand found, raise the other one' : 'No hands found yet'))
        : (isDetected
              ? (isSingleHand ? 'Your hand is in the frame' : 'Your face is in the frame')
              : (isSingleHand ? 'Move your hand into the frame' : 'Look at the camera'));

    final String tips = isDualHand
        ? '• Stand about 1 - 1.5 m from the camera so both hands fit.\n'
              '• Left hand (blue) and right hand (pink) move each side.\n'
              '• Make a fist to catch, block or hit the drum.\n'
              '• Bring both hands together to clap.'
        : (isSingleHand
              ? '• Tilt or slide your hand left / right to steer.\n'
                    '• Make a fist to jump, shoot or chomp.\n'
                    '• "Fill" lets your hand reach both edges of the screen.'
              : '• Tilt your head left / right to steer.\n'
                    '• Open your mouth wide to bite / jump.\n'
                    '• "Fill" makes the camera fill the frame.');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.35), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(isDetected ? '✅' : '👀', style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  statusText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDetected ? KidColors.greenDark : KidColors.orangeDark,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                tips,
                style: const TextStyle(color: KidColors.textSoft, fontSize: 11, height: 1.4, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // CÀI ĐẶT DUAL-HAND MODE (2 TAY ĐỘC LẬP & VỖ TAY)
  // ==========================================
  Widget _buildDualHandSettings(BuildContext context, FaceMotionController ctrl, MotionState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. THẺ THEO DÕI 2 TAY (TRÁI & PHẢI)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildHandCard(ctrl, state.leftHand, '👈 LEFT HAND', _leftHandColor)),
            const SizedBox(width: 10),
            Expanded(child: _buildHandCard(ctrl, state.rightHand, 'RIGHT HAND 👉', _rightHandColor)),
          ],
        ),

        const SizedBox(height: 10),

        // 2. THƯỚC ĐO CỬ CHỈ VỖ TAY
        _section(
          color: KidColors.pink,
          highlight: state.isClapTriggered || (state.handsCount == 2 && state.clapDistance < ctrl.clapThreshold),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _meterHeader(
                '👏',
                'Clap',
                state.isClapTriggered
                    ? 'CLAP!'
                    : (state.handsCount == 2 ? 'Apart ${(state.clapDistance * 100).toInt()}%' : 'Need both hands'),
                state.isClapTriggered || (state.handsCount == 2 && state.clapDistance < ctrl.clapThreshold) ? _activeColor : null,
              ),
              const SizedBox(height: 8),
              _buildClapMeter(state.clapDistance, ctrl.clapThreshold, state.isClapTriggered),
              const SizedBox(height: 4),
              _meterFootnote('Hands: ${state.handsCount} / 2', 'Clap when < ${(ctrl.clapThreshold * 100).toInt()}%'),
            ],
          ),
        ),

        const SizedBox(height: 6),
        _sliderSetting(
          title: 'Clap distance',
          valueText: '${(ctrl.clapThreshold * 100).toInt()}%',
          color: KidColors.pink,
          value: ctrl.clapThreshold,
          min: 0.10,
          max: 0.40,
          divisions: 30,
          onChanged: (val) => setState(() => ctrl.clapThreshold = val),
        ),
        _sliderSetting(
          title: 'Fist strength (both hands)',
          valueText: '${(ctrl.fistThreshold * 100).toInt()}%',
          color: KidColors.yellowDark,
          value: ctrl.fistThreshold,
          min: 0.20,
          max: 0.75,
          divisions: 22,
          onChanged: (val) => setState(() => ctrl.fistThreshold = val),
        ),
        _sliderSetting(
          title: 'Hand reach',
          valueText: '${ctrl.handSensitivity.toStringAsFixed(1)}x',
          color: KidColors.green,
          value: ctrl.handSensitivity,
          min: 1.2,
          max: 4.0,
          divisions: 28,
          onChanged: (val) => setState(() => ctrl.handSensitivity = val),
        ),

        _buildCommonSettings(context, ctrl),
      ],
    );
  }

  Widget _buildHandCard(FaceMotionController ctrl, HandData hand, String title, Color color) {
    final detected = hand.detected;
    return _section(
      color: color,
      highlight: detected,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w900),
                ),
              ),
              _pill(detected ? 'READY' : 'LOST', detected ? color : null),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            detected ? 'Position: ${(hand.x * 100).toInt()}%, ${(hand.y * 100).toInt()}%' : 'Move your hand into view',
            style: TextStyle(color: detected ? KidColors.text : KidColors.textSoft, fontSize: 10.5, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          _buildFistMeter(hand.fistScore, ctrl.fistThreshold, hand.isFist),
          const SizedBox(height: 4),
          Text(
            hand.isFist ? '✊ FIST' : (hand.isOpen ? '✋ OPEN' : 'IN BETWEEN'),
            style: TextStyle(color: hand.isFist ? KidColors.greenDark : KidColors.textSoft, fontSize: 10.5, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // CÀI ĐẶT HAND MODE (CÓ THƯỚC ĐO TRỰC TIẾP)
  // ==========================================
  Widget _buildHandSettings(BuildContext context, FaceMotionController ctrl, MotionState state) {
    final isSteering = state.tiltDirection != TiltDirection.neutral;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. THƯỚC ĐO NGHIÊNG / LƯỚT TAY (TRỤC NGANG X)
        _section(
          color: KidColors.orange,
          highlight: isSteering,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _meterHeader(
                '↔️',
                'Steering',
                state.tiltDirection == TiltDirection.left
                    ? '👈 LEFT ${(state.handX.abs() * 100).toInt()}%'
                    : (state.tiltDirection == TiltDirection.right ? 'RIGHT ${(state.handX.abs() * 100).toInt()}% 👉' : 'CENTER'),
                isSteering ? KidColors.orange : null,
              ),
              const SizedBox(height: 8),
              _buildCenterMeter(state.handX.clamp(-1.0, 1.0), state.handX.abs() > 0.02, KidColors.orange),
              const SizedBox(height: 4),
              _meterFootnote('Hand tilt: ${_fmtDeg(ctrl.currentHandTilt)}', 'Deadzone ±${(ctrl.handDeadzone * 100).toInt()}%'),
            ],
          ),
        ),

        const SizedBox(height: 6),
        _sliderSetting(
          title: 'Steering sensitivity',
          valueText: '${ctrl.handSensitivity.toStringAsFixed(1)}x',
          color: KidColors.orange,
          value: ctrl.handSensitivity,
          min: 1.2,
          max: 4.0,
          divisions: 28,
          onChanged: (val) => setState(() => ctrl.handSensitivity = val),
        ),
        _sliderSetting(
          title: 'Center deadzone',
          valueText: '±${(ctrl.handDeadzone * 100).toInt()}%',
          color: KidColors.orange,
          value: ctrl.handDeadzone,
          min: 0.08,
          max: 0.40,
          divisions: 16,
          onChanged: (val) => setState(() => ctrl.handDeadzone = val),
        ),

        const SizedBox(height: 4),

        // 2. THƯỚC ĐO & NGƯỠNG NẮM / XÒE TAY
        _section(
          color: KidColors.yellowDark,
          highlight: state.isHandFist,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _meterHeader(
                '✊',
                'Fist',
                state.isHandFist
                    ? 'FIST ${(state.handFistScore * 100).toInt()}%'
                    : (state.isHandOpen ? 'OPEN ${(state.handFistScore * 100).toInt()}%' : '${(state.handFistScore * 100).toInt()}%'),
                state.isHandFist ? _activeColor : null,
              ),
              const SizedBox(height: 8),
              _buildFistMeter(state.handFistScore, ctrl.fistThreshold, state.isHandFist),
              const SizedBox(height: 4),
              _meterFootnote(
                'Finger curl: ${(ctrl.currentHandSpan / 100).toStringAsFixed(2)}',
                'Fist at ${(ctrl.fistThreshold * 100).toInt()}%',
              ),
            ],
          ),
        ),

        const SizedBox(height: 6),
        _sliderSetting(
          title: 'Fist strength',
          valueText: '${(ctrl.fistThreshold * 100).toInt()}%',
          color: KidColors.yellowDark,
          value: ctrl.fistThreshold,
          min: 0.20,
          max: 0.75,
          divisions: 22,
          onChanged: (val) => setState(() => ctrl.fistThreshold = val),
        ),

        _switchSetting(
          emoji: '🔄',
          title: 'Swap left & right',
          subtitle: 'Off: tilt / slide left moves left',
          value: ctrl.invertLean,
          color: KidColors.orange,
          onChanged: (val) => setState(() => ctrl.invertLean = val),
        ),

        _buildCommonSettings(context, ctrl),
      ],
    );
  }

  // ==========================================
  // CÀI ĐẶT FACE MODE (CÓ THƯỚC ĐO TRỰC TIẾP)
  // ==========================================
  Widget _buildFaceSettings(BuildContext context, FaceMotionController ctrl, MotionState state) {
    final isTilting = state.tiltDirection != TiltDirection.neutral;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. THƯỚC ĐO NGHIÊNG ĐẦU
        _section(
          color: KidColors.blue,
          highlight: isTilting,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _meterHeader(
                '🙂',
                'Head tilt',
                state.tiltDirection == TiltDirection.left
                    ? '👈 LEFT ${state.relativeRoll.abs().toStringAsFixed(0)}°'
                    : (state.tiltDirection == TiltDirection.right
                          ? 'RIGHT ${state.relativeRoll.abs().toStringAsFixed(0)}° 👉'
                          : '${state.relativeRoll.toStringAsFixed(0)}°'),
                isTilting ? KidColors.blue : null,
              ),
              const SizedBox(height: 8),
              _buildCenterMeter((state.relativeRoll / (ctrl.tiltThreshold * 1.8)).clamp(-1.0, 1.0), isTilting, KidColors.blue),
            ],
          ),
        ),

        const SizedBox(height: 6),
        _sliderSetting(
          title: 'Tilt needed to steer',
          valueText: '±${ctrl.tiltThreshold.toInt()}°',
          color: KidColors.blue,
          value: ctrl.tiltThreshold,
          min: 6.0,
          max: 25.0,
          divisions: 19,
          onChanged: (val) => setState(() => ctrl.tiltThreshold = val),
        ),

        const SizedBox(height: 4),

        // 2. THƯỚC ĐO HÁ MIỆNG
        _section(
          color: KidColors.pink,
          highlight: state.isChomping,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _meterHeader(
                '👄',
                'Mouth open',
                state.isChomping ? 'OPEN ${(state.relativeMouth * 100).toInt()}%' : '${(state.relativeMouth * 100).toInt()}%',
                state.isChomping ? _activeColor : null,
              ),
              const SizedBox(height: 8),
              _buildMouthMeter(state.relativeMouth, ctrl.mouthOpenThreshold, state.isChomping),
            ],
          ),
        ),

        const SizedBox(height: 6),
        _sliderSetting(
          title: 'Mouth open needed',
          valueText: '${(ctrl.mouthOpenThreshold * 100).toInt()}%',
          color: KidColors.pink,
          value: ctrl.mouthOpenThreshold,
          min: 0.08,
          max: 0.35,
          divisions: 27,
          onChanged: (val) => setState(() => ctrl.mouthOpenThreshold = val),
        ),

        _switchSetting(
          emoji: '🔄',
          title: 'Swap left & right',
          subtitle: 'Off: tilt head left moves left',
          value: ctrl.invertLean,
          color: KidColors.blue,
          onChanged: (val) => setState(() => ctrl.invertLean = val),
        ),

        _buildCommonSettings(context, ctrl),
      ],
    );
  }

  // ==========================================
  // CÀI ĐẶT CHUNG (CAMERA, ÂM THANH & NÚT CẢM ỨNG)
  // ==========================================
  Widget _buildCommonSettings(BuildContext context, FaceMotionController ctrl) {
    final muted = SoundService.instance.isMuted;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 6),
        _section(
          color: KidColors.blue,
          child: Row(
            children: [
              const Text('📷', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Rotate camera',
                      style: TextStyle(color: KidColors.text, fontSize: 12, fontWeight: FontWeight.w900),
                    ),
                    Text(
                      'Now: ${ctrl.cameraRotationQuarterTurns * 90}°  •  AI scan: ${ctrl.aiRotationOffset * 90}°',
                      style: const TextStyle(color: KidColors.textSoft, fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 112,
                child: KidButton(
                  icon: Icons.rotate_right_rounded,
                  label: '90°',
                  color: KidColors.blue,
                  shadowColor: KidColors.blueDark,
                  height: 34,
                  onPressed: () {
                    SoundService.instance.playClick();
                    setState(() => ctrl.rotateCamera());
                  },
                ),
              ),
            ],
          ),
        ),
        _switchSetting(
          emoji: muted ? '🔇' : '🔊',
          title: 'Sound effects',
          subtitle: muted ? 'Sound is off' : 'Sound is on (volume ${(SoundService.instance.volume * 100).toInt()}%)',
          value: !muted,
          color: KidColors.yellowDark,
          onChanged: (val) {
            setState(() {
              SoundService.instance.setMuted(!val);
            });
            if (val) SoundService.instance.playScore();
          },
        ),
        _switchSetting(
          emoji: '👆',
          title: 'Touch buttons in game',
          subtitle: 'Off: play only with gestures',
          value: ctrl.showTouchControls,
          color: KidColors.green,
          onChanged: (val) => setState(() => ctrl.showTouchControls = val),
        ),
      ],
    );
  }

  // ==========================================
  // KHỐI GIAO DIỆN DÙNG CHUNG
  // ==========================================

  /// Thẻ trắng bo tròn, viền màu, đổ bóng khối (đậm hơn khi cử chỉ đang kích hoạt)
  Widget _section({required Color color, bool highlight = false, required Widget child}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: highlight ? color : color.withValues(alpha: 0.35), width: 2.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: highlight ? 0.55 : 0.2),
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _meterHeader(String emoji, String title, String value, Color? activeColor) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(color: KidColors.text, fontSize: 13, fontWeight: FontWeight.w900),
          ),
        ),
        _pill(value, activeColor),
      ],
    );
  }

  /// Viên giá trị: tô màu khi đang kích hoạt, xám nhạt khi bình thường
  Widget _pill(String text, Color? color) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: color ?? KidColors.grey.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(12)),
      child: Text(
        text,
        style: TextStyle(color: color != null ? Colors.white : KidColors.textSoft, fontSize: 11, fontWeight: FontWeight.w900),
      ),
    );
  }

  Widget _meterFootnote(String left, String right) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            left,
            style: const TextStyle(color: KidColors.textSoft, fontSize: 9.5, fontWeight: FontWeight.w600),
          ),
        ),
        Text(
          right,
          style: const TextStyle(color: KidColors.orangeDark, fontSize: 9.5, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  Widget _sliderSetting({
    required String title,
    required String valueText,
    required Color color,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: KidColors.text, fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
              _pill(valueText, color),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 8,
              activeTrackColor: color,
              inactiveTrackColor: color.withValues(alpha: 0.18),
              thumbColor: color,
              overlayColor: color.withValues(alpha: 0.15),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10, elevation: 2),
              activeTickMarkColor: Colors.transparent,
              inactiveTickMarkColor: Colors.transparent,
              showValueIndicator: ShowValueIndicator.never,
            ),
            child: Slider(value: value, min: min, max: max, divisions: divisions, onChanged: onChanged),
          ),
        ],
      ),
    );
  }

  Widget _switchSetting({
    required String emoji,
    required String title,
    required String subtitle,
    required bool value,
    required Color color,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: _section(
          color: color,
          highlight: value,
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(color: KidColors.text, fontSize: 12, fontWeight: FontWeight.w900),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(color: KidColors.textSoft, fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeThumbColor: Colors.white,
                activeTrackColor: color,
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: KidColors.grey,
                trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtDeg(double deg) => '${deg >= 0 ? '+' : ''}${deg.toStringAsFixed(1)}°';

  // ==========================================
  // THƯỚC ĐO
  // ==========================================
  static const double _meterHeight = 14;

  Widget _meterTrack({required Widget child}) {
    return Container(
      width: double.infinity, // luôn kín bề ngang (kể cả trong Column căn trái)
      height: _meterHeight,
      decoration: BoxDecoration(color: KidColors.grey.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(_meterHeight / 2)),
      child: ClipRRect(borderRadius: BorderRadius.circular(_meterHeight / 2), child: child),
    );
  }

  /// Vạch ngưỡng kích hoạt trên thanh đo
  Widget _thresholdMark(double threshold) {
    return Align(
      alignment: Alignment((threshold.clamp(0.05, 0.95) * 2.0) - 1.0, 0),
      child: Container(width: 3, height: _meterHeight, color: KidColors.orangeDark),
    );
  }

  Widget _fillBar(double fraction, Color color) {
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: fraction.clamp(0.0, 1.0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(_meterHeight / 2)),
      ),
    );
  }

  /// Thước đo 2 chiều (trái - giữa - phải) cho nghiêng đầu / lướt tay
  Widget _buildCenterMeter(double normalized, bool active, Color color) {
    return _meterTrack(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(width: 2, color: KidColors.textSoft.withValues(alpha: 0.4)),
          Align(
            alignment: Alignment(normalized, 0),
            child: Container(
              width: 22,
              height: _meterHeight,
              decoration: BoxDecoration(
                color: active ? color : KidColors.greyDark,
                borderRadius: BorderRadius.circular(_meterHeight / 2),
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFistMeter(double score, double threshold, bool isFist) {
    return _meterTrack(child: Stack(children: [_fillBar(score, isFist ? _activeColor : KidColors.yellow), _thresholdMark(threshold)]));
  }

  Widget _buildClapMeter(double distance, double threshold, bool isClap) {
    return _meterTrack(
      child: Stack(
        children: [
          _fillBar(distance, isClap ? KidColors.yellow : (distance < threshold ? _activeColor : KidColors.pink.withValues(alpha: 0.75))),
          _thresholdMark(threshold),
        ],
      ),
    );
  }

  Widget _buildMouthMeter(double mouth, double threshold, bool isChomping) {
    final progress = (mouth / (threshold * 1.5)).clamp(0.0, 1.0);
    return _meterTrack(
      child: Stack(
        children: [
          _fillBar(progress, isChomping ? _activeColor : KidColors.pink),
          _thresholdMark(1 / 1.5), // ngưỡng há miệng luôn ở 2/3 thước đo
        ],
      ),
    );
  }
}
