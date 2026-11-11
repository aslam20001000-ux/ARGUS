import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'settings_store.dart';

/// Plays the looping alarm beep and vibrates while an alarm is active.
/// Follows the sound / volume / vibration choices in [SettingsStore].
class AlarmSound {
  AlarmSound._() {
    SettingsStore.instance.addListener(_onSettingsChanged);
  }
  static final AlarmSound instance = AlarmSound._();

  AudioPlayer? _player;

  bool _alarmActive = false; // an alarm is currently ringing
  bool _previewing = false; // the "Test sound" button was pressed
  bool _audioOn = false; // the player is really playing
  Timer? _vibrationTimer;
  Timer? _previewTimer;

  Future<void> start() async {
    if (_alarmActive) return;
    _alarmActive = true;
    _syncVibration();
    await _syncAudio();
  }

  Future<void> stop() async {
    if (!_alarmActive) return;
    _alarmActive = false;
    _syncVibration();
    await _syncAudio();
  }

  /// Plays the alarm for about 1.5 seconds so the user can hear the volume.
  Future<void> preview() async {
    if (_alarmActive) return;
    _previewing = true;
    await _syncAudio();
    _previewTimer?.cancel();
    _previewTimer = Timer(const Duration(milliseconds: 1500), () {
      _previewing = false;
      _syncAudio();
    });
  }

  void _onSettingsChanged() {
    if (!_alarmActive && !_previewing) return;
    _syncVibration();
    _syncAudio();
  }

  void _syncVibration() {
    final want = _alarmActive && SettingsStore.instance.vibrationEnabled;
    if (want && _vibrationTimer == null) {
      HapticFeedback.vibrate();
      _vibrationTimer = Timer.periodic(
        const Duration(seconds: 2),
        (_) => HapticFeedback.vibrate(),
      );
    } else if (!want) {
      _vibrationTimer?.cancel();
      _vibrationTimer = null;
    }
  }

  Future<void> _syncAudio() async {
    final settings = SettingsStore.instance;
    final want =
        (_alarmActive || _previewing) &&
        settings.soundEnabled &&
        settings.volume > 0;

    try {
      final player = _player ??= AudioPlayer();

      if (want) {
        await player.setVolume(settings.volume);
        if (!_audioOn) {
          _audioOn = true;
          await player.setReleaseMode(ReleaseMode.loop);
          await player.play(AssetSource('sounds/alarm.wav'));

          // The alarm may have been stopped while the sound was loading.
          if (!_audioOn) await player.stop();
        }
      } else if (_audioOn) {
        _audioOn = false;
        await player.stop();
      }
    } catch (e) {
      debugPrint('Alarm sound failed: $e');
      _audioOn = false;
      if (want) SystemSound.play(SystemSoundType.alert);
    }
  }
}
