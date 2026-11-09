import 'dart:math' as math;
import '../../services/music_service.dart';
import '../../services/sound_service.dart';
import 'package:flutter/material.dart';
import '../../games/penalty_kick/penalty_screen.dart';
import '../../games/egg_smasher/egg_smasher_screen.dart';
import '../../motion/face_motion_controller.dart';
import '../../motion/motion_state.dart';
import '../widgets/calibration_dialog.dart';
import '../widgets/company_logo_badge.dart';
import '../widgets/kid_ui.dart';
import '../widgets/listenable_selector.dart';
import '../widgets/rabbit_mascot.dart';
import 'dual_hand_hub_screen.dart';

class ArcadeHubScreen extends StatefulWidget {
  final FaceMotionController motionController;

  const ArcadeHubScreen({super.key, required this.motionController});

  @override
  State<ArcadeHubScreen> createState() => _ArcadeHubScreenState();
}

class _ArcadeHubScreenState extends State<ArcadeHubScreen> {
  // Màu từng chữ của tiêu đề (cầu vồng kẹo ngọt)
  static const List<Color> _titleColors = [
    Color(0xFFFF6B6B), Color(0xFFFFA94D), Color(0xFFFFC107), Color(0xFF51CF66),
    Color(0xFF339AF0), Color(0xFF9775FA), Color(0xFFF06595),
  ];

  late final Object _music;

  @override
  void initState() {
    super.initState();
    _music = MusicService.instance.push(MusicTrack.hub); // game mở chồng lên => game đổi bài, thoát game thì phát lại
  }

  @override
  void dispose() {
    MusicService.instance.pop(_music);
    super.dispose();
  }

  void _openCalibration() {
    showDialog(
      context: context,
      builder: (ctx) => CalibrationDialog(controller: widget.motionController),
    );
  }

  void _launchGame(Widget screen) {
    SoundService.instance.playClick();
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = kidScale(context);

    return Scaffold(
      backgroundColor: const Color(0xFFB3E5FC),
      body: Stack(
        children: [
          const Positioned.fill(child: KidSkyBackground()),

          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20 * s, vertical: 12 * s),
              // Chỉ build lại khi thứ đang hiển thị đổi (controller báo theo từng khung camera, ~30 lần/giây)
              child: ListenableSelector(
                listenable: widget.motionController,
                selector: () {
                  final ctrl = widget.motionController;
                  final state = ctrl.state;
                  return (ctrl.inputMode, ctrl.cameraAvailable, ctrl.noCamera, state.faceDetected, state.handDetected,
                      state.isChomping, state.isHandFist, state.tiltDirection);
                },
                builder: (context, _) {
                  final ctrl = widget.motionController;
                  final state = ctrl.state;
                  final isHandMode = ctrl.inputMode == MotionInputMode.hand;
                  final noCamera = ctrl.noCamera; // không có camera: hướng dẫn chơi bằng chạm / chuột

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // CỘT TRÁI: Tiêu đề, chọn chế độ, thỏ chào bé, trạng thái camera & cài đặt
                      Expanded(
                        flex: 40,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildTitle(s),
                            SizedBox(height: 10 * s),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildModeSelector(ctrl, isHandMode, s),
                                  SizedBox(width: 8 * s),
                                  _buildDualHandHubButton(context, s),
                                ],
                              ),
                            ),
                            SizedBox(height: 6 * s),
                            // Thỏ chiếm phần còn lại, tự thu nhỏ theo chiều cao màn hình
                            Expanded(child: _buildMascot(ctrl, state, isHandMode, s)),
                            SizedBox(height: 6 * s),
                            _buildCameraStatus(ctrl, state, isHandMode, s),
                            SizedBox(height: 8 * s),
                            _buildSettingsRow(s),
                          ],
                        ),
                      ),

                      SizedBox(width: 16 * s),

