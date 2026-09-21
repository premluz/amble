import 'package:flutter/foundation.dart' show immutable;
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../shared/services/quick_capture_parser.dart';

enum VoiceCaptureStatus {
  /// Not yet started, or permission/availability failed — the waveform
  /// sits at its flat baseline and no session is open.
  idle,

  /// A [stt.SpeechToText] session is open and receiving results.
  listening,

  /// The user tapped Pause — the session is stopped (not just muted), and
  /// [VoiceCaptureState.committedSegments] captured so far are preserved.
  /// Distinct from the automatic silence-gap restart in
  /// `VoiceCapture._onResult`, which never changes [VoiceCaptureState
  /// .status] at all — confirmed directly: a silence gap is invisible to
  /// the user and just commits a segment before listening resumes on its
  /// own, while tapping Pause is a deliberate stop the UI must show.
  paused,

  /// `VoiceCapture.submit` is in flight — gates the Submit button against
  /// a second tap, same reasoning as
  /// `_QuickCaptureFormState._isSubmitting` (`quick_capture_sheet.dart`).
  submitting,
}

/// How long a silence must last before the current segment is committed
/// and the next one starts. **2 seconds**, requested directly.
///
/// This is a TASK boundary only — it never stops the recording session.
/// `VoiceCapture` runs its own timer on this duration rather than handing
/// it to `speech_to_text`'s `pauseFor`, which would `_stop()` the session
/// outright (see `VoiceCapture._openSession`). Listening continues across
/// the gap, and the next words the user speaks open a new task card.
const voiceCaptureSilenceGap = Duration(seconds: 2);

/// The silence window handed to the PLATFORM recognizer, deliberately far
/// longer than [voiceCaptureSilenceGap] — these are two different jobs
/// and conflating them is what made recording audibly drop and restart on
/// every pause.
///
/// It cannot simply be omitted. On Android the plugin only sets
/// `EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS` when a `pauseFor`
/// is supplied, so leaving it null lets the OS recognizer apply its own
/// ~1s default, call `onEndOfSpeech`, and then (`SpeechToTextPlugin
/// .onEndOfSpeech`, `previousPauseFor ?: 1000`) tear the session down a
/// second later — the drop-then-restart the user reported hearing.
///
/// So it is set HIGH instead: long enough that an ordinary gap between
/// two spoken tasks never reaches it, leaving [voiceCaptureSilenceGap]'s
/// own timer as the only thing that decides where one task name ends.
/// A genuinely long silence still ends the platform session, which
/// `VoiceCapture._onStatus` then reopens — by then the user has been
/// quiet long enough that a restart is inaudible under the next thing
/// they say.
const voiceCapturePlatformPauseFor = Duration(seconds: 30);

@immutable
class VoiceCaptureState {
  const VoiceCaptureState({
    this.status = VoiceCaptureStatus.idle,
    this.soundLevel = 0.0,
    this.partialText = '',
    this.committedSegments = const [],
  });

  final VoiceCaptureStatus status;

  /// Current input amplitude, handed straight to `AppVoiceWaveform.level`
  /// — see that widget's own doc comment on why it stays a plain
  /// `double` rather than a `speech_to_text` type.
  final double soundLevel;

  /// Live, uncommitted words since the last committed segment (or since
  /// listening started) — updates word-by-word as speech is recognized,
  /// shown directly in `VoiceCaptureStatusCard`'s subtitle so the user
  /// sees text appear as they speak, not only once the 2s pause commits
  /// the segment.
  final String partialText;

  /// Finalized segment texts, oldest first — each becomes one task pill,
  /// and each is what `VoiceCapture.submit` runs through
  /// [parseQuickCapture].
  final List<String> committedSegments;

  bool get canSubmit => committedSegments.isNotEmpty;

  VoiceCaptureState copyWith({
    VoiceCaptureStatus? status,
    double? soundLevel,
    String? partialText,
    List<String>? committedSegments,
  }) {
    return VoiceCaptureState(
      status: status ?? this.status,
      soundLevel: soundLevel ?? this.soundLevel,
      partialText: partialText ?? this.partialText,
      committedSegments: committedSegments ?? this.committedSegments,
    );
  }
}
