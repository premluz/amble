import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../../core/feature_flags.dart';
import '../../core/tokens/semantic_theme.dart';
import '../inbox/template_list_screen.dart';
import '../task_detail/category_list_screen.dart';
import '../zones/zone_list_screen.dart';
import 'about_settings_screen.dart';
import 'appearance_settings_screen.dart';
import 'backup_settings_screen.dart';
import 'calendars_settings_screen.dart';
import 'developer_settings_screen.dart';
import 'permissions_settings_screen.dart';
import 'settings_detail_scaffold.dart';
import 'settings_panel.dart';
import 'slack_settings_screen.dart';

/// The real home for export/import and notification preferences — the
/// permanent replacement for Phase 7's temporary "Backup" bottom-nav tab.
/// Per docs/SCOPE.md's Inbox/Timeline/Settings nav structure, this is
/// itself the third persistent tab, not a screen reached another way.
///
/// Restructured to a grouped list of buttons, each pushing its own full
/// page (back button + title) — requested directly, mirroring the
/// existing "Manage zones"/"Manage categories" pattern generalized across
/// every section rather than one long scrolling page of inline panels.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;

    return Container(
      color: theme.colorSurfacePrimary,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(theme.spacingScreenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Settings', style: theme.textHeadline),
              SizedBox(height: theme.spacingLg),

              SettingsPanel(
                theme: theme,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SettingsLinkRow(
                      label: 'Permissions',
                      onTap: () => showPermissionsSettingsScreen(context),
                    ),
                    SizedBox(height: theme.spacingMd),
                    SettingsLinkRow(
                      label: 'Appearance',
                      onTap: () => showAppearanceSettingsScreen(context),
                    ),
                  ],
                ),
              ),

              SizedBox(height: theme.spacingMd),
              SettingsPanel(
                theme: theme,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (FeatureFlags.zoneEnabled) ...[
                      SettingsLinkRow(
                        label: 'Zones',
                        onTap: () => showZoneListScreen(context),
                      ),
                      SizedBox(height: theme.spacingMd),
                    ],
                    SettingsLinkRow(
                      label: 'Templates',
                      onTap: () => showTemplateListScreen(context),
                    ),
                    SizedBox(height: theme.spacingMd),
                    SettingsLinkRow(
                      label: 'Categories',
                      onTap: () => showCategoryListScreen(context),
                    ),
                  ],
                ),
              ),

              SizedBox(height: theme.spacingMd),
              SettingsPanel(
                theme: theme,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SettingsLinkRow(
                      label: 'Calendars',
                      onTap: () => showCalendarsSettingsScreen(context),
                    ),
                    SizedBox(height: theme.spacingMd),
                    SettingsLinkRow(
                      label: 'Slack',
                      onTap: () => showSlackSettingsScreen(context),
                    ),
                  ],
                ),
              ),

              SizedBox(height: theme.spacingMd),
              SettingsPanel(
                theme: theme,
                child: SettingsLinkRow(
                  label: 'Backup',
                  onTap: () => showBackupSettingsScreen(context),
                ),
              ),

              SizedBox(height: theme.spacingMd),
              SettingsPanel(
                theme: theme,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SettingsLinkRow(
                      label: 'About',
                      onTap: () => showAboutSettingsScreen(context),
                    ),
                    // kDebugMode, not FeatureFlags: this isn't a product
                    // feature to gate per-build, it's a developer
                    // convenience that must never exist in a real build
                    // at all — kDebugMode is compile-time false in every
                    // release/profile build, so this row (including its
                    // handler and the whole Developer page it reaches)
                    // dead-code-eliminates the same way a
                    // FeatureFlags-gated subtree does. See
                    // docs/DECISIONS.md.
                    if (kDebugMode) ...[
                      SizedBox(height: theme.spacingMd),
                      SettingsLinkRow(
                        label: 'Developer',
                        onTap: () => showDeveloperSettingsScreen(context),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
