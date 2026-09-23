import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_mic_button.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/app_sheet_handle.dart';
import '../../core/widgets/app_step_scaffold.dart' show HeaderCircleButton;
import '../../core/widgets/app_undo_toast.dart';
import '../../shared/models/category.dart';
import '../../shared/models/task.dart';
import '../../shared/providers/category_providers.dart';
import '../../shared/providers/task_providers.dart';
import '../../shared/services/quick_capture_parser.dart';

/// Opens the quick-capture sheet — free-text entry for adding an item to
/// the Inbox (or, on a confident natural-language parse, straight onto the
/// Timeline). Per design principle 2 (capture is frictionless,
/// prioritization is deferred): typing alone is enough, no required
/// fields, no confirmation step — see [parseQuickCapture] for exactly
/// what "confident" means and docs/DECISIONS.md for why that threshold
/// was chosen.
///
/// [task] is null for a genuinely new capture. Passing an existing
/// (unscheduled) [task] switches this into an EDIT of that same note's
/// title — requested directly: tapping an existing Inbox card reuses this
/// same sheet rather than a second, near-identical one. Editing only ever
/// rewrites the existing task's title via [TaskList.updateTask] — it never
/// re-parses the input as a natural-language quick capture (no
/// auto-scheduling from typed text once a real task already exists), and
/// never creates a second task.
///
/// **No header title text** (2026-09-21) — requested directly, alongside
/// moving Close/mic/Done into one header row: Close top-left, mic (styled
/// secondary — [AppMicButton.isPrimary] false, and sized to match Done via
/// [AppMicButton.size]) then Done (a small circular [HeaderCircleButton],
/// not the large pill [AppButton] Task creation uses) top-right. New-vs-
/// edit is no longer distinguished by a title at all; only the hint text
/// still differs (see the field's own `hintText`). A drag handle
/// ([AppSheetHandle]) sits above this row — dragging it down far/fast
/// enough closes the sheet, the same "handle to dismiss" affordance
/// `QuickCreateSheetHandle` gives the quick-create overlay.
///
/// **Keyboard submit keeps the sheet open** (2026-09-21) — pressing the
/// keyboard's own "done" key creates the task and clears the field for
/// another entry, rather than closing, so several notes/tasks can be
/// captured in a row. **The header's own Done button now does the exact
/// same thing** (2026-09-22, requested directly against
/// docs/DESIGN_SYSTEM.md's "Sheets" section: a sheet's primary action
/// "should act the same way as Submit in keyboard... but not close
/// modal") — only the Close button, a tap outside the sheet, or dragging
/// the handle down actually closes it. See
/// [_QuickCaptureFormState._submit] and the field's own
/// `onEditingComplete` doc comment for why a no-op override there is
/// required (not optional) to actually keep the keyboard up through a
/// kept-open submit, rather than visibly flashing closed and reopening.
///
/// Stays [AppSheetSize.small] (content-sized) — reversed back from a
/// brief [AppSheetSize.half] attempt, confirmed directly: "since we added
/// close add note sheet has scrolling shouldn't have should automatically
/// push size to match content." The Close button (not a fixed height) is
/// what makes the sheet feel appropriately roomy now; forcing a fixed
/// half-viewport height on top of that just left dead space and an
/// unnecessary scroll region for a form this short.
Future<void> showQuickCaptureSheet(BuildContext context, {Task? task}) {
  return AppSheet.show<void>(
    context: context,
    // The CALLER's context (captured here, before the sheet route
    // exists) is what the undo toast anchors to — the sheet's own
    // context becomes invalid the instant `Navigator.pop()` removes its
    // route, but the screen underneath (whatever called
    // showQuickCaptureSheet) keeps its Overlay ancestor for the toast to
    // insert into.
    builder: (sheetContext) =>
        _QuickCaptureForm(rootContext: context, task: task),
  );
}

