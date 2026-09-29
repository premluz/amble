import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/inbox/voice_capture_provider.dart';
import 'package:amble/features/inbox/voice_capture_screen_parts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('plugin.csdcorp.com/speech_to_text');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'when the recognizer cannot start (permission denied, no '
    'recognizer), the session says so instead of passing for listening',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            _channel,
            (call) async => call.method == 'initialize' ? false : null,
          );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(_channel, null),
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final keepAlive = container.listen(voiceCaptureProvider, (_, _) {});
      addTearDown(keepAlive.close);

      await container.read(voiceCaptureProvider.notifier).startListening();

      expect(
        container.read(voiceCaptureProvider).status,
        VoiceCaptureStatus.unavailable,
      );
    },
  );

  testWidgets('the status card reads "Can\'t listen" with what to do', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VoiceCaptureStatusCard(
          theme: AmbleTheme.dark,
          state: const VoiceCaptureState(
            status: VoiceCaptureStatus.unavailable,
          ),
        ),
      ),
    );
    expect(find.text('Can\'t listen'), findsOneWidget);
    expect(find.textContaining('Settings'), findsOneWidget);
    expect(find.text('Listening'), findsNothing);
  });
}
