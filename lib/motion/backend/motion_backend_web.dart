import 'package:flutter/widgets.dart';
import '../motion_state.dart';
import 'motion_backend.dart';

MotionBackend createMotionBackend({
  required FaceResultCallback onFace,
  required HandResultCallback onHands,
  required int Function(MotionInputMode mode) aiRotationIndex,
}) =>
    WebMotionBackend(onFace: onFace, onHands: onHands, aiRotationIndex: aiRotationIndex);

/// Web: webcam + MediaPipe Tasks Vision (JS).
/// Bản tạm: chưa mở camera => app chạy chế độ nút cảm ứng.
class WebMotionBackend extends MotionBackend {
  WebMotionBackend({required super.onFace, required super.onHands, required super.aiRotationIndex});

  @override
  Future<void> start({VoidCallback? onCameraReady}) async {
    throw UnsupportedError('Camera is not supported on web yet');
  }

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}

  @override
  bool get isReady => false;

  @override
  bool get mirrored => true;

  @override
  Size? get previewSize => null;

  @override
  bool get supportsRotation => false;

  @override
  Widget buildPreview() => const SizedBox.shrink();
}
