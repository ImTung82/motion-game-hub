import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../core/constants.dart';
import '../../motion/face_motion_controller.dart';
import '../../motion/motion_state.dart';
import '../../ui/widgets/calibration_dialog.dart';
import '../../ui/widgets/camera_pip_overlay.dart';
import '../../ui/widgets/listenable_selector.dart';
import 'sky_chomp_canvas.dart';
import 'sky_chomp_engine.dart';

class SkyChompScreen extends StatefulWidget {
  final FaceMotionController motionController;

  const SkyChompScreen({super.key, required this.motionController});

  @override
  State<SkyChompScreen> createState() => _SkyChompScreenState();
}

class _SkyChompScreenState extends State<SkyChompScreen> with SingleTickerProviderStateMixin {
  late final SkyChompEngine _engine;
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  double _animationValue = 0.0;

  @override
  void initState() {
    super.initState();
    _engine = SkyChompEngine();
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
          // RepaintBoundary: canvas vẽ lại mỗi khung, HUD phía trên không phải vẽ lại theo
          RepaintBoundary(
            child: CustomPaint(
              painter: SkyChompCanvasPainter(
                engine: _engine,
                animationValue: _animationValue,
              ),
            ),
          ),

          _buildLandscapeHud(),

          CameraPipOverlay(
            motionController: widget.motionController,
            onCalibrate: _openCalibration,
          ),

          // Phím ảo cảm ứng (Mặc định ẩn, chỉ hiện nếu bật trong Cài đặt)
          ListenableSelector(
            listenable: widget.motionController,
            selector: () => widget.motionController.showTouchControls,
            builder: (context, _) {
              if (!widget.motionController.showTouchControls) return const SizedBox.shrink();
              return _buildDualThumbControls();
            },
          ),

          ListenableSelector(
            listenable: _engine,
            selector: () => _engine.isPaused,
            builder: (context, _) {
              if (!_engine.isPaused) return const SizedBox.shrink();
              return Container(
                color: Colors.black54,
                child: Center(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GameColors.neonCyan,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('RESUME', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () => _engine.resumeGame(),
                  ),
                ),
              );
            },
          ),

          ListenableSelector(
            listenable: _engine,
            selector: () => (_engine.isGameOver, _engine.score, _engine.totalChomps, _engine.totalDodges, _engine.maxCombo),
            builder: (context, _) {
              if (!_engine.isGameOver) return const SizedBox.shrink();
              return _buildGameOverDialog();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLandscapeHud() {
    return Positioned(
      top: 10,
      left: 12,
      child: ListenableSelector(
        listenable: _engine,
        selector: () => (_engine.score, _engine.combo, _engine.player.lives, _engine.feverEnergy, _engine.isFeverMode),
        builder: (context, _) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: GameColors.surface.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                      icon: const Icon(Icons.arrow_back, color: Colors.white, size: 18),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_engine.score}',
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                    ),
                    if (_engine.combo > 1) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: GameColors.neonYellow, borderRadius: BorderRadius.circular(10)),
                        child: Text('x${_engine.combo} COMBO', style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w900)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (index) {
                    final isAlive = index < _engine.player.lives;
                    return Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(isAlive ? Icons.favorite : Icons.favorite_border, color: isAlive ? GameColors.neonPink : Colors.white24, size: 18),
                    );
                  }),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: Container(
                    width: 110,
                    height: 6,
                    color: Colors.white10,
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: _engine.feverEnergy,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _engine.isFeverMode ? const [GameColors.neonYellow, GameColors.neonPink] : const [GameColors.neonCyan, GameColors.neonPurple],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDualThumbControls() {
    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              GestureDetector(
                onTapDown: (_) => widget.motionController.simulateTilt(TiltDirection.left),
                onTapUp: (_) => widget.motionController.simulateTilt(TiltDirection.neutral),
                onTapCancel: () => widget.motionController.simulateTilt(TiltDirection.neutral),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: GameColors.surface.withValues(alpha: 0.7),
                    shape: BoxShape.circle,
                    border: Border.all(color: GameColors.neonCyan.withValues(alpha: 0.5), width: 1.8),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new, color: GameColors.neonCyan, size: 20),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTapDown: (_) => widget.motionController.simulateTilt(TiltDirection.right),
                onTapUp: (_) => widget.motionController.simulateTilt(TiltDirection.neutral),
                onTapCancel: () => widget.motionController.simulateTilt(TiltDirection.neutral),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: GameColors.surface.withValues(alpha: 0.7),
                    shape: BoxShape.circle,
                    border: Border.all(color: GameColors.neonCyan.withValues(alpha: 0.5), width: 1.8),
                  ),
                  child: const Icon(Icons.arrow_forward_ios, color: GameColors.neonCyan, size: 20),
                ),
              ),
            ],
          ),

          GestureDetector(
            onTapDown: (_) => widget.motionController.simulateChomp(true),
            onTapUp: (_) => widget.motionController.simulateChomp(false),
            onTapCancel: () => widget.motionController.simulateChomp(false),
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: widget.motionController.state.isChomping ? GameColors.neonGreen.withValues(alpha: 0.85) : GameColors.surface.withValues(alpha: 0.7),
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.motionController.state.isChomping ? GameColors.neonGreen : GameColors.neonPink.withValues(alpha: 0.6),
                  width: 2.5,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.restaurant_menu_rounded, color: widget.motionController.state.isChomping ? Colors.black : Colors.white, size: 22),
                  const Text('CHOMP', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameOverDialog() {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 360,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: GameColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: GameColors.neonPink, width: 2),
            boxShadow: [BoxShadow(color: GameColors.neonPink.withValues(alpha: 0.35), blurRadius: 20)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('GAME OVER', style: TextStyle(color: GameColors.neonPink, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2)),
              const SizedBox(height: 10),
              Text('${_engine.score}', style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w900)),
              const Text('SCORE', style: TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 1.5)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Text('Chomps: ${_engine.totalChomps}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  Text('Dodges: ${_engine.totalDodges}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  Text('Max Combo: x${_engine.maxCombo}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white30), padding: const EdgeInsets.symmetric(vertical: 10)),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Icon(Icons.home, size: 20),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: GameColors.neonCyan, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 10)),
                      icon: const Icon(Icons.replay),
                      label: const Text('PLAY AGAIN', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                      onPressed: () => _engine.startGame(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
