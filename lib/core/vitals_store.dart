import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

/// One snapshot of every reading shown in the app.
class VitalsData {
  final int hr;
  final int spo2;
  final int rr;
  final double temp;
  final double impedance;
  final bool ecgLeadOff;
  final bool ecgIrregular;

  const VitalsData({
    this.hr = 78,
    this.spo2 = 98,
    this.rr = 16,
    this.temp = 36.7,
    this.impedance = 40,
    this.ecgLeadOff = false,
    this.ecgIrregular = false,
  });

  /// Prototype mapping only: higher impedance -> higher displayed filling.
  /// Replace with the real sensor calibration later.
  double get bladderPercent {
    const minImpedance = 40.0;
    const maxImpedance = 180.0;
    final percentage =
        ((impedance - minImpedance) / (maxImpedance - minImpedance)) * 100;
    return percentage.clamp(0.0, 100.0).toDouble();
  }
}

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

  final ValueNotifier<VitalsData> vitals = ValueNotifier(const VitalsData());

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
  }

  void _startSimulationIfNeeded() {
    if (!_started || _external || _timer != null) return;
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _simulate());
  }

  /// Real device mode: stop the demo data (the history is kept).
  void useDevice() {
    _external = true;
    _timer?.cancel();
    _timer = null;
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
    _impedance += 4 + _random.nextDouble() * 8;
    if (_impedance >= 180) {
      _impedance = 40;
    }

    _publish(VitalsData(
      hr: 72 + _random.nextInt(15),
      spo2: 96 + _random.nextInt(4),
      rr: 14 + _random.nextInt(6),
      temp: 36.4 + _random.nextDouble() * 0.8,
      impedance: _impedance,
    ));
  }
}
