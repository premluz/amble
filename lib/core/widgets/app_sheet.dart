import 'package:flutter/material.dart';

import '../tokens/component_tokens.dart';
import '../tokens/semantic_theme.dart';
import 'app_sheet_route.dart';
import 'app_sheet_scroll_body.dart';
import 'app_top_scroll_fade.dart';
import 'app_modal_scope.dart';

/// How tall an [AppSheet] should be. Three sizes, confirmed directly rather
/// than left as one auto-sized default for everything:
/// - [small]: sizes to its content, same as the original (only) behavior —
///   a short form or picker that shouldn't claim more room than it needs.
/// - [half]: a fixed half-viewport-height sheet, for a picker/list with
///   real content but not a full flow (e.g. the Category picker).
/// - [nearFull]: matches `StepScaffold`'s own near-full-screen inset
///   (`spacingXl` from the top) — for a sheet that's really a whole small
///   form (e.g. Add Category), not a quick picker.
enum AppSheetSize { small, half, nearFull }

/// Adaptive modal sheet — a rounded Material bottom sheet everywhere except
/// iOS/macOS, where it uses Cupertino's modal-popup styling. Screens should
/// never reach for `showModalBottomSheet`/`showCupertinoModalPopup`
/// directly; this is the only entry point, per docs/CONSTITUTION.md design
/// principle 4.
///
/// Both platforms share AppSheetRoute. Plain sheets slide immediately;
/// autofocus sheets join the tail of Android's actual keyboard animation.
/// Keyboard inset and surface translation are handled by AppSheetMotion.
class AppSheet {
  AppSheet._();

  /// [padded] wraps [builder]'s result in the sheet's standard inset.
  /// Content that manages its own padding (a picker that needs its wheels
  /// to reach the sheet's edges) passes false.
  ///
  /// [size] defaults to [AppSheetSize.small] — the original, only behavior
  /// this sheet had — so every pre-existing caller is unaffected unless it
  /// opts into a larger size explicitly.
  ///
  /// [autofocusesKeyboard] picks the entrance mode — see this class's own
  /// doc comment for the two modes. Defaults to `false` (the plain
  /// slide-in): a caller whose content autofocuses a field (e.g. an
  /// `autofocus: true` `TextField`, which brings the keyboard up as the
  /// sheet opens) passes `true`. Android 11+ reports progress; other
  /// platforms use a grace period before the ordinary slide.
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool padded = true,
    AppSheetSize size = AppSheetSize.small,
    bool autofocusesKeyboard = false,
  }) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final platform = Theme.of(context).platform;
    final isCupertino =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;

    // Builds with the SHEET ROUTE's context, not the caller's. Building
    // eagerly with the outer context (as this used to) meant a builder
    // that called `Navigator.of(ctx).pop(value)` popped the caller's
    // route instead of the sheet — so the sheet never closed and
    // `show()` never returned its value. Only surfaced once a caller
    // actually needed a return value; every prior caller was fire-and-
    // forget, which is why it went unnoticed.
    Widget content(BuildContext sheetContext) {
      // **2026-09-23 — no TOP inset here any more.** Reported directly:
      // "top padding should be in header" — a sheet whose content starts
      // with an [AppSheetHeader] already gets its own top spacing from
      // that header's own fixed-height row. Content that does NOT start
      // with one supplies its own top gap.
      //
      // **2026-09-30 — the bottom space is INSIDE the scroll.** Requested
      // directly: content "should come from bottom phone edge but on top
      // would be that shadow" — no margin cutting it off. The device's
      // bottom safe area plus `spacingBottomClearance` (padded sheets)
      // end the scrolling content, and a fade exactly that tall lies over
      // it: fitted content looks as before; scrolling content runs to the
      // edge and fades there.
      final media = MediaQuery.of(sheetContext);
      final bottom =
          media.padding.bottom + (padded ? theme.spacingBottomClearance : 0);
      final body = padded
          ? Padding(
              padding: EdgeInsets.symmetric(horizontal: theme.spacingLg),
              child: builder(sheetContext),
            )
          : builder(sheetContext);
      final scroll = SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            body,
            SizedBox(height: bottom),
          ],
        ),
      );

      final sized = switch (size) {
        // Sizes to its content, capped so it never reaches under the
        // status bar: the top safe area plus a visible gap stay clear, so
        // the header's × / ‹ is always reachable.
        AppSheetSize.small => ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: media.size.height - media.padding.top - theme.spacingXl,
          ),
          child: scroll,
        ),
        // A fixed fraction of the viewport, scrollable if content
        // overflows it — a picker/list with real content, not a full
        // flow.
        AppSheetSize.half => SizedBox(
          height: media.size.height * 0.5,
          child: scroll,
        ),
        // Matches StepScaffold's own near-full-screen inset exactly, so a
        // sheet-based flow and a route-pushed flow (task creation, Zone
        // add/edit) read as the same "this is basically a whole screen"
        // scale rather than two different near-full heights.
        AppSheetSize.nearFull => SizedBox(
          height: media.size.height - theme.spacingXl,
          child: scroll,
        ),
      };

      return AppSheetBottomInset(
        value: bottom,
        child: Stack(
          children: [
            sized,
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AppTopScrollFade(
                color: SheetTokens.surface(theme),
                height: bottom,
                fromBottom: true,
              ),
            ),
          ],
        ),
      );
    }

    return Navigator.of(context, rootNavigator: true).push<T>(
      AppSheetRoute<T>(
        isCupertino: isCupertino,
        autofocusesKeyboard: autofocusesKeyboard,
        theme: theme,
        builder: rootModalBuilder(context, content),
      ),
    );
  }
}
