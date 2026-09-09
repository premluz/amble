import 'dart:async';

import 'package:amble/core/app_intents/app_intent_channel.dart';
import 'package:amble/core/app_intents/intent_notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'intent_test_store.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late IntentTestStore store;
  var readySignals = 0;
  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    store = IntentTestStore();
    await store.open();
    readySignals = 0;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(appIntentsChannel, (
      call,
    ) async {
      if (call.method == 'ready') readySignals++;
      return null;
    });
    await registerAppIntentChannel(store.container);
  });
  tearDown(() async {
    appIntentsChannel.setMethodCallHandler(null);
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      appIntentsChannel,
      null,
    );
    debugDefaultTargetPlatformOverride = null;
    await store.close();
  });

  Future<Object?> invoke(String method, Map<String, Object> args) {
    const codec = StandardMethodCodec();
    final result = Completer<Object?>();
    binding.defaultBinaryMessenger.handlePlatformMessage(
      appIntentsChannel.name,
      codec.encodeMethodCall(MethodCall(method, args)),
      (data) {
        try {
          result.complete(codec.decodeEnvelope(data!));
        } catch (error, stack) {
          result.completeError(error, stack);
        }
      },
    );
    return result.future;
  }

  test('ready handshake and native method envelope reach persistent Dart handler without UI', () async {
    expect(readySignals, 1);
    expect(
      await invoke('addNote', {'text': 'Siri bridge note'}),
      contains('Added note'),
    );
    expect(store.tasks.values.single.title, 'Siri bridge note');
  });

  test('simultaneous overlapping zone requests serialize; failure does not poison queue', () async {
    final first = invoke('addZone', {
      'title': 'First',
      'startMinutes': 540,
      'endMinutes': 600,
    });
    final second = invoke('addZone', {
      'title': 'Second',
      'startMinutes': 570,
      'endMinutes': 630,
    });
    final rejected = expectLater(
      second,
      throwsA(
        isA<PlatformException>().having((e) => e.code, 'code', 'intent_input'),
      ),
    );
    await first;
    await rejected;
    expect(store.zones.length, 1);
    await invoke('addNote', {'text': 'Still works'});
    expect(store.tasks.length, 1);
  });
}
