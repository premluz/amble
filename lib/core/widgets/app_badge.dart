import 'package:flutter/material.dart';

import '../tokens/semantic_theme.dart';
import 'app_button.dart';

/// A small circular count/status indicator — the classic "notification
/// badge" pattern (an item count on a tab, a cart icon, etc.), positioned
/// as an OVERLAY on another control rather than a standalone tap target.
/// New component, requested directly for the Zones edit dock's own
/// deselect button ("this badge is actually a new comp, it's a classic
/// comp so let's default to what Flutter has... used to show number of
/// items e.g. in tab etc").
///
/// Two variants ([AppBadgeVariant.filled]/[AppBadgeVariant.outline]) and
/// three sizes ([AppBadgeSize.xs]/`.sm`/`.md`) — confirmed via
/// AskUserQuestion. Color tokens deliberately reuse [AppButton]'s own
/// accent-fill vocabulary ("token color wise, same as our interactive
/// button that can be pressed," confirmed as the accent/primary state,
/// not the subtle/ghost one): [AmbleTheme.colorAccent] for the filled
/// background/outline stroke, [AmbleTheme.colorSurfacePrimary] for the
/// on-accent foreground (filled variant's text) and as the outline
/// variant's own background (so an outline badge reads as a ring sitting
/// on the surface behind it, not a transparent hole).
class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.count,
    this.variant = AppBadgeVariant.filled,
    this.size = AppBadgeSize.sm,
  });

  /// The number shown inside the badge. Callers decide whether/when to
  /// show this widget at all (e.g. "only when more than one item is
  /// selected") — [AppBadge] itself always renders once built, with no
  /// implicit "hide at zero/one" behavior of its own.
  final int count;

  final AppBadgeVariant variant;
  final AppBadgeSize size;

  double _diameter(AmbleTheme theme) => switch (size) {
    AppBadgeSize.xs => theme.sizeBadgeXs,
    AppBadgeSize.sm => theme.sizeBadgeSm,
    AppBadgeSize.md => theme.sizeBadgeMd,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final diameter = _diameter(theme);
    final filled = variant == AppBadgeVariant.filled;

    return Container(
      width: diameter,
      height: diameter,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? theme.colorAccent : theme.colorSurfacePrimary,
        border: filled
            ? null
            : Border.all(color: theme.colorAccent, width: 1.5),
      ),
      child: Text(
        '$count',
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.clip,
        style: theme.textCaption.copyWith(
          color: filled ? theme.colorSurfacePrimary : theme.colorAccent,
          fontWeight: FontWeight.w700,
          // The caption style's own line-height reads too tall for a
          // diameter this small and clips/pushes the digit off-center —
          // pinned to 1.0 so the glyph centers on the badge's own middle
          // rather than the font's natural leading.
          height: 1.0,
        ),
      ),
    );
  }
}

enum AppBadgeVariant { filled, outline }

/// 3 rungs, matching [AppValueChipSize]'s own xs/sm/md shape rather than
/// [AppButtonSize]'s 5-rung scale — a badge is a smaller-scope component
/// than either a chip or a button. Backed by [AmbleTheme.sizeBadgeXs]/
/// `sizeBadgeSm`/`sizeBadgeMd`, not shared with any other component's own
/// size fields — see those fields' own doc comment for why a badge needs
/// a materially smaller scale than a real tap target.
enum AppBadgeSize { xs, sm, md }