class _QuickCaptureForm extends ConsumerStatefulWidget {
  const _QuickCaptureForm({required this.rootContext, this.task});

  /// See [showQuickCaptureSheet]'s own doc comment on why this is the
  /// CALLER's context, not this widget's own `context`.
  final BuildContext rootContext;

  /// Null for a new capture; the existing task being renamed otherwise —
  /// see [showQuickCaptureSheet]'s own doc comment.
  final Task? task;

  @override
  ConsumerState<_QuickCaptureForm> createState() => _QuickCaptureFormState();
}

class _QuickCaptureFormState extends ConsumerState<_QuickCaptureForm> {
  late final TextEditingController _titleController;
  late final FocusNode _focusNode;

  /// Whether this sheet is renaming an existing captured task rather than
  /// creating a new one — drives the field's hint text and [_doSubmit]'s
  /// branch. See [_QuickCaptureForm.task]'s own doc comment.
  bool get _isEditing => widget.task != null;

  /// True for the duration of an in-flight [_doSubmit] — the re-entrancy
  /// guard, same reasoning as `_TaskDetailFlowState._isSaving`: without
  /// this, a second tap/keyboard-submit before the previous one finishes
  /// could create the same task twice (or capture the same title twice on
  /// the fallback path). The header Done button has no loading spinner to
  /// drive (it's a plain [HeaderCircleButton], not an [AppButton]) — this
  /// guard alone is what prevents the double-submit.
  bool _isSubmitting = false;

  /// Cumulative vertical drag distance on the sheet's own handle — reset
  /// to 0 on every drag end regardless of outcome. See the handle's own
  /// `onVerticalDragEnd` for the close threshold.
  double _dragDistance = 0;

