import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/component_tokens.dart';
import '../../core/tokens/semantic_theme.dart';
import '../../core/timeline_clock.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_sheet_surface.dart';
import '../../core/widgets/app_top_scroll_fade.dart';
import '../../core/widgets/app_size_reporter.dart';
import '../../core/widgets/app_step_scaffold.dart' show HeaderCircleButton;
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/app_trial_gate.dart';
import '../../core/widgets/app_value_chip.dart';
import '../../shared/models/category.dart';
import '../../shared/models/recurrence_frequency.dart';
import '../../shared/models/recurrence_rule.dart';
import '../../shared/models/task.dart';
import '../../shared/providers/task_providers.dart';
import '../../shared/providers/trial_providers.dart';
import 'recently_saved_task_provider.dart';
import '../task_detail/quick_create_sheet_shell.dart';
import '../task_detail/task_behavior_modal.dart';
import '../task_detail/task_category_modal.dart';
import '../task_detail/task_detail_sheet.dart';
import '../task_detail/task_duration_modal.dart';
import '../task_detail/task_preset_modal.dart';
import '../task_detail/task_repeat_modal.dart';
import '../task_detail/task_start_time_modal.dart';
import 'pending_task_draft_provider.dart';

/// The small quick-create panel dropped alongside the provisional placeholder
/// pill by tapping empty Timeline space — requested directly: "a small
/// sheet with a task name input without the keyboard opened... a little
/// handle in the middle that the user can extend to near full size add
/// sheet." Mirrors the real full-size sheet's own header/footer button
/// positions (close top-right, primary action a bottom pill button — see
/// `StepScaffold`) so the small and expanded states read as one
/// continuous flow, not two different UIs.
///
/// **Deliberately NOT a pushed `Navigator` route.** An earlier version
/// pushed this panel as a route (reusing `showTaskDetailSheet`'s own
/// `_pushDetailRoute`, wrapped to a small height) and it was confirmed
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
/// no `Navigator`, no barrier, nothing absorbing pointers below it. Only
/// once the user drags the handle past the expand threshold, taps the
/// Name field, or taps the primary button does a REAL route get pushed
/// (the ordinary, unmodified [showTaskDetailSheet] flow) — at that point
/// `AbsorbPointer` making Timeline non-interactive underneath is correct
/// and expected, exactly like every other entry point into that same
/// sheet.
class QuickCreateOverlay extends ConsumerStatefulWidget {
  const QuickCreateOverlay({super.key, required this.draft});

  final PendingTaskDraft draft;

  @override
  ConsumerState<QuickCreateOverlay> createState() => _QuickCreateOverlayState();
}

