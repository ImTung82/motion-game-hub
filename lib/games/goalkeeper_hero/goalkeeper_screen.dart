import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../motion/face_motion_controller.dart';
import '../../services/music_service.dart';
import '../../services/sound_service.dart';
import '../../ui/widgets/calibration_dialog.dart';
import '../../ui/widgets/camera_pip_overlay.dart';
import '../../ui/widgets/company_logo_badge.dart';
import '../../ui/widgets/kid_ui.dart';
import '../../ui/widgets/lives_hearts.dart';
import '../../ui/widgets/listenable_selector.dart';
import '../../ui/widgets/rabbit_mascot.dart';
import '../../ui/widgets/ready_gate.dart';
import '../../ui/widgets/score_fly_layer.dart';
import '../../ui/widgets/touch_hint.dart';
import 'goalkeeper_canvas.dart';
import 'goalkeeper_engine.dart';
import 'goalkeeper_models.dart';

class GoalkeeperScreen extends StatefulWidget {
  final FaceMotionController motionController;

  const GoalkeeperScreen({super.key, required this.motionController});

  @override
  State<GoalkeeperScreen> createState() => _GoalkeeperScreenState();
}

class _GoalkeeperScreenState extends State<GoalkeeperScreen> with SingleTickerProviderStateMixin {
  late final GoalkeeperEngine _engine;
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;

  // Điểm bay: số sao trên HUD chỉ tăng khi "+N⭐" bay tới nơi
  final GlobalKey<ScoreFlyLayerState> _flyLayerKey = GlobalKey<ScoreFlyLayerState>();
  final GlobalKey _scoreKey = GlobalKey();
  int _shownScore = 0;

  // Thỏ nói "Oops!" một lúc sau khi lọt lưới
  double _oopsTimer = 0.0;

  // Mốc số sao để nhận 1 / 2 / 3 cúp cuối ván
  static const List<int> _cupThresholds = [3, 10, 20];

  // Ảnh quả bóng nạp sẵn
  static const _ballAsset = ResizeImage(AssetImage('assets/images/soccer_ball.png'), width: 192, height: 192);
  ImageStream? _ballStream;
  ImageStreamListener? _ballListener;
  ui.Image? _ballImage;

  // Kích thước HUD chuẩn
  static const double _hudButtonSize = 46;
  static const double _hudMargin = 12;

  bool _prevShowCameraPip = true;


  late final Object _music;

  /// Màn kết quả: nhạc nền nhỏ đi (engine báo mỗi khung, MusicService bỏ qua khi không đổi)
  void _syncMusic() => MusicService.instance.setQuiet(_engine.isGameOver);

  @override
  void initState() {
    super.initState();
    _music = MusicService.instance.push(MusicTrack.goalkeeperHero);
    _prevShowCameraPip = widget.motionController.showCameraPip;
    widget.motionController.setCameraPipQuietly(false);

    // Engine bắt đầu ở màn chọn mức độ & chủ đề, bấm PLAY mới vào ván
    _engine = GoalkeeperEngine();
    _engine.onBallSaved = _onBallSaved;
    _engine.onGoalConceded = _onGoalConceded;
    _engine.onGameOver = _onGameOver;
    _engine.addListener(_syncMusic);

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

    if (_oopsTimer > 0) {
      _oopsTimer -= clampedDt;
      if (_oopsTimer <= 0) setState(() {});
    }

    _engine.update(clampedDt, widget.motionController.state, touchMode: widget.motionController.touchMode);
  }

  // ---------------------------------------------------------------------------
  // CHƠI CHẠM / CHUỘT: chạm, kéo hoặc rê chuột tới đâu thì đôi găng tới đó
  // ---------------------------------------------------------------------------
  bool _touchUsed = false; // đã chạm lần đầu -> ẩn gợi ý

