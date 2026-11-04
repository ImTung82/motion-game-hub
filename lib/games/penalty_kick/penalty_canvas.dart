import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'penalty_engine.dart';

class PenaltyCanvasPainter extends CustomPainter {
  final PenaltyEngine engine;
  final double animationValue;
  final ui.Image? ballImage; // ảnh quả bóng (assets/images/soccer_ball.png); null -> vẽ bóng vector

  PenaltyCanvasPainter({
    required this.engine,
    required this.animationValue,
    this.ballImage,
  }) : super(repaint: engine);

  @override
  void paint(Canvas canvas, Size size) {
    _drawStadiumBackground(canvas, size);
    _drawGrassPitch(canvas, size);
    _drawGoalNet(canvas, size);
    _drawGoalPosts(canvas, size);
    _drawFruitTargets(canvas, size);
    _drawAimReticle(canvas, size);
    _drawBall(canvas, size);
    _drawParticles(canvas, size);
    // Banner thông báo đã chuyển sang bóng thoại của thỏ linh vật (RabbitMascot)
  }

  // Bảng màu pastel tươi sáng cho trẻ mẫu giáo
  static const List<Color> _fanColors = [
    Color(0xFFFF8A80), // hồng cam
    Color(0xFFFFD54F), // vàng
    Color(0xFF81D4FA), // xanh da trời
    Color(0xFFA5D6A7), // xanh lá nhạt
    Color(0xFFCE93D8), // tím nhạt
    Color(0xFFFFAB40), // cam
    Color(0xFF80CBC4), // xanh ngọc
  ];
  static const List<Color> _rainbow = [
    Color(0xFFFF6B6B), Color(0xFFFFA94D), Color(0xFFFFD43B),
    Color(0xFF69DB7C), Color(0xFF4DABF7), Color(0xFF9775FA),
  ];

