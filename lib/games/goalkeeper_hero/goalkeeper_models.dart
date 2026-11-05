import 'dart:ui';

enum BallState {
  incoming,
  saved,
  caught,
  goal,
  dead,
}

enum GloveType {
  left,
  right,
}

/// Các giai đoạn của 1 ván: chọn mức độ -> chờ giơ 2 tay -> "GREAT! Get ready" -> đếm ngược 3-2-1 -> chơi -> kết thúc
enum KeeperPhase {
  setup,
  waitingHands,
  handsReady,
  countdown,
  playing,
  gameOver,
}

/// Mức độ chơi (cô giáo chọn trước ván). Mức Dễ dành cho bé mầm non mới làm quen.
enum KeeperDifficulty {
  easy(
    label: 'EASY',
    emoji: '🐢',
    flightStart: 4.0,
    flightEnd: 4.0,
    intervalStart: 4.4,
    intervalEnd: 4.4,
    rampSeconds: 1,
    curveChance: 0.0,
    curveMax: 0.0,
    targetHalfWidth: 0.45,
    targetTop: -0.30,
    targetBottom: 0.30,
    reachScale: 1.6,
    showTargetMarker: true,
  ),
  medium(
    label: 'MEDIUM',
    emoji: '🐰',
    flightStart: 2.8,
    flightEnd: 2.4,
    intervalStart: 3.4,
    intervalEnd: 2.8,
    rampSeconds: 180,
    curveChance: 0.25,
    curveMax: 0.10,
    targetHalfWidth: 0.65,
    targetTop: -0.50,
    targetBottom: 0.35,
    reachScale: 1.2,
    showTargetMarker: true,
  ),
  hard(
    label: 'HARD',
    emoji: '🚀',
    flightStart: 2.4,
    flightEnd: 1.8,
    intervalStart: 2.8,
    intervalEnd: 1.8,
    rampSeconds: 150,
    curveChance: 0.4,
    curveMax: 0.15,
    targetHalfWidth: 0.70,
    targetTop: -0.60,
    targetBottom: 0.35,
    reachScale: 0.9,
    showTargetMarker: false,
  );

  final String label;
  final String emoji;
  final double flightStart; // Thời gian bóng bay (giây) lúc đầu ván
  final double flightEnd; // ... và sau [rampSeconds] giây
  final double intervalStart; // Nhịp sút bóng lúc đầu ván
  final double intervalEnd;
  final double rampSeconds;
  final double curveChance; // Tỉ lệ bóng xoáy
  final double curveMax;
  final double targetHalfWidth; // Vùng bóng tới theo chiều ngang (-w -> w)
  final double targetTop; // Vùng bóng tới theo chiều dọc (âm = cao)
  final double targetBottom;
  final double reachScale; // Độ rộng vùng chạm của găng (so với nửa kích thước găng)
  final bool showTargetMarker; // Vòng báo trước điểm bóng tới

  const KeeperDifficulty({
    required this.label,
    required this.emoji,
    required this.flightStart,
    required this.flightEnd,
    required this.intervalStart,
    required this.intervalEnd,
    required this.rampSeconds,
    required this.curveChance,
    required this.curveMax,
    required this.targetHalfWidth,
    required this.targetTop,
    required this.targetBottom,
    required this.reachScale,
    required this.showTargetMarker,
  });
}

/// Chủ đề từ vựng: chỉ dùng các từ đã có file phát âm trong assets/words
enum WordTopic {
  fruits(label: 'FRUITS', emoji: '🍎'),
  animals(label: 'ANIMALS', emoji: '🐶'),
  things(label: 'THINGS', emoji: '📦'),
  mixed(label: 'MIXED', emoji: '🎲');

  final String label;
  final String emoji;

  const WordTopic({required this.label, required this.emoji});

  List<WordItem> get words => switch (this) {
        WordTopic.fruits => WordItem.fruits,
        WordTopic.animals => WordItem.animals,
        WordTopic.things => WordItem.things,
        WordTopic.mixed => [...WordItem.fruits, ...WordItem.animals, ...WordItem.things, ...WordItem.extras],
      };
}

class WordItem {
  final String word;
  final String label;
  final String emoji;
  final Color color;

  const WordItem({
    required this.word,
    required this.label,
    required this.emoji,
    required this.color,
  });

