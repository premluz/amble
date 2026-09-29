import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_time_format.dart';
import 'package:amble/features/settings/appearance_settings_screen.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/shared/models/time_format.dart';
import 'package:amble/shared/providers/preferences_providers.dart';
import 'package:amble/shared/repositories/hive_preferences_repository.dart';
import 'package:amble/shared/repositories/preferences_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';

void main() {
  late Box<dynamic> box;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_time_format');
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapters();
    box = await Hive.openBox<dynamic>(
      'test_time_format_${DateTime.now().microsecondsSinceEpoch}',
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

  test('follows the device until chosen; the choice persists by name and '
      'survives a relaunch', () async {
    final first = container();
    expect(first.read(timeFormatSettingProvider), TimeFormatPreference.system);
    await first
        .read(timeFormatSettingProvider.notifier)
        .set(TimeFormatPreference.twentyFourHour);
    expect(
      first
          .read(preferencesRepositoryProvider)
          .getValue<String>(PreferenceKeys.timeFormat),
      'twentyFourHour',
    );
    expect(
      container().read(timeFormatSettingProvider),
      TimeFormatPreference.twentyFourHour,
    );
  });

  test('an unknown stored value falls back to following the device', () {
    expect(TimeFormatPreference.fromName('nope'), TimeFormatPreference.system);
    expect(TimeFormatPreference.fromName(null), TimeFormatPreference.system);
  });

  group('AppTimeFormat', () {
    Future<String> formatted(WidgetTester tester, bool? use24Hour) async {
      late String text;
      await tester.pumpWidget(
        MediaQuery(
          // A device set to 12-hour, to show the preference overriding it.
          data: const MediaQueryData(alwaysUse24HourFormat: false),
          child: Localizations(
            locale: const Locale('en', 'US'),
            delegates: const [
              DefaultMaterialLocalizations.delegate,
              DefaultWidgetsLocalizations.delegate,
            ],
            child: AppTimeFormat(
              use24Hour: use24Hour,
              child: Builder(
                builder: (context) {
                  text = const TimeOfDay(hour: 21, minute: 0).format(context);
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      );
      return text;
    }

    testWidgets('24-hour shows 21:00; 12-hour shows 9:00 PM; system keeps '
        "the device's own", (tester) async {
      expect(await formatted(tester, true), '21:00');
      expect(await formatted(tester, false), '9:00 PM');
      expect(await formatted(tester, null), '9:00 PM');
    });
  });

  testWidgets('Appearance offers System / 12-hour / 24-hour and saves the '
      'choice', (tester) async {
    final c = container();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: ThemeData(extensions: [AmbleTheme.light]),
          home: const AppearanceSettingsScreen(),
        ),
      ),
    );
    expect(find.text('Time format'), findsOneWidget);
    for (final label in ['System', '12-hour', '24-hour']) {
      expect(find.text(label), findsWidgets);
    }
    await tester.ensureVisible(find.text('24-hour'));
    // The choice is a real Hive write: let it land on the real clock.
    await tester.runAsync(() async {
      await tester.tap(find.text('24-hour'));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    expect(
      c.read(timeFormatSettingProvider),
      TimeFormatPreference.twentyFourHour,
    );
  });
}
