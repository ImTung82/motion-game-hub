// Toàn màn hình cho bản web (nhất là khi bị nhúng trong iframe nhỏ 800x600 kiểu PhET).
// Android đã chạy immersive sẵn => bản native không làm gì.
export 'fullscreen_service_native.dart' if (dart.library.js_interop) 'fullscreen_service_web.dart';
