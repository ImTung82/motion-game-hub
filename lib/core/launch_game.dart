/// Game mở thẳng từ link (bản web), kiểu mỗi mô phỏng PhET có link riêng:
///   https://motion-game-hub-web.web.app/?game=fruits-kick
/// Dùng cho mã nhúng `<iframe>` (xem web/embed.html). Android không có query => luôn null.
enum LaunchGame {
  fruitsKick('fruits-kick', 'penalty_kick', 'FRUITS KICK', '⚽🍎🍌'),
  eggSmasher('egg-smasher', 'egg_smasher', 'EGG SMASHER', '🥚🔨🐣'),
  goalkeeperHero('goalkeeper-hero', 'goalkeeper_hero', 'GOALKEEPER HERO', '🧤⚽🥅');

  /// Tên trên link (`?game=`)
  final String slug;

  /// Tên thư mục trong lib/games (cũng nhận trên link)
  final String folder;
  final String title;
  final String art;

  const LaunchGame(this.slug, this.folder, this.title, this.art);

  /// Game chỉ chơi 2 tay: mở qua hub 2 tay (hub bật chế độ tay + giữ 2 tay trong lúc chơi)
  bool get needsDualHandHub => this == LaunchGame.goalkeeperHero;

  static LaunchGame? fromUrl([Uri? url]) {
    final String? raw;
    try {
      raw = (url ?? Uri.base).queryParameters['game'];
    } catch (_) {
      return null;
    }
    if (raw == null) return null;
    final id = raw.trim().toLowerCase().replaceAll('_', '-');
    for (final game in values) {
      if (game.slug == id || game.folder.replaceAll('_', '-') == id) return game;
    }
    return null;
  }
}
