# ARGUS: Patient Monitor

A Flutter app that shows a patient's vital signs live from an ESP32 sensor board, raises alarms when a reading leaves its safe range, and keeps a history you can export as a PDF report.

Without a device configured, the app runs on built-in demo data, so every screen can be tried without hardware.

## Features

- **Live monitor:** heart rate, SpO₂, respiratory rate, temperature and an ECG waveform (12.5 / 25 / 50 mm/s sweep).
- **Alarms:** high/low limits per vital, ECG lead-off and irregular rhythm, device-disconnected alarm. Includes sound, vibration, a 2-minute silence, and background notifications.
- **Early warning score:** a simplified NEWS2-style score built from the four measured vitals (max 12). It is a visual aid, not a clinical tool.
- **Bladder filling:** estimated from bio-impedance (prototype mapping: 40–180 Ω → 0–100 %).
- **History:** trends over 15 min / 1 h / 6 h / 24 h, the alarm log, and a PDF report.
- **Patient profile:** identity, body metrics with BMI, medical record and care team.
- **Accounts:** Firebase email sign-in. Settings and alarm limits are saved per account.
- **Display:** light and dark themes, English and Arabic (RTL). Layouts adapt to phone, tablet and desktop.
- **Background monitoring:** on Android, a foreground service keeps alarms running with the screen off. On iOS, the screen is kept awake instead.

## Getting started

Requirements: Flutter 3.44 or newer, and a Firebase project with Email/Password sign-in enabled.

```bash
flutter pub get
flutterfire configure   # regenerates lib/firebase_options.dart for your Firebase project
flutter run
```

Sign-up accepts `@gmail.com` addresses.

## Connecting the ESP32

1. Flash the board and join it to the same Wi-Fi network as the phone. Its IP address is printed in the Serial Monitor.
2. In the app, open **Settings → Device → Connect**, then enter the IP and port (default `81`).

The app connects to `ws://<ip>:<port>` and expects JSON text messages:

```jsonc
// about once a second; a missing or null field means "no reading"
{"t":"vitals","hr":78,"spo2":98,"rr":16,"temp":36.7,"imp":40.0,"leadOff":false,"irregular":false}

// about 10 times a second
{"t":"ecg","fs":250,"s":[512,520,531]}
```

If no message arrives for 5 seconds, the connection counts as lost. The app then raises the device alarm, clears the stale readings, and retries every 3 seconds. Clearing the address in Settings switches back to demo data.

## Project layout

```
lib/
  core/            app logic: vitals, alarms, device, settings, auth, EWS, PDF report
    widgets/       shared widgets (vital cards, waveform, sparkline, alarm banner)
  features/
    auth/          splash, login, sign-up, logout
    home/          home page and side menu
    monitor/       dashboard, alarms, history, trend charts
    bladder/       bladder filling
    profile/       patient profile
    settings/      settings
test/              unit tests for the monitoring logic
```

## Tests

```bash
flutter test
```

The tests cover missing readings, the bladder mapping, the early warning score, alarm-limit validation, temperature conversion, and alarm start, clear margin and logging.
