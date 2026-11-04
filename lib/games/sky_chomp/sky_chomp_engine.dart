import '../../services/sound_service.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../../motion/motion_state.dart';
import 'sky_chomp_models.dart';

class SkyChompEngine extends ChangeNotifier {
  final Player player = Player();
  final List<FoodItem> foods = [];
  final List<Obstacle> obstacles = [];
  final List<Particle> particles = [];
  final List<FloatingText> floatingTexts = [];

  final List<Offset> starsFar = [];
  final List<Offset> starsMid = [];
  final List<Offset> starsNear = [];

  int score = 0;
  int highScore = 0;
  int combo = 0;
  int maxCombo = 0;
  double feverEnergy = 0.0;
  bool isFeverMode = false;
  double feverTimer = 0.0;

  int totalChomps = 0;
  int totalDodges = 0;

  bool isPlaying = false;
  bool isGameOver = false;
  bool isPaused = false;

  double shakeAmount = 0.0;
  double _gameTime = 0.0;
  double _foodSpawnTimer = 0.0;
  double _obstacleSpawnTimer = 0.0;
  final math.Random _random = math.Random();

  SkyChompEngine() {
    _initStars();
    _loadHighScore();
  }

  void _initStars() {
    starsFar.clear();
    starsMid.clear();
    starsNear.clear();
    for (int i = 0; i < 40; i++) {
      starsFar.add(Offset(_random.nextDouble(), _random.nextDouble()));
    }
    for (int i = 0; i < 25; i++) {
      starsMid.add(Offset(_random.nextDouble(), _random.nextDouble()));
    }
    for (int i = 0; i < 15; i++) {
      starsNear.add(Offset(_random.nextDouble(), _random.nextDouble()));
    }
  }

