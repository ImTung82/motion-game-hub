import '../../services/sound_service.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../motion/motion_state.dart';

class PipePair {
  double x; // 0.0 -> 1.0 (normalized)
  final double topHeight; // 0.1 -> 0.6
  final double gap; // khoảng trống giữa 2 cột (0.28)
  bool isPassed;

  PipePair({
    required this.x,
    required this.topHeight,
    this.gap = 0.28,
    this.isPassed = false,
  });

  double get bottomY => topHeight + gap;
}

class FlappyEngine extends ChangeNotifier {
  double birdX = 0.25;
  double birdY = 0.5;
  double birdVelocity = 0.0;
  double birdRotation = 0.0;
  double mouthProgress = 0.0;

  final List<PipePair> pipes = [];
  final List<Offset> clouds = [];

  int score = 0;
  int highScore = 0;
  bool isPlaying = false;
  bool isGameOver = false;
  bool isPaused = false;

  bool _wasChomping = false;
  double _pipeSpawnTimer = 0.0;
  final math.Random _random = math.Random();

  FlappyEngine() {
    _initClouds();
    _loadHighScore();
  }

  void _initClouds() {
    clouds.clear();
    for (int i = 0; i < 6; i++) {
      clouds.add(Offset(_random.nextDouble(), 0.1 + _random.nextDouble() * 0.4));
    }
  }

  Future<void> _loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    highScore = prefs.getInt('flappy_mouth_high_score') ?? 0;
    notifyListeners();
  }

  Future<void> _saveHighScore() async {
    if (score > highScore) {
      highScore = score;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('flappy_mouth_high_score', highScore);
    }
  }

  void startGame() {
    birdX = 0.25;
    birdY = 0.5;
    birdVelocity = 0.0;
    birdRotation = 0.0;
    mouthProgress = 0.0;
    pipes.clear();
    score = 0;
    _wasChomping = false;
    _pipeSpawnTimer = 0.0;

    isPlaying = true;
    isGameOver = false;
    isPaused = false;
    notifyListeners();
  }

  void pauseGame() {
    isPaused = !isPaused;
    notifyListeners();
  }

  void flap() {
    if (!isPlaying || isGameOver || isPaused) return;
    birdVelocity = -0.52;
    HapticFeedback.lightImpact();
    SoundService.instance.playFlap();
  }

  void update(double dt, MotionState motion) {
    if (!isPlaying || isGameOver || isPaused) return;

    // Detect mouth flap (khi ngÆ°á»i chÆ¡i má»Ÿ miá»‡ng to)
    mouthProgress = motion.isChomping ? 1.0 : (motion.relativeMouth * 3.5).clamp(0.0, 1.0);
    if (motion.isChomping && !_wasChomping) {
      flap();
    }
    _wasChomping = motion.isChomping;

    // Head Tilt nudges bird X position slightly
    if (motion.tiltDirection == TiltDirection.left) {
      birdX = (birdX - 0.2 * dt).clamp(0.12, 0.4);
    } else if (motion.tiltDirection == TiltDirection.right) {
      birdX = (birdX + 0.2 * dt).clamp(0.12, 0.4);
    }

    // Physics
    const gravity = 1.35;
    birdVelocity += gravity * dt;
    birdY += birdVelocity * dt;
    birdRotation = (birdVelocity * 1.5).clamp(-0.5, 0.7);

    // Clouds
    for (int i = 0; i < clouds.length; i++) {
      var cx = clouds[i].dx - 0.05 * dt;
      if (cx < -0.2) cx = 1.1;
      clouds[i] = Offset(cx, clouds[i].dy);
    }

    // Spawn pipes
    _pipeSpawnTimer += dt;
    if (_pipeSpawnTimer >= 2.0) {
      _pipeSpawnTimer = 0.0;
      _spawnPipe();
    }

    // Move pipes
    for (final pipe in pipes) {
      pipe.x -= 0.26 * dt;

      // Pass check
      if (!pipe.isPassed && pipe.x < birdX) {
        pipe.isPassed = true;
        score++;
        HapticFeedback.mediumImpact();
        SoundService.instance.playScore();
      }
    }
    pipes.removeWhere((p) => p.x < -0.2);

    // Collisions
    _checkCollisions();

    notifyListeners();
  }

  void _spawnPipe() {
    final topH = 0.15 + _random.nextDouble() * 0.35;
    pipes.add(PipePair(
      x: 1.1,
      topHeight: topH,
      gap: 0.28,
    ));
  }

  void _checkCollisions() {
    const birdR = 0.030;

    // Floor and ceiling
    if (birdY - birdR < 0.02 || birdY + birdR > 0.95) {
      _triggerGameOver();
      return;
    }

    // Pipes collision
    const pipeWidth = 0.12;
    for (final pipe in pipes) {
      final inX = (birdX + birdR > pipe.x) && (birdX - birdR < pipe.x + pipeWidth);
      if (inX) {
        final hitTop = (birdY - birdR < pipe.topHeight);
        final hitBottom = (birdY + birdR > pipe.bottomY);
        if (hitTop || hitBottom) {
          _triggerGameOver();
          return;
        }
      }
    }
  }

  void _triggerGameOver() {
    isPlaying = false;
    isGameOver = true;
    _saveHighScore();
    HapticFeedback.heavyImpact();
    SoundService.instance.playCrash();
    SoundService.instance.playGameOver();
    notifyListeners();
  }
}
