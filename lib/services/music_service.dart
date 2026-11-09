import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'sound_service.dart';

/// Nhạc nền mỗi màn (file trong `assets/audio/music/`, đã cân cùng độ to ~-18 LUFS, mono 96 kbps).
enum MusicTrack {
  hub('play_with_me'),
  penaltyKick('funny_cat'),
  eggSmasher('the_cutest_bunny'),
  goalkeeperHero('cutie_kitty');

  final String file;
  const MusicTrack(this.file);
}

/// Nhạc nền: 1 player riêng phát lặp, tách khỏi các player hiệu ứng của [SoundService].
///
/// - Mỗi màn gọi [push] trong `initState`, [pop] trong `dispose` => thoát game về hub là hub phát lại bài của mình.
/// - Đọc từ => [duck] hạ nhạc thật nhỏ rồi tăng lại dần; màn kết quả => [setQuiet] cho nhạc nhỏ đi.
/// - Tắt tiếng chung theo nút loa của [SoundService]; app chạy nền / ẩn tab => tạm dừng.
/// - Web chặn tự phát khi chưa chạm => lỗi thì chờ lần chạm đầu tiên rồi phát.
class MusicService with WidgetsBindingObserver {
  static final MusicService instance = MusicService._();

  MusicService._();

  // Mức nhạc so với tiếng đọc từ (1.0 x volume chung)
  static const double _baseLevel = 0.3;
  static const double _duckFactor = 0.25; // khi đang đọc từ
  static const double _quietFactor = 0.45; // màn kết quả (tiếng tada / good_result nổi lên)
  static const Duration _duckHold = Duration(milliseconds: 1400); // tiếng đọc từ dài ~1 s
  static const Duration _switchFade = Duration(milliseconds: 450);

  AudioPlayer? _player;
  bool _initialized = false;
  final List<(Object, MusicTrack)> _stack = [];
  MusicTrack? _loaded; // bài đang nạp trong player
  bool _quiet = false;
  bool _ducked = false;
  Timer? _duckTimer;
  bool _inBackground = false;
  bool _waitingForGesture = false;

  // Fade: tăng/giảm âm lượng theo bước 40 ms tới mức đích
  double _current = 0;
  double _target = 0;
  double _fadeStep = 0;
  Timer? _fadeTimer;
  int _switchGen = 0; // đổi bài liên tiếp => bỏ lượt cũ

  void _ensureInit() {
    if (_initialized) return;
    _initialized = true;
    final p = AudioPlayer();
    p.setReleaseMode(ReleaseMode.loop);
    p.setPlayerMode(PlayerMode.mediaPlayer).catchError((_) {});
    p.setAudioContext(AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build()).catchError((_) {});
    p.setVolume(0).catchError((_) {});
    _player = p;
    WidgetsBinding.instance.addObserver(this);
  }

  MusicTrack? get _wanted => _stack.isEmpty ? null : _stack.last.$2;

  /// Màn bắt đầu dùng [track]. Giữ token trả về để [pop] khi màn đóng.
  Object push(MusicTrack track) {
    _ensureInit();
    final token = Object();
    _stack.add((token, track));
    _quiet = false; // màn mới luôn bắt đầu ở mức thường
    _sync();
    return token;
  }

  void pop(Object token) {
    _stack.removeWhere((e) => identical(e.$1, token));
    _quiet = false;
    _sync();
  }

  /// Màn kết quả: nhạc nhỏ đi. Gọi được mỗi khung (không đổi thì bỏ qua).
  void setQuiet(bool quiet) {
    if (quiet == _quiet) return;
    _quiet = quiet;
    _fadeTo(_levelNow(), const Duration(milliseconds: 600));
  }

  /// Đang đọc từ: hạ nhạc ngay, hết [_duckHold] thì tăng lại dần.
  void duck() {
    if (_player == null) return;
    _duckTimer?.cancel();
    _ducked = true;
    _fadeTo(_levelNow(), const Duration(milliseconds: 120));
    _duckTimer = Timer(_duckHold, () {
      _ducked = false;
      _fadeTo(_levelNow(), const Duration(milliseconds: 900));
    });
  }

