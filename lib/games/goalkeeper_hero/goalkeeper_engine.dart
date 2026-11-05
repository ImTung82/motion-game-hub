import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../motion/motion_state.dart';
import '../../services/sound_service.dart';
import '../../ui/widgets/ready_gate.dart' show ReadyTiming;
import 'goalkeeper_models.dart';

class GoalkeeperEngine extends ChangeNotifier {
  static const int maxLives = 3;
  static const double kickerWindup = 0.7; // Thời gian cầu thủ chạy đà trước mỗi cú sút
  static const double ballStartY = 0.25; // Chấm phạt đền
  static const String _bestKey = 'goalkeeper_best_stars';
  static const String _difficultyKey = 'goalkeeper_difficulty';
  static const String _topicKey = 'goalkeeper_topic';

  final math.Random _random = math.Random();

  // Danh sách bóng & găng tay
  final List<GoalBall> balls = [];
  final GoalkeeperGlove leftGlove = GoalkeeperGlove(type: GloveType.left);
  final GoalkeeperGlove rightGlove = GoalkeeperGlove(type: GloveType.right);
  final List<SparkParticle> particles = [];

  // Cấu hình ván chơi (lưu lại cho lần sau)
  KeeperDifficulty difficulty = KeeperDifficulty.easy;
  WordTopic topic = WordTopic.fruits;

  /// Kích thước màn hình hiện tại, Screen cập nhật mỗi lần build để va chạm khớp với hình vẽ
  KeeperLayout layout = const KeeperLayout(Size(800, 400));

  // Trạng thái màn chơi
  KeeperPhase phase = KeeperPhase.setup;
  bool isPaused = false;
  bool get isGameOver => phase == KeeperPhase.gameOver;

  int score = 0; // Số sao: cản 1 tay = 1 sao, bắt 2 tay = 2 sao
  int lives = maxLives;
  int streak = 0;
  int maxStreak = 0;
  int highScore = 0;
  bool isNewHighScore = false;
  int ballsSaved = 0;
  int ballsCaught = 0;
  int ballsMissed = 0;
  final List<WordItem> savedWords = []; // Bộ sưu tập từ bé đã cản được trong ván

  // Chờ tay & đếm ngược
  // Bước chuẩn bị (cùng luật với ReadyGate của các game khác): phải thấy ĐỦ 2 tay mới bắt đầu, không tự
  // vào game khi hết giờ chờ; thấy đủ thì giữ thông báo "GREAT!" vài giây; mất tay => quay lại bước chờ.
  double _readyTime = 0.0;
  double _lostTime = 0.0;

  /// 0 -> 1 trong lúc giữ thông báo "GREAT! Get ready"
  double get readyProgress => (_readyTime / ReadyTiming.confirmSeconds).clamp(0.0, 1.0);
  double _countdown = 0.0;
  int _lastCountdownNumber = 0;
  int get countdownNumber => _countdown.ceil();
  double get countdownFraction => _countdown - (countdownNumber - 1); // 1.0 -> 0.0 trong mỗi nhịp đếm
  double goFlash = 0.0; // Chữ "GO!" hiện ngắn sau khi đếm ngược xong

  // Nhịp độ xuất hiện bóng
  double _spawnTimer = 1.0;
  int _ballIdCounter = 0;
  double _gameTime = 0.0;
  List<WordItem> _deck = [];
  WordItem? _lastWord;
  double nextStartX = 0.0; // Vị trí quả bóng đang nằm chờ trên chấm phạt đền

  // Hiệu ứng
  double effectTime = 0.0; // Đồng hồ chạy liên tục cho các hiệu ứng nhấp nháy
  double kickerX = 0.0;
  double kickerApproach = 0.0; // 0.0 = cầu thủ đứng chờ phía sau, 1.0 = sát bóng
  double kickAnim = 0.0; // Chân sút vung lên sau cú sút (1.0 -> 0.0)
  double netShake = 0.0; // Lưới rung khi lọt bóng
  double screenShake = 0.0; // Rung màn hình khi bắt bóng 2 tay
  double crowdJump = 0.0; // Khán giả nhảy lên ăn mừng

