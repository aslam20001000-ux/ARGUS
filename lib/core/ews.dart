import 'vitals_store.dart';

enum EwsRisk { low, medium, high }

/// Points given by one reading.
class EwsPart {
  final String label;
  final String valueText;
  final int points; // 0 – 3
  const EwsPart(this.label, this.valueText, this.points);
}

class EwsResult {
  final int score;
  final EwsRisk risk;
  final List<EwsPart> parts;

  /// How many of the 4 readings were missing (not scored).
  final int missing;
  const EwsResult(this.score, this.risk, this.parts, {this.missing = 0});

  static const int maxScore = 12;

  /// True when none of the readings is available.
  bool get noData => missing == parts.length;

  String get label {
    if (noData) return 'NO DATA';
    final base = switch (risk) {
      EwsRisk.low => 'LOW RISK',
      EwsRisk.medium => 'MEDIUM RISK',
      EwsRisk.high => 'HIGH RISK',
    };
    // A score with missing readings can look better than it really is.
    return missing > 0 ? '$base • PARTIAL' : base;
  }
}

/// A simplified "Early Warning Score" in the style of NEWS2.
///
/// It only uses the 4 readings this device measures (heart rate, breathing
/// rate, SpO₂, temperature), so the maximum is 12 instead of 20. A missing
/// reading is not scored (it is never counted as 0). It is a visual aid, not
/// a clinical decision tool.
class Ews {
  Ews._();

  static int _rrPoints(int rr) => rr <= 8
      ? 3
      : rr <= 11
      ? 1
      : rr <= 20
      ? 0
      : rr <= 24
      ? 2
      : 3;

  static int _spPoints(int sp) => sp <= 91
      ? 3
      : sp <= 93
      ? 2
      : sp <= 95
      ? 1
      : 0;

  static int _tempPoints(double t) => t <= 35.0
      ? 3
      : t <= 36.0
      ? 1
      : t <= 38.0
      ? 0
      : t <= 39.0
      ? 1
      : 2;

  static int _hrPoints(int hr) => hr <= 40
      ? 3
      : hr <= 50
      ? 1
      : hr <= 90
      ? 0
      : hr <= 110
      ? 1
      : hr <= 130
      ? 2
      : 3;

  static EwsResult compute(VitalsData v) {
    final hr = v.hr;
    final sp = v.spo2;
    final rr = v.rr;
    final t = v.temp;

    final parts = [
      EwsPart('HR', hr == null ? '--' : '$hr', hr == null ? 0 : _hrPoints(hr)),
      EwsPart(
        'SpO₂',
        sp == null ? '--' : '$sp%',
        sp == null ? 0 : _spPoints(sp),
      ),
      EwsPart('RR', rr == null ? '--' : '$rr', rr == null ? 0 : _rrPoints(rr)),
      EwsPart(
        'Temp',
        t == null ? '--' : t.toStringAsFixed(1),
        t == null ? 0 : _tempPoints(t),
      ),
    ];
    final missing = [hr, sp, rr, t].where((x) => x == null).length;
    final score = parts.fold<int>(0, (sum, p) => sum + p.points);

    var risk = score >= 7
        ? EwsRisk.high
        : score >= 5
        ? EwsRisk.medium
        : EwsRisk.low;
    // A single very abnormal reading is never "low risk".
    if (risk == EwsRisk.low && parts.any((p) => p.points == 3)) {
      risk = EwsRisk.medium;
    }
    return EwsResult(score, risk, parts, missing: missing);
  }
}
