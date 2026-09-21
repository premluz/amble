import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../shared/models/category.dart';
import '../../shared/providers/category_providers.dart';
import '../../shared/providers/task_providers.dart';
import '../../shared/services/quick_capture_parser.dart';
import 'voice_capture_state.dart';

export 'voice_capture_state.dart';

part 'voice_capture_provider.g.dart';

/// Owns one voice-capture session — the full-screen "speak your tasks"
/// flow's own [stt.SpeechToText] instance, separate from Quick Capture's
/// (`quick_capture_sheet.dart`'s `_QuickCaptureFormState._speech`).
/// Confirmed directly rather than assumed: the two need genuinely
/// different `listen()` configs (this one needs `partialResults` and
/// `onSoundLevelChange` for the live waveform; Quick Capture only
/// surfaces final results, to avoid fighting its live token highlighting)
/// and different session lifetimes (one continuous multi-segment session
/// here vs. one single-shot dictation there).
///
/// `autoDispose` (the codegen default) — screen-local session state,
/// matching [EditModeEnabled]'s own precedent (`edit_mode_provider.dart`):
/// a returning user should never silently resume an old recording
/// session.
///
/// State shape ([VoiceCaptureState]/[VoiceCaptureStatus]) lives in
/// `voice_capture_state.dart`, re-exported here so callers only import
/// this one file — split purely to keep each file under CLAUDE.md's
/// 200-line guidance.
@riverpod
class VoiceCapture extends _$VoiceCapture {
  final stt.SpeechToText _speech = stt.SpeechToText();

  /// Growing transcript for the segment currently in progress — reset to
  /// empty each time a segment commits. [stt.SpeechToText]'s own
  /// `onResult` callback hands back the FULL recognized text for the
  /// current listen() call each time it fires (not just the delta), so
  /// this is what [_commitSegment] reads once a segment finalizes.
  String _liveText = '';

  @override
  VoiceCaptureState build() {
    ref.onDispose(() {
      if (_speech.isListening) _speech.stop();
    });
    return const VoiceCaptureState();
  }

  /// Starts (or resumes) listening. Permission is requested lazily on
  /// first call — same pattern as
  /// `_QuickCaptureFormState._toggleListening`: a denial just leaves the
  /// screen in [VoiceCaptureStatus.idle] rather than dead-ending the
  /// whole flow, since the screen can still show whatever was already
  /// committed and offer Submit.
  Future<void> startListening() async {
    if (state.status == VoiceCaptureStatus.listening) return;

    final available = await _speech.initialize();
    if (!available) return;

    _liveText = '';
    state = state.copyWith(status: VoiceCaptureStatus.listening);
    await _listenOnce();
  }

  /// One `listen()` call, covering exactly one segment. Restarted by
  /// [_onResult] on every silence-gap commit — the SDK call itself ends
  /// when [voiceCaptureSilenceGap] elapses (`pauseFor`), so continuing
  /// after a pause means a NEW `listen()` call, not one continuous stream.
  Future<void> _listenOnce() async {
    await _speech.listen(
      onResult: _onResult,
      onSoundLevelChange: _onSoundLevelChange,
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        pauseFor: voiceCaptureSilenceGap,
      ),
    );
  }

  void _onSoundLevelChange(double level) {
    if (state.status != VoiceCaptureStatus.listening) return;
    // The raw value is platform-specific (decibels on iOS, an
    // undocumented scale on Android, per `speech_to_text`'s own docs) —
    // normalized here rather than leaking a raw platform number into
    // [VoiceCaptureState]. A rough -2..10 floor/ceiling covers both
    // platforms' typical range.
    final normalized = ((level + 2) / 12).clamp(0.0, 1.0);
    state = state.copyWith(soundLevel: normalized);
  }

  void _onResult(SpeechRecognitionResult result) {
    if (state.status != VoiceCaptureStatus.listening) return;
    _liveText = result.recognizedWords;

    if (result.finalResult) {
      // The `pauseFor` timeout is what produced this final result — per
      // [voiceCaptureSilenceGap]'s own doc comment, that silence IS the
      // segment boundary, so a non-empty final result always commits.
      _commitSegment();
      // Silence gap is invisible to the user — status stays `listening`
      // and a new segment starts right away, confirmed directly.
      if (state.status == VoiceCaptureStatus.listening) {
        _listenOnce();
      }
    }
    // Partial (non-final) results are tracked only in `_liveText` — the
    // status card's text is static now (requested directly), so there is
    // no UI left to push interim words to.
  }

  void _commitSegment() {
    final text = _liveText.trim();
    _liveText = '';
    if (text.isEmpty) return;
    state = state.copyWith(committedSegments: [...state.committedSegments, text]);
  }

  /// The explicit user action — stops the SDK session entirely and shows
  /// the Paused state. Distinct from the automatic silence-gap restart in
  /// [_onResult]: see [VoiceCaptureStatus.paused]'s own doc comment.
  Future<void> pause() async {
    if (state.status != VoiceCaptureStatus.listening) return;
    // Whatever was said since the last committed segment is still real
    // speech the user intends to keep — commit it now rather than
    // discarding it just because they paused mid-sentence.
    _commitSegment();
    await _speech.stop();
    state = state.copyWith(status: VoiceCaptureStatus.paused, soundLevel: 0);
  }

  /// Resumes listening after [pause] — appends further segments onto the
  /// same [VoiceCaptureState.committedSegments] list rather than starting
  /// a fresh session, confirmed directly.
  Future<void> resume() => startListening();

  /// Test-only seam: the real segment list only ever grows through a
  /// live [stt.SpeechToText] session (see [_onResult]), which has no
  /// platform channel to drive in a widget-test environment. Lets
  /// [submit]'s own task-creation behaviour be tested without a real
  /// recognizer.
  @visibleForTesting
  void debugSetCommittedSegments(List<String> segments) {
    state = state.copyWith(committedSegments: segments);
  }

  /// Runs every committed segment through the SAME [parseQuickCapture] +
  /// [TaskList.createTask]/[TaskList.captureTask] path Quick Capture uses
  /// today (`quick_capture_sheet.dart`'s own `_submit`) — no new
  /// task-creation logic, so a spoken "call John tomorrow at 3pm" is
  /// scheduled exactly like a typed one, confirmed directly.
  Future<void> submit() async {
    if (!state.canSubmit || state.status == VoiceCaptureStatus.submitting) {
      return;
    }

    if (_speech.isListening) await _speech.stop();
    state = state.copyWith(status: VoiceCaptureStatus.submitting);

    final categories = ref.read(categoryListProvider);
    final notifier = ref.read(taskListProvider.notifier);

    for (final segment in state.committedSegments) {
      final result = parseQuickCapture(
        segment,
        now: DateTime.now(),
        categories: categories,
      );

      if (!result.isConfident) {
        await notifier.captureTask(segment);
        continue;
      }

      await notifier.createTask(
        title: result.title.isEmpty ? segment : result.title,
        scheduledAt: result.scheduledAt!,
        durationMinutes:
            result.durationMinutes ?? quickCaptureDefaultDurationMinutes,
        categoryId: result.category?.id ?? BuiltInCategoryIds.general,
        recurrenceRule: result.recurrenceRule,
      );
    }

    state = const VoiceCaptureState();
  }
}
