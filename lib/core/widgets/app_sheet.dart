import 'package:flutter/material.dart';

import '../tokens/semantic_theme.dart';
import 'app_sheet_route.dart';
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
      // that header's own fixed-height row, so this padding's old
      // `EdgeInsets.all` doubled it. Left/right/bottom are unaffected
      // (bottom isn't provided anywhere else — `AppSheetRoute` only
      // adds bottom inset for an actual on-screen keyboard, and
      // `SafeArea(top: false)` guards the bottom edge, not top). Every
      // caller whose content does NOT start with [AppSheetHeader] (a plain
      // title `Text`, an `ActionRow`/[AppContextMenu] column, etc.) now
      // supplies its own top gap directly — see each one's own top-level
      // widget for a `SizedBox(height: theme.spacingLg)` immediately
      // preceding its first real child.
      final inner = padded
          ? Padding(
              padding: EdgeInsets.only(
                left: theme.spacingLg,
                right: theme.spacingLg,
                bottom: theme.spacingLg,
              ),
              child: builder(sheetContext),
            )
          : builder(sheetContext);

      return switch (size) {
        // Sizes to `inner`'s own height, same as the original (only)
        // behavior — but now wrapped by the CALLER (see `AppSheetRoute`
        // below) in a `ConstrainedBox` + `SingleChildScrollView` safety
        // net, since this route no longer goes through
        // `showModalBottomSheet`'s own `isScrollControlled: true` cap
        // handling (that flag existed specifically to prevent the
        // "bottom overflowed by N pixels" bug this route now has to guard
        // against itself).
        AppSheetSize.small => inner,
        // A fixed fraction of the viewport, scrollable if content
        // overflows it — a picker/list with real content, not a full
        // flow.
        AppSheetSize.half => SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.5,
          child: SingleChildScrollView(child: inner),
        ),
        // Matches StepScaffold's own near-full-screen inset exactly, so a
        // sheet-based flow and a route-pushed flow (task creation, Zone
        // add/edit) read as the same "this is basically a whole screen"
        // scale rather than two different near-full heights.
        AppSheetSize.nearFull => SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height - theme.spacingXl,
          child: SingleChildScrollView(child: inner),
        ),
      };
    }

    return Navigator.of(context, rootNavigator: true).push<T>(
      AppSheetRoute<T>(
        isCupertino: isCupertino,
        autofocusesKeyboard: autofocusesKeyboard,
        theme: theme,
        builder: rootModalBuilder(context, (sheetContext) {
          final sheetContent = content(sheetContext);
          // `AppSheetSize.small`-only safety net: `half`/`nearFull`
          // already wrap `inner` in their own `SizedBox` +
          // `SingleChildScrollView` above, but `small` sizes to its
          // content unconstrained — a real overflow risk now that this
          // route no longer goes through `showModalBottomSheet`'s own
          // `isScrollControlled: true` cap handling. Capped at the
          // viewport's own height (matching every other size's own
          // ceiling) and made scrollable, so a short sheet still sizes to
          // its content exactly as before (this constraint is a MAX, not
          // a fixed height) while a genuinely tall one — or one pushed
          // taller by a rising keyboard — scrolls instead of overflowing.
          return size == AppSheetSize.small
              ? ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(sheetContext).height,
                  ),
                  child: SingleChildScrollView(child: sheetContent),
                )
              : sheetContent;
        }),
      ),
    );
  }
}
