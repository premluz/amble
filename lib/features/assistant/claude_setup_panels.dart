import 'package:flutter/material.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/tokens/type_primitives.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_selectable_chip.dart';
import '../../shared/services/assistant/assistant_tool.dart';

/// Plain-language copy for the two permission levels, shared by the setup
/// and connected states so they never drift.
String permissionLabel(AssistantPermission permission) => switch (permission) {
  AssistantPermission.read => 'See my plan',
  AssistantPermission.readWrite => 'See and update my plan',
};

String permissionDetail(AssistantPermission permission) => switch (permission) {
  AssistantPermission.read =>
    'Claude can read your tasks, zones and free time.',
  AssistantPermission.readWrite =>
    "Claude can also add and move tasks. It can't delete anything.",
};

/// A heading and a line of explanation, the shape every state starts with.
class ClaudeMessage extends StatelessWidget {
  const ClaudeMessage({super.key, required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textBody.copyWith(
            color: theme.colorTextPrimary,
            fontWeight: TypePrimitives.weightSemibold,
          ),
        ),
        SizedBox(height: theme.spacingXs),
        Text(
          body,
          style: theme.textBody.copyWith(color: theme.colorTextSecondary),
        ),
      ],
    );
  }
}

/// The two permission choices, with the selected one explained below.
class PermissionChoice extends StatelessWidget {
  const PermissionChoice({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final AssistantPermission selected;
  final ValueChanged<AssistantPermission> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: theme.spacingSm,
          runSpacing: theme.spacingSm,
          children: [
            for (final permission in AssistantPermission.values)
              AppSelectableChip(
                label: permissionLabel(permission),
                selected: permission == selected,
                inMutuallyExclusiveGroup: true,
                onTap: () => onChanged(permission),
              ),
          ],
        ),
        SizedBox(height: theme.spacingXs),
        Text(
          permissionDetail(selected),
          style: theme.textCaption.copyWith(color: theme.colorTextSecondary),
        ),
      ],
    );
  }
}

/// Not connected yet: what this does, what Claude may do, one button.
class ClaudeIntro extends StatelessWidget {
  const ClaudeIntro({
    super.key,
    required this.permission,
    required this.onPermissionChanged,
    required this.busy,
    required this.onConnect,
  });

  final AssistantPermission permission;
  final ValueChanged<AssistantPermission> onPermissionChanged;
  final bool busy;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ClaudeMessage(
          title: 'Ask Claude about your plan',
          body:
              "Let Claude see your plan and answer questions like 'Find me "
              "four one-hour slots this week'. Everything stays on this Mac.",
        ),
        SizedBox(height: theme.spacingMd),
        PermissionChoice(selected: permission, onChanged: onPermissionChanged),
        SizedBox(height: theme.spacingMd),
        AppButton(
          label: 'Connect to Claude',
          isLoading: busy,
          onPressed: busy ? null : onConnect,
        ),
      ],
    );
  }
}

/// A message with one or two buttons: the shape of every setup step that
/// needs the person to act (Claude missing, waiting, failed, reconnect).
class ClaudeStep extends StatelessWidget {
  const ClaudeStep({
    super.key,
    required this.title,
    required this.body,
    required this.action,
    required this.onAction,
    this.secondary,
    this.onSecondary,
    this.busy = false,
  });

  final String title;
  final String body;
  final String action;
  final VoidCallback onAction;
  final String? secondary;
  final VoidCallback? onSecondary;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final secondaryLabel = secondary;
    final secondaryTap = onSecondary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClaudeMessage(title: title, body: body),
        SizedBox(height: theme.spacingMd),
        Wrap(
          spacing: theme.spacingSm,
          runSpacing: theme.spacingSm,
          children: [
            AppButton(
              label: action,
              isLoading: busy,
              onPressed: busy ? null : onAction,
            ),
            if (secondaryLabel != null && secondaryTap != null)
              AppButton(
                label: secondaryLabel,
                variant: AppButtonVariant.secondary,
                onPressed: busy ? null : secondaryTap,
              ),
          ],
        ),
      ],
    );
  }
}
