import 'dart:math' as math;

/// Khoảng cách giữa 2 kết quả nhận diện mà các hệ số làm mượt cũ được chỉnh theo (Android ~30 lần/giây).
const double kTunedSampleDt = 1.0 / 30.0;

/// Khoảng cách 2 kết quả (giây), chặn trong khoảng hợp lý: lần đầu / sau khi tạm dừng lâu coi như 1 khung chuẩn.
double sampleDt(DateTime? previous, DateTime now) {
  if (previous == null) return kTunedSampleDt;
  final dt = now.difference(previous).inMicroseconds / 1e6;
  if (dt <= 0 || dt > 0.5) return kTunedSampleDt;
  return dt.clamp(1.0 / 120.0, 0.25);
}

/// Đổi hệ số EMA đã chỉnh ở ~30 kết quả/giây sang hệ số đúng cho [dt] thực tế.
///
/// Hệ số cố định mỗi kết quả làm độ trễ tỉ lệ nghịch với tốc độ nhận diện: máy chỉ chạy 12 lần/giây
/// trễ gấp 2,5 lần máy 30 lần/giây. Quy đổi theo thời gian => mọi máy cùng độ trễ, ở 30 lần/giây giữ y như cũ.
double timedAlpha(double alphaAt30Hz, double dt) {
  if (alphaAt30Hz >= 1.0) return 1.0;
  return 1.0 - math.pow(1.0 - alphaAt30Hz, dt / kTunedSampleDt).toDouble();
}

/// Bộ lọc One Euro (Casiez et al., CHI 2012): đứng yên thì lọc mạnh (hết rung), di chuyển nhanh thì gần như
/// không lọc (hết trễ). Chuẩn chung cho điều khiển bằng camera; tính theo thời gian thực nên không phụ thuộc
/// tốc độ nhận diện của máy.
class OneEuroFilter {
  /// [minCutoff] (Hz): độ lọc lúc đứng yên — nhỏ = mượt hơn nhưng trễ hơn.
  /// [beta]: tốc độ (đơn vị/giây) càng lớn thì càng bớt lọc — lớn = bám nhanh hơn.
  OneEuroFilter({required this.minCutoff, required this.beta, this.dCutoff = 1.0});

  /// Lúc đứng yên lọc đúng như EMA cũ [alphaAt30Hz] ở 30 lần/giây (giữ cảm giác đã chỉnh), di chuyển thì bớt trễ.
  factory OneEuroFilter.likeEma(double alphaAt30Hz, {required double beta}) {
    final tau = kTunedSampleDt * (1.0 / alphaAt30Hz - 1.0);
    return OneEuroFilter(minCutoff: 1.0 / (2.0 * math.pi * tau), beta: beta);
  }

  final double minCutoff;
  final double beta;
  final double dCutoff;

  bool _has = false;
  double _x = 0.0;
  double _dx = 0.0;

  bool get hasValue => _has;
  double get value => _x;

  static double _alpha(double cutoff, double dt) {
    final tau = 1.0 / (2.0 * math.pi * cutoff);
    return 1.0 / (1.0 + tau / dt);
  }

  double filter(double raw, double dt) {
    if (!_has) {
      reset(raw);
      return raw;
    }
    final double rawDx = (raw - _x) / dt;
    _dx += (rawDx - _dx) * _alpha(dCutoff, dt);
    final double cutoff = minCutoff + beta * _dx.abs();
    _x += (raw - _x) * _alpha(cutoff, dt);
    return _x;
  }

  /// Đặt thẳng giá trị (VD: sau khi cân bằng); null = quên hẳn, kết quả sau dùng luôn giá trị thô.
  void reset([double? value]) {
    if (value == null) {
      _has = false;
      return;
    }
    _has = true;
    _x = value;
    _dx = 0.0;
  }
}