  /// One [stt.SpeechToText] instance per sheet, not a shared/cached
  /// singleton — `initialize()` is cheap to call again and this way the
  /// permission/availability check is always fresh for the session the
  /// mic button is actually used in.
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    // Editing an existing note's title is never re-parsed as natural
    // language (see the class doc comment) — the live token highlighting
    // `_QuickCaptureTextEditingController` does would be actively
    // misleading here (highlighting a "tomorrow" or "3pm" that will never
    // actually be scheduled from this field), so edit mode uses a plain
    // controller instead, pre-filled with the task's current title.
    _titleController = _isEditing
        ? TextEditingController(text: widget.task!.title)
        : _QuickCaptureTextEditingController(
            theme: () => Theme.of(context).extension<AmbleTheme>()!,
            categories: () => ref.read(categoryListProvider),
          );
    // `autofocus: true` on the field itself (see build()) rather than a
    // focus request from here — the keyboard then starts rising as the
    // sheet mounts, so the two rise TOGETHER as one entrance.
    //
    // A previous version deferred focus until the sheet's own slide-up
    // had completed, reasoning that the two animations shouldn't overlap.
    // That was backwards, and reported directly: "the new note sheet
    // opens in two sequences: 1. opens the actual sheet. 2. after a
    // moment, the keyboard is pushing it. While creating a task, the big
    // sheet is opening without that kind of delay. Both open at once."
    // Not overlapping is exactly what produced the two-step feel; the
    // task-detail sheet (the one that feels right) has always used plain
    // `autofocus`, and this now matches it.
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    if (_isListening) _speech.stop();
    _titleController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Starts/stops dictation. Permission (mic + speech recognition) is
  /// requested lazily here, on first tap — same pattern as
  /// `NotificationService.requestPermissionIfNeeded`, not at app start.
  /// Denial just leaves the mic button inert; typing still works, so the
  /// form never dead-ends.
  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }

    final available = await _speech.initialize();
    if (!available || !mounted) return;

    setState(() => _isListening = true);
    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        // Only the final transcript lands in the field — no progressive
        // highlighting of interim/partial results for this first pass
        // (see docs/SCOPE.md): partial results can still change words
        // mid-recognition, which would fight with the live token
        // highlighting `_QuickCaptureTextEditingController` already does
        // on every keystroke.
        if (result.finalResult) {
          _titleController.text = result.recognizedWords;
          setState(() => _isListening = false);
        }
      },
      // Default silence timeout (unset) is a short, platform-chosen pause
      // (a couple of seconds) — too eager for a task title that has a
      // natural mid-sentence pause (e.g. "Call client... tomorrow at
      // 10:30"). Extended to 5s, confirmed directly.
      listenOptions: stt.SpeechListenOptions(
        pauseFor: const Duration(seconds: 5),
      ),
    );
  }

  /// Submits the current title — shared by the header's own Done button
  /// AND the keyboard's "done" key, which now behave identically
  /// (2026-09-22, requested directly per docs/DESIGN_SYSTEM.md's "Sheets"
  /// section: a sheet's primary action "should act the same way as
  /// Submit in keyboard... but not close modal"). Creates/captures the
  /// task and KEEPS the sheet open, ready for another entry, so several
  /// notes/tasks can be captured in a row — the sheet now closes ONLY via
  /// its Close button or dragging the handle down (see [_doSubmit]'s own
  /// two exceptions: a genuinely empty title, and editing an existing
  /// note, both of which still close since there's nothing left to "add
  /// another" of).
  Future<void> _submit() => _doSubmit();

  Future<void> _doSubmit() async {
    if (_isSubmitting) return;

    final rawInput = _titleController.text.trim();
    // Matches Task creation's own stage-1 "Done" exactly (see
    // _TaskDetailFlowState._confirmNameStage): nothing typed abandons the
    // sheet instead of no-opping — requested directly, alongside renaming
    // this button from "Add" to "Done" to match that same semantic. Always
    // closes, even from the keyboard-submit path — there is nothing to
    // clear-and-reopen for on an empty title.
    if (rawInput.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    if (_isEditing) {
      // Editing an existing note only ever rewrites its title — never
      // re-parsed as natural language (see the class doc comment: a
      // second confident parse here could silently schedule/re-categorize
      // a task the user only meant to rename), never creates a second
      // task. Always closes — renaming has no "add another" to chain
      // into, unlike every other branch below.
      setState(() => _isSubmitting = true);
      try {
        final task = widget.task!;
        task.title = rawInput;
        await ref.read(taskListProvider.notifier).updateTask(task);
        if (!mounted) return;
        Navigator.of(context).pop();
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final categories = ref.read(categoryListProvider);
      final result = parseQuickCapture(
        rawInput,
        now: DateTime.now(),
        categories: categories,
      );
      final notifier = ref.read(taskListProvider.notifier);

      if (!result.isConfident) {
        // Exactly today's fallback behavior — the whole input becomes the
        // title, unscheduled, in the Inbox. No auto-scheduling guessed from
        // ambiguous text (e.g. a bare "every morning" or "for 30 mins" with
        // no date/time anchor) — see parseQuickCapture's own doc comment for
        // the precise confidence rule.
        await notifier.captureTask(rawInput);
        if (!mounted) return;
        _resetForNextCapture();
        return;
      }

      // Confident parse: create immediately, no confirmation dialog.
      final created = await notifier.createTask(
        title: result.title.isEmpty ? rawInput : result.title,
        scheduledAt: result.scheduledAt!,
        durationMinutes:
            result.durationMinutes ?? quickCaptureDefaultDurationMinutes,
        // A detected category word (e.g. "work", "health") wins; falls back
        // to the existing uncategorised default otherwise.
        categoryId: result.category?.id ?? BuiltInCategoryIds.general,
        recurrenceRule: result.recurrenceRule,
      );

      if (!mounted) return;

      // Undo toast anchors to `widget.rootContext` (the CALLER's context,
      // captured before this sheet's own route existed) rather than this
      // sheet's own `context` — the sheet stays open on every successful
      // capture now, but anchoring to the caller keeps this path
      // identical to `_isEditing`'s closing branch above, which has no
      // other context to anchor to once its own route pops.
      _resetForNextCapture();

      if (!widget.rootContext.mounted) return;

      // `notifier` (captured at the very top of this method, before ANY
      // dispose could happen on the closing path) is what onUndo below
      // must close over — NOT a fresh `ref.read(...)` here. On the closing
      // path this widget's own State is disposed the instant the sheet
      // pops, and `ref` on a disposed ConsumerState cannot be used; the
      // toast's Undo button fires long after that. Real bug, reported
      // directly: Undo showed and dismissed correctly but never actually
      // removed the task — an earlier version of this method re-read
      // `ref.read(taskListProvider.notifier)` at this exact point, after
      // the disposal that made it unsafe.
      final time = TimeOfDay.fromDateTime(result.scheduledAt!);
      AppUndoToast.show(
        context: widget.rootContext,
        message:
            "Created '${created.title}' at ${time.format(widget.rootContext)}",
        // A confident parse with a recurrence phrase materializes a whole
        // series (createTask does this immediately — see task_providers.dart),
        // so undoing it has to remove the whole series, not just the one
        // instance the toast is nominally "about".
        onUndo: () => created.isRecurring
            ? notifier.deleteTaskSeries(created)
            : notifier.deleteTask(created.id),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// Clears the title field and keeps focus/keyboard up, ready for the
  /// next capture. Runs after every successful create/capture (both the
  /// keyboard's own submit and the header's Done button — see [_submit]'s
  /// own doc comment), mirroring how the sheet already starts (autofocused,
  /// empty) rather than inventing a second look for "ready to type."
  void _resetForNextCapture() {
    _titleController.clear();
    if (!_focusNode.hasFocus) _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;

    return Padding(
      // Breathing room below the header row, so the sheet doesn't end
      // flush against the keyboard's top edge or the screen bottom.
      // Requested directly: "add padding bottom to that add/edit note
      // sheet."
      //
      // The KEYBOARD's own inset is deliberately NOT added here any more:
      // AppSheet now applies it for every sheet, via an AnimatedPadding
      // that smooths the keyboard's rise (see `liftedForKeyboard`).
      // Reading `viewInsets` here as well would double-count it — and
      // reading it raw, per frame, is exactly what made the sheet jitter
      // against its own slide-up transition.
      padding: EdgeInsets.only(bottom: theme.spacingLg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag-down-to-close handle — requested directly: "we should
          // have sheet 'handle' that user can drag down to close." Own
          // GestureDetector (not reusing `QuickCreateSheetHandle`, which
          // drives that OTHER sheet's own small/minimised/full fraction
          // system — this sheet has exactly one size, so it only needs
          // "dragged past a threshold closes," not a height to animate).
          // Sized to the row's own height, centered, matching
          // `QuickCreateSheetHandle`'s own "top-aligned, small inset, full
          // row is the hit target" shape (see its doc comment) so the
          // handle is easy to grab without demanding a precise hit on the
          // 4px bar itself.
          Center(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragUpdate: (details) =>
                  _dragDistance += details.delta.dy,
              onVerticalDragEnd: (details) {
                // Whichever comes first: dragged far enough, or flicked
                // fast enough — mirrors `QuickCreateSheetHeightController
                // .settle`'s own "distance OR velocity" threshold shape,
                // scaled down for this sheet's much shorter travel (it has
                // no fraction to settle into, just closed/open).
                final farEnough = _dragDistance > theme.spacingXl;
                final fastEnough =
                    details.velocity.pixelsPerSecond.dy > 800;
                _dragDistance = 0;
                if (farEnough || fastEnough) Navigator.of(context).pop();
              },
              child: Padding(
                // Top inset matches the unified reference value
                // (docs/DESIGN_SYSTEM.md's "Sheets" section,
                // `spacingSm` — nudged down one rung from the original
                // `spacingXs`, 2026-09-22). Bottom kept equal so the
                // handle stays vertically centered within its own row.
                padding: EdgeInsets.symmetric(vertical: theme.spacingSm),
                child: AppSheetHandle(theme: theme),
              ),
            ),
          ),
          SizedBox(height: theme.spacingSm),
          // No title text any more — requested directly, alongside moving
          // Close/mic/Done into one header row (Close top-left, mic and
          // Done top-right) rather than a titled header followed by a
          // separate action row below the field.
          Row(
            children: [
              HeaderCircleButton(
                theme: theme,
                icon: Icons.close_rounded,
                onTap: () => Navigator.of(context).pop(),
              ),
              const Spacer(),
              AppMicButton(
                isListening: _isListening,
                onPressed: _isSubmitting ? null : _toggleListening,
                // Secondary, not primary — requested directly: Done is the
                // one primary action in this header, mic is a supporting
                // input method alongside it.
                isPrimary: false,
                // Matches the Done button's own HeaderCircleButton size
                // exactly — requested directly: "voice record should be
                // same size as done."
                size: theme.spacingXl,
              ),
              SizedBox(width: theme.spacingSm),
              HeaderCircleButton(
                theme: theme,
                icon: Icons.check_rounded,
                // Re-entrancy is guarded inside `_doSubmit`'s own
                // `_isSubmitting` check (same as every other submit path
                // here), not by disabling this button — `HeaderCircleButton`
                // takes a non-nullable `onTap`.
                onTap: _submit,
                backgroundColor: theme.colorAccent,
                iconColor: theme.colorSurfacePrimary,
              ),
            ],
          ),
          SizedBox(height: theme.spacingMd),
          // Bare text, no field chrome — matching quick-create's own
          // "Add title" input style exactly (AppTextField's
          // AppTextFieldVariant.bare), requested directly. Kept as a raw
          // TextField (not AppTextField itself) because the live token
          // highlighting below needs `_QuickCaptureTextEditingController`,
          // which AppTextField has no hook for — but every visual property
          // (style, hint color, zero chrome) mirrors that variant's own
          // build() exactly.
          TextField(
            controller: _titleController,
            focusNode: _focusNode,
            // Fires as the sheet mounts, so the keyboard rises with the
            // sheet's own entrance rather than after it — see initState's
            // note on why deferring this read as two separate steps.
            autofocus: true,
            style: theme.textTitle.copyWith(color: theme.colorTextPrimary),
            cursorColor: theme.colorTextPrimary,
            textInputAction: TextInputAction.done,
            // Submitting (the keyboard's own "done" key) creates the task
            // but leaves the sheet open — requested directly, so several
            // notes/tasks can be added in a row without reopening this
            // sheet each time. The header's own Done button now calls the
            // exact same `_submit` (2026-09-22 — see its own doc comment),
            // so only Close or dragging the handle down actually closes
            // this sheet. Editing an existing note is unaffected:
            // `_submit`'s own `_isEditing` branch pops regardless of which
            // control called it, since renaming a single task has nothing
            // left to "add another" of.
            onSubmitted: (_) => _submit(),
            // A no-op `onEditingComplete` is REQUIRED here, not optional
            // polish — reported directly: "when tapping add on keyboard
            // the sheet and keyboard collapses and expands but it should
            // remain open." `EditableText._finalizeEditing` unconditionally
            // unfocuses on `TextInputAction.done` UNLESS `onEditingComplete`
            // is provided (see its own doc comment) — that unfocus, THEN
            // our `_resetForNextCapture` re-requesting focus a moment
            // later, is exactly what read as the keyboard flashing closed
            // and reopening. Overriding this to a no-op keeps focus
            // continuously held throughout the whole submit, so the
            // keyboard never drops in the first place; `onSubmitted` above
            // still fires afterward regardless (Flutter calls it
            // unconditionally once `onEditingComplete` returns).
            onEditingComplete: () {},
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              hintText: _isEditing
                  ? 'What needs doing?'
                  : 'Try "Call client tomorrow at 10:30"',
              hintStyle: theme.textTitle.copyWith(
                color: theme.colorTextSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Live inline token highlighting, implemented via a
/// [TextEditingController] subclass overriding [buildTextSpan] — flagged
/// approach, per the work order: Flutter's `TextField` has no native
/// support for styling substrings while typing, and the two common ways
/// to fake it are (a) a transparent `TextField` layered under a
/// `RichText` painting the highlighted look, or (b) exactly this —
/// overriding how the REAL, single `TextField` paints its own text.
/// Chosen over the overlay approach because it keeps cursor placement,
/// text selection, IME composition, and deletion entirely native — there
/// is only ever one text-rendering object, so there's no second copy of
/// the text that can visually drift out of sync with the real one
/// (a real risk with a stacked-overlay approach, since the overlay's
/// RichText and the real invisible TextField must stay pixel-identical
/// in font metrics, scroll offset, and wrapping for the illusion to
/// hold). Re-parses on every [buildTextSpan] call — cheap for Quick
/// Capture's short, single-line input; not something to reuse verbatim
/// for a large multi-line document.
class _QuickCaptureTextEditingController extends TextEditingController {
  _QuickCaptureTextEditingController({
    required this.theme,
    required this.categories,
  });

  final AmbleTheme Function() theme;

  /// Closure rather than a plain list, matching [theme] — read fresh on
  /// every [buildTextSpan] call so newly created categories highlight
  /// correctly without needing this controller replaced.
  final List<Category> Function() categories;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final input = text;
    if (input.isEmpty) {
      return TextSpan(style: style, text: input);
    }

    final result = parseQuickCapture(
      input,
      now: DateTime.now(),
      categories: categories(),
    );
    if (result.tokens.isEmpty) {
      return TextSpan(style: style, text: input);
    }

    final t = theme();
    final spans = <TextSpan>[];
    var cursor = 0;

    for (final token in result.tokens) {
      if (token.start > cursor) {
        spans.add(TextSpan(text: input.substring(cursor, token.start)));
      }
      spans.add(
        TextSpan(
          text: input.substring(token.start, token.end),
          style: TextStyle(
            color: _highlightColor(t, token.kind),
            fontWeight: FontWeight.w700,
          ),
        ),
      );
      cursor = token.end;
    }
    if (cursor < input.length) {
      spans.add(TextSpan(text: input.substring(cursor)));
    }

    return TextSpan(style: style, children: spans);
  }

  /// Four existing Tier 2 tokens, not new arbitrary colors, per the work
  /// order — flagged mapping, since none was originally named for this
  /// purpose: [AmbleTheme.colorAccent] (date/time — the brand color,
  /// matching how accent already marks the primary/selected state
  /// elsewhere), the WORK category's icon color (duration — an existing
  /// saturated, distinguishable glyph color), [AmbleTheme.colorTaskAlert]
  /// (recurrence — an existing "notable, distinct from ordinary text"
  /// semantic color), and the PERSONAL category's icon color (a detected
  /// category word — deliberately a DIFFERENT category's color than
  /// duration's, so the two never read as the same highlight by
  /// coincidence). All four read clearly against the field's own fill in
  /// both light and dark palettes, and none collides with a category's
  /// own timeline color, since none of the four is being shown on a
  /// category pill here.
  Color _highlightColor(AmbleTheme t, QuickCaptureTokenKind kind) =>
      switch (kind) {
        QuickCaptureTokenKind.dateTime => t.colorAccent,
        QuickCaptureTokenKind.duration =>
          t.categoryIconColors[TaskCategoryToken.work]!,
        QuickCaptureTokenKind.recurrence => t.colorTaskAlert,
        QuickCaptureTokenKind.category =>
          t.categoryIconColors[TaskCategoryToken.personal]!,
      };
}
