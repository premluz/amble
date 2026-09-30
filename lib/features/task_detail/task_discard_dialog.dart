import 'package:flutter/widgets.dart';

import '../../core/widgets/app_alert_dialog.dart';

/// Asked when a task sheet with unsaved edits is closed: save it, discard
/// it, or keep editing.
Future<AppAlertDialogChoice> confirmDiscardTask(BuildContext context) =>
    AppAlertDialog.showThreeWay(
      context: context,
      primaryAction: const AppAlertDialogAction(label: 'Save as thing'),
      destructiveAction: const AppAlertDialogAction(
        label: 'Discard',
        isDestructive: true,
      ),
      cancelAction: const AppAlertDialogAction(label: 'Keep editing'),
    );
