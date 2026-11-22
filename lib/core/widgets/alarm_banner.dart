import 'package:flutter/material.dart';

import '../alarm_service.dart';
import '../device_service.dart';

/// Red banner shown on top of every page while an alarm is active and has not
/// been silenced.
class AlarmBanner extends StatelessWidget {
  const AlarmBanner({super.key});

  static const _red = Color(0xFFE65F72);

  @override
  Widget build(BuildContext context) {
    final service = AlarmService.instance;

    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final active = service.activeParams;
        if (service.activeCount == 0 || service.silenced) {
          return const SizedBox.shrink();
        }
        final lines = [
          if (service.deviceLost) AlarmService.deviceLostText,
          ...active.map(service.summaryOf),
        ];

        return SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Material(
              color: _red,
              elevation: 8,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ALARM',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            lines.join('\n'),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: service.silence,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.white.withValues(alpha: .16),
                      ),
                      icon: const Icon(Icons.volume_off, size: 18),
                      label: const Text('Silence'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Strip at the bottom of every page while the ESP32 connection is lost.
/// Readings are never invented: the screen shows "--" until the connection
/// comes back (the red alarm banner and sound are handled by AlarmService).
class DeviceLostBanner extends StatelessWidget {
  const DeviceLostBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DeviceService.instance,
      builder: (context, _) {
        final d = DeviceService.instance;
        if (!d.wanted || d.connected) return const SizedBox.shrink();
        final connecting = d.status == DeviceStatus.connecting;
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Material(
              color: const Color(0xFF8A5A00),
              elevation: 6,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.link_off_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        connecting
                            ? 'Connecting to the device…'
                            : 'Device disconnected – readings are not updating. Reconnecting…',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