class _QuickCreateOverlayState extends ConsumerState<QuickCreateOverlay>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _titleController;
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

  /// Guards against promoting twice — [_onHeightChanged] fires on every
  /// `notifyListeners()`, and [_promote] is also reachable directly from
  /// the Name field's own focus and the Done button, but the promotion
  /// (pushing the real sheet) must happen exactly once per draft.
  bool _promoted = false;

  /// See [Task.isImportant]. Reported directly as missing from this
  /// panel ("can't see important in quick add in mini sheet") — the
  /// full sheet, the edit flow, and templates all gained a real toggle
  /// for this field, but the mini sheet's own direct-Add path
  /// (`_schedule`) had no way to set it at all.
  /// It remains user-overridable, same as the title field is.
  bool _isImportant = false;

  /// The label selected from the shared label picker. General is the
  /// neutral fallback and is not shown as a selectable label in the modal.
  String _categoryId = BuiltInCategoryIds.general;

  String? _behaviorId;
  String? _templateId;
  TimeOfDay? _timeOverride;
  DateTime? _dateOverride;
  int? _durationOverride;
  bool _notificationsEnabled = true;
  bool _repeats = false;
  late Set<int> _selectedDays;

  /// Re-entrancy guards for the direct save, mirroring the full sheet's
  /// own pair: [_isSaving] stops two taps overlapping, [_hasSaved] stops
  /// a second tap arriving after the first committed from creating a
  /// duplicate task.
  bool _isSaving = false;
  bool _hasSaved = false;

  bool _entranceStarted = false;

  @override
  void initState() {
    super.initState();
    // A real default name ("New thing") rather than starting empty —
    // requested directly, so Add is always meaningful even if the
    // user never types. Tapping the field clears it outright (see the
    // field's own onFocusChanged) so typing starts from scratch.
    _titleController = TextEditingController(text: 'New thing');
    _selectedDays = {widget.draft.scheduledAt.weekday};
    _heightController = QuickCreateSheetHeightController(
      initialFraction: quickCreateSheetMinFraction,
    )..addListener(_onHeightChanged);
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
    _heightController.removeListener(_onHeightChanged);
    _heightController.dispose();
    _titleController.dispose();
    _entrance.dispose();
    super.dispose();
  }

  void _onHeightChanged() {
    if (!_heightController.expanded) return;
    _promote();
  }

  /// The one and only handoff to the real flow: an ordinary, unmodified
  /// showTaskDetailSheet push, seeded with whatever the user already
  /// typed and linked to the same draft id so the placeholder pill stays
  /// put and gets cleared/replaced the normal way once that flow saves
  /// or is abandoned (see task_detail_sheet.dart's own draftId
  /// handling, unchanged by this widget). Reachable three ways —
  /// dragging the handle to full (via [_onHeightChanged]), tapping the
  /// Name field, or tapping the Done button — all three are "the user
  /// wants the full form" in one form or another, requested directly:
  /// "when name input is tapped then it goes into near full screen
  /// mode."
  ///
  /// [stayOnNameStage] is true ONLY for the Name-field-tap path: that
  /// promotion fires on the TAP itself, before any typing happens, so
  /// there is no confirmed name yet to skip stage 1 on — the real
  /// sheet's own Name field takes over, autofocused, keyboard already
  /// up, so typing continues uninterrupted in what reads as the same
  /// field. The handle-drag and Done-button paths, by contrast, both
  /// mean "I'm done with the name" (whatever it currently reads,
  /// including the untouched "New thing" default), so they skip straight
  /// to the schedule fields as usual.
  void _promote({bool stayOnNameStage = false}) {
    if (_promoted) return;
    // Rebuilds this widget to render nothing (see build()'s own early
    // return) — once promoted, the real pushed route is the only visible
    // "sheet"; this overlay must not keep rendering alongside it.
    setState(() => _promoted = true);

    showTaskDetailSheet(
      context,
      initialScheduledAt: _scheduledAt,
      initialTimeOfDay: TimeOfDay.fromDateTime(_scheduledAt),
      draftId: widget.draft.id,
      initialTitle: _titleController.text,
      initialDurationMinutes: _durationMinutes,
      initialCategoryId: _categoryId,
      initialIsImportant: _isImportant,
      initialBehaviorId: _behaviorId,
      templateId: _templateId,
      stayOnNameStage: stayOnNameStage,
    );
  }

  /// Creates the task directly from the mini sheet, without ever opening
  /// the full form — the compact action commits the task directly
  /// and writes the settled draft values immediately.
  ///
  /// Everything needed is already settled by this point: the title (typed
  /// or from a chip or the "New thing" default), the category (from a chip,
  /// else General), and the start/duration (from where the user dropped
  /// and sized the placeholder pill). So this is a complete answer, not a
  /// shortcut past unanswered questions — the full sheet stays reachable
  /// for anything more (notes, repeats, notifications) by tapping the
  /// Name field.
  ///
  /// Saves the chosen position and size as-is. Overlaps are valid task
  /// layout; the timeline exposes explicit resolution actions afterward.
  Future<void> _schedule() async {
    if (_isSaving || _hasSaved) return;

    final title = _titleController.text.trim();
    // Nothing sensible to create, and no field is showing an error — the
    // user has actively emptied a field that ships with a default.
    if (title.isEmpty) return;

    final scheduledAt = _scheduledAt;
    final durationMinutes = _durationMinutes;

    setState(() => _isSaving = true);

    try {
      final notifier = ref.read(taskListProvider.notifier);
      Future<Task> attempt() => notifier.createTask(
        title: title,
        scheduledAt: scheduledAt,
        durationMinutes: durationMinutes,
        categoryId: _categoryId,
        recurrenceRule: _repeats ? _recurrenceRule : null,
        behaviorId: _behaviorId,
        notificationsEnabled: _notificationsEnabled,
        isImportant: _isImportant,
        templateId: _templateId,
      );
      Task created;
      try {
        created = await attempt();
      } on TrialExpiredException {
        if (!mounted) return;
        final unlocked = await presentPaywallForTrialExpired(context, ref);
        if (!unlocked || !mounted) return;
        try {
          created = await attempt();
        } on TrialExpiredException {
          return;
        }
      }
      _hasSaved = true;
      // Lets the Timeline animate the new pill in rather than having it
      // appear fully-formed — the same handoff the full sheet's own save
      // performs.
      ref
          .read(recentlySavedTaskProvider.notifier)
          .record(created.id, SavedTaskChange.created);
      // Clearing the draft removes BOTH the placeholder pill and this
      // overlay; the real task pill takes the placeholder's place.
      ref.read(pendingTaskDraftProvider.notifier).clear();
    } finally {
      // Guarded: clearing the draft above unmounts this widget, so by the
      // time this runs there may be no State left to set.
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _openLabelModal() async {
    final result = await TaskCategoryModal.show(
      context: context,
      categoryId: _categoryId,
    );
    if (!mounted || result == null) return;
    setState(() => _categoryId = result);
  }

  /// Guards [_onCloseRequested] against firing twice (e.g. a second drag
  /// past the close threshold while the exit is already playing) — the
  /// same "runs exactly once" shape [_promoted]/[_entranceStarted] already
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

  DateTime get _scheduledAt {
    final draft = widget.draft.scheduledAt;
    final date = _dateOverride ?? draft;
    final time = _timeOverride ?? TimeOfDay.fromDateTime(draft);
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  int get _durationMinutes => _durationOverride ?? widget.draft.durationMinutes;

  RecurrenceRule get _recurrenceRule {
    final days = _selectedDays.isEmpty ? {DateTime.monday} : _selectedDays;
    return days.length == 7
        ? RecurrenceRule(frequency: RecurrenceFrequency.daily)
        : RecurrenceRule(
            frequency: RecurrenceFrequency.weekly,
            daysOfWeek: days.toList()..sort(),
          );
  }

  Future<void> _openPresetModal() async {
    final template = await TaskPresetModal.show(
      context: context,
      selectedTemplateId: _templateId,
    );
    if (!mounted || template == null) return;
    setState(() {
      _templateId = template.id;
      _titleController.text = template.title;
      _categoryId = template.categoryId;
      _behaviorId = template.behaviorId;
      _isImportant = template.isImportant;
    });
  }

  Future<void> _openDatePicker() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledAt,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (!mounted || picked == null) return;
    setState(() {
      _dateOverride = DateTime(picked.year, picked.month, picked.day);
    });
  }

  Future<void> _openStartTimeModal() async {
    final result = await TaskStartTimeModal.show(
      context: context,
      initialHour: _scheduledAt.hour,
      initialMinute: _scheduledAt.minute,
    );
    if (!mounted || result == null) return;
    setState(
      () => _timeOverride = TimeOfDay(hour: result.$1, minute: result.$2),
    );
  }

  Future<void> _openDurationModal() async {
    final result = await TaskDurationModal.show(
      context: context,
      initialMinutes: _durationMinutes,
    );
    if (!mounted || result == null) return;
    setState(() => _durationOverride = result);
  }

  Future<void> _openRepeatModal() async {
    final result = await TaskRepeatModal.show(
      context: context,
      enabled: _repeats,
      selectedDays: _selectedDays,
    );
    if (!mounted || result == null) return;
    setState(() {
      _repeats = result.enabled;
      _selectedDays = {...result.selectedDays};
    });
  }

  Future<void> _openBehaviorModal() async {
    final result = await TaskBehaviorModal.show(
      context: context,
      behaviorId: _behaviorId,
    );
    if (!mounted || result == null) return;
    setState(() => _behaviorId = result.behaviorId);
  }

  String _dateLabel(BuildContext context) {
    final date = _scheduledAt;
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Today';
    }
    return MaterialLocalizations.of(context).formatMediumDate(date);
  }

  String _startTimeLabel(BuildContext context) =>
      timelineClock(context, TimeOfDay.fromDateTime(_scheduledAt));

  String get _durationLabel => '${_durationMinutes}m';

  /// The content's natural height (fields, chips, bottom space), measured
  /// after layout. The small state hugs it — no empty band under the chips
  /// — capped at the old fixed share of the screen, which the Timeline's
  /// own clearance still assumes.
  double? _contentHeight;

  void _onContentHeight(double height) {
    if (!mounted || height == _contentHeight) return;
    setState(() => _contentHeight = height);
  }

  /// The panel's height for the controller's fraction: minimised → small →
  /// full, piecewise, with small = the content's height (see
  /// [_contentHeight]). Clamped at 0 — the fraction may go negative
  /// mid-drag (drag down to close), a height can't.
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
    final height = fraction <= small
        ? minHeight +
              (smallHeight - minHeight) *
                  (fraction - minimised) /
                  (small - minimised)
        : smallHeight +
              (fullHeight - smallHeight) * (fraction - small) / (1 - small);
    return math.max(0, height);
  }

  @override
  Widget build(BuildContext context) {
    // Once promoted, the real pushed route takes over entirely — this
    // overlay's own job is done (see _promote).
    if (_promoted) return const SizedBox.shrink();

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
        MediaQuery.paddingOf(context).bottom + theme.spacingBottomClearance;

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
      child: Stack(
        children: [
          AnimatedBuilder(
            animation: _heightController,
            builder: (context, _) {
              final fullHeight = viewport - theme.spacingXl;
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
                bottom: 0,
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
                          // A scroll view, not a bare Column — a defensive floor
                          // against a genuinely short viewport (a small/landscape
                          // device, or a wide-but-short test surface) where
                          // quickCreateSheetMinFraction's own height budget for
                          // handle+field+Done doesn't quite fit; scrolling beats
                          // a RenderFlex overflow, and on an ordinary phone
                          // portrait viewport this content never actually needs
                          // to scroll at all.
                          child: SingleChildScrollView(
                            // No horizontal padding here: the template strip
                            // below runs full-bleed so it can scroll past both
                            // edges rather than clipping inside an inset. Every
                            // other child applies the side padding itself.
                            child: AppSizeReporter(
                              onSize: (size) => _onContentHeight(size.height),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // A small top gap before the header row —
                                  // requested directly: "in quick mode needs slight
                                  // larger" top space than it had (this row
                                  // previously sat flush against the sheet's own
                                  // rounded top corner, zero gap, while the Add note
                                  // sheet's own AppSheet wrapper gives it spacingLg —
                                  // kept larger there deliberately, per the same
                                  // request). `spacingSm`, not `spacingLg`: a
                                  // genuinely SLIGHT nudge, not matching the other
                                  // sheet's larger inset.
                                  SizedBox(height: theme.spacingSm),
                                  // Handle and X (close) share one header row. The
                                  // handle is `Positioned.fill`ed behind the X so
                                  // its drag target spans the WHOLE row width, not
                                  // just the visual bar — Android's own non-modal
                                  // bottom sheet drags from anywhere in its header,
                                  // and this was reported directly as "difficult
                                  // to do" when only the hairline bar was grabbable.
                                  // The X stays on top of it (and wins its own
                                  // taps) at the same top-right position the real
                                  // full-size sheet's StepScaffold header uses.
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
                                              controller: _heightController,
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
                                          // outright rather than handing off to the
                                          // full form.
                                          // Both buttons hide while MINIMISED —
                                          // requested directly: "just the title is
                                          // shown, and there is this little handle
                                          // to expand or tap to expand." The handle
                                          // behind them stays, and becomes the whole
                                          // row's tap/drag target.
                                          if (!_heightController.minimised)
                                            Positioned(
                                              top: 0,
                                              bottom: 0,
                                              right: 0,
                                              child: Center(
                                                child: AppButton(
                                                  label: 'Add',
                                                  size: AppButtonSize.md,
                                                  shape: AppButtonShape.pill,
                                                  onPressed: _isSaving
                                                      ? null
                                                      : _schedule,
                                                ),
                                              ),
                                            ),
                                          if (!_heightController.minimised)
                                            Positioned(
                                              top: 0,
                                              bottom: 0,
                                              left: 0,
                                              child: Center(
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
                                                child: HeaderCircleButton(
                                                  theme: theme,
                                                  icon: Icons.close_rounded,
                                                  onTap: _onCloseRequested,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  // MINIMISED: the title alone, read-only, with the
                                  // handle above it the only control — requested
                                  // directly: "just the title is shown, and there
                                  // is this little handle to expand or tap to
                                  // expand." Tapping anywhere here restores the
                                  // small sheet, matching the handle's own tap.
                                  if (_heightController.minimised)
                                    GestureDetector(
                                      onTap: _heightController.restoreToSmall,
                                      behavior: HitTestBehavior.opaque,
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: theme.spacingLg,
                                        ),
                                        child: SizedBox(
                                          width: double.infinity,
                                          child: ListenableBuilder(
                                            listenable: _titleController,
                                            builder: (context, _) {
                                              final title = _titleController
                                                  .text
                                                  .trim();
                                              return Text(
                                                // "(No title)" confirmed directly,
                                                // matching the reference screenshot's
                                                // own wording for an unnamed draft.
                                                title.isEmpty
                                                    ? '(No title)'
                                                    : title,
                                                style: theme.textTitle.copyWith(
                                                  color: title.isEmpty
                                                      ? theme.colorTextSecondary
                                                      : theme.colorTextPrimary,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                textAlign: TextAlign.center,
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    )
                                  else ...[
                                    SizedBox(height: theme.spacingSm),
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: theme.spacingLg,
                                      ),
                                      child: AppTextField(
                                        controller: _titleController,
                                        label: 'Add title',
                                        // Bare text, no field chrome — requested
                                        // directly against a reference screenshot:
                                        // "we need a new style for the input field...
                                        // just text and, on top, can be edited." The
                                        // label doubles as the placeholder ("Add
                                        // title", matching that screenshot) since
                                        // there is no floating label in this variant.
                                        variant: AppTextFieldVariant.bare,
                                        // Not selectAllOnFocus: the field is CLEARED
                                        // outright when tapped (see onFocusChanged
                                        // below), so there is nothing left to select.
                                        // Tapping the field is itself a request for
                                        // the full form — requested directly ("when
                                        // name input is tapped then it goes into
                                        // near full screen mode"). Fires on the tap
                                        // itself (before any typing), so this stays
                                        // on the real sheet's own stage 1
                                        // (autofocused Name field, keyboard already
                                        // up) rather than skipping ahead — see
                                        // _promote's own doc comment on
                                        // stayOnNameStage.
                                        onFocusChanged: (hasFocus) {
                                          if (!hasFocus) return;
                                          // Reported directly: "New task name input
                                          // should be reset to nothing, clears, so
                                          // user can type in from scratch." Clearing
                                          // beats selectAllOnFocus here because the
                                          // full sheet this promotes into is seeded
                                          // from `initialTitle` — a selection would
                                          // not survive that handoff, but an empty
                                          // string does.
                                          _titleController.clear();
                                          _promote(stayOnNameStage: true);
                                        },
                                      ),
                                    ),
                                    // A clear break between the name and its
                                    // settings: the chips are a separate group.
                                    SizedBox(height: theme.spacingMd),
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: theme.spacingLg,
                                      ),
                                      // Full width, start-aligned: a shrink-wrapped
                                      // column was centred by the sheet's column,
                                      // insetting the chips from the name.
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Wrap(
                                            spacing: theme.spacingSm,
                                            runSpacing: theme.spacingSm,
                                            children: [
                                              AppValueChip(
                                                label: 'Preset',
                                                hasValue: false,
                                                onTap: _openPresetModal,
                                              ),
                                              AppValueChip(
                                                label: _dateLabel(context),
                                                hasValue: true,
                                                onTap: _openDatePicker,
                                              ),
                                              AppValueChip(
                                                label: _startTimeLabel(context),
                                                hasValue: true,
                                                onTap: _openStartTimeModal,
                                              ),
                                              AppValueChip(
                                                label: _durationLabel,
                                                hasValue: true,
                                                onTap: _openDurationModal,
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: theme.spacingSm),
                                          Wrap(
                                            spacing: theme.spacingSm,
                                            runSpacing: theme.spacingSm,
                                            children: [
                                              AppValueChip(
                                                label: '',
                                                icon: Icons.star_rounded,
                                                iconOnly: true,
                                                hasValue: _isImportant,
                                                onTap: () => setState(
                                                  () => _isImportant =
                                                      !_isImportant,
                                                ),
                                              ),
                                              AppValueChip(
                                                label: '#',
                                                iconOnly: true,
                                                hasValue:
                                                    _categoryId !=
                                                    BuiltInCategoryIds.general,
                                                onTap: _openLabelModal,
                                              ),
                                              AppValueChip(
                                                label: '',
                                                icon: Icons.fingerprint_rounded,
                                                iconOnly: true,
                                                hasValue: _behaviorId != null,
                                                onTap: _openBehaviorModal,
                                              ),
                                              AppValueChip(
                                                label: '',
                                                icon: _notificationsEnabled
                                                    ? Icons
                                                          .notifications_rounded
                                                    : Icons
                                                          .notifications_off_rounded,
                                                iconOnly: true,
                                                hasValue: _notificationsEnabled,
                                                onTap: () => setState(
                                                  () => _notificationsEnabled =
                                                      !_notificationsEnabled,
                                                ),
                                              ),
                                              AppValueChip(
                                                label: '',
                                                icon: Icons.repeat_rounded,
                                                iconOnly: true,
                                                hasValue: _repeats,
                                                onTap: _openRepeatModal,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  SizedBox(height: bottomSpace),
                                ],
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
