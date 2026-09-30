import 'package:flutter/material.dart';

import '../tokens/semantic_theme.dart';

/// A quiet empty-state message with an optional illustration or icon above it.
///
/// The accessory is intentionally a widget rather than an [IconData], so the
/// same layout can host the current meditation icon or a future image without
/// changing the empty-state component. [size] controls the accessory footprint,
/// the gap below it, and the surrounding breathing room as one coherent rung.
/// When used as an overlay in a [Stack], place it in [Positioned.fill] so the
/// [Center] can use the full visible viewport rather than its content size.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.message,
    required this.accessory,
    this.size = AppEmptyStateSize.md,
  });

  final String message;
  final Widget accessory;
  final AppEmptyStateSize size;

  double _accessorySize(AmbleTheme theme) => switch (size) {
    AppEmptyStateSize.sm => theme.spacingLg,
    AppEmptyStateSize.md => theme.spacingXl * 1.5,
    AppEmptyStateSize.lg => theme.spacingXl * 2,
  };

  double _accessoryMessageGap(AmbleTheme theme) => switch (size) {
    AppEmptyStateSize.sm => theme.spacingSm,
    AppEmptyStateSize.md => theme.spacingMd,
    AppEmptyStateSize.lg => theme.spacingLg,
  };

  double _padding(AmbleTheme theme) => switch (size) {
    AppEmptyStateSize.sm => theme.spacingLg,
    AppEmptyStateSize.md => theme.spacingXl,
    AppEmptyStateSize.lg => theme.spacingXl * 2,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final accessorySize = _accessorySize(theme);
    final accessoryColor = theme.colorTextSecondary;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(_padding(theme)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              key: const ValueKey('app-empty-state-accessory'),
              dimension: accessorySize,
              child: Center(
                child: IconTheme(
                  data: IconThemeData(
                    color: accessoryColor,
                    size: accessorySize,
                  ),
                  child: FittedBox(fit: BoxFit.contain, child: accessory),
                ),
              ),
            ),
            SizedBox(height: _accessoryMessageGap(theme)),
            Text(
              message,
              style: theme.textCaption.copyWith(color: accessoryColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

enum AppEmptyStateSize { sm, md, lg }
