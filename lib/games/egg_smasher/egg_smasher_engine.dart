import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../motion/motion_state.dart';
import '../../services/sound_service.dart';
import '../../services/word_bank.dart';
import 'egg_smasher_models.dart';

class EggSmasherEngine extends ChangeNotifier {
  // Trạng thái màn chơi
  bool isPlaying = false;
  bool isGameOver = false;
  bool isPaused = false;
  int score = 0;

  // ENDLESS MODE: đập liên tục, đập sai mất 1 mạng, hết 3 mạng là Game Over
  static const int maxLives = 3;
  int lives = maxLives;
  int eggsSmashed = 0; // số từ đã đập đúng
  int streak = 0;
  int highScore = 0;
  bool isNewHighScore = false;
  double _gameOverDelay = 0.0;

  /// Gọi khi ghi điểm: (điểm cộng, chuỗi đúng, toạ độ chuẩn hoá x/y trên màn hình) -> để vẽ điểm bay
  void Function(int gained, int streak, double x, double y)? onScored; // chờ hiệu ứng đập sai cuối cùng trước khi hiện Game Over
  WordEntry? _lastTarget;

  // Dữ liệu vòng chơi hiện tại
  WordEntry? currentTarget;
  final List<EggItem> eggs = [];
  final List<EggShellFragment> fragments = [];
  final List<SparkleStar> sparkles = [];
  final List<HatchedCreature> hatchedCreatures = [];

  // Banner thông báo kết quả & hiệu ứng chuyển vòng
  bool isRoundTransition = false;
  bool lastSmashCorrect = true; // kết quả cú đập vừa rồi (để thỏ vui / buồn trong lúc chuyển vòng)
  double transitionTimer = 0.0;
  String bannerMessage = '';
  Color bannerColor = Colors.white;

  // Đếm thời gian tự động phát lại audio của từ mục tiêu mỗi 5 giây
  double wordAudioRepeatTimer = 5.0;

  // Đếm thời gian phục hồi khi đập sai trứng (tự động xóa banner & dừng lắc trứng sau 1.5s)
  double wrongSmashTimer = 0.0;

  // Kích thước trứng (tỉ lệ màn hình) & vị trí tổ rơm so với tâm trứng (khớp _drawStrawNest)
  static const double eggRadiusX = 0.098;
  static const double eggRadiusY = 0.138;
  static const double nestOffsetFactor = 0.78; // tâm tổ = tâm trứng + eggRadiusY * 0.78

  // Độ cao hàng trứng (tỉ lệ chiều cao màn hình). Màn hình gọi setNestGroundY() theo tỉ lệ khung hình
  // để tổ trứng luôn nằm trên mặt cỏ của ảnh nền
  double eggRowY = 0.75;

  /// Đặt tâm tổ rơm tại độ cao [nestCenterY] (tỉ lệ chiều cao màn hình). Không notify (gọi trong build được)
  void setNestGroundY(double nestCenterY) {
    final newRowY = nestCenterY - eggRadiusY * nestOffsetFactor;
    if ((newRowY - eggRowY).abs() < 0.0005) return;
    eggRowY = newRowY;
    cursorY = newRowY;
    for (final egg in eggs) {
      egg.y = newRowY;
    }
  }

  // Tọa độ con trỏ Búa (Búa di chuyển ngang Trái/Phải; Y cố định theo hàng trứng)
  double cursorX = 0.5;
  double cursorY = 0.75;

  // Trạng thái nắm tay để lướt búa (Hand Mode Grab & Drag)
  bool isHandGrabbing = false;
  bool _wasHandFist = false;
  bool _wasNodding = true; // true: đang cúi sẵn lúc vào game thì phải ngẩng lên rồi gật mới tính

  // Trạng thái gật đầu để đập búa (Face Mode Nod Down)

  // Animation vung búa xuống (1.0 -> 0.0)
  double hammerSmashAnim = 0.0;
  DateTime _lastSmashTime = DateTime.fromMillisecondsSinceEpoch(0);

