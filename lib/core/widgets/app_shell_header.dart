import 'package:flutter/material.dart';
import '../tokens/semantic_theme.dart';
import '../tokens/motion_primitives.dart';
import 'app_button.dart';
import 'app_shell_chrome.dart';

/// One geometry contract for main navigation and contextual route tabs.
class AppShellHeader extends StatelessWidget {
  const AppShellHeader({super.key, required this.controller, required this.child});
  final AppShellChromeController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    return SizedBox(
      height: appButtonHeightFor(theme, AppButtonSize.md),
      child: ListenableBuilder(listenable: controller, builder: (context, _) {
        final editing = controller.header != null;
        return AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero :
            const Duration(milliseconds: MotionPrimitives.durationViewCrossfadeMs),
          switchInCurve: theme.curveStandard,
          switchOutCurve: theme.curveStandard,
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.centerLeft,
            children: [
              for (final old in previous)
                ExcludeFocus(child: ExcludeSemantics(child: IgnorePointer(child: old))),
              ?current,
            ],
          ),
          child: KeyedSubtree(key: ValueKey(editing), child: controller.header ?? child),
        );
      }),
    );
  }
}
