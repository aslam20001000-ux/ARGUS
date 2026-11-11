import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'ecg_buffer.dart';
import 'notification_service.dart';
import 'settings_store.dart';
import 'vitals_store.dart';

enum DeviceStatus { off, connecting, connected, lost }

/// Connects to the ESP32 over Wi-Fi (WebSocket) and feeds [VitalsStore].
///
/// Messages (JSON text) from the device:
///   {"t":"vitals","hr":78,"spo2":98,"rr":16,"temp":36.7,"imp":40.0,
///    "leadOff":false,"irregular":false}                 about once a second
///   {"t":"ecg","fs":250,"s":[512,520,...]}               about 10 times a second
///
/// With no address saved, the app keeps showing demo data. With an address,
/// demo data is turned off and a lost connection is reported (never faked).
class DeviceService extends ChangeNotifier {
  DeviceService._();
  static final DeviceService instance = DeviceService._();

  static const Duration silenceLimit = Duration(seconds: 5);
  static const Duration retryEvery = Duration(seconds: 3);

  DeviceStatus status = DeviceStatus.off;
  String lastError = '';
  DateTime? lastMessage;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _watchdog;
  Timer? _retry;
  bool _wanted = false;
  bool _notifiedLost = false;
  int _attempt = 0; // ignores callbacks from old connections

  bool get connected => status == DeviceStatus.connected;

  /// True when an address is saved and the app should be using the device.
  bool get wanted => _wanted;

  /// Connects using the address saved in Settings (call after login and
  /// after the address changes). Does nothing if no address is saved.
  Future<void> start() async {
    final host = SettingsStore.instance.deviceHost.trim();
    if (host.isEmpty) {
      await stop();
      return;
    }
    _wanted = true;
    VitalsStore.instance.useDevice();
    await _open();
  }

  /// Disconnects and goes back to the demo data.
  Future<void> stop() async {
    _wanted = false;
    _retry?.cancel();
    _retry = null;
    await _close();
    _setStatus(DeviceStatus.off);
    _notifiedLost = false;
    EcgBuffer.instance.clear();
    VitalsStore.instance.useSimulation();
  }

  Future<void> _open() async {
    await _close();
    final settings = SettingsStore.instance;
    final attempt = ++_attempt;
    _setStatus(DeviceStatus.connecting);

    try {
      final uri = Uri.parse('ws://${settings.deviceHost}:${settings.devicePort}');
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;
      await channel.ready.timeout(const Duration(seconds: 5));
      if (attempt != _attempt) return;

      _sub = channel.stream.listen(
        _onMessage,
        onError: (Object e) {
          if (attempt == _attempt) _lost('$e');
        },
        onDone: () {
          if (attempt == _attempt) _lost('Connection closed');
        },
        cancelOnError: true,
      );
      lastMessage = DateTime.now();
      _setStatus(DeviceStatus.connected);
      _notifiedLost = false;
      _watchdog?.cancel();
      _watchdog = Timer.periodic(const Duration(seconds: 1), (_) {
        final last = lastMessage;
        if (connected && last != null &&
            DateTime.now().difference(last) > silenceLimit) {
          _lost('No data from the device');
        }
      });
    } catch (e) {
      if (attempt == _attempt) _lost('$e');
    }
  }

  Future<void> _close() async {
    _watchdog?.cancel();
    _watchdog = null;
    await _sub?.cancel();
    _sub = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  void _lost(String reason) {
    if (!_wanted) return;
    lastError = reason;
    _close();
    _setStatus(DeviceStatus.lost);
    if (!_notifiedLost) {
      _notifiedLost = true;
      NotificationService.instance.showAlarm(
        'ARGUS: device disconnected',
        'No readings from the ESP32. Trying to reconnect…',
      );
    }
    _retry?.cancel();
    _retry = Timer(retryEvery, () {
      if (_wanted) _open();
    });
  }

  void _onMessage(dynamic raw) {
    lastMessage = DateTime.now();
    try {
      final msg = jsonDecode(raw as String) as Map<String, dynamic>;
      switch (msg['t']) {
        case 'vitals':
          VitalsStore.instance.update(
            VitalsData(
              hr: (msg['hr'] as num?)?.round() ?? 0,
              spo2: (msg['spo2'] as num?)?.round() ?? 0,
              rr: (msg['rr'] as num?)?.round() ?? 0,
              temp: (msg['temp'] as num?)?.toDouble() ?? 0,
              impedance: (msg['imp'] as num?)?.toDouble() ?? 0,
              ecgLeadOff: msg['leadOff'] == true,
              ecgIrregular: msg['irregular'] == true,
            ),
          );
        case 'ecg':
          final list = msg['s'];
          if (list is List) {
            EcgBuffer.instance.add(
              list.whereType<num>().toList(),
              sampleRate: (msg['fs'] as num?)?.round(),
            );
          }
      }
    } catch (_) {
      // Ignore a malformed message; the next one will fix it.
    }
  }

  void _setStatus(DeviceStatus s) {
    status = s;
    SettingsStore.instance.setDeviceConnected(s == DeviceStatus.connected);
    notifyListeners();
  }
}
