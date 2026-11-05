import 'package:flutter/painting.dart';

/// TextPainter đã layout sẵn, dùng lại giữa các khung hình cho chữ / emoji vẽ trong CustomPainter.
/// Tạo + layout TextPainter mỗi khung rất tốn (nhất là trên web: mỗi lần là 1 Paragraph mới bên CanvasKit).
/// Chữ có cỡ đổi liên tục (VD: hiệu ứng phóng to) thì lấy cỡ cố định rồi canvas.scale, đừng đưa cỡ động vào đây.
///
/// Font hệ thống đổi / vừa tải xong (web: font emoji Noto chỉ được tải SAU lần layout đầu tiên gặp emoji đó)
/// => xoá cache để layout lại; không thì emoji vẽ trước khi font về sẽ là ô vuông lỗi mãi mãi.
class TextPainterCache {
  TextPainterCache._();

  static const int _maxEntries = 96;
  static final Map<(String, TextStyle), TextPainter> _cache = {};
  static bool _listening = false;

  static TextPainter get(String text, TextStyle style) {
    _listenForFontChanges();
    final key = (text, style);
    final hit = _cache.remove(key);
    if (hit != null) {
      _cache[key] = hit; // đưa về cuối = vừa dùng
      return hit;
    }
    if (_cache.length >= _maxEntries) _cache.remove(_cache.keys.first)?.dispose(); // bỏ mục lâu không dùng nhất
    final painter = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr)..layout();
    _cache[key] = painter;
    return painter;
  }

  static void _listenForFontChanges() {
    if (_listening) return;
    _listening = true;
    PaintingBinding.instance.systemFonts.addListener(clear);
  }

  /// Bỏ toàn bộ painter đã layout (lần vẽ sau tự layout lại với font mới)
  static void clear() {
    for (final painter in _cache.values) {
      painter.dispose();
    }
    _cache.clear();
  }
}
