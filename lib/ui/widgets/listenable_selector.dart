import 'package:flutter/widgets.dart';

/// Như [ListenableBuilder] nhưng chỉ build lại khi giá trị [selector] đổi (so sánh ==, nên trả về record
/// gồm đúng các trường mà [builder] đọc, VD: `() => (engine.lives, engine.score, engine.isPaused)`).
///
/// Engine game báo mỗi khung để canvas vẽ lại; HUD nghe thẳng engine thì cũng build + layout chữ lại
/// mỗi khung (trên web tốn ~25% luồng chính). Bọc HUD bằng widget này để chỉ build khi số liệu đổi.
/// Cha build lại (setState) thì widget này vẫn build lại như thường.
class ListenableSelector<T> extends StatefulWidget {
  final Listenable listenable;
  final T Function() selector;
  final TransitionBuilder builder;
  final Widget? child;

  const ListenableSelector({
    super.key,
    required this.listenable,
    required this.selector,
    required this.builder,
    this.child,
  });

  @override
  State<ListenableSelector<T>> createState() => _ListenableSelectorState<T>();
}

class _ListenableSelectorState<T> extends State<ListenableSelector<T>> {
  late T _value;

  @override
  void initState() {
    super.initState();
    _value = widget.selector();
    widget.listenable.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(covariant ListenableSelector<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.listenable != widget.listenable) {
      oldWidget.listenable.removeListener(_onChanged);
      widget.listenable.addListener(_onChanged);
    }
    _value = widget.selector();
  }

  @override
  void dispose() {
    widget.listenable.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    final value = widget.selector();
    if (value != _value) setState(() => _value = value);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, widget.child);
}
