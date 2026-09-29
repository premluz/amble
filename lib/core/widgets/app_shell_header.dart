import 'package:flutter/material.dart';

import '../tokens/header_reveal_spec.dart';
import '../tokens/semantic_theme.dart';
import 'app_button.dart';
import 'app_pane_morph.dart';
import 'app_shell_chrome.dart';
import 'app_stagger_exit.dart';

/// One geometry contract for main navigation and contextual route tabs.
///
/// A route's header (Edit mode's Things | Zones) arrives as the main nav's
/// items stagger out and a glass pane grows from the header's leading edge
/// into it — the Inbox mic's stretch into the voice toolbar
/// ([HeaderRevealSpec]). The pane is drawn here, so a route passes only the
/// pane's content. Leaving plays it backwards.
class AppShellHeader extends StatefulWidget {
  const AppShellHeader({
    super.key,
    required this.controller,
    required this.child,
  });
  final AppShellChromeController controller;
  final Widget child;

  @override
  State<AppShellHeader> createState() => _AppShellHeaderState();
}

class _AppShellHeaderState extends State<AppShellHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: HeaderRevealSpec.duration,
  )..addStatusListener(_onStatus);
  late final Animation<double> _morph = CurvedAnimation(
    parent: _reveal,
    curve: Interval(HeaderRevealSpec.morphStart, 1),
  );

  /// The route header on screen — kept through the exit, after the route
  /// has already released it.
  Widget? _shown;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_sync);
    _shown = widget.controller.header;
    if (_shown != null) _reveal.value = 1;
  }

  @override
  void didUpdateWidget(AppShellHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_sync);
    widget.controller.addListener(_sync);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
    _reveal.dispose();
    super.dispose();
  }

  void _sync() {
    final header = widget.controller.header;
    final instant = MediaQuery.disableAnimationsOf(context);
    setState(() {
      if (header != null) _shown = header;
    });
    if (header != null) {
      instant ? _reveal.value = 1 : _reveal.forward();
    } else {
      instant ? _reveal.value = 0 : _reveal.reverse();
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed &&
        widget.controller.header == null) {
      setState(() => _shown = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final height = appButtonHeightFor(theme, AppButtonSize.md);
    // A tab change re-sends the header without a new state; read it live.
    final shown = widget.controller.header ?? _shown;
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          children: [
            AnimatedBuilder(
              animation: _reveal,
              child: AppStaggerExitScope(
                progress: _reveal,
                child: widget.child,
              ),
              builder: (context, nav) {
                final away = _reveal.value > 0;
                return IgnorePointer(
                  ignoring: away,
                  child: ExcludeFocus(
                    excluding: away,
                    child: ExcludeSemantics(excluding: away, child: nav),
                  ),
                );
              },
            ),
            if (shown != null)
              Positioned.fill(
                child: AppPaneMorph(
                  theme: theme,
                  animation: _morph,
                  spec: HeaderRevealSpec.morph,
                  forwardSeconds: HeaderRevealSpec.morphSeconds,
                  origin: Rect.fromLTWH(0, 0, height, height),
                  target: Offset.zero & Size(constraints.maxWidth, height),
                  from: const SizedBox.shrink(),
                  child: shown,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
