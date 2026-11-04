import 'dart:math' as math;
import 'package:flutter/material.dart';

enum EggState {
  idle,
  wobbling,
  cracking,
  shattered,
}

class PhonicsWord {
  final String word;
  final String phonicsFamily;
  final String iconEmoji;
  final IconData materialIcon;

  const PhonicsWord({
    required this.word,
    required this.phonicsFamily,
    required this.iconEmoji,
    required this.materialIcon,
  });
}

class EggColorTheme {
  final Color primary;
  final Color secondary;
  final Color spotColor;
  final Color glowColor;

  const EggColorTheme({
    required this.primary,
    required this.secondary,
    required this.spotColor,
    required this.glowColor,
  });

  static const List<EggColorTheme> themes = [
    EggColorTheme(
      primary: Color(0xFF00E5FF), // Cyan Dino Egg
      secondary: Color(0xFF007799),
      spotColor: Color(0xFF76FF03),
      glowColor: Color(0x6600E5FF),
    ),
    EggColorTheme(
      primary: Color(0xFFFF4081), // Pink Dragon Egg
      secondary: Color(0xFF990033),
      spotColor: Color(0xFFFFD600),
      glowColor: Color(0x66FF4081),
    ),
    EggColorTheme(
      primary: Color(0xFFFFD600), // Golden Mythic Egg
      secondary: Color(0xFF997A00),
      spotColor: Color(0xFFFF6D00),
      glowColor: Color(0x66FFD600),
    ),
    EggColorTheme(
      primary: Color(0xFF76FF03), // Neon Green Jungle Egg
      secondary: Color(0xFF2E7D32),
      spotColor: Color(0xFF00E5FF),
      glowColor: Color(0x6676FF03),
    ),
  ];
}

class EggItem {
  final int id;
  final PhonicsWord word;
  double x; // normalized 0..1 (center)
  double y; // normalized 0..1 (center)
  double radiusX;
  double radiusY;
  final bool isTarget;
  final EggColorTheme colorTheme;

  EggState state = EggState.idle;
  double wobbleAngle = 0.0;
  double wobblePhase = 0.0;
  double crackIntensity = 0.0; // 0..1
  double shatterTimer = 0.0;
  double bounceScale = 1.0;

  EggItem({
    required this.id,
    required this.word,
    required this.x,
    required this.y,
    this.radiusX = 0.09,
    this.radiusY = 0.125,
    required this.isTarget,
    required this.colorTheme,
  }) {
    wobblePhase = math.Random().nextDouble() * math.pi * 2;
  }

  bool containsPoint(double px, double py) {
    if (state == EggState.shattered) return false;
    final dx = (px - x) / (radiusX * 1.15);
    final dy = (py - y) / (radiusY * 1.15);
    return (dx * dx + dy * dy) <= 1.0;
  }
}

class EggShellFragment {
  double x;
  double y;
  double vx;
  double vy;
  double rotation;
  double vRot;
  double size;
  Color color;
  double life = 1.0;
  double maxLife;

  EggShellFragment({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.rotation,
    required this.vRot,
    required this.size,
    required this.color,
    this.maxLife = 0.6,
  });

  bool update(double dt) {
    x += vx * dt;
    y += vy * dt;
    vy += 1.8 * dt; // gravity
    rotation += vRot * dt;
    life -= dt / maxLife;
    return life > 0;
  }
}

class SparkleStar {
  double x;
  double y;
  double vx;
  double vy;
  double size;
  Color color;
  double life = 1.0;
  double maxLife;

  SparkleStar({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.color,
    this.maxLife = 0.55,
  });

  bool update(double dt) {
    x += vx * dt;
    y += vy * dt;
    life -= dt / maxLife;
    return life > 0;
  }
}

class HatchedCreature {
  double x;
  double y;
  final PhonicsWord word;
  double scale = 0.0;
  double bounceY = 0.0;
  double life = 1.0;
  final double maxLife = 1.8;

  HatchedCreature({
    required this.x,
    required this.y,
    required this.word,
  });

  bool update(double dt) {
    life -= dt / maxLife;
    final progress = 1.0 - (life / maxLife);
    if (progress < 0.25) {
      scale = (progress / 0.25) * 1.25;
    } else if (progress < 0.4) {
      scale = 1.25 - ((progress - 0.25) / 0.15) * 0.25;
    } else {
      scale = 1.0;
    }
    bounceY = math.sin(progress * math.pi * 5) * 0.03 * (1.0 - progress);
    return life > 0;
  }
}
