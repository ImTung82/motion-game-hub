import '../../services/word_bank.dart';

enum ShotOutcome {
  none,
  goal,        // Sút trúng hoa quả mục tiêu!
  wrongTarget, // Sút trúng hoa quả khác (sai đáp án)
  missed,      // Sút ra ngoài khung thành
}

class GoalWordTarget {
  final int slotIndex;      // 0: Trái (-0.48), 1: Giữa (0.0), 2: Phải (+0.48)
  final WordEntry word;
  final double x;           // Vị trí X trong khung thành
  final double y;           // Vị trí Y (độ cao trên lưới)
  bool isHit;
  double hitWobble;         // Hiệu ứng rung lắc khi bị bóng sút trúng

  GoalWordTarget({
    required this.slotIndex,
    required this.word,
    required this.x,
    required this.y,
    this.isHit = false,
    this.hitWobble = 0.0,
  });
}

class SoccerBall {
  double x; // -0.75 (trái) -> 0.75 (phải)
  double y; // 0.05 (mặt cỏ) -> 0.65 (xà ngang)
  double z; // 0.0 (chấm 11m) -> 1.0 (vạch vôi/lưới)

  double vx;
  double vy;
  double vz;
  double rotation;
  bool inFlight;
  bool hasCollided;

  SoccerBall({
    this.x = 0.0,
    this.y = 0.05,
    this.z = 0.0,
    this.vx = 0.0,
    this.vy = 0.0,
    this.vz = 0.0,
    this.rotation = 0.0,
    this.inFlight = false,
    this.hasCollided = false,
  });

  void reset({double startX = 0.0, double startY = 0.05, double startZ = 0.0}) {
    x = startX;
    y = startY;
    z = startZ;
    vx = 0.0;
    vy = 0.0;
    vz = 0.0;
    rotation = 0.0;
    inFlight = false;
    hasCollided = false;
  }
}

class PenaltyParticle {
  double x;
  double y;
  double vx;
  double vy;
  double life;
  final double maxLife;
  final int colorValue;
  final double size;

  PenaltyParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.maxLife,
    required this.colorValue,
    required this.size,
  }) : life = maxLife;

  bool update(double dt) {
    x += vx * dt;
    y += vy * dt;
    vy += 1.2 * dt;
    life -= dt;
    return life > 0;
  }
}
