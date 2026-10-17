import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/core/widgets/app_floating_surface.dart';
import 'package:amble/core/widgets/app_sheet_surface.dart';
import 'package:amble/core/widgets/app_value_chip.dart';
import 'package:amble/features/task_detail/task_inspector_panel.dart';
import 'package:amble/features/task_detail/task_sheet_fields.dart';
import 'package:amble/features/task_detail/task_sheet.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task.dart';

import '../../support/task_inspector_host.dart';

/// In the wide layout's panel the task's settings are the phone's chips
/// (Preset, Date, Time, Duration and the icon toggles), and each opens its
/// picker as a popover beside the panel, not as a bottom sheet. Requested
/// 2026-10-11: "should use same badges as mobile" (the earlier one-per-line
/// panel, 2026-10-08, was replaced).

void main() {
  final boxes = TaskInspectorBoxes();
  late Box<Task> box;

  setUp(() async {
    await boxes.open('task_panel_fields');
    box = boxes.tasks;
  });

  tearDown(boxes.close);

  final panel = find.byType(TaskInspectorPanel);
  Finder inPanel(Finder finder) => find.descendant(of: panel, matching: finder);

  Future<Task> openTask(WidgetTester tester) async {
    final task = Task.create(
      title: 'Standup',
      scheduledAt: daysFromToday(0, hour: 9),
      durationMinutes: 30,
      categoryId: BuiltInCategoryIds.work,
    );
    await tester.runAsync(() => box.put(task.id, task));
    final navigatorKey = await boxes.pump(tester);
    showTaskSheet(navigatorKey.currentContext!, task: task);
    await tester.pumpAndSettle();
    return task;
  }

  testWidgets('settings are the phone\'s chips, not lines', (tester) async {
    await openTask(tester);

    expect(inPanel(find.byType(TaskSheetFields)), findsOneWidget);
    // Date, Time, Duration; the icon toggles come after (Important,
    // label, tracked, notify, repeat, note).
    expect(inPanel(find.byType(AppValueChip)), findsNWidgets(3 + 6));
    expect(inPanel(find.text('30m')), findsOneWidget);
    for (final icon in [
      Icons.star_rounded,
      Icons.fingerprint_rounded,
      Icons.notifications_rounded,
      Icons.repeat_rounded,
      Icons.notes_rounded,
    ]) {
      expect(inPanel(find.byIcon(icon)), findsOneWidget, reason: '$icon');
    }
    expect(inPanel(find.text('Notify at start')), findsNothing);
  });

  testWidgets('a value opens its picker beside the panel, not a sheet', (
    tester,
  ) async {
    await openTask(tester);
    await tapAndSettle(tester, inPanel(find.text('30m')));

    // The length picker (its title and its typed field both say so).
    expect(
      find.descendant(
        of: find.byType(AppFloatingSurface),
        matching: find.text('Duration'),
      ),
      findsWidgets,
    );
    expect(find.byType(AppSheetSurface), findsNothing);
    final popover = tester.getRect(find.byType(AppFloatingSurface));
    expect(popover.right, lessThanOrEqualTo(tester.getRect(panel).left));
  });

  testWidgets('a value picked in the popover shows on its line', (
    tester,
  ) async {
    await openTask(tester);
    await tapAndSettle(tester, inPanel(find.text('30m')));
    await tapAndSettle(tester, find.text('1h'));
    await tapAndSettle(tester, find.text('Done'));

    expect(find.byType(AppFloatingSurface), findsNothing);
    expect(inPanel(find.text('60m')), findsOneWidget);
  });

  testWidgets('tapping the Important chip flips it', (tester) async {
    await openTask(tester);
    final important = inPanel(
      find.ancestor(
        of: find.byIcon(Icons.star_rounded),
        matching: find.byType(AppValueChip),
      ),
    );
    expect(tester.widget<AppValueChip>(important).hasValue, isFalse);

    await tapAndSettle(tester, important);

    expect(tester.widget<AppValueChip>(important).hasValue, isTrue);
  });
}
