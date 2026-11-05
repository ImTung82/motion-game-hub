import 'package:flutter_test/flutter_test.dart';
import 'package:motion_game_hub/motion/signal_filters.dart';

/// Thời gian (giây) để bộ lọc đi được [fraction] quãng đường tới bước nhảy 0 -> 1, lấy mẫu mỗi [dt]
double timeToReach(double Function(double raw, double dt) step, double dt, double fraction) {
  double t = 0.0;
  while (t < 5.0) {
    t += dt;
    if (step(1.0, dt) >= fraction) return t;
  }
  return double.infinity;
}

void main() {
  test('timedAlpha giữ nguyên hệ số cũ ở 30 lần/giây', () {
    expect(timedAlpha(0.45, kTunedSampleDt), closeTo(0.45, 1e-9));
    expect(timedAlpha(1.0, 0.1), 1.0);
  });

  test('EMA theo thời gian: máy chậm không trễ hơn máy nhanh', () {
    double runEma(double dt) {
      double v = 0.0;
      return timeToReach((raw, d) => v += (raw - v) * timedAlpha(0.45, d), dt, 0.9);
    }

    final fast = runEma(1 / 30);
    final slow = runEma(1 / 12);
    // Chênh nhau tối đa 1 mẫu của máy chậm (do lấy mẫu rời rạc), không phải gấp 2,5 lần như EMA cố định
    expect(slow - fast, lessThan(1 / 12 + 1e-9));
  });

  test('One Euro lúc đứng yên lọc như EMA cũ ở 30 lần/giây', () {
    final f = OneEuroFilter.likeEma(0.45, beta: 0.0);
    f.reset(0.0);
    expect(f.filter(1.0, kTunedSampleDt), closeTo(0.45, 1e-9));
  });

  test('One Euro di chuyển nhanh thì bám sát hơn EMA', () {
    final euro = OneEuroFilter.likeEma(0.45, beta: 5.0);
    euro.reset(0.0);
    double ema = 0.0;
    double raw = 0.0;
    for (int i = 0; i < 10; i++) {
      raw += 0.06; // tay vung ~1,8 khung hình / giây
      euro.filter(raw, kTunedSampleDt);
      ema += (raw - ema) * 0.45;
    }
    expect((raw - euro.value).abs(), lessThan((raw - ema).abs() * 0.6));
  });

  test('One Euro đứng yên thì vẫn lọc rung', () {
    final euro = OneEuroFilter.likeEma(0.45, beta: 5.0);
    euro.reset(0.0);
    double maxAbs = 0.0;
    for (int i = 0; i < 60; i++) {
      final noise = i.isEven ? 0.004 : -0.004; // rung điểm mốc ~0,4% khung hình
      final v = euro.filter(noise, kTunedSampleDt);
      if (v.abs() > maxAbs) maxAbs = v.abs();
    }
    expect(maxAbs, lessThan(0.004));
  });

  test('sampleDt chặn giá trị bất thường', () {
    final t0 = DateTime(2026);
    expect(sampleDt(null, t0), kTunedSampleDt);
    expect(sampleDt(t0, t0.add(const Duration(seconds: 3))), kTunedSampleDt);
    expect(sampleDt(t0, t0.add(const Duration(milliseconds: 80))), closeTo(0.08, 1e-9));
  });
}
