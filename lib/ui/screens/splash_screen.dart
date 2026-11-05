import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../core/launch_game.dart';
import '../../games/egg_smasher/egg_smasher_screen.dart';
import '../../games/goalkeeper_hero/goalkeeper_screen.dart';
import '../../games/penalty_kick/penalty_screen.dart';
import '../../motion/face_motion_controller.dart';
import '../../services/sound_service.dart';
import '../widgets/kid_ui.dart';
import 'arcade_hub_screen.dart';
import 'dual_hand_hub_screen.dart';

class SplashScreen extends StatefulWidget {
  final FaceMotionController motionController;

  const SplashScreen({
    super.key,
    required this.motionController,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  bool _navigated = false;

  /// Link có `?game=...` (VD: iframe nhúng kiểu PhET) => sau splash vào thẳng game đó
  final LaunchGame? _launchGame = LaunchGame.fromUrl();
  bool _showPlay = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this);

    _animationController.addStatusListener((status) {
      if (status != AnimationStatus.completed) return;
      if (_launchGame == null) {
        _navigateToHub();
      } else {
        // Chờ bé bấm PLAY: trình duyệt chỉ cho phát âm thanh (đọc từ, còi...) sau một lần chạm / click
        setState(() => _showPlay = true);
      }
    });
  }

  static Route<void> _fadeRoute(Widget screen, {int ms = 300}) => PageRouteBuilder(
        transitionDuration: Duration(milliseconds: ms),
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      );

  void _navigateToHub() {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      _fadeRoute(ArcadeHubScreen(motionController: widget.motionController), ms: 500),
    );
  }

  /// Dựng đúng chồng màn như khi bé tự bấm từ hub => nút Back trong game quay về hub như thường
  void _openLaunchGame(LaunchGame game) {
    if (_navigated || !mounted) return;
    _navigated = true;
    SoundService.instance.playClick();

    final ctrl = widget.motionController;
    final nav = Navigator.of(context);
    nav.pushReplacement(_fadeRoute(ArcadeHubScreen(motionController: ctrl)));
    if (game.needsDualHandHub) nav.push(_fadeRoute(DualHandHubScreen(motionController: ctrl)));
    nav.push(_fadeRoute(switch (game) {
      LaunchGame.fruitsKick => PenaltyScreen(motionController: ctrl),
      LaunchGame.eggSmasher => EggSmasherScreen(motionController: ctrl),
      LaunchGame.goalkeeperHero => GoalkeeperScreen(motionController: ctrl),
    }));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logo = Lottie.asset(
      'assets/animations/splash_screen.json',
      controller: _animationController,
      width: 320,
      fit: BoxFit.contain,
      repeat: false,
      onLoaded: (composition) {
        _animationController
          ..duration = composition.duration
          ..forward();
      },
    );
    final game = _launchGame;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background graphic if available
          Image.asset(
            'assets/images/splash_bg.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
          ),

          // Enspire Splash Lottie Animation
          if (game == null)
            Center(child: logo)
          else
            // Giữ sẵn chỗ cho nút PLAY ngay từ đầu để logo không bị nhảy khi nút hiện ra
            SafeArea(
              child: Column(
                children: [
                  Expanded(child: Center(child: logo)),
                  _buildLaunchPanel(context, game),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLaunchPanel(BuildContext context, LaunchGame game) {
    final s = kidScale(context);
    return IgnorePointer(
      ignoring: !_showPlay,
      child: AnimatedOpacity(
        opacity: _showPlay ? 1 : 0,
        duration: const Duration(milliseconds: 300),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 20 * s),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${game.art}  ${game.title}',
                  style: TextStyle(
                    color: KidColors.text,
                    fontSize: 22 * s,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
              SizedBox(height: 10 * s),
              SizedBox(
                width: 220 * s,
                child: KidButton(
                  icon: Icons.play_arrow_rounded,
                  label: 'PLAY',
                  color: KidColors.green,
                  shadowColor: KidColors.greenDark,
                  height: 52 * s,
                  onPressed: () => _openLaunchGame(game),
                ),
              ),
              SizedBox(height: 6 * s),
              TextButton(
                onPressed: () {
                  SoundService.instance.playClick();
                  _navigateToHub();
                },
                child: Text(
                  'All games',
                  style: TextStyle(color: KidColors.textSoft, fontSize: 14 * s, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