  static const List<WordItem> fruits = [
    WordItem(word: 'apple', label: 'APPLE', emoji: '🍎', color: Color(0xFFFF5252)),
    WordItem(word: 'banana', label: 'BANANA', emoji: '🍌', color: Color(0xFFFFD600)),
    WordItem(word: 'cherry', label: 'CHERRY', emoji: '🍒', color: Color(0xFFD50000)),
    WordItem(word: 'coconut', label: 'COCONUT', emoji: '🥥', color: Color(0xFF8D6E63)),
    WordItem(word: 'grape', label: 'GRAPE', emoji: '🍇', color: Color(0xFFAB47BC)),
    WordItem(word: 'kiwi', label: 'KIWI', emoji: '🥝', color: Color(0xFF7CB342)),
    WordItem(word: 'lemon', label: 'LEMON', emoji: '🍋', color: Color(0xFFFFEE58)),
    WordItem(word: 'mango', label: 'MANGO', emoji: '🥭', color: Color(0xFFFFA000)),
    WordItem(word: 'melon', label: 'MELON', emoji: '🍈', color: Color(0xFF9CCC65)),
    WordItem(word: 'orange', label: 'ORANGE', emoji: '🍊', color: Color(0xFFFF9800)),
    WordItem(word: 'peach', label: 'PEACH', emoji: '🍑', color: Color(0xFFFF8A65)),
    WordItem(word: 'pear', label: 'PEAR', emoji: '🍐', color: Color(0xFFC0CA33)),
    WordItem(word: 'pineapple', label: 'PINEAPPLE', emoji: '🍍', color: Color(0xFFFFC107)),
    WordItem(word: 'strawberry', label: 'STRAWBERRY', emoji: '🍓', color: Color(0xFFFF1744)),
    WordItem(word: 'watermelon', label: 'WATERMELON', emoji: '🍉', color: Color(0xFF43A047)),
    WordItem(word: 'avocado', label: 'AVOCADO', emoji: '🥑', color: Color(0xFF689F38)),
  ];

  static const List<WordItem> animals = [
    WordItem(word: 'cat', label: 'CAT', emoji: '🐱', color: Color(0xFFFF9100)),
    WordItem(word: 'dog', label: 'DOG', emoji: '🐶', color: Color(0xFF8D6E63)),
    WordItem(word: 'pig', label: 'PIG', emoji: '🐷', color: Color(0xFFFF80AB)),
    WordItem(word: 'frog', label: 'FROG', emoji: '🐸', color: Color(0xFF4CAF50)),
    WordItem(word: 'fox', label: 'FOX', emoji: '🦊', color: Color(0xFFFF6D00)),
    WordItem(word: 'hen', label: 'HEN', emoji: '🐔', color: Color(0xFFE53935)),
    WordItem(word: 'rat', label: 'RAT', emoji: '🐀', color: Color(0xFF78909C)),
    WordItem(word: 'bug', label: 'BUG', emoji: '🐛', color: Color(0xFF8BC34A)),
    WordItem(word: 'bat', label: 'BAT', emoji: '🦇', color: Color(0xFF5E35B1)),
  ];

  static const List<WordItem> things = [
    WordItem(word: 'box', label: 'BOX', emoji: '📦', color: Color(0xFF795548)),
    WordItem(word: 'hat', label: 'HAT', emoji: '🎩', color: Color(0xFF7E57C2)),
    WordItem(word: 'sun', label: 'SUN', emoji: '☀️', color: Color(0xFFFFAB00)),
    WordItem(word: 'pen', label: 'PEN', emoji: '🖊️', color: Color(0xFF1E88E5)),
    WordItem(word: 'mug', label: 'MUG', emoji: '☕', color: Color(0xFF6D4C41)),
    WordItem(word: 'van', label: 'VAN', emoji: '🚐', color: Color(0xFF039BE5)),
    WordItem(word: 'map', label: 'MAP', emoji: '🗺️', color: Color(0xFF26A69A)),
    WordItem(word: 'bed', label: 'BED', emoji: '🛏️', color: Color(0xFF5C6BC0)),
    WordItem(word: 'pan', label: 'PAN', emoji: '🍳', color: Color(0xFF546E7A)),
    WordItem(word: 'cap', label: 'CAP', emoji: '🧢', color: Color(0xFF1565C0)),
    WordItem(word: 'can', label: 'CAN', emoji: '🥫', color: Color(0xFFE53935)),
    WordItem(word: 'net', label: 'NET', emoji: '🥅', color: Color(0xFF00897B)),
    WordItem(word: 'tub', label: 'TUB', emoji: '🛁', color: Color(0xFF29B6F6)),
  ];

