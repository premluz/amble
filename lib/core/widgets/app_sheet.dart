import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../tokens/semantic_theme.dart';

/// Adaptive modal sheet — a rounded Material bottom sheet everywhere except
/// iOS/macOS, where it uses Cupertino's modal-popup styling. Screens should
/// never reach for `showModalBottomSheet`/`showCupertinoModalPopup`
/// directly; this is the only entry point, per docs/CONSTITUTION.md design
/// principle 4.
class AppSheet {
  AppSheet._();

  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
  }) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final platform = Theme.of(context).platform;
    final isCupertino =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;

    final content = Padding(
      padding: EdgeInsets.all(theme.spacingLg),
      child: builder(context),
    );

    if (isCupertino) {
      return showCupertinoModalPopup<T>(
        context: context,
        builder: (context) => Container(
          decoration: BoxDecoration(
            color: theme.colorSurfacePrimary,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(theme.radiusSheet),
            ),
          ),
          // showCupertinoModalPopup has no Material ancestor, but sheet
          // content may still need one (e.g. a Material TextField) — an
          // adaptive layer that can only safely host Cupertino widgets
          // isn't a useful abstraction. Transparent so it doesn't fight
          // the Cupertino background above.
          child: Material(
            type: MaterialType.transparency,
            child: SafeArea(top: false, child: content),
          ),
        ),
      );
    }

    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: theme.colorSurfacePrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(theme.radiusSheet),
        ),
      ),
      builder: (context) => SafeArea(top: false, child: content),
    );
  }
}
