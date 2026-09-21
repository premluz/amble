import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
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
  /// this is what [_commitSegment] reads and what feeds
  /// [VoiceCaptureState.partialText].
  String _liveText = '';

  /// Fires [voiceCaptureSilenceGap] after the last recognized word to
  /// close off the current task name — see [_restartSilenceTimer]. Ours,
  /// not the SDK's, precisely because the SDK's equivalent (`pauseFor`)
  /// would stop the session instead of just marking a boundary.
  Timer? _silenceTimer;

  /// Debounces session reopening — see [_reopenSession].
  Timer? _reopenTimer;

  /// Everything already committed out of the CURRENT platform
  /// transcript, so [_onResult] can subtract it and keep only genuinely
  /// new speech. Cleared whenever the platform starts a fresh transcript
  /// or the session is stopped outright.
  String _committedText = '';

  @override
  VoiceCaptureState build() {
    ref.onDispose(() {
      _silenceTimer?.cancel();
      _reopenTimer?.cancel();
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

    // Registered on `initialize`, not `listen` (which has no such
    // parameters) — the `statusListener`/`errorListener` these set
    // persist for the life of this `_speech` instance, so [_onStatus]
    // and [_onError] keep covering any later session the platform cuts
    // short.
    final available = await _speech.initialize(
      onStatus: _onStatus,
      onError: _onError,
    );
    if (!available) return;

    _liveText = '';
    _committedText = '';
    state = state.copyWith(
      status: VoiceCaptureStatus.listening,
      partialText: '',
    );
    await _openSession();
  }

  /// Opens a platform listen session.
  ///
  /// `pauseFor` is [voiceCapturePlatformPauseFor] (30s), NOT
  /// [voiceCaptureSilenceGap] (2s) — see that constant's own doc comment.
  /// Passing the 2s task gap here made the SDK `_stop()` the session on
  /// every pause while our restart logic reopened it, which is the
  /// audible drop-and-restart cycle; omitting it entirely was worse on
  /// Android, where the OS recognizer then falls back to its own ~1s
  /// silence default and the plugin tears down shortly after.
  ///
  /// The 2s silence is a TASK boundary, not a session boundary
  /// (requested directly), so it is detected separately by
  /// [_restartSilenceTimer]. The session itself is meant to run
  /// continuously until [pause] or [submit] stops it; [_onStatus]
  /// reopens it if the platform ends it anyway.
  Future<void> _openSession() async {
    await _speech.listen(
      onResult: _onResult,
      onSoundLevelChange: _onSoundLevelChange,
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        pauseFor: voiceCapturePlatformPauseFor,
      ),
    );
  }

  /// Commits the in-progress segment once [voiceCaptureSilenceGap] passes
  /// with no new recognition activity — the "that task name is finished"
  /// rule, WITHOUT touching the session. Restarted on every result so the
  /// countdown always measures silence since the last recognized word.
  void _restartSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(voiceCaptureSilenceGap, () {
      if (state.status != VoiceCaptureStatus.listening) return;
      // Listening continues: the next words the user speaks land in a
      // fresh segment (and so a new card), which is the whole point of
      // the pause being a task delimiter rather than a stop.
      _commitSegment();
    });
  }

  /// Platform-level session status — recovery only, for a session the
  /// PLATFORM ended on its own (OS-imposed listen cap, audio focus lost).
  /// Nothing in this flow asks the SDK to stop any more (see
  /// [_openSession]), so reaching a not-listening status while the user
  /// still expects to be recording means something external cut us off
  /// and the session has to be reopened.
  void _onStatus(String status) {
    if (state.status != VoiceCaptureStatus.listening) return;
    if (status != stt.SpeechToText.doneStatus &&
        status != stt.SpeechToText.notListeningStatus) {
      return;
    }
    _reopenSession();
  }

  /// A recognizer error, which on Android also ENDS the session (the
  /// plugin's own `onError` calls `notifyListening(false)`). The common
  /// ones here are entirely benign for this flow — `error_no_match` and
  /// `error_speech_timeout` just mean "that stretch held no words,"
  /// which is exactly what happens while the user pauses between two
  /// tasks. Treated as another reopen trigger rather than a failure: the
  /// user asked to keep recording until they press pause, so a silent
  /// stretch must not end the session.
  ///
  /// Not surfaced in [VoiceCaptureState]: there is no user-actionable
  /// error here, and anything already committed is untouched. A
  /// genuinely fatal condition (permissions revoked mid-session) still
  /// leaves `_speech.isListening` false with nothing reopening
  /// successfully, which the UI reads as the waveform going flat.
  void _onError(SpeechRecognitionError error) {
    if (state.status != VoiceCaptureStatus.listening) return;
    _reopenSession();
  }

  /// Reopens a session the platform ended, for both [_onStatus] and
  /// [_onError].
  ///
  /// Guarded and debounced because Android reports one teardown TWICE —
  /// an `onError` (`error_no_match`/`error_speech_timeout`) and a
  /// not-listening status — and calling `listen()` twice in quick
  /// succession restarts the mic twice, which is itself audible. The
  /// short delay also lets the plugin finish destroying the previous
  /// recognizer (`SpeechToTextPlugin.destroyRecognizer` posts its own
  /// 50ms teardown) before a new one is created on top of it.
  void _reopenSession() {
    if (_reopenTimer?.isActive ?? false) return;
    if (_speech.isListening) return;
    _reopenTimer = Timer(const Duration(milliseconds: 120), () {
      if (state.status != VoiceCaptureStatus.listening) return;
      if (_speech.isListening) return;
      _openSession();
    });
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

    final words = result.recognizedWords;
    // The platform re-delivers the whole session transcript on every
    // callback, and keeps doing so (as a final result) even after the
    // silence timer has already committed those words as a task. Without
    // this guard that text would be re-adopted as live and committed a
    // SECOND time on the next boundary, duplicating the task. Anything
    // already committed is ignored until the user actually says
    // something new.
    if (_committedText.isNotEmpty) {
      if (words.length <= _committedText.length) return;
      if (!words.startsWith(_committedText)) {
        // The platform restarted its transcript from scratch (a
        // reopened session), so what arrives is genuinely new speech.
        _committedText = '';
      }
    }

    _liveText = _committedText.isEmpty
        ? words
        : words.substring(_committedText.length).trimLeft();
    if (_liveText.isEmpty) return;

    // Live, word-by-word — requested directly: the words appear in their
    // own in-progress task card as they are recognized, rather than the
    // whole segment landing at once when it commits.
    state = state.copyWith(partialText: _liveText);

    // Any result — partial or final — is recognition activity, so the
    // silence countdown starts over. A `finalResult` here no longer
    // means "the session ended" (nothing stops it any more, see
    // [_openSession]); it is just the platform settling on its
    // transcription, and the 2s timer alone decides where one task name
    // ends and the next begins.
    _restartSilenceTimer();
  }

  void _commitSegment() {
    final text = _liveText.trim();
    _liveText = '';
    if (text.isEmpty) {
      state = state.copyWith(partialText: '');
      return;
    }
    // Remember what has been consumed so [_onResult] can tell already-
    // committed words apart from genuinely new speech in the platform's
    // running transcript — see its own guard.
    _committedText = _committedText.isEmpty ? text : '$_committedText $text';
    state = state.copyWith(
      committedSegments: [...state.committedSegments, text],
      partialText: '',
    );
  }

  /// The explicit user action — stops the SDK session entirely and shows
  /// the Paused state. Distinct from the automatic silence-gap restart in
  /// [_onResult]: see [VoiceCaptureStatus.paused]'s own doc comment.
  Future<void> pause() async {
    if (state.status != VoiceCaptureStatus.listening) return;
    // Whatever was said since the last committed segment is still real
    // speech the user intends to keep — commit it now rather than
    // discarding it just because they paused mid-sentence.
    _silenceTimer?.cancel();
    _reopenTimer?.cancel();
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

    _silenceTimer?.cancel();
    _reopenTimer?.cancel();
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
