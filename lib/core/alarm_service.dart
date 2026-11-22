import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'alarm_sound.dart';
import 'auth_service.dart';
import 'notification_service.dart';
import 'settings_store.dart';
import 'vitals_store.dart';

enum AlarmParam { heartRate, spo2, respRate, temperature, ecg, bladder }

enum AlarmLevel { normal, low, high, alert }

class AlarmLimit {
  double low;
  double high;
  bool enabled;

  AlarmLimit({required this.low, required this.high, this.enabled = true});
}

class AlarmEvent {
  /// The reading that alarmed, or null for the device-connection alarm.
  final AlarmParam? param;
  final AlarmLevel level;
  final String message;
  final String valueText;
  final DateTime time;

  const AlarmEvent({
    required this.param,
    required this.level,
    required this.message,
    required this.valueText,
    required this.time,
  });

  /// True for "the ESP32 connection was lost".
  bool get isDevice => param == null;

  /// "Heart Rate", "SpO₂", … or "Device".
  String get label => param == null ? 'Device' : AlarmService.labelOf(param!);
}

/// Watches [VitalsStore], compares every reading with its limits, keeps the
/// current alarm level of each parameter, logs every new alarm and drives the
/// alarm sound and vibration.
class AlarmService extends ChangeNotifier {
  AlarmService._();
  static final AlarmService instance = AlarmService._();

  static const int maxHistory = 50;

  /// How long "Silence" mutes the sound before it rings again (if the alarm
  /// is still active), like a bedside monitor.
  static const Duration silenceFor = Duration(minutes: 2);

  /// Default limits (low, high). Temperature in °C.
  static const Map<AlarmParam, (double, double)> defaultLimits = {
    AlarmParam.heartRate: (50.0, 120.0),
    AlarmParam.spo2: (92.0, 100.0),
    AlarmParam.respRate: (10.0, 25.0),
    AlarmParam.temperature: (35.5, 38.0),
    // ECG has no numeric limits: it alarms on lead-off / irregular rhythm.
    AlarmParam.ecg: (0.0, 0.0),
    // Bladder only has a high limit (filling percentage).
    AlarmParam.bladder: (0.0, 80.0),
  };

  /// Values a limit may be set to (min, max). Outside these an alarm would be
  /// silently switched off (e.g. heart rate high = 999), so they are refused.
  /// Temperature in °C.
  static const Map<AlarmParam, (double, double)> allowedRange = {
    AlarmParam.heartRate: (20.0, 250.0),
    AlarmParam.spo2: (50.0, 100.0),
    AlarmParam.respRate: (3.0, 60.0),
    AlarmParam.temperature: (30.0, 43.0),
    AlarmParam.bladder: (10.0, 100.0),
  };

  /// Once an alarm is on, the reading must come back inside the limits by
  /// this much before the alarm clears. Stops a value hovering at the limit
  /// (119 / 121 / 119 ...) from starting a new alarm every second.
  static const Map<AlarmParam, double> clearMargin = {
    AlarmParam.heartRate: 3.0,
    AlarmParam.spo2: 1.0,
    AlarmParam.respRate: 1.0,
    AlarmParam.temperature: 0.2,
    AlarmParam.bladder: 3.0,
  };

  final Map<AlarmParam, AlarmLimit> limits = {
    for (final e in defaultLimits.entries)
      e.key: AlarmLimit(low: e.value.$1, high: e.value.$2),
  };

  /// Error text if [low]–[high] is not allowed for [p], otherwise null.
  /// Values in internal units (°C for temperature).
  static String? checkLimits(AlarmParam p, double low, double high) {
    final range = allowedRange[p];
    if (range == null) return null;
    final (min, max) = range;
    String f(double v) => formatNumber(p, v);
    final unit = unitOf(p);
    if (p != AlarmParam.bladder && (low < min || low > max)) {
      return 'Low limit must be between ${f(min)} and ${f(max)} $unit';
    }
    if (high < min || high > max) {
      return 'High limit must be between ${f(min)} and ${f(max)} $unit';
    }
    if (low >= high) return 'Low limit must be below high limit';
    return null;
  }

  final Map<AlarmParam, AlarmLevel> levels = {
    for (final p in AlarmParam.values) p: AlarmLevel.normal,
  };

  final List<AlarmEvent> history = [];

  /// True after the user pressed "Silence". It resets when all alarms clear or
  /// when a new alarm starts.
  bool silenced = false;
  Timer? _silenceTimer;

  /// True while the ESP32 connection is lost (set by DeviceService).
  bool deviceLost = false;

  bool _started = false;

  /// Start watching the readings (call after login).
  void init() {
    if (_started) return;
    _started = true;
    VitalsStore.instance.vitals.addListener(_evaluate);
    _evaluate();
  }

