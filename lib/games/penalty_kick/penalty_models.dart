
enum ShotOutcome {
  none,
  goal,        // Sút trúng hoa quả mục tiêu!
  wrongTarget, // Sút trúng hoa quả khác (sai đáp án)
  missed,      // Sút ra ngoài khung thành
}

class FruitItem {
  final String name;        // e.g. 'Apple'
  final String emoji;       // e.g. '🍎'
  final int colorValue;     // e.g. 0xFFFF2A55

  const FruitItem({
    required this.name,
    required this.emoji,
    required this.colorValue,
  });
}

class GoalFruitTarget {
  final int slotIndex;      // 0: Trái (-0.48), 1: Giữa (0.0), 2: Phải (+0.48)
  final FruitItem fruit;
  final double x;           // Vị trí X trong khung thành
  final double y;           // Vị trí Y (độ cao trên lưới)
  bool isHit;
  double hitWobble;         // Hiệu ứng rung lắc khi bị bóng sút trúng

  GoalFruitTarget({
    required this.slotIndex,
    required this.fruit,
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

/// Bộ đề hoa quả cho Fruits Penalty (tên viết hoa chữ cái đầu; audio: `assets/words/<tên thường>.mp3`)
const List<FruitItem> kAllFruits = [
  FruitItem(name: 'Apple', emoji: '🍎', colorValue: 0xFFFF2A55),
  FruitItem(name: 'Banana', emoji: '🍌', colorValue: 0xFFFFD600),
  FruitItem(name: 'Orange', emoji: '🍊', colorValue: 0xFFFF7A00),
  FruitItem(name: 'Watermelon', emoji: '🍉', colorValue: 0xFF00E676),
  FruitItem(name: 'Grape', emoji: '🍇', colorValue: 0xFFAA00FF),
  FruitItem(name: 'Strawberry', emoji: '🍓', colorValue: 0xFFFF1744),
  FruitItem(name: 'Pineapple', emoji: '🍍', colorValue: 0xFFFFAB00),
  FruitItem(name: 'Mango', emoji: '🥭', colorValue: 0xFFFF9100),
  FruitItem(name: 'Lemon', emoji: '🍋', colorValue: 0xFFFFF176),
  FruitItem(name: 'Peach', emoji: '🍑', colorValue: 0xFFFF8A80),
  FruitItem(name: 'Cherry', emoji: '🍒', colorValue: 0xFFE91E63),
  FruitItem(name: 'Pear', emoji: '🍐', colorValue: 0xFFC6E36B),
  FruitItem(name: 'Kiwi', emoji: '🥝', colorValue: 0xFF8BC34A),
  FruitItem(name: 'Coconut', emoji: '🥥', colorValue: 0xFFA1887F),
  FruitItem(name: 'Melon', emoji: '🍈', colorValue: 0xFFB2FF59),
  FruitItem(name: 'Avocado', emoji: '🥑', colorValue: 0xFF689F38),
];
