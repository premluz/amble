import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../tokens/semantic_theme.dart';
import 'app_press_feedback.dart';

enum AppButtonVariant { primary, secondary, ghost }

/// A fixed height scale — `xs`/`sm` are for compact icon-only or inline
/// contexts, `md` is the everyday default, `lg`/`xl` clear the standard
/// 44-48px comfortable tap target. Replaces the old `regular`/`large`
/// two-rung enum (2026-09-19, requested directly: "speaking of height we
/// should have size scales xs sm md lg xl") — every call site that used
/// `regular` maps to [md], every `large` maps to [lg]. See
/// [AmbleTheme.sizeButtonXs] and its sibling fields for the actual pixel
/// values.
enum AppButtonSize { xs, sm, md, lg, xl }

enum AppButtonShape { rounded, pill, circle }

/// The pixel height for [size] — shared by [AppButton] and its sibling
/// selection primitives ([AppTabSwitch], [AppConnectedButtons]) so all
/// three sit flush at the same height when placed in one row, rather than
/// each picking its own independent sizing. See [AmbleTheme.sizeButtonXs]
/// and its sibling fields for the scale's own reasoning.
double appButtonHeightFor(AmbleTheme theme, AppButtonSize size) =>
    switch (size) {
      AppButtonSize.xs => theme.sizeButtonXs,
      AppButtonSize.sm => theme.sizeButtonSm,
      AppButtonSize.md => theme.sizeButtonMd,
      AppButtonSize.lg => theme.sizeButtonLg,
      AppButtonSize.xl => theme.sizeButtonXl,
    };

