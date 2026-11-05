import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../motion/face_motion_controller.dart';
import '../../services/sound_service.dart';
import '../../ui/widgets/calibration_dialog.dart';
import '../../ui/widgets/camera_pip_overlay.dart';
import '../../ui/widgets/company_logo_badge.dart';
import '../../ui/widgets/kid_ui.dart';
import '../../ui/widgets/listenable_selector.dart';
import '../../ui/widgets/rabbit_mascot.dart';
import '../../ui/widgets/lives_hearts.dart';
import '../../ui/widgets/ready_gate.dart';
import '../../ui/widgets/score_fly_layer.dart';
import 'penalty_canvas.dart';
import 'penalty_engine.dart';
import 'penalty_models.dart';

class PenaltyScreen extends StatefulWidget {
  final FaceMotionController motionController;

  const PenaltyScreen({super.key, required this.motionController});

  @override
  State<PenaltyScreen> createState() => _PenaltyScreenState();
}

class _PenaltyScreenState extends State<PenaltyScreen> with SingleTickerProviderStateMixin {
  late final PenaltyEngine _engine;
  final ReadyGate _readyGate = ReadyGate(playGoWhistle: false); // announceTarget đã thổi còi
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  double _animationValue = 0.0;

  // Điểm bay: điểm trên HUD chỉ tăng khi "+N" bay tới nơi
  final GlobalKey<ScoreFlyLayerState> _flyLayerKey = GlobalKey<ScoreFlyLayerState>();
  final GlobalKey _scoreKey = GlobalKey();
  int _shownScore = 0;

  // Trạng thái PiP camera trước khi vào game (để khôi phục cho các game khác)
  bool _prevShowCameraPip = true;

  // Ảnh quả bóng (gốc 3840px) -> giải mã nhỏ 192px vì bóng trên sân chỉ cỡ 28px, đỡ tốn RAM
  static const _ballAsset = ResizeImage(AssetImage('assets/images/soccer_ball.png'), width: 192, height: 192);
  ImageStream? _ballStream;
  ImageStreamListener? _ballListener;
  ui.Image? _ballImage;

  // Kích thước HUD chuẩn (nhân với hệ số kidScale theo màn hình)
  static const double _hudButtonSize = 46;
  static const double _hudMargin = 12;
  static const double _logoW = 96;
  static const double _logoH = 40;

  @override
  void initState() {
    super.initState();
    // Mặc định ẩn camera PiP khi vào game (bấm nút camera trên HUD để mở lại); thoát game thì trả lại như cũ
    _prevShowCameraPip = widget.motionController.showCameraPip;
    widget.motionController.setCameraPipQuietly(false);
    _engine = PenaltyEngine();
    _engine.onScored = _onScored;
    _readyGate.onGo = _engine.announceTarget; // thổi còi & đọc đề khi bé đã vào vị trí
    _ticker = createTicker(_onTick);
    _ticker.start();
  }

  void _onTick(Duration elapsed) {
    if (_lastTick == Duration.zero) {
      _lastTick = elapsed;
      return;
    }

    final double dt = (elapsed - _lastTick).inMicroseconds / 1000000.0;
    _lastTick = elapsed;

    final clampedDt = dt.clamp(0.001, 0.05);
    _animationValue += clampedDt;

    final ctrl = widget.motionController;
    if (!_engine.isPaused) _readyGate.update(clampedDt, ctrl.state, cameraAvailable: ctrl.cameraAvailable, calibrating: ctrl.isCalibrating);
    if (!_readyGate.isDone) return; // chưa thấy mặt / tay hoặc đang đếm ngược: game đứng yên

    _engine.update(clampedDt, ctrl.state);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Canvas cần ui.Image: nạp ảnh bóng 1 lần, chưa nạp xong thì painter vẽ bóng vector như cũ
    if (_ballStream == null) {
      _ballStream = _ballAsset.resolve(createLocalImageConfiguration(context));
      _ballListener = ImageStreamListener((info, _) {
        if (mounted) setState(() => _ballImage = info.image);
      });
      _ballStream!.addListener(_ballListener!);
    }
  }

