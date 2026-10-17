import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/component_tokens.dart';
import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_scroll_reveal_fade.dart';
import '../../core/widgets/app_sheet_surface.dart';
import '../../core/widgets/app_top_scroll_fade.dart';
import '../../core/widgets/app_size_reporter.dart';
import '../../core/widgets/app_step_scaffold.dart' show HeaderCircleButton;
import '../../core/widgets/sheet_keyboard_background.dart';
import '../task_detail/quick_create_sheet_shell.dart';
import '../task_detail/task_sheet_fields.dart';
import '../task_detail/task_sheet_form.dart';
import '../task_detail/task_sheet_save.dart';
import 'pending_task_draft_provider.dart';

/// The small quick-create panel dropped alongside the provisional placeholder
/// pill by tapping empty Timeline space — requested directly: "a small
/// sheet with a task name input without the keyboard opened... a little
/// handle in the middle that the user can extend to near full size add
/// sheet." Its fields and save are the shared task sheet's
/// (`TaskSheetFields` / `saveTaskSheet`), the same as editing a task
/// (`showTaskSheet`); the name is typed in place, with the sheet riding
/// above the keyboard.
///
/// **Deliberately NOT a pushed `Navigator` route.** An earlier version
/// pushed this panel as a route (wrapped to a small height) and it was
/// confirmed
/// broken by direct testing: Flutter's `Navigator` unconditionally wraps
/// every route BELOW the topmost one in an `AbsorbPointer`, regardless of
/// `barrierColor`/`opaque` — no route-level configuration can opt out of
/// it. That meant Timeline (and the draggable placeholder pill on it)
/// could never stay interactive while a pushed route sat on top, no
/// matter how that route was configured — confirmed via a real
/// widget-test hit-test trace showing `RenderAbsorbPointer` swallowing a
/// pointer at the pill's exact location. Direct user observation matched
/// exactly: "the sheet cannot be actually modal otherwise dragging would
/// be possible."
///
/// So this widget is a plain member of `_DayTimelineState`'s own Stack —
/// no `Navigator`, no barrier, nothing absorbing pointers below it — for
/// its whole life, expanded or not (the full-size task sheet it used to
/// hand off to is gone, 2026-09-30).
class QuickCreateOverlay extends ConsumerStatefulWidget {
  const QuickCreateOverlay({super.key, required this.draft});

  final PendingTaskDraft draft;

  @override
  ConsumerState<QuickCreateOverlay> createState() => _QuickCreateOverlayState();
}

