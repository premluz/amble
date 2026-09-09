import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/providers/notification_providers.dart';
import 'app_intent_service.dart';
import 'intent_notification_service.dart';

/// Called after the normal bootstrap has initialized Hive, registered adapters,
/// opened boxes and seeded categories. Native code starts that bootstrap even
/// without a FlutterViewController; no Workmanager/second Hive isolate is used.
Future<void> registerAppIntentChannel(ProviderContainer container) async {
  if (defaultTargetPlatform != TargetPlatform.iOS) return;
  final service = AppIntentService(container);
  final notifications = container.read(notificationServiceProvider);
  Future<void> queue = Future.value();
  appIntentsChannel.setMethodCallHandler((call) {
    // Serializes Siri writes, including validation + save, without holding
    // anything open during native parameter disambiguation.
    final result = queue.then<Object>((_) async {
      try {
        if (notifications is IntentNotificationService) {
          await notifications.drain();
        }
        final value = await service.handle(
          call.method,
          (call.arguments as Map?)?.cast<Object?, Object?>() ?? {},
        );
        if (notifications is IntentNotificationService) {
          await notifications.drain();
        }
        return value;
      } on AppIntentFailure catch (error) {
        throw PlatformException(code: 'intent_input', message: error.message);
      } catch (error, stack) {
        debugPrint('App Intent failed: $error\n$stack');
        throw PlatformException(
          code: 'intent_failed',
          message: 'Amble could not confirm completion. Check the app before trying again.',
        );
      }
    });
    queue = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  });
  await appIntentsChannel.invokeMethod<void>('ready');
}
