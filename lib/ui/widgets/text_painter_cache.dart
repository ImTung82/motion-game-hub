import 'package:flutter/painting.dart';

/// TextPainter đã layout sẵn, dùng lại giữa các khung hình cho chữ / emoji vẽ trong CustomPainter.
/// Tạo + layout TextPainter mỗi khung rất tốn (nhất là trên web: mỗi lần là 1 Paragraph mới bên CanvasKit).
/// Chữ có cỡ đổi liên tục (VD: hiệu ứng phóng to) thì lấy cỡ cố định rồi canvas.scale, đừng đưa cỡ động vào đây.
class TextPainterCache {
  TextPainterCache._();

  static const int _maxEntries = 96;
  static final Map<(String, TextStyle), TextPainter> _cache = {};

  static TextPainter get(String text, TextStyle style) {
    final key = (text, style);
    final hit = _cache.remove(key);
    if (hit != null) {
      _cache[key] = hit; // đưa về cuối = vừa dùng
      return hit;
    }
    if (_cache.length >= _maxEntries) _cache.remove(_cache.keys.first); // bỏ mục lâu không dùng nhất
    final painter = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr)..layout();
    _cache[key] = painter;
    return painter;
  }
}