  bool get _acceptsTouch =>
      widget.motionController.touchMode &&
      !_engine.isPaused &&
      (_engine.phase == KeeperPhase.countdown || _engine.phase == KeeperPhase.playing);

  void _onPointer(PointerEvent e) {
    if (!_acceptsTouch) return;
    // Chuột rê ngang qua (chưa bấm) cũng điều khiển được, nhưng không tính là "đã chạm" để ẩn gợi ý
    if (e is! PointerHoverEvent && !_touchUsed) setState(() => _touchUsed = true);
    _engine.touchMoveTo(e.localPosition);
  }

  void _startGame() {
    SoundService.instance.playClick();
    setState(() {
      _shownScore = 0;
      _oopsTimer = 0.0;
      _touchUsed = false;
      _engine.startGame();
    });
  }

  void _onBallSaved(SaveEvent event) {
    if (_oopsTimer > 0) setState(() => _oopsTimer = 0.0);

    // Thả sao bay tới HUD
    _flyLayerKey.currentState?.spawn(
      _engine.layout.toScreen(event.screenPosition.dx, event.screenPosition.dy),
      '+${event.starsGained}⭐',
      subText: event.isSuperCatch ? 'SUPER CATCH!' : 'SAVE!',
      color: event.isSuperCatch ? Colors.amberAccent : const Color(0xFF00E5FF),
    );
  }

  void _onGoalConceded() {
    if (mounted) setState(() => _oopsTimer = 1.4);
  }

