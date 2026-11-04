import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/constants.dart';
import 'flappy_engine.dart';

class FlappyCanvasPainter extends CustomPainter {
  final FlappyEngine engine;
  final double animationValue;

  FlappyCanvasPainter({
    required this.engine,
    required this.animationValue,
  }) : super(repaint: engine);

  @override
  void paint(Canvas canvas, Size size) {
    _drawSky(canvas, size);
    _drawPipes(canvas, size);
    _drawBird(canvas, size);
    _drawGround(canvas, size);
  }

  void _drawSky(Canvas canvas, Size size) {
    final bgRect = Rect.fromLTWH(0, 0, size.width, size.height);
    const bgGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF0F1A30), Color(0xFF1B2A4A), Color(0xFF261D3A)],
    );
    canvas.drawRect(bgRect, Paint()..shader = bgGradient.createShader(bgRect));

    final cloudPaint = Paint()..color = Colors.white.withValues(alpha: 0.15);
    for (final cloud in engine.clouds) {
      final cx = cloud.dx * size.width;
      final cy = cloud.dy * size.height;
      canvas.drawCircle(Offset(cx, cy), 24, cloudPaint);
      canvas.drawCircle(Offset(cx + 18, cy - 6), 18, cloudPaint);
      canvas.drawCircle(Offset(cx - 18, cy + 2), 16, cloudPaint);
    }
  }

  void _drawPipes(Canvas canvas, Size size) {
    const pipeW = 0.12;
    final w = pipeW * size.width;

    for (final pipe in engine.pipes) {
      final x = pipe.x * size.width;
      final topH = pipe.topHeight * size.height;
      final bottomY = pipe.bottomY * size.height;

      final topRect = Rect.fromLTWH(x, 0, w, topH);
      _drawNeonPipe(canvas, topRect, true);

      final bottomRect = Rect.fromLTWH(x, bottomY, w, size.height - bottomY - 30);
      _drawNeonPipe(canvas, bottomRect, false);
    }
  }

  void _drawNeonPipe(Canvas canvas, Rect rect, bool isTop) {
    final bodyPaint = Paint()..color = const Color(0xFF132F24);
    final borderPaint = Paint()
      ..color = GameColors.neonGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final glowPaint = Paint()
      ..color = GameColors.neonGreen.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10.0);

    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), glowPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), bodyPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), borderPaint);

    final capH = 18.0;
    final capRect = isTop
        ? Rect.fromLTWH(rect.left - 4, rect.bottom - capH, rect.width + 8, capH)
        : Rect.fromLTWH(rect.left - 4, rect.top, rect.width + 8, capH);
    canvas.drawRRect(RRect.fromRectAndRadius(capRect, const Radius.circular(6)), bodyPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(capRect, const Radius.circular(6)), borderPaint);
  }

  void _drawBird(Canvas canvas, Size size) {
    final bx = engine.birdX * size.width;
    final by = engine.birdY * size.height;
    final r = size.height * 0.082;

    canvas.save();
    canvas.translate(bx, by);
    canvas.rotate(engine.birdRotation);

    final glowPaint = Paint()
      ..color = GameColors.neonYellow.withValues(alpha: 0.45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14.0);
    canvas.drawCircle(Offset.zero, r + 4, glowPaint);

    final bodyPaint = Paint()..color = const Color(0xFF382D12);
    final borderPaint = Paint()
      ..color = GameColors.neonYellow
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    canvas.drawCircle(Offset.zero, r, bodyPaint);
    canvas.drawCircle(Offset.zero, r, borderPaint);

    final wingY = math.sin(animationValue * 20) * 4.0;
    final wingPaint = Paint()..color = GameColors.neonOrange;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(-r * 0.35, wingY), width: r * 0.7, height: r * 0.45),
      wingPaint,
    );

    canvas.drawCircle(Offset(r * 0.35, -r * 0.25), r * 0.28, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(r * 0.42, -r * 0.25), r * 0.14, Paint()..color = Colors.black);

    // Beak / Mouth (Há to theo cử chỉ!)
    final mouthProgress = engine.mouthProgress;
    final beakTop = Path()
      ..moveTo(r * 0.5, -r * 0.1)
      ..lineTo(r * 1.2, -r * 0.05)
      ..lineTo(r * 0.5, 0)
      ..close();
    canvas.drawPath(beakTop, Paint()..color = GameColors.neonPink);

    final beakBottom = Path()
      ..moveTo(r * 0.5, 0)
      ..lineTo(r * 1.15, r * 0.1 + mouthProgress * r * 0.45)
      ..lineTo(r * 0.45, r * 0.25)
      ..close();
    canvas.drawPath(beakBottom, Paint()..color = GameColors.neonOrange);

    canvas.restore();
  }

  void _drawGround(Canvas canvas, Size size) {
    final groundRect = Rect.fromLTWH(0, size.height - 30, size.width, 30);
    final groundPaint = Paint()..color = const Color(0xFF1E2838);
    final borderPaint = Paint()..color = GameColors.neonCyan..strokeWidth = 2.0..style = PaintingStyle.stroke;

    canvas.drawRect(groundRect, groundPaint);
    canvas.drawLine(Offset(0, size.height - 30), Offset(size.width, size.height - 30), borderPaint);
  }

  @override
  bool shouldRepaint(covariant FlappyCanvasPainter oldDelegate) => true;
}
