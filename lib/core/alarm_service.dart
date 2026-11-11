import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'alarm_sound.dart';
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
  final AlarmParam param;
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
}

/// Watches [VitalsStore], compares every reading with its limits, keeps the
/// current alarm level of each parameter, logs every new alarm and drives the
/// alarm sound and vibration.
class AlarmService extends ChangeNotifier {
  AlarmService._();
  static final AlarmService instance = AlarmService._();

  static const int maxHistory = 50;

  final Map<AlarmParam, AlarmLimit> limits = {
    AlarmParam.heartRate: AlarmLimit(low: 50, high: 120),
    AlarmParam.spo2: AlarmLimit(low: 92, high: 100),
    AlarmParam.respRate: AlarmLimit(low: 10, high: 25),
    AlarmParam.temperature: AlarmLimit(low: 35.5, high: 38.0),
    // ECG has no numeric limits: it alarms on lead-off / irregular rhythm.
    AlarmParam.ecg: AlarmLimit(low: 0, high: 0),
    // Bladder only has a high limit (filling percentage).
    AlarmParam.bladder: AlarmLimit(low: 0, high: 80),
  };

  final Map<AlarmParam, AlarmLevel> levels = {
    for (final p in AlarmParam.values) p: AlarmLevel.normal,
  };

  final List<AlarmEvent> history = [];

  /// True after the user pressed "Silence". It resets when all alarms clear or
  /// when a new alarm starts.
  bool silenced = false;

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
    silenced = false;
    AlarmSound.instance.stop();
    notifyListeners();
  }

  int get activeCount =>
      levels.values.where((l) => l != AlarmLevel.normal).length;

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
  static double valueOf(AlarmParam p, VitalsData v) => _numericValue(p, v);

  static double _numericValue(AlarmParam p, VitalsData v) => switch (p) {
    AlarmParam.heartRate => v.hr.toDouble(),
    AlarmParam.spo2 => v.spo2.toDouble(),
    AlarmParam.respRate => v.rr.toDouble(),
    AlarmParam.temperature => v.temp,
    AlarmParam.ecg => 0,
    AlarmParam.bladder => v.bladderPercent,
  };

  static String formatValue(AlarmParam p, VitalsData v) {
    if (p == AlarmParam.ecg) {
      if (v.ecgLeadOff) return 'Lead off';
      if (v.ecgIrregular) return 'Irregular';
      return 'Normal';
    }
    return '${formatNumber(p, _numericValue(p, v))} ${unitOf(p)}';
  }

  /// Short status text for chips: OFF / NORMAL / LOW / HIGH / ALERT.
  String statusLabel(AlarmParam p) {
    if (!limits[p]!.enabled) return 'OFF';
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

  /// Loads the alarm limits saved on this device (call once at app start).
  Future<void> loadLimits() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final p in AlarmParam.values) {
        final text = prefs.getString('alarm_${p.name}');
        if (text == null) continue;
        final parts = text.split('|');
        if (parts.length != 3) continue;
        final low = double.tryParse(parts[0]);
        final high = double.tryParse(parts[1]);
        if (low == null || high == null) continue;
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
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final p in AlarmParam.values) {
        final l = limits[p]!;
        await prefs.setString(
          'alarm_${p.name}',
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

  /// Mute the sound for the current alarms. A new alarm un-mutes it.
  void silence() {
    silenced = true;
    AlarmSound.instance.stop();
    notifyListeners();
  }

  // ---------- Evaluation ----------

  AlarmLevel _levelFor(AlarmParam p, VitalsData v) {
    final limit = limits[p]!;
    if (!limit.enabled) return AlarmLevel.normal;

    if (p == AlarmParam.ecg) {
      return (v.ecgLeadOff || v.ecgIrregular)
          ? AlarmLevel.alert
          : AlarmLevel.normal;
    }

    final value = _numericValue(p, v);
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

  void _evaluate() {
    final v = VitalsStore.instance.vitals.value;
    var newAlarm = false;

    for (final p in AlarmParam.values) {
      final level = _levelFor(p, v);
      final previous = levels[p] ?? AlarmLevel.normal;
      levels[p] = level;

      // Log only when an alarm starts (or changes level), not on every tick.
      if (level != AlarmLevel.normal && level != previous) {
        newAlarm = true;
        history.insert(
          0,
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
        if (history.length > maxHistory) {
          history.removeRange(maxHistory, history.length);
        }
      }
    }

    if (activeCount == 0) {
      silenced = false;
      AlarmSound.instance.stop();
    } else if (newAlarm) {
      silenced = false;
      AlarmSound.instance.start();
    }

    notifyListeners();
  }
}