  /// Từ lẻ (màu, số, động từ) chỉ xuất hiện ở chủ đề MIXED
  static const List<WordItem> extras = [
    WordItem(word: 'red', label: 'RED', emoji: '🔴', color: Color(0xFFFF1744)),
    WordItem(word: 'six', label: 'SIX', emoji: '6️⃣', color: Color(0xFF00E676)),
    WordItem(word: 'ten', label: 'TEN', emoji: '🔟', color: Color(0xFF00B0FF)),
    WordItem(word: 'run', label: 'RUN', emoji: '🏃', color: Color(0xFF2979FF)),
  ];
}

/// Quy đổi toạ độ game (-1 -> 1) sang pixel màn hình và kích thước vật thể co giãn theo màn hình.
/// Dùng chung cho canvas (vẽ), engine (va chạm) và screen (điểm bay) để 3 nơi luôn khớp nhau.
class KeeperLayout {
  final Size size;

  const KeeperLayout(this.size);

  /// Hệ số co giãn giống kidScale: màn hình càng lớn (TV, máy chiếu) vật thể càng to
  double get u => (size.shortestSide / 400).clamp(0.85, 1.6);

  Offset toScreen(double x, double y) => Offset(size.width / 2 + x * size.width * 0.44, size.height * 0.52 + y * size.height * 0.38);

  /// Bán kính bóng to dần theo chiều sâu Z (từ xa -> sát khung thành)
  double ballRadius(double z) => (18.0 + z * 50.0).clamp(16.0, 72.0) * u;

  double get gloveSize => 58.0 * u;

  /// Bán kính vùng chạm của găng: bóng chạm vòng này là cản được
  double gloveReach(KeeperDifficulty difficulty) => gloveSize * 0.5 * difficulty.reachScale;
}

class GoalBall {
  final int id;
  final double startX; // Tọa độ xuất phát ở vạch 11m (-0.2 -> 0.2)
  final double startY; // Tọa độ xuất phát
  final double targetX; // Mục tiêu khung thành
  final double targetY; // Mục tiêu khung thành
  final WordItem wordItem;
  final double speed; // Thời gian bay (giây)

  double currentX = 0.0;
  double currentY = 0.0;
  double z = 0.0; // 0.0 (xa) -> 1.0 (ngay vạch vôi khung thành)
  double rotation = 0.0;
  double rotationSpeed = 2.5;
  double curveFactor = 0.0;
  BallState state = BallState.incoming;
  double timeAlive = 0.0;
  bool announced = false; // Đã đọc từ vựng khi bóng đang bay tới chưa

  // Vật lý khi bị cản phá bật ra
  double bounceVx = 0.0;
  double bounceVy = 0.0;
  double bounceVz = 0.0;
  GloveType? caughtBy;

  GoalBall({
    required this.id,
    required this.startX,
    required this.startY,
    required this.targetX,
    required this.targetY,
    required this.wordItem,
    required this.speed,
    this.curveFactor = 0.0,
  }) {
    currentX = startX;
    currentY = startY;
  }
}

class GoalkeeperGlove {
  final GloveType type;
  double x = 0.0; // -1.0 (Trái) -> 1.0 (Phải)
  double y = 0.0; // -1.0 (Trên) -> 1.0 (Dưới)
  double targetX = 0.0;
  double targetY = 0.0;
  bool detected = false;
  double impactAnim = 0.0; // Hiệu ứng giật găng khi đỡ bóng (1.0 -> 0.0)

  GoalkeeperGlove({required this.type});
}

class SparkParticle {
  double x;
  double y;
  double vx;
  double vy;
  Color color;
  double radius;
  double life;
  double maxLife;
  String? emoji;
  bool confetti; // Giấy pháo hoa hình chữ nhật xoay (ăn mừng bắt bóng 2 tay)

  SparkParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
    required this.radius,
    required this.life,
    required this.maxLife,
    this.emoji,
    this.confetti = false,
  });
}

class SaveEvent {
  final bool isSuperCatch;
  final WordItem word;
  final Offset screenPosition; // Toạ độ game (-1 -> 1)
  final int starsGained;
  final GloveType? gloveType;

  const SaveEvent({
    required this.isSuperCatch,
    required this.word,
    required this.screenPosition,
    required this.starsGained,
    this.gloveType,
  });
}
