import 'package:amble/core/tokens/component_tokens.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_sub_nav.dart';
import 'package:amble/core/widgets/app_top_nav.dart';
import 'package:amble/features/inbox/inbox_section_filter_provider.dart';
import 'package:amble/features/inbox/inbox_section_tabs.dart';
import 'package:amble/features/timeline/app_calendar_header.dart';
import 'package:amble/features/tracked_behavior/tracked_period_calendar.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/shared/models/section.dart';
import 'package:amble/shared/models/tracked_behavior_view_mode.dart';
import 'package:amble/shared/providers/section_providers.dart';
import 'package:amble/shared/repositories/hive_section_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';

import '../../support/seeded_section_box.dart';

final _theme = AmbleTheme.light;

void main() {
  late Box<Section> sectionBox;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_inbox_sub_nav');
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapters();
    sectionBox = await openSectionBox(
      'test_sections_${DateTime.now().microsecondsSinceEpoch}',
    );
  });

  tearDown(() => sectionBox.close());

  Widget host(Widget child) => ProviderScope(
    overrides: [
      sectionRepositoryProvider.overrideWithValue(
        HiveSectionRepository(sectionBox),
      ),
    ],
    child: MaterialApp(
      theme: ThemeData(useMaterial3: true, extensions: [_theme]),
      home: Scaffold(
        body: Align(alignment: Alignment.topLeft, child: child),
      ),
    ),
  );

  /// Where [text] sits inside the heading widget [heading] — each heading
  /// sits at the top of its own page, so equal offsets mean the text does
  /// not move when switching pages.
  Offset offsetIn(WidgetTester tester, Finder heading, Finder text) =>
      tester.getTopLeft(text) - tester.getTopLeft(heading);

  testWidgets('the Inbox tabs sit exactly where the Day date and the Habits '
      'period heading sit, and all three share one heading type', (
    tester,
  ) async {
    await tester.pumpWidget(host(const AppCalendarHeader()));
    final day = find.byType(AppCalendarHeader);
    final dayText = find.descendant(of: day, matching: find.byType(Text)).first;
    final dayOffset = offsetIn(tester, day, dayText);
    final dayStyle = tester.widget<Text>(dayText).style!;

    await tester.pumpWidget(
      host(
        TrackedPeriodCalendar(
          viewMode: TrackedBehaviorViewMode.weekly,
          bodyBuilder: (_, _) => const SizedBox(height: 100),
        ),
      ),
    );
    final habits = find.byType(TrackedPeriodCalendar);
    final habitsText = find
        .descendant(of: habits, matching: find.byType(Text))
        .first;
    expect(offsetIn(tester, habits, habitsText), dayOffset);
    final habitsStyle = tester.widget<Text>(habitsText).style!;

    await tester.pumpWidget(
      host(
        InboxSectionTabs(
          targets: InboxSectionTabTargets(const [
            InboxSectionFilterAll(),
            InboxSectionFilterUnfiled(),
          ]),
        ),
      ),
    );
    await tester.pump();
    final things = find.byType(InboxSectionTabs);
    final all = find.text('All');
    expect(
      offsetIn(tester, things, all),
      dayOffset,
      reason: 'the heading line does not budge between pages',
    );
    final allStyle = tester.widget<Text>(all).style!;
    expect(
      allStyle,
      AppNavLabel.styleFor(
        _theme,
        selected: true,
        variant: AppNavLabelVariant.sub,
      ),
    );
    expect(
      tester.widget<Text>(find.text('Unfiled')).style,
      AppNavLabel.styleFor(
        _theme,
        selected: false,
        variant: AppNavLabelVariant.sub,
      ),
    );
    // One type across the three headings: the page-heading token, one
    // step below body, and the calendar's own (regular) weight.
    final heading = PageHeadingTokens.text(_theme);
    for (final style in [dayStyle, habitsStyle, allStyle]) {
      expect(style.fontSize, heading.fontSize);
      expect(style.fontWeight, heading.fontWeight);
      expect(style.fontFamily, heading.fontFamily);
    }
    expect(heading.fontSize, lessThan(_theme.textBody.fontSize!));
  });

  testWidgets('a tab being dragged over shows a wash behind it, without '
      'moving its text', (tester) async {
    Future<Offset> pumpWith(InboxSectionFilter? drop) async {
      await tester.pumpWidget(
        host(
          InboxSectionTabs(
            targets: InboxSectionTabTargets(const [
              InboxSectionFilterAll(),
              InboxSectionFilterUnfiled(),
            ]),
            dropTargetFilter: drop,
          ),
        ),
      );
      await tester.pump();
      return tester.getTopLeft(find.text('Unfiled'));
    }

    final resting = await pumpWith(null);
    final over = await pumpWith(const InboxSectionFilterUnfiled());
    final label = tester.widget<AppSubNavLabel>(
      find.ancestor(
        of: find.text('Unfiled'),
        matching: find.byType(AppSubNavLabel),
      ),
    );
    expect(label.highlighted, isTrue);
    expect(over, resting);
  });
}
