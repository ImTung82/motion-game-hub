import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/constants.dart';
import 'motion/face_motion_controller.dart';
import 'ui/screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  final motionController = FaceMotionController();
  await motionController.initialize();

  runApp(MotionArcadeHubApp(motionController: motionController));
}

class MotionArcadeHubApp extends StatelessWidget {
  final FaceMotionController motionController;

  const MotionArcadeHubApp({
    super.key,
    required this.motionController,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Enspire Digital',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: GameColors.background,
        colorScheme: const ColorScheme.dark(
          primary: GameColors.neonCyan,
          secondary: GameColors.neonPink,
          surface: GameColors.surface,
        ),
        textTheme: GoogleFonts.beVietnamProTextTheme(ThemeData.dark().textTheme),
        useMaterial3: true,
      ),
      home: SplashScreen(motionController: motionController),
    );
  }
}
