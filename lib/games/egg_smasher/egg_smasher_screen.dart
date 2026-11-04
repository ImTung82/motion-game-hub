import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../motion/face_motion_controller.dart';
import '../../services/sound_service.dart';
import '../../ui/widgets/calibration_dialog.dart';
import '../../ui/widgets/camera_pip_overlay.dart';
import '../../ui/widgets/company_logo_badge.dart';
import '../../ui/widgets/kid_ui.dart';
import '../../ui/widgets/rabbit_mascot.dart';
import '../../ui/widgets/lives_hearts.dart';
import '../../ui/widgets/ready_gate.dart';
import '../../ui/widgets/score_fly_layer.dart';
import 'egg_smasher_canvas.dart';
import 'egg_smasher_engine.dart';

class EggSmasherScreen extends StatefulWidget {
  final FaceMotionController motionController;

  const EggSmasherScreen({super.key, required this.motionController});

  @override
  State<EggSmasherScreen> createState() => _EggSmasherScreenState();
}

class _EggSmasherScreenState extends State<EggSmasherScreen> with SingleTickerProviderStateMixin {
  late final EggSmasherEngine _engine;
  final ReadyGate _readyGate = ReadyGate();
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  double _animationValue = 0.0;

  // Điểm bay: điểm trên HUD chỉ tăng khi "+N" bay tới nơi
  final GlobalKey<ScoreFlyLayerState> _flyLayerKey = GlobalKey<ScoreFlyLayerState>();
  final GlobalKey _scoreKey = GlobalKey();
  int _shownScore = 0;

  // Trạng thái PiP camera trước khi vào game (để khôi phục cho các game khác)
  bool _prevShowCameraPip = true;

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
    _engine = EggSmasherEngine();
    _engine.onScored = _onScored;
    _engine.startGame(announce: false);
    _readyGate.onGo = _engine.announceTarget; // đọc từ khi bé đã vào vị trí

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
    if (!_engine.isPaused) _readyGate.update(clampedDt, ctrl.state, cameraAvailable: ctrl.cameraAvailable);
    if (!_readyGate.isDone) return; // chưa thấy mặt / tay hoặc đang đếm ngược: game đứng yên

