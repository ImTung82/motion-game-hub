import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Bộ UI phong cách hoạt hình tươi sáng cho trẻ mẫu giáo:
/// màu kẹo ngọt, bo tròn, viền dày, bóng đổ "nổi khối" kiểu đồ chơi.
class KidColors {
  static const Color text = Color(0xFF5D4037); // nâu gỗ ấm (dễ đọc trên nền sáng)
  static const Color textSoft = Color(0xFF8D6E63);
  static const Color cream = Color(0xFFFFFBF0);

  static const Color green = Color(0xFF66BB6A);
  static const Color greenDark = Color(0xFF388E3C);
  static const Color orange = Color(0xFFFFA726);
  static const Color orangeDark = Color(0xFFEF6C00);
  static const Color blue = Color(0xFF42A5F5);
  static const Color blueDark = Color(0xFF1E88E5);
  static const Color pink = Color(0xFFFF7096);
  static const Color pinkDark = Color(0xFFD81B60);
  static const Color yellow = Color(0xFFFFCA28);
  static const Color yellowDark = Color(0xFFF9A825);
  static const Color grey = Color(0xFFBDBDBD);
  static const Color greyDark = Color(0xFF9E9E9E);
}

/// Hệ số co giãn UI theo màn hình: lấy cạnh ngắn 400px làm chuẩn (điện thoại nằm ngang)
double kidScale(BuildContext context) => (MediaQuery.sizeOf(context).shortestSide / 400).clamp(0.85, 1.6);

/// Nút tròn nổi khối: lún xuống khi bấm
class KidIconButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final Color shadowColor;
  final VoidCallback onPressed;
  final double size;
  final String? tooltip;

  const KidIconButton({
    super.key,
    required this.icon,
    required this.color,
    required this.shadowColor,
    required this.onPressed,
    this.size = 46,
    this.tooltip,
  });

  @override
  State<KidIconButton> createState() => _KidIconButtonState();
}

class _KidIconButtonState extends State<KidIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final depth = widget.size * 0.09;
    final button = GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onPressed,
      child: SizedBox(
        width: widget.size,
        height: widget.size + depth,
        child: Stack(
          children: [
            // Phần "đế" tối màu tạo cảm giác nổi khối
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: widget.size,
              child: DecoratedBox(decoration: BoxDecoration(color: widget.shadowColor, shape: BoxShape.circle)),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 70),
              left: 0,
              right: 0,
              top: _pressed ? depth : 0,
              height: widget.size,
              child: Container(
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: widget.size * 0.06),
                ),
                child: Icon(widget.icon, color: Colors.white, size: widget.size * 0.52),
              ),
            ),
          ],
        ),
      ),
    );
    return widget.tooltip == null ? button : Tooltip(message: widget.tooltip!, child: button);
  }
}

/// Nút chữ dạng viên kẹo (dùng trong hộp thoại)
class KidButton extends StatefulWidget {
  final String? label;
  final IconData icon;
  final Color color;
  final Color shadowColor;
  final VoidCallback onPressed;
  final double height;

  const KidButton({
    super.key,
    this.label,
    required this.icon,
    required this.color,
    required this.shadowColor,
    required this.onPressed,
    this.height = 52,
  });

  @override
  State<KidButton> createState() => _KidButtonState();
}

