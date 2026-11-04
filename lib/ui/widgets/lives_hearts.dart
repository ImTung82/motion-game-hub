import 'package:flutter/material.dart';

/// Hàng tim hiển thị số mạng còn lại (dùng chung cho các game endless).
/// Tim vừa mất sẽ "bật" lên rồi xám đi để người chơi nhận ra ngay.
class LivesHearts extends StatelessWidget {
  final int lives;
  final int maxLives;
  final double size;
  final Color emptyColor; // màu tim đã mất (nền sáng thì truyền màu đậm hơn để vẫn thấy)

  const LivesHearts({
    super.key,
    required this.lives,
    required this.maxLives,
    this.size = 20,
    this.emptyColor = Colors.white24,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(maxLives, (i) {
        final alive = i < lives;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: size * 0.08),
          child: TweenAnimationBuilder<double>(
            key: ValueKey('heart_${i}_$alive'),
            tween: Tween(begin: 1.45, end: 1.0),
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
            child: Icon(
              alive ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              size: size,
              color: alive ? const Color(0xFFFF4D6D) : emptyColor,
            ),
          ),
        );
      }),
    );
  }
}