/// Adaptive button — Cupertino on iOS, Material elsewhere. Screens should
/// never reach for `CupertinoButton`/`ElevatedButton` directly; this is the
/// only entry point, per docs/CONSTITUTION.md design principle 4.
///
/// Content is one of: [label] alone, [icon] alone (icon-only — pass
/// [shape] as [AppButtonShape.circle] to match the old dedicated icon
/// buttons this replaces), both together (icon leading the label), or
/// [child] as a full escape hatch for content neither of those two cover
/// (e.g. the calendar header's day-of-month numeral in the same circular
/// outline as its icon buttons). Exactly one of [label]/[icon]/[child]
/// grouping is expected per call site; passing both [icon] and [label]
/// renders icon-then-label, and [child] overrides both when present.
///
/// **Variant visual language** (refined 2026-09-19, requested directly
/// against the first Widgetbook pass — "secondary is semi-transparent
/// with blurred bg... primary should take accent color... icon only
/// secondary is just border but should be same surface as text button"):
/// - [AppButtonVariant.primary] — filled [AmbleTheme.colorAccent], the
///   one "this is the main action" surface.
/// - [AppButtonVariant.secondary] — a translucent, BLURRED surface (see
///   [_secondaryTint]) rather than an opaque fill or a bare hairline
///   outline — reads as "the next surface up," not a fully contrasted
///   block. Both the rounded/pill text-button shape AND the circle
///   icon-only shape share this exact treatment now; the circle shape no
///   longer falls back to a plain border.
/// - [AppButtonVariant.ghost] — fully transparent at rest, no fill in any
///   state; only [AppPressFeedback]'s own tap ripple answers a press.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    this.label,
    this.icon,
    this.child,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.md,
    this.shape = AppButtonShape.rounded,
    this.isLoading = false,
    this.tooltip,
    this.iconColor,
    this.borderColor,
  }) : assert(
         label != null || icon != null || child != null,
         'must provide a label, an icon, or a child',
       );

  final String? label;
  final IconData? icon;

  /// Escape hatch for content that isn't a plain label/icon — see class
  /// doc. Ignored when [isLoading] is true (the spinner always wins).
  final Widget? child;

  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final AppButtonShape shape;

  /// Wraps the button in a [Tooltip] when set — the icon-only replacement
  /// for [AppSubtleIconButton]'s (previously required) `tooltip`.
  final String? tooltip;

  /// Per-instance overrides for [icon]'s color and, on the
  /// [AppButtonShape.circle] shape, the selected/secondary tint —
  /// [AppSubtleIconButton] exposed both for the few call sites that
  /// needed a non-default color; most callers leave these null and get
  /// the variant's normal palette. [borderColor] is kept as a field name
  /// for API continuity even though the circle shape no longer draws a
  /// literal border — it now tints the circle's own blurred fill instead.
  final Color? iconColor;
  final Color? borderColor;

  /// Shows a small spinner in place of [label] and disables the button —
  /// regardless of what [onPressed] itself is — for the duration of an
  /// in-flight async action the button triggered (e.g. saving a task).
  /// Requested directly: without this, a slow save left the button still
  /// tappable, and a second tap before the first save finished could
  /// create/edit the same task twice. Callers still own their own
  /// re-entrancy guard (e.g. a `_isSaving` flag around the async call) —
  /// this only covers the VISUAL half of "don't let them tap again."
  final bool isLoading;

  /// The secondary variant's translucent tint — derived from
  /// [AmbleTheme.colorTextPrimary] at low alpha, NOT
  /// [AmbleTheme.colorSurfaceBlurOverlay] directly. Mirrors
  /// [GlassPillSurface.glassTint]'s own reasoning exactly:
  /// `colorSurfaceBlurOverlay` is `surface1`-derived and measures near-white
  /// in BOTH themes (light `#FFFFFF`@36%, dark near-black@36% — i.e. it
  /// does not flip), which is what produced the reported dark-mode bug
  /// ("ghost text currently is same dark on dark" traced to the same
  /// non-flipping-token family during this fix). `colorTextPrimary` is a
  /// genuine per-theme pair (dark ink on light, pale sand on dark), so
  /// tinting from it — dark ink on a light theme, pale sand on a dark one
  /// — reads as a real "next surface" step in both directions.
  /// 0.08 read as too subtle in practice ("can't see text secondary,
  /// ghost, also can't see icon on sec and ghost") — raised to 0.16, still
  /// well short of [GlassPillSurface]'s own 0.22 (a full-screen-width
  /// timeline block, which needs to read as substantial from a distance;
  /// a button is a smaller, closer-read control, so a lighter touch than
  /// that reference still applies, just not as light as the original).
  static Color _secondaryTint(AmbleTheme theme) =>
      theme.colorTextPrimary.withValues(alpha: 0.16);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final isDisabled = onPressed == null || isLoading;

    if (shape == AppButtonShape.circle) {
      return _buildCircle(context, theme, isDisabled);
    }

    final isPrimary = variant == AppButtonVariant.primary;
    final isGhost = variant == AppButtonVariant.ghost;
    final isSecondary = variant == AppButtonVariant.secondary;
    final height = appButtonHeightFor(theme, size);

    // Explicit disabled treatment rather than each platform's own default
    // (`CupertinoButton`/`ElevatedButton` both fade the WHOLE button,
    // fill included, toward transparent — which reads as blurry/washed
    // out). A disabled control should look like a real, solid surface
    // that merely can't be pressed: the fill goes flat grey, and only the
    // TEXT loses opacity, so the button still has a defined edge instead
    // of dissolving into the page behind it. Secondary/ghost are the
    // exception, by construction — see below.
    //
    // Loading is deliberately a DIFFERENT look from plain disabled: a
    // washed-out grey button reads as "you can't do this," but a loading
    // button just did exactly what was asked and is busy following
    // through on it — the fill stays its normal enabled color, and only
    // the label swaps for a spinner.
    final Color? background = isPrimary
        ? (isLoading || !isDisabled ? theme.colorAccent : theme.colorSurfaceField)
        : null; // secondary/ghost never use a flat Color background — see
    // _secondaryTint's blur layer and the ghost no-fill branch below.
    final foreground = isGhost
        ? theme.colorTextPrimary
        : (isSecondary
              ? theme.colorTextPrimary
              : (isLoading
                    ? theme.colorSurfacePrimary
                    : (isDisabled
                          ? theme.colorTextSecondary
                          : theme.colorSurfacePrimary)));
    final textStyle = theme.textLabel.copyWith(
      color: (isDisabled && !isLoading)
          ? foreground.withValues(alpha: 0.6)
          : foreground,
      // Not bold — requested directly ("button text should not be bold
      // neither state"). w500 reads as a present, actionable label
      // without shouting, in every variant/state.
      fontWeight: FontWeight.w500,
    );
    // radiusPill (the live "Pill shape" setting) for BOTH rounded and
    // pill shapes — requested directly ("all buttons and other related
    // should be fully rounded"), confirmed the default `rounded` shape
    // should track the same live setting as `pill` rather than staying
    // pinned to a fixed 8px corner. The two shapes are visually identical
    // whenever the setting resolves to `full`; they only diverge if a
    // future non-full rung is selected.
    final cornerRadius = theme.radiusPill;
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
        : child ?? _buildLabelContent(theme, foreground, textStyle);

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
    // Primary paints its own opaque fill through the platform button, so
    // its disabled/enabled palette logic (above) still applies unchanged.
    // Secondary/ghost are ALWAYS transparent at the platform-button layer
    // — their real fill (a blurred glass tint, or nothing at all) is
    // painted by the wrapping layers in `_wrapBackground` below, which
    // sits OUTSIDE this platform button rather than being handed to it as
    // a `color`/`backgroundColor`.
    final resolvedBackground = background ?? Colors.transparent;
    final button = isCupertino
        ? CupertinoButton(
            onPressed: isDisabled ? null : noop,
            color: isPrimary ? resolvedBackground : null,
            disabledColor: isPrimary ? resolvedBackground : Colors.transparent,
            borderRadius: BorderRadius.circular(cornerRadius),
            padding: EdgeInsets.symmetric(horizontal: theme.spacingLg),
            child: content,
          )
        : ElevatedButton(
            onPressed: isDisabled ? null : noop,
            style: ElevatedButton.styleFrom(
              backgroundColor: resolvedBackground,
              foregroundColor: foreground,
              disabledBackgroundColor: resolvedBackground,
              disabledForegroundColor: foreground,
              elevation: 0,
              // Material's own ink splash is suppressed — AppPressFeedback
              // paints the wash instead, so leaving this on would show two
              // overlapping ripples with different origins and timings.
              splashFactory: NoSplash.splashFactory,
              padding: EdgeInsets.symmetric(horizontal: theme.spacingLg),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(cornerRadius),
              ),
            ),
            child: content,
          );

    final sizedButton = SizedBox(height: height, child: button);

    final result = AppPressFeedback(
      onTap: isDisabled ? null : onPressed,
      borderRadius: BorderRadius.circular(cornerRadius),
      // The wash rides on the button's own foreground color: against a
      // filled accent primary a dark wash would be nearly invisible,
      // while the light foreground reads correctly on it — and on
      // secondary/ghost that same foreground is the dark-on-light (or
      // light-on-dark) text color, which is exactly what a translucent or
      // empty fill needs.
      rippleColor: foreground,
      // AbsorbPointer, NOT IgnorePointer: both stop the platform button
      // handling the tap, but IgnorePointer also removes it from hit
      // testing entirely — which left 40 existing tests (which target
      // `find.byType(ElevatedButton)`) tapping a non-hit-testable node.
      // AbsorbPointer keeps the button hit-testable and simply swallows
      // the event, so those finders still resolve while the wrapper above
      // still receives the pointer.
      child: AbsorbPointer(
        child: _wrapBackground(
          theme: theme,
          isSecondary: isSecondary,
          cornerRadius: cornerRadius,
          child: sizedButton,
        ),
      ),
    );

    return tooltip == null ? result : Tooltip(message: tooltip!, child: result);
  }

  /// Applies the secondary variant's blurred glass fill BEHIND [child] —
  /// primary and ghost pass through unchanged (primary already painted its
  /// own opaque fill via the platform button; ghost paints nothing at
  /// rest by design). `ClipRRect` keeps the blur inside the button's own
  /// rounded corners rather than bleeding past them, same as
  /// [GlassPillSurface]'s own shape.
  Widget _wrapBackground({
    required AmbleTheme theme,
    required bool isSecondary,
    required double cornerRadius,
    required Widget child,
  }) {
    if (!isSecondary) return child;

    final radius = BorderRadius.circular(cornerRadius);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: theme.blurOverlaySigma,
          sigmaY: theme.blurOverlaySigma,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _secondaryTint(theme),
            borderRadius: radius,
          ),
          child: child,
        ),
      ),
    );
  }

  /// Icon-only or label-only content for the rounded/pill shapes — [icon]
  /// leading [label] when both are given, matching the order every
  /// existing "icon + text" control in the app already uses.
  Widget _buildLabelContent(
    AmbleTheme theme,
    Color foreground,
    TextStyle textStyle,
  ) {
    final labelText = label;
    final iconData = icon;
    if (iconData != null && labelText != null) {
      // `CrossAxisAlignment.center` alone still let the icon read as
      // sitting slightly higher than the label — Text reserves vertical
      // space for its font's full line height (ascent+descent+leading),
      // which is taller than Icon's tight square box, so centering each
      // widget's own bounding box does not center their visual glyphs
      // against each other. Wrapping the icon in a SizedBox at the
      // text style's own line height (fontSize * height) makes its
      // bounding box match Text's, so centering the two now centers what
      // you actually see, not just their boxes.
      final lineHeight = textStyle.fontSize! * (textStyle.height ?? 1.0);
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            height: lineHeight,
            child: Icon(iconData, color: foreground, size: textStyle.fontSize),
          ),
          SizedBox(width: theme.spacingXs),
          Text(labelText, style: textStyle),
        ],
      );
    }
    if (iconData != null) return Icon(iconData, color: foreground);
    return Text(labelText!, style: textStyle);
  }

  /// Circular icon-only rendering — replaces the old dedicated
  /// `AppIconButton` (primary, filled accent) and `AppSubtleIconButton`
  /// (secondary/ghost, hairline outline or none) widgets. [child], when
  /// given, overrides the icon entirely (e.g. the calendar header's
  /// day-of-month numeral).
  ///
  /// Secondary now shares the exact same blurred-glass treatment as the
  /// rounded/pill text button's secondary variant, rather than a plain
  /// hairline border — requested directly ("icon only secondary is just
  /// border but should be same surface as text button").
  Widget _buildCircle(BuildContext context, AmbleTheme theme, bool isDisabled) {
    final isPrimary = variant == AppButtonVariant.primary;
    final isSecondary = variant == AppButtonVariant.secondary;
    // Diameter now follows the SAME AppButtonSize scale as the text/pill
    // shapes — requested directly ("icon only missing size variants
    // should also have the same sizes and paddings"). Previously fixed at
    // spacingXl/spacingXl*1.5 regardless of `size`, so every icon-only
    // button was one size no matter what was passed.
    final diameter = appButtonHeightFor(theme, size);
    // Icon itself scales with the circle rather than staying pinned to
    // spacingLg, so a xs circle doesn't end up with an icon that visually
    // overflows its own smaller diameter, and an xl circle doesn't end up
    // with a visually undersized icon rattling around in it.
    final iconSize = diameter * 0.5;

    final background = isPrimary
        ? theme.colorAccent
        : (isSecondary ? (borderColor ?? _secondaryTint(theme)) : null);
    final foreground = isPrimary
        ? theme.colorSurfacePrimary
        : (iconColor ?? theme.colorTextPrimary);

    final content =
        child ??
        (icon != null ? Icon(icon, size: iconSize, color: foreground) : null);

    final filled = Container(
      width: diameter,
      height: diameter,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: content,
    );

    final blurred = !isSecondary
        ? filled
        : ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: theme.blurOverlaySigma,
                sigmaY: theme.blurOverlaySigma,
              ),
              child: filled,
            ),
          );

    final circle = AppPressFeedback(
      onTap: isDisabled ? null : onPressed,
      shape: BoxShape.circle,
      // Primary's fill is dark/accent-colored, so the wash rides on the
      // light foreground already used on it, same reasoning as the
      // rounded/pill shapes above. Secondary/ghost have a light or no
      // fill, so the wash rides on the neutral default instead.
      rippleColor: isPrimary ? foreground : null,
      child: blurred,
    );

    return tooltip == null ? circle : Tooltip(message: tooltip!, child: circle);
  }
}

/// A no-op passed as the platform buttons' `onPressed` — see the note in
/// [AppButton.build] on why it can't simply be null.
void _noop() {}
