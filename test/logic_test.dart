// Unit tests for the app's monitoring logic (no Firebase, no UI).

import 'package:flutter_application_1/core/alarm_service.dart';
import 'package:flutter_application_1/core/ews.dart';
import 'package:flutter_application_1/core/settings_store.dart';
import 'package:flutter_application_1/core/vitals_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VitalsData', () {
    test('missing readings are shown as "--", never as 0', () {
      expect(showInt(null), '--');
      expect(showDouble(null, 1), '--');
      expect(showInt(72), '72');
      expect(showDouble(36.66, 1), '36.7');
      expect(VitalsData.none.hasAny, isFalse);
    });

    test('bladder filling maps 40–180 Ω to 0–100 % and clamps', () {
      expect(const VitalsData(impedance: 40).bladderPercent, 0);
      expect(const VitalsData(impedance: 110).bladderPercent, 50);
      expect(const VitalsData(impedance: 180).bladderPercent, 100);
      expect(const VitalsData(impedance: 10).bladderPercent, 0);
      expect(const VitalsData(impedance: 400).bladderPercent, 100);
      expect(const VitalsData().bladderPercent, isNull);
    });
  });

  group('Early warning score', () {
    test('no readings gives NO DATA, not a "low risk" score of 0', () {
      final r = Ews.compute(VitalsData.none);
      expect(r.noData, isTrue);
      expect(r.missing, 4);
      expect(r.label, 'NO DATA');
    });

    test('normal readings score 0 and are low risk', () {
      final r = Ews.compute(
        const VitalsData(hr: 75, spo2: 98, rr: 16, temp: 36.8),
      );
      expect(r.score, 0);
      expect(r.risk, EwsRisk.low);
      expect(r.label, 'LOW RISK');
    });

    test('one very abnormal reading is never low risk', () {
      // SpO₂ 88 % alone is 3 points (total below the medium threshold).
      final r = Ews.compute(
        const VitalsData(hr: 75, spo2: 88, rr: 16, temp: 36.8),
      );
      expect(r.score, 3);
      expect(r.risk, EwsRisk.medium);
    });

    test('several abnormal readings add up to high risk', () {
      final r = Ews.compute(
        const VitalsData(hr: 135, spo2: 90, rr: 26, temp: 39.5),
      );
      expect(r.score, 3 + 3 + 3 + 2);
      expect(r.risk, EwsRisk.high);
    });

    test('a partial score is marked as PARTIAL', () {
      final r = Ews.compute(const VitalsData(hr: 75, spo2: 98));
      expect(r.missing, 2);
      expect(r.label, 'LOW RISK • PARTIAL');
    });
  });

  group('Alarm limits', () {
    test('valid limits are accepted', () {
      expect(AlarmService.checkLimits(AlarmParam.heartRate, 50, 120), isNull);
    });

    test('low must be below high', () {
      expect(
        AlarmService.checkLimits(AlarmParam.heartRate, 120, 120),
        isNotNull,
      );
    });

    test('limits outside the allowed range are refused', () {
      // A high limit of 999 would silently switch the alarm off.
      expect(
        AlarmService.checkLimits(AlarmParam.heartRate, 50, 999),
        isNotNull,
      );
      expect(AlarmService.checkLimits(AlarmParam.spo2, 10, 100), isNotNull);
    });

    test('bladder only checks its high limit', () {
      expect(AlarmService.checkLimits(AlarmParam.bladder, 0, 80), isNull);
    });
  });

  group('Temperature unit', () {
    final settings = SettingsStore.instance;
    tearDown(() => settings.tempUnit = TempUnit.celsius);

    test('values are stored in °C and converted for display', () {
      settings.tempUnit = TempUnit.fahrenheit;
      expect(settings.tempSymbol, '°F');
      expect(settings.toDisplayTemp(37), closeTo(98.6, 1e-9));
      expect(settings.fromDisplayTemp(98.6), closeTo(37, 1e-9));
      expect(AlarmService.formatNumber(AlarmParam.temperature, 37), '98.6');
    });
  });

  group('Alarm evaluation', () {
    final alarms = AlarmService.instance;
    final store = VitalsStore.instance;

    setUp(() {
      alarms.resetLimits();
      alarms.init();
    });
    tearDown(() {
      alarms.stopMonitoring();
      store.update(VitalsData.none);
    });

    test('a reading above the limit starts one alarm and logs it once', () {
      store.update(const VitalsData(hr: 130));
      expect(alarms.levels[AlarmParam.heartRate], AlarmLevel.high);
      expect(alarms.activeCount, 1);

      // Still high on the next reading: no second log entry.
      store.update(const VitalsData(hr: 131));
      expect(alarms.history.length, 1);
      expect(alarms.history.first.param, AlarmParam.heartRate);
    });

    test('an alarm clears only after the value is back by the margin', () {
      store.update(const VitalsData(hr: 125)); // limit 120
      expect(alarms.levels[AlarmParam.heartRate], AlarmLevel.high);

      // 119 is inside the limit but within the 3 BPM margin: stays on.
      store.update(const VitalsData(hr: 119));
      expect(alarms.levels[AlarmParam.heartRate], AlarmLevel.high);

      store.update(const VitalsData(hr: 110));
      expect(alarms.levels[AlarmParam.heartRate], AlarmLevel.normal);
      expect(alarms.activeCount, 0);
    });

    test('a missing reading never raises an alarm', () {
      store.update(const VitalsData(spo2: 98));
      expect(alarms.activeCount, 0);
      expect(alarms.statusLabel(AlarmParam.heartRate), 'NO DATA');
    });

    test('ECG lead-off is an alert', () {
      store.update(const VitalsData(ecgLeadOff: true));
      expect(alarms.levels[AlarmParam.ecg], AlarmLevel.alert);
      expect(alarms.history.first.message, 'ECG leads disconnected');
    });

    test('a disabled alarm stays quiet', () {
      alarms.limits[AlarmParam.heartRate]!.enabled = false;
      store.update(const VitalsData(hr: 200));
      expect(alarms.levels[AlarmParam.heartRate], AlarmLevel.normal);
    });
  });
}
