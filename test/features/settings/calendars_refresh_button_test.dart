import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/settings/calendars_settings_screen.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/shared/providers/calendar_providers.dart';
import 'package:amble/shared/providers/preferences_providers.dart';
import 'package:amble/shared/repositories/hive_preferences_repository.dart';
import 'package:device_calendar/device_calendar.dart' as dc;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';

import '../../support/fake_device_calendar_plugin.dart';

void main() {
  late Box<dynamic> prefs;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_calendars_refresh');
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapters();
    prefs = await Hive.openBox<dynamic>(
      'prefs_${DateTime.now().microsecondsSinceEpoch}',
    );
  });

  tearDown(() => prefs.deleteFromDisk());

  testWidgets('Refresh events re-reads every open calendar view', (
    tester,
  ) async {
    final plugin = FakeDeviceCalendarPlugin()
      ..calendars = [dc.Calendar(id: 'cal-1', name: 'Work')];
    final container = ProviderContainer(
      overrides: [
        deviceCalendarPluginProvider.overrideWithValue(plugin),
        preferencesRepositoryProvider.overrideWithValue(
          HivePreferencesRepository(prefs),
        ),
      ],
    );
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData(extensions: [AmbleTheme.light]),
          home: const CalendarsSettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Work'), findsWidgets);
    expect(container.read(externalCalendarRefreshProvider), 0);
    await tester.tap(find.text('Refresh events'));
    await tester.pumpAndSettle();

    expect(container.read(externalCalendarRefreshProvider), 1);
    expect(find.text('Events re-read from your calendars.'), findsOneWidget);
  });
}
