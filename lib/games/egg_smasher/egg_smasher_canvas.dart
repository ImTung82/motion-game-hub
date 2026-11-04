import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../ui/widgets/text_painter_cache.dart';
import 'egg_smasher_engine.dart';
import 'egg_smasher_models.dart';

class EggSmasherCanvasPainter extends CustomPainter {
  final EggSmasherEngine engine;
  final double animationValue;

  EggSmasherCanvasPainter({
    required this.engine,
    required this.animationValue,
  }) : super(repaint: engine);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // 1. NỀN: ảnh bãi cỏ (assets/images/bg_egg_smasher.png) được vẽ bằng widget Image phía dưới canvas

    // 2. VẼ TỔ RƠM (NESTS) CHO CÁC QUẢ TRỨNG
    for (final egg in engine.eggs) {
      _drawStrawNest(canvas, size, egg);
    }

    // 3. VẼ CÁC QUẢ TRỨNG HOẠT HÌNH 3D & THẺ TỪ PHONICS
    for (final egg in engine.eggs) {
      _drawEgg(canvas, size, egg);
    }

    // 4. VẼ MẢNH VỠ VỎ TRỨNG NỔ TUNG TÓE
    for (final f in engine.fragments) {
      _drawEggFragment(canvas, size, f);
    }

    // 5. VẼ CÁC NGÔI SAO LẤP LÁNH
    for (final s in engine.sparkles) {
      _drawSparkleStar(canvas, size, s);
    }

    // 6. VẼ SINH VẬT ĐÁNG YÊU NỞ RA TỪ TRỨNG
    for (final c in engine.hatchedCreatures) {
      _drawHatchedCreature(canvas, size, c);
    }