  void _onGameOver() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
    _engine.removeListener(_syncMusic);
    _engine.dispose();
    MusicService.instance.pop(_music);
    super.dispose();
  }

  void _openCalibration() {
    showDialog(
      context: context,
      builder: (ctx) => CalibrationDialog(
        controller: widget.motionController,
        initialDualHand: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = kidScale(context);
    final pad = MediaQuery.paddingOf(context);

    return Scaffold(
      backgroundColor: const Color(0xFF6EC6FF),
      // Listener bọc cả màn: chạm / kéo / rê chuột ở đâu (kể cả trên thỏ, banner) găng cũng tới đó.
      // Listener không giành sự kiện nên các nút HUD vẫn bấm bình thường.
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _onPointer,
        onPointerMove: _onPointer,
        onPointerHover: _onPointer,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. GAME CANVAS 60 FPS (VẼ SÂN VẬN ĐỘNG & BÓNG BAY TOÀN MÀN HÌNH)
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Engine tính va chạm theo pixel nên cần biết kích thước vùng vẽ
                  _engine.layout = KeeperLayout(constraints.biggest);
                  // RepaintBoundary: canvas vẽ lại mỗi khung, HUD phía trên không phải vẽ lại theo
                  return RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: _engine,
                      builder: (context, _) => GoalkeeperCanvas(
                        engine: _engine,
                        ballImage: _ballImage,
                      ),
                    ),
                  );
                },
              ),
            ),

            // Lớp phủ sao bay về ô tổng sao
            Positioned.fill(
              child: ScoreFlyLayer(
                key: _flyLayerKey,
                targetKey: _scoreKey,
                onArrive: () {
                  if (mounted) setState(() => _shownScore = _engine.score);
                },
              ),
            ),

            // 2. MASCOT THỎ CỔ VŨ Ở GÓC DƯỚI TRÁI
            Positioned(
              left: pad.left + 12 * s,
              bottom: pad.bottom + 8 * s,
              child: ListenableSelector(
                listenable: _engine,
                selector: () => (_engine.phase, _engine.streak, _engine.lives),
                builder: (context, _) => _buildMascot(s),
              ),
            ),

            // 4. CHỜ GIƠ 2 TAY / ĐẾM NGƯỢC 3-2-1 / LỜI NHẮC KHI MẤT TAY
            Positioned.fill(
              child: IgnorePointer(
                child: ListenableSelector(
                  listenable: _engine,
                  selector: () => (
                    _engine.phase,
                    _engine.readyProgress,
                    _engine.countdownNumber,
                    _engine.countdownFraction,
                    _engine.goFlash,
                    _engine.leftGlove.detected,
                    _engine.rightGlove.detected,
                    widget.motionController.state.handsCount == 0,
                    widget.motionController.touchMode,
                  ),
                  builder: (context, _) => _buildPhaseOverlay(s, pad),
                ),
              ),
            ),

            // 4b. GỢI Ý CHƠI CHẠM (ẩn sau lần chạm đầu): dưới chân khung thành
            if (!_touchUsed)
              ListenableSelector(
                listenable: Listenable.merge([widget.motionController, _engine]),
                selector: () => widget.motionController.touchMode && _engine.phase == KeeperPhase.playing,
                builder: (context, _) {
                  if (!widget.motionController.touchMode || _engine.phase != KeeperPhase.playing) {
                    return const SizedBox.shrink();
                  }
                  return Align(
                    alignment: const Alignment(0, 0.86),
                    child: TouchHint(text: 'Move the gloves to the ball!', scale: s),
                  );
                },
              ),

            // 5. HUD HEADER (LOGO, BACK, TIM MẠNG, SỐ SAO, CÀI ĐẶT)
            Positioned(
              top: pad.top + _hudMargin * s,
              left: pad.left + _hudMargin * s,
              right: pad.right + _hudMargin * s,
              child: _buildTopHud(s),
            ),

            // 6. CAMERA PIP OVERLAY
            CameraPipOverlay(
              motionController: widget.motionController,
              onCalibrate: _openCalibration,
              top: pad.top + _hudMargin * s + (_hudButtonSize * 1.09) * s + 8,
              right: pad.right + _hudMargin * s,
            ),

            // 7. CHỌN MỨC ĐỘ & CHỦ ĐỀ TRƯỚC KHI CHƠI
            ListenableSelector(
              listenable: _engine,
              selector: () => (_engine.phase, _engine.difficulty),
              builder: (context, _) {
                if (_engine.phase != KeeperPhase.setup) return const SizedBox.shrink();
                return _buildSetupDialog(s);
              },
            ),

            // 8. TẠM DỪNG (PAUSED DIALOG)
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
                      'Take a little rest, Keeper! 🧤',
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
                        _engine.resume();
                      },
                      showHome: true,
                    ),
                  ],
                );
              },
            ),

            // 9. KẾT THÚC (GAME OVER DIALOG)
            ListenableSelector(
              listenable: _engine,
              selector: () => (
                _engine.isGameOver,
                _engine.score,
                _engine.highScore,
                _engine.isNewHighScore,
              ),
              builder: (context, _) {
                if (!_engine.isGameOver) return const SizedBox.shrink();
                return _buildGameOverDialog(s);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // CHỌN MỨC ĐỘ
  // ===========================================================================
  Widget _buildSetupDialog(double s) {
    return KidDialog(
      mascot: RabbitMascot.images[RabbitMood.happy],
      accent: KidColors.green,
      children: [
        _dialogTitle('GOALKEEPER HERO 🧤', KidColors.greenDark, s),
        SizedBox(height: 12 * s),
        _sectionLabel('LEVEL', s),
        SizedBox(height: 6 * s),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8 * s,
          runSpacing: 6 * s,
          children: [
            for (final d in KeeperDifficulty.values)
              _buildOptionChip(
                emoji: d.emoji,
                label: d.label,
                selected: _engine.difficulty == d,
                color: KidColors.blue,
                onTap: () => _engine.setDifficulty(d),
                s: s,
              ),
          ],
        ),
        SizedBox(height: 18 * s),
        _buildActionRow(
          s: s,
          primaryIcon: Icons.play_arrow_rounded,
          primaryLabel: 'PLAY',
          onPrimary: _startGame,
          showHome: true,
        ),
      ],
    );
  }

  Widget _sectionLabel(String text, double s) {
    return Text(
      text,
      style: TextStyle(color: KidColors.textSoft, fontSize: 12 * s, fontWeight: FontWeight.w900, letterSpacing: 1.5),
    );
  }

  Widget _buildOptionChip({
    required String emoji,
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
    required double s,
  }) {
    return GestureDetector(
      onTap: () {
        SoundService.instance.playClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: 12 * s, vertical: 7 * s),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(18 * s),
          border: Border.all(color: selected ? Colors.white : color, width: 2.5 * s),
          boxShadow: selected ? [BoxShadow(color: color.withValues(alpha: 0.6), offset: Offset(0, 3 * s))] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: TextStyle(fontSize: 18 * s)),
            SizedBox(width: 5 * s),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : KidColors.text,
                fontSize: 13 * s,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // CHỜ 2 TAY / ĐẾM NGƯỢC / GO! / NHẮC GIƠ TAY
  // ===========================================================================
  Widget _buildPhaseOverlay(double s, EdgeInsets pad) {
    switch (_engine.phase) {
      case KeeperPhase.waitingHands:
        return Center(child: _buildHandsUpPanel(s));
      case KeeperPhase.handsReady:
        return Center(
          child: ReadyConfirmedPanel(
            scale: s,
            progress: _engine.readyProgress,
            icons: const [
              ReadyIcon(emoji: '🤚', color: Color(0xFF00B8D4), label: 'LEFT'),
              ReadyIcon(emoji: '✋', color: Color(0xFFFF4081), label: 'RIGHT'),
            ],
          ),
        );
      case KeeperPhase.countdown:
        final pop = 1.0 + 0.35 * _engine.countdownFraction;
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
                '${_engine.countdownNumber}',
                style: TextStyle(color: KidColors.text, fontSize: 64 * s, fontWeight: FontWeight.w900, height: 1.0),
              ),
            ),
          ),
        );
      case KeeperPhase.playing:
        if (_engine.goFlash > 0) {
          final t = _engine.goFlash.clamp(0.0, 1.0);
          return Center(
            child: Opacity(
              opacity: t,
              child: Transform.scale(
                scale: 1.6 - 0.6 * t,
                child: Text(
                  'GO! ⚽',
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
        if (widget.motionController.state.handsCount == 0 && !widget.motionController.touchMode) {
          return Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.only(top: pad.top + 70 * s),
              child: _buildHandsMissingPrompt(s),
            ),
          );
        }
        return const SizedBox.shrink();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildHandsUpPanel(double s) {
    return KidPanel(
      padding: EdgeInsets.symmetric(horizontal: 26 * s, vertical: 16 * s),
      radius: 28 * s,
      borderWidth: 4 * s,
      borderColor: KidColors.blue,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'HANDS UP! 👐',
            style: TextStyle(color: KidColors.blueDark, fontSize: 28 * s, fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 2 * s),
          // Camera chia đôi màn hình: mỗi tay giữ 1 nửa khung thành (nửa tô màu trên sân)
          Text(
            'One hand on each side',
            style: TextStyle(color: KidColors.textSoft, fontSize: 15 * s, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 10 * s),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHandIndicator('🤚', '◀ LEFT', _engine.leftGlove.detected, const Color(0xFF00B8D4), s),
              SizedBox(width: 28 * s),
              _buildHandIndicator('✋', 'RIGHT ▶', _engine.rightGlove.detected, const Color(0xFFFF4081), s),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHandIndicator(String emoji, String label, bool detected, Color color, double s) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
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
                child: Text(emoji, style: TextStyle(fontSize: 38 * s)),
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
          label,
          style: TextStyle(color: detected ? color : KidColors.textSoft, fontSize: 13 * s, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }

  Widget _buildHandsMissingPrompt(double s) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16 * s, vertical: 8 * s),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(20 * s),
        border: Border.all(color: Colors.amberAccent, width: 2 * s),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('👐', style: TextStyle(fontSize: 22 * s)),
          SizedBox(width: 8 * s),
          Text(
            'Hands up!',
            style: TextStyle(color: Colors.white, fontSize: 15 * s, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // KẾT THÚC VÁN
  // ===========================================================================
  Widget _buildGameOverDialog(double s) {
    final isRecord = _engine.isNewHighScore;
    final cups = _cupThresholds.where((t) => _engine.score >= t).length;

    return KidDialog(
      mascot: RabbitMascot.images[isRecord || cups >= 2 ? RabbitMood.happy : RabbitMood.normal],
      accent: isRecord ? KidColors.yellow : KidColors.pink,
      children: [
        _dialogTitle(
          isRecord ? 'NEW RECORD! 🏆' : 'GREAT GOALKEEPING! 🧤',
          isRecord ? KidColors.orangeDark : KidColors.pinkDark,
          s,
        ),
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
        SizedBox(height: 4 * s),
        // 1-3 cúp theo số sao
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int i = 0; i < _cupThresholds.length; i++)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 3 * s),
                child: Opacity(
                  opacity: i < cups ? 1.0 : 0.22,
                  child: Text('🏆', style: TextStyle(fontSize: 30 * s)),
                ),
              ),
          ],
        ),
        SizedBox(height: 18 * s),
        _buildActionRow(
          s: s,
          primaryIcon: Icons.replay_rounded,
          primaryLabel: 'PLAY', // 3 nút cùng hàng: chữ ngắn để không bị thu nhỏ
          onPrimary: _startGame,
          showHome: true,
          onSettings: () {
            SoundService.instance.playClick();
            setState(() => _shownScore = 0);
            _engine.openSetup();
          },
        ),
      ],
    );
  }

  // ===========================================================================
  // HUD
  // ===========================================================================
  Widget _buildTopHud(double s) {
    return Row(
      children: [
        // Nút Back
        KidIconButton(
          icon: Icons.arrow_back_rounded,
          color: KidColors.orange,
          shadowColor: KidColors.orangeDark,
          size: _hudButtonSize * s,
          onPressed: () {
            SoundService.instance.playClick();
            Navigator.of(context).pop();
          },
        ),
        SizedBox(width: 8 * s),

        // Logo công ty
        Container(
          padding: EdgeInsets.symmetric(horizontal: 6 * s, vertical: 3 * s),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12 * s),
            boxShadow: [BoxShadow(color: const Color(0x33000000), offset: Offset(0, 2 * s))],
          ),
          child: Image(
            image: CompanyLogoBadge.logo,
            height: 32 * s,
            fit: BoxFit.contain,
          ),
        ),
        SizedBox(width: 10 * s),

        // Tim mạng (3 trái tim sinh động)
        LivesHearts(lives: _engine.lives, maxLives: GoalkeeperEngine.maxLives),

        const Spacer(),

        // Bảng số sao
        _buildScoreHud(s),

        SizedBox(width: 8 * s),

        // Nút Bật/Tắt Camera PiP
        ListenableSelector(
          listenable: widget.motionController,
          selector: () => widget.motionController.showCameraPip,
          builder: (context, _) {
            final pipOn = widget.motionController.showCameraPip;
            return KidIconButton(
              icon: pipOn ? Icons.videocam_rounded : Icons.videocam_off_rounded,
              color: pipOn ? KidColors.blue : KidColors.grey,
              shadowColor: pipOn ? KidColors.blueDark : KidColors.greyDark,
              size: _hudButtonSize * s,
              tooltip: pipOn ? 'Hide Camera' : 'Show Camera',
              onPressed: () {
                SoundService.instance.playClick();
                widget.motionController.showCameraPip = !pipOn;
              },
            );
          },
        ),
        SizedBox(width: 8 * s),

        // Nút Mute
        KidIconButton(
          icon: SoundService.instance.isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
          color: SoundService.instance.isMuted ? KidColors.grey : KidColors.yellow,
          shadowColor: SoundService.instance.isMuted ? KidColors.greyDark : KidColors.yellowDark,
          size: _hudButtonSize * s,
          onPressed: () {
            setState(() => SoundService.instance.toggleMute());
          },
        ),
        SizedBox(width: 8 * s),

        // Nút Cài đặt Camera
        KidIconButton(
          icon: Icons.tune_rounded,
          color: KidColors.pink,
          shadowColor: KidColors.pinkDark,
          size: _hudButtonSize * s,
          onPressed: () {
            SoundService.instance.playClick();
            _openCalibration();
          },
        ),
      ],
    );
  }

  Widget _buildScoreHud(double s) {
    return KidPanel(
      key: _scoreKey,
      padding: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 6 * s),
      radius: 18 * s,
      borderColor: KidColors.yellow,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('⭐', style: TextStyle(fontSize: 18 * s)),
          SizedBox(width: 6 * s),
          Text(
            '$_shownScore',
            style: TextStyle(
              fontSize: 20 * s,
              fontWeight: FontWeight.w900,
              color: KidColors.text,
            ),
          ),
          if (_engine.streak >= 2) ...[
            SizedBox(width: 6 * s),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 5 * s, vertical: 1.5 * s),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(8 * s),
              ),
              child: Text(
                '${_engine.streak}x 🔥',
                style: TextStyle(color: Colors.white, fontSize: 10 * s, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMascot(double s) {
    final bool touch = widget.motionController.touchMode;
    RabbitMood mood = RabbitMood.normal;
    String headline = 'READY! 🧤';
    String? caption = 'Guard the goal';
    String? footnote = touch ? 'Move the gloves' : 'Use both hands';

    if (_engine.phase == KeeperPhase.waitingHands) {
      headline = 'HANDS UP! 👐';
      caption = 'One hand';
      footnote = 'on each side';
    } else if (_engine.phase == KeeperPhase.handsReady) {
      mood = RabbitMood.happy;
      headline = 'GREAT! 🎉';
      caption = 'Get ready...';
      footnote = 'Keep both hands up';
    } else if (_oopsTimer > 0) {
      headline = 'OOPS! 🙈';
      caption = 'Never mind!';
      footnote = 'Try the next one';
    } else if (_engine.streak >= 3) {
      mood = RabbitMood.happy;
      headline = 'ON FIRE! 🔥';
      caption = 'You are unstoppable!';
      footnote = '${_engine.streak} Saves in a row!';
    } else if (_engine.lives == 1 && _engine.phase == KeeperPhase.playing) {
      headline = 'LAST CHANCE!';
      caption = 'Focus on the ball';
      footnote = touch ? 'Gloves to the ball!' : 'Block with both hands';
    }

    return RabbitMascot(
      mood: mood,
      caption: caption,
      headline: headline,
      footnote: footnote,
      rabbitHeight: 110 * s,
      bubbleMaxWidth: 150 * s,
      textScale: s * 0.8,
    );
  }

  Widget _dialogTitle(String text, Color color, double s) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(color: color, fontSize: 26 * s, fontWeight: FontWeight.w900, letterSpacing: 1.2, height: 1.1),
    );
  }

  Widget _buildActionRow({
    required double s,
    required IconData primaryIcon,
    required String primaryLabel,
    required VoidCallback onPrimary,
    bool showHome = false,
    VoidCallback? onSettings,
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
        if (onSettings != null) ...[
          // Về màn chọn mức độ & chủ đề
          KidButton(
            icon: Icons.settings_rounded,
            color: KidColors.blue,
            shadowColor: KidColors.blueDark,
            height: h,
            onPressed: onSettings,
          ),
          SizedBox(width: 10 * s),
        ],
        // KidButton có label không tự có chiều rộng (Stack toàn Positioned) -> bắt buộc bọc Expanded
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
}
