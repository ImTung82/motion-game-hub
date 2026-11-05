import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../motion/face_motion_controller.dart';
import '../../motion/motion_state.dart';
import '../../services/sound_service.dart';
import '../widgets/calibration_dialog.dart';
import '../widgets/company_logo_badge.dart';
import '../widgets/fullscreen_button.dart';
import '../widgets/kid_ui.dart';
import '../widgets/listenable_selector.dart';
import '../widgets/rabbit_mascot.dart';
import '../../games/goalkeeper_hero/goalkeeper_screen.dart';

class DualHandHubScreen extends StatefulWidget {
  final FaceMotionController motionController;

  const DualHandHubScreen({super.key, required this.motionController});

  @override
  State<DualHandHubScreen> createState() => _DualHandHubScreenState();
}

class _DualHandHubScreenState extends State<DualHandHubScreen> {
  static const List<Color> _titleColors = [
    Color(0xFFFF4081),
    Color(0xFF00E5FF),
    Color(0xFFFFD600),
    Color(0xFF76FF03),
    Color(0xFFFF6D00),
    Color(0xFF9C27B0),
  ];

  @override
  void initState() {
    super.initState();
    // Tự động chuyển sang Hand mode khi vào Hub 2 tay
    if (widget.motionController.inputMode != MotionInputMode.hand) {
      widget.motionController.inputMode = MotionInputMode.hand;
    }
    // Hub & game ở đây dùng 2 tay (game mở chồng lên hub nên hub vẫn sống trong lúc chơi)
    widget.motionController.holdTwoHands();
  }

