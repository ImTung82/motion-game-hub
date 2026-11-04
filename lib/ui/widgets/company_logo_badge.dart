import 'package:flutter/material.dart';

/// Logo công ty (Enspire): PNG nền trong suốt, hiển thị trực tiếp không có nền.
class CompanyLogoBadge extends StatelessWidget {
  static const AssetImage logo = AssetImage('assets/images/logo_enspire_digital.png');

  final double width;
  final double height;
  final EdgeInsets padding;
  final double borderRadius;
  final Color borderColor;
  final double borderWidth;
  final List<BoxShadow>? boxShadow;

  const CompanyLogoBadge({
    super.key,
    required this.width,
    required this.height,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    this.borderRadius = 10,
    this.borderColor = Colors.white,
    this.borderWidth = 0,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    // Chỉ để hiển thị: không chặn thao tác chạm của game
    return IgnorePointer(
      child: Container(
        width: width,
        height: height,
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          border: borderWidth > 0 ? Border.all(color: borderColor, width: borderWidth) : null,
          boxShadow: boxShadow,
        ),
        child: const Image(
          image: logo,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}
