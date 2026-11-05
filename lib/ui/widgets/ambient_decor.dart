import 'dart:math' as math;
import 'package:flutter/painting.dart';

/// Hoạt cảnh nền dùng chung cho các game (mây trôi, chim bay, bướm, bóng bay, cờ dây) để cảnh vật sinh động.
///
/// Vẽ thẳng trong CustomPainter của game (đúng lớp: sau nền, trước trứng / bóng / khung thành), theo thời gian
/// [t] tính bằng giây. Hiệu năng: mỗi nhóm gộp vào 1-2 Path => chỉ vài lệnh vẽ mỗi khung, không tạo Paint mới.
class AmbientDecor {
  AmbientDecor._();

  static final Paint _cloudPaint = Paint()..color = const Color(0xF2FFFFFF);
  static final Paint _cloudShadePaint = Paint()..color = const Color(0x22607D8B);
  static final Paint _birdPaint = Paint()
    ..color = const Color(0xFF455A64)
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  static final Paint _fillPaint = Paint();
  static final Paint _linePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  // ---------------------------------------------------------------------------------------------------------
  // Mây
  // ---------------------------------------------------------------------------------------------------------

  /// Mây trôi ngang trong [area]: mỗi đám (x0, y, tỉ lệ, tốc độ) — x0, y theo tỉ lệ [area], tốc độ = bề ngang
  /// [area] / giây. Ra khỏi mép phải thì vòng lại từ mép trái.
  static void drawClouds(
    Canvas canvas,
    Rect area,
    double t,
    List<(double, double, double, double)> clouds, {
    required double size,
  }) {
    final path = Path();
    final shade = Path();
    for (final (x0, y, scale, speed) in clouds) {
      final x = ((x0 + t * speed) % 1.4) - 0.2;
      final c = Offset(area.left + x * area.width, area.top + y * area.height);
      final r = size * scale;
      path
        ..addOval(Rect.fromCircle(center: c, radius: r))
        ..addOval(Rect.fromCircle(center: c.translate(-r * 1.05, r * 0.3), radius: r * 0.7))
        ..addOval(Rect.fromCircle(center: c.translate(r * 1.1, r * 0.3), radius: r * 0.75))
        ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTRB(c.dx - r * 1.6, c.dy + r * 0.2, c.dx + r * 1.7, c.dy + r * 0.85),
          Radius.circular(r * 0.4),
        ));
      shade.addRRect(RRect.fromRectAndRadius(
        Rect.fromLTRB(c.dx - r * 1.4, c.dy + r * 0.62, c.dx + r * 1.5, c.dy + r * 0.92),
        Radius.circular(r * 0.3),
      ));
    }
    canvas.drawPath(shade, _cloudShadePaint);
    canvas.drawPath(path, _cloudPaint);
  }

  // ---------------------------------------------------------------------------------------------------------
  // Chim
  // ---------------------------------------------------------------------------------------------------------

  /// Đàn chim nhỏ vỗ cánh bay ngang [area] theo chu kỳ [period] giây (bay qua ~60% chu kỳ, còn lại nghỉ ngoài
  /// màn hình để trời không lúc nào cũng có chim). [phase] (0..1) để các đàn khác nhau không bay cùng lúc.
  static void drawBirdFlock(
    Canvas canvas,
    Rect area,
    double t, {
    required double size,
    double period = 24,
    double phase = 0,
    int count = 3,
    bool leftToRight = true,
  }) {
    final cycle = ((t / period) + phase) % 1.0;
    const flyPart = 0.6;
    if (cycle > flyPart) return;
    final p = cycle / flyPart; // 0 -> 1 trong lúc bay qua
    final travel = area.width + size * 12;
    final baseX = leftToRight ? area.left - size * 6 + p * travel : area.right + size * 6 - p * travel;
    final baseY = area.top + area.height * (0.35 + 0.25 * math.sin(p * math.pi * 2 + phase * 6));

    final path = Path();
    for (int i = 0; i < count; i++) {
      // Đội hình chữ V lỏng, mỗi con vỗ cánh lệch nhịp
      final dx = (leftToRight ? -1 : 1) * i * size * 2.2;
      final dy = (i.isEven ? 1 : -1) * ((i + 1) ~/ 2) * size * 1.1 + math.sin(t * 2.0 + i) * size * 0.3;
      final c = Offset(baseX + dx, baseY + dy);
      final s = size * (1.0 - i * 0.08);
      final flap = math.sin(t * 9.0 + i * 1.7); // -1 (cánh cụp) .. 1 (cánh giương)
      final tipY = c.dy - flap * s * 0.55;
      path
        ..moveTo(c.dx - s, tipY)
        ..quadraticBezierTo(c.dx - s * 0.45, c.dy - s * 0.55 - flap * s * 0.2, c.dx, c.dy)
        ..quadraticBezierTo(c.dx + s * 0.45, c.dy - s * 0.55 - flap * s * 0.2, c.dx + s, tipY);
    }
    _birdPaint.strokeWidth = math.max(1.2, size * 0.2);
    canvas.drawPath(path, _birdPaint);
  }

  // ---------------------------------------------------------------------------------------------------------
  // Bướm
  // ---------------------------------------------------------------------------------------------------------

  /// 1 con bướm bay lượn quanh vùng [area] (quỹ đạo Lissajous, không bao giờ ra khỏi vùng), vỗ cánh liên tục
  static void drawButterfly(
    Canvas canvas,
    Rect area,
    double t, {
    required double size,
    required Color color,
    double seed = 0,
  }) {
    final x = area.center.dx + area.width * 0.5 * math.sin(t * 0.37 + seed * 2.1);
    final y = area.center.dy + area.height * 0.5 * math.sin(t * 0.61 + seed * 1.3) * math.cos(t * 0.23 + seed);
    // Hướng bay (để thân hơi nghiêng theo chiều di chuyển)
    final vx = math.cos(t * 0.37 + seed * 2.1);
    final flap = 0.25 + 0.75 * (0.5 + 0.5 * math.sin(t * 16.0 + seed * 5)).abs(); // bề rộng cánh 25% -> 100%

    canvas.save();
    canvas.translate(x, y + math.sin(t * 5 + seed) * size * 0.3);
    canvas.rotate(vx * 0.25);

    final wings = Path();
    for (final side in const [-1.0, 1.0]) {
      final ww = size * flap;
      wings
        ..addOval(Rect.fromCenter(center: Offset(side * ww * 0.55, -size * 0.3), width: ww * 1.1, height: size * 1.0))
        ..addOval(Rect.fromCenter(center: Offset(side * ww * 0.45, size * 0.35), width: ww * 0.8, height: size * 0.7));
    }
    _fillPaint.color = color;
    canvas.drawPath(wings, _fillPaint);

    _linePaint
      ..color = const Color(0xFF4E342E)
      ..strokeWidth = math.max(1.0, size * 0.18);
    canvas.drawLine(Offset(0, -size * 0.55), Offset(0, size * 0.6), _linePaint);
    canvas.restore();
  }

  // ---------------------------------------------------------------------------------------------------------
  // Bóng bay
  // ---------------------------------------------------------------------------------------------------------

  /// Bóng bay bay lên từ đáy [area] tới đỉnh rồi lặp lại sau [period] giây, đung đưa nhẹ
  static void drawBalloon(
    Canvas canvas,
    Rect area,
    double t, {
    required double size,
    required Color color,
    double x = 0.5,
    double period = 14,
    double phase = 0,
  }) {
    final p = ((t / period) + phase) % 1.0;
    final cx = area.left + area.width * x + math.sin(t * 1.3 + phase * 9) * size * 0.8;
    final cy = area.bottom + size * 2 - p * (area.height + size * 5);
    final body = Rect.fromCenter(center: Offset(cx, cy), width: size * 1.6, height: size * 2.0);

    _linePaint
      ..color = const Color(0x99FFFFFF)
      ..strokeWidth = math.max(1.0, size * 0.08);
    final sway = math.sin(t * 2.1 + phase * 7) * size * 0.4;
    final string = Path()
      ..moveTo(cx, body.bottom)
      ..quadraticBezierTo(cx + sway, body.bottom + size * 0.9, cx - sway * 0.5, body.bottom + size * 1.8);
    canvas.drawPath(string, _linePaint);

    _fillPaint.color = color;
    canvas.drawOval(body, _fillPaint);
    final knot = Path()
      ..moveTo(cx - size * 0.15, body.bottom + size * 0.18)
      ..lineTo(cx + size * 0.15, body.bottom + size * 0.18)
      ..lineTo(cx, body.bottom - size * 0.05)
      ..close();
    canvas.drawPath(knot, _fillPaint);
    _fillPaint.color = const Color(0x66FFFFFF);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - size * 0.35, cy - size * 0.45), width: size * 0.4, height: size * 0.6),
      _fillPaint,
    );
  }

  // ---------------------------------------------------------------------------------------------------------
  // Cờ dây
  // ---------------------------------------------------------------------------------------------------------

  static const List<Color> _buntingColors = [
    Color(0xFFFF6B6B),
    Color(0xFFFFD43B),
    Color(0xFF4DABF7),
    Color(0xFF69DB7C),
  ];

  /// Dây cờ đuôi nheo căng từ [from] tới [to] (võng xuống ở giữa), các lá cờ phấp phới theo gió.
  /// Gộp cờ cùng màu vào 1 Path: dù nhiều cờ cũng chỉ 5 lệnh vẽ.
  static void drawBunting(Canvas canvas, Offset from, Offset to, double t, {required double flagSize, double sag = 0.15}) {
    final length = (to - from).distance;
    final count = math.max(4, (length / (flagSize * 1.5)).floor());
    final sagPx = length * sag;
    Offset at(double k) =>
        Offset.lerp(from, to, k)! + Offset(0, sagPx * 4 * k * (1 - k) + math.sin(t * 1.5 + k * 3) * flagSize * 0.12);

    final rope = Path()..moveTo(from.dx, from.dy);
    for (int i = 1; i <= 24; i++) {
      final p = at(i / 24);
      rope.lineTo(p.dx, p.dy);
    }
    _linePaint
      ..color = const Color(0xCC5D4037)
      ..strokeWidth = math.max(1.0, flagSize * 0.08);
    canvas.drawPath(rope, _linePaint);

    final flags = List.generate(_buntingColors.length, (_) => Path());
    for (int i = 0; i < count; i++) {
      final k0 = (i + 0.15) / count;
      final k1 = (i + 0.85) / count;
      final a = at(k0), b = at(k1);
      final mid = Offset.lerp(a, b, 0.5)!;
      final flutter = math.sin(t * 4.0 + i * 0.9) * flagSize * 0.25;
      flags[i % flags.length]
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy)
        ..lineTo(mid.dx + flutter, mid.dy + flagSize * 1.1)
        ..close();
    }
    for (int i = 0; i < flags.length; i++) {
      _fillPaint.color = _buntingColors[i];
      canvas.drawPath(flags[i], _fillPaint);
    }
  }
}
