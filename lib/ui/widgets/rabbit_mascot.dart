import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Biểu cảm của thỏ linh vật: bình thường (đọc đề), vui (trả lời đúng), buồn (trả lời sai)
enum RabbitMood { normal, happy, sad }

/// Hướng đuôi bóng thoại (chỉ về phía thỏ)
enum BubbleTail { left, bottom }

/// Thỏ linh vật + bóng thoại kiểu manga.
/// - [BubbleTail.left]: bóng thoại nằm BÊN PHẢI thỏ (đuôi chĩa sang trái về miệng thỏ)
/// - [BubbleTail.bottom]: bóng thoại nằm PHÍA TRÊN thỏ (đuôi chĩa xuống đầu thỏ)
class RabbitMascot extends StatefulWidget {
  static const Map<RabbitMood, AssetImage> images = {
    RabbitMood.normal: AssetImage('assets/images/rabbit_normal.png'),
    RabbitMood.happy: AssetImage('assets/images/rabbit_happy.png'),
    RabbitMood.sad: AssetImage('assets/images/rabbit_sad.png'),
  };

  final RabbitMood mood;
  final String? caption; // dòng nhỏ phía trên (vd: "Smash the egg:")
  final String headline; // dòng chính, to (vd: từ mục tiêu / "GREAT JOB!")
  final String? footnote; // dòng nhỏ phía dưới (vd: đáp án đúng)
  final double rabbitHeight;
  final double bubbleMaxWidth;
  final BubbleTail tail;
  final double textScale; // co giãn chữ & lề bóng thoại theo kích thước màn hình

  const RabbitMascot({
    super.key,
    required this.mood,
    required this.headline,
    this.caption,
    this.footnote,
    this.rabbitHeight = 130,
    this.bubbleMaxWidth = 220,
    this.tail = BubbleTail.left,
    this.textScale = 1.0,
  });

  @override
  State<RabbitMascot> createState() => _RabbitMascotState();
}

class _RabbitMascotState extends State<RabbitMascot> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Nạp sẵn cả 3 biểu cảm để lúc đổi ảnh không bị nháy
    for (final img in RabbitMascot.images.values) {
      precacheImage(img, context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rabbitWidth = widget.rabbitHeight * 0.64;
    final rabbit = _buildRabbit(rabbitWidth);
    final bubble = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: widget.bubbleMaxWidth),
      child: _buildBubble(),
    );

    // Chỉ để hiển thị: không chặn thao tác chạm của game
    return IgnorePointer(
      child: widget.tail == BubbleTail.left
          ? Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                rabbit,
                Padding(padding: EdgeInsets.only(top: widget.rabbitHeight * 0.18), child: bubble),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [bubble, const SizedBox(height: 2), rabbit],
            ),
    );
  }

  // Thỏ: đổi ảnh theo biểu cảm; vui thì nhảy lên, buồn thì lắc nhẹ
  Widget _buildRabbit(double width) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(widget.mood),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: widget.mood == RabbitMood.normal ? 1 : 650),
      builder: (context, t, child) {
        double dx = 0, dy = 0;
        if (widget.mood == RabbitMood.happy) {
          dy = -math.sin(t * math.pi) * widget.rabbitHeight * 0.12;
        } else if (widget.mood == RabbitMood.sad) {
          dx = math.sin(t * math.pi * 6) * (1 - t) * 5;
        }
        return Transform.translate(offset: Offset(dx, dy), child: child);
      },
      child: SizedBox(
        width: width,
        height: widget.rabbitHeight,
        child: Image(
          image: RabbitMascot.images[widget.mood]!,
          fit: BoxFit.contain,
          alignment: Alignment.bottomCenter,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
        ),
      ),
    );
  }

  Widget _buildBubble() {
    final (Color fill, Color accent) = switch (widget.mood) {
      RabbitMood.normal => (Colors.white, const Color(0xFF2E3A8C)),
      RabbitMood.happy => (const Color(0xFFFFF6C9), const Color(0xFF1B8A3A)),
      RabbitMood.sad => (const Color(0xFFE6EEFF), const Color(0xFFD32F2F)),
    };
    const textDark = Color(0xFF3A3A4A);
    const tailLen = _MangaBubblePainter.tailLength;
    final k = widget.textScale;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.caption != null)
          Text(
            widget.caption!,
            style: TextStyle(color: textDark, fontSize: 11.5 * k, fontWeight: FontWeight.w800, height: 1.15),
          ),
        Text(
          widget.headline,
          style: TextStyle(color: accent, fontSize: 22 * k, fontWeight: FontWeight.w900, letterSpacing: 1.2, height: 1.15),
        ),
        if (widget.footnote != null)
          Text(
            widget.footnote!,
            style: TextStyle(color: textDark, fontSize: 11 * k, fontWeight: FontWeight.w700, height: 1.2),
          ),
      ],
    );

    // Bóng thoại "bật" ra mỗi lần thỏ nói câu mới
    return TweenAnimationBuilder<double>(
      key: ValueKey('${widget.mood}|${widget.caption}|${widget.headline}|${widget.footnote}'),
      tween: Tween(begin: 0.55, end: 1.0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) => Transform.scale(
        scale: scale,
        alignment: widget.tail == BubbleTail.left ? Alignment.centerLeft : Alignment.bottomLeft,
        child: child,
      ),
      child: CustomPaint(
        painter: _MangaBubblePainter(mood: widget.mood, tail: widget.tail, fill: fill),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            (widget.tail == BubbleTail.left ? tailLen : 0) + 14 * k,
            9 * k,
            14 * k,
            (widget.tail == BubbleTail.bottom ? tailLen : 0) + 10 * k,
          ),
          child: content,
        ),
      ),
    );
  }
}

