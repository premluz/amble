import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/tokens/task_state_tokens.dart';
import 'package:amble/features/timeline/task_capsule_block.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Task titles are one step under semibold (medium) everywhere they
/// render — requested directly: "font weight for task label names one
/// step less."
FontWeight? _weightOf(WidgetTester tester, String text) {
  FontWeight? found;
  for (final element in find.byType(RichText).evaluate()) {
    (element.widget as RichText).text.visitChildren((span) {
      if (span is TextSpan && span.text == text) found = span.style?.fontWeight;
      return true;
    });
  }
  return found;
}

Widget _app(Widget child) => MaterialApp(
  theme: ThemeData(extensions: [AmbleTheme.light]),
  home: Scaffold(body: child),
);

Task _task() => Task.create(
  title: 'Plan the week',
  scheduledAt: DateTime(2026, 10, 10, 9),
  durationMinutes: 30,
  categoryId: BuiltInCategoryIds.work,
);

void main() {
  test('the title weight is medium, one step under semibold', () {
    expect(TaskStateTokens.titleWeight, FontWeight.w500);
  });

  for (final compact in [false, true]) {
    testWidgets('TaskCapsuleTextRow title uses it (compactInlineLayout: '
        '$compact)', (tester) async {
      await tester.pumpWidget(
        _app(
          TaskCapsuleTextRow(
            task: _task(),
            timeColumnWidth: 80,
            durationColumnWidth: 40,
            compactInlineLayout: compact,
          ),
        ),
      );
      expect(_weightOf(tester, 'Plan the week'), TaskStateTokens.titleWeight);
    });
  }
}
