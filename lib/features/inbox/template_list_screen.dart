import 'package:flutter/material.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_icon_button.dart';
import 'task_template_form.dart';
import 'template_list_view.dart';

/// Opens the Templates list as its own pushed page — mirrors
/// `zone_list_screen.dart`'s `ZoneListScreen`/`showZoneListScreen` shape
/// exactly (back button, heading, "+" to add), so Settings' new "Manage"
/// section can link to Templates the same way it already links to Zones
/// and Categories. `TemplateListView` itself already exists as the Inbox
/// Manage tab's own Templates sub-tab body — this only adds the missing
/// full-screen wrapper around it, the one piece Zones/Categories already
/// had and Templates didn't.
Future<void> showTemplateListScreen(BuildContext context) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (context) => const TemplateListScreen()),
  );
}

class TemplateListScreen extends StatelessWidget {
  const TemplateListScreen({super.key});

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
                  Expanded(child: Text('Templates', style: theme.textHeadline)),
                  AppIconButton(
                    icon: Icons.add_rounded,
                    onPressed: () => showTaskTemplateForm(context),
                  ),
                ],
              ),
            ),
            const Expanded(child: TemplateListView()),
          ],
        ),
      ),
    );
  }
}