class _KidButtonState extends State<KidButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final depth = widget.height * 0.1;
    final radius = BorderRadius.circular(widget.height / 2);
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onPressed,
      child: SizedBox(
        width: widget.label == null ? widget.height * 1.5 : null, // nút chỉ có icon: rộng cố định
        height: widget.height + depth,
        child: Stack(
          children: [
            Positioned.fill(
              top: depth,
              child: DecoratedBox(decoration: BoxDecoration(color: widget.shadowColor, borderRadius: radius)),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 70),
              left: 0,
              right: 0,
              top: _pressed ? depth : 0,
              height: widget.height,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: widget.height * 0.35),
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: radius,
                  border: Border.all(color: Colors.white, width: widget.height * 0.05),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(widget.icon, color: Colors.white, size: widget.height * 0.5),
                    if (widget.label != null) ...[
                      SizedBox(width: widget.height * 0.12),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            widget.label!,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: widget.height * 0.36,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                              shadows: const [Shadow(color: Color(0x40000000), offset: Offset(0, 1.5))],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Khung trắng kem bo tròn, viền màu, đổ bóng khối (HUD điểm / mạng, thẻ thống kê...)
class KidPanel extends StatelessWidget {
  final Widget child;
  final Color borderColor;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double borderWidth;

  const KidPanel({
    super.key,
    required this.child,
    this.borderColor = KidColors.yellow,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    this.radius = 22,
    this.borderWidth = 3,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: KidColors.cream.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: [BoxShadow(color: borderColor.withValues(alpha: 0.55), offset: const Offset(0, 4))],
      ),
      child: child,
    );
  }
}

/// Hộp thoại giữa màn hình (Tạm dừng / Kết thúc): thỏ bên trái, nội dung bên phải.
/// Bố cục ngang hợp màn hình nằm ngang; tự thu nhỏ (scaleDown) để luôn vừa mọi kích thước màn hình.
class KidDialog extends StatelessWidget {
  final ImageProvider? mascot;
  final Color accent;
  final List<Widget> children;

  const KidDialog({super.key, this.mascot, required this.accent, required this.children});

  @override
  Widget build(BuildContext context) {
    final s = kidScale(context);
    final size = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);
    final cardW = 440.0 * s;

    final card = Material(
      color: Colors.transparent,
      child: Container(
        width: cardW,
        padding: EdgeInsets.fromLTRB(18 * s, 18 * s, 22 * s, 18 * s),
        decoration: BoxDecoration(
          color: KidColors.cream,
          borderRadius: BorderRadius.circular(30 * s),
          border: Border.all(color: accent, width: 5 * s),
          boxShadow: [
            BoxShadow(color: accent.withValues(alpha: 0.6), offset: Offset(0, 7 * s)),
            const BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, 10)),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (mascot != null) ...[
              Image(image: mascot!, height: 150 * s, fit: BoxFit.contain, filterQuality: FilterQuality.medium),
              SizedBox(width: 14 * s),
            ],
            Expanded(
              child: Column(mainAxisSize: MainAxisSize.min, children: children),
            ),
          ],
        ),
      ),
    );

    return Container(
      color: const Color(0x66263238), // phủ mờ nhẹ, không tối hẳn để vẫn thấy khung cảnh tươi sáng
      padding: EdgeInsets.fromLTRB(pad.left + 16, pad.top + 16, pad.right + 16, pad.bottom + 16),
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: size.width * 0.92, maxHeight: size.height * 0.92),
        child: FittedBox(fit: BoxFit.scaleDown, child: card),
      ),
    );
  }
}

/// Nền trời ngày nắng cho menu: trời xanh, mặt trời cười, mây trôi, đồi cỏ & hoa (vẽ bằng code, co giãn mọi màn hình)
class KidSkyBackground extends StatefulWidget {
  const KidSkyBackground({super.key});

  @override
  State<KidSkyBackground> createState() => _KidSkyBackgroundState();
}

class _KidSkyBackgroundState extends State<KidSkyBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(seconds: 60))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(painter: _KidSkyPainter(_controller), size: Size.infinite),
    );
  }
}

class _KidSkyPainter extends CustomPainter {
  final Animation<double> t;

  _KidSkyPainter(this.t) : super(repaint: t);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rect = Offset.zero & size;