  final math.Random _random = math.Random();

  EggSmasherEngine() {
    _loadHighScore();
  }

  Future<void> _loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    highScore = prefs.getInt('egg_smasher_high_score') ?? 0;
    notifyListeners();
  }

  Future<void> _saveHighScore() async {
    isNewHighScore = score > highScore;
    if (isNewHighScore) {
      highScore = score;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('egg_smasher_high_score', highScore);
    }
  }

  /// [announce] = false: chưa đọc từ mục tiêu (màn chơi gọi [announceTarget] sau khi bé vào vị trí)
  void startGame({bool announce = true}) {
    isPlaying = true;
    isGameOver = false;
    isPaused = false;
    score = 0;
    lives = maxLives;
    eggsSmashed = 0;
    streak = 0;
    isNewHighScore = false;
    _gameOverDelay = 0.0;
    _lastTarget = null;
    cursorX = 0.5;
    cursorY = eggRowY;
    isHandGrabbing = false;
    wordAudioRepeatTimer = 5.0;
    wrongSmashTimer = 0.0;
    fragments.clear();
    sparkles.clear();
    hatchedCreatures.clear();
    _startRound(announce: announce);
    notifyListeners();
  }

  /// Đọc từ mục tiêu & hẹn giờ đọc lại sau 5s
  void announceTarget() {
    if (currentTarget == null) return;
    SoundService.instance.playWord(currentTarget!.word);
    wordAudioRepeatTimer = 5.0;
  }

  void pauseGame() {
    isPaused = true;
    notifyListeners();
  }

  void resumeGame() {
    isPaused = false;
    notifyListeners();
  }

  void restartGame() {
    startGame();
  }

  void _startRound({bool announce = true}) {
    isRoundTransition = false;
    transitionTimer = 0.0;
    bannerMessage = '';
    eggs.clear();

    // Chọn từ mục tiêu ngẫu nhiên trong kho từ chung (không lặp lại từ của vòng ngay trước)
    // (chạy thử trên localhost: chỉ từ đã có ảnh, xem WordImages.testImagesOnly)
    final availableWords = WordBank.instance.shuffled(_random, min: 3);
    final target = availableWords.firstWhere((w) => w.word != _lastTarget?.word, orElse: () => availableWords.first);
    currentTarget = target;
    _lastTarget = target;

    // Chọn 2 từ khác làm đáp án nhiễu
    final distractors = availableWords.where((w) => w.word != target.word).take(2).toList();
    final roundWords = [target, ...distractors]..shuffle(_random);

    // Bố trí 3 quả trứng cân đối trên hàng ngang (Trái: 0.22, Giữa: 0.50, Phải: 0.78)
    final xCoords = [0.22, 0.50, 0.78];
    for (int i = 0; i < roundWords.length; i++) {
      final w = roundWords[i];
      eggs.add(EggItem(
        id: i,
        word: w,
        x: xCoords[i],
        y: eggRowY,
        radiusX: eggRadiusX,
        radiusY: eggRadiusY,
        isTarget: w.word == target.word,
        colorTheme: EggColorTheme.themes[i % EggColorTheme.themes.length],
      ));
    }

    // Phát âm thanh của từ mục tiêu ngay khi từ mới xuất hiện
    if (announce) announceTarget();
    wordAudioRepeatTimer = 5.0;
    wrongSmashTimer = 0.0;
  }

  void update(double dt, MotionState motion) {
    if (!isPlaying || isGameOver || isPaused) return;

    final now = DateTime.now();
    cursorY = eggRowY; // Ghim vững chắc tại độ cao hàng trứng để búa không bị trôi lên/xuống

    // =========================================================================
    // 1. HAND MODE: XÒE TAY DI CHUYỂN BÚA | NẮM TAY ĐỂ ĐẬP
    // =========================================================================
    if (motion.inputMode == MotionInputMode.hand && motion.handDetected) {
      isHandGrabbing = motion.isHandFist;

      // Búa đi theo steerX: giá trị TRÁI/PHẢI thống nhất Face & Hand (cùng chiều thước đo Hiệu chỉnh).
      // Không dùng handVisualX: đó là toạ độ ảnh preview, chỉ để vẽ reticle, bị ngược chiều & chưa cân bằng.
      // Trái (-1.0) -> X = 0.18 (Trứng Trái) | Giữa (0.0) -> X = 0.50 | Phải (+1.0) -> X = 0.82 (Trứng Phải)
      final double targetX = (0.50 + motion.steerX * 0.32).clamp(0.18, 0.82);
      cursorX += (targetX - cursorX) * (18.0 * dt).clamp(0.0, 1.0);

      // CỬ CHỈ ĐẬP BÚA: NẮM TAY (FIST)
      // Kích hoạt theo sườn lên (từ Xòe sang Nắm) với cooldown 350ms, mỗi lần nắm là 1 cú đập dứt khoát
      if (motion.isHandFist && !_wasHandFist && now.difference(_lastSmashTime).inMilliseconds > 350) {
        _triggerSmash(cursorX, cursorY);
      }
      _wasHandFist = motion.isHandFist;
    }
    // =========================================================================
    // 2. FACE MODE: NGHIÊNG/QUAY MẶT CHỌN TRỨNG | CHỈ BẮT GẬT ĐẦU ĐỂ ĐẬP
    // =========================================================================
    else if (motion.faceDetected) {
      isHandGrabbing = false;
      _wasHandFist = false;

      // DI CHUYỂN BÚA NGANG theo steerX (cùng logic & cùng chiều với Hand mode):
      // Nghiêng đầu Trái -> âm -> Búa sang Trái | Nghiêng đầu Phải -> dương -> Búa sang Phải
      final double targetX = (0.50 + motion.steerX * 0.32).clamp(0.18, 0.82);
      cursorX += (targetX - cursorX) * (14.0 * dt).clamp(0.0, 1.0);

      // CỬ CHỈ ĐẬP DUY NHẤT Ở FACE MODE: GẬT ĐẦU XUỐNG DƯỚI (Head Nod Down)
      // ĐÃ BỎ HÀNH ĐỘNG HÁ MIỆNG THEO YÊU CẦU CỦA USER
      // isNodding đã có trễ (hysteresis) + giữ đủ lâu trong FaceMotionController: đập 1 lần khi vừa bắt đầu gật
      if (motion.isNodding && !_wasNodding && now.difference(_lastSmashTime).inMilliseconds > 500) {
        _triggerSmash(cursorX, cursorY);
      }
      _wasNodding = motion.isNodding;
    } else {
      isHandGrabbing = false;
    }

    // =========================================================================
    // 3. CẬP NHẬT HIỆU ỨNG VUNG BÚA BỔ XUỐNG
    // =========================================================================
    if (hammerSmashAnim > 0) {
      hammerSmashAnim = math.max(0.0, hammerSmashAnim - dt * 3.8);
    }

    // =========================================================================
    // 4. CẬP NHẬT ĐỘ LẮC LƯ & NỨT CỦA CÁC QUẢ TRỨNG
    // =========================================================================
    for (final egg in eggs) {
      egg.wobblePhase += dt * 3.5;
      if (egg.state == EggState.wobbling) {
        egg.wobbleAngle = math.sin(egg.wobblePhase * 4) * 0.22;
      } else if (egg.state == EggState.idle) {
        egg.wobbleAngle = math.sin(egg.wobblePhase) * 0.04;
      }
    }

    // =========================================================================
    // 5. TỰ ĐỘNG RESET TRẠNG THÁI KHI ĐẬP SAI (Xóa banner Thử lại & dừng lắc trứng)
    // =========================================================================
    if (wrongSmashTimer > 0) {
      wrongSmashTimer -= dt;
      if (wrongSmashTimer <= 0) {
        wrongSmashTimer = 0.0;
        if (bannerMessage == 'TRY AGAIN! 🥚') {
          bannerMessage = '';
        }
        for (final egg in eggs) {
          if (egg.state == EggState.wobbling) {
            egg.state = EggState.idle;
            egg.wobbleAngle = 0.0;
            egg.crackIntensity = 0.0;
          }
        }
      }
    }

    // =========================================================================
    // 6. TỰ ĐỘNG PHÁT LẠI AUDIO CỦA TỪ MỖI 5 GIÂY TRONG VÒNG CHƠI
    // =========================================================================
    if (isPlaying && !isGameOver && !isPaused && !isRoundTransition && currentTarget != null) {
      wordAudioRepeatTimer -= dt;
      if (wordAudioRepeatTimer <= 0) {
        wordAudioRepeatTimer = 5.0;
        SoundService.instance.playWord(currentTarget!.word);
      }
    }

    // =========================================================================
    // 5. CẬP NHẬT MẢNH VỠ & SAO BAY & SINH VẬT NỞ
    // =========================================================================
    fragments.removeWhere((f) => !f.update(dt));
    sparkles.removeWhere((s) => !s.update(dt));
    hatchedCreatures.removeWhere((c) => !c.update(dt));

    // =========================================================================
    // 6. ĐẾM THỜI GIAN CHUYỂN VÒNG KHI ĐẬP ĐÚNG
    // =========================================================================
    if (isRoundTransition) {
      transitionTimer -= dt;
      if (transitionTimer <= 0) {
        if (lives > 0) _startRound(); // Endless: sang từ mới liên tục (hết mạng thì chờ Game Over)
      }
    }

    // =========================================================================
    // 7. HẾT MẠNG -> GAME OVER (sau 1.2s để kịp thấy trứng lắc & tim mất)
    // =========================================================================
    if (_gameOverDelay > 0) {
      _gameOverDelay -= dt;
      if (_gameOverDelay <= 0) {
        _gameOverDelay = 0.0;
        isGameOver = true;
        isPlaying = false;
        bannerMessage = '';
        _saveHighScore();
        SoundService.instance.playTada();
      }
    }

    notifyListeners();
  }

  /// Chơi bằng chuột: búa đi theo con trỏ ([px] tỉ lệ bề ngang màn hình)
  void touchHover(double px) {
    if (!isPlaying || isGameOver || isPaused) return;
    cursorX = px.clamp(0.18, 0.82);
  }

  /// Chơi bằng chạm: đập quả trứng gần chỗ chạm nhất theo chiều ngang (chạm khe giữa 2 trứng
  /// hay chạm lên trời phía trên trứng vẫn trúng, bé nhỏ chạm không chuẩn)
  void touchSmashAt(double px) {
    EggItem? nearest;
    for (final egg in eggs) {
      if (egg.state == EggState.shattered) continue;
      if (nearest == null || (px - egg.x).abs() < (px - nearest.x).abs()) nearest = egg;
    }
    if (nearest == null) return;
    cursorX = nearest.x;
    cursorY = eggRowY;
    _triggerSmash(nearest.x, eggRowY);
    notifyListeners();
  }

  void _triggerSmash(double px, double py) {
    if (!isPlaying || isGameOver || isPaused || isRoundTransition) return;
    // Đang hồi sau cú đập sai / đang chờ Game Over: bỏ qua để 1 cử chỉ rung không trừ 2 mạng
    if (wrongSmashTimer > 0 || _gameOverDelay > 0) return;

    _lastSmashTime = DateTime.now();
    hammerSmashAnim = 1.0;
    HapticFeedback.heavyImpact();

    // Tìm quả trứng bị trúng búa (đối chiếu theo tọa độ X của hàng 3 quả trứng)
    EggItem? hitEgg;
    for (final egg in eggs) {
      if (egg.state == EggState.shattered) continue;
      final dx = (px - egg.x).abs();
      if (dx <= egg.radiusX * 1.35) {
        hitEgg = egg;
        break;
      }
    }

    if (hitEgg != null) {
      if (hitEgg.isTarget) {
        // SMASH TRÚNG ĐÁP ÁN ĐÚNG!
        hitEgg.state = EggState.shattered;
        eggsSmashed++;
        streak++;
        // Thưởng chuỗi: +20 cho mỗi lần đúng liên tiếp (tối đa +100)
        final gained = 100 + (math.min(streak - 1, 5) * 20);
        score += gained;
        isRoundTransition = true;
        lastSmashCorrect = true;
        transitionTimer = 1.8;
        wrongSmashTimer = 0.0;
        bannerMessage = ''; // điểm hiển thị bằng hiệu ứng bay về ô tổng điểm
        onScored?.call(gained, streak, hitEgg.x, hitEgg.y - 0.12);

        // Reset các quả trứng khác về trạng thái bình thường
        for (final egg in eggs) {
          if (egg != hitEgg && egg.state == EggState.wobbling) {
            egg.state = EggState.idle;
            egg.wobbleAngle = 0.0;
            egg.crackIntensity = 0.0;
          }
        }

        _spawnEggShatter(hitEgg);
        SoundService.instance.playEggCrack();
        SoundService.instance.playCorrect();
      } else {
        // SMASH NHẦM TRỨNG! Vẫn tính 1 lần đập: trứng vỡ, mất 1 mạng, sang từ tiếp theo
        hitEgg.state = EggState.shattered;
        streak = 0;
        lives = math.max(0, lives - 1);
        isRoundTransition = true;
        lastSmashCorrect = false;
        transitionTimer = 1.8;
        wrongSmashTimer = 0.0;
        if (lives == 0) _gameOverDelay = 1.2;

        for (final egg in eggs) {
          if (egg != hitEgg && egg.state == EggState.wobbling) {
            egg.state = EggState.idle;
            egg.wobbleAngle = 0.0;
            egg.crackIntensity = 0.0;
          }
        }

        _spawnEggShatter(hitEgg, celebrate: false);
        SoundService.instance.playEggCrack();
        SoundService.instance.playWrongAnswer();
        HapticFeedback.mediumImpact();
      }
    } else {
      // Đập vào không khí
      // Đã bỏ âm thanh flap theo yêu cầu
    }
  }

  /// [celebrate] = false (đập sai): chỉ vỡ vỏ, không có sao lấp lánh & sinh vật nở ra
  void _spawnEggShatter(EggItem egg, {bool celebrate = true}) {
    // 1. Mảnh vỡ vỏ trứng bắn tung tóe
    for (int i = 0; i < 30; i++) {
      final angle = _random.nextDouble() * math.pi * 2;
      final speed = 0.35 + _random.nextDouble() * 0.75;
      fragments.add(EggShellFragment(
        x: egg.x,
        y: egg.y,
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed - 0.45,
        rotation: _random.nextDouble() * math.pi,
        vRot: (_random.nextDouble() - 0.5) * 16.0,
        size: 0.015 + _random.nextDouble() * 0.025,
        color: _random.nextBool() ? egg.colorTheme.primary : egg.colorTheme.secondary,
        maxLife: 0.65 + _random.nextDouble() * 0.35,
      ));
    }

    if (!celebrate) return;

    // 2. Chùm sao lấp lánh nở rộ
    for (int i = 0; i < 22; i++) {
      final angle = _random.nextDouble() * math.pi * 2;
      final speed = 0.2 + _random.nextDouble() * 0.55;
      sparkles.add(SparkleStar(
        x: egg.x,
        y: egg.y - 0.05,
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed - 0.25,
        size: 0.012 + _random.nextDouble() * 0.018,
        color: _random.nextBool() ? const Color(0xFFFFD600) : const Color(0xFF00E5FF),
        maxLife: 0.55 + _random.nextDouble() * 0.3,
      ));
    }

    // 3. Nhân vật đáng yêu nhảy ra từ trong quả trứng (kèm thẻ ăn mừng đầy đủ chữ & nghĩa)
    hatchedCreatures.add(HatchedCreature(
      x: egg.x,
      y: egg.y - 0.06,
      word: egg.word,
    ));
  }
}
