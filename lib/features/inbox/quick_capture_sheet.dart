import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_mic_button.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/app_undo_toast.dart';
import '../../shared/models/category.dart';
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
Future<void> showQuickCaptureSheet(BuildContext context) {
  return AppSheet.show<void>(
    context: context,
    // The CALLER's context (captured here, before the sheet route
    // exists) is what the undo toast anchors to — the sheet's own
    // context becomes invalid the instant `Navigator.pop()` removes its
    // route, but the screen underneath (whatever called
    // showQuickCaptureSheet) keeps its Overlay ancestor for the toast to
    // insert into.
    builder: (sheetContext) => _QuickCaptureForm(rootContext: context),
  );
}

class _QuickCaptureForm extends ConsumerStatefulWidget {
  const _QuickCaptureForm({required this.rootContext});

  /// See [showQuickCaptureSheet]'s own doc comment on why this is the
  /// CALLER's context, not this widget's own `context`.
  final BuildContext rootContext;

  @override
  ConsumerState<_QuickCaptureForm> createState() => _QuickCaptureFormState();
}

class _QuickCaptureFormState extends ConsumerState<_QuickCaptureForm> {
  late final _QuickCaptureTextEditingController _titleController;
  late final FocusNode _focusNode;

  /// True for the duration of an in-flight [_submit] — drives the Add
  /// button's spinner (see [AppButton.isLoading]) AND is the actual
  /// re-entrancy guard, same reasoning as
  /// `_TaskDetailFlowState._isSaving`: without this, a second tap before
  /// the sheet closes could create the same task twice (or capture the
  /// same title twice on the fallback path).
  bool _isSubmitting = false;

  /// One [stt.SpeechToText] instance per sheet, not a shared/cached
  /// singleton — `initialize()` is cheap to call again and this way the
  /// permission/availability check is always fresh for the session the
  /// mic button is actually used in.
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _titleController = _QuickCaptureTextEditingController(
      theme: () => Theme.of(context).extension<AmbleTheme>()!,
      categories: () => ref.read(categoryListProvider),
    );
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
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

  Future<void> _submit() async {
    if (_isSubmitting) return;

    final rawInput = _titleController.text.trim();
    if (rawInput.isEmpty) return;

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
        Navigator.of(context).pop();
        return;
      }

      // Confident parse: create immediately, no confirmation dialog, then
      // close the sheet and show the undo toast over whatever screen is
      // now visible (the sheet itself is gone by the time the toast
      // appears, so it can't anchor to the sheet's own context).
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
      Navigator.of(context).pop();

      if (!widget.rootContext.mounted) return;

      // `notifier` (captured at the very top of this method, before ANY
      // dispose could happen) is what onUndo below must close over — NOT a
      // fresh `ref.read(...)` here. This widget's own State is disposed the
      // instant the sheet pops (two lines up), and `ref` on a disposed
      // ConsumerState cannot be used; the toast's Undo button fires long
      // after that. Real bug, reported directly: Undo showed and dismissed
      // correctly but never actually removed the task — an earlier version
      // of this method re-read `ref.read(taskListProvider.notifier)` at
      // this exact point, after the disposal that made it unsafe.
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add to Inbox', style: theme.textTitle),
          SizedBox(height: theme.spacingMd),
          TextField(
            controller: _titleController,
            focusNode: _focusNode,
            style: theme.textBody,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              hintText: 'What needs doing? Try "Call client tomorrow at 10:30"',
              hintStyle: theme.textBody.copyWith(
                color: theme.colorTextSecondary,
              ),
              filled: true,
              fillColor: theme.colorSurfaceSecondary,
              contentPadding: EdgeInsets.symmetric(
                horizontal: theme.spacingMd,
                vertical: theme.spacingMd,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(theme.radiusMd),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          SizedBox(height: theme.spacingMd),
          Row(
            children: [
              AppMicButton(
                isListening: _isListening,
                onPressed: _isSubmitting ? null : _toggleListening,
              ),
              SizedBox(width: theme.spacingMd),
              Expanded(
                child: AppButton(
                  label: 'Add',
                  onPressed: _submit,
                  isLoading: _isSubmitting,
                ),
              ),
            ],
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
