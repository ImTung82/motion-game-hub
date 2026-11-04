import 'package:flutter/material.dart';
import '../../motion/motion_state.dart';
import '../../services/sound_service.dart';
import 'kid_ui.dart';

/// Các bước chuẩn bị đầu ván: chờ thấy mặt / tay -> đếm ngược 3-2-1 -> GO!
enum ReadyPhase {
  waiting,
  countdown,
  done,
}

/// Cổng chuẩn bị đầu ván dùng chung cho các game Face / 1-Hand (giống bước "giơ 2 tay" của Thủ môn):
/// game đứng yên tới khi camera thấy mặt (Face) hoặc bàn tay (1-Hand), rồi đếm ngược 3-2-1 mới bắt đầu.
class ReadyGate extends ChangeNotifier {
  static const double _waitTimeout = 5.0; // Chờ tối đa 5s để thấy mặt/tay rồi vẫn bắt đầu (như Thủ môn)
  static const double _countdownSeconds = 3.0;

  /// Gọi đúng lúc "GO!" (VD: đọc từ mục tiêu khi bé đã vào vị trí)
  VoidCallback? onGo;

  /// Tắt khi [onGo] đã tự thổi còi, tránh 2 tiếng còi chồng nhau
  final bool playGoWhistle;

  ReadyGate({this.playGoWhistle = true});

  ReadyPhase phase = ReadyPhase.waiting;
  bool targetDetected = false;
  double goFlash = 0.0; // 1.0 -> 0.0: chữ GO! mờ dần sau khi bắt đầu
  double _waitTime = 0.0;
  double _countdown = 0.0;
  int _lastCountdownNumber = 0;

  bool get isDone => phase == ReadyPhase.done;
  int get countdownNumber => _countdown.ceil();
  double get countdownFraction => _countdown - (countdownNumber - 1); // 1.0 -> 0.0 trong mỗi nhịp đếm

  /// Bắt đầu lại từ bước chờ mặt/tay (vào game / chơi lại)
  void reset() {
    phase = ReadyPhase.waiting;
    targetDetected = false;
    goFlash = 0.0;
    _waitTime = 0.0;
    _countdown = 0.0;
    notifyListeners();
  }

  void update(double dt, MotionState motion, {required bool cameraAvailable}) {
    switch (phase) {
      case ReadyPhase.waiting:
        _waitTime += dt;
        targetDetected = motion.inputMode == MotionInputMode.hand ? motion.handDetected : motion.faceDetected;
        // Không có camera (chơi cảm ứng) thì không cần chờ
        if (targetDetected || !cameraAvailable || _waitTime >= _waitTimeout) {
          _beginCountdown();
        }
      case ReadyPhase.countdown:
        _countdown -= dt;
        if (_countdown <= 0) {
          phase = ReadyPhase.done;
          goFlash = 1.0;
          if (playGoWhistle) SoundService.instance.playWhistle();
          onGo?.call();
        } else if (countdownNumber != _lastCountdownNumber) {
          _lastCountdownNumber = countdownNumber;
          SoundService.instance.playCountdownTick();
        }
      case ReadyPhase.done:
        if (goFlash <= 0) return; // ván đang chơi: không cần vẽ lại
        goFlash = (goFlash - dt * 1.6).clamp(0.0, 1.0);
    }
    notifyListeners();
  }

  void _beginCountdown() {
    phase = ReadyPhase.countdown;
    _countdown = _countdownSeconds;
    _lastCountdownNumber = countdownNumber;
    SoundService.instance.playCountdownTick();
  }
}

/// Lớp phủ giữa màn hình cho [ReadyGate]: bảng "Cho cô xem mặt / tay" -> số đếm 3-2-1 -> GO!
class ReadyGateOverlay extends StatelessWidget {
  final ReadyGate gate;
  final MotionInputMode inputMode;
  final double scale;
  final String goEmoji;

  const ReadyGateOverlay({
    super.key,
    required this.gate,
    required this.inputMode,
    required this.scale,
    this.goEmoji = '🚀',
  });

  @override
  Widget build(BuildContext context) {
    final s = scale;
    switch (gate.phase) {
      case ReadyPhase.waiting:
        return Center(child: _buildShowMePanel(s));
      case ReadyPhase.countdown:
        final pop = 1.0 + 0.35 * gate.countdownFraction;
        return Center(
          child: Transform.scale(
            scale: pop,
            child: Container(
              width: 120 * s,
              height: 120 * s,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: KidColors.yellow,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 6 * s),
                boxShadow: [BoxShadow(color: KidColors.orangeDark.withValues(alpha: 0.7), offset: Offset(0, 6 * s))],
              ),
              child: Text(
                '${gate.countdownNumber}',
                style: TextStyle(color: KidColors.text, fontSize: 64 * s, fontWeight: FontWeight.w900, height: 1.0),
              ),
            ),
          ),
        );
      case ReadyPhase.done:
        if (gate.goFlash <= 0) return const SizedBox.shrink();
        final t = gate.goFlash.clamp(0.0, 1.0);
        return Center(
          child: Opacity(
            opacity: t,
            child: Transform.scale(
              scale: 1.6 - 0.6 * t,
              child: Text(
                'GO! $goEmoji',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 64 * s,
                  fontWeight: FontWeight.w900,
                  shadows: const [Shadow(color: Color(0xAA000000), blurRadius: 8, offset: Offset(0, 4))],
                ),
              ),
            ),
          ),
        );
    }
  }

  Widget _buildShowMePanel(double s) {
    final isHand = inputMode == MotionInputMode.hand;
    final detected = gate.targetDetected;
    final color = isHand ? const Color(0xFF00B8D4) : KidColors.pink;

    return KidPanel(
      padding: EdgeInsets.symmetric(horizontal: 26 * s, vertical: 16 * s),
      radius: 28 * s,
      borderWidth: 4 * s,
      borderColor: KidColors.blue,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isHand ? 'HAND UP! ✋' : 'LOOK AT ME! 👀',
            style: TextStyle(color: KidColors.blueDark, fontSize: 28 * s, fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 12 * s),
          Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 72 * s,
                height: 72 * s,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: detected ? color : KidColors.grey.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                  border: Border.all(color: detected ? Colors.white : KidColors.grey, width: 4 * s),
                ),
                child: Opacity(
                  opacity: detected ? 1.0 : 0.5,
                  child: Text(isHand ? '✋' : '🙂', style: TextStyle(fontSize: 38 * s)),
                ),
              ),
              if (detected)
                Positioned(
                  right: -4 * s,
                  top: -4 * s,
                  child: Text('✅', style: TextStyle(fontSize: 22 * s)),
                ),
            ],
          ),
          SizedBox(height: 4 * s),
          Text(
            isHand ? 'Show me your hand' : 'Show me your face',
            style: TextStyle(color: detected ? color : KidColors.textSoft, fontSize: 13 * s, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}
