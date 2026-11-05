import 'package:flutter/material.dart';
import '../../motion/motion_state.dart';
import '../../services/sound_service.dart';
import 'kid_ui.dart';

/// Các bước chuẩn bị đầu ván: chờ thấy mặt / tay -> "GREAT! Get ready" (giữ vài giây) -> đếm ngược 3-2-1 -> GO!
enum ReadyPhase {
  waiting,
  confirmed,
  countdown,
  done,
}

/// Thời gian chuẩn bị dùng chung cho mọi game (Face, 1-Hand, 2-Hands)
class ReadyTiming {
  ReadyTiming._();

  /// Đã đủ điều kiện: giữ thông báo "GREAT! Get ready" bấy lâu rồi mới đếm ngược
  static const double confirmSeconds = 2.5;
  static const double countdownSeconds = 3.0;

  /// Mất mặt / tay lâu hơn thế (lúc đang giữ thông báo / đếm ngược) => quay lại bước chờ.
  /// Chừa chút dung sai vì AI có thể trượt vài khung khi bé cử động.
  static const double lostGraceSeconds = 0.5;
}

/// Cổng chuẩn bị đầu ván dùng chung cho các game Face / 1-Hand (Thủ môn có bước "giơ 2 tay" tương tự):
/// game đứng yên tới khi camera thấy mặt (Face) hoặc bàn tay (1-Hand) & đã cân bằng xong, giữ thông báo
/// "GREAT!" vài giây rồi đếm ngược 3-2-1 mới bắt đầu. Không tự vào game khi chưa đủ điều kiện;
/// chỉ bỏ qua bước chờ khi không có camera (chơi cảm ứng).
class ReadyGate extends ChangeNotifier {

  /// Gọi đúng lúc "GO!" (VD: đọc từ mục tiêu khi bé đã vào vị trí)
  VoidCallback? onGo;

  /// Tắt khi [onGo] đã tự thổi còi, tránh 2 tiếng còi chồng nhau
  final bool playGoWhistle;

  ReadyGate({this.playGoWhistle = true});

  ReadyPhase phase = ReadyPhase.waiting;
  bool targetDetected = false;

  /// Đã thấy mặt / tay nhưng AI đang cân bằng mốc trung tính (bé cần đứng yên 1 chút)
  bool calibrating = false;
  double goFlash = 0.0; // 1.0 -> 0.0: chữ GO! mờ dần sau khi bắt đầu
  double _confirmTime = 0.0;
  double _lostTime = 0.0;
  double _countdown = 0.0;
  int _lastCountdownNumber = 0;

  bool get isDone => phase == ReadyPhase.done;

  /// 0 -> 1 trong lúc giữ thông báo "GREAT! Get ready"
  double get confirmProgress => (_confirmTime / ReadyTiming.confirmSeconds).clamp(0.0, 1.0);
  int get countdownNumber => _countdown.ceil();
  double get countdownFraction => _countdown - (countdownNumber - 1); // 1.0 -> 0.0 trong mỗi nhịp đếm

  /// Bắt đầu lại từ bước chờ mặt/tay (vào game / chơi lại)
  void reset() {
    phase = ReadyPhase.waiting;
    targetDetected = false;
    calibrating = false;
    goFlash = 0.0;
    _confirmTime = 0.0;
    _lostTime = 0.0;
    _countdown = 0.0;
    notifyListeners();
  }

