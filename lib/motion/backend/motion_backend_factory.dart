// Chọn nguồn camera + AI theo nền tảng lúc build:
// Android dùng ML Kit + hand_landmarker, Web dùng MediaPipe Tasks Vision (JS).
// APK không chứa code web và bản web không chứa ML Kit / jni (dart:ffi).
export 'motion_backend_native.dart' if (dart.library.js_interop) 'motion_backend_web.dart';
