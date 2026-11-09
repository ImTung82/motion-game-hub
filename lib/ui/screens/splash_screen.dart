import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../motion/face_motion_controller.dart';
import 'arcade_hub_screen.dart';
import '../../services/word_bank.dart';

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

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this);

    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _navigateToHub();
      }
    });
  }

  Future<void> _navigateToHub() async {
    if (_navigated || !mounted) return;
    _navigated = true;
    await WordBank.instance.load(); // thường đã xong từ lâu; game cần kho từ ngay khi bắt đầu
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (context, animation, secondaryAnimation) =>
            ArcadeHubScreen(motionController: widget.motionController),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          Center(
            child: Lottie.asset(
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
            ),
          ),
        ],
      ),
    );
  }
}