  @override
  void dispose() {
    widget.motionController.releaseTwoHands();
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
      backgroundColor: const Color(0xFFE1BEE7), // Tím pastel mộng mơ cho phân hệ 2 tay
      body: Stack(
        children: [
          const Positioned.fill(child: KidSkyBackground()),

          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20 * s, vertical: 12 * s),
              // Chỉ build lại khi thứ đang hiển thị đổi (controller báo theo từng khung camera, ~30 lần/giây)
              child: ListenableSelector(
                listenable: widget.motionController,
                selector: () => (
                  widget.motionController.state.handsCount,
                  widget.motionController.state.isClapTriggered,
                  widget.motionController.noCamera,
                ),
                builder: (context, _) {
                  final ctrl = widget.motionController;
                  final state = ctrl.state;
                  final handsCount = state.handsCount;

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // CỘT TRÁI: Nút quay lại, Tiêu đề 2-HANDS, Thỏ mascot, Trạng thái 2 tay & Cài đặt
                      Expanded(
                        flex: 38,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildTopRow(s),
                            SizedBox(height: 6 * s),
                            Expanded(child: _buildMascot(ctrl, state, handsCount, s)),
                            SizedBox(height: 6 * s),
                            _buildHandsStatus(ctrl, state, s),
                            SizedBox(height: 8 * s),
                            _buildSettingsRow(s),
                          ],
                        ),
                      ),

                      SizedBox(width: 14 * s),

                      // CỘT PHẢI: thẻ game 2 tay (chỉ hiện game đã có; Phonics Drummer, Magic Clap đang phát triển)
                      Expanded(
                        flex: 62,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            // Điện thoại: thẻ ~300px như cũ. Màn rộng (laptop, TV): to bằng thẻ ở hub chính
                            // (1/2 cột phải, tối đa 360*s) thay vì kẹt ở 340px trông bé tí giữa cột
                            final phoneW = (300.0 * s).clamp(240.0, 340.0);
                            final wideW = math.min((constraints.maxWidth - 14 * s) / 2, 360.0 * s);
                            final cardW = math.min(math.max(phoneW, wideW), constraints.maxWidth);
                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: SizedBox(
                                height: constraints.maxHeight,
                                child: Row(
                                  children: [
                                    // Game 1: GOALKEEPER HERO (MVP P1)
                                    _buildGameCard(
                                      s: s,
                                      width: cardW,
                                      title: 'GOALKEEPER HERO',
                                      art: '🧤⚽🥅',
                                      badge: '🔥 POPULAR',
                                      badgeColor: KidColors.orange,
                                      description: 'Use both hands to block incoming shots! Save the goal and learn English words.',
                                      steps: ctrl.noCamera
                                          ? const [('👆', 'Drag the gloves to the ball')]
                                          : const [
                                              ('👐', 'Move both hands to guard the net'),
                                              ('✊', 'Close hands together to catch the ball!'),
                                            ],
                                      color: KidColors.blue,
                                      colorDark: KidColors.blueDark,
                                      bannerColors: const [Color(0xFF80D8FF), Color(0xFF00B0FF)],
                                      onPlay: () {
                                        SoundService.instance.playWhistle();
                                        _launchGame(GoalkeeperScreen(motionController: widget.motionController));
                                      },
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
  // HÀNG TRÊN CÙNG: Nút Back + Tiêu đề DUAL HANDS
  // ===========================================================================
  Widget _buildTopRow(double s) {
    return Row(
      children: [
        KidIconButton(
          icon: Icons.arrow_back_rounded,
          color: KidColors.orange,
          shadowColor: KidColors.orangeDark,
          size: 40 * s,
          tooltip: 'Back to Single Hub',
          onPressed: () {
            SoundService.instance.playClick();
            Navigator.of(context).pop();
          },
        ),
        SizedBox(width: 8 * s),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 5 * s, vertical: 3 * s),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12 * s),
            boxShadow: [BoxShadow(color: const Color(0x33000000), offset: Offset(0, 2 * s))],
          ),
          child: Image(image: CompanyLogoBadge.logo, height: 32 * s, fit: BoxFit.contain),
        ),
        SizedBox(width: 8 * s),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              children: [
                for (int i = 0; i < '2-HANDS HUB'.length; i++)
                  Text(
                    '2-HANDS HUB'[i],
                    style: TextStyle(
                      fontSize: 22 * s,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: _titleColors[i % _titleColors.length],
                      shadows: [
                        Shadow(color: Colors.white, offset: Offset(-1.5 * s, -1.5 * s)),
                        Shadow(color: Colors.white, offset: Offset(1.5 * s, -1.5 * s)),
                        Shadow(color: Colors.white, offset: Offset(-1.5 * s, 1.5 * s)),
                        Shadow(color: Colors.white, offset: Offset(1.5 * s, 1.5 * s)),
                        Shadow(color: const Color(0x44000000), offset: Offset(0, 3 * s)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // THỎ MASCOT PHẢN HỒI THEO 2 TAY
  // ===========================================================================
  Widget _buildMascot(FaceMotionController ctrl, MotionState state, int handsCount, double s) {
    RabbitMood mood = RabbitMood.normal;
    String? caption = 'Step back a little! 🏃';
    String headline = 'SHOW BOTH HANDS!';
    String? footnote = 'Raise both hands up 👐';

    if (ctrl.noCamera) {
      caption = 'Hi friend!';
      headline = "LET'S PLAY!";
      footnote = 'Tap PLAY to start 👆';
    } else if (state.isClapTriggered) {
      mood = RabbitMood.happy;
      caption = 'GREAT CLAP! 🎉';
      headline = 'NICE JOB!';
      footnote = 'Keep clapping!';
    } else if (handsCount >= 2) {
      mood = RabbitMood.happy;
      caption = 'I see BOTH hands! 👐';
      headline = 'READY TO PLAY!';
      footnote = 'Pick a game to start';
    } else if (handsCount == 1) {
      caption = 'Found 1 hand! ✋';
      headline = 'ONE MORE!';
      footnote = 'Now raise your other hand';
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final rabbitH = math.min(constraints.maxHeight, 180.0 * s);
        if (rabbitH < 40) return const SizedBox.shrink();
        final rabbitW = rabbitH * 0.64;

        return Align(
          alignment: Alignment.centerLeft,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: RabbitMascot(
              mood: mood,
              caption: caption,
              headline: headline,
              footnote: footnote,
              rabbitHeight: rabbitH,
              bubbleMaxWidth: math.max(constraints.maxWidth - rabbitW, 120.0),
              textScale: s * 0.88,
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // TRẠNG THÁI 2 BÀN TAY
  // ===========================================================================
  Widget _buildHandsStatus(FaceMotionController ctrl, MotionState state, double s) {
    final int count = state.handsCount;
    final bool fullTwoHands = count >= 2;
    final Color color = ctrl.noCamera
        ? KidColors.orange
        : (fullTwoHands ? KidColors.green : (count == 1 ? KidColors.orange : KidColors.pink));

    String statusText;
    if (ctrl.noCamera) {
      statusText = 'Touch mode 👆';
    } else if (fullTwoHands) {
      statusText = 'Both Hands Ready! (2/2) 👐';
    } else if (count == 1) {
      statusText = '1 Hand Detected (Need 2) ✋';
    } else {
      statusText = 'Looking for hands... 🔍';
    }

    return KidPanel(
      borderColor: color,
      borderWidth: 2.5 * s,
      radius: 16 * s,
      padding: EdgeInsets.symmetric(horizontal: 12 * s, vertical: 6 * s),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(fullTwoHands ? Icons.pan_tool_alt_rounded : Icons.front_hand_outlined, size: 18 * s, color: color),
          SizedBox(width: 6 * s),
          Flexible(
            child: Text(
              statusText,
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
          // Hẹp (VD: iframe 800x600 kiểu PhET, có thêm nút toàn màn hình) => chỉ hiện icon, khỏi co chữ tí hon
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 150 * s;
              return SizedBox(
                width: 190 * s,
                child: KidButton(
                  icon: Icons.tune_rounded,
                  label: compact ? null : 'CAMERA SETUP',
                  color: KidColors.blue,
                  shadowColor: KidColors.blueDark,
                  height: 42 * s,
                  onPressed: () {
                    SoundService.instance.playClick();
                    _openCalibration();
                  },
                ),
              );
            },
          ),
        ),
        SizedBox(width: 10 * s),
        KidIconButton(
          icon: muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
          color: muted ? KidColors.grey : KidColors.yellow,
          shadowColor: muted ? KidColors.greyDark : KidColors.yellowDark,
          size: 42 * s,
          tooltip: muted ? 'Sound on' : 'Sound off',
          onPressed: () {
            setState(() {
              SoundService.instance.toggleMute();
            });
          },
        ),
        FullscreenButton(size: 42 * s, leadingGap: 10 * s),
      ],
    );
  }

  // ===========================================================================
  // THẺ GAME 2 TAY
  // ===========================================================================
  Widget _buildGameCard({
    required double s,
    required double width,
    required String title,
    required String art,
    required String badge,
    required Color badgeColor,
    required String description,
    required List<(String, String)> steps,
    required Color color,
    required Color colorDark,
    required List<Color> bannerColors,
    required VoidCallback onPlay,
  }) {
    final radius = 24 * s;
    return Container(
      width: width,
      margin: EdgeInsets.only(bottom: 6 * s),
      decoration: BoxDecoration(
        color: KidColors.cream,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: color, width: 3.5 * s),
        boxShadow: [
          BoxShadow(color: colorDark, offset: Offset(0, 5 * s), blurRadius: 0),
          BoxShadow(color: const Color(0x22000000), offset: Offset(0, 8 * s), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner trên
          Container(
            height: 64 * s,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: bannerColors),
              borderRadius: BorderRadius.vertical(top: Radius.circular(radius - 3.5 * s)),
            ),
            child: Stack(
              children: [
                Center(
                  child: Text(
                    art,
                    style: TextStyle(
                      fontSize: 34 * s,
                      shadows: [Shadow(color: const Color(0x33000000), offset: Offset(0, 3 * s), blurRadius: 4)],
                    ),
                  ),
                ),
                Positioned(
                  top: 6 * s,
                  right: 8 * s,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8 * s, vertical: 3 * s),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(12 * s),
                      boxShadow: [BoxShadow(color: Colors.black26, offset: Offset(0, 2 * s))],
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(color: Colors.white, fontSize: 10 * s, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: EdgeInsets.all(12 * s),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colorDark,
                    fontSize: 16 * s,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                SizedBox(height: 4 * s),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: KidColors.text, fontSize: 11.5 * s, height: 1.25, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8 * s),
                for (final step in steps)
                  Padding(
                    padding: EdgeInsets.only(bottom: 4 * s),
                    child: Row(
                      children: [
                        Text(step.$1, style: TextStyle(fontSize: 14 * s)),
                        SizedBox(width: 6 * s),
                        Expanded(
                          child: Text(
                            step.$2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: KidColors.textSoft, fontSize: 11 * s, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          const Spacer(),

          Padding(
            padding: EdgeInsets.fromLTRB(12 * s, 0, 12 * s, 12 * s),
            child: KidButton(
              icon: Icons.play_arrow_rounded,
              label: 'PLAY NOW',
              color: color,
              shadowColor: colorDark,
              height: 42 * s,
              onPressed: onPlay,
            ),
          ),
        ],
      ),
    );
  }
}
