import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart' show AssetManifest, rootBundle;

/// Ảnh minh hoạ của từ: `assets/words/<nhóm>/<từ>.png|jpg|jpeg|webp`, cùng thư mục & cùng tên với file đọc từ
/// (VD `animals/bat.png` cạnh `animals/bat.mp3`). Tra theo tên file trong AssetManifest => đổi nhóm không phải sửa code.
///
/// Ảnh được giải mã sẵn 1 lần (thu nhỏ còn [_decodeSize] px) để CustomPainter vẽ thẳng mỗi khung.
/// Từ chưa có ảnh thì [image] trả null => nơi vẽ dùng emoji thay thế.
class WordImages {
  WordImages._();
  static final WordImages instance = WordImages._();

  static const List<String> _extensions = ['.png', '.jpg', '.jpeg', '.webp'];

  /// Cạnh dài sau khi thu nhỏ: đủ nét cho huy hiệu to nhất trên màn TV, không tốn bộ nhớ (~256 KB / ảnh)
  static const int _decodeSize = 256;

  final Map<String, String> _paths = {}; // 'bat' -> 'assets/words/animals/bat.png'
  final Map<String, ui.Image> _images = {};
  Future<void>? _ready;

  /// Gọi 1 lần lúc mở app; gọi lại cũng không sao.
  Future<void> preload() => _ready ??= _load();

  /// Đường dẫn asset của ảnh (cho widget `Image.asset`), null nếu từ chưa có ảnh.
  String? assetPath(String word) => _paths[_key(word)];

  /// Ảnh đã giải mã (cho CustomPainter), null nếu chưa có ảnh hoặc chưa nạp xong.
  ui.Image? image(String word) => _images[_key(word)];

  static String _key(String word) => word.toLowerCase().trim();

  /// Chạy thử (web trên localhost / bản debug): game chỉ ra từ ĐÃ CÓ ẢNH để duyệt ảnh mới thêm.
  /// Bản thật (Firebase / bản release) dùng mọi từ.
  static final bool testImagesOnly =
      kDebugMode || (kIsWeb && const {'localhost', '127.0.0.1'}.contains(Uri.base.host));

  /// Xáo [items]. Khi [testImagesOnly]: chỉ giữ từ có ảnh (xếp trước); chưa đủ [min] từ thì bù từ chưa có ảnh
  /// ở cuối danh sách để game vẫn chạy được (VD Fruits Kick cần 3 quả). Game nên lấy đáp án từ đầu danh sách.
  List<T> shuffledPreferImages<T>(Iterable<T> items, String Function(T) wordOf, math.Random random, {int min = 1}) {
    final all = List<T>.of(items)..shuffle(random);
    if (!testImagesOnly) return all;
    final withImage = all.where((e) => assetPath(wordOf(e)) != null).toList();
    if (withImage.length >= min) return withImage;
    final fillers = all.where((e) => assetPath(wordOf(e)) == null).take(min - withImage.length);
    return [...withImage, ...fillers];
  }

  Future<void> _load() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      for (final asset in manifest.listAssets()) {
        if (!asset.startsWith('assets/words/')) continue;
        final lower = asset.toLowerCase();
        final ext = _extensions.where(lower.endsWith).firstOrNull;
        if (ext == null) continue;
        final name = asset.substring(asset.lastIndexOf('/') + 1, asset.length - ext.length);
        _paths[_key(name)] = asset;
      }
      await Future.wait(_paths.entries.map((e) => _decode(e.key, e.value)));
    } catch (e) {
      _ready = null; // lỗi thì lần sau thử lại
      debugPrint('Word images load error: $e');
    }
  }

  Future<void> _decode(String key, String asset) async {
    try {
      final data = await rootBundle.load(asset);
      // KHÔNG dùng ui.ImageDescriptor: web không hỗ trợ (lỗi => game lặng lẽ vẽ emoji).
      // instantiateImageCodecWithSize chạy cả web lẫn Android; chỉ thu nhỏ (không phóng to), giữ tỉ lệ ảnh.
      final buffer = await ui.ImmutableBuffer.fromUint8List(data.buffer.asUint8List());
      final codec = await ui.instantiateImageCodecWithSize(
        buffer,
        getTargetSize: (int w, int h) {
          final int longSide = math.max(w, h);
          if (longSide <= _decodeSize) return ui.TargetImageSize(width: w, height: h);
          return w >= h ? ui.TargetImageSize(width: _decodeSize) : ui.TargetImageSize(height: _decodeSize);
        },
      );
      final frame = await codec.getNextFrame();
      codec.dispose();
      _images[key] = frame.image;
    } catch (e) {
      debugPrint('Word image decode error ($asset): $e');
    }
  }

  static final Paint _imagePaint = Paint()..filterQuality = FilterQuality.medium;

  /// Vẽ ảnh của [word] vừa trong ô vuông [box] (giữ tỉ lệ, căn giữa), cắt theo hình tròn hoặc bo góc [radius].
  /// Trả false nếu từ chưa có ảnh => nơi gọi tự vẽ emoji thay thế.
  bool paint(Canvas canvas, String word, Rect box, {double radius = 0, bool circle = false}) {
    final img = image(word);
    if (img == null) return false;

    final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
    final fitted = applyBoxFit(BoxFit.contain, src.size, box.size);
    final dst = Alignment.center.inscribe(fitted.destination, box);

    canvas.save();
    if (circle) {
      canvas.clipPath(Path()..addOval(box));
    } else if (radius > 0) {
      canvas.clipRRect(RRect.fromRectAndRadius(box, Radius.circular(radius)));
    }
    canvas.drawImageRect(img, src, dst, _imagePaint);
    canvas.restore();
    return true;
  }
}
