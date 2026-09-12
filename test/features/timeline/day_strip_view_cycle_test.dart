import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/core/dev_config.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/timeline/day_strip.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/shared/providers/preferences_providers.dart';
import 'package:amble/shared/repositories/hive_preferences_repository.dart';

/// Requested directly: "we have setting zone view off in dev switching
/// timeline cycles, but actually that'd be list view off now, zone view
/// and task view are on always, and list view as default off." The old
/// `DevZoneViewInCycle` (which could remove Zone view from the cycle) is
/// replaced by `DevListViewInCycle` (which removes LIST view instead,
/// default false — i.e. List view is excluded from the cycle by default).
void main() {
  late Box<dynamic> preferencesBox;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_day_strip_view_cycle');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapters();
    }
    final suffix = DateTime.now().microsecondsSinceEpoch;
    preferencesBox = await Hive.openBox<dynamic>('test_preferences_$suffix');
  });

  tearDown(() async {
    await preferencesBox.close();
  });

  Future<void> pumpStrip(
    WidgetTester tester, {
    bool listViewInCycle = false,
  }) async {
    tester.view.physicalSize = const Size(430, 200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preferencesRepositoryProvider.overrideWithValue(
            HivePreferencesRepository(preferencesBox),
          ),
          devListViewInCycleProvider.overrideWith(
            () => _FixedDevListViewInCycle(listViewInCycle),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
          home: Scaffold(body: DayStrip(onCreatePressed: () {})),
        ),
      ),
    );
    await tester.pump();
  }

  IconData currentIcon(WidgetTester tester) =>
      tester.widget<Icon>(find.byType(Icon).first).icon!;

  testWidgets(
    'with List view excluded (default), the cycle button toggles only '
    'between Zone and Task view — List is never reached',
    (tester) async {
      await pumpStrip(tester);

      // Starting mode depends on ShowHourLabelsSetting/ZoneViewEnabledSetting
      // real defaults (Task, since both default off/false → showHourLabels
      // true). Tap through several times and confirm List view's own icon
      // never appears.
      final listIcon = Icons.view_agenda_outlined;
      for (var i = 0; i < 6; i++) {
        expect(currentIcon(tester), isNot(listIcon));
        await tester.runAsync(() async {
          await tester.tap(find.byType(IconButton).first);
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await tester.pump();
      }
    },
  );

  testWidgets(
    'with List view included (dev toggle on), the cycle reaches List view',
    (tester) async {
      await pumpStrip(tester, listViewInCycle: true);

      final listIcon = Icons.view_agenda_outlined;
      var sawListView = false;
      for (var i = 0; i < 6; i++) {
        if (currentIcon(tester) == listIcon) sawListView = true;
        await tester.runAsync(() async {
          await tester.tap(find.byType(IconButton).first);
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await tester.pump();
      }
      expect(
        sawListView,
        isTrue,
        reason: 'List view should be reachable once the dev toggle is on',
      );
    },
  );
}

class _FixedDevListViewInCycle extends DevListViewInCycle {
  _FixedDevListViewInCycle(this._value);

  final bool _value;

  @override
  bool build() => _value;
}
