import 'package:flutter/material.dart';

import '../tokens/semantic_theme.dart';
import 'app_button.dart';

/// The small horizontal grip bar shown at the top of a draggable sheet —
/// the "this can be dragged/tapped" affordance, visually distinct from
/// `ResizeHandle`'s accent-colored dot (`features/timeline/
/// resize_handle.dart`), which marks a resize edge on a TASK, not a
/// sheet's own drag surface.
///
/// Purely visual: this widget draws only the bar itself. It carries no
/// gesture handling of its own, since real callers need the drag/tap
/// target to span a whole header row, not just the bar's own small hit
/// box (see `QuickCreateSheetHandle`'s own doc comment on why its
/// `GestureDetector` wraps the FULL row, with this bar centered inside
/// it via `Align`/`Positioned`).
///
/// Systematized 2026-09-20, requested directly against a screenshot:
/// "move the handle higher up and make it lighter color, use token colors
/// available e.g. button subtle color" — the quick-create sheet's handle
/// (`QuickCreateSheetHandle` in `quick_create_sheet_shell.dart`) used to
/// draw its own bar inline, filled with `colorTextSecondary` (a
/// text-contrast token, too dark/heavy for a purely decorative grip) and
/// centered in its row rather than sitting near the row's own top edge.
class AppSheetHandle extends StatelessWidget {
  const AppSheetHandle({super.key, required this.theme});

  final AmbleTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: theme.spacingXl * 1.2,
      height: 4,
      decoration: BoxDecoration(
        // `AppButton.subtleTint` — the same low-alpha
        // `colorTextPrimary` wash the secondary button variant uses,
        // rather than a text-contrast token like `colorTextSecondary`
        // (too heavy for a purely decorative grip, not a text/icon that
        // needs to read clearly) or a new bespoke alpha invented just
        // for this bar.
        color: AppButton.subtleTint(theme),
        borderRadius: BorderRadius.circular(theme.radiusSm),
      ),
    );
  }
}
