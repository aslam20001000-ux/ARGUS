import 'package:flutter/foundation.dart';

/// The last few seconds of raw ECG samples sent by the device.
class EcgBuffer extends ChangeNotifier {
  EcgBuffer._();
  static final EcgBuffer instance = EcgBuffer._();

  /// Samples per second (set by the device in each message).
  int fs = 250;

  static const int seconds = 8;
  final List<double> _samples = [];

  List<double> get samples => _samples;
  bool get hasData => _samples.length > 50;

  void add(List<num> values, {int? sampleRate}) {
    if (sampleRate != null && sampleRate > 0) fs = sampleRate;
    for (final v in values) {
      _samples.add(v.toDouble());
    }
    final max = fs * seconds;
    if (_samples.length > max) {
      _samples.removeRange(0, _samples.length - max);
    }
    notifyListeners();
  }

  void clear() {
    _samples.clear();
    notifyListeners();
  }
}