    // 7. VẼ BÚA ĐẬP & CON TRỎ TAY
    _drawHammerCursor(canvas, size);
  }

  // ===========================================================================
  // 2. STRAW NEST (TỔ RƠM)
  // ===========================================================================
  void _drawStrawNest(Canvas canvas, Size size, EggItem egg) {
    final cx = egg.x * size.width;
    final cy = (egg.y + egg.radiusY * EggSmasherEngine.nestOffsetFactor) * size.height;
    final rw = egg.radiusX * size.width * 1.35;
    final rh = egg.radiusY * size.height * 0.42;

    // Bóng râm dưới tổ
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy + rh * 0.3), width: rw * 1.3, height: rh * 0.9), shadowPaint);

    // Lớp tổ chính (bó rơm đan)
    final nestPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFD7A15C), // Rơm vàng óng
          const Color(0xFF8D5B28), // Nâu vỏ cây
          const Color(0xFF4E2608), // Nâu sẫm
        ],
        stops: const [0.2, 0.7, 1.0],
      ).createShader(Rect.fromCenter(center: Offset(cx, cy), width: rw * 2, height: rh * 2));

    canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy), width: rw * 2, height: rh * 2), nestPaint);
  }

  // ===========================================================================
  // 3. EGG (QUẢ TRỨNG HOẠT HÌNH)
  // ===========================================================================
  void _drawEgg(Canvas canvas, Size size, EggItem egg) {
    if (egg.state == EggState.shattered) return;

    final cx = egg.x * size.width;
    final cy = egg.y * size.height;
    final rx = egg.radiusX * size.width;
    final ry = egg.radiusY * size.height;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(egg.wobbleAngle);
    canvas.scale(egg.bounceScale, egg.bounceScale);

    // Tạo đường cong hình quả trứng (thuôn nhọn ở đầu, bầu bĩnh ở đáy)
    final Path eggPath = Path();
    eggPath.moveTo(0, -ry);
    eggPath.cubicTo(rx * 0.82, -ry * 0.98, rx * 1.08, ry * 0.32, rx * 0.98, ry * 0.72);
    eggPath.cubicTo(rx * 0.88, ry * 1.05, -rx * 0.88, ry * 1.05, -rx * 0.98, ry * 0.72);
    eggPath.cubicTo(-rx * 1.08, ry * 0.32, -rx * 0.82, -ry * 0.98, 0, -ry);
    eggPath.close();

    // Hào quang tỏa sáng cho trứng
    final glowPaint = Paint()
      ..color = egg.colorTheme.glowColor.withValues(alpha: egg.colorTheme.glowColor.a * 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawPath(eggPath, glowPaint);

    // Tô màu 3D thể tích quả trứng
    final eggPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.42),
        radius: 0.95,
        colors: [
          Colors.white.withValues(alpha: 0.95), // Điểm sáng bóng rực
          egg.colorTheme.primary,
          egg.colorTheme.secondary,
        ],
        stops: const [0.0, 0.42, 1.0],
      ).createShader(Rect.fromCenter(center: Offset.zero, width: rx * 2.2, height: ry * 2.2));
    canvas.drawPath(eggPath, eggPaint);

    // Hoa văn đốm chấm ngộ nghĩnh (Dino spots)
    final spotPaint = Paint()
      ..color = egg.colorTheme.spotColor.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;

    canvas.save();
    canvas.clipPath(eggPath);
    canvas.drawCircle(Offset(-rx * 0.42, -ry * 0.35), rx * 0.22, spotPaint);
    canvas.drawCircle(Offset(rx * 0.48, -ry * 0.15), rx * 0.18, spotPaint);
    canvas.drawCircle(Offset(-rx * 0.32, ry * 0.45), rx * 0.26, spotPaint);
    canvas.drawCircle(Offset(rx * 0.38, ry * 0.52), rx * 0.20, spotPaint);

    // Vết nứt trên vỏ trứng nếu bị đập trúng
    if (egg.crackIntensity > 0) {
      _drawCracks(canvas, rx, ry, egg.crackIntensity);
    }
    canvas.restore();

    // Viền sáng bóng cạnh ngoài quả trứng
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    canvas.drawPath(eggPath, borderPaint);

    // THẺ TỪ PHONICS TRÊN BỤNG QUẢ TRỨNG
    _drawPhonicsBadge(canvas, rx, ry, egg);

    canvas.restore();
  }

  // Vẽ các tia nứt vỏ trứng
  void _drawCracks(Canvas canvas, double rx, double ry, double intensity) {
    final crackPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5 + intensity * 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final crackPath = Path();
    crackPath.moveTo(0, -ry * 0.2);
    crackPath.lineTo(rx * 0.25, -ry * 0.05);
    crackPath.lineTo(-rx * 0.15, ry * 0.15);
    crackPath.lineTo(rx * 0.3, ry * 0.35);
    crackPath.lineTo(0, ry * 0.55);

    // Nhánh phụ
    crackPath.moveTo(rx * 0.25, -ry * 0.05);
    crackPath.lineTo(rx * 0.6, -ry * 0.1);

    crackPath.moveTo(-rx * 0.15, ry * 0.15);
    crackPath.lineTo(-rx * 0.55, ry * 0.22);

    canvas.drawPath(crackPath, crackPaint);
  }

  // Huy hiệu hình ảnh minh họa trên quả trứng (Bỏ chữ ở state chưa đập, chỉ hiện tranh)
  void _drawPhonicsBadge(Canvas canvas, double rx, double ry, EggItem egg) {
    final badgeRadius = rx * 0.56;
    final badgeCenter = Offset(0, ry * 0.08);

    // Nền trắng sữa bóng loáng
    final badgePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.96)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(badgeCenter, badgeRadius, badgePaint);

    // Viền nổi bật theo màu trứng
    final badgeBorder = Paint()
      ..color = egg.colorTheme.primary
      ..strokeWidth = 3.2
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(badgeCenter, badgeRadius, badgeBorder);

    // Vẽ Icon Emoji minh họa to, rõ ràng, căn chính giữa huy hiệu
    final emojiPainter = TextPainterCache.get(egg.word.iconEmoji, TextStyle(fontSize: rx * 0.64));
    emojiPainter.paint(
      canvas,
      Offset(-emojiPainter.width / 2, badgeCenter.dy - emojiPainter.height / 2),
    );
  }

  // ===========================================================================
  // 4. EGG SHELL FRAGMENTS (MẢNH VỠ VỎ TRỨNG)
  // ===========================================================================
  void _drawEggFragment(Canvas canvas, Size size, EggShellFragment f) {
    final cx = f.x * size.width;
    final cy = f.y * size.height;
    final s = f.size * size.width;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(f.rotation);

    final fragPaint = Paint()
      ..color = f.color.withValues(alpha: f.life.clamp(0.0, 1.0))
      ..style = PaintingStyle.fill;

    // Tam giác nhọn vỏ trứng
    final path = Path();
    path.moveTo(0, -s);
    path.lineTo(s * 0.8, s * 0.9);
    path.lineTo(-s * 0.7, s * 0.7);
    path.close();

    canvas.drawPath(path, fragPaint);

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: f.life.clamp(0.0, 0.8))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawPath(path, linePaint);

    canvas.restore();
  }

  // ===========================================================================
  // 5. SPARKLE STARS (SAO THẦN TIÊN)
  // ===========================================================================
  void _drawSparkleStar(Canvas canvas, Size size, SparkleStar s) {
    final cx = s.x * size.width;
    final cy = s.y * size.height;
    final radius = s.size * size.width;

    final starPaint = Paint()
      ..color = s.color.withValues(alpha: s.life.clamp(0.0, 1.0))
      ..style = PaintingStyle.fill;

    // Ngôi sao 4 cánh nhọn
    final path = Path();
    path.moveTo(cx, cy - radius);
    path.quadraticBezierTo(cx, cy, cx + radius, cy);
    path.quadraticBezierTo(cx, cy, cx, cy + radius);
    path.quadraticBezierTo(cx, cy, cx - radius, cy);
    path.quadraticBezierTo(cx, cy, cx, cy - radius);
    path.close();

    canvas.drawPath(path, starPaint);
  }

  // ===========================================================================
  // 6. HATCHED CREATURE (SINH VẬT CUTE NỞ RA)
  // ===========================================================================
  void _drawHatchedCreature(Canvas canvas, Size size, HatchedCreature c) {
    final cx = c.x * size.width;
    final cy = (c.y + c.bounceY) * size.height;
    final scale = c.scale;
    if (scale <= 0.05) return;

    canvas.save();
    canvas.translate(cx, cy);
    final ui = _uiScale(size);
    canvas.scale(scale * ui, scale * ui);

    // Hào quang vàng rực rỡ phía sau
    final auraPaint = Paint()
      ..color = const Color(0xFFFFD600).withValues(alpha: 0.35 * c.life)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);
    canvas.drawCircle(Offset.zero, 60, auraPaint);

    // Bảng thẻ chúc mừng nở trứng
    final cardW = 116.0;
    final cardH = 96.0;
    final cardRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: cardW, height: cardH),
      const Radius.circular(20),
    );

    final cardPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFF9C4), Colors.white],
      ).createShader(Rect.fromCenter(center: Offset.zero, width: cardW, height: cardH));
    canvas.drawRRect(cardRect, cardPaint);

    final cardBorder = Paint()
      ..color = const Color(0xFFFFD600)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(cardRect, cardBorder);

    // Emoji to khổng lồ
    final emojiPainter = TextPainterCache.get(c.word.iconEmoji, const TextStyle(fontSize: 42));
    emojiPainter.paint(canvas, Offset(-emojiPainter.width / 2, -cardH * 0.42));

    // Chữ từ vựng Phonics
    final wordPainter = TextPainterCache.get(
      c.word.word,
      const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
        color: Color(0xFF0F172A),
      ),
    );
    wordPainter.paint(canvas, Offset(-wordPainter.width / 2, 14));

    canvas.restore();
  }

  // ===========================================================================
  // 7. HAMMER & CURSOR (BÚA ĐẬP ĐỒ CHƠI)
  // ===========================================================================
  void _drawHammerCursor(Canvas canvas, Size size) {
    final cx = engine.cursorX * size.width;
    final cy = engine.cursorY * size.height;
    final smashAnim = engine.hammerSmashAnim;

    // VÒNG MỤC TIÊU DƯỚI MẶT ĐẤT
    final ui = _uiScale(size);
    final reticleRadius = (32.0 + math.sin(animationValue * 4) * 3) * ui;
    // Màu kẹo ngọt hợp nền bãi cỏ: trắng (đang ngắm) / vàng (đang nắm tay kéo) / đỏ (đập)
    final Color activeColor = smashAnim > 0
        ? const Color(0xFFFF1744)
        : (engine.isHandGrabbing ? const Color(0xFFFFCA28) : Colors.white);
    final reticlePaint = Paint()
      ..color = activeColor.withValues(alpha: 0.95)
      ..strokeWidth = (engine.isHandGrabbing ? 4.0 : 3.0) * ui
      ..style = PaintingStyle.stroke;
    // Viền tối phía dưới để vòng ngắm nổi rõ trên nền trời xanh sáng
    canvas.drawCircle(
      Offset(cx, cy),
      reticleRadius,
      Paint()
        ..color = const Color(0xFF5D4037).withValues(alpha: 0.45)
        ..strokeWidth = reticlePaint.strokeWidth + 3 * ui
        ..style = PaintingStyle.stroke,
    );
    canvas.drawCircle(Offset(cx, cy), reticleRadius, reticlePaint);

    // Chấm tâm
    final centerDotPaint = Paint()
      ..color = smashAnim > 0 ? const Color(0xFFFF1744) : const Color(0xFFFFA726)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), 5.5 * ui, centerDotPaint);

    // Sóng chấn động khi đập búa xuống
    if (smashAnim > 0) {
      final waveRadius = (1.0 - smashAnim) * 80.0 * ui;
      final wavePaint = Paint()
        ..color = const Color(0xFFFFD600).withValues(alpha: smashAnim * 0.7)
        ..strokeWidth = 3.5 * ui
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(Offset(cx, cy), waveRadius, wavePaint);
    }

    // VẼ CÂY BÚA HOẠT HÌNH
    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(ui, ui);

    // Góc vung búa: Bình thường nghiêng nhẹ (-25 độ), khi đập bổ xuống (+45 độ)
    final hammerAngle = -0.45 + (smashAnim * 1.15);
    canvas.rotate(hammerAngle);

    // Cán búa (Gỗ sồi nâu ấm áp)
    final handlePaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFD7CCC8), Color(0xFF8D6E63), Color(0xFF4E342E)],
      ).createShader(const Rect.fromLTWH(-6, -75, 12, 75));

    final handleRRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-5, -80, 10, 80),
      const Radius.circular(5),
    );
    canvas.drawRRect(handleRRect, handlePaint);

    // Đầu búa đồ chơi sắc màu (Thân đỏ candy, 2 đầu bọc cao su vàng neon)
    final headRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-28, -108, 56, 32),
      const Radius.circular(8),
    );
    final headPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFF5252), Color(0xFFD50000)],
      ).createShader(const Rect.fromLTWH(-28, -108, 56, 32));
    canvas.drawRRect(headRect, headPaint);

    // 2 đầu đệm cao su vàng
    final cushionPaint = Paint()..color = const Color(0xFFFFD600);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-32, -106, 6, 28), const Radius.circular(3)), cushionPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(26, -106, 6, 28), const Radius.circular(3)), cushionPaint);

    // Sao vàng trang trí trên mặt búa
    final starPaint = Paint()..color = Colors.white;
    canvas.drawCircle(const Offset(0, -92), 4, starPaint);

    canvas.restore();
  }

  /// Hệ số co giãn các chi tiết vẽ bằng pixel (búa, vòng ngắm, thẻ sinh vật) theo màn hình,
  /// lấy cạnh ngắn 400px làm chuẩn (khớp kidScale của HUD)
  double _uiScale(Size size) => (size.shortestSide / 400).clamp(0.85, 1.6);

  @override
  bool shouldRepaint(covariant EggSmasherCanvasPainter oldDelegate) => true;
}
