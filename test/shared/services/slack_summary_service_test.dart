import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/services/slack_summary_service.dart';

void main() {
  group('buildMorningSummaryText', () {
    test('empty task list produces a friendly no-tasks message', () {
      expect(
        buildMorningSummaryText(const []),
        'Good morning! Nothing on today\'s schedule.',
      );
    });

    test('a single scheduled task lists its time and title', () {
      final task = Task.create(
        title: 'Stand-up',
        scheduledAt: DateTime(2026, 9, 2, 9, 30),
        durationMinutes: 15,
        categoryId: BuiltInCategoryIds.work,
      );

      final text = buildMorningSummaryText([task]);

      expect(text, contains('Good morning!'));
      expect(text, contains("today's plan (1 task)"));
      expect(text, contains('• 09:30 — Stand-up'));
    });

    test('multiple tasks are sorted by scheduled time, not input order', () {
      final later = Task.create(
        title: 'Lunch',
        scheduledAt: DateTime(2026, 9, 2, 12, 0),
        durationMinutes: 30,
        categoryId: BuiltInCategoryIds.personal,
      );
      final earlier = Task.create(
        title: 'Stand-up',
        scheduledAt: DateTime(2026, 9, 2, 9, 0),
        durationMinutes: 15,
        categoryId: BuiltInCategoryIds.work,
      );

      final text = buildMorningSummaryText([later, earlier]);
      final standupLine = text.indexOf('Stand-up');
      final lunchLine = text.indexOf('Lunch');

      expect(standupLine, lessThan(lunchLine));
      expect(text, contains('(2 tasks)'));
    });

    test('an unscheduled (Inbox) task is excluded from the summary', () {
      final scheduled = Task.create(
        title: 'Stand-up',
        scheduledAt: DateTime(2026, 9, 2, 9, 0),
        durationMinutes: 15,
        categoryId: BuiltInCategoryIds.work,
      );
      final inboxItem = Task.captured(title: 'Someday idea');

      final text = buildMorningSummaryText([scheduled, inboxItem]);

      expect(text, contains('Stand-up'));
      expect(text, isNot(contains('Someday idea')));
      expect(text, contains('(1 task)'));
    });
  });

  group('buildSlackPayload', () {
    test('always includes text', () {
      final payload = buildSlackPayload(text: 'Hello');
      expect(payload['text'], 'Hello');
    });

    test('username/icon_emoji OMITTED entirely when null', () {
      final payload = buildSlackPayload(text: 'Hello');
      expect(payload.containsKey('username'), isFalse);
      expect(payload.containsKey('icon_emoji'), isFalse);
    });

    test('username/icon_emoji OMITTED entirely when blank/whitespace-only', () {
      final payload = buildSlackPayload(
        text: 'Hello',
        displayName: '   ',
        iconEmoji: '',
      );
      expect(payload.containsKey('username'), isFalse);
      expect(payload.containsKey('icon_emoji'), isFalse);
    });

    test('username/icon_emoji PRESENT and trimmed when set', () {
      final payload = buildSlackPayload(
        text: 'Hello',
        displayName: '  Amble  ',
        iconEmoji: '  :sunrise:  ',
      );
      expect(payload['username'], 'Amble');
      expect(payload['icon_emoji'], ':sunrise:');
    });

    test('setting only one of the two omits the other', () {
      final payload = buildSlackPayload(text: 'Hello', displayName: 'Amble');
      expect(payload['username'], 'Amble');
      expect(payload.containsKey('icon_emoji'), isFalse);
    });
  });

  group('postToSlackWebhook', () {
    test(
      'empty URL throws SlackWebhookException without any HTTP call',
      () async {
        var callCount = 0;
        final client = MockClient((request) async {
          callCount++;
          return http.Response('', 200);
        });

        await expectLater(
          () => postToSlackWebhook(
            webhookUrl: '',
            payload: const {'text': 'hi'},
            client: client,
          ),
          throwsA(isA<SlackWebhookException>()),
        );
        expect(callCount, 0);
      },
    );

    test('a non-Slack URL throws SlackWebhookException without any HTTP '
        'call', () async {
      var callCount = 0;
      final client = MockClient((request) async {
        callCount++;
        return http.Response('', 200);
      });

      await expectLater(
        () => postToSlackWebhook(
          webhookUrl: 'https://example.com/not-slack',
          payload: const {'text': 'hi'},
          client: client,
        ),
        throwsA(isA<SlackWebhookException>()),
      );
      expect(callCount, 0);
    });

    test('a malformed URL (no scheme) throws SlackWebhookException', () async {
      await expectLater(
        () => postToSlackWebhook(
          webhookUrl: 'not a url at all',
          payload: const {'text': 'hi'},
          client: MockClient((request) async => http.Response('', 200)),
        ),
        throwsA(isA<SlackWebhookException>()),
      );
    });

    test('a valid Slack webhook URL posts the JSON payload and succeeds '
        'on 200', () async {
      Uri? capturedUri;
      String? capturedBody;
      final client = MockClient((request) async {
        capturedUri = request.url;
        capturedBody = request.body;
        return http.Response('ok', 200);
      });

      await postToSlackWebhook(
        webhookUrl: 'https://hooks.slack.com/services/T00/B00/XXX',
        payload: const {'text': 'Hello'},
        client: client,
      );

      expect(
        capturedUri.toString(),
        'https://hooks.slack.com/services/T00/B00/XXX',
      );
      expect(capturedBody, '{"text":"Hello"}');
    });

    test('a non-2xx response throws SlackWebhookException with the status '
        'code', () async {
      final client = MockClient(
        (request) async => http.Response('invalid_token', 404),
      );

      await expectLater(
        () => postToSlackWebhook(
          webhookUrl: 'https://hooks.slack.com/services/T00/B00/XXX',
          payload: const {'text': 'Hello'},
          client: client,
        ),
        throwsA(
          isA<SlackWebhookException>().having(
            (e) => e.message,
            'message',
            contains('404'),
          ),
        ),
      );
    });

    test('a network failure (client throws) surfaces as '
        'SlackWebhookException, not a raw exception', () async {
      final client = MockClient((request) async {
        throw const SocketExceptionStub();
      });

      await expectLater(
        () => postToSlackWebhook(
          webhookUrl: 'https://hooks.slack.com/services/T00/B00/XXX',
          payload: const {'text': 'Hello'},
          client: client,
        ),
        throwsA(isA<SlackWebhookException>()),
      );
    });
  });
}

/// A minimal stand-in for `SocketException` — doesn't need `dart:io`'s real
/// type, just something that isn't already a [SlackWebhookException], to
/// prove the generic catch-and-wrap path works for an arbitrary thrown
/// error, not only ones this package already knows about.
class SocketExceptionStub implements Exception {
  const SocketExceptionStub();

  @override
  String toString() => 'SocketExceptionStub: network unreachable';
}
