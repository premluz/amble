import 'package:amble/core/tokens/depth_motion_spec.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_depth.dart';
import 'package:flutter/material.dart';

/// "Add 3" makes rows emerge from depth, staggered; tapping a row makes it
/// recede and give its space back. The pattern every object uses for create
/// and delete.
Widget depthDemo(BuildContext context) => const _DepthDemo();

class _DepthDemo extends StatefulWidget {
  const _DepthDemo();

  @override
  State<_DepthDemo> createState() => _DepthDemoState();
}

class _DepthDemoState extends State<_DepthDemo> {
  final _rows = <int>[1, 2];
  final _arriving = <int, int>{};
  final _leaving = <int>{};
  var _next = 3;

  void _addThree() => setState(() {
    for (var i = 0; i < 3; i++) {
      _arriving[_next] = i;
      _rows.insert(0, _next++);
    }
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    return ColoredBox(
      color: theme.colorSurfaceBase,
      child: ListView(
        padding: EdgeInsets.all(theme.spacingScreenPadding),
        children: [
          TextButton(
            onPressed: _addThree,
            child: Text('Add 3', style: theme.textBody),
          ),
          for (final row in _rows)
            AppDepthPresence(
              key: ValueKey(row),
              animateIn: _arriving.containsKey(row),
              delay: DepthMotionSpec.standard.staggerFor(_arriving[row] ?? 0),
              present: !_leaving.contains(row),
              onExited: () => setState(() {
                _leaving.remove(row);
                _rows.remove(row);
              }),
              child: Padding(
                padding: EdgeInsets.only(bottom: theme.spacingSm),
                child: GestureDetector(
                  onTap: () => setState(() => _leaving.add(row)),
                  child: Container(
                    padding: EdgeInsets.all(theme.spacingMd),
                    decoration: BoxDecoration(
                      color: theme.colorSurfacePrimary,
                      borderRadius: BorderRadius.circular(theme.radiusXl),
                    ),
                    child: Row(
                      children: [
                        AppDepthShape(
                          child: Container(
                            width: theme.sizeTaskBadge,
                            height: theme.sizeTaskBadge,
                            decoration: BoxDecoration(
                              color: theme.colorAccent,
                              borderRadius: BorderRadius.circular(
                                theme.radiusPill,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: theme.spacingSm),
                        AppDepthFade(
                          child: Text(
                            'Task $row — tap to remove',
                            style: theme.textBody,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
