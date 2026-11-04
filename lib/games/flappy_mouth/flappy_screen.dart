import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../core/constants.dart';
import '../../motion/face_motion_controller.dart';
import '../../ui/widgets/calibration_dialog.dart';
import '../../ui/widgets/camera_pip_overlay.dart';
import 'flappy_canvas.dart';
import 'flappy_engine.dart';

class FlappyMouthScreen extends StatefulWidget {
  final FaceMotionController motionController;

  const FlappyMouthScreen({super.key, required this.motionController});

  @override
  State<FlappyMouthScreen> createState() => _FlappyMouthScreenState();
}

class _FlappyMouthScreenState extends State<FlappyMouthScreen> with SingleTickerProviderStateMixin {
  late final FlappyEngine _engine;
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  double _animationValue = 0.0;

  @override
  void initState() {
    super.initState();
    _engine = FlappyEngine();
    _engine.startGame();

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

    _engine.update(clampedDt, widget.motionController.state);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _engine.dispose();
    super.dispose();
  }

  void _openCalibration() {
    showDialog(
      context: context,
      builder: (ctx) => CalibrationDialog(controller: widget.motionController),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: FlappyCanvasPainter(
              engine: _engine,
              animationValue: _animationValue,
            ),
          ),

          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: ListenableBuilder(
                  listenable: _engine,
                  builder: (context, _) => Text(
                    '${_engine.score}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      shadows: [Shadow(color: GameColors.neonGreen, blurRadius: 15)],
                    ),
                  ),
                ),
              ),
            ),
          ),

          CameraPipOverlay(
            motionController: widget.motionController,
            onCalibrate: _openCalibration,
          ),

          // Nút chạm vỗ cánh (Mặc định ẩn, chỉ hiện nếu bật trong Cài đặt)
          ListenableBuilder(
            listenable: widget.motionController,
            builder: (context, _) {
              if (!widget.motionController.showTouchControls) return const SizedBox.shrink();
              return Positioned(
                bottom: 16,
                right: 16,
                child: GestureDetector(
                  onTap: () => _engine.flap(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    decoration: BoxDecoration(
                      color: GameColors.surface.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: GameColors.neonGreen, width: 2),
                      boxShadow: [
                        BoxShadow(color: GameColors.neonGreen.withValues(alpha: 0.3), blurRadius: 10),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.flutter_dash, color: GameColors.neonGreen, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'OPEN YOUR MOUTH TO FLY (OR TAP)',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          ListenableBuilder(
            listenable: _engine,
            builder: (context, _) {
              if (!_engine.isGameOver) return const SizedBox.shrink();

              return Center(
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: 320,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: GameColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: GameColors.neonPink, width: 2),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('GAME OVER', style: TextStyle(color: GameColors.neonPink, fontSize: 24, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 10),
                        Text('${_engine.score}', style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w900)),
                        Text('Best: ${_engine.highScore}', style: const TextStyle(color: GameColors.neonYellow, fontSize: 13)),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 10)),
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Menu'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: GameColors.neonGreen, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 10)),
                                onPressed: () => _engine.startGame(),
                                child: const Text('PLAY AGAIN', style: TextStyle(fontWeight: FontWeight.w900)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
