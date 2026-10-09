import 'package:flutter/material.dart';

import '../tokens/semantic_theme.dart';
import 'app_sheet.dart';
import 'app_sheet_header.dart';
import 'app_sheet_presentation.dart';

/// Picks a calendar date. On a phone this is the platform date dialog, as
/// before. In a popover scope (the wide layout's panel) it is a month
/// calendar in a popover beside the control, and choosing a day closes it.
Future<DateTime?> showAppDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  if (AppSheetPresentationScope.of(context) != AppSheetPresentation.popover) {
    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
  }
  return AppSheet.show<DateTime>(
    context: context,
    padded: false,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext).extension<AmbleTheme>()!;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: theme.spacingLg),
            child: AppSheetHeader(
              theme: theme,
              title: 'Date',
              onClose: () => Navigator.of(sheetContext).pop(),
            ),
          ),
          CalendarDatePicker(
            initialDate: initialDate,
            firstDate: firstDate,
            lastDate: lastDate,
            onDateChanged: (date) => Navigator.of(sheetContext).pop(date),
          ),
        ],
      );
    },
  );
}
