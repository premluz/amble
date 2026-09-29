import 'package:flutter/widgets.dart';

import '../tokens/component_tokens.dart';
import '../tokens/semantic_theme.dart';

/// Where a page of an `AppSheetFlow` stands.
enum AppSheetPageRole {
  /// Showing and interactive.
  top,

  /// Covered by a later page: shifted aside, faded out, then kept alive
  /// offstage so its state (a typed name, a picked colour) survives.
  below,

  /// Going back: sliding out to the right, then removed.
  leaving,
}

/// One page of an `AppSheetFlow`, sliding between its places: a new page
/// comes in from the right over the one before, which shifts aside by
/// [SheetTokens.pageBehindShift] and fades; going back reverses it.
class AppSheetPageSlot extends StatefulWidget {
  const AppSheetPageSlot({
    super.key,
    required this.theme,
    required this.role,
    required this.animateIn,
    required this.onGone,
    required this.child,
  });

  final AmbleTheme theme;
  final AppSheetPageRole role;

  /// False for the flow's first page, which arrives with the sheet itself.
  final bool animateIn;

  /// Called once a [AppSheetPageRole.leaving] page has slid out.
  final VoidCallback onGone;
  final Widget child;

  @override
  State<AppSheetPageSlot> createState() => _AppSheetPageSlotState();
}

class _AppSheetPageSlotState extends State<AppSheetPageSlot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shown = AnimationController(
    vsync: this,
    duration: widget.theme.motionNormal,
    value: widget.animateIn ? 0 : 1,
  );

  @override
  void initState() {
    super.initState();
    if (widget.animateIn) _shown.forward();
  }

  @override
  void didUpdateWidget(AppSheetPageSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.role == widget.role) return;
    switch (widget.role) {
      case AppSheetPageRole.top:
        _shown.forward();
      case AppSheetPageRole.below:
        _shown.reverse();
      case AppSheetPageRole.leaving:
        _shown.reverse().whenComplete(() {
          if (mounted) widget.onGone();
        });
    }
  }

  @override
  void dispose() {
    _shown.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _shown,
    child: widget.child,
    builder: (context, child) {
      final role = widget.role;
      final shown = widget.theme.curveStandard.transform(_shown.value);
      final side = role == AppSheetPageRole.below
          ? -SheetTokens.pageBehindShift
          : 1.0;
      final away = role == AppSheetPageRole.below && _shown.isDismissed;
      return Offstage(
        offstage: away,
        child: TickerMode(
          enabled: !away,
          child: IgnorePointer(
            ignoring: role != AppSheetPageRole.top,
            child: ExcludeSemantics(
              excluding: role != AppSheetPageRole.top,
              child: FractionalTranslation(
                translation: Offset(side * (1 - shown), 0),
                child: Opacity(opacity: shown, child: child),
              ),
            ),
          ),
        ),
      );
    },
  );
}
