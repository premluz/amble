import 'dart:async';

import 'package:flutter/material.dart';

import '../tokens/component_tokens.dart';
import '../tokens/semantic_theme.dart';
import 'app_floating_surface.dart';

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

  static final Map<OverlayState, Set<OverlayEntry>> _entriesByOverlay = {};

  /// Keeps active toasts above the page that created them but below a newly
  /// pushed modal route. Navigator's own overlay rearrangement puts manually
  /// inserted entries back on top whenever a route is pushed, so the modal
  /// route must explicitly reclaim the top of the stack.
  static void placeBelowRoute(OverlayState overlay, Route<dynamic> route) {
    final toastEntries = _entriesByOverlay[overlay];
    final routeEntries = route.overlayEntries;
    if (toastEntries == null || toastEntries.isEmpty || routeEntries.isEmpty) {
      return;
    }

    // Remove and reinsert the entries below the route's barrier. `rearrange`
    // cannot express this with a subset of entries because its unspecified
    // entries are kept as a group at the top; inserting below the known route
    // entry gives the overlay the exact order we need.
    for (final entry in toastEntries) {
      entry.remove();
      overlay.insert(entry, below: routeEntries.first);
    }
  }

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
      final entries = _entriesByOverlay[overlay];
      entries?.remove(entry);
      if (entries != null && entries.isEmpty) {
        _entriesByOverlay.remove(overlay);
      }
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

    _entriesByOverlay.putIfAbsent(overlay, () => <OverlayEntry>{}).add(entry);
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

  /// The auto-dismiss delay — a real [Timer], not a bare
  /// `Future<void>.delayed`, specifically so [dispose] can [Timer.cancel]
  /// it. A bare `Future.delayed` still schedules the identical platform
  /// timer under the hood, but exposes no handle to cancel it — tapping
  /// Undo (see [widget.onUndo]) removes this overlay entry well before
  /// [widget.duration] elapses, but that timer kept existing and firing
  /// anyway (its own `mounted` guard made the fire a harmless no-op in
  /// production, but `flutter_test`'s teardown treats ANY still-pending
  /// Timer as a real assertion failure — caught by a new automated test
  /// for the undo mechanism itself, not by inspection).
  late final Timer _expireTimer;

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

    _expireTimer = Timer(widget.duration, () async {
      if (!mounted) return;
      await _controller.reverse();
      if (mounted) widget.onExpired();
    });
  }

  @override
  void dispose() {
    _expireTimer.cancel();
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
          // Glass, and see-through enough to show what's behind it —
          // requested directly: "make the toast glass and semitransparent."
          // The shared floating material (blur, edge, shadow), with its
          // fill thinned to `ToastTokens.fillAlpha`.
          child: Material(
            color: Colors.transparent,
            child: AppFloatingSurface(
              theme: theme,
              borderRadius: BorderRadius.circular(theme.radiusMd),
              surfaceColor: ToastTokens.fill(theme),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: theme.spacingMd,
                  vertical: theme.spacingSm,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        widget.message,
                        style: theme.textBody.copyWith(
                          color: theme.colorTextPrimary,
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
                            fontWeight: FontWeight.w600,
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
      ),
    );
  }
}
