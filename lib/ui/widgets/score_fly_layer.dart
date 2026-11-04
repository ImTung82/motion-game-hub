import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';

/// Lớp phủ hiệu ứng điểm bay: "+100" bật lên tại chỗ ghi điểm, rồi bay theo đường cong
/// về ô tổng điểm (targetKey) và mờ dần. Khi tới nơi gọi onArrive để HUD cộng điểm & nảy số.
///
/// Đặt lớp này phủ toàn màn hình (cùng hệ toạ độ với canvas game) và gọi
/// `layerKey.currentState?.spawn(Offset(px, py), '+100')`.
class ScoreFlyLayer extends StatefulWidget {
  final GlobalKey targetKey;
  final VoidCallback? onArrive;

  const ScoreFlyLayer({super.key, required this.targetKey, this.onArrive});

  @override
  ScoreFlyLayerState createState() => ScoreFlyLayerState();
}

class _ScoreFly {
  final AnimationController controller;
  final Offset from;
  final Offset? to; // null: không tìm thấy ô điểm -> chỉ bay lên & mờ dần
  final String text;
  final String? subText;
  final Color color;

  _ScoreFly({
    required this.controller,
    required this.from,
    required this.to,
    required this.text,
    required this.subText,
    required this.color,
  });
}

class ScoreFlyLayerState extends State<ScoreFlyLayer> with TickerProviderStateMixin {
  final List<_ScoreFly> _flies = [];

  void spawn(Offset from, String text, {String? subText, Color color = const Color(0xFFFFE600)}) {
    if (!mounted) return;
    final controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1150));
    final fly = _ScoreFly(
      controller: controller,
      from: from,
      to: _targetCenter(),
      text: text,
      subText: subText,
      color: color,
    );
    setState(() => _flies.add(fly));
    controller.forward().whenComplete(() {
      widget.onArrive?.call();
      if (!mounted) return;
      setState(() => _flies.remove(fly));
      controller.dispose();
    });
  }

  /// Tâm ô tổng điểm, quy về toạ độ của lớp phủ này
  Offset? _targetCenter() {
    final targetBox = widget.targetKey.currentContext?.findRenderObject() as RenderBox?;
    final layerBox = context.findRenderObject() as RenderBox?;
    if (targetBox == null || layerBox == null || !targetBox.attached || !layerBox.attached) return null;
    final global = targetBox.localToGlobal(targetBox.size.center(Offset.zero));
    return layerBox.globalToLocal(global);
  }

  @override
  void dispose() {
    for (final f in _flies) {
      f.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        clipBehavior: Clip.none,
        children: [for (final f in _flies) _buildFly(f)],
      ),
    );
  }

  Widget _buildFly(_ScoreFly f) {
    return AnimatedBuilder(
      animation: f.controller,
      builder: (context, _) {
        final t = f.controller.value;
        const popEnd = 0.28; // 0 -> 0.28: bật lên
        const flyStart = 0.42; // 0.28 -> 0.42: dừng cho kịp đọc, 0.42 -> 1.0: bay về ô điểm
        final risen = f.from.translate(0, -36);

        Offset pos;
        double scale;
        double opacity = 1.0;

        if (t < popEnd) {
          final p = Curves.easeOutBack.transform(t / popEnd);
          pos = Offset.lerp(f.from, risen, p)!;
          scale = lerpDouble(0.4, 1.2, p)!;
          opacity = (t / 0.12).clamp(0.0, 1.0);
        } else if (t < flyStart) {
          pos = risen;
          scale = 1.2;
        } else {
          final p = Curves.easeInCubic.transform((t - flyStart) / (1 - flyStart));
          if (f.to != null) {
            // Đường cong Bezier bậc 2 vồng lên trên cho chuyển động tự nhiên
            final control = Offset((risen.dx + f.to!.dx) / 2, f.to!.dy + (risen.dy - f.to!.dy) * 0.25 - 60);
            final a = Offset.lerp(risen, control, p)!;
            final b = Offset.lerp(control, f.to!, p)!;
            pos = Offset.lerp(a, b, p)!;
            scale = lerpDouble(1.2, 0.45, p)!;
            opacity = p > 0.85 ? (1 - (p - 0.85) / 0.15) : 1.0;
          } else {
            pos = risen.translate(0, -50 * p);
            scale = 1.2;
            opacity = 1 - p;
          }
        }

        return Positioned(
          left: pos.dx,
          top: pos.dy,
          child: FractionalTranslation(
            translation: const Offset(-0.5, -0.5),
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: scale,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(f.text, style: _style(f.color, 34)),
                    if (f.subText != null) Text(f.subText!, style: _style(Colors.white, 15)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  TextStyle _style(Color color, double size) => TextStyle(
        color: color,
        fontSize: size,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.0,
        shadows: const [
          Shadow(color: Colors.black, blurRadius: 6),
          Shadow(color: Colors.black87, offset: Offset(0, 2), blurRadius: 2),
        ],
      );
}
