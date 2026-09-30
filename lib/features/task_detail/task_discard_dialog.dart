import 'package:flutter/widgets.dart';

import '../../core/widgets/app_alert_dialog.dart';

/// Asked when a task sheet with unsaved edits is closed: save it, discard
/// it, or keep editing.
Future<AppAlertDialogChoice> confirmDiscardTask(BuildContext context) =>
    AppAlertDialog.showThreeWay(
      context: context,
      title: 'Discard this task?',
      message:
          "You haven't saved this task yet. Save it with the current "
          'time and duration, or discard the draft?',
      primaryAction: const AppAlertDialogAction(label: 'Save task'),
      destructiveAction: const AppAlertDialogAction(
        label: 'Discard draft',
        isDestructive: true,
      ),
      cancelAction: const AppAlertDialogAction(label: 'Keep editing'),
    );
