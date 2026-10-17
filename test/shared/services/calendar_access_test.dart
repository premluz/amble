import 'package:amble/features/settings/calendars_settings_screen.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/shared/providers/calendar_providers.dart';
import 'package:amble/shared/services/calendar_permission_service.dart';
import 'package:amble/shared/services/system_settings_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_device_calendar_plugin.dart';

/// Records the calls instead of reaching the OS.
class _RecordingSettings extends SystemSettingsService {
  _RecordingSettings({this.opens = true});

  final bool opens;
  int opened = 0;

  @override
  Future<bool> openCalendarSettings() async {
    opened++;
    return opens;
  }
}

void main() {
  group('CalendarPermissionService.access', () {
    test('granted when the plugin already has permission', () async {
      final plugin = FakeDeviceCalendarPlugin();
      expect(
        await CalendarPermissionService(plugin).access(),
        CalendarAccess.granted,
      );
    });

    test('denied when the user has said no', () async {
      final plugin = FakeDeviceCalendarPlugin()..permissionGranted = false;
      expect(
        await CalendarPermissionService(plugin).access(),
        CalendarAccess.denied,
      );
    });

    test('unavailable when the platform has no calendar', () async {
      final plugin = FakeDeviceCalendarPlugin()..platformSupported = false;
      expect(
        await CalendarPermissionService(plugin).access(),
        CalendarAccess.unavailable,
      );
    });
  });

  group('SystemSettingsService', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel(SystemSettingsService.channelName);

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('asks the platform to open the calendar settings', () async {
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call.method);
            return true;
          });
      expect(await const SystemSettingsService().openCalendarSettings(), true);
      expect(calls, ['openCalendarSettings']);
    });

    test('reports false where the platform has no handler', () async {
      expect(
        await const SystemSettingsService().openCalendarSettings(),
        isFalse,
      );
    });
  });

  group('Calendars settings screen', () {
    Future<_RecordingSettings> pump(
      WidgetTester tester,
      FakeDeviceCalendarPlugin plugin, {
      bool settingsOpen = true,
    }) async {
      final settings = _RecordingSettings(opens: settingsOpen);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deviceCalendarPluginProvider.overrideWithValue(plugin),
            systemSettingsServiceProvider.overrideWithValue(settings),
          ],
          child: MaterialApp(
            theme: ThemeData(extensions: [AmbleTheme.light]),
            home: const CalendarsSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return settings;
    }

    testWidgets('denied: Enable permission replaces "no calendar detected" '
        'and opens settings', (tester) async {
      final plugin = FakeDeviceCalendarPlugin()..permissionGranted = false;
      final settings = await pump(tester, plugin);

      expect(find.text('Enable permission'), findsOneWidget);
      expect(find.textContaining('No calendar detected'), findsNothing);

      await tester.tap(find.text('Enable permission'));
      await tester.pumpAndSettle();
      expect(settings.opened, 1);
      expect(find.textContaining('Could not open settings'), findsNothing);
    });

    testWidgets('denied and settings cannot open: tells the user where to '
        'go', (tester) async {
      final plugin = FakeDeviceCalendarPlugin()..permissionGranted = false;
      await pump(tester, plugin, settingsOpen: false);
      await tester.tap(find.text('Enable permission'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Could not open settings'), findsOneWidget);
    });

    testWidgets('allowed but no calendars: "no calendar detected", no '
        'button', (tester) async {
      await pump(tester, FakeDeviceCalendarPlugin());
      expect(find.textContaining('No calendar detected'), findsOneWidget);
      expect(find.text('Enable permission'), findsNothing);
    });

    testWidgets('a platform with no calendar: "no calendar detected", no '
        'button', (tester) async {
      await pump(tester, FakeDeviceCalendarPlugin()..platformSupported = false);
      expect(find.textContaining('No calendar detected'), findsOneWidget);
      expect(find.text('Enable permission'), findsNothing);
    });

    testWidgets('looks again when the app returns from settings', (
      tester,
    ) async {
      final plugin = FakeDeviceCalendarPlugin()..permissionGranted = false;
      await pump(tester, plugin);
      expect(find.text('Enable permission'), findsOneWidget);

      plugin.permissionGranted = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.text('Enable permission'), findsNothing);
      expect(find.textContaining('No calendar detected'), findsOneWidget);
    });
  });
}