  /// Stop watching, clear active alarms and stop the sound (call on logout).
  void stopMonitoring() {
    if (_started) {
      VitalsStore.instance.vitals.removeListener(_evaluate);
      _started = false;
    }
    for (final p in AlarmParam.values) {
      levels[p] = AlarmLevel.normal;
    }
    deviceLost = false;
    _clearSilence();
    // The next person to log in must not see this account's alarms.
    history.clear();
    AlarmSound.instance.stop();
    notifyListeners();
  }

  /// Number of active alarms, the device-lost alarm included.
  int get activeCount =>
      levels.values.where((l) => l != AlarmLevel.normal).length +
      (deviceLost ? 1 : 0);

  /// Text for the device-lost alarm.
  static const String deviceLostText = 'Device disconnected • no readings';

  /// Called by DeviceService when the connection is lost / comes back.
  void setDeviceLost(bool lost) {
    if (deviceLost == lost) return;
    deviceLost = lost;
    if (lost) {
      _log(
        AlarmEvent(
          param: null,
          level: AlarmLevel.alert,
          message: 'Device disconnected',
          valueText: 'No readings',
          time: DateTime.now(),
        ),
      );
    }
    _updateSound(newAlarm: lost);
    notifyListeners();
  }

  List<AlarmParam> get activeParams => [
    for (final p in AlarmParam.values)
      if (levels[p] != AlarmLevel.normal) p,
  ];

  // ---------- Labels / formatting ----------

  static String labelOf(AlarmParam p) => switch (p) {
    AlarmParam.heartRate => 'Heart Rate',
    AlarmParam.spo2 => 'SpO₂',
    AlarmParam.respRate => 'Resp. Rate',
    AlarmParam.temperature => 'Temperature',
    AlarmParam.ecg => 'ECG',
    AlarmParam.bladder => 'Bladder',
  };

  static String unitOf(AlarmParam p) => switch (p) {
    AlarmParam.heartRate => 'BPM',
    AlarmParam.spo2 => '%',
    AlarmParam.respRate => 'RPM',
    AlarmParam.temperature => SettingsStore.instance.tempSymbol,
    AlarmParam.ecg => '',
    AlarmParam.bladder => '%',
  };

  /// Formats a value or limit for display. Temperatures are stored in °C and
  /// converted to the unit chosen in Settings.
  static String formatNumber(AlarmParam p, double x) {
    if (p == AlarmParam.temperature) {
      return SettingsStore.instance.toDisplayTemp(x).toStringAsFixed(1);
    }
    return x.toStringAsFixed(0);
  }

  /// Numeric reading of a parameter (°C for temperature).
  /// null when there is no reading for it.
  static double? valueOf(AlarmParam p, VitalsData v) => _numericValue(p, v);

  static double? _numericValue(AlarmParam p, VitalsData v) => switch (p) {
    AlarmParam.heartRate => v.hr?.toDouble(),
    AlarmParam.spo2 => v.spo2?.toDouble(),
    AlarmParam.respRate => v.rr?.toDouble(),
    AlarmParam.temperature => v.temp,
    AlarmParam.ecg => 0.0,
    AlarmParam.bladder => v.bladderPercent,
  };

  static String formatValue(AlarmParam p, VitalsData v) {
    if (p == AlarmParam.ecg) {
      if (v.ecgLeadOff) return 'Lead off';
      if (v.ecgIrregular) return 'Irregular';
      return 'Normal';
    }
    final value = _numericValue(p, v);
    if (value == null) return '-- ${unitOf(p)}';
    return '${formatNumber(p, value)} ${unitOf(p)}';
  }

  /// Short status text for chips: OFF / NORMAL / LOW / HIGH / ALERT.
  String statusLabel(AlarmParam p) {
    if (!limits[p]!.enabled) return 'OFF';
    if (p != AlarmParam.ecg &&
        _numericValue(p, VitalsStore.instance.vitals.value) == null) {
      return 'NO DATA';
    }
    return switch (levels[p] ?? AlarmLevel.normal) {
      AlarmLevel.normal => 'NORMAL',
      AlarmLevel.low => 'LOW',
      AlarmLevel.high => 'HIGH',
      AlarmLevel.alert => 'ALERT',
    };
  }

  /// One line describing a currently active alarm, e.g. "Heart Rate HIGH • 130 BPM".
  String summaryOf(AlarmParam p) {
    final v = VitalsStore.instance.vitals.value;
    return '${labelOf(p)} ${statusLabel(p)} • ${formatValue(p, v)}';
  }

  // ---------- Editing / actions ----------

  void setLimits(AlarmParam p, double low, double high) {
    limits[p]!
      ..low = low
      ..high = high;
    _saveLimits();
    _evaluate();
  }

  void setEnabled(AlarmParam p, bool enabled) {
    limits[p]!.enabled = enabled;
    _saveLimits();
    _evaluate();
  }

  /// Saved limits are kept separately for each account.
  static String _key(AlarmParam p) => 'alarm_${AuthService.uid}_${p.name}';

