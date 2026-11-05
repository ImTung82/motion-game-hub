import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../ui/widgets/ambient_decor.dart';
import '../../ui/widgets/text_painter_cache.dart';
import 'goalkeeper_engine.dart';
import 'goalkeeper_models.dart';

class GoalkeeperCanvas extends StatelessWidget {
  final GoalkeeperEngine engine;
  final ui.Image? ballImage;

  const GoalkeeperCanvas({
    super.key,
    required this.engine,
    this.ballImage,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox.expand(
        child: CustomPaint(
          painter: _GoalkeeperPainter(
            engine: engine,
            ballImage: ballImage,
          ),
        ),
      ),
    );
  }
}

class _GoalkeeperPainter extends CustomPainter {
  final GoalkeeperEngine engine;
  final ui.Image? ballImage;

  _GoalkeeperPainter({
    required this.engine,
    this.ballImage,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final layout = KeeperLayout(size);
    final double w = size.width;
    final double h = size.height;
    final double horizonY = h * 0.40; // Đường chân trời

    // Rung màn hình khi bé bắt bóng bằng 2 tay
    canvas.save();
    if (engine.screenShake > 0) {
      final amp = engine.screenShake * 8 * layout.u;
      canvas.translate(math.sin(engine.effectTime * 60) * amp, math.cos(engine.effectTime * 53) * amp * 0.7);
    }

    // 1. VẼ BẦU TRỜI, KHÁN ĐÀI & KHÁN GIẢ
    _drawSkyAndStadium(canvas, layout, w, horizonY);

    // 2. VẼ MẶT CỎ 3D VÀ KẺ VẠCH PHỐI CẢNH
    _drawPitch(canvas, layout, w, h, horizonY);

    // 3. CẦU THỦ SÚT BÓNG & QUẢ BÓNG ĐANG NẰM CHỜ TRÊN CHẤM PHẠT ĐỀN
    _drawKicker(canvas, layout);
    _drawRestingBall(canvas, layout);

    // 4. VẼ KHUNG THÀNH VÀ LƯỚI 3D
    _drawGoalNetAndPosts(canvas, layout, w, h);

    // 5. VÒNG BÁO TRƯỚC ĐIỂM BÓNG TỚI
    if (engine.difficulty.showTargetMarker) _drawTargetMarkers(canvas, layout);

    // 6. VẼ CÁC QUẢ BÓNG BAY TỚI
    _drawBalls(canvas, layout);

    // 7. VẼ CẢ 2 GĂNG TAY THỦ MÔN (CYAN & PINK)
    _drawGloves(canvas, layout);

    // 8. VẼ HẠT NGÔI SAO, TIA LỬA & PHÁO GIẤY
    _drawParticles(canvas, layout);

    canvas.restore();
  }

  void _drawSkyAndStadium(Canvas canvas, KeeperLayout l, double w, double horizonY) {
    final u = l.u;
    final m = 12 * u; // Vẽ tràn ra ngoài 1 chút để rung màn hình không lộ mép

    // Bầu trời ban ngày tươi sáng rực rỡ
    final skyRect = Rect.fromLTRB(-m, -m, w + m, horizonY);
    final skyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF6EC6FF), Color(0xFFB3E5FC), Color(0xFFE1F5FE)],
        stops: [0.0, 0.6, 1.0],
      ).createShader(skyRect);
    canvas.drawRect(skyRect, skyPaint);

    // Khán đài xa xa (Dãy màu tím nhạt và đèn sân vận động)
    final standH = 45 * u;
    final roofTop = horizonY - standH - 12.0 * u;

    // Cảnh trời chuyển động (sau khán đài & khung thành): mây trôi, chim bay
    final t = engine.effectTime;
    final sky = Rect.fromLTWH(0, 0, w, roofTop);
    AmbientDecor.drawClouds(
      canvas,
      sky,
      t,
      const [(0.1, 0.35, 1.0, 0.016), (0.5, 0.2, 0.8, 0.011), (0.8, 0.55, 0.65, 0.02)],
      size: 18 * u,
    );
    AmbientDecor.drawBirdFlock(canvas, Rect.fromLTWH(0, roofTop * 0.15, w, roofTop * 0.5), t, size: 8 * u, period: 21);
    AmbientDecor.drawBirdFlock(canvas, Rect.fromLTWH(0, roofTop * 0.1, w, roofTop * 0.45), t,
        size: 6.5 * u, period: 28, phase: 0.5, count: 2, leftToRight: false);
    final standRect = Rect.fromLTRB(-m, horizonY - standH, w + m, horizonY);
    final standPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFB39DDB), Color(0xFF9FA8DA)],
      ).createShader(standRect);
    canvas.drawRect(standRect, standPaint);

    // Khán giả: nhún nhẹ khi xem, nhảy cẫng lên khi bé bắt bóng 2 tay
    _drawCrowd(canvas, l, w, horizonY, standH);

    // Mái che khán đài kẻ sọc đỏ trắng vui nhộn cho trẻ nhỏ
    final roofH = 12.0 * u;
    final stripeW = w / 24;
    for (int i = 0; i < 24; i++) {
      canvas.drawRect(
        Rect.fromLTWH(i * stripeW, horizonY - standH - roofH, stripeW + 0.5, roofH),
        Paint()..color = i.isEven ? const Color(0xFFFF6B6B) : Colors.white,
      );
    }

    // Dây cờ đuôi nheo phấp phới trên mép mái khán đài
    AmbientDecor.drawBunting(canvas, Offset(-m, roofTop), Offset(w * 0.5, roofTop), t, flagSize: 9 * u, sag: 0.04);
    AmbientDecor.drawBunting(canvas, Offset(w * 0.5, roofTop), Offset(w + m, roofTop), t + 1.3, flagSize: 9 * u, sag: 0.04);

    // Đèn chiếu sáng sân vận động (Floodlights) 2 bên
    _drawStadiumLight(canvas, u, 60 * u, horizonY - standH - 5 * u);
    _drawStadiumLight(canvas, u, w - 60 * u, horizonY - standH - 5 * u);
  }

  void _drawCrowd(Canvas canvas, KeeperLayout l, double w, double horizonY, double standH) {
    const colors = [
      Color(0xFFFFCC80),
      Color(0xFF8D6E63),
      Color(0xFFFFE0B2),
      Color(0xFFD7A86E),
    ];
    const shirts = [
      Color(0xFFFF5252),
      Color(0xFFFFD600),
      Color(0xFF40C4FF),
      Color(0xFF69F0AE),
      Color(0xFFE040FB),
    ];
    final u = l.u;
    final spacing = 18 * u;
    final headR = 6.5 * u;
    final jump = engine.crowdJump;

    for (int row = 0; row < 2; row++) {
      final baseY = horizonY - standH + (row == 0 ? 14 : 32) * u;
      final offsetX = row == 0 ? 0.0 : spacing / 2;
      final count = (w / spacing).ceil() + 1;
      for (int i = 0; i < count; i++) {
        final seed = i * 7 + row * 3;
        final double bounce = jump > 0
            ? (math.sin(engine.effectTime * 14 + seed * 0.7)).abs() * 8 * u * jump
            : (math.sin(engine.effectTime * 2 + seed)).abs() * 1.2 * u;
        final x = offsetX + i * spacing;
        final y = baseY - bounce;
        canvas.drawCircle(Offset(x, y + headR * 1.4), headR * 1.1, Paint()..color = shirts[seed % shirts.length]);
        canvas.drawCircle(Offset(x, y), headR, Paint()..color = colors[seed % colors.length]);
        // Giơ 2 tay lên khi ăn mừng
        if (jump > 0.15) {
          final armPaint = Paint()
            ..color = colors[seed % colors.length]
            ..strokeWidth = 2.5 * u
            ..strokeCap = StrokeCap.round;
          canvas.drawLine(Offset(x - headR, y + headR), Offset(x - headR * 1.6, y - headR * 0.8), armPaint);
          canvas.drawLine(Offset(x + headR, y + headR), Offset(x + headR * 1.6, y - headR * 0.8), armPaint);
        }
      }
    }
  }

  void _drawStadiumLight(Canvas canvas, double u, double x, double y) {
    final polePaint = Paint()
      ..color = Colors.white70
      ..strokeWidth = 3.0 * u;
    canvas.drawLine(Offset(x, y), Offset(x, y + 40 * u), polePaint);

    // Cụm đèn
    final lightPaint = Paint()..color = Colors.white;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, y), width: 24 * u, height: 12 * u), Radius.circular(4 * u)),
      lightPaint,
    );
  }

  void _drawPitch(Canvas canvas, KeeperLayout l, double w, double h, double horizonY) {
    final u = l.u;
    final m = 12 * u;
    final centerX = w / 2;

    // Nền cỏ tổng thể xanh tươi mướt mắt
    final pitchRect = Rect.fromLTRB(-m, horizonY, w + m, h + m);
    final pitchPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF43A047), Color(0xFF2E7D32)],
      ).createShader(pitchRect);
    canvas.drawRect(pitchRect, pitchPaint);

    // Các dải cỏ sọc 3D phối cảnh
    final stripePaint = Paint()..color = const Color(0x22FFFFFF);
    const int numStripes = 8;
    for (int i = 0; i < numStripes; i += 2) {
      final double topY = horizonY + (h - horizonY) * (i / numStripes);
      final double botY = horizonY + (h - horizonY) * ((i + 1) / numStripes);
      canvas.drawRect(Rect.fromLTRB(-m, topY, w + m, botY), stripePaint);
    }

    // Vạch vôi 3D
    final linePaint = Paint()
      ..color = Colors.white60
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0 * u;

    // Chấm phạt đền 11m (nơi bóng bắt đầu sút)
    final spot = l.toScreen(0, GoalkeeperEngine.ballStartY);
    canvas.drawOval(Rect.fromCenter(center: spot, width: 14 * u, height: 6 * u), Paint()..color = Colors.white70);

    // Vòng cấm địa 3D
    final boxPath = Path()
      ..moveTo(centerX - w * 0.28, h * 0.95)
      ..lineTo(centerX - w * 0.18, horizonY + (h - horizonY) * 0.45)
      ..lineTo(centerX + w * 0.18, horizonY + (h - horizonY) * 0.45)
      ..lineTo(centerX + w * 0.28, h * 0.95);
    canvas.drawPath(boxPath, linePaint);
  }

  /// Chú gấu cầu thủ: đứng chờ phía sau bóng, chạy đà chéo tới rồi vung chân sút
  void _drawKicker(Canvas canvas, KeeperLayout l) {
    final u = l.u;
    final run = Curves.easeIn.transform(engine.kickerApproach.clamp(0.0, 1.0));
    final ballPos = l.toScreen(engine.kickerX, GoalkeeperEngine.ballStartY);

    // Vị trí bàn chân: lúc chờ lùi xa phía sau-bên trái, lúc sút sát ngay sau bóng
    final feet = ballPos + Offset.lerp(Offset(-40 * u, -36 * u), Offset(-16 * u, -6 * u), run)!;
    final isRunning = engine.kickerApproach > 0 && engine.kickerApproach < 1 && engine.kickAnim <= 0;
    final bob = isRunning
        ? -(math.sin(engine.kickerApproach * math.pi * 6)).abs() * 4 * u
        : math.sin(engine.effectTime * 3) * 0.8 * u;
    final k = u * (0.9 + 0.15 * run); // Lại gần thì to hơn chút (phối cảnh)

    // Bóng đổ dưới chân
    canvas.drawOval(Rect.fromCenter(center: feet, width: 30 * k, height: 7 * k), Paint()..color = const Color(0x33000000));

    canvas.save();
    canvas.translate(feet.dx, feet.dy - 27 * k + bob);

    const fur = Color(0xFF8D6E63);
    const furDark = Color(0xFF6D4C41);
    final furPaint = Paint()..color = fur;

    // Chân: chân phải vung lên khi sút
    final legPaint = Paint()..color = furDark;
    final step = isRunning ? math.sin(engine.kickerApproach * math.pi * 6) * 3 * k : 0.0;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(-6 * k, 18 * k + step), width: 8 * k, height: 14 * k), Radius.circular(4 * k)), legPaint);
    canvas.save();
    canvas.translate(6 * k, 11 * k);
    canvas.rotate(-engine.kickAnim * 1.1);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-4 * k, 0, 8 * k, 14 * k - step), Radius.circular(4 * k)), legPaint);
    canvas.restore();

    // Tay đánh theo nhịp chạy
    final armSwing = isRunning ? math.sin(engine.kickerApproach * math.pi * 6) * 4 * k : 0.0;
    canvas.drawCircle(Offset(-15 * k, 2 * k + armSwing), 5 * k, furPaint);
    canvas.drawCircle(Offset(15 * k, 2 * k - armSwing), 5 * k, furPaint);

    // Thân mặc áo đấu đỏ, số 10
    canvas.drawCircle(Offset.zero, 14 * k, Paint()..color = const Color(0xFFE53935));
    canvas.drawRect(Rect.fromCenter(center: Offset(0, -2 * k), width: 26 * k, height: 3 * k), Paint()..color = Colors.white);
    // Số áo layout 1 lần ở cỡ gốc (u) rồi phóng theo k bằng canvas.scale (k đổi mỗi khung khi cầu thủ chạy đà)
    final numberPainter = TextPainterCache.get('10', TextStyle(color: Colors.white, fontSize: 9 * u, fontWeight: FontWeight.w900));
    canvas.save();
    canvas.translate(0, 2 * k);
    canvas.scale(k / u);
    numberPainter.paint(canvas, Offset(-numberPainter.width / 2, 0));
    canvas.restore();

    // Đầu gấu
    canvas.drawCircle(Offset(-10 * k, -30 * k), 5 * k, furPaint);
    canvas.drawCircle(Offset(10 * k, -30 * k), 5 * k, furPaint);
    canvas.drawCircle(Offset(-10 * k, -30 * k), 2.5 * k, Paint()..color = const Color(0xFFFFAB91));
    canvas.drawCircle(Offset(10 * k, -30 * k), 2.5 * k, Paint()..color = const Color(0xFFFFAB91));
    canvas.drawCircle(Offset(0, -20 * k), 13 * k, furPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(0, -15 * k), width: 12 * k, height: 8 * k), Paint()..color = const Color(0xFFD7CCC8));
    canvas.drawCircle(Offset(0, -17 * k), 2.2 * k, Paint()..color = Colors.black87);
    canvas.drawCircle(Offset(-5 * k, -23 * k), 2 * k, Paint()..color = Colors.black87);
    canvas.drawCircle(Offset(5 * k, -23 * k), 2 * k, Paint()..color = Colors.black87);
    canvas.drawCircle(Offset(-4.4 * k, -23.6 * k), 0.7 * k, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(5.6 * k, -23.6 * k), 0.7 * k, Paint()..color = Colors.white);

    canvas.restore();
  }

  /// Quả bóng nằm chờ trên chấm phạt đền (ẩn ngay sau cú sút, rồi quả mới được đặt lại)
  void _drawRestingBall(Canvas canvas, KeeperLayout l) {
    if (engine.kickAnim > 0 || engine.phase == KeeperPhase.setup) return;
    final pos = l.toScreen(engine.nextStartX, GoalkeeperEngine.ballStartY);
    _drawBallSprite(canvas, pos, l.ballRadius(0), 0);
  }

  void _drawGoalNetAndPosts(Canvas canvas, KeeperLayout l, double w, double h) {
    final u = l.u;
    final centerX = w / 2;

    // Kích thước khung thành theo phối cảnh màn hình
    final double goalW = w * 0.88;
    final double goalLeft = centerX - goalW / 2;
    final double goalRight = centerX + goalW / 2;
    final double crossbarY = h * 0.16;
    final double groundY = h * 0.90;

    // 1. Lưới khung thành, rung rinh khi bóng lọt lưới
    final netPaint = Paint()
      ..color = const Color(0x33FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 * u;

    const int netCols = 22;
    const int netRows = 14;
    final shake = engine.netShake;
    final t = engine.effectTime;

    for (int c = 0; c <= netCols; c++) {
      final double dx = shake > 0 ? math.sin(t * 40 + c * 0.8) * 6 * u * shake : 0.0;
      final double x = goalLeft + (goalW * (c / netCols));
      canvas.drawLine(Offset(x + dx, crossbarY), Offset(x + dx, groundY), netPaint);
    }
    for (int r = 0; r <= netRows; r++) {
      final double dy = shake > 0 ? math.sin(t * 36 + r * 0.9) * 5 * u * shake : 0.0;
      final double y = crossbarY + ((groundY - crossbarY) * (r / netRows));
      canvas.drawLine(Offset(goalLeft, y + dy), Offset(goalRight, y + dy), netPaint);
    }

    // 2. Cột dọc và xà ngang 3D (Goal Posts & Crossbar)
    final postPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 14.0 * u
      ..strokeCap = StrokeCap.round;

    final postShadowPaint = Paint()
      ..color = const Color(0x44000000)
      ..strokeWidth = 16.0 * u
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);

    // Bóng đổ khung thành
    canvas.drawLine(Offset(goalLeft, crossbarY + 6 * u), Offset(goalRight, crossbarY + 6 * u), postShadowPaint);
    canvas.drawLine(Offset(goalLeft + 4 * u, crossbarY), Offset(goalLeft + 4 * u, groundY), postShadowPaint);
    canvas.drawLine(Offset(goalRight + 4 * u, crossbarY), Offset(goalRight + 4 * u, groundY), postShadowPaint);

    // Xà ngang & 2 cột dọc
    canvas.drawLine(Offset(goalLeft, crossbarY), Offset(goalRight, crossbarY), postPaint);
    canvas.drawLine(Offset(goalLeft, crossbarY), Offset(goalLeft, groundY), postPaint);
    canvas.drawLine(Offset(goalRight, crossbarY), Offset(goalRight, groundY), postPaint);

    // Mối nối góc bo tròn
    canvas.drawCircle(Offset(goalLeft, crossbarY), 9.0 * u, postPaint);
    canvas.drawCircle(Offset(goalRight, crossbarY), 9.0 * u, postPaint);
  }

  /// Vòng sáng trên lưới đánh dấu chỗ bóng sẽ tới: càng gần càng rõ & nhấp nháy càng nhanh
  void _drawTargetMarkers(Canvas canvas, KeeperLayout l) {
    final u = l.u;
    for (final ball in engine.balls) {
      if (ball.state != BallState.incoming) continue;
      final pos = l.toScreen(ball.targetX, ball.targetY);
      final double z = ball.z.clamp(0.0, 1.0);
      final double pulse = 1.0 + 0.08 * math.sin(engine.effectTime * (6 + z * 14));
      final double r = l.ballRadius(0.9) * pulse;
      final double alpha = 0.25 + 0.6 * z;
      final color = ball.wordItem.color;

      canvas.drawCircle(pos, r, Paint()..color = color.withValues(alpha: 0.15 * alpha));
      canvas.drawCircle(
        pos,
        r,
        Paint()
          ..color = color.withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4 * u,
      );
      canvas.drawCircle(
        pos,
        r * 0.55,
        Paint()
          ..color = Colors.white.withValues(alpha: alpha * 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 * u,
      );
    }
  }

  void _drawBallSprite(Canvas canvas, Offset pos, double radius, double rotation) {
    // Bóng đổ trên mặt đất (Drop shadow)
    canvas.drawOval(
      Rect.fromCenter(center: Offset(pos.dx, pos.dy + radius * 1.05), width: radius * 1.1, height: radius * 0.35),
      Paint()..color = const Color(0x3A000000),
    );

    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(rotation);

    if (ballImage != null) {
      final src = Rect.fromLTWH(0, 0, ballImage!.width.toDouble(), ballImage!.height.toDouble());
      final dst = Rect.fromCenter(center: Offset.zero, width: radius * 2, height: radius * 2);
      canvas.drawImageRect(ballImage!, src, dst, Paint()..filterQuality = FilterQuality.medium);
    } else {
      // Fallback bóng vector bóng đá truyền thống
      canvas.drawCircle(Offset.zero, radius, Paint()..color = Colors.white);
      canvas.drawCircle(Offset.zero, radius, Paint()..color = Colors.black87..style = PaintingStyle.stroke..strokeWidth = 2.5);
      canvas.drawCircle(Offset.zero, radius * 0.42, Paint()..color = Colors.black87);
    }
    canvas.restore();
  }

  void _drawBalls(Canvas canvas, KeeperLayout l) {
    for (final ball in engine.balls) {
      if (ball.state == BallState.dead) continue;

      final pos = l.toScreen(ball.currentX, ball.currentY);
      final double ballRadius = l.ballRadius(ball.z);
      _drawBallSprite(canvas, pos, ballRadius, ball.rotation);

      // HUY HIỆU TỪ VỰNG GẮN TRÊN BÓNG (Hiển thị khi bóng bay lại gần Z > 0.30)
      if (ball.z > 0.30 && ball.state != BallState.goal) {
        _drawWordBadge(canvas, l, Offset(pos.dx, pos.dy - ballRadius - 6 * l.u), ball.wordItem, ball.z);
      }
    }
  }

  /// Huy hiệu ưu tiên hình ảnh: emoji thật to (bé chưa biết đọc), chữ nhỏ bên dưới
  void _drawWordBadge(Canvas canvas, KeeperLayout l, Offset bottomCenter, WordItem word, double z) {
    final scale = (z * 1.1).clamp(0.65, 1.0) * l.u;

    // Chữ layout 1 lần ở cỡ gốc (l.u) rồi phóng theo độ sâu bằng canvas.scale: cỡ đổi mỗi khung khi bóng bay tới
    final double f = scale / l.u;
    final emojiPainter = TextPainterCache.get(word.emoji, TextStyle(fontSize: 30 * l.u));
    final labelPainter = TextPainterCache.get(
      word.label,
      TextStyle(color: const Color(0xFF1A237E), fontSize: 12 * l.u, fontWeight: FontWeight.w900, letterSpacing: 0.5),
    );

    final double padX = 10 * scale;
    final double padY = 4 * scale;
    final double badgeW = math.max(emojiPainter.width, labelPainter.width) * f + padX * 2;
    final double badgeH = (emojiPainter.height + labelPainter.height) * f + padY * 2;
    final rect = Rect.fromLTWH(bottomCenter.dx - badgeW / 2, bottomCenter.dy - badgeH, badgeW, badgeH);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(16 * scale));

    // Đổ bóng & nền
    canvas.drawRRect(
      rrect.shift(Offset(0, 3 * scale)),
      Paint()
        ..color = const Color(0x33000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0),
    );
    canvas.drawRRect(rrect, Paint()..color = Colors.white);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = word.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * scale,
    );

    canvas.save();
    canvas.translate(rect.center.dx, rect.top + padY);
    canvas.scale(f);
    emojiPainter.paint(canvas, Offset(-emojiPainter.width / 2, 0));
    labelPainter.paint(canvas, Offset(-labelPainter.width / 2, emojiPainter.height));
    canvas.restore();
  }

  void _drawGloves(Canvas canvas, KeeperLayout l) {
    // 1. TAY TRÁI (Cyan Glove)
    _drawSingleGlove(
      canvas: canvas,
      layout: l,
      glove: engine.leftGlove,
      mainColor: const Color(0xFF00E5FF),
      label: 'LEFT',
    );

    // 2. TAY PHẢI (Pink Glove)
    _drawSingleGlove(
      canvas: canvas,
      layout: l,
      glove: engine.rightGlove,
      mainColor: const Color(0xFFFF4081),
      label: 'RIGHT',
    );
  }

  void _drawSingleGlove({
    required Canvas canvas,
    required KeeperLayout layout,
    required GoalkeeperGlove glove,
    required Color mainColor,
    required String label,
  }) {
    final u = layout.u;
    final pos = layout.toScreen(glove.x, glove.y);

    // Nếu tay chưa phát hiện -> vẽ mờ mờ
    final double opacity = glove.detected ? 1.0 : 0.45;
    final double gloveSize = layout.gloveSize * (1.0 + glove.impactAnim * 0.25);

    canvas.save();
    canvas.translate(pos.dx, pos.dy);

    if (glove.detected) {
      // Vòng hào quang phát sáng
      canvas.drawCircle(
        Offset.zero,
        gloveSize * 0.85,
        Paint()
          ..color = mainColor.withValues(alpha: 0.25 + glove.impactAnim * 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12.0),
      );
      // Vòng vùng chạm: bóng chạm vào vòng này là cản được
      canvas.drawCircle(
        Offset.zero,
        layout.gloveReach(engine.difficulty),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 * u,
      );
    }

    // ✋ Găng tay thủ môn xòe với đệm lòng bàn tay
    final palmPaint = Paint()..color = mainColor.withValues(alpha: opacity);
    final palmBorder = Paint()
      ..color = Colors.white.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5 * u;
    final fingerRadius = Radius.circular(8 * u);

    // Lòng bàn tay
    final palm = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(0, 4 * u), width: gloveSize * 0.9, height: gloveSize * 0.85),
      Radius.circular(20 * u),
    );
    canvas.drawRRect(palm, palmPaint);
    canvas.drawRRect(palm, palmBorder);

    // Đệm cao su lòng bàn tay (Inner Grip Pad)
    canvas.drawCircle(Offset(0, 4 * u), gloveSize * 0.26, Paint()..color = Colors.white.withValues(alpha: opacity * 0.85));

    // 4 ngón tay vươn ra
    final fingerW = gloveSize * 0.18;
    final fingerH = gloveSize * 0.42;
    final offsets = [
      Offset(-gloveSize * 0.32, -gloveSize * 0.42),
      Offset(-gloveSize * 0.11, -gloveSize * 0.55),
      Offset(gloveSize * 0.11, -gloveSize * 0.55),
      Offset(gloveSize * 0.32, -gloveSize * 0.42),
    ];
    for (final off in offsets) {
      final finger = RRect.fromRectAndRadius(Rect.fromCenter(center: off, width: fingerW, height: fingerH), fingerRadius);
      canvas.drawRRect(finger, palmPaint);
      canvas.drawRRect(finger, palmBorder);
    }

    // Ngón cái (Thumb)
    final thumbX = glove.type == GloveType.left ? gloveSize * 0.42 : -gloveSize * 0.42;
    final thumb = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(thumbX, 0), width: fingerW * 1.1, height: fingerH * 0.85), fingerRadius);
    canvas.drawRRect(thumb, palmPaint);
    canvas.drawRRect(thumb, palmBorder);

    // Nhãn LEFT / RIGHT bên dưới
    final labelPainter = TextPainterCache.get(
      label,
      TextStyle(
        color: Colors.white.withValues(alpha: opacity),
        fontSize: 12 * u,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.8,
        shadows: const [Shadow(color: Colors.black54, offset: Offset(0, 2))],
      ),
    );
    labelPainter.paint(canvas, Offset(-labelPainter.width / 2, gloveSize * 0.56));

    canvas.restore();
  }

  void _drawParticles(Canvas canvas, KeeperLayout l) {
    final u = l.u;
    for (final p in engine.particles) {
      final pos = l.toScreen(p.x, p.y);
      final double progress = (p.life / p.maxLife).clamp(0.0, 1.0);

      if (p.confetti) {
        // Giấy pháo: giữ nguyên màu, chỉ mờ dần ở nửa giây cuối
        final double alpha = (p.life / 0.5).clamp(0.0, 1.0);
        canvas.save();
        canvas.translate(pos.dx, pos.dy);
        canvas.rotate(p.life * 8 + p.x * 10);
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: p.radius * 1.6 * u, height: p.radius * 0.8 * u),
          Paint()..color = p.color.withValues(alpha: alpha),
        );
        canvas.restore();
      } else if (p.emoji != null) {
        // Emoji co dần theo progress: layout 1 lần ở cỡ đầy đủ rồi canvas.scale
        if (progress <= 0) continue;
        final painter = TextPainterCache.get(p.emoji!, TextStyle(fontSize: p.radius * 2.8 * u));
        canvas.save();
        canvas.translate(pos.dx, pos.dy);
        canvas.scale(progress);
        painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
        canvas.restore();
      } else {
        canvas.drawCircle(pos, p.radius * progress * u, Paint()..color = p.color.withValues(alpha: progress));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GoalkeeperPainter oldDelegate) => true;
}