                      // CỘT PHẢI: 2 thẻ game
                      Expanded(
                        flex: 60,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final gap = 14 * s;
                            // 2 thẻ luôn hiện đủ trên màn hình (bé không cần biết cuộn ngang);
                            // chỉ màn cực hẹp (< 150px/thẻ) mới phải cuộn
                            final cardW = ((constraints.maxWidth - gap) / 2).clamp(150.0, 360.0 * s);
                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: SizedBox(
                                height: constraints.maxHeight,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _buildGameCard(
                                      s: s,
                                      width: cardW,
                                      title: 'FRUITS KICK',
                                      art: '⚽🍎🍌',
                                      description: 'Listen to the fruit name, then kick the ball into the goal with the matching picture!',
                                      steps: noCamera
                                          ? const [('👆', 'Tap the matching picture to kick')]
                                          : isHandMode
                                              ? const [('✋', 'Move your open hand to aim'), ('✊', 'Make a fist to kick')]
                                              : const [('👤', 'Tilt your head to aim'), ('⬇️', 'Nod or open your mouth to kick')],
                                      color: KidColors.green,
                                      colorDark: KidColors.greenDark,
                                      bannerColors: const [Color(0xFFA5E887), Color(0xFF66BB6A)],
                                      onPlay: () => _launchGame(PenaltyScreen(motionController: widget.motionController)),
                                    ),
                                    SizedBox(width: gap),
                                    _buildGameCard(
                                      s: s,
                                      width: cardW,
                                      title: 'EGG SMASHER',
                                      art: '🥚🔨🐣',
                                      description: 'Listen to the word, then smash the egg with the matching picture to hatch a friend!',
                                      steps: noCamera
                                          ? const [('👆', 'Tap the matching egg to smash')]
                                          : isHandMode
                                              ? const [('✋', 'Move your open hand to pick an egg'), ('✊', 'Make a fist to smash')]
                                              : const [('👤', 'Tilt your head to pick an egg'), ('⬇️', 'Nod down to smash')],
                                      color: KidColors.orange,
                                      colorDark: KidColors.orangeDark,
                                      bannerColors: const [Color(0xFFFFE082), Color(0xFFFFB74D)],
                                      onPlay: () => _launchGame(EggSmasherScreen(motionController: widget.motionController)),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TIÊU ĐỀ: logo + chữ cầu vồng viền trắng
  // ===========================================================================
  Widget _buildTitle(double s) {
    const title = 'ENSPIRE ARCADE';
    final fontSize = 30 * s;
    TextSpan spans({required bool outline}) {
      int colorIndex = 0;
      return TextSpan(
        children: [
          for (final ch in title.split(''))
            TextSpan(
              text: ch,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                foreground: outline
                    ? (Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = 6 * s
                      ..strokeJoin = StrokeJoin.round
                      ..color = Colors.white)
                    : null,
                color: outline ? null : _titleColors[(ch == ' ' ? colorIndex : colorIndex++) % _titleColors.length],
                shadows: outline ? [Shadow(color: const Color(0x55000000), offset: Offset(0, 3 * s))] : null,
              ),
            ),
        ],
      );
    }

    return Row(
      children: [
        // Logo công ty (PNG nền trong suốt, ngang) đặt trên nền trắng bo góc
        Container(
          padding: EdgeInsets.symmetric(horizontal: 6 * s, vertical: 3 * s),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14 * s),
            boxShadow: [BoxShadow(color: const Color(0x33000000), offset: Offset(0, 3 * s))],
          ),
          child: Image(image: CompanyLogoBadge.logo, height: 38 * s, fit: BoxFit.contain, filterQuality: FilterQuality.medium),
        ),
        SizedBox(width: 10 * s),
        // Tự thu nhỏ chữ cho vừa cột thay vì bị cắt
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Stack(
              children: [
                Text.rich(spans(outline: true), maxLines: 1),
                Text.rich(spans(outline: false), maxLines: 1),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // CHỌN CHẾ ĐỘ: Khuôn mặt / Bàn tay & Hub 2 tay
  // ===========================================================================
  Widget _buildModeSelector(FaceMotionController ctrl, bool isHandMode, double s) {
    return KidPanel(
      padding: EdgeInsets.all(3.5 * s),
      radius: 22 * s,
      borderWidth: 2.5 * s,
      borderColor: isHandMode ? KidColors.orange : KidColors.blue,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildModeTab(
            s: s,
            emoji: '👤',
            title: 'FACE',
            isSelected: !isHandMode,
            color: KidColors.blue,
            onTap: () {
              SoundService.instance.playClick();
              ctrl.inputMode = MotionInputMode.face;
            },
          ),
          SizedBox(width: 4 * s),
          _buildModeTab(
            s: s,
            emoji: '✋',
            title: 'HAND',
            isSelected: isHandMode,
            color: KidColors.orange,
            onTap: () {
              SoundService.instance.playClick();
              ctrl.inputMode = MotionInputMode.hand;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildModeTab({
    required double s,
    required String emoji,
    required String title,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 12 * s, vertical: 7 * s),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(18 * s),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: TextStyle(fontSize: 15 * s)),
            SizedBox(width: 5 * s),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : KidColors.textSoft,
                fontSize: 13 * s,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDualHandHubButton(BuildContext context, double s) {
    return GestureDetector(
      onTap: () {
        SoundService.instance.playClick();
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                DualHandHubScreen(motionController: widget.motionController),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 7 * s),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFFF4081), Color(0xFFFF80AB)]),
          borderRadius: BorderRadius.circular(18 * s),
          border: Border.all(color: Colors.white, width: 2 * s),
          boxShadow: [
            BoxShadow(color: const Color(0xFFC2185B), offset: Offset(0, 2.5 * s)),
            BoxShadow(color: const Color(0x33000000), offset: Offset(0, 3.5 * s), blurRadius: 4),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('👐', style: TextStyle(fontSize: 13 * s)),
            SizedBox(width: 4 * s),
            Text(
              '2-HANDS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11.5 * s,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
              ),
            ),
            SizedBox(width: 2 * s),
            Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 9 * s),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // THỎ CHÀO BÉ: phản hồi cử chỉ theo thời gian thực
  // ===========================================================================
  Widget _buildMascot(FaceMotionController ctrl, MotionState state, bool isHandMode, double s) {
    final detected = isHandMode ? state.handDetected : state.faceDetected;
    final acting = isHandMode ? state.isHandFist : state.isChomping;

    RabbitMood mood = RabbitMood.normal;
    String? caption = 'Hi friend!';
    String headline = "LET'S PLAY!";
    String? footnote = ctrl.noCamera ? 'Tap PLAY to start 👆' : (isHandMode ? 'Show me your hand ✋' : 'Look at the camera 👀');
    if (detected && acting) {
      mood = RabbitMood.happy;
      caption = null;
      headline = 'YAY! 🎉';
      footnote = isHandMode ? 'Nice fist!' : 'Great job!';
    } else if (detected) {
      caption = 'I can see you!';
      headline = 'HELLO! 👋';
      footnote = 'Pick a game to play';
    }

    // Chế độ khuôn mặt: thỏ nghiêng theo hướng nghiêng đầu của bé
    double tilt = 0.0;
    if (!isHandMode && state.tiltDirection == TiltDirection.left) tilt = -0.12;
    if (!isHandMode && state.tiltDirection == TiltDirection.right) tilt = 0.12;

    return LayoutBuilder(
      builder: (context, constraints) {
        final rabbitH = math.min(constraints.maxHeight, 190.0 * s);
        if (rabbitH < 40) return const SizedBox.shrink(); // màn quá thấp: ẩn thỏ, ưu tiên các nút
        final rabbitW = rabbitH * 0.64;
        return Align(
          alignment: Alignment.centerLeft,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: AnimatedRotation(
              turns: tilt / (2 * math.pi),
              duration: const Duration(milliseconds: 250),
              alignment: Alignment.bottomLeft,
              child: RabbitMascot(
                mood: mood,
                caption: caption,
                headline: headline,
                footnote: footnote,
                rabbitHeight: rabbitH,
                bubbleMaxWidth: math.max(constraints.maxWidth - rabbitW, 120.0),
                textScale: s * 0.9,
              ),
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // TRẠNG THÁI CAMERA & CÀI ĐẶT
  // ===========================================================================
  Widget _buildCameraStatus(FaceMotionController ctrl, MotionState state, bool isHandMode, double s) {
    final detected = isHandMode ? state.handDetected : state.faceDetected;
    final noCamera = ctrl.noCamera;
    final Color color = detected ? KidColors.green : (noCamera ? KidColors.orange : KidColors.blue);
    final String text = noCamera
        ? 'Touch mode'
        : isHandMode
            ? (detected ? 'Hand found!' : 'Raise your hand to the camera')
            : (detected ? 'Face found!' : (ctrl.cameraAvailable ? 'Camera ready' : 'Starting camera...'));
    final IconData icon = noCamera
        ? Icons.touch_app_rounded
        : isHandMode
            ? (detected ? Icons.pan_tool_rounded : Icons.front_hand_outlined)
            : (detected ? Icons.face_rounded : Icons.videocam_rounded);

    return KidPanel(
      borderColor: color,
      borderWidth: 2.5 * s,
      radius: 18 * s,
      padding: EdgeInsets.symmetric(horizontal: 12 * s, vertical: 6 * s),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18 * s, color: color),
          SizedBox(width: 6 * s),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: KidColors.text, fontSize: 13 * s, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsRow(double s) {
    final muted = SoundService.instance.isMuted;
    return Row(
      children: [
        Flexible(
          child: SizedBox(
            width: 190 * s,
            child: KidButton(
              icon: Icons.tune_rounded,
              label: 'CAMERA SETUP',
              color: KidColors.blue,
              shadowColor: KidColors.blueDark,
              height: 44 * s,
              onPressed: () {
                SoundService.instance.playClick();
                _openCalibration();
              },
            ),
          ),
        ),
        SizedBox(width: 10 * s),
        KidIconButton(
          icon: muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
          color: muted ? KidColors.grey : KidColors.yellow,
          shadowColor: muted ? KidColors.greyDark : KidColors.yellowDark,
          size: 44 * s,
          tooltip: muted ? 'Sound on' : 'Sound off',
          onPressed: () {
            setState(() {
              SoundService.instance.toggleMute();
            });
            if (!SoundService.instance.isMuted) {
              SoundService.instance.playScore();
            }
          },
        ),
      ],
    );
  }

  // ===========================================================================
  // THẺ GAME
  // ===========================================================================
  Widget _buildGameCard({
    required double s,
    required double width,
    required String title,
    required String art,
    required String description,
    required List<(String, String)> steps, // (biểu tượng, cách thao tác) theo chế độ hiện tại
    required Color color,
    required Color colorDark,
    required List<Color> bannerColors,
    required VoidCallback onPlay,
  }) {
    final radius = 26 * s;
    final compact = width < 240; // thẻ hẹp (điện thoại nhỏ): bỏ đoạn mô tả, chỉ giữ cách chơi
    return Container(
      width: width,
      margin: EdgeInsets.only(bottom: 6 * s),
      decoration: BoxDecoration(
        color: KidColors.cream,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: color, width: 4 * s),
        boxShadow: [BoxShadow(color: colorDark, offset: Offset(0, 6 * s))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Băng minh hoạ trên đầu thẻ: emoji to, nền màu theo game
          Container(
            height: (compact ? 60 : 76) * s,
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: bannerColors),
              borderRadius: BorderRadius.vertical(top: Radius.circular(radius - 4 * s)),
            ),
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(horizontal: 12 * s, vertical: 6 * s),
            child: FittedBox(child: Text(art, style: TextStyle(fontSize: 46 * s))),
          ),

          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(14 * s, 10 * s, 14 * s, 12 * s),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      title,
                      maxLines: 1,
                      style: TextStyle(color: colorDark, fontSize: 22 * s, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                    ),
                  ),
                  SizedBox(height: 6 * s),

                  // Mô tả + cách chơi: cuộn được nếu màn hình thấp, không bao giờ tràn thẻ
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!compact) ...[
                            Text(
                              description,
                              style: TextStyle(color: KidColors.text, fontSize: 13 * s, height: 1.35, fontWeight: FontWeight.w600),
                            ),
                            SizedBox(height: 8 * s),
                          ],
                          for (final (emoji, text) in steps)
                            Container(
                              margin: EdgeInsets.only(bottom: 5 * s),
                              padding: EdgeInsets.symmetric(horizontal: 8 * s, vertical: 5 * s),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12 * s),
                              ),
                              child: Row(
                                children: [
                                  Text(emoji, style: TextStyle(fontSize: 15 * s)),
                                  SizedBox(width: 8 * s),
                                  Expanded(
                                    child: Text(
                                      text,
                                      style: TextStyle(color: KidColors.text, fontSize: 12 * s, fontWeight: FontWeight.w700, height: 1.25),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 8 * s),
                  KidButton(
                    icon: Icons.play_arrow_rounded,
                    label: 'PLAY!',
                    color: KidColors.pink,
                    shadowColor: KidColors.pinkDark,
                    height: 50 * s,
                    onPressed: onPlay,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
