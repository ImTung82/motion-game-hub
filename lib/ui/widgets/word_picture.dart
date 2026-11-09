import 'package:flutter/material.dart';

import '../../services/word_images.dart';

/// Hình minh hoạ của từ trong giao diện (ngoài canvas game): ảnh trong assets/words nếu có, chưa có thì emoji.
class WordPicture extends StatelessWidget {
  final String word;
  final String fallbackEmoji;
  final double size;
  final double radius;

  const WordPicture({super.key, required this.word, required this.fallbackEmoji, required this.size, this.radius = 6});

  @override
  Widget build(BuildContext context) {
    final path = WordImages.instance.assetPath(word);
    if (path == null) {
      return Text(fallbackEmoji, style: TextStyle(fontSize: size * 0.8, height: 1.2));
    }
    final int cacheSize = (size * MediaQuery.devicePixelRatioOf(context)).ceil();
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.asset(
        path,
        width: size,
        height: size,
        fit: BoxFit.contain,
        cacheWidth: cacheSize,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stack) => Text(fallbackEmoji, style: TextStyle(fontSize: size * 0.8)),
      ),
    );
  }
}