    _engine.update(clampedDt, ctrl.state);
  }

  static const _bgAsset = AssetImage('assets/images/bg_egg_smasher.png');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(_bgAsset, context); // nạp sẵn ảnh nền để không bị nháy khung trống
  }

  @override
  void dispose() {
    widget.motionController.setCameraPipQuietly(_prevShowCameraPip, persist: true);
    _ticker.dispose();
    _readyGate.dispose();
    _engine.dispose();
    super.dispose();
  }

  // Ảnh nền 1672x941, mặt cỏ phẳng bắt đầu ~83% chiều cao ảnh -> đặt tâm tổ trứng ở ~87.5% ảnh
  static const double _bgAspect = 1672 / 941;
  static const double _bgNestY = 0.875;

  /// Độ cao tâm tổ trứng trên MÀN HÌNH (tỉ lệ), tính theo cách ảnh nền được phủ kín (cover, neo đáy):
  /// màn rộng hơn ảnh -> ảnh bị phóng theo bề ngang và cắt bớt phía trên -> mặt cỏ dời lên trên màn hình
  double _nestGroundY(Size size) {
    if (size.height <= 0) return 0.75 + EggSmasherEngine.eggRadiusY * EggSmasherEngine.nestOffsetFactor;
    final imageHeightRatio = math.max(1.0, (size.width / size.height) / _bgAspect);
    return 1.0 - (1.0 - _bgNestY) * imageHeightRatio;
  }

  void _onScored(int gained, int streak, double nx, double ny) {
    final size = MediaQuery.of(context).size;
    _flyLayerKey.currentState?.spawn(
      Offset(nx * size.width, ny * size.height),
      '+$gained',
      subText: streak > 1 ? '🔥 x$streak' : null,
    );
  }

  void _restart() {
    setState(() => _shownScore = 0);
    _engine.startGame(announce: false);
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
      backgroundColor: const Color(0xFF8ED1F5), // trùng màu trời của ảnh nền (khi ảnh chưa kịp hiện)
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 0. ẢNH NỀN BÃI CỎ: neo đáy để bãi cỏ (nơi đặt tổ trứng) luôn hiện, màn dài thì cắt bớt trời
          const Positioned.fill(
            child: Image(
              image: _bgAsset,
              fit: BoxFit.cover,
              alignment: Alignment.bottomCenter,
              filterQuality: FilterQuality.medium,
            ),
          ),

          // 1. VÙNG GAME CANVAS (chạm để đập CHỈ khi bật "touch buttons" trong Cài đặt)
          LayoutBuilder(
            builder: (context, constraints) {
              _engine.setNestGroundY(_nestGroundY(constraints.biggest));
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) {
                  if (!widget.motionController.showTouchControls) return; // tắt cảm ứng: chỉ chơi bằng cử chỉ
                  if (!_readyGate.isDone) return; // chưa "GO!"
                  final px = details.localPosition.dx / constraints.maxWidth;
                  final py = details.localPosition.dy / constraints.maxHeight;
                  _engine.triggerSmashDirect(px, py);
                },
                child: CustomPaint(
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                  painter: EggSmasherCanvasPainter(
                    engine: _engine,
                    animationValue: _animationValue,
                  ),
                ),
              );
            },
          ),

          // 2. HUD TRÊN CÙNG: Back | Mạng + Điểm | Camera | Pause
          _buildTopBar(s, pad),

          // 3. PIP CAMERA (góc trên phải, ngay dưới thanh HUD)
          CameraPipOverlay(
            motionController: widget.motionController,
            onCalibrate: _openCalibration,
            top: pad.top + _hudMargin * s + (_hudButtonSize * 1.09) * s + 8,
            right: pad.right + _hudMargin * s,
            showNodMode: true,
          ),

          // 4. LOGO CÔNG TY: góc dưới trái, ngoài vùng chơi chính
          Positioned(
            left: pad.left + _hudMargin * s,
            bottom: pad.bottom + 8 * s,
            child: CompanyLogoBadge(width: _logoW * s, height: _logoH * s),
          ),

          // 5. THỎ LINH VẬT + BÓNG THOẠI: đọc đề / khen khi đập đúng / buồn khi đập sai
          //    Đứng trên logo ở góc dưới trái, bóng thoại phía trên (vùng trời, không che trứng)
          _buildRabbitMascot(s, pad),

          // 5b. ĐIỂM BAY VỀ Ô TỔNG ĐIỂM
          Positioned.fill(
            child: ScoreFlyLayer(
              key: _flyLayerKey,
              targetKey: _scoreKey,
              onArrive: () {
                if (mounted) setState(() => _shownScore = _engine.score);
              },
            ),
          ),

          // 5c. CHUẨN BỊ ĐẦU VÁN: chờ thấy mặt / tay -> đếm ngược 3-2-1 -> GO!
          Positioned.fill(
            child: IgnorePointer(
              child: ListenableBuilder(
                listenable: _readyGate,
                builder: (context, _) => ReadyGateOverlay(
                  gate: _readyGate,
                  inputMode: widget.motionController.inputMode,
                  scale: s,
                  goEmoji: '🔨',
                ),
              ),
            ),
          ),

          // 6. TẠM DỪNG
          ListenableBuilder(
            listenable: _engine,
            builder: (context, _) {
              if (!_engine.isPaused) return const SizedBox.shrink();
              return KidDialog(
                mascot: RabbitMascot.images[RabbitMood.normal],
                accent: KidColors.blue,
                children: [
                  _dialogTitle('PAUSED', KidColors.blueDark, s),
                  SizedBox(height: 6 * s),
                  Text(
                    'Take a little rest! 🌼',
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
                  ),
                ],
              );
            },
          ),

          // 7. KẾT THÚC (Endless mode): lời khen tích cực cho bé, kể cả khi không phá kỷ lục
          ListenableBuilder(
            listenable: _engine,
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
                    crossAxisAlignment: CrossAxisAlignment.center,
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
                      _buildStatChip('🥚', '${_engine.eggsSmashed} words', KidColors.green, s),
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
      child: ListenableBuilder(
        listenable: _engine,
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

              // MẠNG + ĐIỂM
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
                        maxLives: EggSmasherEngine.maxLives,
                        size: 22 * s,
                        emptyColor: const Color(0xFFD7CCC8),
                      ),
                      Container(
                        width: 2 * s,
                        height: btn * 0.45,
                        margin: EdgeInsets.symmetric(horizontal: 10 * s),
                        decoration: BoxDecoration(color: const Color(0xFFEFDFBF), borderRadius: BorderRadius.circular(2)),
                      ),
                      Icon(Icons.star_rounded, color: KidColors.yellow, size: 24 * s),
                      SizedBox(width: 3 * s),
                      _AnimatedScore(key: _scoreKey, score: _shownScore, fontSize: 19 * s),
                    ],
                  ),
                ),
              ),

              SizedBox(width: gap),

              // ẨN/HIỆN CAMERA
              ListenableBuilder(
                listenable: widget.motionController,
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
                  if (_engine.isPaused) {
                    _engine.resumeGame();
                  } else {
                    _engine.pauseGame();
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  // ===========================================================================
  // THỎ LINH VẬT
  // ===========================================================================
  static const List<String> _praises = ['GREAT JOB!', 'AWESOME!', 'YAY! 🎉', 'SUPER!', 'WELL DONE!'];

  Widget _buildRabbitMascot(double s, EdgeInsets pad) {
    final size = MediaQuery.sizeOf(context);
    // Thỏ cao ~30% màn hình nhưng không rộng quá ~11% bề ngang (trứng trái bắt đầu từ ~12%)
    final rabbitH = math.min(math.min(size.height * 0.3, size.width * 0.11 / 0.64), 210.0).clamp(80.0, 210.0);
    final rabbitW = rabbitH * 0.64;
    final logoW = _logoW * s;

    return Positioned(
      // Căn giữa thỏ trên logo
      left: pad.left + _hudMargin * s + math.max(0.0, (logoW - rabbitW) / 2),
      bottom: pad.bottom + 8 * s + _logoH * s + 2,
      child: ListenableBuilder(
        listenable: _engine,
        builder: (context, _) {
          final target = _engine.currentTarget;
          if (target == null) return const SizedBox.shrink();

          RabbitMood mood = RabbitMood.normal;
          String? caption = 'Smash the egg:';
          String headline = target.word;
          String? footnote;

          if (_engine.isRoundTransition && _engine.lastSmashCorrect) {
            mood = RabbitMood.happy;
            caption = null;
            headline = _praises[_engine.eggsSmashed % _praises.length];
            footnote = '${target.iconEmoji} ${target.word}';
          } else if (_engine.isRoundTransition || _engine.lives == 0) {
            // Đập sai: hé lộ đáp án đúng rồi sang từ tiếp theo
            mood = RabbitMood.sad;
            caption = null;
            headline = 'OOPS!';
            footnote = _engine.lives > 0 ? 'It was ${target.iconEmoji} ${target.word}' : 'Out of lives! 💔';
          }

          return RabbitMascot(
            mood: mood,
            caption: caption,
            headline: headline,
            footnote: footnote,
            rabbitHeight: rabbitH,
            bubbleMaxWidth: math.max(size.width * 0.3, 170.0),
            tail: BubbleTail.bottom,
            textScale: s,
          );
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
      style: TextStyle(
        color: color,
        fontSize: 28 * s,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.2,
        height: 1.1,
      ),
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
        style: TextStyle(color: KidColors.text, fontWeight: FontWeight.w900, fontSize: fontSize),
      ),
    );
  }
}
