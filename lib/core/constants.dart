import 'package:flutter/material.dart';

class GameColors {
  static const Color background = Color(0xFF0D0E15);
  static const Color surface = Color(0xFF161926);
  static const Color surfaceLight = Color(0xFF222738);

  // Neon accents
  static const Color neonCyan = Color(0xFF00F0FF);
  static const Color neonGreen = Color(0xFF39FF14);
  static const Color neonPink = Color(0xFFFF007F);
  static const Color neonYellow = Color(0xFFFFE600);
  static const Color neonPurple = Color(0xFFB026FF);
  static const Color neonOrange = Color(0xFFFF6B00);

  // Player & Elements
  static const Color playerBody = Color(0xFF00F0FF);
  static const Color playerMouth = Color(0xFFFF007F);
  static const Color playerGlow = Color(0x6600F0FF);

  static const Color foodStar = Color(0xFFFFE600);
  static const Color foodDonut = Color(0xFFFF4081);
  static const Color foodPizza = Color(0xFFFF9100);
  static const Color foodGem = Color(0xFF00E5FF);

  static const Color obstacleMeteor = Color(0xFFFF3366);
  static const Color obstacleLaser = Color(0xFFFF1744);
}

class MotionDefaults {
  // Ngưỡng góc nghiêng đầu (độ) - nhạy và tự nhiên
  static const double defaultTiltThreshold = 9.0;
  static const double defaultTiltRelease = 4.5;

  // Ngưỡng độ há miệng (delta miệng mở so với baseline ngậm miệng)
  static const double defaultMouthOpenThreshold = 0.12;
  static const double defaultMouthCloseThreshold = 0.06;

  // Trọng số làm mượt EMA (alpha: 0.0 - 1.0)
  static const double emaAlpha = 0.45;
}
