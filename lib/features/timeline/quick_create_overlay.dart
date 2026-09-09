import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_step_scaffold.dart' show HeaderCircleButton;
import '../../core/widgets/app_switch.dart';
import '../../core/widgets/app_text_field.dart';
import '../../shared/models/category.dart';
import '../../shared/models/task_template.dart';
import '../../shared/providers/preferences_providers.dart';
import '../../shared/providers/task_providers.dart';
import '../../shared/services/overlap_checker.dart';
import 'recently_saved_task_provider.dart';
import '../task_detail/quick_create_sheet_shell.dart';
import '../task_detail/task_detail_sheet.dart';
import 'pending_task_draft_provider.dart';
import 'template_chip_strip.dart';

/// The small quick-create panel dropped alongside the wiggly placeholder
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

class _QuickCreateOverlayState extends ConsumerState<QuickCreateOverlay> {
  late final TextEditingController _titleController;
  late final QuickCreateSheetHeightController _heightController;

  /// Guards against promoting twice — [_onHeightChanged] fires on every
  /// `notifyListeners()`, and [_promote] is also reachable directly from
  /// the Name field's own focus and the Done button, but the promotion
  /// (pushing the real sheet) must happen exactly once per draft.
  bool _promoted = false;

  /// The template whose title/category the user applied, if any. Carried
  /// into the real sheet on promotion so the category survives the
  /// handoff — the mini sheet has no category field of its own to show
  /// it in, so the chip's own selected state is the only visible
  /// indication until the full form opens.
  TaskTemplate? _appliedTemplate;

  /// See [Task.isImportant]. Reported directly as missing from this
  /// panel ("can't see important in quick add in mini sheet") — the
  /// full sheet, the edit flow, and templates all gained a real toggle
  /// for this field, but the mini sheet's own direct-Schedule path
  /// (`_schedule`) had no way to set it at all, and applying a template
  /// carrying `isImportant: true` had nowhere to surface that either.
  /// Seeded from an applied template (see [_applyTemplate]) but always
  /// user-overridable afterward, same as the title field is.
  bool _isImportant = false;

  /// Set when a direct Schedule would collide with an existing task and
  /// the "Prevent overlapping tasks" setting is on — surfaced in the
  /// panel rather than silently refusing the tap. Mirrors the full
  /// sheet's own `_overlapError`.
  String? _overlapError;

  /// Re-entrancy guards for the direct save, mirroring the full sheet's
  /// own pair: [_isSaving] stops two taps overlapping, [_hasSaved] stops
  /// a second tap arriving after the first committed from creating a
  /// duplicate task.
  bool _isSaving = false;
  bool _hasSaved = false;

  @override
  void initState() {
    super.initState();
    // A real default name ("New task") rather than starting empty —
    // requested directly, so Schedule is always meaningful even if the
    // user never types. Tapping the field clears it outright (see the
    // field's own onFocusChanged) so typing starts from scratch.
    _titleController = TextEditingController(text: 'New task');
    _heightController = QuickCreateSheetHeightController(
      initialFraction: quickCreateSheetMinFraction,
    )..addListener(_onHeightChanged);
  }

