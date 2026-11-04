import 'package:flutter/material.dart';
import '../../core/constants.dart';

enum FoodType { star, donut, pizza, diamond, megaBurger }
enum ObstacleType { meteor, spikyDrone, laserBarrier }

class Player {
  double x;
  double y;
  double targetX;
  double mouthOpenProgress;
  double tiltAngle;
  bool isChomping;
  bool isInvincible;
  double invincibleTimer;
  int lives;

  Player({
    this.x = 0.5,
    this.y = 0.78,
    this.targetX = 0.5,
    this.mouthOpenProgress = 0.0,
    this.tiltAngle = 0.0,
    this.isChomping = false,
    this.isInvincible = false,
    this.invincibleTimer = 0.0,
    this.lives = 3,
  });

  void reset() {
    x = 0.5;
    y = 0.78;
    targetX = 0.5;
    mouthOpenProgress = 0.0;
    tiltAngle = 0.0;
    isChomping = false;
    isInvincible = false;
    invincibleTimer = 0.0;
    lives = 3;
  }
}

class FoodItem {
  final String id;
  final FoodType type;
  double x;
  double y;
  final double radius;
  final int points;
  final double feverEnergy;
  final double speed;
  double wobblePhase;
  bool isEaten;

  FoodItem({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    this.radius = 24.0,
    required this.points,
    required this.feverEnergy,
    required this.speed,
    this.wobblePhase = 0.0,
    this.isEaten = false,
  });

  Color get color {
    switch (type) {
      case FoodType.star: return GameColors.foodStar;
      case FoodType.donut: return GameColors.foodDonut;
      case FoodType.pizza: return GameColors.foodPizza;
      case FoodType.diamond: return GameColors.foodGem;
      case FoodType.megaBurger: return GameColors.neonOrange;
    }
  }

  String get label {
    switch (type) {
      case FoodType.star: return 'STAR';
      case FoodType.donut: return 'DONUT';
      case FoodType.pizza: return 'PIZZA';
      case FoodType.diamond: return 'GEM';
      case FoodType.megaBurger: return 'BURGER';
    }
  }
}

class Obstacle {
  final String id;
  final ObstacleType type;
  double x;
  double y;
  final double size;
  final double speed;
  double rotation;
  final double rotationSpeed;
  bool isDestroyed;

  Obstacle({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    this.size = 32.0,
    required this.speed,
    this.rotation = 0.0,
    this.rotationSpeed = 1.5,
    this.isDestroyed = false,
  });
}

class Particle {
  double x;
  double y;
  double vx;
  double vy;
  Color color;
  double life;
  final double maxLife;
  final double size;

  Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
    required this.life,
    required this.maxLife,
    required this.size,
  });

  bool update(double dt) {
    x += vx * dt;
    y += vy * dt;
    life -= dt / maxLife;
    return life > 0;
  }
}

class FloatingText {
  final String text;
  double x;
  double y;
  final Color color;
  double opacity;
  double scale;
  double life;

  FloatingText({
    required this.text,
    required this.x,
    required this.y,
    required this.color,
    this.opacity = 1.0,
    this.scale = 1.0,
    this.life = 1.0,
  });

  bool update(double dt) {
    y -= 40 * dt;
    scale += 0.2 * dt;
    life -= dt;
    opacity = (life / 1.0).clamp(0.0, 1.0);
    return life > 0;
  }
}
