import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/timeline_clock.dart';
import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_selectable_chip.dart';
import '../../shared/services/assistant/assistant_activity.dart';
import '../../shared/services/assistant/assistant_tool.dart';
import 'claude_setup_panels.dart';

/// Example questions, tapped to copy into Claude.
const claudeExampleQuestions = [
  'Find me four one-hour slots this week',
  "What's important today?",
  'Move my 3pm to the first free hour tomorrow',
];

/// Connected: what Claude may do, ideas to try, what it has done (with
/// Undo), Disconnect, and the technical details behind "Advanced".
class ClaudeConnectedPanel extends StatefulWidget {
  const ClaudeConnectedPanel({
    super.key,
    required this.permission,
    required this.onPermissionChanged,
    required this.activity,
    required this.onUndo,
    required this.onDisconnect,
    required this.advancedSnippet,
  });

  final AssistantPermission permission;
  final ValueChanged<AssistantPermission> onPermissionChanged;
  final List<AssistantActivity> activity;
  final Future<void> Function(AssistantActivity) onUndo;
  final VoidCallback onDisconnect;

  /// The command for Claude Code and similar tools; shown only under
  /// Advanced.
  final String advancedSnippet;

  @override
  State<ClaudeConnectedPanel> createState() => _ClaudeConnectedPanelState();
}

class _ClaudeConnectedPanelState extends State<ClaudeConnectedPanel> {
  String? _copied;
  bool _advanced = false;

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) setState(() => _copied = text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClaudeMessage(
          title: 'Connected to Claude',
          body: '${permissionLabel(widget.permission)}. Change it any time.',
        ),
        SizedBox(height: theme.spacingSm),
        PermissionChoice(
          selected: widget.permission,
          onChanged: widget.onPermissionChanged,
        ),
        SizedBox(height: theme.spacingLg),
        const ClaudeMessage(
          title: 'Try asking Claude',
          body: 'Tap one to copy it.',
        ),
        SizedBox(height: theme.spacingSm),
        Wrap(
          spacing: theme.spacingSm,
          runSpacing: theme.spacingSm,
          children: [
            for (final question in claudeExampleQuestions)
              AppSelectableChip(
                label: question,
                selected: _copied == question,
                onTap: () => _copy(question),
              ),
          ],
        ),
        SizedBox(height: theme.spacingLg),
        _ActivityList(entries: widget.activity, onUndo: widget.onUndo),
        SizedBox(height: theme.spacingLg),
        Wrap(
          spacing: theme.spacingSm,
          runSpacing: theme.spacingSm,
          children: [
            AppButton(
              label: 'Disconnect',
              variant: AppButtonVariant.secondary,
              onPressed: widget.onDisconnect,
            ),
            AppButton(
              label: _advanced ? 'Hide advanced' : 'Advanced',
              variant: AppButtonVariant.ghost,
              onPressed: () => setState(() => _advanced = !_advanced),
            ),
          ],
        ),
        if (_advanced) ...[
          SizedBox(height: theme.spacingSm),
          _Advanced(snippet: widget.advancedSnippet, onCopy: _copy),
        ],
      ],
    );
  }
}

class _ActivityList extends StatelessWidget {
  const _ActivityList({required this.entries, required this.onUndo});

  final List<AssistantActivity> entries;
  final Future<void> Function(AssistantActivity) onUndo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final style = theme.textBody.copyWith(color: theme.colorTextSecondary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ClaudeMessage(
          title: "What Claude has done",
          body: 'Changes Claude made to your plan since Amble opened.',
        ),
        SizedBox(height: theme.spacingSm),
        if (entries.isEmpty) Text('Nothing yet.', style: style),
        for (final entry in entries)
          Padding(
            padding: EdgeInsets.only(bottom: theme.spacingXs),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${timelineClock(context, TimeOfDay.fromDateTime(entry.at))}'
                    ' · ${entry.summary}',
                    style: style,
                  ),
                ),
                if (entry.undo != null)
                  AppButton(
                    label: 'Undo',
                    variant: AppButtonVariant.ghost,
                    onPressed: () => onUndo(entry),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Advanced extends StatelessWidget {
  const _Advanced({required this.snippet, required this.onCopy});

  final String snippet;
  final ValueChanged<String> onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'For Claude Code and other tools that accept a local address. '
          'Keep this private: it lets a tool use Amble as you.',
          style: theme.textCaption.copyWith(color: theme.colorTextSecondary),
        ),
        SizedBox(height: theme.spacingSm),
        AppButton(
          label: 'Copy for Claude Code',
          variant: AppButtonVariant.secondary,
          onPressed: () => onCopy(snippet),
        ),
      ],
    );
  }
}
