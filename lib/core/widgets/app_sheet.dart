import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../tokens/semantic_theme.dart';

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
class AppSheet {
  AppSheet._();

  /// [padded] wraps [builder]'s result in the sheet's standard inset.
  /// Content that manages its own padding (a picker that needs its wheels
  /// to reach the sheet's edges) passes false.
  ///
  /// [size] defaults to [AppSheetSize.small] — the original, only behavior
  /// this sheet had — so every pre-existing caller is unaffected unless it
  /// opts into a larger size explicitly.
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool padded = true,
    AppSheetSize size = AppSheetSize.small,
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
      final inner = padded
          ? Padding(
              padding: EdgeInsets.all(theme.spacingLg),
              child: builder(sheetContext),
            )
          : builder(sheetContext);

      return switch (size) {
        // Unconstrained — the sheet sizes to inner's own height, same as
        // the original (only) behavior.
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

    if (isCupertino) {
      return showCupertinoModalPopup<T>(
        context: context,
        builder: (sheetContext) => Container(
          decoration: BoxDecoration(
            color: theme.colorSurfaceBase,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(theme.radiusModal),
            ),
          ),
          // showCupertinoModalPopup has no Material ancestor, but sheet
          // content may still need one (e.g. a Material TextField) — an
          // adaptive layer that can only safely host Cupertino widgets
          // isn't a useful abstraction. Transparent so it doesn't fight
          // the Cupertino background above.
          child: Material(
            type: MaterialType.transparency,
            child: SafeArea(top: false, child: content(sheetContext)),
          ),
        ),
      );
    }

    return showModalBottomSheet<T>(
      context: context,
      barrierColor: theme.colorScrim,
      backgroundColor: theme.colorSurfaceBase,
      // Without this, Material caps the sheet at a fixed fraction of the
      // screen (9/16) regardless of the keyboard — a content-sized sheet
      // with a focused TextField would then overflow the instant the
      // keyboard opened, since the sheet had no room left to grow into.
      // `isScrollControlled: true` lets it grow to fit (up to the full
      // screen height), so `MediaQuery.viewInsets.bottom` padding inside
      // the content actually has somewhere to go. Reported directly as a
      // "bottom overflowed by N pixels" dev banner on the quick-capture
      // sheet.
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(theme.radiusModal),
        ),
      ),
      builder: (sheetContext) =>
          SafeArea(top: false, child: content(sheetContext)),
    );
  }
}
