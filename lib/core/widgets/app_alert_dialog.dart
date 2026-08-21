import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../tokens/semantic_theme.dart';

/// A destructive action offered alongside a primary one in [AppAlertDialog].
class AppAlertDialogAction {
  const AppAlertDialogAction({required this.label, this.isDestructive = false});

  final String label;
  final bool isDestructive;
}

/// Adaptive two-choice confirmation dialog — `CupertinoAlertDialog` on
/// iOS/macOS, Material `AlertDialog` elsewhere. Screens should never reach
/// for `showDialog`/`showCupertinoDialog` directly; this is the only entry
/// point, per docs/CONSTITUTION.md design principle 4.
///
/// Returns `true` if [primaryAction] was chosen, `false` if
/// [secondaryAction] was chosen, or `null` if dismissed without a choice.
class AppAlertDialog {
  AppAlertDialog._();

  static Future<bool?> show({
    required BuildContext context,
    required String title,
    required String message,
    required AppAlertDialogAction primaryAction,
    required AppAlertDialogAction secondaryAction,
  }) {
    final platform = Theme.of(context).platform;
    final isCupertino =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;

    if (isCupertino) {
      return showCupertinoDialog<bool>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              isDestructiveAction: secondaryAction.isDestructive,
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(secondaryAction.label),
            ),
            CupertinoDialogAction(
              isDestructiveAction: primaryAction.isDestructive,
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(primaryAction.label),
            ),
          ],
        ),
      );
    }

    return showDialog<bool>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context).extension<AmbleTheme>()!;
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                secondaryAction.label,
                style: TextStyle(
                  color: secondaryAction.isDestructive
                      ? theme.colorTaskAlert
                      : null,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                primaryAction.label,
                style: TextStyle(
                  color: primaryAction.isDestructive
                      ? theme.colorTaskAlert
                      : null,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
