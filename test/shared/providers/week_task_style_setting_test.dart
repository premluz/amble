import 'package:amble/core/tokens/component_tokens.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/settings/appearance_settings_screen.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/shared/providers/preferences_providers.dart';
import 'package:amble/shared/providers/week_task_style_setting.dart';
import 'package:amble/shared/repositories/hive_preferences_repository.dart';
import 'package:amble/shared/repositories/preferences_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';

void main() {
  late Box<dynamic> box;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_week_task_style');
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapters();
    box = await Hive.openBox<dynamic>(
      'test_week_task_style_${DateTime.now().microsecondsSinceEpoch}',
    );
  });

  tearDown(() => box.deleteFromDisk());

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        preferencesRepositoryProvider.overrideWithValue(
          HivePreferencesRepository(box),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('defaults to pills; the choice persists by name and survives a '
      'relaunch', () async {
    final first = container();
    expect(first.read(weekTaskStyleSettingProvider), WeekTaskStyle.pills);
    await first
        .read(weekTaskStyleSettingProvider.notifier)
        .set(WeekTaskStyle.blocks);
    expect(box.get(PreferenceKeys.weekTaskStyle), 'blocks');
    expect(
      container().read(weekTaskStyleSettingProvider),
      WeekTaskStyle.blocks,
    );
  });

  test('an unrecognised stored value falls back to pills', () async {
    await box.put(PreferenceKeys.weekTaskStyle, 'tiles');
    expect(container().read(weekTaskStyleSettingProvider), WeekTaskStyle.pills);
  });

  Future<void> pumpAppearance(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container(),
        child: MaterialApp(
          theme: ThemeData(extensions: [AmbleTheme.light]),
          home: const AppearanceSettingsScreen(),
        ),
      ),
    );
  }

  testWidgets('Appearance offers the week task style on the wide layout', (
    tester,
  ) async {
    await pumpAppearance(tester, ShellLayoutTokens.sideNavMinWindowWidth);
    await tester.scrollUntilVisible(find.text('Week task style'), 200);
    expect(find.text('Pills'), findsOneWidget);
    expect(find.text('Blocks'), findsOneWidget);
  });

  testWidgets('and not on a phone-width window', (tester) async {
    await pumpAppearance(tester, ShellLayoutTokens.sideNavMinWindowWidth - 1);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -2000));
    await tester.pump();
    expect(find.text('Week task style'), findsNothing);
    expect(find.text('Calendar grid lines'), findsOneWidget);
  });
}
