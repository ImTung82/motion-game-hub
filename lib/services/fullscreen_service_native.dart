import 'package:flutter/foundation.dart';

class FullscreenService {
  FullscreenService._();
  static final FullscreenService instance = FullscreenService._();

  bool get isSupported => false;
  final ValueNotifier<bool> isFullscreen = ValueNotifier(false);
  void toggle() {}
}
