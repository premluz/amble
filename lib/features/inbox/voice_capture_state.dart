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
/// and a new one starts. **2 seconds**, requested directly — shorter than
/// Quick Capture's own 5s `pauseFor` (`quick_capture_sheet.dart`), which
/// is tuned for "let one task title breathe mid-sentence." This flow's
/// pause IS the delimiter between tasks, so it has to fire quickly enough
/// that a natural breath between two spoken tasks reads as two pills, not
/// one run-on title — but not so quickly that an ordinary mid-sentence
/// breath splits one task into two.
const voiceCaptureSilenceGap = Duration(seconds: 2);

@immutable
class VoiceCaptureState {
  const VoiceCaptureState({
    this.status = VoiceCaptureStatus.idle,
    this.soundLevel = 0.0,
    this.committedSegments = const [],
  });

  final VoiceCaptureStatus status;

  /// Current input amplitude, handed straight to `AppVoiceWaveform.level`
  /// — see that widget's own doc comment on why it stays a plain
  /// `double` rather than a `speech_to_text` type.
  final double soundLevel;

  /// Finalized segment texts, oldest first — each becomes one task pill,
  /// and each is what `VoiceCapture.submit` runs through
  /// [parseQuickCapture].
  final List<String> committedSegments;

  bool get canSubmit => committedSegments.isNotEmpty;

  VoiceCaptureState copyWith({
    VoiceCaptureStatus? status,
    double? soundLevel,
    List<String>? committedSegments,
  }) {
    return VoiceCaptureState(
      status: status ?? this.status,
      soundLevel: soundLevel ?? this.soundLevel,
      committedSegments: committedSegments ?? this.committedSegments,
    );
  }
}
