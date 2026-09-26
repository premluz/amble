import 'package:flutter/material.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_modal_route.dart';
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
  return pushRootScreenRoute<void>(
    context,
    (context) => const TemplateListScreen(),
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
                  AppButton(
                    icon: Icons.arrow_back_rounded,
                    onPressed: () => Navigator.of(context).pop(),
                    shape: AppButtonShape.circle,
                    // Ghost, not primary — app-wide button unification
                    // pass, requested directly ("only one primary [per
                    // screen]"); the add button below stays primary as
                    // this screen's one real action.
                    variant: AppButtonVariant.ghost,
                  ),
                  SizedBox(width: theme.spacingMd),
                  Expanded(child: Text('Templates', style: theme.textTitle)),
                  AppButton(
                    icon: Icons.add_rounded,
                    onPressed: () => showTaskTemplateForm(context),
                    shape: AppButtonShape.circle,
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