  /// Back to the default limits (used on logout and before loading).
  void resetLimits() {
    for (final e in defaultLimits.entries) {
      limits[e.key]!
        ..low = e.value.$1
        ..high = e.value.$2
        ..enabled = true;
    }
  }

  /// Loads the signed-in account's alarm limits (call when a session starts).
  Future<void> loadLimits() async {
    resetLimits();
    if (AuthService.uid.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final p in AlarmParam.values) {
        final text = prefs.getString(_key(p));
        if (text == null) continue;
        final parts = text.split('|');
        if (parts.length != 3) continue;
        final low = double.tryParse(parts[0]);
        final high = double.tryParse(parts[1]);
        if (low == null || high == null) continue;
        // Ignore a saved value that is outside the allowed range.
        if (checkLimits(p, low, high) != null) continue;
        limits[p]!
          ..low = low
          ..high = high
          ..enabled = parts[2] == '1';
      }
    } catch (_) {
      // Keep the default limits.
    }
  }

  Future<void> _saveLimits() async {
    if (AuthService.uid.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final p in AlarmParam.values) {
        final l = limits[p]!;
        await prefs.setString(
          _key(p),
          '${l.low}|${l.high}|${l.enabled ? 1 : 0}',
        );
      }
    } catch (_) {
      // Saving is best-effort.
    }
  }

  void clearHistory() {
    history.clear();
    notifyListeners();
  }

  /// Mute the sound for [silenceFor]. A new alarm un-mutes it at once; if
  /// the alarm is still active when the time is up, it rings again.
  void silence() {
    silenced = true;
    AlarmSound.instance.stop();
    _silenceTimer?.cancel();
    _silenceTimer = Timer(silenceFor, () {
      _silenceTimer = null;
      silenced = false;
      if (activeCount > 0) AlarmSound.instance.start();
      notifyListeners();
    });
    notifyListeners();
  }

  void _clearSilence() {
    silenced = false;
    _silenceTimer?.cancel();
    _silenceTimer = null;
  }

  void _updateSound({required bool newAlarm}) {
    if (activeCount == 0) {
      _clearSilence();
      AlarmSound.instance.stop();
    } else if (newAlarm) {
      _clearSilence();
      AlarmSound.instance.start();
    }
  }

  // ---------- Evaluation ----------

  AlarmLevel _levelFor(AlarmParam p, VitalsData v, AlarmLevel previous) {
    final limit = limits[p]!;
    if (!limit.enabled) return AlarmLevel.normal;

    if (p == AlarmParam.ecg) {
      return (v.ecgLeadOff || v.ecgIrregular)
          ? AlarmLevel.alert
          : AlarmLevel.normal;
    }

    // No reading: nothing to compare (shown as "NO DATA"). A lost device
    // has its own alarm.
    final value = _numericValue(p, v);
    if (value == null) return AlarmLevel.normal;

    // Already alarming: stay on until the value is back inside by a margin.
    final margin = clearMargin[p] ?? 0;
    if (previous == AlarmLevel.low && value < limit.low + margin) {
      return AlarmLevel.low;
    }
    if (previous == AlarmLevel.high && value > limit.high - margin) {
      return AlarmLevel.high;
    }

    if (value < limit.low) return AlarmLevel.low;
    if (value > limit.high) return AlarmLevel.high;
    return AlarmLevel.normal;
  }

  String _messageFor(AlarmParam p, AlarmLevel level, VitalsData v) {
    if (p == AlarmParam.ecg) {
      return v.ecgLeadOff ? 'ECG leads disconnected' : 'Irregular ECG rhythm';
    }
    if (p == AlarmParam.bladder) return 'Bladder filling above limit';
    final direction = level == AlarmLevel.low ? 'below' : 'above';
    return '${labelOf(p)} $direction limit';
  }

  /// Adds [e] to the top of the alarm log (newest first, at most [maxHistory]).
  void _log(AlarmEvent e) {
    history.insert(0, e);
    if (history.length > maxHistory) {
      history.removeRange(maxHistory, history.length);
    }
  }

  void _evaluate() {
    final v = VitalsStore.instance.vitals.value;
    var newAlarm = false;

    for (final p in AlarmParam.values) {
      final previous = levels[p] ?? AlarmLevel.normal;
      final level = _levelFor(p, v, previous);
      levels[p] = level;

      // Log only when an alarm starts (or changes level), not on every tick.
      if (level != AlarmLevel.normal && level != previous) {
        newAlarm = true;
        _log(
          AlarmEvent(
            param: p,
            level: level,
            message: _messageFor(p, level, v),
            valueText: formatValue(p, v),
            time: DateTime.now(),
          ),
        );
        NotificationService.instance.showAlarm(
          'ARGUS alarm: ${labelOf(p)}',
          '${_messageFor(p, level, v)} • ${formatValue(p, v)}',
        );
      }
    }

    _updateSound(newAlarm: newAlarm);
    notifyListeners();
  }
}
