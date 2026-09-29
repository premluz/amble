import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/tokens/task_state_tokens.dart';
import 'package:amble/features/task_detail/category_visual.dart';
import 'package:amble/features/timeline/task_capsule_block.dart';
import 'package:amble/features/timeline/task_state_style.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/task_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The task state grammar: normal, unlabeled, important, done — each
/// distinguishable from the others in both themes.
void main() {
  final themes = {'light': AmbleTheme.light, 'dark': AmbleTheme.dark};

  Task task({bool important = false, bool done = false}) => Task.create(
    title: 'Task',
    scheduledAt: DateTime(2026, 9, 28, 9),
    durationMinutes: 60,
    categoryId: BuiltInCategoryIds.work,
    isImportant: important,
  )..status = done ? TaskStatus.completed : TaskStatus.pending;

  final general = Category(
    id: BuiltInCategoryIds.general,
    name: 'General',
    colorToken: 0,
    emoji: '',
    isBuiltIn: true,
  );

  double contrast(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final hi = la > lb ? la : lb;
    final lo = la > lb ? lb : la;
    return (hi + .05) / (lo + .05);
  }

  for (final MapEntry(key: name, value: theme) in themes.entries) {
    group('$name theme', () {
      final label = theme.categorySwatches[4];

      test('a new, unlabeled task gets the reserved neutral, never a label '
          'palette colour', () {
        final visual = resolveCategoryVisual(theme: theme, category: general);
        expect(visual.pillColor, TaskStateTokens.unlabeledFill(theme));
        expect(theme.categorySwatches, isNot(contains(visual.pillColor)));
      });

      test('the unassigned tone is opaque, visibly coloured (not grey), '
          'shared by imported events, and never a done tint', () {
        final fill = TaskStateTokens.unlabeledFill(theme);
        expect(fill.a, 1, reason: 'not transparent');
        final channels = [fill.r, fill.g, fill.b];
        final spread =
            channels.reduce((a, b) => a > b ? a : b) -
            channels.reduce((a, b) => a < b ? a : b);
        expect(spread, greaterThan(.08), reason: 'a tone, not a grey');
        expect(TaskStateTokens.importedFill(theme), fill);
        for (final swatch in theme.categorySwatches) {
          expect(TaskStateTokens.doneFill(theme, swatch), isNot(fill));
        }
      });

      test('done recedes toward the page: a pale tint of its label, closer '
          'to the surface than the label itself', () {
        final done = TaskStateStyle.resolve(
          theme: theme,
          task: task(done: true),
          labelColor: label,
        );
        expect(done.fill, isNot(label));
        expect(
          contrast(done.fill, theme.colorSurfaceBase),
          lessThan(contrast(label, theme.colorSurfaceBase)),
        );
        expect(done.fill, isNot(TaskStateTokens.unlabeledFill(theme)));
      });

      test('done title is struck, paler than a live title, and the strike is '
          'exactly the text colour', () {
        final style = TaskStateStyle.resolve(
          theme: theme,
          task: task(done: true),
          labelColor: label,
        ).title(theme.textTaskTitle);
        expect(style.decoration, TextDecoration.lineThrough);
        expect(style.color!.a, lessThan(theme.colorTextPrimary.a));
        expect(style.decorationColor, style.color);
        expect(style.decorationThickness, TaskStateTokens.doneStrikeThickness);
      });

      test(
        'important: an accent-TINTED title (not full accent) and a star',
        () {
          final style = TaskStateStyle.resolve(
            theme: theme,
            task: task(important: true),
            labelColor: label,
          );
          expect(style.titleColor, TaskStateTokens.importantTitle(theme));
          expect(style.titleColor, isNot(theme.colorAccent));
          expect(style.titleColor, isNot(theme.colorTextPrimary));
          expect(style.showStar, isTrue);
        },
      );

      test('the star is a quiet neutral easing into a hint of accent — never '
          'the accent itself', () {
        final [base, tip] = TaskStateTokens.importantStarGradient(theme);
        expect(base, isNot(theme.colorAccent));
        expect(tip, isNot(theme.colorAccent));
        expect(
          contrast(base, theme.colorSurfaceBase),
          lessThan(contrast(theme.colorTextPrimary, theme.colorSurfaceBase)),
          reason: 'softer than the text it sits beside',
        );
      });

      testWidgets('the important star has a page-surface outline', (
        tester,
      ) async {
        const pillWidth = 40.0;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(extensions: [theme]),
            home: Scaffold(
              body: Center(
                child: TaskImportantStar(theme: theme, pillWidth: pillWidth),
              ),
            ),
          ),
        );

        final stars = tester
            .widgetList<Icon>(
              find.descendant(
                of: find.byType(TaskImportantStar),
                matching: find.byIcon(Icons.star_rounded),
              ),
            )
            .toList();
        final iconSize = pillWidth * TaskStateTokens.importantStarScale;

        expect(stars, hasLength(2));
        expect(stars.first.color, theme.colorSurfaceBase);
        expect(
          stars.first.size,
          iconSize + TaskStateTokens.importantStarOutlineWidth * 2,
        );
        expect(stars.last.size, iconSize);
      });

      test('done wins over important for the title, the star stays', () {
        final style = TaskStateStyle.resolve(
          theme: theme,
          task: task(important: true, done: true),
          labelColor: label,
        );
        expect(style.titleColor, TaskStateTokens.doneTitle(theme));
        expect(style.showStar, isTrue);
      });
    });
  }

  test('pill glyphs are paper on dark fills and charcoal on light ones — '
      'never pure white or black', () {
    expect(glyphColorOn(const Color(0xFF202020)), TaskStateTokens.glyphOnDark);
    expect(glyphColorOn(const Color(0xFFEFEFEF)), TaskStateTokens.glyphOnLight);
    expect(TaskStateTokens.glyphOnDark, isNot(const Color(0xFFFFFFFF)));
    expect(TaskStateTokens.glyphOnLight, isNot(const Color(0xFF000000)));
  });

  testWidgets('a done pill\'s glyph is faded; an active one is not', (
    tester,
  ) async {
    final work = Category(
      id: BuiltInCategoryIds.work,
      name: 'Work',
      colorToken: 4,
      emoji: '',
      iconCodePoint: Icons.work.codePoint,
      isBuiltIn: true,
    );
    Future<double> glyphAlpha(Task t) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [AmbleTheme.light]),
          home: Scaffold(
            body: TaskCapsuleBlock(task: t, category: work),
          ),
        ),
      );
      final icon = tester.widget<Icon>(
        find
            .descendant(
              of: find.byType(TaskCapsuleBlock),
              matching: find.byType(Icon),
            )
            .first,
      );
      return icon.color!.a;
    }

    expect(await glyphAlpha(task()), 1);
    expect(
      await glyphAlpha(task(done: true)),
      closeTo(TaskStateTokens.doneGlyphAlpha, .01),
    );
    expect(
      TaskStateTokens.doneGlyphAlpha,
      lessThan(.3),
      reason: 'a done icon is barely there',
    );
  });

  testWidgets('an important pill carries the corner star; a normal one does '
      'not', (tester) async {
    Future<void> pump(Task t) => tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [AmbleTheme.light]),
        home: Scaffold(body: TaskCapsuleBlock(task: t)),
      ),
    );
    await pump(task(important: true));
    expect(find.byType(TaskImportantStar), findsOneWidget);
    await pump(task());
    expect(find.byType(TaskImportantStar), findsNothing);
  });
}
