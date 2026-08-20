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
    final background = isPrimary
        ? theme.colorAccent
        : theme.colorSurfaceSecondary;
    final foreground = isPrimary
        ? theme.colorSurfacePrimary
        : theme.colorTextPrimary;
    final baseTextStyle = isLarge ? theme.textBody : theme.textLabel;
    final textStyle = baseTextStyle.copyWith(
      color: foreground,
      fontWeight: FontWeight.w700,
    );
    final verticalPadding = isLarge ? theme.spacingMd : theme.spacingSm;
    final cornerRadius = shape == AppButtonShape.pill
        ? theme.radiusTaskPill
        : theme.radiusControl;

    final platform = Theme.of(context).platform;
    final isCupertino =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;

    if (isCupertino) {
      return CupertinoButton(
        onPressed: onPressed,
        color: background,
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
