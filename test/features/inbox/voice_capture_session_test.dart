import 'package:amble/features/inbox/voice_capture_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

const _channel = MethodChannel('plugin.csdcorp.com/speech_to_text');

/// Delivers a platform → Dart call on the speech channel, as the native
/// recognizer does when it reports a status.
Future<void> _fromPlatform(String method, Object? arguments) async {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  await messenger.handlePlatformMessage(
    _channel.name,
    _channel.codec.encodeMethodCall(MethodCall(method, arguments)),
    (_) {},
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var listens = 0;

  setUp(() {
    listens = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          if (call.method == 'listen') listens++;
          return switch (call.method) {
            'initialize' || 'listen' || 'has_permission' => true,
            _ => null,
          };
        });
  });

  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null),
  );

  test('a session still reopens when the platform ends it, even though '
      'the shared recognizer was already initialized elsewhere first '
      '(Quick Capture\'s mic, or an earlier voice session)', () async {
    // Quick Capture initializes the same singleton, with no listeners.
    expect(await stt.SpeechToText().initialize(), isTrue);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final keepAlive = container.listen(voiceCaptureProvider, (_, _) {});
    addTearDown(keepAlive.close);

    await container.read(voiceCaptureProvider.notifier).startListening();
    expect(listens, 1);

    await _fromPlatform('notifyStatus', stt.SpeechToText.listeningStatus);
    await _fromPlatform('notifyStatus', stt.SpeechToText.notListeningStatus);
    // The reopen is debounced (the plugin tears the old recognizer down).
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(listens, 2, reason: 'reopened the session the platform ended');
    expect(
      container.read(voiceCaptureProvider).status,
      VoiceCaptureStatus.listening,
    );
  });

  test(
    'a disposed session unhooks itself from the shared recognizer',
    () async {
      final container = ProviderContainer();
      final keepAlive = container.listen(voiceCaptureProvider, (_, _) {});
      await container.read(voiceCaptureProvider.notifier).startListening();
      expect(stt.SpeechToText().statusListener, isNotNull);
      keepAlive.close();
      container.dispose();
      expect(stt.SpeechToText().statusListener, isNull);
      expect(stt.SpeechToText().errorListener, isNull);
    },
  );
}
