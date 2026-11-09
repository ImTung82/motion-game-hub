import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../motion/motion_state.dart';
import '../../services/sound_service.dart';
import '../../services/word_bank.dart';
import 'penalty_models.dart';

class PenaltyEngine extends ChangeNotifier {
  final SoccerBall ball = SoccerBall();
  final List<GoalWordTarget> targets = [];
  final List<PenaltyParticle> particles = [];

  WordEntry? currentTargetWord;
  int targetSlotIndex = 1; // 0: Trái, 1: Giữa, 2: Phải

  // Khung thành (toạ độ chuẩn hoá theo goalHalfW): cột trái -1.04 -> cột phải +1.04.
  // 3 ô chia đều, phủ kín toàn bộ khung thành.
  static const double goalEdgeX = 1.04;
  static const double slotWidth = goalEdgeX * 2 / 3; // ~0.693
  static const double slotBoundaryX = slotWidth / 2; // ranh giới Giữa | Trái/Phải ~0.347
  static const double slotCenterY = 0.5; // giữa chiều cao khung thành
  static const double maxAimX = 0.88;

  /// Ô (0/1/2) chứa toạ độ x trong khung thành
  static int slotForX(double x) => x < -slotBoundaryX ? 0 : (x > slotBoundaryX ? 2 : 1);

  // ENDLESS MODE: chơi liên tục, sút sai mất 1 mạng, hết 3 mạng là Game Over
  static const int maxLives = 3;
  int lives = maxLives;
  int goals = 0;
  int streak = 0; // chuỗi sút đúng liên tiếp
  int highScore = 0;
  bool isNewHighScore = false;

  int score = 0;
  bool isGameOver = false;

  /// Gọi khi ghi điểm: (điểm cộng, chuỗi đúng, toạ độ x/y trong khung thành) -> để vẽ điểm bay
  void Function(int gained, int streak, double goalX, double goalY)? onScored;

  // Tự động đọc lại từ mục tiêu mỗi 5 giây khi đang ngắm
  double _wordRepeatTimer = 5.0;
  bool isPaused = false;

  // Tọa độ ngắm sút trong khung thành
  double aimX = 0.0;  // -maxAimX -> +maxAimX
  double aimY = slotCenterY; // Chiều cao mục tiêu hoa quả trên lưới
  bool isAimLocked = false;
  bool isChargingPower = false;
  double shotPower = 0.85;

  double netWobble = 0.0;
  String bannerTitle = '';
  double bannerTimer = 0.0;

  ShotOutcome currentOutcome = ShotOutcome.none;
  double _outcomeDelayTimer = 0.0;

  // Ghi bàn: cổ động viên nhảy theo tiếng reo crowd_cheer.mp3 (~4.4s): 4 nhịp x 1.1s,
  // tiếng reo phát xong rồi mới sang câu mới (không đè lên tiếng đọc từ của câu sau)
  static const double cheerJumpDuration = 1.1;
  static const int cheerJumps = 4;
  static const double _goalAdvanceDelay = cheerJumpDuration * cheerJumps + 0.3;
  static const double _wrongAdvanceDelay = 1.9;

  /// Thời gian (giây) kể từ lúc ghi bàn; null nếu không phải đang ăn mừng bàn thắng
  double? get goalCelebrationTime => currentOutcome == ShotOutcome.goal ? _outcomeDelayTimer : null;

  bool _wasFist = false;
  bool _nodArmed = true;
  bool _wasChomping = false;
  DateTime _lastShotTime = DateTime.fromMillisecondsSinceEpoch(0);

  final math.Random _random = math.Random();

  PenaltyEngine() {
    _loadHighScore();
    startNewMatch(announce: false); // màn chơi đọc đề sau bước chuẩn bị (ReadyGate)
  }

