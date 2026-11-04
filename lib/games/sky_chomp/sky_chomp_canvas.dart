import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/constants.dart';
import 'sky_chomp_engine.dart';
import 'sky_chomp_models.dart';

class SkyChompCanvasPainter extends CustomPainter {
  final SkyChompEngine engine;
  final double animationValue;

  SkyChompCanvasPainter({
    required this.engine,
    required this.animationValue,
  }) : super(repaint: engine);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();

    if (engine.shakeAmount > 0) {
      final dx = (math.sin(animationValue * 50) * engine.shakeAmount);
      final dy = (math.cos(animationValue * 45) * engine.shakeAmount * 0.7);
      canvas.translate(dx, dy);
    }

    _drawBackground(canvas, size);
    _drawFoods(canvas, size);
    _drawObstacles(canvas, size);
    _drawParticles(canvas, size);
    _drawPlayer(canvas, size);

    canvas.restore();
  }

  void _drawBackground(Canvas canvas, Size size) {
    final bgRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final bgGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: engine.isFeverMode
          ? const [Color(0xFF2C0B3E), Color(0xFF1B082B), Color(0xFF0F001A)]
          : const [Color(0xFF070B19), Color(0xFF0C1022), Color(0xFF0A0D18)],
    );
    final bgPaint = Paint()..shader = bgGradient.createShader(bgRect);
    canvas.drawRect(bgRect, bgPaint);

    final starPaint = Paint()..style = PaintingStyle.fill;

    starPaint.color = Colors.white.withValues(alpha: 0.35);
    for (final star in engine.starsFar) {
      canvas.drawCircle(Offset(star.dx * size.width, star.dy * size.height), 1.2, starPaint);
    }

    starPaint.color = (engine.isFeverMode ? GameColors.neonYellow : GameColors.neonCyan).withValues(alpha: 0.55);
    for (final star in engine.starsMid) {
      canvas.drawCircle(Offset(star.dx * size.width, star.dy * size.height), 1.8, starPaint);
    }

    for (final star in engine.starsNear) {
      final twinkle = 0.5 + 0.5 * math.sin(animationValue * 6 + star.dx * 10);
      starPaint.color = (engine.isFeverMode ? GameColors.neonPink : Colors.white).withValues(alpha: 0.8 * twinkle);
      canvas.drawCircle(Offset(star.dx * size.width, star.dy * size.height), 2.5, starPaint);
    }

    if (engine.isFeverMode) {
      final borderPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.0
        ..shader = const LinearGradient(
          colors: [GameColors.neonPink, GameColors.neonYellow, GameColors.neonCyan, GameColors.neonPink],
        ).createShader(bgRect);
      canvas.drawRect(bgRect, borderPaint);
    }
  }

  void _drawFoods(Canvas canvas, Size size) {
    for (final food in engine.foods) {
      if (food.isEaten) continue;

      final px = food.x * size.width;
      final py = food.y * size.height;
      final wobble = math.sin(food.wobblePhase) * 4.0;

      final glowPaint = Paint()
        ..color = food.color.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12.0);
      canvas.drawCircle(Offset(px, py + wobble), food.radius + 6, glowPaint);

      final bodyPaint = Paint()..color = const Color(0xFF1E2235);
      canvas.drawCircle(Offset(px, py + wobble), food.radius, bodyPaint);

      final borderPaint = Paint()
        ..color = food.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawCircle(Offset(px, py + wobble), food.radius, borderPaint);

      _drawFoodIcon(canvas, Offset(px, py + wobble), food.type, food.radius, food.color);
    }
  }

  void _drawFoodIcon(Canvas canvas, Offset center, FoodType type, double radius, Color color) {
    final iconPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    switch (type) {
      case FoodType.star:
        final path = Path();
        const points = 5;
        for (int i = 0; i < points * 2; i++) {
          final r = (i % 2 == 0) ? radius * 0.65 : radius * 0.32;
          final angle = (i * math.pi) / points - math.pi / 2;
          final x = center.dx + r * math.cos(angle);
          final y = center.dy + r * math.sin(angle);
          if (i == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        path.close();
        canvas.drawPath(path, iconPaint);
        break;

      case FoodType.donut:
        canvas.drawCircle(center, radius * 0.55, iconPaint);
        canvas.drawCircle(center, radius * 0.22, Paint()..color = const Color(0xFF1E2235));
        break;

      case FoodType.pizza:
        final path = Path()
          ..moveTo(center.dx, center.dy - radius * 0.6)
          ..lineTo(center.dx + radius * 0.55, center.dy + radius * 0.45)
          ..lineTo(center.dx - radius * 0.55, center.dy + radius * 0.45)
          ..close();
        canvas.drawPath(path, iconPaint);
        break;

      case FoodType.diamond:
        final path = Path()
          ..moveTo(center.dx, center.dy - radius * 0.6)
          ..lineTo(center.dx + radius * 0.5, center.dy)
          ..lineTo(center.dx, center.dy + radius * 0.6)
          ..lineTo(center.dx - radius * 0.5, center.dy)
          ..close();
        canvas.drawPath(path, iconPaint);
        break;

      case FoodType.megaBurger:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: center, width: radius * 1.1, height: radius * 0.7),
            const Radius.circular(6),
          ),
          iconPaint,
        );
        break;
    }
  }

  void _drawObstacles(Canvas canvas, Size size) {
    for (final obs in engine.obstacles) {
      if (obs.isDestroyed) continue;

      final px = obs.x * size.width;
      final py = obs.y * size.height;

      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(obs.rotation);

      final dangerGlow = Paint()
        ..color = GameColors.obstacleMeteor.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14.0);
      canvas.drawCircle(Offset.zero, obs.size + 4, dangerGlow);

      final bodyPaint = Paint()..color = const Color(0xFF2C101E)..style = PaintingStyle.fill;
      final strokePaint = Paint()..color = GameColors.obstacleMeteor..style = PaintingStyle.stroke..strokeWidth = 3.0;

      final path = Path();
      const points = 6;
      final radiusOut = obs.size;
      final radiusIn = obs.size * 0.65;
      for (int i = 0; i < points * 2; i++) {
        final r = (i % 2 == 0) ? radiusOut : radiusIn;
        final angle = (i * math.pi) / points;
        final x = r * math.cos(angle);
        final y = r * math.sin(angle);
          if (i == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
      }
      path.close();

      canvas.drawPath(path, bodyPaint);
      canvas.drawPath(path, strokePaint);

      final corePaint = Paint()..color = GameColors.obstacleMeteor;
      canvas.drawCircle(Offset.zero, obs.size * 0.25, corePaint);

      canvas.restore();
    }
  }

  void _drawPlayer(Canvas canvas, Size size) {
    final p = engine.player;
    if (p.isInvincible && (animationValue * 15).floor() % 2 == 0 && !engine.isFeverMode) {
      return;
    }

    final px = p.x * size.width;
    final py = p.y * size.height;
    final r = size.height * 0.105;

    canvas.save();
    canvas.translate(px, py);
    canvas.rotate(p.tiltAngle);

    final flameHeight = 15.0 + math.sin(animationValue * 30) * 8.0 + (engine.isFeverMode ? 15.0 : 0.0);
    final flamePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: engine.isFeverMode
            ? [GameColors.neonYellow, GameColors.neonPink, Colors.transparent]
            : [GameColors.neonCyan, GameColors.neonPurple, Colors.transparent],
      ).createShader(Rect.fromLTWH(-r * 0.4, r * 0.7, r * 0.8, flameHeight));

    final flamePath = Path()
      ..moveTo(-r * 0.35, r * 0.7)
      ..quadraticBezierTo(0, r * 0.7 + flameHeight, r * 0.35, r * 0.7)
      ..close();
    canvas.drawPath(flamePath, flamePaint);

    final glowColor = engine.isFeverMode
        ? GameColors.neonYellow
        : (p.isChomping ? GameColors.neonGreen : GameColors.neonCyan);

    final glowPaint = Paint()
      ..color = glowColor.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20.0);
    canvas.drawCircle(Offset.zero, r + 8, glowPaint);

    final bodyPaint = Paint()..color = const Color(0xFF132035)..style = PaintingStyle.fill;
    final strokePaint = Paint()..color = glowColor..style = PaintingStyle.stroke..strokeWidth = 3.5;

    canvas.drawCircle(Offset.zero, r, bodyPaint);
    canvas.drawCircle(Offset.zero, r, strokePaint);

    final eyeRadius = r * 0.22;
    final eyeOffsetY = -r * 0.25;
    final eyeSpacing = r * 0.38;

    final eyeWhite = Paint()..color = Colors.white;
    final pupilPaint = Paint()..color = const Color(0xFF090D1A);
    final pupilOffsetX = (p.tiltAngle * 12.0).clamp(-4.0, 4.0);

    canvas.drawCircle(Offset(-eyeSpacing, eyeOffsetY), eyeRadius, eyeWhite);
    canvas.drawCircle(Offset(-eyeSpacing + pupilOffsetX, eyeOffsetY), eyeRadius * 0.55, pupilPaint);
    canvas.drawCircle(Offset(-eyeSpacing + pupilOffsetX - 1, eyeOffsetY - 1), eyeRadius * 0.2, eyeWhite);

    canvas.drawCircle(Offset(eyeSpacing, eyeOffsetY), eyeRadius, eyeWhite);
    canvas.drawCircle(Offset(eyeSpacing + pupilOffsetX, eyeOffsetY), eyeRadius * 0.55, pupilPaint);
    canvas.drawCircle(Offset(eyeSpacing + pupilOffsetX - 1, eyeOffsetY - 1), eyeRadius * 0.2, eyeWhite);

    final mouthProgress = p.mouthOpenProgress;
    final mouthY = r * 0.28;
    final mouthWidth = r * 0.9;
    final mouthHeight = (r * 0.25 + mouthProgress * r * 0.65);

    final mouthPaint = Paint()
      ..color = mouthProgress > 0.4 ? const Color(0xFFFF0055) : const Color(0xFF0F1526)
      ..style = PaintingStyle.fill;
    final mouthBorder = Paint()
      ..color = mouthProgress > 0.4 ? GameColors.neonPink : GameColors.neonCyan
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final mouthRect = Rect.fromCenter(
      center: Offset(0, mouthY + mouthHeight * 0.3),
      width: mouthWidth,
      height: mouthHeight,
    );
    final mouthRRect = RRect.fromRectAndRadius(mouthRect, Radius.circular(mouthHeight * 0.5));
    canvas.drawRRect(mouthRRect, mouthPaint);
    canvas.drawRRect(mouthRRect, mouthBorder);

    if (mouthProgress > 0.35) {
      final toothPaint = Paint()..color = Colors.white;
      final tPath1 = Path()
        ..moveTo(-r * 0.2, mouthRect.top)
        ..lineTo(-r * 0.1, mouthRect.top + 7)
        ..lineTo(0, mouthRect.top)
        ..close();
      final tPath2 = Path()
        ..moveTo(0, mouthRect.top)
        ..lineTo(r * 0.1, mouthRect.top + 7)
        ..lineTo(r * 0.2, mouthRect.top)
        ..close();
      canvas.drawPath(tPath1, toothPaint);
      canvas.drawPath(tPath2, toothPaint);
    }

    if (p.isChomping || mouthProgress > 0.5) {
      final chompWavePaint = Paint()
        ..color = GameColors.neonGreen.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      final waveRadius = r + 12.0 + (math.sin(animationValue * 25) * 6.0);
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: waveRadius),
        0.2,
        math.pi - 0.4,
        false,
        chompWavePaint,
      );
    }

    canvas.restore();
  }

  void _drawParticles(Canvas canvas, Size size) {
    for (final p in engine.particles) {
      final px = p.x * size.width;
      final py = p.y * size.height;
      final paint = Paint()
        ..color = p.color.withValues(alpha: p.life.clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(px, py), p.size * p.life, paint);
    }
  }


  @override
  bool shouldRepaint(covariant SkyChompCanvasPainter oldDelegate) => true;
}
