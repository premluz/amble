import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/background/background_tasks.dart';
import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_switch.dart';
import '../../core/widgets/app_text_field.dart';
import '../../shared/providers/preferences_providers.dart';
import '../../shared/providers/task_providers.dart';
import '../../shared/services/slack_summary_service.dart';
import 'settings_detail_scaffold.dart';
import 'settings_panel.dart';

Future<void> showSlackSettingsScreen(BuildContext context) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (context) => const SlackSettingsScreen()),
  );
}

class SlackSettingsScreen extends ConsumerStatefulWidget {
  const SlackSettingsScreen({super.key});

  @override
  ConsumerState<SlackSettingsScreen> createState() =>
      _SlackSettingsScreenState();
}

class _SlackSettingsScreenState extends ConsumerState<SlackSettingsScreen> {
  // Slack morning-summary fields — plain TextEditingControllers (like every
  // other AppTextField user in the app) rather than reading the provider
  // value on every keystroke, so typing doesn't fight a rebuild. Committed
  // to PreferencesRepository on blur/submit, not per-keystroke — same
  // reasoning as every other free-text field in Settings/task-detail.
  late final TextEditingController _webhookController;
  late final TextEditingController _displayNameController;
  late final TextEditingController _iconEmojiController;
  String? _statusMessage;
  bool _statusIsError = false;
  bool _testBusy = false;

  @override
  void initState() {
    super.initState();
    _webhookController = TextEditingController(
      text: ref.read(slackWebhookUrlSettingProvider) ?? '',
    );
    _displayNameController = TextEditingController(
      text: ref.read(slackDisplayNameSettingProvider) ?? '',
    );
    _iconEmojiController = TextEditingController(
      text: ref.read(slackIconEmojiSettingProvider) ?? '',
    );
  }

  @override
  void dispose() {
    _webhookController.dispose();
    _displayNameController.dispose();
    _iconEmojiController.dispose();
    super.dispose();
  }

  Future<void> _saveWebhookUrl() async {
    await ref
        .read(slackWebhookUrlSettingProvider.notifier)
        .set(_webhookController.text);
  }

  Future<void> _saveDisplayName() async {
    await ref
        .read(slackDisplayNameSettingProvider.notifier)
        .set(_displayNameController.text);
  }

  Future<void> _saveIconEmoji() async {
    await ref
        .read(slackIconEmojiSettingProvider.notifier)
        .set(_iconEmojiController.text);
  }

  /// "Send test message now" — the important manual trigger the work order
  /// calls out explicitly, since it lets the feature be verified without
  /// depending on unreliable background timing, and gives immediate
  /// feedback on a bad webhook URL. Sends today's REAL summary (not a
  /// placeholder "hello world"), through the exact same
  /// `buildMorningSummaryText`/`buildSlackPayload`/`postToSlackWebhook`
  /// path the background task uses — so a successful test send is a
  /// genuine end-to-end proof the automatic one would also work, not a
  /// separate code path that could silently drift from it.
  Future<void> _sendTestMessage() async {
    setState(() {
      _testBusy = true;
      _statusMessage = null;
    });
    try {
      final webhookUrl = _webhookController.text;
      final today = DateTime.now();
      final todaysTasks = ref.read(taskListProvider).where((task) {
        final scheduledAt = task.scheduledAt;
        if (scheduledAt == null) return false;
        return scheduledAt.year == today.year &&
            scheduledAt.month == today.month &&
            scheduledAt.day == today.day;
      }).toList();
      final text = buildMorningSummaryText(todaysTasks);
      final payload = buildSlackPayload(
        text: text,
        displayName: _displayNameController.text,
        iconEmoji: _iconEmojiController.text,
      );
      await postToSlackWebhook(webhookUrl: webhookUrl, payload: payload);
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Test message sent — check Slack.';
        _statusIsError = false;
      });
    } on SlackWebhookException catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = e.message;
        _statusIsError = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Could not send test message: $e';
        _statusIsError = true;
      });
    } finally {
      if (mounted) setState(() => _testBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;

    return SettingsDetailScaffold(
      title: 'Slack',
      body: SettingsPanel(
        theme: theme,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sends a plain-text summary of today\'s tasks to a Slack '
              'channel every morning. This is a Slack Incoming Webhook URL '
              '— create one in Slack (Slack app settings → Incoming '
              'Webhooks) and paste it below. It is not an Amble-managed '
              'Slack connection; Amble never sees anything beyond the URL '
              'you paste here, and the message is sent directly from this '
              'device to that URL.',
              style: theme.textBody.copyWith(color: theme.colorTextSecondary),
            ),
            SizedBox(height: theme.spacingMd),
            AppTextField(
              controller: _webhookController,
              label: 'Slack webhook URL',
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _saveWebhookUrl(),
              onFocusChanged: (focused) {
                if (!focused) _saveWebhookUrl();
              },
            ),
            SizedBox(height: theme.spacingMd),
            AppTextField(
              controller: _displayNameController,
              label: 'Display name (optional)',
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _saveDisplayName(),
              onFocusChanged: (focused) {
                if (!focused) _saveDisplayName();
              },
            ),
            SizedBox(height: theme.spacingSm),
            AppTextField(
              controller: _iconEmojiController,
              label: 'Icon emoji (optional, e.g. :sunrise:)',
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _saveIconEmoji(),
              onFocusChanged: (focused) {
                if (!focused) _saveIconEmoji();
              },
            ),
            Padding(
              padding: EdgeInsets.only(top: theme.spacingXs),
              child: Text(
                'Left blank, Slack uses the webhook\'s own default name/icon.',
                style: theme.textCaption.copyWith(
                  color: theme.colorTextSecondary,
                ),
              ),
            ),
            SizedBox(height: theme.spacingMd),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Send automatically each morning',
                        style: theme.textBody.copyWith(
                          color: theme.colorTextPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: theme.spacingXs),
                      Text(
                        'Targets around ${morningSummaryTargetHour}am local '
                        'time. Delivery time isn\'t guaranteed, especially '
                        'on iOS — the operating system decides exactly '
                        'when background tasks actually run, and may '
                        'delay or skip a day entirely. Use "Send test '
                        'message now" below any time you want it right '
                        'away.',
                        style: theme.textBody.copyWith(
                          color: theme.colorTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: theme.spacingMd),
                AppSwitch(
                  value: ref.watch(slackSummaryEnabledSettingProvider),
                  onChanged: (value) async {
                    await ref
                        .read(slackSummaryEnabledSettingProvider.notifier)
                        .set(value);
                    await registerMorningSummaryTask(enabled: value);
                  },
                ),
              ],
            ),
            SizedBox(height: theme.spacingMd),
            AppButton(
              label: 'Send test message now',
              variant: AppButtonVariant.secondary,
              isLoading: _testBusy,
              onPressed: _testBusy ? null : _sendTestMessage,
            ),
            if (_statusMessage != null) ...[
              SizedBox(height: theme.spacingMd),
              Text(
                _statusMessage!,
                style: theme.textBody.copyWith(
                  color: _statusIsError
                      ? theme.colorTaskAlert
                      : theme.colorTextPrimary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