  Future<void> _loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    highScore = prefs.getInt('sky_chomp_high_score') ?? 0;
    notifyListeners();
  }

  Future<void> _saveHighScore() async {
    if (score > highScore) {
      highScore = score;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('sky_chomp_high_score', highScore);
    }
  }

  void startGame() {
    player.reset();
    foods.clear();
    obstacles.clear();
    particles.clear();
    floatingTexts.clear();

    score = 0;
    combo = 0;
    maxCombo = 0;
    feverEnergy = 0.0;
    isFeverMode = false;
    feverTimer = 0.0;
    totalChomps = 0;
    totalDodges = 0;
    shakeAmount = 0.0;
    _gameTime = 0.0;
    _foodSpawnTimer = 0.0;
    _obstacleSpawnTimer = 0.0;

    isPlaying = true;
    isGameOver = false;
    isPaused = false;
    notifyListeners();
  }

  void resumeGame() {
    isPaused = false;
    notifyListeners();
  }

  void pauseGame() {
    isPaused = !isPaused;
    notifyListeners();
  }

  void update(double dt, MotionState motion) {
    if (!isPlaying || isGameOver || isPaused) return;

    _gameTime += dt;

    _updatePlayerFromMotion(dt, motion);
    _updateStars(dt);
    _updateFever(dt);
    _updateSpawners(dt);
    _updateEntities(dt);
    _checkCollisions();

    particles.removeWhere((p) => !p.update(dt));
    floatingTexts.removeWhere((t) => !t.update(dt));

    if (shakeAmount > 0) {
      shakeAmount = math.max(0.0, shakeAmount - 30 * dt);
    }

    notifyListeners();
  }

  void _updatePlayerFromMotion(double dt, MotionState motion) {
    double steerSpeed = 1.35;
    if (isFeverMode) steerSpeed = 1.6;

    if (motion.tiltDirection == TiltDirection.left) {
      final intensity = (motion.relativeRoll.abs() / 25.0).clamp(0.5, 1.8);
      player.targetX = (player.targetX - steerSpeed * intensity * dt).clamp(0.08, 0.92);
      player.tiltAngle = -0.25;
    } else if (motion.tiltDirection == TiltDirection.right) {
      final intensity = (motion.relativeRoll.abs() / 25.0).clamp(0.5, 1.8);
      player.targetX = (player.targetX + steerSpeed * intensity * dt).clamp(0.08, 0.92);
      player.tiltAngle = 0.25;
    } else {
      player.tiltAngle = 0.0;
    }

    player.x += (player.targetX - player.x) * (14.0 * dt).clamp(0.0, 1.0);

    final targetMouth = motion.isChomping ? 1.0 : (motion.relativeMouth * 3.5).clamp(0.0, 0.8);
    player.mouthOpenProgress += (targetMouth - player.mouthOpenProgress) * (20.0 * dt).clamp(0.0, 1.0);
    player.isChomping = motion.isChomping;

    if (player.isInvincible && !isFeverMode) {
      player.invincibleTimer -= dt;
      if (player.invincibleTimer <= 0) {
        player.isInvincible = false;
      }
    }
  }

  void _updateStars(double dt) {
    final baseSpeed = isFeverMode ? 0.9 : 0.35;
    for (int i = 0; i < starsFar.length; i++) {
      var dy = (starsFar[i].dy + baseSpeed * 0.2 * dt) % 1.0;
      starsFar[i] = Offset(starsFar[i].dx, dy);
    }
    for (int i = 0; i < starsMid.length; i++) {
      var dy = (starsMid[i].dy + baseSpeed * 0.5 * dt) % 1.0;
      starsMid[i] = Offset(starsMid[i].dx, dy);
    }
    for (int i = 0; i < starsNear.length; i++) {
      var dy = (starsNear[i].dy + baseSpeed * 0.9 * dt) % 1.0;
      starsNear[i] = Offset(starsNear[i].dx, dy);
    }
  }

  void _updateFever(double dt) {
    if (isFeverMode) {
      feverTimer -= dt;
      feverEnergy = (feverTimer / 6.0).clamp(0.0, 1.0);
      if (feverTimer <= 0) {
        isFeverMode = false;
        feverEnergy = 0.0;
        player.isInvincible = false;
      }
    }
  }

  void _updateSpawners(double dt) {
    final speedMultiplier = 1.0 + (_gameTime / 60.0) * 0.5;

    _foodSpawnTimer += dt;
    if (_foodSpawnTimer >= 1.3) {
      _foodSpawnTimer = 0.0;
      _spawnFood(speedMultiplier);
    }

    _obstacleSpawnTimer += dt;
    final obstacleInterval = math.max(1.1, 2.2 - (_gameTime / 45.0) * 0.7);
    if (_obstacleSpawnTimer >= obstacleInterval) {
      _obstacleSpawnTimer = 0.0;
      _spawnObstacle(speedMultiplier);
    }
  }

  void _spawnFood(double speedMultiplier) {
    final types = [
      FoodType.star,
      FoodType.donut,
      FoodType.pizza,
      FoodType.diamond,
      if (_random.nextDouble() < 0.25) FoodType.megaBurger,
    ];
    final type = types[_random.nextInt(types.length)];
    int pts = 50;
    double feverBoost = 0.08;
    if (type == FoodType.donut) pts = 80;
    if (type == FoodType.pizza) pts = 100;
    if (type == FoodType.diamond) { pts = 200; feverBoost = 0.15; }
    if (type == FoodType.megaBurger) { pts = 300; feverBoost = 0.25; }

    foods.add(FoodItem(
      id: UniqueKey().toString(),
      type: type,
      x: 0.12 + _random.nextDouble() * 0.76,
      y: -0.05,
      points: pts,
      feverEnergy: feverBoost,
      speed: (0.28 + _random.nextDouble() * 0.12) * speedMultiplier,
    ));
  }

  void _spawnObstacle(double speedMultiplier) {
    final types = [
      ObstacleType.meteor,
      ObstacleType.spikyDrone,
      if (_gameTime > 20) ObstacleType.laserBarrier,
    ];
    final type = types[_random.nextInt(types.length)];

    obstacles.add(Obstacle(
      id: UniqueKey().toString(),
      type: type,
      x: 0.12 + _random.nextDouble() * 0.76,
      y: -0.08,
      speed: (0.32 + _random.nextDouble() * 0.16) * speedMultiplier,
      rotationSpeed: (_random.nextDouble() - 0.5) * 4.0,
    ));
  }

  void _updateEntities(double dt) {
    for (final food in foods) {
      food.y += food.speed * dt;
      food.wobblePhase += 4.0 * dt;
    }
    foods.removeWhere((f) => f.y > 1.1 || f.isEaten);

    for (final obs in obstacles) {
      obs.y += obs.speed * dt;
      obs.rotation += obs.rotationSpeed * dt;

      if (obs.y > player.y + 0.05 && obs.y - obs.speed * dt <= player.y + 0.05 && !obs.isDestroyed) {
        totalDodges++;
        score += 30;
        _addFloatingText('DODGED! +30', obs.x, obs.y, GameColors.neonCyan);
      }
    }
    obstacles.removeWhere((o) => o.y > 1.1 || o.isDestroyed);
  }

  void _checkCollisions() {
    const playerRadius = 0.042;

    for (final food in foods) {
      if (food.isEaten) continue;
      final dist = math.sqrt(math.pow(food.x - player.x, 2) + math.pow(food.y - player.y, 2));

      if (isFeverMode && dist < 0.22) {
        food.x += (player.x - food.x) * 0.2;
        food.y += (player.y - food.y) * 0.2;
      }

      if (dist < playerRadius + 0.04) {
        food.isEaten = true;
        _handleFoodEaten(food);
      }
    }

    for (final obs in obstacles) {
      if (obs.isDestroyed) continue;
      final dist = math.sqrt(math.pow(obs.x - player.x, 2) + math.pow(obs.y - player.y, 2));

      if (dist < playerRadius + 0.035) {
        if (isFeverMode) {
          obs.isDestroyed = true;
          score += 150;
          _spawnExplosion(obs.x, obs.y, GameColors.neonPurple);
          _addFloatingText('DESTROYED! +150', obs.x, obs.y, GameColors.neonPurple);
          shakeAmount = 8.0;
          HapticFeedback.mediumImpact();
        } else if (!player.isInvincible) {
          obs.isDestroyed = true;
          _handlePlayerHit(obs);
        }
      }
    }
  }

  void _handleFoodEaten(FoodItem food) {
    totalChomps++;
    final isChompSuccessful = player.mouthOpenProgress > 0.35 || player.isChomping || isFeverMode;

    if (isChompSuccessful) {
      combo++;
      if (combo > maxCombo) maxCombo = combo;

      final multiplier = 1.0 + (combo * 0.15).clamp(0.0, 3.0);
      final earned = (food.points * multiplier).round();
      score += earned;

      if (!isFeverMode) {
        feverEnergy = (feverEnergy + food.feverEnergy).clamp(0.0, 1.0);
        if (feverEnergy >= 1.0) {
          _activateFeverMode();
        }
      }

      _spawnExplosion(food.x, food.y, food.color);
      _addFloatingText(
        combo > 1 ? 'CHOMP! x$combo +$earned' : 'CHOMP! +$earned',
        food.x,
        food.y,
        GameColors.neonGreen,
      );
      HapticFeedback.lightImpact();
      if (combo > 1) {
        SoundService.instance.playCombo();
      } else {
        SoundService.instance.playChomp();
      }
    } else {
      final earned = (food.points * 0.3).round();
      score += earned;
      combo = 0;
      _addFloatingText('OPEN WIDE! +$earned', food.x, food.y, GameColors.neonYellow);
      SoundService.instance.playChomp();
    }
  }

  void _activateFeverMode() {
    isFeverMode = true;
    feverTimer = 6.0;
    feverEnergy = 1.0;
    player.isInvincible = true;
    shakeAmount = 12.0;
    _addFloatingText('FEVER MODE!', player.x, player.y - 0.1, GameColors.neonYellow);
    HapticFeedback.heavyImpact();
    SoundService.instance.playCombo();
  }

  void _handlePlayerHit(Obstacle obs) {
    player.lives--;
    combo = 0;
    shakeAmount = 20.0;
    player.isInvincible = true;
    player.invincibleTimer = 2.0;

    _spawnExplosion(player.x, player.y, GameColors.neonPink);
    _addFloatingText('HIT! -1 LIFE', player.x, player.y - 0.08, GameColors.neonPink);
    HapticFeedback.heavyImpact();
    SoundService.instance.playBomb();

    if (player.lives <= 0) {
      _triggerGameOver();
    }
  }

  void _triggerGameOver() {
    isPlaying = false;
    isGameOver = true;
    _saveHighScore();
    SoundService.instance.playGameOver();
    notifyListeners();
  }

  void _spawnExplosion(double x, double y, Color color) {
    for (int i = 0; i < 18; i++) {
      final angle = _random.nextDouble() * 2 * math.pi;
      final speed = 0.15 + _random.nextDouble() * 0.45;
      particles.add(Particle(
        x: x,
        y: y,
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed,
        color: color,
        life: 1.0,
        maxLife: 0.6 + _random.nextDouble() * 0.4,
        size: 3.0 + _random.nextDouble() * 4.0,
      ));
    }
  }

  void _addFloatingText(String text, double x, double y, Color color) {
    // Đã loại bỏ hoàn toàn text thông báo / điểm nhảy trên màn hình để tránh gây nháy khó chịu
  }
}