/// Bóng thoại manga: viền đen dày, bóng đổ cứng lệch góc, đuôi nhọn chỉ về thỏ.
/// Vui: thêm tia "action lines" toả ra xung quanh. Buồn: thêm vài nét "rầu rĩ" phía trên.
class _MangaBubblePainter extends CustomPainter {
  static const double tailLength = 14;

  final RabbitMood mood;
  final BubbleTail tail;
  final Color fill;

  _MangaBubblePainter({required this.mood, required this.tail, required this.fill});

  @override
  void paint(Canvas canvas, Size size) {
    final body = Rect.fromLTRB(
      tail == BubbleTail.left ? tailLength : 0,
      0,
      size.width,
      tail == BubbleTail.bottom ? size.height - tailLength : size.height,
    );

    final bodyPath = Path()..addRRect(RRect.fromRectAndRadius(body, const Radius.circular(18)));
    final tailPath = Path();
    if (tail == BubbleTail.left) {
      final y = math.min(22.0, body.height * 0.5);
      tailPath
        ..moveTo(body.left + 4, y - 8)
        ..lineTo(0, y + 12)
        ..lineTo(body.left + 4, y + 8)
        ..close();
    } else {
      const x = 34.0;
      tailPath
        ..moveTo(x - 9, body.bottom - 4)
        ..lineTo(x - 14, size.height)
        ..lineTo(x + 9, body.bottom - 4)
        ..close();
    }
    final shape = Path.combine(PathOperation.union, bodyPath, tailPath);

    // Bóng đổ cứng kiểu truyện tranh
    canvas.drawPath(shape.shift(const Offset(3, 3)), Paint()..color = const Color(0x66000000));
    canvas.drawPath(shape, Paint()..color = fill);
    canvas.drawPath(
      shape,
      Paint()
        ..color = const Color(0xFF15151F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeJoin = StrokeJoin.round,
    );

    final linePaint = Paint()
      ..color = const Color(0xFF15151F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    if (mood == RabbitMood.happy) {
      // Tia nhấn mạnh toả ra quanh bóng thoại (bỏ qua phía có đuôi)
      final c = body.center;
      final rx = body.width / 2, ry = body.height / 2;
      const count = 14;
      for (int i = 0; i < count; i++) {
        final a = -math.pi / 2 + i * 2 * math.pi / count;
        final dirX = math.cos(a), dirY = math.sin(a);
        if (tail == BubbleTail.left && dirX < -0.6) continue;
        if (tail == BubbleTail.bottom && dirY > 0.6 && dirX < 0) continue;
        canvas.drawLine(
          Offset(c.dx + dirX * (rx + 6), c.dy + dirY * (ry + 6)),
          Offset(c.dx + dirX * (rx + 15), c.dy + dirY * (ry + 13)),
          linePaint,
        );
      }
    } else if (mood == RabbitMood.sad) {
      // 3 nét rầu rĩ nhỏ ở góc trên phải
      for (int i = 0; i < 3; i++) {
        final x = body.right - 10 - i * 8.0;
        canvas.drawLine(Offset(x, body.top - 5), Offset(x - 2, body.top - 14), linePaint..strokeWidth = 1.8);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MangaBubblePainter old) =>
      old.mood != mood || old.tail != tail || old.fill != fill;
}
