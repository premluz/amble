import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/timeline/completion_checkbox.dart';
import 'package:amble/features/timeline/external_event_capsule_block.dart'
    show DashedPillRail;
import 'package:amble/features/timeline/zone_container_block.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/external_calendar_event.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/task_status.dart';
import 'package:amble/shared/models/zone.dart';

void main() {
  final zone = Zone.create(
    title: 'Morning ritual',
    startMinutes: 7 * 60,
    endMinutes: 12 * 60,
  );
  final category = Category(
    id: BuiltInCategoryIds.work,
    name: 'Work',
    colorToken: 0,
    emoji: '💼',
    isBuiltIn: true,
  );
  final task = Task.create(
    title: 'Deep work',
    scheduledAt: DateTime(2026, 9, 4, 9),
    durationMinutes: 230, // 3h 50m.
    categoryId: BuiltInCategoryIds.work,
  );
  final stackKey = GlobalKey();

  Future<void> pump(
    WidgetTester tester, {
    bool durationVisible = true,
    bool timeRangeVisible = true,
    bool startTimeOnlyVisible = false,
    List<ExternalCalendarEvent> externalEvents = const [],
    bool showCompletionCheckbox = true,
    Map<String, Category> categoriesById = const {},
    bool flatStyle = false,
    List<Task>? tasksOverride,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
        home: Scaffold(
          body: SizedBox(
            key: stackKey,
            width: 400,
            child: ZoneContainerBlock(
              theme: AmbleTheme.light,
              zone: zone,
              tasks: tasksOverride ?? [task],
              externalEvents: externalEvents,
              categoriesById: categoriesById,
              stackAncestorKey: stackKey,
              durationVisible: durationVisible,
              timeRangeVisible: timeRangeVisible,
              startTimeOnlyVisible: startTimeOnlyVisible,
              showCompletionCheckbox: showCompletionCheckbox,
              flatStyle: flatStyle,
            ),
          ),
        ),
      ),
    );
  }

  // Regression test for a real bug, reported directly: "task name should
  // be same font size as time and duration of task in zone mode, atm in
  // list mode and task mode font is larger of time and task name" — the
  // in-container row's title used textBody while its time/duration line
  // used the smaller textCaption, unlike Task/List mode where both use
  // textBody.
  testWidgets('the task title and its time line render at the same font size', (
    tester,
  ) async {
    await pump(tester);

    final titleText = tester.widget<Text>(find.text('Deep work'));
    final timeText = tester.widget<Text>(
      find.textContaining('9:00', findRichText: false),
    );

    expect(titleText.style?.fontSize, timeText.style?.fontSize);
  });

  // Regression test for a real bug, reported directly: "some items when
  // selected as 'done' in zone view are not crossed out and greyed out,
  // while they are on task view spatial." The checkbox already reflected
  // `task.status` correctly (it toggled fine) — the row's own TITLE never
  // referenced completion at all, so marking a task done in Zone view
  // changed the checkbox but left the title looking untouched. Matches
  // `TaskCapsuleBlock`'s own completed-title treatment (muted secondary
  // color + strikethrough).
  testWidgets(
    'a completed task\'s title is greyed out and struck through, matching '
    'the Spatial Task View\'s own treatment',
    (tester) async {
      final completedTask = Task.create(
        title: 'Deep work',
        scheduledAt: DateTime(2026, 9, 4, 9),
        durationMinutes: 230,
        categoryId: BuiltInCategoryIds.work,
      )..status = TaskStatus.completed;

      await pump(tester, tasksOverride: [completedTask]);

      final titleText = tester.widget<Text>(find.text('Deep work'));
      expect(
        titleText.style?.color,
        AmbleTheme.light.colorTextSecondary,
        reason: 'a completed task\'s title must grey out',
      );
      expect(
        titleText.style?.decoration,
        TextDecoration.lineThrough,
        reason: 'a completed task\'s title must be struck through',
      );
    },
  );

  testWidgets(
    'an INCOMPLETE task\'s title stays bold primary color with no '
    'strikethrough',
    (tester) async {
      await pump(tester);

      final titleText = tester.widget<Text>(find.text('Deep work'));
      expect(titleText.style?.color, AmbleTheme.light.colorTextPrimary);
      expect(titleText.style?.decoration, TextDecoration.none);
    },
  );

  // Requested directly: "Size of text in zone view (task name one scale
  // up)." AmbleTheme.light's own default resolves textTaskTitle to md's
  // size and textTaskTitleZone to lg's — one genuine rung larger, not
  // just a different color/weight on the same size.
  testWidgets(
    'the task title renders one scale up from the shared textTaskTitle '
    'token Task/List view use',
    (tester) async {
      await pump(tester);

      final titleText = tester.widget<Text>(find.text('Deep work'));
      expect(
        titleText.style?.fontSize,
        AmbleTheme.light.textTaskTitleZone.fontSize,
      );
      expect(
        titleText.style?.fontSize,
        greaterThan(AmbleTheme.light.textTaskTitle.fontSize!),
        reason:
            'Zone view must read larger than Task/List view at the same '
            'Task-size setting',
      );
    },
  );

  // Second half of the same report: Zone mode should show "start - end
  // (duration)" like Task mode, not just a bare start time.
  testWidgets(
    'shows "start - end (duration)", matching TaskCapsuleBlock\'s format',
    (tester) async {
      await pump(tester);
      expect(
        find.textContaining('9:00 AM - 12:50 PM (3h 50m)'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'durationVisible: false hides the "(duration)" suffix but keeps the '
    'start - end range — matches the dev-config toggle\'s existing '
    'TaskCapsuleBlock contract',
    (tester) async {
      await pump(tester, durationVisible: false);
      expect(find.textContaining('9:00 AM - 12:50 PM'), findsOneWidget);
      expect(find.textContaining('3h 50m'), findsNothing);
    },
  );

  // Requested directly: "Hide/show start end should also affect zone
  // view" — timeRangeVisible and durationVisible are two independent
  // pieces, same contract as TaskCapsuleTextRow's own split.
  testWidgets(
    'timeRangeVisible: false hides the start - end range but keeps the '
    '"(duration)" suffix — independent of durationVisible',
    (tester) async {
      await pump(tester, timeRangeVisible: false);
      expect(find.textContaining('9:00 AM'), findsNothing);
      expect(find.textContaining('12:50 PM'), findsNothing);
      expect(find.textContaining('(3h 50m)'), findsOneWidget);
    },
  );

  testWidgets(
    'timeRangeVisible: false AND durationVisible: false hides the whole '
    'time line for the row',
    (tester) async {
      await pump(tester, timeRangeVisible: false, durationVisible: false);
      expect(find.textContaining('9:00 AM'), findsNothing);
      expect(find.textContaining('3h 50m'), findsNothing);
      // The task's own title still renders — only the time/duration line
      // is empty.
      expect(find.text('Deep work'), findsOneWidget);
    },
  );

  // Requested directly: "we need to add control show time Start time
  // (zone view), this will add task start time only (we have similar
  // show start end time switch, but this one only start time)."
  group('startTimeOnlyVisible', () {
    testWidgets('renders just the start time — no end time, no duration '
        'suffix, no dash separator', (tester) async {
      await pump(tester, startTimeOnlyVisible: true);

      final timeText = tester.widget<Text>(
        find.textContaining('9:00 AM', findRichText: false),
      );
      expect(
        timeText.data,
        '9:00 AM',
        reason: 'exactly the start time, nothing appended — the zone '
            'HEADER above still legitimately shows its own "7:00 AM - '
            '12:00 PM" range, which is a different Text widget and '
            'unaffected by this per-row toggle',
      );
      expect(find.textContaining('12:50 PM'), findsNothing);
      expect(find.textContaining('3h 50m'), findsNothing);
    });

    testWidgets('WINS over timeRangeVisible when both are somehow true — '
        'the more specific request takes priority', (tester) async {
      await pump(
        tester,
        startTimeOnlyVisible: true,
        timeRangeVisible: true,
        durationVisible: true,
      );

      expect(find.textContaining('9:00 AM'), findsOneWidget);
      expect(find.textContaining('12:50 PM'), findsNothing);
    });

    testWidgets('off (default): the row keeps its existing start-end '
        'range, unchanged', (tester) async {
      await pump(tester);

      expect(find.textContaining('9:00 AM'), findsOneWidget);
      expect(find.textContaining('12:50 PM'), findsOneWidget);
    });

    testWidgets('the label renders in colorTextTertiary, the more subtle '
        'of the two muted text tokens', (tester) async {
      await pump(tester, startTimeOnlyVisible: true);

      final timeText = tester.widget<Text>(
        find.textContaining('9:00 AM', findRichText: false),
      );
      expect(timeText.style?.color, AmbleTheme.light.colorTextTertiary);
    });

    testWidgets('does not affect the zone header\'s own time range', (
      tester,
    ) async {
      await pump(tester, startTimeOnlyVisible: true);

      // The zone's own header still shows its full start-end range
      // (7:00 AM - 12:00 PM per this file's own `zone` fixture),
      // regardless of the task row toggle.
      expect(find.textContaining('7:00 AM'), findsOneWidget);
      expect(find.textContaining('12:00 PM'), findsOneWidget);
    });
  });

  group('externalEvents (merged into the container\'s own row list)', () {
    // Regression coverage for a real bug, reported directly: "on zone
    // mode tasks imported should be inside zones like other task[s]" —
    // external events previously only rendered on the outer axis,
    // regardless of whether they belonged inside a zone.
    final event = ExternalCalendarEvent(
      id: 'evt-1',
      title: 'Team sync',
      start: DateTime(2026, 9, 4, 10),
      end: DateTime(2026, 9, 4, 10, 30),
      sourceCalendarId: 'cal-1',
    );

    testWidgets('a matched external event renders as its own row inside '
        'the container, alongside the zone\'s tasks', (tester) async {
      await pump(tester, externalEvents: [event]);

      expect(find.text('Deep work'), findsOneWidget);
      expect(find.text('Team sync'), findsOneWidget);
    });

    testWidgets(
      'tapping an external event row opens the read-only info sheet',
      (tester) async {
        await pump(tester, externalEvents: [event]);

        await tester.tap(find.text('Team sync'));
        await tester.pumpAndSettle();

        // Title appears twice with the sheet open: once on the row
        // behind it, once in the sheet itself.
        expect(find.text('Team sync'), findsNWidgets(2));
      },
    );

    testWidgets('an external event row has no completion checkbox — strictly '
        'read-only, unlike a real task row', (tester) async {
      await pump(tester, externalEvents: [event]);
      // Exactly one CompletionCheckbox — the real task's — not two;
      // the external event row renders no equivalent control at all.
      expect(find.byType(CompletionCheckbox), findsOneWidget);
    });

    // Requested directly, from a screenshot comparing the two views: "on
    // the zone view, the imported items from calendar should be rendered
    // in the same way as other events, other tasks, so with the circle,
    // and icon inside the circle is dotted, same as in the timeline
    // view." This row used to be a bare muted title with no badge at all,
    // which is what made an imported event read as a different KIND of
    // object here than it does in Task view.
    testWidgets('an external event row shows the same dashed calendar badge '
        'Task view\'s own imported events use', (tester) async {
      await pump(tester, externalEvents: [event]);

      expect(find.byType(DashedPillRail), findsOneWidget);
    });

    testWidgets('the dashed badge is sized to theme.sizeTaskBadge, matching '
        'a real task row\'s own category badge exactly', (tester) async {
      await pump(tester, externalEvents: [event]);

      final rail = tester.widget<DashedPillRail>(
        find.byType(DashedPillRail),
      );
      expect(rail.width, AmbleTheme.light.sizeTaskBadge);
      expect(rail.height, AmbleTheme.light.sizeTaskBadge);
    });

    testWidgets('a zone with no external events renders no dashed badge at '
        'all', (tester) async {
      await pump(tester);

      expect(find.byType(DashedPillRail), findsNothing);
    });

    // Regression coverage for a real bug, reported directly from a
    // screenshot with time hidden: "the tasks are still not aligned, 3
    // different alignment for text — imported from other calendar
    // (indent) / inside zone / outside zone."
    //
    // `_ZoneTaskRow` collapses its time column AND the trailing
    // `spacingSm` gap together behind `if (timeLabel.isNotEmpty)`.
    // `_ZoneExternalEventRow` had no such guard, so with time hidden its
    // empty `Text` collapsed to zero width but the gap SURVIVED, pushing
    // every imported row's badge and title exactly 8px (spacingSm) right
    // of the task rows beside them. Measured before the fix: badge 24.0
    // vs 16.0, title 56.0 vs 48.0.
    testWidgets(
      'with time hidden, an imported event row\'s badge and title line up '
      'exactly with a task row\'s — no leftover gap indenting it',
      (tester) async {
        await pump(
          tester,
          externalEvents: [event],
          timeRangeVisible: false,
          durationVisible: false,
          categoriesById: {BuiltInCategoryIds.work: category},
        );

        final taskBadge = tester.getRect(
          find
              .ancestor(of: find.text('💼'), matching: find.byType(Container))
              .first,
        );
        final eventBadge = tester.getRect(find.byType(DashedPillRail));

        expect(
          eventBadge.left,
          moreOrLessEquals(taskBadge.left, epsilon: 0.5),
          reason:
              'imported badge left=${eventBadge.left}, task badge '
              'left=${taskBadge.left}',
        );
        expect(
          tester.getTopLeft(find.text('Team sync')).dx,
          moreOrLessEquals(
            tester.getTopLeft(find.text('Deep work')).dx,
            epsilon: 0.5,
          ),
        );
      },
    );

    testWidgets(
      'timeRangeVisible: false hides an external event row\'s time too',
      (tester) async {
        await pump(tester, externalEvents: [event], timeRangeVisible: false);

        expect(find.textContaining('10:00'), findsNothing);
        expect(find.text('Team sync'), findsOneWidget);
      },
    );
  });

  testWidgets(
    'timeRangeVisible: false hides the zone header\'s own start-end range, '
    'keeping its title\'s duration suffix',
    (tester) async {
      await pump(tester, timeRangeVisible: false);

      // Header title: "Morning ritual 5h" — the zone's own 07:00-12:00
      // duration (no parentheses — requested directly: "remove brackets
      // from duration in zone names"). Kept regardless; only the
      // separate time-range text (also "7:00 AM - 12:00 PM") hides.
      expect(find.textContaining('Morning ritual 5h'), findsOneWidget);
      expect(find.textContaining('7:00 AM - 12:00 PM'), findsNothing);
    },
  );

  // `ShowCompletionCheckboxSetting` — one setting across all three views.
  // This is the Zone view's own row; the other two are covered by
  // task_capsule_checkbox_test.dart and overlap_cluster_block_test.dart.
  testWidgets(
    'showCompletionCheckbox: false removes the task row\'s checkbox',
    (tester) async {
      await pump(tester);
      expect(find.byType(CompletionCheckbox), findsOneWidget);

      await pump(tester, showCompletionCheckbox: false);
      expect(find.byType(CompletionCheckbox), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  // **2026-09-12 — reversed.** Requested directly: "the emoji and circle
  // ... smaller" and "make actually same shape as timeline, not circle
  // but rounded square." Was `sizeTaskBadgeXl` (32px) + `BoxShape.circle`;
  // now `theme.sizeTaskBadge` (the SAME active, resolved size
  // TaskCapsuleBlock's own pill rail uses) + a `radiusSm`-rounded square,
  // matching that same pill exactly rather than being its own enlarged
  // circle.
  testWidgets(
    'the category badge is sized to theme.sizeTaskBadge, matching the '
    'Task view pill exactly',
    (tester) async {
      await pump(tester, categoriesById: {BuiltInCategoryIds.work: category});

      final badge = tester.widget<Container>(
        find
            .ancestor(of: find.text('💼'), matching: find.byType(Container))
            .first,
      );
      expect(badge.constraints?.maxWidth, AmbleTheme.light.sizeTaskBadge);
      expect(badge.constraints?.maxHeight, AmbleTheme.light.sizeTaskBadge);
      expect(
        badge.constraints?.maxWidth,
        lessThan(AmbleTheme.light.sizeTaskBadgeXl),
        reason: 'must be smaller than the old enlarged size',
      );
    },
  );

  testWidgets('the category badge is a rounded square, not a circle', (
    tester,
  ) async {
    await pump(tester, categoriesById: {BuiltInCategoryIds.work: category});

    final badge = tester.widget<Container>(
      find
          .ancestor(of: find.text('💼'), matching: find.byType(Container))
          .first,
    );
    final decoration = badge.decoration! as BoxDecoration;
    expect(decoration.shape, BoxShape.rectangle);
    expect(
      decoration.borderRadius,
      // theme.radiusPill, not radiusSm — tracks the "Pill shape" setting;
      // AmbleTheme.light's own field already resolves to its default rung
      // (PillShape.small -> radiusPillSmall, 8), not the old hardcoded
      // radiusSm (4).
      BorderRadius.circular(AmbleTheme.light.radiusPill),
    );
  });

  testWidgets(
    'the gap between the category badge and the task title matches the '
    'gap used outside zones (theme.spacingSm)',
    (tester) async {
      await pump(tester, categoriesById: {BuiltInCategoryIds.work: category});

      // Measured off the badge CONTAINER's own right edge, not the emoji
      // Text's — a Text widget's measured bounds include font-metric
      // padding beyond its visible glyph, which would inflate the gap by
      // more than the actual SizedBox between them.
      final badgeFinder = find
          .ancestor(of: find.text('💼'), matching: find.byType(Container))
          .first;
      final badgeRight = tester.getTopRight(badgeFinder).dx;
      final titleLeft = tester.getTopLeft(find.text('Deep work')).dx;
      expect(titleLeft - badgeRight, AmbleTheme.light.spacingSm);
    },
  );

  // Requested directly: "add a control in admin that affects the grid
  // zone view and removes the background from zones and[,] uh, padding
  // as well[;] so what's left is a title[,] and underneath the tasks
  // related inside this zone[,] and duration[,] of course, also stays."
  group('flatStyle (DevZoneCardFlat)', () {
    testWidgets('off (default) keeps the card\'s background fill and padding', (
      tester,
    ) async {
      await pump(tester);

      final decoratedBox = tester.widget<DecoratedBox>(
        find.byType(DecoratedBox).first,
      );
      final decoration = decoratedBox.decoration as BoxDecoration;
      expect(decoration.color, AmbleTheme.light.colorSurfaceSecondary);

      // Asymmetric on purpose: no RIGHT padding, so the trailing
      // completion checkbox lines up with the one on a task row outside a
      // zone. See "a nested checkbox lines up with a standalone task
      // row's" below for the measurement that drove this.
      final padding = tester.widget<Padding>(find.byType(Padding).first);
      expect(
        padding.padding,
        EdgeInsets.fromLTRB(
          AmbleTheme.light.spacingMd,
          AmbleTheme.light.spacingMd,
          0,
          AmbleTheme.light.spacingMd,
        ),
      );
    });

    testWidgets(
      'on removes the background fill and padding, keeping the title, '
      'duration, and member task row',
      (tester) async {
        await pump(tester, flatStyle: true);

        final decoratedBox = tester.widget<DecoratedBox>(
          find.byType(DecoratedBox).first,
        );
        final decoration = decoratedBox.decoration as BoxDecoration;
        expect(decoration.color, isNull);

        final padding = tester.widget<Padding>(find.byType(Padding).first);
        expect(padding.padding, EdgeInsets.zero);

        // Title (with its duration suffix) and the member task row both
        // still render — only the chrome around them is gone.
        expect(find.textContaining('Morning ritual'), findsOneWidget);
        expect(find.text('Deep work'), findsOneWidget);
      },
    );

    // Requested directly, same session: "tasks should be in 'card' like
    // they are in manage (but keep size of them as they are in zone view
    // atm)."
    testWidgets(
      'each task row gets its own Manage-style card (colorSurfaceSecondary '
      'fill, radiusXl corners), with the row\'s own height unchanged',
      (tester) async {
        await pump(tester, flatStyle: true);

        // The task row's own DecoratedBox is the SECOND one in the tree —
        // the container's own (now colorless) fill is the first.
        final rowDecoratedBox = tester.widget<DecoratedBox>(
          find.byType(DecoratedBox).at(1),
        );
        final decoration = rowDecoratedBox.decoration as BoxDecoration;
        expect(decoration.color, AmbleTheme.light.colorSurfaceSecondary);
        expect(
          decoration.borderRadius,
          BorderRadius.circular(AmbleTheme.light.radiusXl),
        );

        // Row height is untouched — still the fixed zoneContainerRowHeight
        // (44px), confirmed directly ("keep size of them as they are").
        final rowBox = find
            .ancestor(
              of: find.text('Deep work'),
              matching: find.byType(SizedBox),
            )
            .first;
        expect(tester.widget<SizedBox>(rowBox).height, zoneContainerRowHeight);
      },
    );

    testWidgets('off (default), the task row has no card of its own — plain, '
        'colorless BoxDecoration, matching the pre-existing bare row', (
      tester,
    ) async {
      await pump(tester);

      final rowDecoratedBox = tester.widget<DecoratedBox>(
        find.byType(DecoratedBox).at(1),
      );
      final decoration = rowDecoratedBox.decoration as BoxDecoration;
      expect(decoration.color, isNull);
    });
  });

  group('onHeaderTap gating', () {
    // The non-spatial Zone view (`ZoneDayTimeline`, requested directly:
    // "current zone view make non spatial.. just list of zones one by
    // one") wires ONLY onHeaderTap, no move contract, with
    // editModeEnabled always false — its whole point is a header tap that
    // works without Edit Mode. Task view's own multi-task-select route
    // (zone_multi_task_selection_test.dart) is the other caller, and
    // wires onHeaderTap ALONGSIDE onMoveEnd, gated behind editModeEnabled
    // — unaffected by this test.
    testWidgets(
      'fires with editModeEnabled: false when no move contract is wired',
      (tester) async {
        var tapped = false;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              useMaterial3: true,
              extensions: [AmbleTheme.light],
            ),
            home: Scaffold(
              body: SizedBox(
                key: stackKey,
                width: 400,
                child: ZoneContainerBlock(
                  theme: AmbleTheme.light,
                  zone: zone,
                  tasks: const [],
                  categoriesById: const {},
                  stackAncestorKey: stackKey,
                  onHeaderTap: () => tapped = true,
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Morning ritual 5h'));
        expect(tapped, isTrue);
      },
    );

    testWidgets(
      'does NOT fire when a move contract is wired and editModeEnabled '
      'is false — Task view\'s multi-task-select route stays Edit-Mode-gated',
      (tester) async {
        var tapped = false;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              useMaterial3: true,
              extensions: [AmbleTheme.light],
            ),
            home: Scaffold(
              body: SizedBox(
                key: stackKey,
                width: 400,
                child: ZoneContainerBlock(
                  theme: AmbleTheme.light,
                  zone: zone,
                  tasks: const [],
                  categoriesById: const {},
                  stackAncestorKey: stackKey,
                  editModeEnabled: false,
                  onHeaderTap: () => tapped = true,
                  onMoveStart: (_) {},
                  onMoveUpdate: (_) {},
                  onMoveEnd: (_) {},
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Morning ritual 5h'));
        expect(tapped, isFalse);
      },
    );
  });

  // Reported directly from a device screenshot: "the position of the
  // checkbox in the zone view should be on the right hand side.
  // Currently, it's somewhere in the middle." The row laid the title out
  // as `Expanded(flex: 3)` against the time column's `flex: 2`, so the
  // title's BOX ran all the way to the flex boundary and the checkbox was
  // parked immediately after it — wherever that 2:3 split happened to
  // land, rather than at the row's own right edge.
  testWidgets(
    'the completion checkbox sits flush against the row\'s right edge',
    (tester) async {
      await pump(tester, categoriesById: {category.id: category});

      final checkbox = tester.getRect(find.byType(CompletionCheckbox));
      final row = tester.getRect(find.byKey(stackKey));

      // Flush right, allowing only the row's own trailing padding. A
      // mid-row checkbox (the bug) sat hundreds of pixels short of this.
      expect(
        row.right - checkbox.right,
        lessThan(24.0),
        reason:
            'checkbox right edge is \${row.right - checkbox.right}px from the '
            'row right edge — it should be flush, not floating mid-row',
      );
    },
  );

  // The other half of the same fix: a SHORT title must not drag the
  // checkbox leftward with it. This is what distinguishes a real
  // right-anchored layout from one that merely looks right for the one
  // title length the first test happens to use.
  testWidgets('a short title leaves the checkbox at the same right edge', (
    tester,
  ) async {
    await pump(tester, categoriesById: {category.id: category});
    final withLongTitle = tester.getRect(find.byType(CompletionCheckbox)).right;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
        home: Scaffold(
          body: SizedBox(
            key: stackKey,
            width: 400,
            child: ZoneContainerBlock(
              theme: AmbleTheme.light,
              zone: zone,
              tasks: [
                Task.create(
                  title: 'cf',
                  scheduledAt: DateTime(2026, 9, 4, 9),
                  durationMinutes: 230,
                  categoryId: BuiltInCategoryIds.work,
                ),
              ],
              categoriesById: {category.id: category},
              stackAncestorKey: stackKey,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getRect(find.byType(CompletionCheckbox)).right,
      withLongTitle,
    );
  });

  // Reported directly: "Cant see task names on zone view." An earlier fix
  // that pinned the checkbox right (title `Flexible(flex: 3)` beside a
  // `Spacer(flex: 100)`) gave the title ~3/103 of the free width —
  // measured at 7.5px, so every task name collapsed to an ellipsis.
  //
  // The checkbox-position tests above all still passed through that
  // regression, because none of them looked at the title. This asserts
  // the other half of the same row.
  testWidgets('the task title gets real width, not a squeezed sliver', (
    tester,
  ) async {
    await pump(tester, categoriesById: {category.id: category});

    final title = tester.getRect(find.text('Deep work'));
    final row = tester.getRect(find.byKey(stackKey));

    expect(
      title.width,
      greaterThan(60.0),
      reason: 'title is ${title.width}px — too narrow to read',
    );
    // And it should occupy a real share of the row, not a token amount.
    expect(title.width, greaterThan(row.width * 0.2));
  });

  testWidgets('a long title ellipsizes instead of pushing the checkbox off', (
    tester,
  ) async {
    await pump(
      tester,
      categoriesById: {category.id: category},
      tasksOverride: [
        Task.create(
          title: 'An extremely long task title that cannot possibly fit',
          scheduledAt: DateTime(2026, 9, 4, 9),
          durationMinutes: 230,
          categoryId: BuiltInCategoryIds.work,
        ),
      ],
    );

    final checkbox = tester.getRect(find.byType(CompletionCheckbox));
    final row = tester.getRect(find.byKey(stackKey));

    // The title must yield to the checkbox, not shove it out of the row.
    expect(checkbox.right, lessThanOrEqualTo(row.right));
    expect(row.right - checkbox.right, lessThan(24.0));
  });

  // Reported directly: "The position of checkbox not right (regression on
  // zone view) (it's ok in tasks outside zones)."
  //
  // A task row INSIDE a zone card and a task row outside one both end in a
  // completion checkbox, and the two must line up down the same screen
  // edge. The zone card's own `spacingMd` right padding used to push the
  // nested one 16px further in (40px from the screen edge against a
  // standalone row's 24px), which reads as a misalignment down the column.
  testWidgets('a nested checkbox lines up with a standalone task row\'s', (
    tester,
  ) async {
    const screenWidth = 400.0;
    final pagePadding = AmbleTheme.light.spacingScreenPadding;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
        home: Scaffold(
          body: SizedBox(
            key: stackKey,
            width: screenWidth,
            child: Padding(
              // The page padding ZoneDayTimeline's own ListView applies.
              padding: EdgeInsets.symmetric(horizontal: pagePadding),
              child: ZoneContainerBlock(
                theme: AmbleTheme.light,
                zone: zone,
                tasks: [task],
                categoriesById: {category.id: category},
                stackAncestorKey: stackKey,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final checkbox = tester.getRect(find.byType(CompletionCheckbox));

    // A task row outside a zone is inset by the page padding alone, so its
    // checkbox ends exactly that far from the screen edge. The nested one
    // must match.
    expect(
      screenWidth - checkbox.right,
      closeTo(pagePadding, 0.5),
      reason:
          'nested checkbox is ${screenWidth - checkbox.right}px from the '
          'screen edge; a standalone row\'s is ${pagePadding}px',
    );
  });

  // Reported directly: "in zone view inside zone items have some
  // additional padding/margin left than name of zone" — clarified via
  // AskUserQuestion to mean specifically: with time/duration both hidden,
  // the task row's category badge (and title after it) should start at
  // the same x as the zone name in the header above, not sit offset from
  // it. The empty time-label `Text` inside `IntrinsicWidth` still reserved
  // real width even with nothing to show, plus its trailing gap, leaving
  // the badge ~31px in against the header's 16px.
  group('left alignment with time hidden', () {
    testWidgets(
      'the category badge lines up with the zone name when time is hidden',
      (tester) async {
        await pump(
          tester,
          timeRangeVisible: false,
          durationVisible: false,
          categoriesById: {category.id: category},
        );

        final headerRect = tester.getRect(
          find.textContaining('Morning ritual').first,
        );
        final badgeRect = tester.getRect(
          find
              .ancestor(of: find.text('💼'), matching: find.byType(Container))
              .first,
        );

        expect(
          badgeRect.left,
          closeTo(headerRect.left, 0.5),
          reason:
              'badge left=${badgeRect.left}, zone name left='
              '${headerRect.left}',
        );
      },
    );

    testWidgets(
      'the badge stays offset (unchanged) when time IS visible — no regression',
      (tester) async {
        await pump(tester, categoriesById: {category.id: category});

        final headerRect = tester.getRect(
          find.textContaining('Morning ritual').first,
        );
        final badgeRect = tester.getRect(
          find
              .ancestor(of: find.text('💼'), matching: find.byType(Container))
              .first,
        );

        // With a real time label rendering, the badge legitimately sits
        // well to the right of the header — this is the EXISTING,
        // unchanged behavior; only the empty-time-label case was ever
        // the bug.
        expect(badgeRect.left, greaterThan(headerRect.left + 50));
      },
    );

    testWidgets('drag still works via the badge when time is hidden', (
      tester,
    ) async {
      double? capturedTop;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
          home: Scaffold(
            body: SizedBox(
              key: stackKey,
              width: 400,
              child: ZoneContainerBlock(
                theme: AmbleTheme.light,
                zone: zone,
                tasks: [task],
                categoriesById: {category.id: category},
                stackAncestorKey: stackKey,
                timeRangeVisible: false,
                durationVisible: false,
                onRowDragStart: (_, top) => capturedTop = top,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final badgeCenter = tester.getCenter(find.text('💼'));
      final gesture = await tester.startGesture(badgeCenter);
      await gesture.moveBy(const Offset(0, 5));
      await tester.pump();
      await gesture.up();

      expect(
        capturedTop,
        isNotNull,
        reason: 'dragging the badge should have started a row drag',
      );
    });
  });

  // Requested directly: "Make zone names even subtler color (add new
  // subtler semantic token)." The zone card's own header title (this
  // container's version of the zone name) moves to colorTextTertiary,
  // along with the time-range text beside it — the two were deliberately
  // made to match on colorTextSecondary once before, and stay matched
  // here at the new, subtler value.
  testWidgets(
    'the zone header title and its time range render in colorTextTertiary',
    (tester) async {
      await pump(tester);

      final title = tester.widget<Text>(
        find.textContaining('Morning ritual').first,
      );
      final timeRange = tester.widget<Text>(
        find.textContaining('7:00 AM - 12:00 PM', findRichText: false),
      );

      expect(title.style?.color, AmbleTheme.light.colorTextTertiary);
      expect(timeRange.style?.color, AmbleTheme.light.colorTextTertiary);
    },
  );
}