  /// [calibrating]: AI đang cân bằng mốc (FaceMotionController.isCalibrating) — chưa tính là sẵn sàng
  void update(double dt, MotionState motion, {required bool cameraAvailable, bool calibrating = false}) {
    if (phase != ReadyPhase.done) {
      targetDetected = motion.inputMode == MotionInputMode.hand ? motion.handDetected : motion.faceDetected;
      this.calibrating = targetDetected && calibrating;
    }
    final bool ready = targetDetected && !this.calibrating;

    switch (phase) {
      case ReadyPhase.waiting:
        if (!cameraAvailable) {
          _beginCountdown(); // chơi cảm ứng: không có gì để chờ
        } else if (ready) {
          phase = ReadyPhase.confirmed;
          _confirmTime = 0.0;
          _lostTime = 0.0;
          SoundService.instance.playClick();
        }
      case ReadyPhase.confirmed:
        if (_lostTarget(dt, ready, cameraAvailable)) break;
        if (ready) _confirmTime += dt;
        if (_confirmTime >= ReadyTiming.confirmSeconds) _beginCountdown();
      case ReadyPhase.countdown:
        if (_lostTarget(dt, ready, cameraAvailable)) break;
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

  /// Mất mặt / tay quá [ReadyTiming.lostGraceSeconds] => quay lại bước chờ (true)
  bool _lostTarget(double dt, bool ready, bool cameraAvailable) {
    if (ready || !cameraAvailable) {
      _lostTime = 0.0;
      return false;
    }
    _lostTime += dt;
    if (_lostTime < ReadyTiming.lostGraceSeconds) return false;
    phase = ReadyPhase.waiting;
    _confirmTime = 0.0;
    _lostTime = 0.0;
    return true;
  }

  void _beginCountdown() {
    phase = ReadyPhase.countdown;
    _lostTime = 0.0;
    _countdown = ReadyTiming.countdownSeconds;
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
      case ReadyPhase.confirmed:
        final isHand = inputMode == MotionInputMode.hand;
        return Center(
          child: ReadyConfirmedPanel(
            scale: s,
            progress: gate.confirmProgress,
            icons: [
              ReadyIcon(emoji: isHand ? '✋' : '🙂', color: isHand ? const Color(0xFF00B8D4) : KidColors.pink),
            ],
          ),
        );
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
    final holdStill = gate.calibrating;
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
            holdStill ? 'Hold still...' : (isHand ? 'Show me your hand' : 'Show me your face'),
            style: TextStyle(color: detected ? color : KidColors.textSoft, fontSize: 13 * s, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

/// 1 biểu tượng mặt / tay đã nhận diện được trong [ReadyConfirmedPanel]
class ReadyIcon {
  final String emoji;
  final Color color;
  final String? label;

  const ReadyIcon({required this.emoji, required this.color, this.label});
}

/// Bảng "GREAT! Get ready..." hiện vài giây sau khi đã đủ điều kiện, có thanh tiến độ trước khi đếm ngược.
/// Dùng chung cho game Face / 1-Hand ([ReadyGateOverlay]) và Thủ môn (2 tay).
class ReadyConfirmedPanel extends StatelessWidget {
  final double scale;
  final double progress; // 0 -> 1
  final List<ReadyIcon> icons;

  const ReadyConfirmedPanel({super.key, required this.scale, required this.progress, required this.icons});

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return KidPanel(
      padding: EdgeInsets.symmetric(horizontal: 26 * s, vertical: 16 * s),
      radius: 28 * s,
      borderWidth: 4 * s,
      borderColor: KidColors.green,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'GREAT! 🎉',
            style: TextStyle(color: KidColors.greenDark, fontSize: 28 * s, fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 12 * s),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < icons.length; i++) ...[
                if (i > 0) SizedBox(width: 28 * s),
                _buildIcon(icons[i], s),
              ],
            ],
          ),
          SizedBox(height: 10 * s),
          Text(
            'Get ready...',
            style: TextStyle(color: KidColors.text, fontSize: 16 * s, fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 8 * s),
          ClipRRect(
            borderRadius: BorderRadius.circular(6 * s),
            child: SizedBox(
              width: 160 * s,
              height: 10 * s,
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: KidColors.grey.withValues(alpha: 0.25),
                valueColor: const AlwaysStoppedAnimation<Color>(KidColors.green),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIcon(ReadyIcon icon, double s) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 72 * s,
              height: 72 * s,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: icon.color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4 * s),
              ),
              child: Text(icon.emoji, style: TextStyle(fontSize: 38 * s)),
            ),
            Positioned(
              right: -4 * s,
              top: -4 * s,
              child: Text('✅', style: TextStyle(fontSize: 22 * s)),
            ),
          ],
        ),
        if (icon.label != null) ...[
          SizedBox(height: 4 * s),
          Text(
            icon.label!,
            style: TextStyle(color: icon.color, fontSize: 13 * s, fontWeight: FontWeight.w900),
          ),
        ],
      ],
    );
  }
}
