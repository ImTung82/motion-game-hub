import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show AssetManifest, rootBundle;

import 'word_images.dart';

/// Một từ trong kho: `assets/words/<group>/<word>.mp3` (+ ảnh cùng tên nếu có).
class WordEntry {
  final String group; // 'fruits'
  final String word; // 'orange' (chữ thường, = tên file)
  final String emoji; // vẽ thay khi từ chưa có ảnh
  final Color color; // màu nhấn (viền huy hiệu, hạt pháo hoa...)

  const WordEntry({required this.group, required this.word, required this.emoji, required this.color});

  /// Khoá duy nhất 'fruits/orange' (tách được 'orange' quả cam với 'colors/orange' màu cam) => dùng tra ảnh.
  String get id => '$group/$word';

  /// 'ORANGE'
  String get label => word.toUpperCase();

  /// 'Orange'
  String get title => word.isEmpty ? word : word[0].toUpperCase() + word.substring(1);
}

/// Kho từ chung của mọi game: dò mọi file `.mp3` trong `assets/words/` qua AssetManifest
/// => thêm file đọc + ảnh cho từ mới là game tự dùng, không phải sửa code.
/// Từ chưa có ảnh vẽ emoji trong [_emoji]; chưa có cả ảnh lẫn emoji thì bỏ qua (bé không có hình để chọn).
class WordBank {
  WordBank._();
  static final WordBank instance = WordBank._();

  static const List<String> _imageExts = ['.png', '.jpg', '.jpeg', '.webp'];

  List<WordEntry> _words = const [];
  Future<void>? _ready;

  /// Mọi từ dùng được (sau khi [load] xong).
  List<WordEntry> get words => _words;

  /// Gọi lúc mở app; gọi lại trả cùng Future.
  Future<void> load() => _ready ??= _load();

  Future<void> _load() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final assets = manifest.listAssets().where((a) => a.startsWith('assets/words/')).toList();
      final images = <String>{};
      for (final a in assets) {
        final lower = a.toLowerCase();
        final ext = _imageExts.where(lower.endsWith).firstOrNull;
        if (ext != null) images.add(lower.substring('assets/words/'.length, lower.length - ext.length));
      }
      final list = <WordEntry>[];
      for (final a in assets) {
        if (!a.endsWith('.mp3')) continue;
        final id = a.substring('assets/words/'.length, a.length - '.mp3'.length).toLowerCase(); // 'fruits/orange'
        final slash = id.lastIndexOf('/');
        if (slash < 0) continue;
        final emoji = _emoji[id];
        if (emoji == null && !images.contains(id)) {
          debugPrint('WordBank: bỏ qua "$id" (chưa có ảnh, chưa có emoji)');
          continue;
        }
        list.add(WordEntry(
          group: id.substring(0, slash),
          word: id.substring(slash + 1),
          emoji: emoji ?? '⭐',
          color: _colorWords[id] ?? _palette[id.hashCode.abs() % _palette.length],
        ));
      }
      list.sort((a, b) => a.id.compareTo(b.id));
      _words = List.unmodifiable(list);
    } catch (e) {
      _ready = null; // lỗi thì lần sau thử lại
      debugPrint('WordBank load error: $e');
    }
  }

  /// Bộ từ đã xáo cho 1 lượt chơi, mỗi chữ chỉ 1 lần (VD không có 2 ô 'ORANGE' cùng lúc).
  /// Chạy thử (localhost / debug): ưu tiên từ đã có ảnh, xem [WordImages.shuffledPreferImages].
  List<WordEntry> shuffled(math.Random random, {int min = 1}) {
    final deck = WordImages.instance.shuffledPreferImages(_words, (w) => w.id, random, min: min);
    final seen = <String>{};
    return [for (final w in deck) if (seen.add(w.word)) w];
  }

  /// Màu nhấn của các từ chỉ màu = đúng màu đó
  static const Map<String, Color> _colorWords = {
    'colors/blue': Color(0xFF2196F3),
    'colors/brown': Color(0xFF8D6E63),
    'colors/green': Color(0xFF43A047),
    'colors/orange': Color(0xFFFF9800),
    'colors/pink': Color(0xFFFF6FB5),
    'colors/purple': Color(0xFF8E24AA),
    'colors/red': Color(0xFFFF1744),
    'colors/yellow': Color(0xFFFFD600),
  };

  static const List<Color> _palette = [
    Color(0xFFFF5252), Color(0xFFFF9100), Color(0xFFFFC107), Color(0xFF7CB342), Color(0xFF00BFA5),
    Color(0xFF29B6F6), Color(0xFF1E88E5), Color(0xFF7E57C2), Color(0xFFEC407A), Color(0xFF8D6E63),
  ];

  /// Emoji thay thế khi chưa có ảnh. Từ mới đã có ảnh thì không cần thêm vào đây.
  static const Map<String, String> _emoji = {
    'actions/hug': '🤗', 'actions/run': '🏃',
    'animals/bat': '🦇', 'animals/bug': '🐛', 'animals/cat': '🐱', 'animals/dog': '🐶', 'animals/fox': '🦊',
    'animals/frog': '🐸', 'animals/hen': '🐔', 'animals/pig': '🐷', 'animals/rat': '🐀',
    'body/leg': '🦵', 'body/lip': '👄',
    'colors/blue': '🔵', 'colors/brown': '🟤', 'colors/green': '🟢', 'colors/orange': '🟠',
    'colors/pink': '🌸', 'colors/purple': '🟣', 'colors/red': '🔴', 'colors/yellow': '🟡',
    'describing/big': '🐘', 'describing/cold': '🥶', 'describing/hot': '🔥', 'describing/small': '🐜',
    'fruits/apple': '🍎', 'fruits/avocado': '🥑', 'fruits/banana': '🍌', 'fruits/cherry': '🍒',
    'fruits/coconut': '🥥', 'fruits/grapes': '🍇', 'fruits/kiwi': '🥝', 'fruits/lemon': '🍋',
    'fruits/mango': '🥭', 'fruits/melon': '🍈', 'fruits/orange': '🍊', 'fruits/peach': '🍑',
    'fruits/pear': '🍐', 'fruits/pineapple': '🍍', 'fruits/strawberry': '🍓', 'fruits/watermelon': '🍉',
    'nature/log': '🪵', 'nature/rainbow': '🌈', 'nature/sun': '☀️',
    'numbers/one': '1️⃣', 'numbers/two': '2️⃣', 'numbers/three': '3️⃣', 'numbers/four': '4️⃣',
    'numbers/five': '5️⃣', 'numbers/six': '6️⃣', 'numbers/seven': '7️⃣', 'numbers/eight': '8️⃣',
    'numbers/nine': '9️⃣', 'numbers/ten': '🔟',
    'things/bed': '🛏️', 'things/bin': '🗑️', 'things/box': '📦', 'things/bun': '🥯', 'things/cab': '🚕',
    'things/can': '🥫', 'things/cap': '🧢', 'things/hat': '🎩', 'things/map': '🗺️', 'things/mat': '🧶',
    'things/mug': '☕', 'things/net': '🥅', 'things/pan': '🍳', 'things/pen': '🖊️', 'things/pin': '📌',
    'things/pot': '🍲', 'things/tub': '🛁', 'things/van': '🚐', 'things/wig': '💇',
  };
}
