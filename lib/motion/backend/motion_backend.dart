import 'package:flutter/widgets.dart';
import '../motion_state.dart';

/// Số liệu thô 1 khuôn mặt, cùng thang đo trên mọi nền tảng (Android: ML Kit, Web: MediaPipe JS).
class FaceSample {
  final double rawRoll; // nghiêng đầu (độ)
  final double rawYaw; // quay mặt trái/phải (độ)
  final double rawPitch; // ngẩng/cúi (độ)
  final double rawMouth; // độ há miệng (khoảng cách 2 môi / chiều cao mặt, đã nhân hệ số)
  final Offset center; // tâm khuôn mặt, toạ độ ảnh ĐÃ XOAY ĐỨNG chuẩn hoá [0..1]
  final double smileProb;
  final double leftEyeOpen;
  final double rightEyeOpen;

  const FaceSample({
    required this.rawRoll,
    required this.rawYaw,
    required this.rawPitch,
    required this.rawMouth,
    required this.center,
    this.smileProb = 0.0,
    this.leftEyeOpen = 1.0,
    this.rightEyeOpen = 1.0,
  });
}

/// Kết quả nhận diện bàn tay của 1 khung hình
class HandFrame {
  final List<List<Offset>> hands; // mỗi tay 21 điểm, toạ độ ảnh ĐÃ XOAY ĐỨNG chuẩn hoá [0..1]
  final double uprightW; // kích thước ảnh đứng (pixel) để tính khoảng cách đúng tỉ lệ
  final double uprightH;
  final int latencyMs; // từ lúc gửi khung tới lúc có kết quả

  const HandFrame({required this.hands, required this.uprightW, required this.uprightH, required this.latencyMs});
}

typedef FaceResultCallback = void Function(FaceSample? face, int latencyMs, double fps);
typedef HandResultCallback = void Function(HandFrame frame);

/// Nguồn dữ liệu camera + AI. Mỗi nền tảng một bản (motion_backend_native.dart / motion_backend_web.dart),
/// chọn khi build qua motion_backend_factory.dart. Toàn bộ logic cử chỉ nằm ở FaceMotionController.
abstract class MotionBackend {
  final FaceResultCallback onFace;
  final HandResultCallback onHands;

  /// Chỉ số xoay AI hiện tại (0..3, mỗi bước 90°) theo chế độ — controller giữ & tự "săn góc"
  final int Function(MotionInputMode mode) aiRotationIndex;

  MotionBackend({required this.onFace, required this.onHands, required this.aiRotationIndex});

  /// Chế độ đang chơi: chỉ chạy detector tương ứng (mặt hoặc tay)
  MotionInputMode mode = MotionInputMode.hand;

  /// Số tay tối đa cần nhận diện (1 hoặc 2). Web: 1 tay nhanh gấp ~2 lần khi người chơi chỉ giơ 1 tay.
  /// Android giữ nguyên 2 tay (plugin tạo 1 lần, chưa đổi được lúc chạy).
  int maxHands = 1;

  /// Mở camera & nạp AI. Ném lỗi nếu không có camera (app chuyển sang chơi cảm ứng).
  /// [onCameraReady] được gọi ngay khi camera sẵn sàng, trước khi khung hình đầu tiên được xử lý.
  Future<void> start({VoidCallback? onCameraReady});

  /// Tắt camera (giữ AI) để có thể [start] lại
  Future<void> stop();

  void dispose();

  /// Camera đã mở & có hình xem trước
  bool get isReady;

  /// Hình xem trước là camera trước (lật gương)
  bool get mirrored;

  /// Kích thước khung hình gốc của camera (null khi chưa sẵn sàng)
  Size? get previewSize;

  /// Có hỗ trợ xoay camera / xoay AI (Android) hay không (Web: không)
  bool get supportsRotation;

  Widget buildPreview();
}
