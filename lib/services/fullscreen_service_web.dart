import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

// Đọc kiểu nullable: iPhone Safari không có Fullscreen API (undefined), iframe thiếu allowfullscreen => false
@JS('document.fullscreenEnabled')
external JSBoolean? get _fullscreenEnabled;

@JS('document.fullscreenElement')
external JSObject? get _fullscreenElement;

class FullscreenService {
  FullscreenService._() {
    if (!isSupported) return;
    web.document.addEventListener(
      'fullscreenchange',
      ((web.Event _) => isFullscreen.value = _fullscreenElement != null).toJS,
    );
  }

  static final FullscreenService instance = FullscreenService._();

  /// Có thể bật toàn màn hình không (iframe nhúng phải có `allowfullscreen`)
  bool get isSupported {
    try {
      return _fullscreenEnabled?.toDart ?? false;
    } catch (_) {
      return false;
    }
  }

  final ValueNotifier<bool> isFullscreen = ValueNotifier(false);

  /// Gọi trong lúc bấm nút (trình duyệt chỉ cho bật toàn màn hình theo thao tác người dùng)
  void toggle() {
    if (!isSupported) return;
    try {
      final JSPromise<JSAny?> request = _fullscreenElement != null
          ? web.document.exitFullscreen()
          : web.document.documentElement!.requestFullscreen();
      request.toDart.catchError((Object _) => null);
    } catch (_) {}
  }
}