  @override
  void dispose() {
    if (_ballListener != null) _ballStream?.removeListener(_ballListener!);
    widget.motionController.setCameraPipQuietly(_prevShowCameraPip, persist: true);
    _ticker.dispose();
    _readyGate.dispose();
    _engine.dispose();
    super.dispose();
  }

  // Toạ độ khung thành -> toạ độ màn hình (khớp với PenaltyCanvasPainter)
  void _onScored(int gained, int streak, double goalX, double goalY) {
    final size = MediaQuery.of(context).size;
    final groundY = size.height * 0.39;
    final goalH = groundY - size.height * 0.16;
    _flyLayerKey.currentState?.spawn(
      Offset(size.width * 0.5 + goalX * size.width * 0.25, groundY - goalY * goalH),
      '+$gained',
      subText: streak > 1 ? '🔥 x$streak' : null,
    );
  }

  void _restart() {
    setState(() => _shownScore = 0);
    _engine.startNewMatch(announce: false);
    _readyGate.reset();
  }

  void _openCalibration() {
    showDialog(
      context: context,
      builder: (ctx) => CalibrationDialog(controller: widget.motionController),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = kidScale(context);
    final pad = MediaQuery.paddingOf(context); // tránh tai thỏ / notch / thanh điều hướng

    return Scaffold(
      backgroundColor: const Color(0xFF6EC6FF), // trùng màu trời của canvas
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Sân bóng, khán đài & khung thành
          // RepaintBoundary: canvas vẽ lại mỗi khung, HUD phía trên không phải vẽ lại theo
          RepaintBoundary(
            child: CustomPaint(
              painter: PenaltyCanvasPainter(
                engine: _engine,
                animationValue: _animationValue,
                ballImage: _ballImage,
              ),
            ),
          ),

          // 2. HUD TRÊN CÙNG: Back | Mạng + Bàn thắng + Điểm | Camera | Pause
          _buildTopBar(s, pad),

          // 3. Camera PiP góc phải, ngay dưới thanh HUD
          CameraPipOverlay(
            motionController: widget.motionController,
            onCalibrate: _openCalibration,
            top: pad.top + _hudMargin * s + (_hudButtonSize * 1.09) * s + 8,
            right: pad.right + _hudMargin * s,
          ),

          // 4. Logo công ty: góc dưới trái
          Positioned(
            left: pad.left + _hudMargin * s,
            bottom: pad.bottom + 8 * s,
            child: CompanyLogoBadge(width: _logoW * s, height: _logoH * s),
          ),

          // 5. Thỏ linh vật + bóng thoại: đọc đề / ăn mừng khi vào / buồn khi sút nhầm
          //    Đứng trên logo góc dưới trái, bóng thoại bên phải trên mặt sân (không che khung thành)
          _buildRabbitMascot(s, pad),

          // 6. Nút sút cảm ứng (mặc định ẩn, chỉ hiện nếu bật trong Cài đặt)
          ListenableSelector(
            listenable: widget.motionController,
            selector: () => widget.motionController.showTouchControls,
            builder: (context, _) {
              if (!widget.motionController.showTouchControls) return const SizedBox.shrink();
              return Positioned(
                right: pad.right + 20 * s,
                bottom: pad.bottom + 20 * s,
                child: SizedBox(
                  width: 150 * s,
                  child: KidButton(
                    icon: Icons.sports_soccer,
                    label: 'KICK!',
                    color: KidColors.pink,
                    shadowColor: KidColors.pinkDark,
                    height: 64 * s,
                    onPressed: () {
                      if (_readyGate.isDone) _engine.touchShoot(); // chưa "GO!" thì chưa cho sút
                    },
                  ),
                ),
              );
            },
          ),

          // 6b. Điểm bay về ô tổng điểm
          Positioned.fill(
            child: ScoreFlyLayer(
              key: _flyLayerKey,
              targetKey: _scoreKey,
              onArrive: () {
                if (mounted) setState(() => _shownScore = _engine.score);
              },
            ),
          ),

          // 6c. Chuẩn bị đầu ván: chờ thấy mặt / tay -> đếm ngược 3-2-1 -> GO!
          Positioned.fill(
            child: IgnorePointer(
              child: ListenableBuilder(
                listenable: _readyGate,
                builder: (context, _) => ReadyGateOverlay(
                  gate: _readyGate,
                  inputMode: widget.motionController.inputMode,
                  scale: s,
                  goEmoji: '⚽',
                ),
              ),
            ),
          ),

          // 7. Tạm dừng
          ListenableSelector(
            listenable: _engine,
            selector: () => _engine.isPaused,
            builder: (context, _) {
              if (!_engine.isPaused) return const SizedBox.shrink();
              return KidDialog(
                mascot: RabbitMascot.images[RabbitMood.normal],
                accent: KidColors.blue,
                children: [
                  _dialogTitle('PAUSED', KidColors.blueDark, s),
                  SizedBox(height: 6 * s),
                  Text(
                    'Take a little rest! ⚽',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: KidColors.textSoft, fontSize: 15 * s, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 18 * s),
                  _buildActionRow(
                    s: s,
                    primaryIcon: Icons.play_arrow_rounded,
                    primaryLabel: 'PLAY',
                    onPrimary: () {
                      SoundService.instance.playClick();
                      _engine.resumeGame();
                    },
                    showHome: true,
                  ),
                ],
              );
            },
          ),

          // 8. Kết thúc (Endless mode): lời khen tích cực cho bé, kể cả khi không phá kỷ lục
          ListenableSelector(
            listenable: _engine,
            selector: () => (_engine.isGameOver, _engine.isNewHighScore, _engine.score, _engine.goals, _engine.highScore),
            builder: (context, _) {
              if (!_engine.isGameOver) return const SizedBox.shrink();
              final isRecord = _engine.isNewHighScore;
              return KidDialog(
                mascot: RabbitMascot.images[isRecord ? RabbitMood.happy : RabbitMood.normal],
                accent: isRecord ? KidColors.yellow : KidColors.pink,
                children: [
                  _dialogTitle(isRecord ? 'NEW RECORD! 🏆' : 'GOOD TRY! 🌟', isRecord ? KidColors.orangeDark : KidColors.pinkDark, s),
                  SizedBox(height: 8 * s),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.star_rounded, color: KidColors.yellow, size: 40 * s),
                      SizedBox(width: 4 * s),
                      Text(
                        '${_engine.score}',
                        style: TextStyle(color: KidColors.text, fontSize: 42 * s, fontWeight: FontWeight.w900, height: 1.0),
                      ),
                    ],
                  ),
                  SizedBox(height: 12 * s),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8 * s,
                    runSpacing: 6 * s,
                    children: [
                      _buildStatChip('⚽', '${_engine.goals} goals', KidColors.green, s),
                      _buildStatChip('🏆', 'Best ${_engine.highScore}', KidColors.orange, s),
                    ],
                  ),
                  SizedBox(height: 18 * s),
                  _buildActionRow(
                    s: s,
                    primaryIcon: Icons.replay_rounded,
                    primaryLabel: 'PLAY AGAIN',
                    onPrimary: () {
                      SoundService.instance.playClick();
                      _restart();
                    },
                    showHome: true,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TOP BAR
  // ===========================================================================
  Widget _buildTopBar(double s, EdgeInsets pad) {
    final btn = _hudButtonSize * s;
    final gap = 8 * s;

    return Positioned(
      top: pad.top + _hudMargin * s,
      left: pad.left + _hudMargin * s,
      right: pad.right + _hudMargin * s,
      child: ListenableSelector(
        listenable: _engine,
        selector: () => (_engine.lives, _engine.goals, _engine.streak, _engine.isPaused),
        builder: (context, _) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              KidIconButton(
                icon: Icons.arrow_back_rounded,
                color: KidColors.orange,
                shadowColor: KidColors.orangeDark,
                size: btn,
                tooltip: 'Back',
                onPressed: () {
                  SoundService.instance.playClick();
                  Navigator.of(context).pop();
                },
              ),

              // Từ mục tiêu do thỏ đọc trong bóng thoại -> thanh HUD không hiện lại
              const Spacer(),

              // MẠNG + BÀN THẮNG (+ chuỗi) + ĐIỂM
              SizedBox(
                height: btn,
                child: KidPanel(
                  padding: EdgeInsets.symmetric(horizontal: 12 * s),
                  radius: btn / 2,
                  borderWidth: 3 * s,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LivesHearts(
                        lives: _engine.lives,
                        maxLives: PenaltyEngine.maxLives,
                        size: 22 * s,
                        emptyColor: const Color(0xFFD7CCC8),
                      ),
                      _hudDivider(s, btn),
                      Text('⚽', style: TextStyle(fontSize: 17 * s)),
                      SizedBox(width: 4 * s),
                      Text(
                        '${_engine.goals}',
                        style: TextStyle(color: KidColors.text, fontSize: 18 * s, fontWeight: FontWeight.w900),
                      ),
                      if (_engine.streak > 1) ...[
                        SizedBox(width: 6 * s),
                        Text(
                          '🔥x${_engine.streak}',
                          style: TextStyle(color: KidColors.orangeDark, fontSize: 14 * s, fontWeight: FontWeight.w900),
                        ),
                      ],
                      _hudDivider(s, btn),
                      Icon(Icons.star_rounded, color: KidColors.yellow, size: 24 * s),
                      SizedBox(width: 3 * s),
                      _AnimatedScore(key: _scoreKey, score: _shownScore, fontSize: 19 * s),
                    ],
                  ),
                ),
              ),

              SizedBox(width: gap),

              // ẨN/HIỆN CAMERA
              ListenableSelector(
                listenable: widget.motionController,
                selector: () => widget.motionController.showCameraPip,
                builder: (context, _) {
                  final bool isCamVisible = widget.motionController.showCameraPip;
                  return KidIconButton(
                    icon: isCamVisible ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                    color: isCamVisible ? KidColors.blue : KidColors.grey,
                    shadowColor: isCamVisible ? KidColors.blueDark : KidColors.greyDark,
                    size: btn,
                    tooltip: isCamVisible ? 'Hide camera' : 'Show camera',
                    onPressed: () {
                      SoundService.instance.playClick();
                      widget.motionController.showCameraPip = !isCamVisible;
                    },
                  );
                },
              ),

              SizedBox(width: gap),

              KidIconButton(
                icon: _engine.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                color: KidColors.green,
                shadowColor: KidColors.greenDark,
                size: btn,
                tooltip: _engine.isPaused ? 'Play' : 'Pause',
                onPressed: () {
                  SoundService.instance.playClick();
                  _engine.isPaused ? _engine.resumeGame() : _engine.pauseGame();
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _hudDivider(double s, double btn) => Container(
        width: 2 * s,
        height: btn * 0.45,
        margin: EdgeInsets.symmetric(horizontal: 10 * s),
        decoration: BoxDecoration(color: const Color(0xFFEFDFBF), borderRadius: BorderRadius.circular(2)),
      );

  // ===========================================================================
  // THỎ LINH VẬT: biểu cảm theo kết quả cú sút, lời thoại lấy từ banner của engine
  // ===========================================================================
  Widget _buildRabbitMascot(double s, EdgeInsets pad) {
    final size = MediaQuery.sizeOf(context);
    final rabbitH = math.min(size.height * 0.3, 210.0).clamp(80.0, 210.0);
    final rabbitW = rabbitH * 0.64;
    final logoW = _logoW * s;
    // Bóng thoại nằm trên mặt sân bên trái, không lấn sang vùng bóng ở giữa sân
    final bubbleMaxW = math.max(size.width * 0.42 - rabbitW - pad.left, 160.0);

    return Positioned(
      // Căn giữa thỏ trên logo
      left: pad.left + _hudMargin * s + math.max(0.0, (logoW - rabbitW) / 2),
      bottom: pad.bottom + 8 * s + _logoH * s + 2,
      child: ListenableSelector(
        listenable: _engine,
        selector: () => (_engine.currentTargetFruit, _engine.currentOutcome, _engine.bannerSubtitle),
        builder: (context, _) {
          final target = _engine.currentTargetFruit;
          if (target == null) return const SizedBox.shrink();

          return switch (_engine.currentOutcome) {
            ShotOutcome.goal => RabbitMascot(
                mood: RabbitMood.happy,
                headline: 'GOAL! ⚽',
                footnote: 'Great job! ${target.emoji} ${target.name}',
                rabbitHeight: rabbitH,
                bubbleMaxWidth: bubbleMaxW,
                textScale: s,
              ),
            ShotOutcome.wrongTarget => RabbitMascot(
                mood: RabbitMood.sad,
                headline: 'OOPS!',
                footnote: _engine.bannerSubtitle, // hé lộ ô vừa sút & đáp án đúng
                rabbitHeight: rabbitH,
                bubbleMaxWidth: bubbleMaxW,
                textScale: s,
              ),
            // Chỉ chữ, không hình: bé phải nghe & đọc để tìm đúng hình
            _ => RabbitMascot(
                mood: RabbitMood.normal,
                caption: 'Kick the ball to the',
                headline: target.name,
                rabbitHeight: rabbitH,
                bubbleMaxWidth: bubbleMaxW,
                textScale: s,
              ),
          };
        },
      ),
    );
  }

  // ===========================================================================
  // DIALOG HELPERS (Pause & Kết thúc dùng chung 1 kiểu)
  // ===========================================================================
  Widget _dialogTitle(String text, Color color, double s) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(color: color, fontSize: 28 * s, fontWeight: FontWeight.w900, letterSpacing: 1.2, height: 1.1),
    );
  }

  Widget _buildActionRow({
    required double s,
    required IconData primaryIcon,
    required String primaryLabel,
    required VoidCallback onPrimary,
    bool showHome = false,
  }) {
    final h = 52 * s;
    return Row(
      children: [
        if (showHome) ...[
          KidButton(
            icon: Icons.home_rounded,
            color: KidColors.orange,
            shadowColor: KidColors.orangeDark,
            height: h,
            onPressed: () {
              SoundService.instance.playClick();
              Navigator.of(context).pop();
            },
          ),
          SizedBox(width: 10 * s),
        ],
        Expanded(
          child: KidButton(
            icon: primaryIcon,
            label: primaryLabel,
            color: KidColors.green,
            shadowColor: KidColors.greenDark,
            height: h,
            onPressed: onPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildStatChip(String emoji, String label, Color color, double s) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12 * s, vertical: 6 * s),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16 * s),
        border: Border.all(color: color, width: 2 * s),
      ),
      child: Text(
        '$emoji $label',
        style: TextStyle(color: KidColors.text, fontSize: 14 * s, fontWeight: FontWeight.w800),
      ),
    );
  }
}

/// Số điểm trên HUD: nảy lên mỗi khi giá trị tăng (lúc điểm bay tới nơi)
class _AnimatedScore extends StatelessWidget {
  final int score;
  final double fontSize;

  const _AnimatedScore({super.key, required this.score, this.fontSize = 18});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(score),
      tween: Tween(begin: score == 0 ? 1.0 : 1.45, end: 1.0),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: Text(
        '$score',
        style: TextStyle(color: KidColors.text, fontSize: fontSize, fontWeight: FontWeight.w900),
      ),
    );
  }
}
