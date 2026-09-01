import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../tokens/semantic_theme.dart';

/// A destructive action offered alongside a primary one in [AppAlertDialog].
class AppAlertDialogAction {
  const AppAlertDialogAction({required this.label, this.isDestructive = false});

  final String label;
  final bool isDestructive;
}

/// What the user chose in [AppAlertDialog.showThreeWay].
///
/// A named enum rather than a nullable bool because three outcomes plus
/// dismissal can't be encoded in `bool?` without the call site guessing
/// which branch means what.
enum AppAlertDialogChoice {
  /// The affirmative action — e.g. "Save".
  primary,

  /// The destructive action — e.g. "Discard".
  destructive,

  /// Back out and change nothing — e.g. "Keep editing". Dismissing the
  /// dialog (tapping outside, hardware back) resolves here too, so the
  /// safe outcome is also the default one.
  cancel,
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

  /// Three-choice variant: an affirmative action, a destructive one, and a
  /// cancel that returns the user to what they were doing.
  ///
  /// Separate from [show] rather than an optional third parameter on it,
  /// because the return types genuinely differ — `bool?` cannot express
  /// three outcomes, and overloading it would make every existing call
  /// site's `true`/`false` ambiguous.
  ///
  /// Dismissing resolves to [AppAlertDialogChoice.cancel], never null: the
  /// safe branch and the default branch should be the same one, so a
  /// stray tap outside the dialog can never discard work.
  static Future<AppAlertDialogChoice> showThreeWay({
    required BuildContext context,
    required String title,
    required String message,
    required AppAlertDialogAction primaryAction,
    required AppAlertDialogAction destructiveAction,
    required AppAlertDialogAction cancelAction,
  }) async {
    final platform = Theme.of(context).platform;
    final isCupertino =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;

    final choice = isCupertino
        ? await showCupertinoDialog<AppAlertDialogChoice>(
            context: context,
            builder: (context) => CupertinoAlertDialog(
              title: Text(title),
              content: Text(message),
              actions: [
                CupertinoDialogAction(
                  onPressed: () =>
                      Navigator.of(context).pop(AppAlertDialogChoice.primary),
                  child: Text(primaryAction.label),
                ),
                CupertinoDialogAction(
                  isDestructiveAction: true,
                  onPressed: () =>
                      Navigator.of(context)
                          .pop(AppAlertDialogChoice.destructive),
                  child: Text(destructiveAction.label),
                ),
                CupertinoDialogAction(
                  // Marked as the default so the platform gives it the
                  // emphasis, matching it being the safe outcome.
                  isDefaultAction: true,
                  onPressed: () =>
                      Navigator.of(context).pop(AppAlertDialogChoice.cancel),
                  child: Text(cancelAction.label),
                ),
              ],
            ),
          )
        : await showDialog<AppAlertDialogChoice>(
            context: context,
            builder: (context) {
              final theme = Theme.of(context).extension<AmbleTheme>()!;
              return AlertDialog(
                title: Text(title),
                content: Text(message),
                actions: [
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context).pop(AppAlertDialogChoice.cancel),
                    child: Text(cancelAction.label),
                  ),
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context)
                            .pop(AppAlertDialogChoice.destructive),
                    child: Text(
                      destructiveAction.label,
                      style: TextStyle(color: theme.colorTaskAlert),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context).pop(AppAlertDialogChoice.primary),
                    child: Text(primaryAction.label),
                  ),
                ],
              );
            },
          );

    return choice ?? AppAlertDialogChoice.cancel;
  }
}