  Future<void> _loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    highScore = prefs.getInt('penalty_high_score') ?? 0;
    notifyListeners();
  }

  Future<void> _saveHighScore() async {
    isNewHighScore = score > highScore;
    if (isNewHighScore) {
      highScore = score;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('penalty_high_score', highScore);
    }
  }

  /// [announce] = false: chưa thổi còi & đọc đề (màn chơi gọi [announceTarget] sau khi bé vào vị trí)
  void startNewMatch({bool announce = true}) {
    lives = maxLives;
    goals = 0;
    streak = 0;
    score = 0;
    isNewHighScore = false;
    isGameOver = false;
    isPaused = false;
    _prepareRound(announce: announce);
    notifyListeners();
  }

  /// Hiện banner mục tiêu, thổi còi & đọc tên hoa quả
  void announceTarget() {
    if (currentTargetWord == null) return;
    bannerTimer = 3.0;
    SoundService.instance.playWhistle();
    SoundService.instance.playWord(currentTargetWord!.word);
    _wordRepeatTimer = 5.0;
  }

  void _prepareRound({bool announce = true}) {
    ball.reset();
    currentOutcome = ShotOutcome.none;
    _outcomeDelayTimer = 0.0;
    isAimLocked = false;
    isChargingPower = false;
    shotPower = 0.85;
    aimX = 0.0;
    aimY = slotCenterY;

    // Chọn ngẫu nhiên 3 từ khác nhau trong kho từ chung; từ đầu danh sách làm mục tiêu
    // (chạy thử trên localhost: ưu tiên từ đã có ảnh, xem WordImages.testImagesOnly)
    final chosen3 = WordBank.instance.shuffled(_random, min: 3).take(3).toList();
    final target = chosen3.first;

    // Đặt mục tiêu vào 1 ô ngẫu nhiên trong 3 ô
    chosen3.shuffle(_random);
    targetSlotIndex = chosen3.indexOf(target);
    currentTargetWord = target;

    targets.clear();
    targets.add(GoalWordTarget(
      slotIndex: 0,
      word: chosen3[0],
      x: -slotWidth, // Ô Trái
      y: slotCenterY,
    ));
    targets.add(GoalWordTarget(
      slotIndex: 1,
      word: chosen3[1],
      x: 0.0,        // Ô Giữa
      y: slotCenterY,
    ));
    targets.add(GoalWordTarget(
      slotIndex: 2,
      word: chosen3[2],
      x: slotWidth,  // Ô Phải
      y: slotCenterY,
    ));

    // Chỉ chữ + âm thanh, KHÔNG hiện hình: bé phải nghe & đọc để tìm đúng hình
    bannerTitle = 'TARGET: ${currentTargetWord!.title}';
    bannerTimer = 3.0;
    _wordRepeatTimer = 5.0;
    if (announce) announceTarget();
  }

  /// Đọc lại từ mục tiêu (tự động mỗi 5 giây khi đang ngắm)
  void replayTargetWord() {
    if (currentTargetWord == null || isGameOver || isPaused) return;
    SoundService.instance.playWord(currentTargetWord!.word);
    _wordRepeatTimer = 5.0;
  }

  void pauseGame() {
    if (isGameOver) return;
    isPaused = true;
    notifyListeners();
  }

  void resumeGame() {
    isPaused = false;
    _wordRepeatTimer = 5.0;
    notifyListeners();
  }

  void update(double dt, MotionState motion) {
    // Tạm dừng: đóng băng toàn bộ (bóng, banner, hạt, hẹn giờ đọc từ)
    if (isPaused) return;

    if (bannerTimer > 0) bannerTimer -= dt;
    if (netWobble > 0) netWobble = math.max(0.0, netWobble - 1.2 * dt);

    for (final t in targets) {
      if (t.hitWobble > 0) t.hitWobble = math.max(0.0, t.hitWobble - 2.5 * dt);
    }

    particles.removeWhere((p) => !p.update(dt));

    if (isGameOver) {
      notifyListeners();
      return;
    }

    final now = DateTime.now();

    // 1. KHI BÓNG CHƯA SÚT: ĐIỀU KHIỂN TÂM NGẮM & BẮT CỬ CHỈ SÚT
    if (!ball.inFlight && !ball.hasCollided && currentOutcome == ShotOutcome.none) {
      _wordRepeatTimer -= dt;
      if (_wordRepeatTimer <= 0) replayTargetWord();

      // =======================================================================
      // A. HAND MODE: Xòe tay ngắm | Nắm tay sút bóng
      // =======================================================================
      if (motion.inputMode == MotionInputMode.hand && motion.handDetected) {
        // Tâm ngắm theo steerX: giá trị TRÁI/PHẢI thống nhất Face & Hand (cùng chiều thước đo Hiệu chỉnh)
        final targetAimX = (motion.steerX * maxAimX).clamp(-maxAimX, maxAimX);
        aimX += (targetAimX - aimX) * (18.0 * dt).clamp(0.0, 1.0);

        // Cử chỉ SÚT: Nắm tay (kích hoạt theo sườn lên: Xòe -> Nắm)
        if (motion.isHandFist && !_wasFist && now.difference(_lastShotTime).inMilliseconds > 400) {
          executePlayerShot();
        }
        _wasFist = motion.isHandFist;
      }
      // =======================================================================
      // B. FACE MODE: Nghiêng đầu ngắm | Gật đầu sút
      // =======================================================================
      else if (motion.faceDetected) {
        _wasFist = false;

        // Nghiêng đầu Trái/Phải để chuyển tâm ngắm (steerX - cùng logic & cùng chiều với Hand mode)
        final targetAimX = (motion.steerX * maxAimX).clamp(-maxAimX, maxAimX);
        aimX += (targetAimX - aimX) * (14.0 * dt).clamp(0.0, 1.0);

        // Gật đầu xuống dưới để sút
        final pitch = motion.relativePitch;
        if (pitch > -3.0) _nodArmed = true;
        if (_nodArmed && pitch < -6.5 && now.difference(_lastShotTime).inMilliseconds > 500) {
          _nodArmed = false;
          executePlayerShot();
        }

        // Hoặc Há miệng để sút
        if (motion.isChomping && !_wasChomping && now.difference(_lastShotTime).inMilliseconds > 500) {
          executePlayerShot();
        }
        _wasChomping = motion.isChomping;
      } else {
        _wasFist = false;
      }
    }

    // 2. CẬP NHẬT QUỸ ĐẠO BÓNG BAY
    if (ball.inFlight) {
      ball.rotation += 18.0 * dt;
      ball.z += ball.vz * dt;
      ball.x += ball.vx * dt;
      ball.y += ball.vy * dt;

      _spawnBallTrail();

      // Khi bóng bay đến vạch vôi / khung thành (Z >= 1.0)
      if (ball.z >= 1.0 && !ball.hasCollided) {
        _resolveShotResult();
      }
    }

    // 3. XỬ LÝ CHUYỂN HIỆP SAU KHI DỨT ĐIỂM
    if (currentOutcome != ShotOutcome.none) {
      _outcomeDelayTimer += dt;
      final delay = currentOutcome == ShotOutcome.goal ? _goalAdvanceDelay : _wrongAdvanceDelay;
      if (_outcomeDelayTimer >= delay) {
        _advanceRound();
      }
    }

    notifyListeners();
  }

  // Thực hiện cú sút bóng
  void executePlayerShot([double power = 0.85]) {
    if (ball.inFlight || ball.hasCollided || isGameOver || isPaused) return;

    ball.inFlight = true;
    ball.hasCollided = false;
    _lastShotTime = DateTime.now();

    const flightDuration = 0.48; // Bóng bay dứt khoát vào lưới trong 0.48s
    SoundService.instance.playKick();
    ball.vz = 1.0 / flightDuration;
    ball.vx = (aimX - ball.x) / flightDuration;
    ball.vy = (aimY - ball.y) / flightDuration;
  }

  // Phân định kết quả cú sút
  void _resolveShotResult() {
    ball.hasCollided = true;
    ball.inFlight = false;

    // Xác định ô hoa quả bị bóng bắn trúng (3 ô chia đều toàn khung thành)
    final hitSlot = slotForX(ball.x);

    final hitTarget = targets[hitSlot];
    hitTarget.isHit = true;
    hitTarget.hitWobble = 1.0;
    netWobble = 1.0;

    if (hitSlot == targetSlotIndex) {
      // CHÍNH XÁC QUẢ MỤC TIÊU! VÀOOOO!
      currentOutcome = ShotOutcome.goal;
      goals++;
      streak++;
      // Thưởng chuỗi: +20 cho mỗi bàn liên tiếp (tối đa +100)
      final gained = 100 + (math.min(streak - 1, 5) * 20);
      score += gained;
      SoundService.instance.playGoal();
      // Điểm hiển thị bằng hiệu ứng bay
      bannerTitle = 'GOAL! ⚽';
      onScored?.call(gained, streak, ball.x, ball.y);
      bannerTimer = 2.0;

      _spawnConfetti(ball.x, ball.y);
      _spawnFruitBurst(ball.x, ball.y, currentTargetWord!.color.toARGB32());
    } else {
      // SÚT NHẦM QUẢ KHÁC!
      currentOutcome = ShotOutcome.wrongTarget;
      streak = 0;
      lives = math.max(0, lives - 1);
      SoundService.instance.playWrongAnswer();
      bannerTitle = 'OOPS! ❌';
      bannerTimer = 2.0;

      _spawnExplosion(ball.x, ball.y, 0xFFFF0055);
    }
  }

  void _advanceRound() {
    if (lives <= 0) {
      _endMatch();
    } else {
      _prepareRound();
    }
  }

  void _endMatch() {
    isGameOver = true;
    bannerTimer = 0.0;
    _saveHighScore();
    SoundService.instance.playTada();
  }

  bool get _canAim => !ball.inFlight && !ball.hasCollided && currentOutcome == ShotOutcome.none && !isGameOver && !isPaused;

  /// Chơi bằng chuột: tâm ngắm đi theo con trỏ ([goalX] toạ độ trong khung thành, 0 = giữa, ±1 = cột dọc)
  void touchAim(double goalX) {
    if (!_canAim) return;
    aimX = goalX.clamp(-maxAimX, maxAimX);
  }

  /// Chơi bằng chạm: chạm vào hình nào (hoặc cột nào của màn hình) thì sút thẳng vào giữa ô đó
  void touchShootAt(double goalX) {
    if (!_canAim) return;
    aimX = targets[slotForX(goalX)].x;
    executePlayerShot();
    notifyListeners();
  }

  // ==========================================
  // HẠT HIỆU ỨNG (PARTICLES)
  // ==========================================
  void _spawnBallTrail() {
    final rand = _random;
    particles.add(
      PenaltyParticle(
        x: ball.x + (rand.nextDouble() * 0.04 - 0.02),
        y: ball.y + (rand.nextDouble() * 0.04 - 0.02),
        vx: rand.nextDouble() * 0.1 - 0.05,
        vy: rand.nextDouble() * 0.1 - 0.05,
        maxLife: 0.3,
        colorValue: 0xCCFFFFFF,
        size: 5.0 * (1.0 - ball.z * 0.5),
      ),
    );
  }

  void _spawnExplosion(double x, double y, int color) {
    for (int i = 0; i < 28; i++) {
      final angle = _random.nextDouble() * 2 * math.pi;
      final speed = _random.nextDouble() * 1.2 + 0.4;
      particles.add(
        PenaltyParticle(
          x: x,
          y: y,
          vx: math.cos(angle) * speed,
          vy: math.sin(angle) * speed - 0.5,
          maxLife: _random.nextDouble() * 0.4 + 0.3,
          colorValue: color,
          size: _random.nextDouble() * 4 + 3,
        ),
      );
    }
  }

  void _spawnConfetti(double x, double y) {
    final colors = [0xFF39FF14, 0xFF00F0FF, 0xFFFFE600, 0xFFFF007F];
    for (int i = 0; i < 40; i++) {
      final angle = _random.nextDouble() * 2 * math.pi;
      final speed = _random.nextDouble() * 1.4 + 0.5;
      particles.add(
        PenaltyParticle(
          x: x,
          y: y,
          vx: math.cos(angle) * speed,
          vy: math.sin(angle) * speed - 0.8,
          maxLife: _random.nextDouble() * 0.6 + 0.4,
          colorValue: colors[_random.nextInt(colors.length)],
          size: _random.nextDouble() * 5 + 3,
        ),
      );
    }
  }

  void _spawnFruitBurst(double x, double y, int fruitColor) {
    for (int i = 0; i < 30; i++) {
      final angle = _random.nextDouble() * 2 * math.pi;
      final speed = _random.nextDouble() * 1.5 + 0.5;
      particles.add(
        PenaltyParticle(
          x: x,
          y: y,
          vx: math.cos(angle) * speed,
          vy: math.sin(angle) * speed - 0.6,
          maxLife: _random.nextDouble() * 0.5 + 0.3,
          colorValue: fruitColor,
          size: _random.nextDouble() * 6 + 3,
        ),
      );
    }
  }
}