  // 1. Bầu trời ban ngày: mặt trời cười, mây trôi, khán đài cổ động viên đầy màu sắc
  void _drawStadiumBackground(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    // Bầu trời xanh dịu
    final skyRect = Rect.fromLTWH(0, 0, w, h * 0.4);
    canvas.drawRect(
      skyRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF6EC6FF), Color(0xFFB3E5FC), Color(0xFFE1F5FE)],
        ).createShader(skyRect),
    );

    // Mặt trời bên trái (góc phải là cụm nút HUD), cách nút Back một khoảng
    _drawSmilingSun(canvas, Offset(w * 0.17, h * 0.11), h * 0.065);

    // Mây trắng bồng bềnh trôi chậm sang phải: (x ban đầu, y, tỉ lệ, tốc độ)
    const clouds = [(0.05, 0.07, 1.0, 0.012), (0.42, 0.04, 0.8, 0.008), (0.7, 0.12, 0.65, 0.015)];
    for (final (x0, y, scale, speed) in clouds) {
      final x = ((x0 + animationValue * speed) % 1.3) - 0.15;
      _drawCloud(canvas, Offset(x * w, y * h + h * 0.04), h * 0.045 * scale);
    }

    // Khán đài
    final standTop = h * 0.19, standBottom = h * 0.355;
    final standRect = Rect.fromLTRB(0, standTop, w, standBottom);
    canvas.drawRect(
      standRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFB39DDB), Color(0xFF9FA8DA)],
        ).createShader(standRect),
    );
    // Mái khán đài kẻ sọc đỏ trắng như rạp xiếc
    final roofH = h * 0.025;
    final stripeW = w / 24;
    for (int i = 0; i < 24; i++) {
      canvas.drawRect(
        Rect.fromLTWH(i * stripeW, standTop - roofH, stripeW + 0.5, roofH),
        Paint()..color = i.isEven ? const Color(0xFFFF6B6B) : Colors.white,
      );
    }

    // Cổ động viên: các bạn tròn tròn nhiều màu nhún nhảy; ghi bàn thì nhảy cẫng lên
    // Ghi bàn: cả khán đài nhảy đúng 2 nhịp (lệch pha nhẹ thành "làn sóng"), xong thì về nhún nhẹ
    final cheerTime = engine.goalCelebrationTime;
    const cheerTotal = PenaltyEngine.cheerJumpDuration * PenaltyEngine.cheerJumps;
    final r = h * 0.017;
    final spacing = r * 2.7;
    const rows = 3;
    final eye = Paint()..color = const Color(0xFF4E342E);
    final skin = Paint()..color = const Color(0xFFFFE0C2);
    for (int row = 0; row < rows; row++) {
      final y = standTop + h * 0.03 + row * (standBottom - standTop - h * 0.04) / (rows - 1);
      final offsetX = row.isOdd ? spacing / 2 : 0.0;
      int i = 0;
      for (double x = offsetX + r; x < w; x += spacing, i++) {
        final seed = row * 5 + i * 3; // i*3 (mod 7) để màu các bạn cạnh nhau luôn khác nhau
        double dy;
        final t = cheerTime == null ? -1.0 : cheerTime - (seed % 5) * 0.03;
        if (t >= 0 && t < cheerTotal) {
          dy = -math.sin(t / PenaltyEngine.cheerJumpDuration * math.pi).abs() * r * 1.4;
        } else {
          dy = -math.sin(animationValue * 3 + seed).abs() * r * 0.18;
        }
        final color = _fanColors[seed % _fanColors.length];
        final c = Offset(x, y + dy);
        canvas.drawCircle(c.translate(0, r * 1.25), r * 0.95, Paint()..color = color.withValues(alpha: 0.85)); // thân
        canvas.drawCircle(c, r, skin); // mặt
        canvas.drawCircle(c.translate(0, -r * 0.55), r * 0.75, Paint()..color = color); // mũ
        canvas.drawCircle(c.translate(-r * 0.35, r * 0.05), r * 0.13, eye);
        canvas.drawCircle(c.translate(r * 0.35, r * 0.05), r * 0.13, eye);
      }
    }

    // Hàng rào cầu vồng dọc mép sân
    final fenceTop = h * 0.335, fenceBottom = h * 0.385;
    final panelW = w / 12;
    for (int i = 0; i < 12; i++) {
      final rect = Rect.fromLTRB(i * panelW + 1, fenceTop, (i + 1) * panelW - 1, fenceBottom);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        Paint()..color = _rainbow[i % _rainbow.length],
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTRB(rect.left + 3, rect.top + 3, rect.right - 3, rect.top + 6), const Radius.circular(2)),
        Paint()..color = Colors.white.withValues(alpha: 0.45),
      );
    }
  }

  void _drawSmilingSun(Canvas canvas, Offset c, double r) {
    // Tia nắng xoay chậm
    final rayPaint = Paint()
      ..color = const Color(0xFFFFCA28)
      ..strokeWidth = r * 0.16
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 10; i++) {
      final a = animationValue * 0.4 + i * math.pi / 5;
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + dir * r * 1.25, c + dir * r * 1.6, rayPaint);
    }
    canvas.drawCircle(c, r * 1.12, Paint()..color = const Color(0x55FFF59D));
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFFFFD54F));

    // Mặt cười
    final face = Paint()..color = const Color(0xFF8D6E63);
    canvas.drawCircle(c.translate(-r * 0.33, -r * 0.15), r * 0.11, face);
    canvas.drawCircle(c.translate(r * 0.33, -r * 0.15), r * 0.11, face);
    canvas.drawArc(
      Rect.fromCenter(center: c.translate(0, r * 0.1), width: r * 0.9, height: r * 0.7),
      0.25,
      math.pi - 0.5,
      false,
      Paint()
        ..color = const Color(0xFF8D6E63)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.1
        ..strokeCap = StrokeCap.round,
    );
    final blush = Paint()..color = const Color(0x66FF8A80);
    canvas.drawCircle(c.translate(-r * 0.58, r * 0.22), r * 0.15, blush);
    canvas.drawCircle(c.translate(r * 0.58, r * 0.22), r * 0.15, blush);
  }

  void _drawCloud(Canvas canvas, Offset c, double r) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.95);
    canvas.drawCircle(c, r, paint);
    canvas.drawCircle(c.translate(-r * 1.0, r * 0.3), r * 0.7, paint);
    canvas.drawCircle(c.translate(r * 1.05, r * 0.25), r * 0.78, paint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(c.dx - r * 1.6, c.dy + r * 0.1, c.dx + r * 1.75, c.dy + r * 0.95),
        Radius.circular(r * 0.45),
      ),
      paint,
    );
  }

  // 2. Sân cỏ xanh tươi có sọc cắt cỏ
  void _drawGrassPitch(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final pitchTop = h * 0.38;

    final pitchRect = Rect.fromLTRB(0, pitchTop, w, h);
    canvas.drawRect(
      pitchRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF8BD45E), Color(0xFF6CC24A), Color(0xFF58B03C)],
        ).createShader(pitchRect),
    );

    // Sọc cỏ phối cảnh: dải xa mỏng, dải gần dày
    const bands = 7;
    double y = pitchTop;
    for (int i = 0; i < bands; i++) {
      final bandH = (h - pitchTop) * (0.06 + i * 0.022);
      if (i.isOdd) {
        canvas.drawRect(Rect.fromLTWH(0, y, w, bandH), Paint()..color = Colors.white.withValues(alpha: 0.08));
      }
      y += bandH;
    }

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    // Vạch 16m50
    canvas.drawLine(Offset(w * 0.12, h * 0.55), Offset(w * 0.88, h * 0.55), linePaint);
    canvas.drawLine(Offset(w * 0.12, h * 0.55), Offset(w * 0.08, h * 0.62), linePaint);
    canvas.drawLine(Offset(w * 0.88, h * 0.55), Offset(w * 0.92, h * 0.62), linePaint);

    // Chấm phạt đền 11m
    canvas.drawCircle(Offset(w * 0.5, h * 0.82), 5.5, Paint()..color = Colors.white);
  }

  // 3. Lưới khung thành có hiệu ứng rung (Wobble)
  void _drawGoalNet(Canvas canvas, Size size) {
    final goalLeft = size.width * 0.24;
    final goalRight = size.width * 0.76;
    final crossbarY = size.height * 0.16;
    final groundY = size.height * 0.39;

    final wobbleDx = math.sin(animationValue * 18.0) * (engine.netWobble * 6.0);
    final wobbleDy = math.cos(animationValue * 14.0) * (engine.netWobble * 4.0);

    final netPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..strokeWidth = 1.0;

    // Các đường lưới dọc
    const int numV = 16;
    for (int i = 0; i <= numV; i++) {
      final x = goalLeft + (goalRight - goalLeft) * (i / numV) + (wobbleDx * (1.0 - (i / numV)));
      canvas.drawLine(Offset(x, crossbarY), Offset(x, groundY + wobbleDy), netPaint);
    }

    // Các đường lưới ngang
    const int numH = 8;
    for (int i = 0; i <= numH; i++) {
      final y = crossbarY + (groundY - crossbarY) * (i / numH) + wobbleDy;
      canvas.drawLine(Offset(goalLeft, y), Offset(goalRight, y), netPaint);
    }
  }

  // 4. Khung thành (Cột dọc & Xà ngang)
  void _drawGoalPosts(Canvas canvas, Size size) {
    final goalLeft = size.width * 0.24;
    final goalRight = size.width * 0.76;
    final crossbarY = size.height * 0.16;
    final groundY = size.height * 0.39;

    // Viền tối mảnh bao quanh cột trắng để nổi rõ trên nền trời sáng
    final outlinePaint = Paint()
      ..color = const Color(0xFF546E7A)
      ..strokeWidth = 8.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final postPath = Path()
      ..moveTo(goalLeft, groundY)
      ..lineTo(goalLeft, crossbarY)
      ..lineTo(goalRight, crossbarY)
      ..lineTo(goalRight, groundY);

    canvas.drawPath(postPath, outlinePaint);

    final postPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 5.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawPath(postPath, postPaint);
  }

  // 5. Ba tấm bia hoa quả treo trên khung thành (Trái - Giữa - Phải)
  void _drawFruitTargets(Canvas canvas, Size size) {
    final goalCenter = size.width * 0.5;
    final goalHalfW = size.width * 0.25;
    final groundY = size.height * 0.39;
    final crossbarY = size.height * 0.16;
    final goalH = groundY - crossbarY;

    // Không được lộ đáp án khi đang ngắm (bé phải nghe & đọc chữ để chọn):
    // - Đang ngắm: chỉ sáng ô ĐANG NGẮM (màu trung tính) để dễ căn.
    // - Sau khi sút: sáng ô ĐÁP ÁN ĐÚNG màu xanh để bé học lại.
    final bool revealed = engine.ball.hasCollided;
    final int aimedSlot = PenaltyEngine.slotForX(engine.aimX);

    for (final target in engine.targets) {
      final bool isAnswer = revealed && target.slotIndex == engine.targetSlotIndex;
      final bool isAimed = !revealed && !engine.ball.inFlight && target.slotIndex == aimedSlot;
      final tx = goalCenter + target.x * goalHalfW;
      final ty = groundY - target.y * goalH;

      canvas.save();
      canvas.translate(tx, ty);

      // Hiệu ứng rung lắc khi bị bóng đập trúng
      if (target.hitWobble > 0) {
        // Ô giờ to bằng 1/3 khung thành nên chỉ rung nhẹ để không đè lên cột/ô bên cạnh
        final wobbleAngle = math.sin(target.hitWobble * 22.0) * 0.05 * target.hitWobble;
        canvas.rotate(wobbleAngle);
      }

      // 3 ô phủ kín khung thành: mỗi ô rộng 1/3 khung, cao bằng cả khung (chừa khe nhỏ cho cột/xà)
      const gap = 4.0;
      final boardW = PenaltyEngine.slotWidth * goalHalfW - gap;
      final boardH = goalH - gap * 2;
      final rect = Rect.fromCenter(center: Offset.zero, width: boardW, height: boardH);

      final Color highlight = isAnswer ? const Color(0xFF2ECC40) : const Color(0xFFFF9800);
      final bool lit = isAnswer || isAimed;

      // Viền phát sáng neon
      if (lit) {
        final pulse = math.sin(animationValue * 6.0) * 0.25 + 0.75;
        final glowPaint = Paint()
          ..color = highlight.withValues(alpha: (isAnswer ? 0.45 : 0.25) * pulse)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
        canvas.drawRRect(RRect.fromRectAndRadius(rect.inflate(4), const Radius.circular(14)), glowPaint);
      }

      // Nền tấm bia trắng kem (ô đáp án đúng chuyển xanh nhạt)
      final bgPaint = Paint()
        ..color = isAnswer ? const Color(0xFFE8F8E0) : const Color(0xFFFFFBF0);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12)), bgPaint);

      // Khung viền tấm bia
      final borderPaint = Paint()
        ..color = lit ? highlight : const Color(0xFFB0BEC5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isAnswer ? 4.0 : (isAimed ? 3.5 : 1.5);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12)), borderPaint);

      // Chỉ hiển thị hình hoa quả, to và căn giữa ô
      final emojiSpan = TextSpan(
        text: target.fruit.emoji,
        style: TextStyle(fontSize: (math.min(boardW, boardH) * 0.62).clamp(24.0, 72.0)),
      );
      final emojiTp = TextPainter(text: emojiSpan, textDirection: TextDirection.ltr);
      emojiTp.layout();
      emojiTp.paint(canvas, Offset(-emojiTp.width / 2, -emojiTp.height / 2));

      canvas.restore();
    }
  }

  // 6. Tâm ngắm laser điều khiển theo Face / Hand
  void _drawAimReticle(Canvas canvas, Size size) {
    if (engine.ball.inFlight || engine.isGameOver) return;

    final goalCenter = size.width * 0.5;
    final goalHalfW = size.width * 0.25;
    final groundY = size.height * 0.39;
    final crossbarY = size.height * 0.16;
    final goalH = groundY - crossbarY;

    final rx = goalCenter + engine.aimX * goalHalfW;
    final ry = groundY - (engine.aimY * goalH);

    // Tâm ngắm 1 màu cố định: không đổi màu / hiện tên khi ngắm trúng để không lộ đáp án
    const reticleColor = Color(0xFFFF5722);

    final k = (size.shortestSide / 400).clamp(0.85, 1.6); // co giãn theo màn hình (khớp kidScale của HUD)
    final reticlePaint = Paint()
      ..color = reticleColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0 * k;

    final pulse = (20.0 + math.sin(animationValue * 8.0) * 2.0) * k;
    // Viền trắng phía dưới để tâm ngắm nổi trên mọi nền
    canvas.drawCircle(
      Offset(rx, ry),
      pulse,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.0 * k,
    );
    canvas.drawCircle(Offset(rx, ry), pulse, reticlePaint);

    // Vạch chữ thập
    canvas.drawLine(Offset(rx - pulse - 6 * k, ry), Offset(rx - pulse + 2 * k, ry), reticlePaint);
    canvas.drawLine(Offset(rx + pulse - 2 * k, ry), Offset(rx + pulse + 6 * k, ry), reticlePaint);
    canvas.drawLine(Offset(rx, ry - pulse - 6 * k), Offset(rx, ry - pulse + 2 * k), reticlePaint);
    canvas.drawLine(Offset(rx, ry + pulse - 2 * k), Offset(rx, ry + pulse + 6 * k), reticlePaint);

    // Tâm laser
    canvas.drawCircle(Offset(rx, ry), 4.0 * k, Paint()..color = reticleColor);
  }

  // 7. Quả bóng bóng đá 3D
  void _drawBall(Canvas canvas, Size size) {
    final goalCenter = size.width * 0.5;
    final goalHalfW = size.width * 0.25;
    final groundY = size.height * 0.39;
    final crossbarY = size.height * 0.16;
    final goalH = groundY - crossbarY;

    final spotX = size.width * 0.5;
    final spotY = size.height * 0.82;

    double bx, by, ballRadius;

    // Bóng to, dễ nhìn ở chấm phạt đền; nhỏ dần còn ~35% khi bay vào khung thành
    final baseRadius = (size.height * 0.07).clamp(22.0, 44.0);

    if (!engine.ball.inFlight && !engine.ball.hasCollided) {
      bx = spotX;
      by = spotY;
      ballRadius = baseRadius;
    } else {
      final t = engine.ball.z.clamp(0.0, 1.0);
      final destX = goalCenter + engine.ball.x * goalHalfW;
      final destY = groundY - (engine.ball.y * goalH);

      bx = spotX + (destX - spotX) * t;
      by = spotY + (destY - spotY) * t;
      ballRadius = baseRadius * (1.0 - 0.65 * t); // Thu nhỏ phối cảnh theo chiều sâu 3D
    }

    // Bóng đổ trên mặt cỏ
    final shadowPaint = Paint()..color = Colors.black26;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(bx, by + ballRadius * 0.8), width: ballRadius * 1.8, height: ballRadius * 0.7),
      shadowPaint,
    );

    // Thân quả bóng
    canvas.save();
    canvas.translate(bx, by);
    canvas.rotate(engine.ball.rotation);

    final img = ballImage;
    if (img != null) {
      // Quả bóng trong ảnh chiếm ~95% khung (có viền trong suốt) -> nới khung vẽ để bóng đúng bán kính
      final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
      final dst = Rect.fromCircle(center: Offset.zero, radius: ballRadius * 1.05);
      canvas.drawImageRect(img, src, dst, Paint()..filterQuality = FilterQuality.medium);
      canvas.restore();
      return;
    }

    final ballPaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset.zero, ballRadius, ballPaint);

    // Họa tiết ngũ giác đen
    final hexPaint = Paint()..color = const Color(0xFF1A1A1A);
    canvas.drawCircle(Offset.zero, ballRadius * 0.38, hexPaint);

    for (int i = 0; i < 5; i++) {
      final a = (i * 72.0) * math.pi / 180.0;
      final px = math.cos(a) * ballRadius * 0.75;
      final py = math.sin(a) * ballRadius * 0.75;
      canvas.drawCircle(Offset(px, py), ballRadius * 0.22, hexPaint);
    }

    canvas.restore();
  }

  // 8. Hạt hiệu ứng
  void _drawParticles(Canvas canvas, Size size) {
    final goalCenter = size.width * 0.5;
    final goalHalfW = size.width * 0.25;
    final groundY = size.height * 0.39;
    final crossbarY = size.height * 0.16;
    final goalH = groundY - crossbarY;

    for (final p in engine.particles) {
      final px = goalCenter + p.x * goalHalfW;
      final py = groundY - (p.y * goalH);
      final alpha = (p.life / p.maxLife).clamp(0.0, 1.0);

      final paint = Paint()
        ..color = Color(p.colorValue).withValues(alpha: alpha)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(px, py), p.size * alpha, paint);
    }
  }

  @override
  bool shouldRepaint(covariant PenaltyCanvasPainter oldDelegate) => true;
}
