import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

/// One snapshot of every reading shown in the app.
///
/// A value is null when there is no reading for it (sensor not sending,
/// device disconnected, or nothing received yet). Null is shown as "--" and
/// never treated as 0.
class VitalsData {
  final int? hr;
  final int? spo2;
  final int? rr;
  final double? temp;
  final double? impedance;
  final bool ecgLeadOff;
  final bool ecgIrregular;

  const VitalsData({
    this.hr,
    this.spo2,
    this.rr,
    this.temp,
    this.impedance,
    this.ecgLeadOff = false,
    this.ecgIrregular = false,
  });

  /// No readings at all.
  static const VitalsData none = VitalsData();

  /// True when at least one number is present.
  bool get hasAny =>
      hr != null ||
      spo2 != null ||
      rr != null ||
      temp != null ||
      impedance != null;

  /// Prototype mapping only: higher impedance -> higher displayed filling.
  /// Replace with the real sensor calibration later.
  double? get bladderPercent {
    final z = impedance;
    if (z == null) return null;
    const minImpedance = 40.0;
    const maxImpedance = 180.0;
    final percentage =
        ((z - minImpedance) / (maxImpedance - minImpedance)) * 100;
    return percentage.clamp(0.0, 100.0).toDouble();
  }
}

/// "--" for a missing whole number.
String showInt(int? v) => v == null ? '--' : '$v';

/// "--" for a missing decimal number.
String showDouble(double? v, int digits) =>
    v == null ? '--' : v.toStringAsFixed(digits);

/// A reading saved for the History page.
class VitalsSample {
  final DateTime time;
  final VitalsData data;
  const VitalsSample(this.time, this.data);
}

/// Single source of truth for live readings.
///
/// Right now it simulates data. When the ESP32 is connected, stop calling
/// [start] and call [update] with the real values instead.
class VitalsStore {
  VitalsStore._();
  static final VitalsStore instance = VitalsStore._();

  final ValueNotifier<VitalsData> vitals = ValueNotifier(VitalsData.none);

  /// Saved readings (about one every 10 seconds, last 24 hours). They live in
  /// memory only: closing the app clears them.
  final List<VitalsSample> samples = [];
  static const Duration sampleEvery = Duration(seconds: 10);
  static const Duration keepFor = Duration(hours: 24);

  /// Saved readings from the last [range].
  List<VitalsSample> samplesWithin(Duration range) {
    final from = DateTime.now().subtract(range);
    return [
      for (final s in samples)
        if (!s.time.isBefore(from)) s,
    ];
  }

  Timer? _timer;
  final Random _random = Random();
  double _impedance = 40;

  bool _started = false;
  bool _external = false;

  /// True while real readings from the ESP32 are used instead of the demo.
  bool get usingDevice => _external;

  void start() {
    _started = true;
    _startSimulationIfNeeded();
  }

  void stop() {
    _started = false;
    _timer?.cancel();
    _timer = null;
    samples.clear();
    vitals.value = VitalsData.none;
  }

  void _startSimulationIfNeeded() {
    if (!_started || _external || _timer != null) return;
    _simulate(); // show numbers right away instead of "--" for 2 seconds
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _simulate());
  }

  /// Real device mode: stop the demo data (the history is kept). The screen
  /// shows "--" until the device sends its first reading.
  void useDevice() {
    _external = true;
    _timer?.cancel();
    _timer = null;
    vitals.value = VitalsData.none;
  }

  /// The device stopped sending: show "--" instead of the last (old) values.
  /// Nothing is added to the history.
  void markNoData() {
    vitals.value = VitalsData.none;
  }

  /// Back to the demo data.
  void useSimulation() {
    _external = false;
    _startSimulationIfNeeded();
  }

  void update(VitalsData data) => _publish(data);

  void _publish(VitalsData data) {
    _record(data);
    vitals.value = data;
  }

  void _record(VitalsData data) {
    if (!data.hasAny) return;
    final now = DateTime.now();
    if (samples.isEmpty || now.difference(samples.last.time) >= sampleEvery) {
      samples.add(VitalsSample(now, data));
    }
    final oldest = now.subtract(keepFor);
    while (samples.isNotEmpty && samples.first.time.isBefore(oldest)) {
      samples.removeAt(0);
    }
  }

  void _simulate() {
    // Demo bladder: fills slowly and "empties" at about 75 %, so the demo
    // does not ring the bladder alarm every half minute.
    _impedance += 0.5 + _random.nextDouble();
    if (_impedance >= 145) {
      _impedance = 40;
    }

    _publish(
      VitalsData(
        hr: 72 + _random.nextInt(15),
        spo2: 96 + _random.nextInt(4),
        rr: 14 + _random.nextInt(6),
        temp: 36.4 + _random.nextDouble() * 0.8,
        impedance: _impedance,
      ),
    );
  }
}
