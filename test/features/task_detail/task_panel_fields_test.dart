import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/core/widgets/app_floating_surface.dart';
import 'package:amble/core/widgets/app_sheet_surface.dart';
import 'package:amble/core/widgets/app_value_chip.dart';
import 'package:amble/features/task_detail/task_inspector_panel.dart';
import 'package:amble/features/task_detail/task_panel_fields.dart';
import 'package:amble/features/task_detail/task_sheet.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task.dart';

import '../../support/task_inspector_host.dart';

/// In the wide layout's panel the task's settings sit one per line, and
/// each opens its picker as a popover beside the panel, not as a bottom
/// sheet — requested directly against Notion Calendar's event panel.

void main() {
  final boxes = TaskInspectorBoxes();
  late Box<Task> box;

  setUp(() async {
    await boxes.open('task_panel_fields');
    box = boxes.tasks;
  });

  tearDown(boxes.close);

  final panel = find.byType(TaskInspectorPanel);
  Finder inPanel(Finder finder) =>
      find.descendant(of: panel, matching: finder);

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

  testWidgets('settings sit one per line, not as chips', (tester) async {
    await openTask(tester);

    expect(inPanel(find.byType(TaskPanelFields)), findsOneWidget);
    expect(inPanel(find.byType(AppValueChip)), findsNothing);
    for (final line in ['Work', 'Repeat', 'Important', 'Notify at start']) {
      expect(inPanel(find.text(line)), findsOneWidget, reason: line);
    }
    final label = tester.getRect(inPanel(find.text('Work')));
    final repeat = tester.getRect(inPanel(find.text('Repeat')));
    expect(label.top, greaterThan(repeat.bottom));
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

  testWidgets('tapping a switch line\'s name flips it', (tester) async {
    await openTask(tester);
    expect(inPanel(find.byIcon(Icons.star_rounded)), findsNothing);

    await tapAndSettle(tester, inPanel(find.text('Important')));

    expect(inPanel(find.byIcon(Icons.star_rounded)), findsOneWidget);
  });
}
