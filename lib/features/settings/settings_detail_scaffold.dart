import 'package:flutter/material.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_icon_button.dart';

/// Shared "back button + title" chrome for every Settings sub-page —
/// mirrors `ZoneListScreen`'s own header exactly, so Permissions/
/// Appearance/Calendars/Slack/Backup/About/Developer all look and behave
/// like the pre-existing "Manage zones"/"Manage categories" pattern this
/// whole restructure is generalizing.
class SettingsDetailScaffold extends StatelessWidget {
  const SettingsDetailScaffold({
    super.key,
    required this.title,
    required this.body,
  });

  final String title;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;

    return Scaffold(
      backgroundColor: theme.colorSurfacePrimary,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.all(theme.spacingScreenPadding),
              child: Row(
                children: [
                  AppIconButton(
                    icon: Icons.arrow_back_rounded,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  SizedBox(width: theme.spacingMd),
                  Expanded(child: Text(title, style: theme.textHeadline)),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: theme.spacingScreenPadding,
                ).copyWith(bottom: theme.spacingScreenPadding),
                child: body,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One plain row on the top-level Settings screen — label and chevron
/// only (confirmed directly: no summary text under the label here, unlike
/// `_ManageLinkRow`), tapping through to a pushed sub-page.
class SettingsLinkRow extends StatelessWidget {
  const SettingsLinkRow({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textBody.copyWith(
                color: theme.colorTextPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: theme.colorTextSecondary),
        ],
      ),
    );
  }
}
