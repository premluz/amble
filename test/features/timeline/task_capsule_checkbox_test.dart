import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/timeline/completion_checkbox.dart';
import 'package:amble/features/timeline/task_capsule_block.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task.dart';

/// `ShowCompletionCheckboxSetting` — requested directly as one setting
/// spanning all three views ("it hides it across 3 views"). This covers the
/// Task/List view's own capsule; `overlap_cluster_block_test.dart` and
/// `zone_container_block_test.dart` cover the other two row types.
void main() {
  final task = Task.create(
    title: 'Deep work',
    scheduledAt: DateTime(2026, 9, 4, 9),
    durationMinutes: 90,
    categoryId: BuiltInCategoryIds.work,
  );

  Future<void> pump(
    WidgetTester tester, {
    required bool showCompletionCheckbox,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
        home: Scaffold(
          body: TaskCapsuleBlock(
            task: task,
            onToggleComplete: () {},
            showCompletionCheckbox: showCompletionCheckbox,
          ),
        ),
      ),
    );
  }

  testWidgets('the checkbox renders by default', (tester) async {
    await pump(tester, showCompletionCheckbox: true);
    expect(find.byType(CompletionCheckbox), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'showCompletionCheckbox: false hides it and stops it accepting taps — '
    'kept in the tree (not removed) so an in-flight drag\'s hit-test '
    'ancestry is unchanged, per TaskCapsuleBlock\'s own stable-tree rule',
    (tester) async {
      await pump(tester, showCompletionCheckbox: false);

      // Still present structurally...
      expect(find.byType(CompletionCheckbox), findsOneWidget);
      // ...but fully transparent and non-interactive.
      final opacity = tester.widget<AnimatedOpacity>(
        find
            .ancestor(
              of: find.byType(CompletionCheckbox),
              matching: find.byType(AnimatedOpacity),
            )
            .first,
      );
      expect(opacity.opacity, 0.0);

      final ignorePointer = tester.widget<IgnorePointer>(
        find
            .ancestor(
              of: find.byType(CompletionCheckbox),
              matching: find.byType(IgnorePointer),
            )
            .first,
      );
      expect(ignorePointer.ignoring, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  // Regression test for a real bug, reported directly from a screenshot
  // showing "RIGHT OVERFLOWED BY 56 PIXELS" across stacked pills. In split
  // layout the caller lays this widget out at exactly ONE pill width, but
  // its text column and trailing checkbox still claimed their intrinsic
  // widths — the same RenderFlex overflow class the widget's own ClipRect
  // comment already documents, on the other axis.
  testWidgets(
    'splitLayout renders inside a one-pill-wide box without overflowing',
    (tester) async {
      final pillWidth = AmbleTheme.light.sizeTaskBadge;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
          home: Scaffold(
            body: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  width: pillWidth,
                  child: TaskCapsuleBlock(
                    task: task,
                    onToggleComplete: () {},
                    splitLayout: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // A RenderFlex overflow surfaces as a thrown FlutterError here.
      expect(tester.takeException(), isNull);
      // And the pill really is confined to its box.
      expect(
        tester.getSize(find.byType(TaskCapsuleBlock)).width,
        lessThanOrEqualTo(pillWidth),
      );
    },
  );

  // Regression test for a real bug, reported directly: "affected is lifted
  // (drag drop) state of tasks, right side is cut off, only part of pill
  // visible". While lifted, TaskCapsuleBlock wraps the pill in a frosted
  // Container with `EdgeInsets.all(spacingSm)` inside a ClipRRect — so it
  // needs pillWidth + 2*spacingSm to render whole, and a box sized to
  // exactly one pill width clipped its right edge.
  testWidgets(
    'a LIFTED split-layout pill needs more width than the pill itself — '
    'the frosted lift padding must not be clipped',
    (tester) async {
      final theme = AmbleTheme.light;
      final pillWidth = theme.sizeTaskBadge;

      Future<double> renderedWidth({required bool isLifted}) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(useMaterial3: true, extensions: [theme]),
            home: Scaffold(
              body: Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    // The width the split layout actually reserves.
                    width: pillWidth + theme.spacingSm * 2,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: TaskCapsuleBlock(
                        task: task,
                        splitLayout: true,
                        isLifted: isLifted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        return tester.getSize(find.byType(TaskCapsuleBlock)).width;
      }

      final lifted = await renderedWidth(isLifted: true);

      // The lifted pill genuinely occupies more than a bare pill width —
      // which is exactly why the reserved box has to be wider than one.
      expect(lifted, greaterThan(pillWidth));
      expect(lifted, lessThanOrEqualTo(pillWidth + theme.spacingSm * 2));
      expect(tester.takeException(), isNull);
    },
  );

  // Requested directly: "lifted state should have its inner title and time
  // underneath name showing" — in split layout the shared text column stays
  // anchored at its own x, so a pill dragged away from it would otherwise
  // travel unlabelled.
  testWidgets(
    'liftedTextInline puts the title and time back INSIDE the pill, which '
    'splitLayout alone collapses to zero width',
    (tester) async {
      Future<void> pumpSplit({required bool liftedTextInline}) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              useMaterial3: true,
              extensions: [AmbleTheme.light],
            ),
            home: Scaffold(
              body: TaskCapsuleBlock(
                task: task,
                splitLayout: true,
                liftedTextInline: liftedTextInline,
              ),
            ),
          ),
        );
      }

      // Split layout alone: the title widget stays in the tree (the
      // stable-tree rule this widget depends on) but is collapsed to zero
      // width, so it takes up no room and paints nothing.
      await pumpSplit(liftedTextInline: false);
      expect(tester.getSize(find.text('Deep work')).width, 0);

      // Lifted: the pill carries its own name and time at real width.
      await pumpSplit(liftedTextInline: true);
      expect(tester.getSize(find.text('Deep work')).width, greaterThan(0));
      expect(find.textContaining('9:00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  // Requested directly: "in ghost state we shouldn't have title and time
  // and not icon when moving." `contentHidden` alone deliberately KEEPS the
  // category emoji (it is a resting cluster member's only category cue), so
  // the ghost needs its own flag to drop it too.
  testWidgets(
    'glyphHidden hides the category emoji that contentHidden alone keeps',
    (tester) async {
      Future<Opacity> emojiOpacity({required bool glyphHidden}) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              useMaterial3: true,
              extensions: [AmbleTheme.light],
            ),
            home: Scaffold(
              body: TaskCapsuleBlock(
                task: task,
                contentHidden: true,
                glyphHidden: glyphHidden,
              ),
            ),
          ),
        );
        // The emoji is the pill's only Text child — found by position
        // rather than by literal glyph, so this doesn't break if the
        // category's emoji is ever changed.
        return tester.widget<Opacity>(
          find
              .ancestor(
                of: find.descendant(
                  of: find.byType(AnimatedContainer),
                  matching: find.byType(Text),
                ),
                matching: find.byType(Opacity),
              )
              .first,
        );
      }

      expect((await emojiOpacity(glyphHidden: false)).opacity, 1);
      expect((await emojiOpacity(glyphHidden: true)).opacity, 0);
    },
  );

  // Regression test for a real bug, reported directly: "all corners on
  // elevated drag drop is ok but not on [resting] view top left and
  // bottom left still older rounding." The frosted wrapper's own
  // ClipRRect is ALWAYS present (it can't be built conditionally without
  // breaking the drag gesture — see the widget's own tree-shape comment),
  // and was hard-coded to the LIFTED radius (radiusXl) even at rest,
  // where the pill's rail sits flush against this wrapper's left edge
  // with no padding — so the outer 16px clip landed on top of the pill's
  // own corner and overrode it.
  //
  // The wrapper's rest-state anchor is a small FIXED `radiusSm`,
  // deliberately independent of the pill's own "Pill shape" rung. The trap
  // this pins down (measured, after getting it wrong twice): a BIGGER
  // radius here makes the clipping WORSE. This wrapper spans the whole row
  // (~390px wide) while the pill is a ~24px rail pinned to its top-left,
  // and Flutter clamps a corner to half the box's SHORTER side — so on a
  // short row (a 30-minute task, 390x60) a large radius clamps to a 30px
  // arc that sweeps straight through the pill and bites its corners off.
  testWidgets(
    'the frosted wrapper clips at a small FIXED radius while resting, '
    'independent of the pill rung, and only widens once actually lifted',
    (tester) async {
      final theme = AmbleTheme.light;

      Future<BorderRadiusGeometry?> wrapperRadius({
        required bool isLifted,
      }) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(useMaterial3: true, extensions: [theme]),
            home: Scaffold(
              body: TaskCapsuleBlock(task: task, isLifted: isLifted),
            ),
          ),
        );
        await tester.pumpAndSettle();
        return tester
            .widgetList<ClipRRect>(find.byType(ClipRRect))
            .first
            .borderRadius;
      }

      expect(
        await wrapperRadius(isLifted: false),
        BorderRadius.circular(theme.radiusSm),
      );
      expect(
        await wrapperRadius(isLifted: true),
        BorderRadius.circular(theme.radiusXl),
      );
    },
  );

  // Regression test for a real bug, reported directly from a screenshot:
  // "pills are clipped, rounding is applied not directly on pills but
  // perhaps elsewhere" — SHORT pills rendered flat-topped/flat-bottomed
  // while tall ones looked correct, because the row-wide wrapper's own
  // corner (then anchored to radiusPill) clamped to an arc wide enough to
  // cut across the narrow pill. Two things must hold at every rung: the
  // wrapper stays small and fixed, and the pill keeps its own real corner.
  testWidgets(
    'the pill keeps its own configured radius at every "Pill shape" rung, '
    'and the row-wide wrapper never adopts it — including on a SHORT pill, '
    'the case that actually rendered clipped',
    (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // 30 minutes — short enough that the wrapper's own corner arc used to
      // reach across the pill's full 24px width.
      final shortTask = Task.create(
        title: 'Audiobook',
        scheduledAt: DateTime(2026, 9, 15, 8, 30),
        durationMinutes: 30,
        categoryId: BuiltInCategoryIds.work,
      );

      for (final radiusPill in [8.0, 16.0, 9999.0]) {
        final theme = AmbleTheme.light.copyWith(radiusPill: radiusPill);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(useMaterial3: true, extensions: [theme]),
            home: Scaffold(body: TaskCapsuleBlock(task: shortTask)),
          ),
        );
        await tester.pumpAndSettle();

        final wrapperClip =
            (tester
                        .widgetList<ClipRRect>(find.byType(ClipRRect))
                        .first
                        .borderRadius
                    as BorderRadius?)
                ?.topLeft
                .x;
        final pillRadius =
            ((tester.widget<AnimatedContainer>(
                              find.byType(AnimatedContainer).first,
                            )
                            .decoration
                        as BoxDecoration?)
                    ?.borderRadius
                as BorderRadius?)
                ?.topLeft
                .x;

        expect(
          pillRadius,
          radiusPill,
          reason:
              'the pill itself must carry the configured rung — the '
              'rounding belongs on the pill, not anywhere else',
        );
        expect(
          wrapperClip,
          theme.radiusSm,
          reason:
              'at radiusPill=$radiusPill the row-wide wrapper clipped at '
              '$wrapperClip; it must stay at the small fixed radiusSm, '
              'since a wider arc on a 390px-wide box cuts across the '
              'narrow pill and flattens its corners',
        );
      }
    },
  );

  // Regression test for a real bug, reported twice as "perceived padding
  // right ... still too big". The split layout reserves lift room around
  // the pill by widening its box; that box used to ALSO start
  // `spacingSm` further left, relying on an `Align(topCenter)` to push the
  // rail back to its lane. That never worked — `pillContent` is the whole
  // capsule row (rail + collapsed text column + checkbox) and fills the
  // box's width, so Align had nothing to centre and the rail hugged the
  // box's left edge, painting every pill 8px left of its own lane. Inside
  // a zone band that showed as 4px of padding on the left against 20px on
  // the right.
  testWidgets(
    'the coloured rail paints at the LEFT EDGE of the box it is given, so '
    'a caller placing that box at a lane x gets the rail exactly there',
    (tester) async {
      final theme = AmbleTheme.light;
      const boxLeft = 100.0;
      const boxTop = 50.0;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [theme]),
          home: Scaffold(
            body: Stack(
              children: [
                Positioned(
                  top: boxTop,
                  left: boxLeft,
                  // The box the split layout reserves: one pill, plus lift
                  // room. That room must sit to the RIGHT of the rail.
                  width: theme.sizeTaskBadge + theme.spacingSm * 2,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: TaskCapsuleBlock(task: task, splitLayout: true),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The rail is the pill's own coloured AnimatedContainer.
      final rail = tester.getRect(find.byType(AnimatedContainer).first);

      expect(rail.left, boxLeft, reason: 'rail must start at the lane x');
      expect(rail.top, boxTop, reason: 'rail top IS the task start time');
      expect(rail.width, theme.sizeTaskBadge);
    },
  );

  // Regression test for the bottom-edge counterpart to the zone top inset,
  // requested directly from a screenshot showing a task's pill flush
  // against its own zone's bottom edge: "the task that's matching the
  // timing duration of a zone needs to have a bottom padding of a zone
  // from the zone, same as the top padding (same principle)." Measures the
  // REAL rendered rail height (the pill's own AnimatedContainer), not a
  // copy of the widget's internal arithmetic, so reverting `bottomTrim`'s
  // wiring in TaskCapsuleBlock fails this.
  testWidgets(
    'bottomTrim shrinks the rendered pill height by exactly that amount',
    (tester) async {
      const trim = 4.0; // zoneBackgroundOffset

      Future<double> pillHeight(double bottomTrim) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              useMaterial3: true,
              extensions: [AmbleTheme.light],
            ),
            home: Scaffold(
              body: TaskCapsuleBlock(
                task: task,
                onToggleComplete: () {},
                bottomTrim: bottomTrim,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        return tester.getSize(find.byType(AnimatedContainer).first).height;
      }

      final untrimmed = await pillHeight(0);
      final trimmed = await pillHeight(trim);

      expect(untrimmed - trimmed, trim);
      expect(tester.takeException(), isNull);
    },
  );

  // A task already at the badgeSize floor can't be trimmed below nothing —
  // rawPillHeight - bottomTrim is floored at 0, not left negative.
  testWidgets(
    'bottomTrim never renders a negative pill height for a very short task',
    (tester) async {
      final shortTask = Task.create(
        title: 'Quick check-in',
        scheduledAt: DateTime(2026, 9, 4, 9),
        durationMinutes: 5,
        categoryId: BuiltInCategoryIds.work,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
          home: Scaffold(
            body: TaskCapsuleBlock(
              task: shortTask,
              onToggleComplete: () {},
              bottomTrim: 1000,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(AnimatedContainer).first).height, 0.0);
      expect(tester.takeException(), isNull);
    },
  );

  // Regression test for the "space between tasks" gap requested directly:
  // two close-but-non-overlapping short tasks (5- and 15-minute examples
  // given) both floored to badgeSize could render with touching pills.
  // `maxPillHeight` is the caller's cap for that case (computed by
  // `_maxPillHeight` in timeline_screen.dart, from the next same-column
  // task's real top) — this only tests that TaskCapsuleBlock actually
  // honours the cap, below badgeSize if asked, floored at 0.
  group('maxPillHeight', () {
    testWidgets('caps the rendered pill height even below badgeSize', (
      tester,
    ) async {
      final theme = AmbleTheme.light;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [theme]),
          home: Scaffold(
            body: TaskCapsuleBlock(
              task: task,
              onToggleComplete: () {},
              maxPillHeight: 6,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(theme.sizeTaskBadge, greaterThan(6));
      expect(tester.getSize(find.byType(AnimatedContainer).first).height, 6.0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('null means no cap — badgeSize floor applies as before', (
      tester,
    ) async {
      final theme = AmbleTheme.light;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [theme]),
          home: Scaffold(
            body: TaskCapsuleBlock(task: task, onToggleComplete: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getSize(find.byType(AnimatedContainer).first).height,
        greaterThanOrEqualTo(theme.sizeTaskBadge),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('never renders a negative height', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
          home: Scaffold(
            body: TaskCapsuleBlock(
              task: task,
              onToggleComplete: () {},
              maxPillHeight: -50,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(AnimatedContainer).first).height, 0.0);
      expect(tester.takeException(), isNull);
    });
  });
}
