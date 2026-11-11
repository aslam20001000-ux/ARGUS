import 'package:flutter/material.dart';

/// Phone < 600 px, tablet 600-1000 px, desktop / big browser window >= 1000 px.
enum ScreenSize { phone, tablet, desktop }

class Responsive {
  Responsive._();

  static ScreenSize of(double width) {
    if (width < 600) return ScreenSize.phone;
    if (width < 1000) return ScreenSize.tablet;
    return ScreenSize.desktop;
  }

  static ScreenSize sizeOf(BuildContext context) =>
      of(MediaQuery.sizeOf(context).width);
}

/// Centers its child and stops it from growing wider than [maxWidth]
/// (so pages do not stretch across a big monitor).
class ContentFrame extends StatelessWidget {
  final double maxWidth;
  final Widget child;

  const ContentFrame({super.key, this.maxWidth = 720, required this.child});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Lays children out in equal-width columns (rows have equal height).
/// Give either a fixed [columns], or a [minTileWidth] and the number of
/// columns follows the available width.
class AdaptiveGrid extends StatelessWidget {
  final List<Widget> children;
  final int? columns;
  final double minTileWidth;
  final int maxColumns;
  final double spacing;

  const AdaptiveGrid({
    super.key,
    required this.children,
    this.columns,
    this.minTileWidth = 340,
    this.maxColumns = 3,
    this.spacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final cols =
            columns ??
            (box.maxWidth / minTileWidth).floor().clamp(1, maxColumns);

        if (cols <= 1) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(height: spacing),
                children[i],
              ],
            ],
          );
        }

        final rows = <Widget>[];
        for (var start = 0; start < children.length; start += cols) {
          final cells = <Widget>[];
          for (var c = 0; c < cols; c++) {
            if (c > 0) cells.add(SizedBox(width: spacing));
            final index = start + c;
            cells.add(
              Expanded(
                child: index < children.length
                    ? children[index]
                    : const SizedBox.shrink(),
              ),
            );
          }
          if (rows.isNotEmpty) rows.add(SizedBox(height: spacing));
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: cells,
              ),
            ),
          );
        }
        return Column(children: rows);
      },
    );
  }
}
