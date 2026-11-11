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
  const EwsResult(this.score, this.risk, this.parts);

  static const int maxScore = 12;

  String get label => switch (risk) {
    EwsRisk.low => 'LOW RISK',
    EwsRisk.medium => 'MEDIUM RISK',
    EwsRisk.high => 'HIGH RISK',
  };
}

/// A simplified "Early Warning Score" in the style of NEWS2.
///
/// It only uses the 4 readings this device measures (heart rate, breathing
/// rate, SpO₂, temperature), so the maximum is 12 instead of 20. It is a
/// visual aid, not a clinical decision tool.
class Ews {
  Ews._();

  static EwsResult compute(VitalsData v) {
    final rr = v.rr;
    final rrPts = rr <= 8
        ? 3
        : rr <= 11
        ? 1
        : rr <= 20
        ? 0
        : rr <= 24
        ? 2
        : 3;

    final sp = v.spo2;
    final spPts = sp <= 91
        ? 3
        : sp <= 93
        ? 2
        : sp <= 95
        ? 1
        : 0;

    final t = v.temp;
    final tPts = t <= 35.0
        ? 3
        : t <= 36.0
        ? 1
        : t <= 38.0
        ? 0
        : t <= 39.0
        ? 1
        : 2;

    final hr = v.hr;
    final hrPts = hr <= 40
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

    final parts = [
      EwsPart('HR', '$hr', hrPts),
      EwsPart('SpO₂', '$sp%', spPts),
      EwsPart('RR', '$rr', rrPts),
      EwsPart('Temp', t.toStringAsFixed(1), tPts),
    ];
    final score = hrPts + spPts + rrPts + tPts;

    var risk = score >= 7
        ? EwsRisk.high
        : score >= 5
        ? EwsRisk.medium
        : EwsRisk.low;
    // A single very abnormal reading is never "low risk".
    if (risk == EwsRisk.low && parts.any((p) => p.points == 3)) {
      risk = EwsRisk.medium;
    }
    return EwsResult(score, risk, parts);
  }
}
