import 'package:flutter/material.dart';

import '../tokens/semantic_theme.dart';
import 'app_press_feedback.dart';

/// One setting on its own line: a leading icon, its values, and an optional
/// trailing control (a switch). The wide layout's form row, where a side
/// panel has room to list settings one per line instead of the phone's
/// wrapped chips. Each value opens its own picker beside it.
class AppFieldRow extends StatelessWidget {
  const AppFieldRow({
    super.key,
    required this.icon,
    required this.children,
    this.trailing,
  });

  /// A line with one value, the common case.
  factory AppFieldRow.single({
    Key? key,
    required IconData icon,
    required String label,
    required ValueSetter<BuildContext>? onTap,
    bool hasValue = true,
    Widget? trailing,
  }) => AppFieldRow(
    key: key,
    icon: icon,
    trailing: trailing,
    children: [AppFieldValue(label: label, hasValue: hasValue, onTap: onTap)],
  );

  final IconData icon;

  /// Usually [AppFieldValue]s, with plain text between them (an arrow).
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: theme.sizeButtonMd),
      child: Row(
        children: [
          Icon(icon, size: theme.spacingMd, color: theme.colorTextSecondary),
          SizedBox(width: theme.spacingSm),
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: theme.spacingXs,
              children: children,
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// A tappable value in an [AppFieldRow]: plain text with the shared press
/// response. Without a value it shows its placeholder in the quiet tone,
/// so an unset setting reads as an offer, not as data.
class AppFieldValue extends StatelessWidget {
  const AppFieldValue({
    super.key,
    required this.label,
    required this.onTap,
    this.hasValue = true,
  });

  final String label;

  /// Gets this value's own context, so a picker it opens anchors beside
  /// the value rather than beside the whole form.
  final ValueSetter<BuildContext>? onTap;
  final bool hasValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final onTap = this.onTap;
    return AppPressFeedback(
      onTap: onTap == null ? null : () => onTap(context),
      borderRadius: BorderRadius.circular(theme.radiusSm),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacingSm,
          vertical: theme.spacingXs,
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textBody.copyWith(
            color: hasValue ? theme.colorTextPrimary : theme.colorTextTertiary,
          ),
        ),
      ),
    );
  }
}
