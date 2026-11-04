import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SoundService {
  static final SoundService instance = SoundService._internal();

  SoundService._internal() {
    _init();
  }

  bool _isMuted = false;
  double _volume = 0.8;

  // 2 nhóm player TÁCH RIÊNG, mỗi player chỉ dùng 1 chế độ cố định.
  // (Dùng chung 1 nhóm thì player phải đổi qua lại lowLatency <-> mediaPlayer khi phát,
  //  dễ bị mất âm hoặc phát nhầm âm cũ, vd: bấm sút lại nghe tiếng còi.)
  // - _players: hiệu ứng ngắn (.wav) chế độ lowLatency
  // - _mediaPlayers: âm dài / mp3 (đọc từ, còi, reo hò...) chế độ mediaPlayer
  static const int _poolSize = 6;
  static const int _mediaPoolSize = 5;
  final List<AudioPlayer> _players = [];
  final List<AudioPlayer> _mediaPlayers = [];
  int _nextPlayerIndex = 0;
  int _nextMediaIndex = 0;

  // Player RIÊNG, nạp sẵn cho các âm phải phát ngay & luôn nghe được kể cả khi phát cùng lúc với âm khác
  // (tiếng sút, tiếng vỡ trứng). Không dùng chung nhóm -> không bao giờ bị âm khác chiếm hoặc cắt.
  static const List<String> _preloadedFiles = ['kick.wav', 'egg_crack.wav'];
  final Map<String, AudioPlayer> _preloaded = {};

  DateTime _lastChomp = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastClick = DateTime.fromMillisecondsSinceEpoch(0);

  bool get isMuted => _isMuted;
  double get volume => _volume;

  Future<void> _init() async {
    // Cho phép nhiều âm phát CHỒNG lên nhau (vd: còi + đọc từ cùng lúc).
    // Mặc định Android mỗi lần phát sẽ giành audio focus -> âm đang phát trước bị dừng.
    final mixContext = AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build();
    AudioPlayer createPlayer(PlayerMode mode) {
      final player = AudioPlayer();
      player.setReleaseMode(ReleaseMode.stop);
      player.setAudioContext(mixContext).catchError((_) {});
      player.setPlayerMode(mode).catchError((_) {});
      return player;
    }

    for (int i = 0; i < _poolSize; i++) {
      _players.add(createPlayer(PlayerMode.lowLatency));
    }
    for (int i = 0; i < _mediaPoolSize; i++) {
      _mediaPlayers.add(createPlayer(PlayerMode.mediaPlayer));
    }
    for (final file in _preloadedFiles) {
      final player = createPlayer(PlayerMode.lowLatency);
      player.setSource(AssetSource('audio/$file')).catchError((e) => debugPrint('Preload error ($file): $e'));
      _preloaded[file] = player;
    }
    try {
      await AudioPlayer.global.setAudioContext(mixContext);
    } catch (e) {
      debugPrint('SoundService audio context error: $e');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      _isMuted = prefs.getBool('sfx_muted') ?? false;
      _volume = prefs.getDouble('sfx_volume') ?? 0.8;
      _applyVolume();
    } catch (e) {
      debugPrint('SoundService init error: $e');
    }
  }

  void _applyVolume() {
    final effectiveVol = _isMuted ? 0.0 : _volume.clamp(0.0, 1.0);
    for (final p in [..._players, ..._mediaPlayers, ..._preloaded.values]) {
      p.setVolume(effectiveVol).catchError((_) {});
    }
  }

  /// Phát âm đã nạp sẵn trên player riêng: dừng lần phát trước (nếu còn) rồi phát lại ngay từ đầu
  void _playPreloaded(String file) {
    final player = _preloaded[file];
    if (_isMuted || player == null) return;
    player.stop().then((_) => player.resume()).catchError((e) => debugPrint('Sound play error ($file): $e'));
  }

  /// Lấy player rảnh trong nhóm (ưu tiên player không đang phát để không cắt ngang âm khác)
  AudioPlayer _pickPlayer(PlayerMode mode) {
    final pool = mode == PlayerMode.mediaPlayer ? _mediaPlayers : _players;
    final start = mode == PlayerMode.mediaPlayer ? _nextMediaIndex : _nextPlayerIndex;
    int index = start;
    for (int i = 0; i < pool.length; i++) {
      final candidate = (start + i) % pool.length;
      if (pool[candidate].state != PlayerState.playing) {
        index = candidate;
        break;
      }
    }
    if (mode == PlayerMode.mediaPlayer) {
      _nextMediaIndex = (index + 1) % pool.length;
    } else {
      _nextPlayerIndex = (index + 1) % pool.length;
    }
    return pool[index];
  }

  Future<void> setMuted(bool muted) async {
    _isMuted = muted;
    _applyVolume();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('sfx_muted', _isMuted);
    } catch (_) {}
  }

  Future<void> toggleMute() async {
    await setMuted(!_isMuted);
  }

  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    _applyVolume();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('sfx_volume', _volume);
    } catch (_) {}
  }

  Future<void> _playSound(String assetFileName, {double? volumeMultiplier, PlayerMode mode = PlayerMode.lowLatency}) async {
    if (_isMuted || _players.isEmpty) return;

    try {
      final player = _pickPlayer(mode);

      // lowLatency (SoundPool) không báo "phát xong" -> player kẹt ở trạng thái đang phát,
      // phát lại CÙNG file trên player đó sẽ bị plugin bỏ qua (mất âm). Dừng trước để reset.
      if (mode == PlayerMode.lowLatency) await player.stop();

      final double vol = ((volumeMultiplier ?? 1.0) * _volume).clamp(0.0, 1.0);
      await player.setVolume(vol);
      await player.play(AssetSource('audio/$assetFileName'));
    } catch (e) {
      debugPrint('Sound play error ($assetFileName): $e');
    }
  }

  // ==========================================
  // GAME 1: SKY CHOMP
  // ==========================================
  void playChomp() {
    final now = DateTime.now();
    if (now.difference(_lastChomp).inMilliseconds < 60) return;
    _lastChomp = now;
    _playSound('chomp.wav', volumeMultiplier: 0.9);
  }

  void playBomb() {
    _playSound('bomb.wav', volumeMultiplier: 1.0);
  }

  void playCombo() {
    _playSound('combo.wav', volumeMultiplier: 0.85);
  }

  void playGoodResult() {
    _playSound('good_result.mp3', volumeMultiplier: 1.0, mode: PlayerMode.mediaPlayer);
  }

  void playGameOver() {
    _playSound('game_over.wav', volumeMultiplier: 0.8);
  }

  /// Âm thanh kết thúc màn (Egg Smasher & Fruits Penalty). File dài -> phát bằng mediaPlayer để không bị cắt
  void playTada() {
    _playSound('tada.wav', volumeMultiplier: 0.9, mode: PlayerMode.mediaPlayer);
  }

  // ==========================================
  // GAME 2: FLAPPY COPTER
  // ==========================================
  void playFlap() {
    // Tắt âm thanh flap theo yêu cầu người dùng
  }

  void playScore() {
    _playSound('score.wav', volumeMultiplier: 0.85);
  }

  void playCrash() {
    _playSound('crash.wav', volumeMultiplier: 0.95);
  }

  // ==========================================
  // GAME 3: PENALTY KICK
  // ==========================================
  void playWhistle() {
    _playSound('whistle.mp3', volumeMultiplier: 0.55, mode: PlayerMode.mediaPlayer); // nhỏ hơn tiếng đọc từ (1.0) để không lấn át
  }

  void playKick() => _playPreloaded('kick.wav');

  void playGoal() {
    _playSound('crowd_cheer.mp3', volumeMultiplier: 0.95, mode: PlayerMode.mediaPlayer); // tiếng khán giả reo hò (~4.4s)
  }

  void playSave() {
    _playSound('save.wav', volumeMultiplier: 0.9);
  }

  /// Âm thanh trả lời SAI (Egg Smasher & Fruits Penalty): phát ngẫu nhiên 1 trong 2 tiếng
  final math.Random _random = math.Random();
  void playWrongAnswer() {
    final file = _random.nextBool() ? 'decry1.mp3' : 'decry2.mp3';
    _playSound(file, volumeMultiplier: 1.0, mode: PlayerMode.mediaPlayer);
  }

  // ==========================================
  // GOALKEEPER HERO
  // ==========================================
  /// Tiếng khán giả reo hò nhỏ hơn playGoal để không lấn tiếng đọc từ vựng
  void playCrowdCheer() {
    _playSound('crowd_cheer.mp3', volumeMultiplier: 0.5, mode: PlayerMode.mediaPlayer);
  }

  /// Tiếng "tít" mỗi nhịp đếm ngược 3-2-1
  void playCountdownTick() {
    _playSound('score.wav', volumeMultiplier: 0.7);
  }

  // ==========================================
  // GAME 4: EGG SMASHER
  // ==========================================
  void playEggCrack() => _playPreloaded('egg_crack.wav');

  /// Âm thanh trả lời ĐÚNG (Egg Smasher)
  void playCorrect() {
    _playSound('correct.mp3', volumeMultiplier: 1.0, mode: PlayerMode.mediaPlayer);
  }

  void playHatch() {
    _playSound('hatch.wav', volumeMultiplier: 0.95);
  }

  Future<void> playWord(String word) async {
    if (_isMuted || _players.isEmpty) return;

    try {
      final fileName = '${word.toLowerCase().trim()}.mp3';
      final player = _pickPlayer(PlayerMode.mediaPlayer);

      final double vol = _volume.clamp(0.0, 1.0);
      await player.setVolume(vol);
      await player.play(AssetSource('words/$fileName'));
    } catch (e) {
      debugPrint('Word audio play error ($word): $e');
    }
  }

  // ==========================================
  // UI & HUB
  // ==========================================
  void playClick() {
    final now = DateTime.now();
    if (now.difference(_lastClick).inMilliseconds < 50) return;
    _lastClick = now;
    _playSound('click.wav', volumeMultiplier: 0.5);
  }

  void dispose() {
    for (final p in [..._players, ..._mediaPlayers, ..._preloaded.values]) {
      p.dispose().catchError((_) {});
    }
    _players.clear();
    _mediaPlayers.clear();
    _preloaded.clear();
  }
}
