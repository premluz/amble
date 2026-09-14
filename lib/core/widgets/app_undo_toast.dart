import 'package:flutter/material.dart';

import '../tokens/semantic_theme.dart';

/// A brief, self-dismissing toast, optionally with an "Undo" action — the
/// app's only entry point for this kind of transient confirmation, per
/// docs/CONSTITUTION.md design principle 4. New addition to the adaptive
/// widget layer: nothing like this existed before Quick Capture's
/// confident-parse auto-create needed a lightweight "done, but you can
/// take it back" affordance.
///
/// Deliberately NOT a platform branch (no separate Cupertino/Material
/// look): neither platform's native snackbar/toast is being reached for
/// directly here, and a plain rounded card with text + a text button
/// reads identically as "the app's own" chrome on both platforms — the
/// same reasoning `AppTextField`/`ListWheelScrollView` already apply to
/// widgets whose rendering is genuinely platform-neutral. Uses only Tier
/// 2 tokens.
///
/// Self-manages its own lifetime: shows via [show], which inserts an
/// [OverlayEntry], auto-dismisses after [duration] unless [onUndo] fires
/// first (which also dismisses immediately), and removes itself cleanly
/// either way — callers never need to track or manually remove the entry.
///
/// [onUndo] is optional — a null value renders a plain informational
/// message with no action, added for the Weekly Zone Authoring Grid's
/// "this zone already exists for that day" notice (a heads-up, not an
/// undoable action) rather than building a second, near-identical toast
/// widget for the action-less case.
class AppUndoToast {
  AppUndoToast._();

  static void show({
    required BuildContext context,
    required String message,
    VoidCallback? onUndo,
    Duration duration = const Duration(seconds: 4),
  }) {
    // rootOverlay: true — targets the app's outermost Overlay (supplied
    // by MaterialApp's own Navigator) rather than the nearest enclosing
    // one, which is the more robust choice for anything meant to outlive
    // the specific screen that triggered it (this toast is shown right
    // after a provider write that rebuilds the calling screen).
    final overlay = Overlay.of(context, rootOverlay: true);
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    late OverlayEntry entry;
    var dismissed = false;

    void dismiss() {
      if (dismissed) return;
      dismissed = true;
      entry.remove();
    }

    entry = OverlayEntry(
      builder: (context) => _ToastOverlay(
        theme: theme,
        message: message,
        duration: duration,
        onUndo: onUndo == null
            ? null
            : () {
                onUndo();
                dismiss();
              },
        onExpired: dismiss,
      ),
    );

    overlay.insert(entry);
  }
}

class _ToastOverlay extends StatefulWidget {
  const _ToastOverlay({
    required this.theme,
    required this.message,
    required this.duration,
    required this.onUndo,
    required this.onExpired,
  });

  final AmbleTheme theme;
  final String message;
  final Duration duration;
  final VoidCallback? onUndo;
  final VoidCallback onExpired;

  @override
  State<_ToastOverlay> createState() => _ToastOverlayState();
}

class _ToastOverlayState extends State<_ToastOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.theme.motionNormal,
    );
    _fade = CurvedAnimation(
      parent: _controller,
      curve: widget.theme.curveStandard,
    );
    _controller.forward();

    Future<void>.delayed(widget.duration, () async {
      if (!mounted) return;
      await _controller.reverse();
      if (mounted) widget.onExpired();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;

    // Clears the day strip (DayStrip's own content height, spacingXl *
    // 1.6, plus its vertical padding of spacingSm on each side) AND the
    // device's own bottom safe-area inset — a bare fixed offset (the
    // first pass used spacingXl * 2 = 80px) undershot both and the toast
    // rendered partially behind the strip, reported directly from an
    // on-device screenshot.
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final clearance = theme.spacingXl * 1.6 + theme.spacingSm * 2 + bottomInset;

    return Positioned(
      left: theme.spacingMd,
      right: theme.spacingMd,
      bottom: clearance + theme.spacingSm,
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.15),
            end: Offset.zero,
          ).animate(_fade),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: theme.spacingMd,
                vertical: theme.spacingSm,
              ),
              decoration: BoxDecoration(
                color: theme.colorTextPrimary,
                borderRadius: BorderRadius.circular(theme.radiusMd),
                boxShadow: theme.shadowPane,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      widget.message,
                      style: theme.textBody.copyWith(
                        color: theme.colorSurfacePrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (widget.onUndo case final onUndo?) ...[
                    SizedBox(width: theme.spacingSm),
                    GestureDetector(
                      onTap: onUndo,
                      behavior: HitTestBehavior.opaque,
                      child: Text(
                        'Undo',
                        style: theme.textBody.copyWith(
                          color: theme.colorAccent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
