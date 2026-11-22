import 'package:flutter/material.dart';

import '../alarm_service.dart';
import '../app_colors.dart';
import '../app_state.dart';

/// Shared building blocks so every page has the same look: page header,
/// cards, card titles, status pills, alarm log rows and empty states.

/// Big page title with an optional subtitle and an action on the end.
class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 0, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 26,
                    height: 1.15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: AppColors.text.withValues(alpha: .55),
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );
  }
}

/// White (light) / navy (dark) rounded card with a thin border and soft
/// shadow.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(20);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: color ?? AppColors.card,
        borderRadius: radius,
        border: Border.all(color: borderColor ?? AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Tinted icon box + title (+ subtitle) used at the top of a card.
class CardTitle extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const CardTitle({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconBox(icon: icon, color: color),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.text.withValues(alpha: .52),
                  ),
                ),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );
  }
}

class IconBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const IconBox({
    super.key,
    required this.icon,
    required this.color,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(size * .3),
      ),
      child: Icon(icon, color: color, size: size * .52),
    );
  }
}

/// Small rounded label, e.g. "NORMAL", "HIGH", "2 alarms".
class StatusPill extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;

  const StatusPill(this.text, {super.key, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: .3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Section heading between cards, with an optional action on the end.
class SectionHeading extends StatelessWidget {
  final String text;
  final Widget? action;

  const SectionHeading(this.text, {super.key, this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 0, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

/// Icon + title + text, for cards that have nothing to show yet.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String text;

  const EmptyState({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .13),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 21),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                text,
                style: TextStyle(
                  color: AppColors.text.withValues(alpha: .55),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------ alarm log

IconData alarmIcon(AlarmParam? p) => switch (p) {
  null => Icons.wifi_off_rounded,
  AlarmParam.heartRate => Icons.favorite_rounded,
  AlarmParam.spo2 => Icons.water_drop_rounded,
  AlarmParam.respRate => Icons.air_rounded,
  AlarmParam.temperature => Icons.thermostat_rounded,
  AlarmParam.ecg => Icons.monitor_heart_rounded,
  AlarmParam.bladder => Icons.opacity_rounded,
};

String _two(int n) => n.toString().padLeft(2, '0');

String clockTime(DateTime t) =>
    '${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}';

String timeAgo(DateTime t) {
  final d = DateTime.now().difference(t);
  final m = d.inMinutes;
  if (m < 1) return tr('just now', 'الآن');
  if (m < 60) return tr('$m min ago', 'منذ $m د');
  if (d.inHours < 24) return tr('${d.inHours} h ago', 'منذ ${d.inHours} س');
  return tr('${d.inDays} d ago', 'منذ ${d.inDays} يوم');
}

/// One entry of the alarm log.
class AlarmEventRow extends StatelessWidget {
  final AlarmEvent event;

  /// Show "12:04:31 • 5 min ago" instead of only "5 min ago".
  final bool showClock;

  const AlarmEventRow(this.event, {super.key, this.showClock = false});

  @override
  Widget build(BuildContext context) {
    final e = event;
    final color = e.level == AlarmLevel.low ? AppColors.amber : AppColors.red;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          IconBox(icon: alarmIcon(e.param), color: color, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  showClock
                      ? '${clockTime(e.time)}  •  ${timeAgo(e.time)}'
                      : timeAgo(e.time),
                  style: TextStyle(
                    color: AppColors.text.withValues(alpha: .5),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            e.valueText,
            style: TextStyle(
              color: color,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// A card listing alarm events with thin dividers (or an empty state).
class AlarmLogCard extends StatelessWidget {
  final List<AlarmEvent> events;
  final bool showClock;
  final String emptyTitle;
  final String emptyText;

  const AlarmLogCard({
    super.key,
    required this.events,
    this.showClock = false,
    required this.emptyTitle,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: EmptyState(
          icon: Icons.verified_rounded,
          color: AppColors.green,
          title: emptyTitle,
          text: emptyText,
        ),
      );
    }
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < events.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: 66,
                endIndent: 16,
                color: AppColors.border,
              ),
            AlarmEventRow(events[i], showClock: showClock),
          ],
        ],
      ),
    );
  }
}
