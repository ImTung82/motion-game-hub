import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'kid_ui.dart';

/// Gợi ý chơi bằng chạm ("👆 Tap the egg!") khi không có camera: ngón tay nhún lên xuống cho bé dễ để ý.
/// Màn chơi tự ẩn sau lần chạm đầu tiên. Không nhận chạm (IgnorePointer) để không che game.
class TouchHint extends StatefulWidget {
  final String text;
  final double scale;

  const TouchHint({super.key, required this.text, required this.scale});

  @override
  State<TouchHint> createState() => _TouchHintState();
}

class _TouchHintState extends State<TouchHint> with SingleTickerProviderStateMixin {
  late final AnimationController _bounce = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.scale;
    return IgnorePointer(
      child: KidPanel(
        padding: EdgeInsets.symmetric(horizontal: 18 * s, vertical: 8 * s),
        radius: 26 * s,
        borderWidth: 3 * s,
        borderColor: KidColors.orange,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _bounce,
              builder: (context, child) => Transform.translate(
                offset: Offset(0, -5 * s * math.sin(_bounce.value * math.pi).abs()),
                child: child,
              ),
              child: Text('👆', style: TextStyle(fontSize: 24 * s)),
            ),
            SizedBox(width: 8 * s),
            Flexible(
              child: Text(
                widget.text,
                textAlign: TextAlign.center,
                style: TextStyle(color: KidColors.text, fontSize: 17 * s, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
