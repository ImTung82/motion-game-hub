import 'package:flutter/material.dart';
import '../../services/fullscreen_service.dart';
import '../../services/sound_service.dart';
import 'kid_ui.dart';

/// Nút toàn màn hình (chỉ hiện trên web khi trình duyệt / iframe cho phép).
/// Có [leadingGap] để đặt cạnh nút khác mà không để lại khoảng trống khi bị ẩn.
class FullscreenButton extends StatelessWidget {
  final double size;
  final double leadingGap;

  const FullscreenButton({super.key, required this.size, this.leadingGap = 0});

  @override
  Widget build(BuildContext context) {
    final service = FullscreenService.instance;
    if (!service.isSupported) return const SizedBox.shrink();
    return ValueListenableBuilder<bool>(
      valueListenable: service.isFullscreen,
      builder: (context, isFullscreen, _) => Padding(
        padding: EdgeInsets.only(left: leadingGap),
        child: KidIconButton(
          icon: isFullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
          color: KidColors.green,
          shadowColor: KidColors.greenDark,
          size: size,
          tooltip: isFullscreen ? 'Exit full screen' : 'Full screen',
          onPressed: () {
            SoundService.instance.playClick();
            service.toggle();
          },
        ),
      ),
    );
  }
}
