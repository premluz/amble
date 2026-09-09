import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../tokens/semantic_theme.dart';
import 'app_press_feedback.dart';

enum AppButtonVariant { primary, secondary }

enum AppButtonSize { regular, large }

enum AppButtonShape { rounded, pill }

/// Adaptive button — Cupertino on iOS, Material elsewhere. Screens should
/// never reach for `CupertinoButton`/`ElevatedButton` directly; this is the
/// only entry point, per docs/CONSTITUTION.md design principle 4.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.regular,
    this.shape = AppButtonShape.rounded,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final AppButtonShape shape;

  /// Shows a small spinner in place of [label] and disables the button —
  /// regardless of what [onPressed] itself is — for the duration of an
  /// in-flight async action the button triggered (e.g. saving a task).
  /// Requested directly: without this, a slow save left the button still
  /// tappable, and a second tap before the first save finished could
  /// create/edit the same task twice. Callers still own their own
  /// re-entrancy guard (e.g. a `_isSaving` flag around the async call) —
  /// this only covers the VISUAL half of "don't let them tap again."
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final isPrimary = variant == AppButtonVariant.primary;
    final isLarge = size == AppButtonSize.large;
    // Loading forces the button non-interactive regardless of what
    // [onPressed] itself is — the point is stopping a second tap while an
    // in-flight action is still running.
    final isDisabled = onPressed == null || isLoading;

    // Explicit disabled treatment rather than each platform's own default
    // (`CupertinoButton`/`ElevatedButton` both fade the WHOLE button,
    // fill included, toward transparent — which reads as blurry/washed
    // out). A disabled control should look like a real, solid surface
    // that merely can't be pressed: the fill goes flat grey, and only the
    // TEXT loses opacity, so the button still has a defined edge instead
    // of dissolving into the page behind it.
    //
    // Loading is deliberately a DIFFERENT look from plain disabled: a
    // washed-out grey button reads as "you can't do this," but a loading
    // button just did exactly what was asked and is busy following
    // through on it — the fill stays its normal enabled color, and only
    // the label swaps for a spinner.
    final background = isLoading
        ? (isPrimary ? theme.colorAccent : theme.colorSurfaceSecondary)
        : (isDisabled
              ? theme.colorSurfaceField
              : (isPrimary ? theme.colorAccent : theme.colorSurfaceSecondary));
    final foreground = isLoading
        ? (isPrimary ? theme.colorSurfacePrimary : theme.colorTextPrimary)
        : (isDisabled
              ? theme.colorTextSecondary
              : (isPrimary
                    ? theme.colorSurfacePrimary
                    : theme.colorTextPrimary));
    final baseTextStyle = isLarge ? theme.textBody : theme.textLabel;
    final textStyle = baseTextStyle.copyWith(
      color: (isDisabled && !isLoading)
          ? foreground.withValues(alpha: 0.6)
          : foreground,
      fontWeight: FontWeight.w700,
    );
    final verticalPadding = isLarge ? theme.spacingMd : theme.spacingSm;
    final cornerRadius = shape == AppButtonShape.pill
        ? theme.radiusTaskPill
        : theme.radiusMd;
    // Sized against the text style's own line height so the spinner
    // doesn't change the button's height when it swaps in for the label.
    final spinnerSize = textStyle.fontSize! * 1.2;

    final platform = Theme.of(context).platform;
    final isCupertino =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;

    final content = isLoading
        ? SizedBox(
            width: spinnerSize,
            height: spinnerSize,
            child: isCupertino
                ? CupertinoActivityIndicator(color: foreground)
                : CircularProgressIndicator(strokeWidth: 2, color: foreground),
          )
        : Text(label, style: textStyle);

    // The platform button is kept for its shape, disabled palette,
    // semantics and platform-adaptiveness (design principle 4) — but its
    // OWN tap handling is switched off and the wrapper drives the action
    // instead. Reported directly: "buttons became less responsive, as in
    // tap and nothing happens for some time (and action after a
    // moment)." Both `ElevatedButton` and `CupertinoButton` fire
    // `onPressed` only once the GESTURE ARENA declares a winner, and
    // inside a scrollable the arena holds the tap open to see whether the
    // pointer becomes a scroll — that wait is the delay that was felt.
    // AppPressFeedback fires from `onTapUp` (the instant the finger
    // lifts), the same responsiveness fix `place_task_line.dart` already
    // applies to the Timeline's own tap-to-place gesture.
    //
    // `onPressed` stays NON-NULL (a no-op) rather than null: null would
    // switch both platform buttons to their disabled rendering even for
    // an enabled button. AbsorbPointer below is what actually stops them
    // handling the tap.
    const noop = _noop;
    final button = isCupertino
        ? CupertinoButton(
            onPressed: isDisabled ? null : noop,
            color: background,
            // CupertinoButton ignores `color` once disabled and falls back
            // to its own washed-out default — `disabledColor` is the
            // parameter that actually governs the disabled fill, so it has
            // to repeat the same `background` explicitly or the platform
            // default wins.
            disabledColor: background,
            borderRadius: BorderRadius.circular(cornerRadius),
            padding: EdgeInsets.symmetric(
              horizontal: theme.spacingLg,
              vertical: verticalPadding,
            ),
            child: content,
          )
        : ElevatedButton(
            onPressed: isDisabled ? null : noop,
            style: ElevatedButton.styleFrom(
              backgroundColor: background,
              foregroundColor: foreground,
              // Same reasoning as CupertinoButton's `disabledColor` above:
              // ElevatedButton's default disabled state is Material's own
              // low-alpha grey, layered on top of whatever
              // `backgroundColor` says. These two make the explicit
              // disabled palette the actual disabled palette, not just the
              // enabled one.
              disabledBackgroundColor: background,
              disabledForegroundColor: foreground,
              elevation: 0,
              // Material's own ink splash is suppressed — AppPressFeedback
              // paints the wash instead, so leaving this on would show two
              // overlapping ripples with different origins and timings.
              splashFactory: NoSplash.splashFactory,
              padding: EdgeInsets.symmetric(
                horizontal: theme.spacingLg,
                vertical: verticalPadding,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(cornerRadius),
              ),
            ),
            child: content,
          );

    return AppPressFeedback(
      onTap: isDisabled ? null : onPressed,
      borderRadius: BorderRadius.circular(cornerRadius),
      // The wash rides on the button's own foreground color: against a
      // filled accent primary a dark wash would be nearly invisible,
      // while the light foreground reads correctly on it — and on the
      // secondary variant that same foreground is the dark text color,
      // which is exactly what a light fill needs.
      rippleColor: foreground,
      // AbsorbPointer, NOT IgnorePointer: both stop the platform button
      // handling the tap, but IgnorePointer also removes it from hit
      // testing entirely — which left 40 existing tests (which target
      // `find.byType(ElevatedButton)`) tapping a non-hit-testable node.
      // AbsorbPointer keeps the button hit-testable and simply swallows
      // the event, so those finders still resolve while the wrapper above
      // still receives the pointer.
      child: AbsorbPointer(child: button),
    );
  }
}

/// A no-op passed as the platform buttons' `onPressed` — see the note in
/// [AppButton.build] on why it can't simply be null.
void _noop() {}