  /// Nút loa chung đổi trạng thái => nhạc theo.
  void onMuteChanged() => _sync();

  bool get _shouldPlay =>
      _wanted != null && SoundService.instance.settingsLoaded && !SoundService.instance.isMuted && !_inBackground;

  double _levelNow() {
    if (!_shouldPlay) return 0;
    var v = _baseLevel * SoundService.instance.volume;
    if (_quiet) v *= _quietFactor;
    if (_ducked) v *= _duckFactor;
    return v;
  }

  /// Đưa player về đúng trạng thái mong muốn (bài nào, phát hay dừng)
  void _sync() {
    final p = _player;
    if (p == null) return;
    final gen = ++_switchGen;

    if (!_shouldPlay) {
      // Tắt tiếng / chạy nền / không màn nào cần nhạc: nhỏ dần rồi dừng (giữ vị trí để phát tiếp)
      _fadeTo(0, const Duration(milliseconds: 300), onDone: () {
        if (gen == _switchGen) p.pause().catchError((_) {});
      });
      return;
    }

    final wanted = _wanted!;
    if (_loaded == wanted) {
      _resume(gen);
      return;
    }

    // Đổi bài: bài cũ nhỏ dần, nạp bài mới, to dần
    Future<void> load() async {
      if (gen != _switchGen) return;
      try {
        await p.stop();
        if (gen != _switchGen) return;
        await p.setSource(AssetSource('audio/music/${wanted.file}.mp3'));
        _loaded = wanted;
      } catch (e) {
        debugPrint('Music load error (${wanted.file}): $e');
        return;
      }
      _resume(gen);
    }

    if (_loaded == null || _current <= 0.001) {
      load();
    } else {
      _fadeTo(0, _switchFade, onDone: load);
    }
  }

  Future<void> _resume(int gen) async {
    final p = _player;
    if (p == null || gen != _switchGen) return;
    try {
      if (p.state != PlayerState.playing) {
        await p.setVolume(_current);
        await p.resume();
      }
      _fadeTo(_levelNow(), const Duration(milliseconds: 700));
    } catch (e) {
      // Web: trình duyệt chặn phát khi người dùng chưa chạm vào trang => chờ lần chạm đầu
      debugPrint('Music play blocked, waiting for a tap: $e');
      _waitForGesture();
    }
  }

  void _waitForGesture() {
    if (_waitingForGesture) return;
    _waitingForGesture = true;
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
  }

  void _onPointer(PointerEvent event) {
    if (event is! PointerDownEvent) return;
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
    _waitingForGesture = false;
    // Gọi ngay trong sự kiện chạm => trình duyệt cho phép phát
    _player?.resume().catchError((_) {});
    _sync();
  }

  void _fadeTo(double target, Duration duration, {VoidCallback? onDone}) {
    final p = _player;
    if (p == null) return;
    _fadeTimer?.cancel();
    _target = target;
    const tick = Duration(milliseconds: 40);
    final steps = (duration.inMilliseconds / tick.inMilliseconds).ceil().clamp(1, 1000);
    _fadeStep = (_target - _current).abs() / steps;
    if (_fadeStep < 0.0005) {
      _current = _target;
      p.setVolume(_current).catchError((_) {});
      onDone?.call();
      return;
    }
    _fadeTimer = Timer.periodic(tick, (t) {
      if (_current < _target) {
        _current = (_current + _fadeStep).clamp(0.0, _target);
      } else {
        _current = (_current - _fadeStep).clamp(_target, 1.0);
      }
      p.setVolume(_current).catchError((_) {});
      if ((_current - _target).abs() < 0.0005) {
        t.cancel();
        onDone?.call();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final background = state == AppLifecycleState.paused || state == AppLifecycleState.hidden || state == AppLifecycleState.detached;
    if (background == _inBackground) return;
    _inBackground = background;
    if (background) {
      // Ra nền: dừng ngay, không chờ fade (Timer có thể bị treo khi app ẩn)
      _switchGen++;
      _fadeTimer?.cancel();
      _current = 0;
      _player?.setVolume(0).catchError((_) {});
      _player?.pause().catchError((_) {});
    } else {
      _sync();
    }
  }
}
