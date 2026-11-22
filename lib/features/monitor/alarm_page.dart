import 'package:flutter/material.dart';

import '../../core/responsive.dart';

import '../../core/alarm_service.dart';
import '../../core/settings_store.dart';
import '../../core/vitals_store.dart';
import '../../core/app_colors.dart';

Color get _green => AppColors.green;
Color get _red => AppColors.red;
Color get _blue => AppColors.blue;
Color get _card => AppColors.card;

IconData _iconOf(AlarmParam p) => switch (p) {
  AlarmParam.heartRate => Icons.favorite,
  AlarmParam.spo2 => Icons.air,
  AlarmParam.respRate => Icons.waves,
  AlarmParam.temperature => Icons.thermostat,
  AlarmParam.ecg => Icons.monitor_heart,
  AlarmParam.bladder => Icons.water_drop,
};

String _two(int n) => n.toString().padLeft(2, '0');

String _time(DateTime t) =>
    '${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}';

class AlarmPage extends StatelessWidget {
  /// Hide the big "Alarms" title when the page is opened from Settings (the
  /// app bar already shows a title there).
  final bool showHeader;

  const AlarmPage({super.key, this.showHeader = true});

  @override
  Widget build(BuildContext context) {
    final service = AlarmService.instance;

    return ListenableBuilder(
      listenable: Listenable.merge([service, SettingsStore.instance]),
      builder: (context, _) {
        final v = VitalsStore.instance.vitals.value;

        return ContentFrame(
          maxWidth: 1000,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showHeader) ...[
                  const Text(
                    'Alarms',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Live status and limits for every monitored signal',
                    style: TextStyle(
                      color: AppColors.text.withValues(alpha: .54),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                _statusBanner(service),

                const SizedBox(height: 24),
                const Text(
                  'Alarm Limits',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                // 1 column on phones, 2 columns on wide screens.
                AdaptiveGrid(
                  minTileWidth: 420,
                  maxColumns: 2,
                  children: [
                    for (final p in AlarmParam.values)
                      _paramCard(context, service, p, v),
                  ],
                ),

                const SizedBox(height: 12),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Alarm History',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (service.history.isNotEmpty)
                      TextButton(
                        onPressed: service.clearHistory,
                        child: const Text('Clear'),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                if (service.history.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: _card,
                      boxShadow: AppColors.cardShadow,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.history,
                          color: AppColors.text.withValues(alpha: .54),
                          size: 28,
                        ),
                        SizedBox(width: 14),
                        Text(
                          'No previous alarms',
                          style: TextStyle(
                            color: AppColors.text.withValues(alpha: .54),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  for (final e in service.history) _historyTile(e),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _statusBanner(AlarmService service) {
    final active = service.activeParams;
    final count = service.activeCount; // includes "device disconnected"
    final ok = count == 0;
    final color = ok ? _green : _red;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: .35)),
      ),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.warning_amber_rounded,
            color: color,
            size: 30,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ok
                      ? 'System Normal'
                      : '$count active alarm${count == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ok
                      ? 'No active alarms'
                      : [
                          if (service.deviceLost) 'Device disconnected',
                          ...active.map(AlarmService.labelOf),
                        ].join('  •  '),
                  style: TextStyle(
                    color: AppColors.text.withValues(alpha: .6),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (!ok) ...[
            const SizedBox(width: 8),
            service.silenced
                ? const Chip(
                    avatar: Icon(Icons.volume_off, size: 16),
                    label: Text('Silenced'),
                  )
                : TextButton.icon(
                    onPressed: service.silence,
                    style: TextButton.styleFrom(foregroundColor: _red),
                    icon: const Icon(Icons.volume_off, size: 18),
                    label: const Text('Silence'),
                  ),
          ],
        ],
      ),
    );
  }

  String _limitText(AlarmParam p, AlarmLimit limit) {
    if (p == AlarmParam.ecg) return 'Lead connection & rhythm';
    final unit = AlarmService.unitOf(p);
    final high = AlarmService.formatNumber(p, limit.high);
    if (p == AlarmParam.bladder) return 'High limit: $high $unit';
    final low = AlarmService.formatNumber(p, limit.low);
    return 'Limits: $low – $high $unit';
  }

  Widget _paramCard(
    BuildContext context,
    AlarmService service,
    AlarmParam p,
    VitalsData v,
  ) {
    final limit = service.limits[p]!;
    final level = service.levels[p]!;
    final enabled = limit.enabled;
    final active = enabled && level != AlarmLevel.normal;
    final accent = !enabled
        ? AppColors.text.withValues(alpha: .38)
        : active
        ? _red
        : _green;

    final chipText = service.statusLabel(p);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        boxShadow: AppColors.cardShadow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: active
              ? _red.withValues(alpha: .45)
              : AppColors.text.withValues(alpha: .06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_iconOf(p), color: accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AlarmService.labelOf(p),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _limitText(p, limit),
                      style: TextStyle(
                        color: AppColors.text.withValues(alpha: .54),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: enabled,
                onChanged: (value) => service.setEnabled(p, value),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                AlarmService.formatValue(p, v),
                style: TextStyle(
                  fontSize: p == AlarmParam.ecg ? 22 : 26,
                  fontWeight: FontWeight.bold,
                  color: enabled
                      ? AppColors.text
                      : AppColors.text.withValues(alpha: .38),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  chipText,
                  style: TextStyle(
                    color: accent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (p != AlarmParam.ecg) ...[
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Edit limits',
                  onPressed: () => _editLimits(context, service, p),
                  icon: const Icon(Icons.tune),
                  color: _blue,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _editLimits(
    BuildContext context,
    AlarmService service,
    AlarmParam p,
  ) async {
    final limit = service.limits[p]!;
    final result = await showDialog<({double low, double high})>(
      context: context,
      builder: (_) => _LimitsDialog(param: p, low: limit.low, high: limit.high),
    );
    if (result != null) {
      service.setLimits(p, result.low, result.high);
    }
  }

  Widget _historyTile(AlarmEvent e) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _card,
          boxShadow: AppColors.cardShadow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(_iconOf(e.param), color: _red, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.message,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    e.valueText,
                    style: TextStyle(
                      color: AppColors.text.withValues(alpha: .54),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              _time(e.time),
              style: TextStyle(
                color: AppColors.text.withValues(alpha: .38),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LimitsDialog extends StatefulWidget {
  final AlarmParam param;
  final double low;
  final double high;

  const _LimitsDialog({
    required this.param,
    required this.low,
    required this.high,
  });

  @override
  State<_LimitsDialog> createState() => _LimitsDialogState();
}

class _LimitsDialogState extends State<_LimitsDialog> {
  late final TextEditingController _lowController;
  late final TextEditingController _highController;
  String? _error;

  bool get _onlyHigh => widget.param == AlarmParam.bladder;

  @override
  void initState() {
    super.initState();
    _lowController = TextEditingController(
      text: AlarmService.formatNumber(widget.param, widget.low),
    );
    _highController = TextEditingController(
      text: AlarmService.formatNumber(widget.param, widget.high),
    );
  }

  @override
  void dispose() {
    _lowController.dispose();
    _highController.dispose();
    super.dispose();
  }

  double? _parse(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  void _save() {
    final shownLow = _onlyHigh ? widget.low : _parse(_lowController);
    final shownHigh = _parse(_highController);

    if (shownLow == null || shownHigh == null) {
      setState(() => _error = 'Enter valid numbers');
      return;
    }

    // Temperature is typed in the unit chosen in Settings but stored in °C.
    var low = shownLow;
    var high = shownHigh;
    if (widget.param == AlarmParam.temperature) {
      low = SettingsStore.instance.fromDisplayTemp(shownLow);
      high = SettingsStore.instance.fromDisplayTemp(shownHigh);
    }
    // Refuse limits that would silently switch the alarm off.
    final problem = AlarmService.checkLimits(widget.param, low, high);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    Navigator.pop(context, (low: low, high: high));
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: AppColors.bg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.text.withValues(alpha: .07)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.text.withValues(alpha: .07)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _blue, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unit = AlarmService.unitOf(widget.param);
    const keyboard = TextInputType.numberWithOptions(decimal: true);

    return AlertDialog(
      backgroundColor: _card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        '${AlarmService.labelOf(widget.param)} limits',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_onlyHigh) ...[
            TextField(
              controller: _lowController,
              keyboardType: keyboard,
              decoration: _decoration('Low limit ($unit)'),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _highController,
            keyboardType: keyboard,
            decoration: _decoration('High limit ($unit)'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(_error!, style: TextStyle(color: _red, fontSize: 12)),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