  // Callbacks thông báo ra ngoài Screen & HUD
  Function(SaveEvent)? onBallSaved;
  VoidCallback? onGoalConceded;
  VoidCallback? onGameOver;

  GoalkeeperEngine() {
    _resetGloves();
    _loadPrefs();
  }

  /// Pha chạy đà theo nhịp sút: 0.0 = còn xa cú sút, 1.0 = đúng lúc sút
  double get _runUpTarget => phase == KeeperPhase.playing ? (1.0 - _spawnTimer / kickerWindup).clamp(0.0, 1.0) : 0.0;

  Future<void> _loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      highScore = prefs.getInt(_bestKey) ?? 0;
      difficulty = KeeperDifficulty.values.asNameMap()[prefs.getString(_difficultyKey)] ?? difficulty;
      topic = WordTopic.values.asNameMap()[prefs.getString(_topicKey)] ?? topic;
      notifyListeners();
    } catch (e) {
      debugPrint('Goalkeeper prefs error: $e');
    }
  }

  Future<void> _saveHighScore() async {
    isNewHighScore = score > highScore;
    if (isNewHighScore) {
      highScore = score;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_bestKey, highScore);
    }
  }

  void setDifficulty(KeeperDifficulty value) {
    difficulty = value;
    notifyListeners();
    SharedPreferences.getInstance().then((p) => p.setString(_difficultyKey, value.name)).catchError((_) => false);
  }

  void setTopic(WordTopic value) {
    topic = value;
    notifyListeners();
    SharedPreferences.getInstance().then((p) => p.setString(_topicKey, value.name)).catchError((_) => false);
  }

  void _resetGloves() {
    leftGlove.x = -0.45;
    leftGlove.y = 0.1;
    leftGlove.targetX = -0.45;
    leftGlove.targetY = 0.1;
    leftGlove.detected = false;

    rightGlove.x = 0.45;
    rightGlove.y = 0.1;
    rightGlove.targetX = 0.45;
    rightGlove.targetY = 0.1;
    rightGlove.detected = false;
  }

  /// Quay về màn chọn mức độ & chủ đề
  void openSetup() {
    balls.clear();
    particles.clear();
    phase = KeeperPhase.setup;
    isPaused = false;
    notifyListeners();
  }

  /// Bắt đầu ván mới: chờ bé giơ đủ 2 tay rồi đếm ngược 3-2-1
  void startGame() {
    balls.clear();
    particles.clear();
    savedWords.clear();
    score = 0;
    lives = maxLives;
    streak = 0;
    maxStreak = 0;
    ballsSaved = 0;
    ballsCaught = 0;
    ballsMissed = 0;
    isNewHighScore = false;
    isPaused = false;
    phase = KeeperPhase.waitingHands;
    _readyTime = 0.0;
    _lostTime = 0.0;
    _spawnTimer = 1.0; // Sút quả đầu tiên 1s sau khi "GO!"
    _gameTime = 0.0;
    _deck = [];
    _lastWord = null;
    nextStartX = _randomStartX();
    kickerX = nextStartX;
    kickerApproach = 0.0;
    goFlash = 0.0;
    kickAnim = 0.0;
    netShake = 0.0;
    screenShake = 0.0;
    crowdJump = 0.0;
    _resetGloves();
    notifyListeners();
  }

  void pause() {
    isPaused = true;
    notifyListeners();
  }

  void resume() {
    isPaused = false;
    // Đếm ngược lại để bé kịp vào tư thế trước khi bóng bay tiếp
    if (phase == KeeperPhase.playing) _beginCountdown();
    notifyListeners();
  }

  void _beginCountdown() {
    phase = KeeperPhase.countdown;
    _lostTime = 0.0;
    _countdown = ReadyTiming.countdownSeconds;
    _lastCountdownNumber = countdownNumber;
    SoundService.instance.playCountdownTick();
  }

  /// Mất 1 trong 2 tay quá lâu lúc đang chuẩn bị / đếm ngược => quay lại bước chờ giơ tay (true)
  bool _lostHands(double dt, bool bothHands, bool cameraAvailable) {
    if (bothHands || !cameraAvailable) {
      _lostTime = 0.0;
      return false;
    }
    _lostTime += dt;
    if (_lostTime < ReadyTiming.lostGraceSeconds) return false;
    phase = KeeperPhase.waitingHands;
    _readyTime = 0.0;
    _lostTime = 0.0;
    return true;
  }

  /// [cameraAvailable] = false (chơi cảm ứng): không chờ giơ tay
  void update(double dt, MotionState motionState, {bool cameraAvailable = true}) {
    if (isPaused || phase == KeeperPhase.setup || phase == KeeperPhase.gameOver) return;

    effectTime += dt;

    // Găng tay luôn bám theo tay (kể cả lúc chờ & đếm ngược) để bé thấy mình đã vào vị trí
    _updateGloves(dt, motionState);
    _updateEffects(dt);
    _updateParticles(dt);

    switch (phase) {
      case KeeperPhase.waitingHands:
        if (!cameraAvailable) {
          _beginCountdown();
        } else if (leftGlove.detected && rightGlove.detected) {
          phase = KeeperPhase.handsReady;
          _readyTime = 0.0;
          _lostTime = 0.0;
          SoundService.instance.playClick();
        }
      case KeeperPhase.handsReady:
        final bool both = leftGlove.detected && rightGlove.detected;
        if (_lostHands(dt, both, cameraAvailable)) break;
        if (both) _readyTime += dt;
        if (_readyTime >= ReadyTiming.confirmSeconds) _beginCountdown();
      case KeeperPhase.countdown:
        if (_lostHands(dt, leftGlove.detected && rightGlove.detected, cameraAvailable)) break;
        _countdown -= dt;
        if (_countdown <= 0) {
          phase = KeeperPhase.playing;
          goFlash = 1.0;
          SoundService.instance.playWhistle();
        } else if (countdownNumber != _lastCountdownNumber) {
          _lastCountdownNumber = countdownNumber;
          SoundService.instance.playCountdownTick();
        }
      case KeeperPhase.playing:
        _gameTime += dt;
        _updateSpawning(dt);
        _updateBalls(dt);
      default:
        break;
    }

    notifyListeners();
  }

  void _updateGloves(double dt, MotionState motionState) {
    const double lerpFactor = 14.0; // Tốc độ bắt cử chỉ cực nhạy và mượt

    // TAY TRÁI (Cyan)
    if (motionState.leftHand.detected) {
      leftGlove.detected = true;
      // Map x từ [-1.0, 1.0] sang vùng khung thành [-0.95, 0.95]
      leftGlove.targetX = (motionState.leftHand.visualX * 1.15).clamp(-0.95, 0.95);
      leftGlove.targetY = (motionState.leftHand.visualY * 1.1).clamp(-0.85, 0.85);
    } else {
      leftGlove.detected = false;
      // Trôi nhẹ về vị trí phòng ngự trung lập
      leftGlove.targetX = -0.45;
      leftGlove.targetY = 0.1;
    }

    leftGlove.x += (leftGlove.targetX - leftGlove.x) * (dt * lerpFactor).clamp(0.0, 1.0);
    leftGlove.y += (leftGlove.targetY - leftGlove.y) * (dt * lerpFactor).clamp(0.0, 1.0);
    if (leftGlove.impactAnim > 0) {
      leftGlove.impactAnim = math.max(0.0, leftGlove.impactAnim - dt * 4.0);
    }

    // TAY PHẢI (Pink)
    if (motionState.rightHand.detected) {
      rightGlove.detected = true;
      rightGlove.targetX = (motionState.rightHand.visualX * 1.15).clamp(-0.95, 0.95);
      rightGlove.targetY = (motionState.rightHand.visualY * 1.1).clamp(-0.85, 0.85);
    } else {
      rightGlove.detected = false;
      rightGlove.targetX = 0.45;
      rightGlove.targetY = 0.1;
    }

    rightGlove.x += (rightGlove.targetX - rightGlove.x) * (dt * lerpFactor).clamp(0.0, 1.0);
    rightGlove.y += (rightGlove.targetY - rightGlove.y) * (dt * lerpFactor).clamp(0.0, 1.0);
    if (rightGlove.impactAnim > 0) {
      rightGlove.impactAnim = math.max(0.0, rightGlove.impactAnim - dt * 4.0);
    }
  }

  void _updateEffects(double dt) {
    goFlash = math.max(0.0, goFlash - dt * 1.2);
    kickAnim = math.max(0.0, kickAnim - dt * 2.5);
    netShake = math.max(0.0, netShake - dt * 1.5);
    screenShake = math.max(0.0, screenShake - dt * 3.0);
    crowdJump = math.max(0.0, crowdJump - dt * 0.6);

    // Chạy đà thì bám sát nhịp sút; sút xong thì đi bộ lùi về sau quả bóng mới
    final runUp = _runUpTarget;
    if (runUp >= kickerApproach) {
      kickerApproach = runUp;
    } else if (kickAnim <= 0) {
      kickerApproach = math.max(runUp, kickerApproach - dt * 1.2);
    }
    if (kickAnim <= 0) {
      kickerX += (nextStartX - kickerX) * (dt * 2.5).clamp(0.0, 1.0);
    }
  }

  /// Giá trị tăng/giảm dần theo thời gian chơi, từ [start] tới [end] sau rampSeconds
  double _ramp(double start, double end) => start + (end - start) * (_gameTime / difficulty.rampSeconds).clamp(0.0, 1.0);

  double _randomStartX() => _random.nextDouble() * 0.4 - 0.2;

  void _updateSpawning(double dt) {
    _spawnTimer -= dt;
    if (_spawnTimer <= 0) {
      _spawnBall();
      _spawnTimer = _ramp(difficulty.intervalStart, difficulty.intervalEnd);
    }
  }

  /// Rút từ theo kiểu xáo bài: hết bộ mới xáo lại, không để 2 quả liên tiếp trùng từ
  WordItem _nextWord() {
    if (_deck.isEmpty) {
      _deck = List.of(topic.words)..shuffle(_random);
      if (_deck.length > 1 && _deck.last == _lastWord) {
        final tmp = _deck.first;
        _deck.first = _deck.last;
        _deck.last = tmp;
      }
    }
    _lastWord = _deck.removeLast();
    return _lastWord!;
  }

  void _spawnBall() {
    final d = difficulty;
    final double targetX = (_random.nextDouble() * 2 - 1) * d.targetHalfWidth;
    final double targetY = d.targetTop + _random.nextDouble() * (d.targetBottom - d.targetTop);
    final double curve = _random.nextDouble() < d.curveChance ? (_random.nextDouble() * 2 - 1) * d.curveMax : 0.0;

    balls.add(GoalBall(
      id: ++_ballIdCounter,
      startX: nextStartX,
      startY: ballStartY,
      targetX: targetX,
      targetY: targetY,
      wordItem: _nextWord(),
      speed: _ramp(d.flightStart, d.flightEnd),
      curveFactor: curve,
    ));

    nextStartX = _randomStartX();
    kickAnim = 1.0;
    SoundService.instance.playKick();
  }

  void _updateBalls(double dt) {
    for (int i = balls.length - 1; i >= 0; i--) {
      final ball = balls[i];
      ball.timeAlive += dt;

      if (ball.state == BallState.incoming) {
        // Tịnh tiến chiều sâu Z từ 0.0 (xa) đến 1.0 (vạch khung thành)
        ball.z += dt / ball.speed;
        ball.rotation += ball.rotationSpeed * dt;

        // Quỹ đạo phối cảnh
        ball.currentX = ball.startX + (ball.targetX - ball.startX) * ball.z + math.sin(ball.z * math.pi) * ball.curveFactor;
        ball.currentY = ball.startY + (ball.targetY - ball.startY) * ball.z;

        // Đọc từ vựng ngay khi huy hiệu hiện lên -> bé nào cũng được nghe, kể cả khi để lọt lưới
        if (!ball.announced && ball.z >= 0.30) {
          ball.announced = true;
          SoundService.instance.playWord(ball.wordItem.word);
        }

        // KIỂM TRA VA CHẠM VỚI 2 GĂNG TAY KHI BÓNG ĐẾN KHUNG THÀNH (Z >= 0.80)
        if (ball.z >= 0.80 && ball.z <= 1.04) {
          _checkGloveCollisions(ball);
        }

        // BÓNG QUA VẠCH VÔI -> VÀO LƯỚI (GOAL!)
        if (ball.z >= 1.04 && ball.state == BallState.incoming) {
          _handleGoalConceded(ball);
        }
      } else if (ball.state == BallState.saved) {
        // Vật lý bóng bị đấm bật ngược ra ngoài
        ball.currentX += ball.bounceVx * dt;
        ball.currentY += ball.bounceVy * dt;
        ball.z += ball.bounceVz * dt;
        ball.rotation += ball.rotationSpeed * 2.0 * dt;

        // Biến mất khi bay xa
        if (ball.z < 0.2 || ball.currentY > 1.2 || ball.currentX.abs() > 1.3) {
          ball.state = BallState.dead;
        }
      } else if (ball.state == BallState.caught) {
        // Bóng dính chặt giữa 2 găng tay thủ môn
        ball.currentX = (leftGlove.x + rightGlove.x) / 2;
        ball.currentY = (leftGlove.y + rightGlove.y) / 2;
        ball.z = 1.0;

        // Giữ lại 0.8s cho bé ngắm thành tích rồi tan biến
        if (ball.timeAlive > 0.8) {
          ball.state = BallState.dead;
        }
      } else if (ball.state == BallState.goal) {
        // Rung nhẹ trong lưới rồi tan biến
        if (ball.timeAlive > 0.8) {
          ball.state = BallState.dead;
        }
      }

      if (ball.state == BallState.dead) {
        balls.removeAt(i);
      }
    }
  }

  void _checkGloveCollisions(GoalBall ball) {
    // Va chạm tính bằng pixel: bóng chạm vòng sáng quanh găng là cản được (đúng như bé nhìn thấy)
    final ballPos = layout.toScreen(ball.currentX, ball.currentY);
    final double reach = layout.ballRadius(ball.z) + layout.gloveReach(difficulty);

    // Găng chưa nhận diện được tay thì không tính (tránh găng tự đứng yên vẫn đỡ được bóng)
    double distanceTo(GoalkeeperGlove glove) =>
        glove.detected ? (ballPos - layout.toScreen(glove.x, glove.y)).distance : double.infinity;
    final double dLeft = distanceTo(leftGlove);
    final double dRight = distanceTo(rightGlove);

    final bool hitLeft = dLeft < reach;
    final bool hitRight = dRight < reach;
    if (!hitLeft && !hitRight) return;

    // 1 tay chạm = đấm cản phá. Cả 2 tay cùng ôm bóng (tay còn lại ở sát bóng) = bắt dính
    final bool isCatch = (hitLeft && dRight < reach * 1.6) || (hitRight && dLeft < reach * 1.6);

    if (isCatch) {
      // 👐 SUPER CATCH: BẮT DÍNH BÓNG BẰNG 2 TAY!
      ball.state = BallState.caught;
      ball.timeAlive = 0.0;
      ball.caughtBy = dLeft <= dRight ? GloveType.left : GloveType.right;
      leftGlove.impactAnim = 1.0;
      rightGlove.impactAnim = 1.0;

      ballsSaved++;
      ballsCaught++;
      _addStreak();
      const int stars = 2;
      score += stars;
      _collectWord(ball.wordItem);

      // Ăn mừng thật lớn: sao, pháo giấy, rung màn hình, khán giả nhảy lên
      _spawnCatchParticles(ball.currentX, ball.currentY, ball.wordItem.color);
      _spawnConfetti();
      screenShake = 1.0;
      crowdJump = 1.0;

      SoundService.instance.playCrowdCheer();
      SoundService.instance.playWord(ball.wordItem.word);

      onBallSaved?.call(SaveEvent(
        isSuperCatch: true,
        word: ball.wordItem,
        screenPosition: Offset(ball.currentX, ball.currentY),
        starsGained: stars,
        gloveType: ball.caughtBy,
      ));
    } else {
      // 🧤 PUNCH / BLOCK: ĐẤM CẢN PHÁ BÓNG!
      ball.state = BallState.saved;
      ball.timeAlive = 0.0;
      final hitGlove = hitLeft ? leftGlove : rightGlove;
      hitGlove.impactAnim = 1.0;

      // Véc tơ văng ngược ra ngoài
      final double dx = ball.currentX - hitGlove.x;
      ball.bounceVx = dx * 2.5 + (hitLeft ? -0.4 : 0.4);
      ball.bounceVy = -0.9 - _random.nextDouble() * 0.4;
      ball.bounceVz = -1.2;

      ballsSaved++;
      _addStreak();
      const int stars = 1;
      score += stars;
      _collectWord(ball.wordItem);

      // Sinh tia lửa cản phá
      _spawnBlockParticles(ball.currentX, ball.currentY, hitLeft ? const Color(0xFF00E5FF) : const Color(0xFFFF4081));

      SoundService.instance.playSave();
      SoundService.instance.playWord(ball.wordItem.word);

      onBallSaved?.call(SaveEvent(
        isSuperCatch: false,
        word: ball.wordItem,
        screenPosition: Offset(ball.currentX, ball.currentY),
        starsGained: stars,
        gloveType: hitLeft ? GloveType.left : GloveType.right,
      ));
    }
  }

  void _addStreak() {
    streak++;
    if (streak > maxStreak) maxStreak = streak;
  }

  void _collectWord(WordItem word) {
    if (!savedWords.any((w) => w.word == word.word)) savedWords.add(word);
  }

  void _handleGoalConceded(GoalBall ball) {
    ball.state = BallState.goal;
    ball.timeAlive = 0.0;
    ballsMissed++;
    streak = 0;
    lives--;
    netShake = 1.0;

    // Tiếng còi nhẹ nhàng thay vì tiếng "sai rồi" để bé không nản
    SoundService.instance.playWhistle();
    onGoalConceded?.call();

    if (lives <= 0) {
      phase = KeeperPhase.gameOver;
      _saveHighScore();
      SoundService.instance.playTada();
      onGameOver?.call();
    }
    notifyListeners();
  }

  void _spawnCatchParticles(double x, double y, Color color) {
    for (int i = 0; i < 24; i++) {
      final double angle = _random.nextDouble() * 2 * math.pi;
      final double spd = 0.6 + _random.nextDouble() * 1.4;
      particles.add(SparkParticle(
        x: x,
        y: y,
        vx: math.cos(angle) * spd,
        vy: math.sin(angle) * spd,
        color: i % 2 == 0 ? color : Colors.amberAccent,
        radius: 4.0 + _random.nextDouble() * 5.0,
        life: 0.65,
        maxLife: 0.65,
        emoji: i % 4 == 0 ? '⭐' : (i % 4 == 1 ? '✨' : null),
      ));
    }
  }

  void _spawnBlockParticles(double x, double y, Color color) {
    for (int i = 0; i < 16; i++) {
      final double angle = _random.nextDouble() * 2 * math.pi;
      final double spd = 0.8 + _random.nextDouble() * 1.6;
      particles.add(SparkParticle(
        x: x,
        y: y,
        vx: math.cos(angle) * spd,
        vy: math.sin(angle) * spd,
        color: i % 2 == 0 ? color : Colors.white,
        radius: 3.5 + _random.nextDouble() * 3.5,
        life: 0.45,
        maxLife: 0.45,
      ));
    }
  }

  /// Pháo giấy rơi từ trên xuống khắp màn hình
  void _spawnConfetti() {
    const colors = [
      Color(0xFFFF5252),
      Color(0xFFFFD600),
      Color(0xFF00E676),
      Color(0xFF40C4FF),
      Color(0xFFE040FB),
      Color(0xFFFF9100),
    ];
    for (int i = 0; i < 40; i++) {
      particles.add(SparkParticle(
        x: _random.nextDouble() * 2.4 - 1.2,
        y: -1.45 - _random.nextDouble() * 0.3,
        vx: (_random.nextDouble() - 0.5) * 0.4,
        vy: 0.2 + _random.nextDouble() * 0.5,
        color: colors[i % colors.length],
        radius: 5.0 + _random.nextDouble() * 4.0,
        life: 2.2,
        maxLife: 2.2,
        confetti: true,
      ));
    }
  }

  void _updateParticles(double dt) {
    for (int i = particles.length - 1; i >= 0; i--) {
      final p = particles[i];
      p.life -= dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.vy += dt * (p.confetti ? 0.35 : 1.8); // Pháo giấy rơi chậm, bồng bềnh

      if (p.life <= 0) {
        particles.removeAt(i);
      }
    }
  }
}
