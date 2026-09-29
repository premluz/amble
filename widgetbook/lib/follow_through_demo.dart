import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_button.dart';
import 'package:amble/core/widgets/app_follow_through.dart';
import 'package:amble/core/widgets/app_view_transition.dart';
import 'package:flutter/material.dart';

/// Pages slide with their key items following through: tap ‹ / › to move
/// between three pages. Rows trail the page (top first), and each card's
/// dots trail their card (the side leading the travel first).
Widget followThroughDemo(BuildContext context) => const _FollowThroughDemo();

class _FollowThroughDemo extends StatefulWidget {
  const _FollowThroughDemo();

  @override
  State<_FollowThroughDemo> createState() => _FollowThroughDemoState();
}

class _FollowThroughDemoState extends State<_FollowThroughDemo> {
  static const _pages = ['Day', 'Inbox', 'Tracked'];
  var _index = 0;
  var _forward = true;

  void _go(int delta) => setState(() {
    _forward = delta > 0;
    _index = (_index + delta).clamp(0, _pages.length - 1);
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    return ColoredBox(
      color: theme.colorSurfaceTimeline,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppButton(
                icon: Icons.chevron_left_rounded,
                shape: AppButtonShape.circle,
                tooltip: 'Previous page',
                onPressed: _index > 0 ? () => _go(-1) : null,
              ),
              SizedBox(width: theme.spacingMd),
              Text(_pages[_index], style: theme.textBody),
              SizedBox(width: theme.spacingMd),
              AppButton(
                icon: Icons.chevron_right_rounded,
                shape: AppButtonShape.circle,
                tooltip: 'Next page',
                onPressed: _index < _pages.length - 1 ? () => _go(1) : null,
              ),
            ],
          ),
          Expanded(
            child: ClipRect(
              child: AppViewTransition(
                viewId: _pages[_index],
                slide: true,
                forward: _forward,
                child: _DemoPage(theme: theme, title: _pages[_index]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoPage extends StatelessWidget {
  const _DemoPage({required this.theme, required this.title});

  final AmbleTheme theme;
  final String title;

  @override
  Widget build(BuildContext context) => ListView(
    padding: EdgeInsets.all(theme.spacingScreenPadding),
    children: [
      for (var i = 0; i < 5; i++)
        Padding(
          padding: EdgeInsets.only(bottom: theme.spacingSm),
          child: AppFollowThrough(
            child: Container(
              padding: EdgeInsets.all(theme.spacingMd),
              decoration: BoxDecoration(
                color: theme.colorSurfaceSecondary,
                borderRadius: BorderRadius.circular(theme.radiusXl),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$title item ${i + 1}', style: theme.textBody),
                  SizedBox(height: theme.spacingSm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (var d = 0; d < 7; d++)
                        AppFollowThrough(
                          child: Container(
                            width: theme.sizeTaskBadge,
                            height: theme.sizeTaskBadge,
                            decoration: BoxDecoration(
                              color: d.isEven
                                  ? theme.colorAccent
                                  : theme.colorSurfaceField,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
    ],
  );
}