  @override
  void dispose() {
    _heightController.removeListener(_onHeightChanged);
    _heightController.dispose();
    _titleController.dispose();
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
  /// including the untouched "New task" default), so they skip straight
  /// to the schedule fields as usual.
  void _promote({bool stayOnNameStage = false}) {
    if (_promoted) return;
    // Rebuilds this widget to render nothing (see build()'s own early
    // return) — once promoted, the real pushed route is the only visible
    // "sheet"; this overlay must not keep rendering alongside it.
    setState(() => _promoted = true);

    showTaskDetailSheet(
      context,
      initialScheduledAt: widget.draft.scheduledAt,
      initialTimeOfDay: TimeOfDay.fromDateTime(widget.draft.scheduledAt),
      draftId: widget.draft.id,
      initialTitle: _titleController.text,
      initialDurationMinutes: widget.draft.durationMinutes,
      initialCategoryId: _appliedTemplate?.categoryId,
      initialIsImportant: _isImportant,
      templateId: _appliedTemplate?.id,
      stayOnNameStage: stayOnNameStage,
    );
  }

  /// Creates the task directly from the mini sheet, without ever opening
  /// the full form — reported directly: "Done let's change to Schedule
  /// and it already sets the task there."
  ///
  /// Everything needed is already settled by this point: the title (typed
  /// or from a chip or the "New task" default), the category (from a chip,
  /// else General), and the start/duration (from where the user dropped
  /// and sized the placeholder pill). So this is a complete answer, not a
  /// shortcut past unanswered questions — the full sheet stays reachable
  /// for anything more (notes, repeats, notifications) by tapping the
  /// Name field.
  ///
  /// Enforces the same "Prevent overlapping tasks" guard the full sheet's
  /// own `_save` does. Skipping it here would make the mini sheet a way
  /// to create exactly the overlaps that setting exists to prevent.
  Future<void> _schedule() async {
    if (_isSaving || _hasSaved) return;

    final title = _titleController.text.trim();
    // Nothing sensible to create, and no field is showing an error — the
    // user has actively emptied a field that ships with a default.
    if (title.isEmpty) return;

    final scheduledAt = widget.draft.scheduledAt;
    final durationMinutes = widget.draft.durationMinutes;

    if (ref.read(preventOverlappingTasksSettingProvider) &&
        overlapsExistingTask(
          scheduledAt: scheduledAt,
          durationMinutes: durationMinutes,
          existingTasks: ref.read(taskListProvider),
        )) {
      setState(
        () => _overlapError =
            'This overlaps another task. Choose a different time.',
      );
      return;
    }

    setState(() {
      _overlapError = null;
      _isSaving = true;
    });

    try {
      final created = await ref
          .read(taskListProvider.notifier)
          .createTask(
            title: title,
            scheduledAt: scheduledAt,
            durationMinutes: durationMinutes,
            categoryId:
                _appliedTemplate?.categoryId ?? BuiltInCategoryIds.general,
            isImportant: _isImportant,
            templateId: _appliedTemplate?.id,
          );
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

  /// Applies a tapped template's title and category to the in-progress
  /// task — and deliberately NOT its duration, specified directly: "as
  /// soon as they click a template, that applies the name and the
  /// category, but not the duration. The duration is not overridden, it
  /// remains the one set by the user." By this point the user has
  /// already sized the placeholder pill by dragging and resizing it, so
  /// the draft's own `durationMinutes` is a real expressed intent that a
  /// template's suggested default must not overwrite.
  ///
  /// Applying does not promote to the full sheet — the user stays in the
  /// mini sheet, free to keep adjusting the pill or pick a different
  /// template.
  void _applyTemplate(TaskTemplate template) {
    setState(() {
      _appliedTemplate = template;
      _titleController.text = template.title;
      _isImportant = template.isImportant;
    });
  }

  /// Dragging the handle down far enough — or tapping the X — closes the
  /// whole flow, requested directly ("the sheet should also be closing
  /// with this handle that expands it... and close in same positions as
  /// big sheet"). Clears the draft, which removes both this overlay AND
  /// the placeholder pill from Timeline (the same "abandoned without
  /// saving" outcome the real sheet's own close button produces via
  /// `pendingTaskDraftProvider.notifier.clear()` — see
  /// `task_detail_sheet.dart`'s `_handleClose`).
  void _onCloseRequested() {
    ref.read(pendingTaskDraftProvider.notifier).clear();
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

    return Stack(
      children: [
        AnimatedBuilder(
          animation: _heightController,
          builder: (context, _) {
            final fullHeight = viewport - theme.spacingXl;
            final minHeight = math.max(
              viewport * quickCreateSheetMinFraction,
              barsHeight,
            );
            final fractionRange = 1.0 - quickCreateSheetMinFraction;
            // Clamped at 0 — the controller's own fraction is
            // deliberately allowed to go negative mid-drag (see
            // QuickCreateSheetHeightController.updateFraction's own doc
            // comment, for the "drag down to close" gesture), but a
            // real widget height obviously can't.
            final currentHeight = math.max(
              0.0,
              minHeight +
                  (fullHeight - minHeight) *
                      ((_heightController.fraction -
                              quickCreateSheetMinFraction) /
                          fractionRange),
            );

            return Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                height: currentHeight,
                // Nav-bar-matched fill with rounded top corners and no
                // shadow/glow — the Android non-modal bottom sheet
                // shape, requested directly.
                decoration: BoxDecoration(
                  color: theme.colorSurfacePrimary,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(theme.radiusModal),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: SafeArea(
                  top: false,
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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
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
                            // Taller than the old bare-handle row: it now
                            // has to fit real buttons, not just a hairline
                            // drag bar.
                            height: theme.spacingXl * 1.8,
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: QuickCreateSheetHandle(
                                    theme: theme,
                                    controller: _heightController,
                                    viewportHeight: viewport,
                                    onCloseRequested: _onCloseRequested,
                                  ),
                                ),
                                // Schedule sits at the header's LEFT,
                                // opposite the X — per the layout mockup,
                                // which moves it up out of the sheet's body
                                // so the template strip can occupy the full
                                // width below. Both buttons sit ON TOP of
                                // the `Positioned.fill` handle and win their
                                // own taps; the handle still drags from any
                                // part of the row they don't cover.
                                //
                                // "Schedule", not "Done": it commits the
                                // task outright rather than handing off to
                                // the full form — reported directly ("Done
                                // let's change to Schedule and it already
                                // sets the task there").
                                Positioned(
                                  top: 0,
                                  bottom: 0,
                                  left: 0,
                                  child: Center(
                                    child: AppButton(
                                      label: 'Schedule',
                                      size: AppButtonSize.regular,
                                      shape: AppButtonShape.pill,
                                      onPressed: _isSaving ? null : _schedule,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 0,
                                  bottom: 0,
                                  right: 0,
                                  child: Center(
                                    // Explicit `colorSurfaceSecondary`
                                    // rather than HeaderCircleButton's own
                                    // `colorSurfaceField` default —
                                    // requested directly ("the style of
                                    // close button should be same as in
                                    // big sheet"). The widget IS the same
                                    // one the big sheet uses, but that
                                    // sheet's body sits on
                                    // `colorSurfaceBase` while this panel
                                    // is nav-matched `colorSurfacePrimary`
                                    // (a step darker in dark mode), so the
                                    // shared default reads flatter here;
                                    // this restores the same visible
                                    // contrast against THIS ground.
                                    child: HeaderCircleButton(
                                      theme: theme,
                                      icon: Icons.close_rounded,
                                      backgroundColor:
                                          theme.colorSurfaceSecondary,
                                      onTap: _onCloseRequested,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: theme.spacingSm),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: theme.spacingLg,
                          ),
                          child: AppTextField(
                            controller: _titleController,
                            label: 'Task name',
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
                        // Important toggle — reported directly as
                        // missing from this panel ("can't see important
                        // in quick add in mini sheet"). Compact rather
                        // than a full AppPane, matching this sheet's own
                        // "small, no extra chrome" scale — the full
                        // sheet's own bare-pane treatment would be
                        // oversized here relative to the Name field
                        // beside it.
                        SizedBox(height: theme.spacingSm),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: theme.spacingLg,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Important',
                                style: theme.textBody.copyWith(
                                  color: theme.colorTextPrimary,
                                ),
                              ),
                              AppSwitch(
                                value: _isImportant,
                                onChanged: (value) =>
                                    setState(() => _isImportant = value),
                              ),
                            ],
                          ),
                        ),
                        // Surfaced in the panel rather than letting the
                        // Schedule tap silently do nothing — the mini
                        // sheet has no other way to explain a refusal.
                        if (_overlapError != null) ...[
                          SizedBox(height: theme.spacingSm),
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: theme.spacingLg,
                            ),
                            child: SizedBox(
                              width: double.infinity,
                              child: Text(
                                _overlapError!,
                                // Same token pair StepScaffold uses for
                                // this identical message in the full
                                // sheet.
                                style: theme.textBody.copyWith(
                                  color: theme.colorTaskAlert,
                                ),
                              ),
                            ),
                          ),
                        ],
                        // Matches the sheet's own side padding, reported
                        // directly: "larger gap from task name (same as
                        // from side paddings)."
                        SizedBox(height: theme.spacingLg),
                        // Full-bleed: the strip is the one child with no
                        // side padding of its own, so it can scroll past
                        // both edges of the sheet instead of clipping
                        // inside an inset. It applies `spacingLg` as its
                        // own leading/trailing inset so the first and
                        // last chip still line up with everything above.
                        TemplateChipStrip(
                          onTemplateSelected: _applyTemplate,
                          selectedTemplateId: _appliedTemplate?.id,
                        ),
                        SizedBox(height: theme.spacingSm),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  /// The backdrop's own height — reaches from the screen's bottom up to
  /// (approximately) the TOP of where DayStrip used to sit, so the sheet
  /// visually replaces BOTH bars that a live draft hides: the bottom
  /// NavigationBar and the DayStrip above it (day chips, view-switch
  /// button, "+" button). Requested directly: "it should cover also the
  /// days 'adjacent to main nav' with plus and view switch."
  ///
  /// Composed from the same tokens those two widgets build themselves
  /// from, rather than a hard dependency on either one's private layout:
  /// DayStrip is `AppBottomExtensionBar`'s `spacingSm` vertical padding
  /// (×2) around a `spacingXl * 1.6` chip row, and Material's own
  /// `NavigationBar` defaults to [kBottomNavigationBarHeight]. The
  /// device's own bottom safe-area inset sits under both and is added on
  /// top, since both bars wrap themselves in a `SafeArea`.
  double _backdropHeight(
    AmbleTheme theme,
    double viewport,
    double bottomInset,
  ) {
    final dayStripHeight = theme.spacingXl * 1.6 + theme.spacingSm * 2;
    return math.min(
      viewport,
      dayStripHeight + kBottomNavigationBarHeight + bottomInset,
    );
  }
}