    // Bầu trời
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF64B5F6), Color(0xFFB3E5FC), Color(0xFFE1F5FE)],
        ).createShader(rect),
    );

    // Mặt trời cười (góc trên phải) với tia nắng xoay chậm
    final sunC = Offset(w * 0.93, h * 0.1);
    final r = h * 0.075;
    final angle = t.value * 2 * math.pi;
    final rayPaint = Paint()
      ..color = const Color(0xFFFFCA28)
      ..strokeWidth = r * 0.16
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 10; i++) {
      final a = angle + i * math.pi / 5;
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(sunC + dir * r * 1.25, sunC + dir * r * 1.6, rayPaint);
    }
    canvas.drawCircle(sunC, r, Paint()..color = const Color(0xFFFFD54F));
    final face = Paint()..color = const Color(0xFF8D6E63);
    canvas.drawCircle(sunC.translate(-r * 0.33, -r * 0.15), r * 0.11, face);
    canvas.drawCircle(sunC.translate(r * 0.33, -r * 0.15), r * 0.11, face);
    canvas.drawArc(
      Rect.fromCenter(center: sunC.translate(0, r * 0.1), width: r * 0.9, height: r * 0.7),
      0.25,
      math.pi - 0.5,
      false,
      Paint()
        ..color = const Color(0xFF8D6E63)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.1
        ..strokeCap = StrokeCap.round,
    );

    // Mây trôi: (x ban đầu, y, tỉ lệ, số vòng trôi mỗi chu kỳ 60s)
    const clouds = [(0.1, 0.14, 1.0, 1.0), (0.45, 0.07, 0.75, 2.0), (0.72, 0.22, 0.6, 1.0), (0.3, 0.3, 0.5, 3.0)];
    final cloudPaint = Paint()..color = Colors.white.withValues(alpha: 0.95);
    for (final (x0, y, scale, speed) in clouds) {
      final x = ((x0 + t.value * speed * 1.3) % 1.3) - 0.15;
      final c = Offset(x * w, y * h);
      final cr = h * 0.05 * scale;
      canvas.drawCircle(c, cr, cloudPaint);
      canvas.drawCircle(c.translate(-cr, cr * 0.3), cr * 0.7, cloudPaint);
      canvas.drawCircle(c.translate(cr * 1.05, cr * 0.25), cr * 0.78, cloudPaint);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTRB(c.dx - cr * 1.6, c.dy + cr * 0.1, c.dx + cr * 1.75, c.dy + cr * 0.95), Radius.circular(cr * 0.45)),
        cloudPaint,
      );
    }

    // Đồi cỏ 2 lớp
    final backHill = Path()
      ..moveTo(0, h * 0.78)
      ..quadraticBezierTo(w * 0.25, h * 0.62, w * 0.55, h * 0.76)
      ..quadraticBezierTo(w * 0.8, h * 0.86, w, h * 0.7)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(backHill, Paint()..color = const Color(0xFFA5D6A7));
    final frontHill = Path()
      ..moveTo(0, h * 0.88)
      ..quadraticBezierTo(w * 0.35, h * 0.78, w * 0.7, h * 0.9)
      ..quadraticBezierTo(w * 0.88, h * 0.95, w, h * 0.86)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(frontHill, Paint()..color = const Color(0xFF81C784));

    // Hoa nhỏ rải rác trên đồi
    const flowers = [(0.06, 0.94), (0.18, 0.9), (0.33, 0.95), (0.52, 0.93), (0.64, 0.97), (0.8, 0.95), (0.93, 0.92)];
    const petals = [Color(0xFFFFFFFF), Color(0xFFFFF176), Color(0xFFF48FB1)];
    final fr = h * 0.012;
    for (int i = 0; i < flowers.length; i++) {
      final (fx, fy) = flowers[i];
      final c = Offset(fx * w, fy * h);
      final petal = Paint()..color = petals[i % petals.length];
      for (int k = 0; k < 5; k++) {
        final a = k * 2 * math.pi / 5;
        canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * fr, fr * 0.8, petal);
      }
      canvas.drawCircle(c, fr * 0.6, Paint()..color = const Color(0xFFFFB300));
    }
  }

  @override
  bool shouldRepaint(covariant _KidSkyPainter old) => false;
}
