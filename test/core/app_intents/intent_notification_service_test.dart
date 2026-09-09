import 'dart:async';

import 'package:amble/core/app_intents/intent_notification_service.dart';
import 'package:amble/shared/models/task.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const notifications = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );
  late IntentNotificationService service;
  late List<String> calls;
  var foreground = false;
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    IOSFlutterLocalNotificationsPlugin.registerWith();
    service = IntentNotificationService();
    calls = [];
    foreground = false;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      appIntentsChannel,
      (call) async => foreground,
    );
    binding.defaultBinaryMessenger.setMockMethodCallHandler(notifications, (
      call,
    ) async {
      calls.add(call.method);
      if (call.method == 'checkPermissions') return {'isEnabled': true};
      if (call.method == 'requestPermissions') return true;
      return null;
    });
  });
  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      appIntentsChannel,
      null,
    );
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      notifications,
      null,
    );
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'headless Siri checks permission without consuming the foreground prompt',
    () async {
      expect(await service.requestPermissionIfNeeded(), isTrue);
      expect(calls, ['checkPermissions']);
      foreground = true;
      expect(await service.requestPermissionIfNeeded(), isTrue);
      expect(calls, ['checkPermissions', 'requestPermissions']);
      await service.requestPermissionIfNeeded();
      expect(calls.last, 'checkPermissions');
      expect(calls.where((c) => c == 'requestPermissions'), hasLength(1));
    },
  );

  test(
    'drain waits for the real native side effect before intent completion',
    () async {
      final cancellation = Completer<void>();
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        notifications,
        (_) => cancellation.future,
      );
      final write = service.syncForTask(Task.captured(title: 'Note'));
      var drained = false;
      final drain = service.drain().then((_) => drained = true);
      await Future<void>.delayed(Duration.zero);
      expect(drained, isFalse);
      cancellation.complete();
      await write;
      await drain;
      expect(drained, isTrue);
    },
  );

  test(
    'notification failure releases drain and remains visible to its caller',
    () async {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(notifications, (
        _,
      ) async {
        throw PlatformException(code: 'unavailable');
      });
      await expectLater(
        service.syncForTask(Task.captured(title: 'Note')),
        throwsA(isA<PlatformException>()),
      );
      await service.drain();
    },
  );
}
