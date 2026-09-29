import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_press_feedback.dart';
import 'package:amble/core/widgets/app_sub_nav.dart';
import 'package:flutter/material.dart';

/// A page's sub nav (the Inbox sections): the main nav's own labels in the
/// page-heading slot. Tap a tab to select it; the "+" toggles a drop-target
/// wash on the last tab.
Widget subNavDemo(BuildContext context) => const _SubNavDemo();

class _SubNavDemo extends StatefulWidget {
  const _SubNavDemo();

  @override
  State<_SubNavDemo> createState() => _SubNavDemoState();
}

class _SubNavDemoState extends State<_SubNavDemo> {
  static const _tabs = ['All', 'Work', 'Home', 'Unfiled'];
  var _selected = 0;
  var _dropOverLast = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    return ColoredBox(
      color: theme.colorSurfaceTimeline,
      child: Align(
        alignment: Alignment.topLeft,
        child: AppSubNav(
          trailing: AppPressFeedback(
            onTap: () => setState(() => _dropOverLast = !_dropOverLast),
            child: Icon(
              Icons.add_rounded,
              size: theme.spacingMd,
              color: theme.colorTextTertiary,
            ),
          ),
          children: [
            for (var i = 0; i < _tabs.length; i++)
              AppSubNavLabel(
                label: _tabs[i],
                selected: i == _selected,
                highlighted: _dropOverLast && i == _tabs.length - 1,
                onTap: () => setState(() => _selected = i),
              ),
          ],
        ),
      ),
    );
  }
}
