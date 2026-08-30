import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../tokens/semantic_theme.dart';

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
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final AppButtonShape shape;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final isPrimary = variant == AppButtonVariant.primary;
    final isLarge = size == AppButtonSize.large;
    final isDisabled = onPressed == null;

    // Explicit disabled treatment rather than each platform's own default
    // (`CupertinoButton`/`ElevatedButton` both fade the WHOLE button,
    // fill included, toward transparent — which reads as blurry/washed
    // out). A disabled control should look like a real, solid surface
    // that merely can't be pressed: the fill goes flat grey, and only the
    // TEXT loses opacity, so the button still has a defined edge instead
    // of dissolving into the page behind it.
    final background = isDisabled
        ? theme.colorSurfaceField
        : (isPrimary ? theme.colorAccent : theme.colorSurfaceSecondary);
    final foreground = isDisabled
        ? theme.colorTextSecondary
        : (isPrimary ? theme.colorSurfacePrimary : theme.colorTextPrimary);
    final baseTextStyle = isLarge ? theme.textBody : theme.textLabel;
    final textStyle = baseTextStyle.copyWith(
      color: isDisabled ? foreground.withValues(alpha: 0.6) : foreground,
      fontWeight: FontWeight.w700,
    );
    final verticalPadding = isLarge ? theme.spacingMd : theme.spacingSm;
    final cornerRadius = shape == AppButtonShape.pill
        ? theme.radiusTaskPill
        : theme.radiusMd;

    final platform = Theme.of(context).platform;
    final isCupertino =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;

    if (isCupertino) {
      return CupertinoButton(
        onPressed: onPressed,
        color: background,
        // CupertinoButton ignores `color` once disabled and falls back to
        // its own washed-out default — `disabledColor` is the parameter
        // that actually governs the disabled fill, so it has to repeat
        // the same `background` explicitly or the platform default wins.
        disabledColor: background,
        borderRadius: BorderRadius.circular(cornerRadius),
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacingLg,
          vertical: verticalPadding,
        ),
        child: Text(label, style: textStyle),
      );
    }

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        // Same reasoning as CupertinoButton's `disabledColor` above:
        // ElevatedButton's default disabled state is Material's own
        // low-alpha grey, layered on top of whatever `backgroundColor`
        // says. These two make the explicit disabled palette the actual
        // disabled palette, not just the enabled one.
        disabledBackgroundColor: background,
        disabledForegroundColor: foreground,
        elevation: 0,
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacingLg,
          vertical: verticalPadding,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cornerRadius),
        ),
      ),
      child: Text(label, style: textStyle),
    );
  }
}