class _QuickCreateOverlayState extends ConsumerState<QuickCreateOverlay>
    with SingleTickerProviderStateMixin {
  late final QuickCreateSheetHeightController _heightController;

  /// A one-shot fade+slide-up on mount, requested directly: "still not see
  /// wired [into the shared animation system]... it shows abruptly" — this
  /// panel previously had NO entrance motion at all, popping straight to
  /// its resting height the instant it's inserted into Timeline's own
  /// `Stack`. Reuses the same `motionSheetSlide`/`curveDecelerate` tokens
  /// [AppSheetMotion]'s own plain (non-keyboard) mode computes
  /// (`curveDecelerate.transform(routeAnimation.value)`) — but NOT that
  /// widget itself: `AppSheetMotion` fully owns its child's bottom-anchored
  /// positioning/height internally (`Align(bottomCenter)` +
  /// `ConstrainedBox`), which would collide with this panel's own
  /// `Positioned` + height-animated `AnimatedContainer` (see `build()`
  /// below) — the two would each try to own the same layout. This is the
  /// PLAIN mode's math only, applied as a wrapper around the
  /// already-positioned panel instead. No keyboard-aware mode here by
  /// design — see this class's own doc comment on why a real
  /// `Navigator`-route-driven `AppSheetRoute` can't be used at all for
  /// this specific overlay (the `AbsorbPointer` bug), which is also what
  /// rules out reusing `AppSheetMotion` wholesale.
  late final AnimationController _entrance;

  /// The sheet's fields. Its date, time and length and the draft pill's
  /// are one: dragging the pill updates them, picking them moves the pill.
  late final TaskSheetForm _form;

  /// While the pill's own move is being copied into [_form], so that copy
  /// isn't sent straight back to the pill.
  bool _followingDraft = false;

  /// Re-entrancy guards for the save: [_isSaving] stops two taps
  /// overlapping, [_hasSaved] stops a second tap arriving after the first
  /// committed from creating a duplicate task.
  bool _isSaving = false;
  bool _hasSaved = false;

  bool _entranceStarted = false;

  @override
  void initState() {
    super.initState();
    // A real default name ("New thing"), so Add is meaningful untouched;
    // the first tap into the name clears it (see [_clearDefaultName]).
    _form = TaskSheetForm(
      title: _defaultName,
      date: widget.draft.scheduledAt,
      time: TimeOfDay.fromDateTime(widget.draft.scheduledAt),
      durationMinutes: widget.draft.durationMinutes,
    )..addListener(_moveDraftToForm);
    _heightController = QuickCreateSheetHeightController(
      initialFraction: quickCreateSheetMinFraction,
    );
    // Duration is set from `theme.motionSheetSlide` in
    // `didChangeDependencies` (the theme isn't reachable yet here) —
    // `vsync` is all `initState` can safely provide.
    _entrance = AnimationController(vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Runs once — `_entranceStarted` guards against a later
    // `didChangeDependencies` call (e.g. a theme hot-reload) restarting an
    // already-played entrance.
    if (_entranceStarted) return;
    _entranceStarted = true;
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    _entrance.duration = theme.motionSheetSlide;
    _entrance.forward();
  }

  @override
  void dispose() {
    _heightController.dispose();
    _form
      ..removeListener(_moveDraftToForm)
      ..dispose();
    _entrance.dispose();
    _fieldsScroll.dispose();
    super.dispose();
  }

  static const _defaultName = 'New thing';

  @override
  void didUpdateWidget(QuickCreateOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    final draft = widget.draft;
    if (draft.scheduledAt == oldWidget.draft.scheduledAt &&
        draft.durationMinutes == oldWidget.draft.durationMinutes) {
      return;
    }
    _followingDraft = true;
    _form.setSchedule(draft.scheduledAt, draft.durationMinutes);
    _followingDraft = false;
  }

  /// A time or length picked in the sheet moves the draft pill with it.
  void _moveDraftToForm() {
    if (_followingDraft) return;
    final at = _form.scheduledAt;
    final minutes = _form.durationMinutes;
    if (at == null || minutes == null) return;
    final draft = widget.draft;
    final notifier = ref.read(pendingTaskDraftProvider.notifier);
    if (at != draft.scheduledAt) notifier.updatePosition(at);
    if (minutes != draft.durationMinutes) notifier.updateDuration(minutes);
  }

  /// The first tap into the name clears the default, so typing starts
  /// fresh (reported directly); a name the user typed or a preset's stays.
  void _clearDefaultName(bool hasFocus) {
    if (hasFocus && _form.title.text == _defaultName) _form.title.clear();
  }

  /// Add: the shared task save ([saveTaskSheet]), which also clears the
  /// draft. [_isSaving] stops overlapping taps, [_hasSaved] a second save.
  Future<void> _save() async {
    if (_isSaving || _hasSaved || !_form.canSave) return;
    setState(() => _isSaving = true);
    try {
      _hasSaved = await saveTaskSheet(
        context,
        ref,
        _form,
        draftId: widget.draft.id,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Guards [_onCloseRequested] against firing twice (e.g. a second drag
  /// past the close threshold while the exit is already playing) — the
  /// same "runs exactly once" shape [_entranceStarted] already
  /// establish for this class's other one-shot transitions.
  bool _closing = false;

  /// Dragging the handle down far enough — or tapping the X — closes the
  /// whole flow, requested directly ("the sheet should also be closing
  /// with this handle that expands it... and close in same positions as
  /// big sheet").
  ///
  /// **2026-09-24 — plays the exit animation FIRST, then clears the
  /// draft.** Reported directly alongside the entrance fix: this panel
  /// closed exactly as abruptly as it opened — `clear()` used to run
  /// immediately, which removes this widget from Timeline's `Stack` on
  /// the very next frame (see `timeline_screen.dart`'s own
  /// `if (widget.pendingDraft != null)` conditional), giving `_entrance`
  /// no time to reverse before the widget was gone. Reversing first and
  /// deferring the real clear to the reverse animation's completion
  /// means the placeholder pill UNDERNEATH also stays visible for the
  /// same span (`clear()` is what removes both — see the class's own
  /// prior doc comment on that), so the whole draft — pill and panel
  /// together — fades out as one motion instead of the panel vanishing
  /// out from under a pill that lingered a frame longer.
  void _onCloseRequested() {
    if (_closing) return;
    _closing = true;
    _entrance.reverse().whenComplete(() {
      if (!mounted) return;
      ref.read(pendingTaskDraftProvider.notifier).clear();
    });
  }

  /// The content's natural height (fields, chips, bottom space), measured
  /// after layout. The small state hugs it — no empty band under the chips
  /// — capped at the old fixed share of the screen, which the Timeline's
  /// own clearance still assumes.
  double? _contentHeight;

  /// The fields' scroll, which drives the top fade.
  final _fieldsScroll = ScrollController();

  /// The pinned block above the fields: the top gap and the header row.
  double _headerExtent(AmbleTheme theme) =>
      theme.spacingSm + theme.spacingXl * 1.8;

  void _onContentHeight(double height) {
    if (!mounted || height == _contentHeight) return;
    setState(() => _contentHeight = height);
  }

  /// The panel's height for the controller's fraction, from minimised up to
  /// small — small being the content's height (see [_contentHeight]),
  /// capped at the old fixed share of [fullHeight]. The sheet never goes
  /// above small. Clamped at 0 — the fraction may go below the minimised
  /// floor mid-drag (drag down to close), a height can't.
  double _sheetHeight(double minHeight, double fullHeight) {
    const minimised = quickCreateSheetMinimisedFraction;
    const small = quickCreateSheetMinFraction;
    final fixedSmall =
        minHeight +
        (fullHeight - minHeight) * (small - minimised) / (1 - minimised);
    final smallHeight = math.max(
      minHeight,
      math.min(_contentHeight ?? fixedSmall, fixedSmall),
    );
    final fraction = _heightController.fraction;
    final height =
        minHeight +
        (smallHeight - minHeight) *
            (fraction - minimised) /
            (small - minimised);
    return math.max(0, height);
  }

  Widget _minimisedTitle(AmbleTheme theme) => ListenableBuilder(
    listenable: _form.title,
    builder: (context, _) {
      final title = _form.title.text.trim();
      return Text(
        // "(No title)" confirmed directly, matching the reference
        // screenshot's own wording for an unnamed draft.
        title.isEmpty ? '(No title)' : title,
        style: SheetTokens.titleStyle(theme).copyWith(
          color: title.isEmpty
              ? theme.colorTextSecondary
              : theme.colorTextPrimary,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final viewport = MediaQuery.sizeOf(context).height;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    // The floor the panel never goes below while open: exactly the space
    // the two bars a live draft hides (the bottom NavigationBar and the
    // DayStrip above it) used to occupy, so the sheet visually replaces
    // both rather than leaving a strip of bare Timeline where they were.
    // Requested directly: "it should cover also the days 'adjacent to
    // main nav' with plus and view switch."
    final barsHeight = _backdropHeight(theme, viewport, bottomInset);
    final bottomSpace =
        MediaQuery.paddingOf(context).bottom +
        SheetTokens.contentBottomInset(theme);

    // The one-shot entrance wrap — see `_entrance`'s own doc comment.
    // `curveDecelerate.transform`, matching exactly what `AppSheetMotion`'s
    // own plain-mode `_visibleProgress()` computes, so this panel's
    // entrance reads as the same motion family as every `AppSheet`-based
    // sheet even though it can't share that widget directly.
    return AnimatedBuilder(
      animation: _entrance,
      builder: (context, child) {
        final progress = theme.curveDecelerate.transform(_entrance.value);
        return Opacity(
          opacity: progress,
          child: FractionalTranslation(
            translation: Offset(0, 1 - progress),
            child: child,
          ),
        );
      },
      // The sheet's colour behind the keyboard, so its rounded top corners
      // show the sheet, not the Timeline — reported directly: "apple
      // keyboard is round... there is gap, sheet not covering it." Same
      // treatment every `AppSheet` gets.
      child: SheetKeyboardBackground(
        inset: MediaQuery.viewInsetsOf(context).bottom,
        color: SheetTokens.surface(theme),
        child: LayoutBuilder(
          builder: (context, constraints) => Stack(
            children: [
              AnimatedBuilder(
                animation: _heightController,
                builder: (context, _) {
                  // Full height is bounded by the space this sheet actually
                  // has — the Timeline area under the shell header (and above
                  // the keyboard) — not the whole screen, or dragged up it
                  // slid under the header and the status bar with its ×
                  // out of reach (reported directly).
                  final fullHeight = math.max(
                    0.0,
                    math.min(
                          viewport,
                          constraints.maxHeight -
                              MediaQuery.viewInsetsOf(context).bottom,
                        ) -
                        theme.spacingXl,
                  );
                  // The floor is the MINIMISED state now, not the small one —
                  // the sheet has three states (see
                  // `quickCreateSheetMinimisedFraction`). `barsHeight` still
                  // applies: even minimised, the panel must cover the space the
                  // nav bar and day strip occupied rather than leaving a strip
                  // of bare Timeline where they were.
                  final minHeight = math.max(
                    viewport * quickCreateSheetMinimisedFraction,
                    barsHeight,
                  );
                  final currentHeight = _sheetHeight(minHeight, fullHeight);

                  return Positioned(
                    left: 0,
                    right: 0,
                    // Above the keyboard while the name is being typed.
                    bottom: MediaQuery.viewInsetsOf(context).bottom,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      height: currentHeight,
                      // `AppSheetSurface`: the shared sheet surface and floating
                      // edge — requested directly, "sheets should have that
                      // elevated styling (border)", replacing this sheet's
                      // earlier "no shadow/glow" Android non-modal look.
                      child: AppSheetSurface(
                        theme: theme,
                        // The bottom space is the END of the scroll (safe area +
                        // clearance), under a fade — content runs to the phone's
                        // edge, like every sheet (DESIGN_SYSTEM.md "Sheets").
                        child: Stack(
                          children: [
                            SafeArea(
                              top: false,
                              bottom: false,
                              // The header row stays pinned; only the fields
                              // scroll, under a fade that appears once they do
                              // (requested directly: "in top part we should
                              // have that fade gradient as we have on bottom").
                              // OverflowBox + ClipRect keep the header whole
                              // while a drag-to-close shrinks the sheet below
                              // it, instead of overflowing.
                              child: LayoutBuilder(
                                builder: (context, box) => ClipRect(
                                  child: OverflowBox(
                                    alignment: Alignment.topCenter,
                                    maxHeight: math.max(
                                      box.maxHeight,
                                      _headerExtent(theme),
                                    ),
                                    child: Column(
                                      children: [
                                        // A small top gap before the header row.
                                        SizedBox(height: theme.spacingSm),
                                        Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: theme.spacingLg,
                                          ),
                                          child: SizedBox(
                                            // Keep the original breathing room around the
                                            // header controls; the chip row below owns its
                                            // own content-sized spacing.
                                            height: theme.spacingXl * 1.8,
                                            child: Stack(
                                              children: [
                                                Positioned.fill(
                                                  child: QuickCreateSheetHandle(
                                                    theme: theme,
                                                    controller:
                                                        _heightController,
                                                    viewportHeight: viewport,
                                                    onCloseRequested:
                                                        _onCloseRequested,
                                                  ),
                                                ),
                                                // Add RIGHT, close LEFT — matching the new
                                                // quick-add mockup's action placement.
                                                // Matches the platform convention
                                                // that screenshot shows (dismiss left,
                                                // confirm right).
                                                //
                                                // Both buttons sit ON TOP of the
                                                // `Positioned.fill` handle and win their own
                                                // taps; the handle still drags from any part
                                                // of the row they don't cover.
                                                //
                                                // "Add", not "Done": it commits the task
                                                // outright.
                                                // Both buttons hide while MINIMISED —
                                                // requested directly: "just the title is
                                                // shown, and there is this little handle
                                                // to expand or tap to expand." The handle
                                                // behind them stays, and becomes the whole
                                                // row's tap/drag target.
                                                if (!_heightController
                                                    .minimised)
                                                  Positioned(
                                                    top: 0,
                                                    bottom: 0,
                                                    right: 0,
                                                    child: Center(
                                                      child: AppButton(
                                                        label: 'Add',
                                                        size: AppButtonSize.md,
                                                        shape:
                                                            AppButtonShape.pill,
                                                        onPressed: _isSaving
                                                            ? null
                                                            : _save,
                                                      ),
                                                    ),
                                                  ),
                                                if (!_heightController
                                                    .minimised)
                                                  // Top-anchored, not
                                                  // vertically centered, so
                                                  // this button's top inset
                                                  // from the SHEET'S OWN edge
                                                  // (`AppSheetSurface`) is
                                                  // exactly `spacingLg` —
                                                  // matching its `spacingLg`
                                                  // side inset — the same as
                                                  // every other sheet header
                                                  // (docs/DESIGN_SYSTEM.md's
                                                  // "Sheet header circle
                                                  // buttons" section).
                                                  // `theme.spacingLg -
                                                  // theme.spacingSm`, not
                                                  // `spacingLg` outright,
                                                  // because the `spacingSm`
                                                  // gap above this row (see
                                                  // "A small top gap before
                                                  // the header row" above)
                                                  // already supplies part of
                                                  // that distance — pinned
                                                  // by `quick_task_add_test
                                                  // .dart`'s own geometry
                                                  // assertion.
                                                  Positioned(
                                                    top:
                                                        theme.spacingLg -
                                                        theme.spacingSm,
                                                    left: 0,
                                                    child:
                                                        // No `backgroundColor` override any
                                                        // more (2026-09-23). This used to pass
                                                        // `colorSurfaceSecondary` explicitly,
                                                        // because HeaderCircleButton's own
                                                        // default was then the flat, darker
                                                        // `colorSurfaceField` and read as too
                                                        // low-contrast against this panel's
                                                        // nav-matched ground — requested
                                                        // directly at the time ("the style of
                                                        // close button should be same as in big
                                                        // sheet"). That default is now the
                                                        // translucent secondary glass tint
                                                        // every other secondary control uses,
                                                        // so the override would make THIS the
                                                        // odd one out instead.
                                                        HeaderCircleButton(
                                                          theme: theme,
                                                          icon: Icons
                                                              .close_rounded,
                                                          onTap:
                                                              _onCloseRequested,
                                                        ),
                                                  ),
                                                // MINIMISED: the title alone, where the
                                                // header row sits in the open sheet —
                                                // requested directly ("just the title is
                                                // shown", and "in the same position as
                                                // header"). Taps fall through to the
                                                // handle behind it, which restores.
                                                if (_heightController.minimised)
                                                  Positioned.fill(
                                                    child: IgnorePointer(
                                                      child: Center(
                                                        child: _minimisedTitle(
                                                          theme,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Stack(
                                            children: [
                                              // A scroll view, not a bare Column — a
                                              // defensive floor against a genuinely
                                              // short viewport.
                                              SingleChildScrollView(
                                                controller: _fieldsScroll,
                                                child: AppSizeReporter(
                                                  // The small state hugs header + fields.
                                                  onSize: (size) =>
                                                      _onContentHeight(
                                                        _headerExtent(theme) +
                                                            size.height,
                                                      ),
                                                  child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      if (!_heightController
                                                          .minimised) ...[
                                                        SizedBox(
                                                          height:
                                                              SheetTokens.headerToFieldGap(
                                                                theme,
                                                              ),
                                                        ),
                                                        Padding(
                                                          padding:
                                                              EdgeInsets.symmetric(
                                                                horizontal: theme
                                                                    .spacingLg,
                                                              ),
                                                          // Typed in place: the sheet rises
                                                          // with the keyboard (see the
                                                          // Positioned's bottom).
                                                          child: TaskSheetFields(
                                                            form: _form,
                                                            showPreset: true,
                                                            onNameFocusChanged:
                                                                _clearDefaultName,
                                                          ),
                                                        ),
                                                      ],
                                                      SizedBox(
                                                        height: bottomSpace,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              Positioned(
                                                left: 0,
                                                right: 0,
                                                top: 0,
                                                child: AppScrollRevealFade(
                                                  controller: _fieldsScroll,
                                                  color: SheetTokens.surface(
                                                    theme,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: AppTopScrollFade(
                                color: SheetTokens.surface(theme),
                                height: bottomSpace,
                                fromBottom: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The backdrop's own height — reaches from the screen's bottom up to
  /// (approximately) the top of the bottom nav pill, so the sheet visually
  /// replaces it while a draft is live. Requested directly: "it should
  /// cover also the days 'adjacent to main nav' with plus and view
  /// switch."
  ///
  /// **2026-09-12** — the day-navigation/view-switch/"+" bar this used to
  /// also cover (`DayStrip`, then briefly `AppBottomExtensionBar`) is gone
  /// entirely: day navigation moved to the top `AppCalendarHeader`, and
  /// the "+" is now an independently floating button (already hidden
  /// while a draft is live via its own `pendingTaskDraftProvider` check,
  /// same as before) rather than sharing a bar with the nav. So this only
  /// needs to reach Material's own `NavigationBar` height
  /// ([kBottomNavigationBarHeight]) plus the device's bottom safe-area
  /// inset, which the nav wraps itself in a `SafeArea` to guard.
  double _backdropHeight(
    AmbleTheme theme,
    double viewport,
    double bottomInset,
  ) {
    return math.min(viewport, kBottomNavigationBarHeight + bottomInset);
  }
}
