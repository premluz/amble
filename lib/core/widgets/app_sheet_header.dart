import 'package:flutter/material.dart';

import '../tokens/semantic_theme.dart';
import 'app_step_scaffold.dart' show HeaderCircleButton;

/// The "close (left) + primary action (right), no title" sheet header —
/// the shared shape behind `new_section_sheet.dart`, `new_zone_sheet.dart`,
/// `quick_capture_sheet.dart` and (as the reference implementation it was
/// modelled on) the Timeline quick-create overlay's own header row. Each
/// had hand-built this independently. Extracted per direct request against
/// a reference screenshot: "this can also be added to our widget book
/// storybook as a sheet header, and this will be one of the variants of
/// it."
///
/// **2026-09-23 (second pass) — a fixed-height row with the drag handle
/// layered BEHIND the controls, not a handle stacked above a separate
/// button row.** Reported directly: "header not same height / too big gap
/// / drag 'to close' thingy not same positioned as on add quick task
/// sheet." The first pass kept the note sheet's own vertical stack (handle
/// row, then header row below it) and only fixed the gap between them,
/// which left three visible differences against the reference:
///
/// - **Height** — the reference reserves ONE row of `spacingXl * 1.8` and
///   fits everything inside it; a stack of two rows is taller by the
///   handle's own height plus whatever gap separates them.
/// - **Gap** — with the handle in the layout flow, its own bottom padding
///   and the header's top padding ADD, which is what read as "too big."
///   Here there is no gap to get wrong: they occupy the same row.
/// - **Handle position** — the reference top-aligns the handle inside that
///   shared row (`spacingSm` from its top), so it sits ABOVE the buttons'
///   own centre line rather than in a band of its own.
///
/// The handle is [Positioned.fill]ed so its drag target spans the whole
/// row width (not just the visual bar), with the close/[trailing] controls
/// layered on top winning their own taps — copied from the reference's own
/// structure, which documents that shape as a direct fix for the bar alone
/// being "difficult to" grab.
///
/// The close icon is fixed to `Icons.close_rounded`, matching the app's
/// general `_rounded` icon convention (`quick_capture_sheet.dart`'s own
/// original header already used it) — `new_section_sheet.dart`/
/// `new_zone_sheet.dart` previously used the plain, non-rounded `Icons
/// .close` instead; migrating them onto this shared header is a small,
/// deliberate visual unification onto the more common variant, not an
/// oversight.
class AppSheetHeader extends StatelessWidget {
  const AppSheetHeader({
    super.key,
    required this.theme,
    required this.onClose,
    this.trailing,
    this.handle,
  });

  final AmbleTheme theme;
  final VoidCallback onClose;

  /// The right-hand content — typically an [AppButton] (Create/Save/Done),
  /// but a caller with a secondary control alongside it (e.g.
  /// `quick_capture_sheet.dart`'s mic button before its own Done) passes a
  /// `Row` of its own here rather than this widget growing an N-slot API.
  final Widget? trailing;

  /// The drag-to-close affordance, layered behind the controls and filling
  /// the whole row so it drags from anywhere the buttons don't cover — see
  /// this class's own doc comment. Null for a sheet with no drag-to-close
  /// gesture at all (`new_section_sheet.dart`, `new_zone_sheet.dart`),
  /// which then renders just the controls at the same row height, so every
  /// sheet's header still lines up whether or not it has a handle.
  final Widget? handle;

  /// Matches the reference implementation's own reserved header height
  /// (`quick_create_overlay.dart`) exactly — "taller than the old
  /// bare-handle row: it now has to fit real buttons, not just a hairline
  /// drag bar."
  static double heightFor(AmbleTheme theme) => theme.spacingXl * 1.8;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: heightFor(theme),
      child: Stack(
        children: [
          if (handle != null) Positioned.fill(child: handle!),
          Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            child: Center(
              child: HeaderCircleButton(
                theme: theme,
                icon: Icons.close_rounded,
                onTap: onClose,
              ),
            ),
          ),
          if (trailing != null)
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              child: Center(child: trailing!),
            ),
        ],
      ),
    );
  }
}
