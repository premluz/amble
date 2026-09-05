import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/task.dart';

/// Builds the morning-summary message text for [tasks] (already filtered to
/// the day being summarized — this function has no opinion on "today",
/// callers decide that). Pure and widget/IO-free, same "pure function,
/// caller wires it to real data" shape as `generateRecurrenceInstances`/
/// `resolveZoneContainment`, so the text itself is unit-testable without a
/// Hive box or a real HTTP call.
///
/// Deliberately plain text, not Slack Block Kit — per the work order's own
/// non-goal ("no rich formatting... plain readable text is enough").
/// [tasks] does not need to be pre-sorted; this sorts by `scheduledAt`
/// itself so a caller can pass an unsorted list straight from the
/// repository.
String buildMorningSummaryText(List<Task> tasks) {
  final scheduled = tasks.where((task) => task.scheduledAt != null).toList()
    ..sort((a, b) => a.scheduledAt!.compareTo(b.scheduledAt!));

  final buffer = StringBuffer('Good morning! ');
  if (scheduled.isEmpty) {
    buffer.write("Nothing on today's schedule.");
    return buffer.toString();
  }

  buffer.write(
    "Here's today's plan (${scheduled.length} "
    '${scheduled.length == 1 ? 'task' : 'tasks'}):\n',
  );
  for (final task in scheduled) {
    final time = _formatTimeOfDay(task.scheduledAt!);
    buffer.write('• $time — ${task.title}\n');
  }
  return buffer.toString().trimRight();
}

/// `HH:MM`, 24h — no `BuildContext`/`TimeOfDay.format` available here (this
/// runs in the background isolate too, where there's no widget tree at
/// all), so this is a small manual formatter rather than reaching for the
/// Flutter-only helper every other on-screen time label uses.
String _formatTimeOfDay(DateTime dateTime) {
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

/// Builds the JSON body for a Slack Incoming Webhook POST. `username`/
/// `icon_emoji` are OMITTED entirely (not sent as empty strings) when
/// [displayName]/[iconEmoji] are null or blank — requested directly: "if
/// left blank, omit those fields from the payload and let Slack use the
/// webhook's own configured default, don't invent a fallback name." An
/// empty-string value would override the webhook's own configured default
/// with an empty name, which is worse than not sending the field at all.
Map<String, dynamic> buildSlackPayload({
  required String text,
  String? displayName,
  String? iconEmoji,
}) {
  final payload = <String, dynamic>{'text': text};
  final trimmedName = displayName?.trim();
  if (trimmedName != null && trimmedName.isNotEmpty) {
    payload['username'] = trimmedName;
  }
  final trimmedEmoji = iconEmoji?.trim();
  if (trimmedEmoji != null && trimmedEmoji.isNotEmpty) {
    payload['icon_emoji'] = trimmedEmoji;
  }
  return payload;
}

/// Thrown by [postToSlackWebhook] for any failure — bad URL, network error,
/// or a non-2xx response — so callers can distinguish "nothing was sent"
/// from "sent successfully" without inspecting HTTP internals themselves.
/// [message] is written to be shown directly to the user on the manual
/// "Send test message" path.
class SlackWebhookException implements Exception {
  const SlackWebhookException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Posts [payload] to [webhookUrl] — a direct device-to-Slack POST, no
/// intermediary backend, matching the "no data leaves the device except
/// straight to the user's own webhook" scope. Throws
/// [SlackWebhookException] for every failure mode (blank/malformed URL,
/// non-Slack host, network failure, non-2xx response) so both call sites
/// (the manual test button, the background task) can handle failure their
/// own way — the manual path surfaces [SlackWebhookException.message]
/// directly, the background path catches and logs/skips silently (see
/// `core/background/background_tasks.dart`), per the work order's explicit
/// split.
Future<void> postToSlackWebhook({
  required String webhookUrl,
  required Map<String, dynamic> payload,
  http.Client? client,
}) async {
  final trimmedUrl = webhookUrl.trim();
  if (trimmedUrl.isEmpty) {
    throw const SlackWebhookException('No Slack webhook URL is set.');
  }

  final uri = Uri.tryParse(trimmedUrl);
  // A Slack Incoming Webhook is always `https://hooks.slack.com/...` —
  // validated here (not just "is this a URI at all") so a pasted non-Slack
  // URL, or a plain typo missing the scheme, fails with a specific message
  // rather than an opaque network error further down.
  if (uri == null ||
      !uri.isAbsolute ||
      uri.scheme != 'https' ||
      uri.host != 'hooks.slack.com') {
    throw const SlackWebhookException(
      'That doesn\'t look like a Slack Incoming Webhook URL — it should '
      'start with https://hooks.slack.com/...',
    );
  }

  final httpClient = client ?? http.Client();
  try {
    final response = await httpClient.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SlackWebhookException(
        'Slack rejected the message (HTTP ${response.statusCode}). Check '
        'the webhook URL is still valid.',
      );
    }
  } on SlackWebhookException {
    rethrow;
  } catch (e) {
    throw SlackWebhookException('Could not reach Slack: $e');
  } finally {
    if (client == null) httpClient.close();
  }
}
