// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'voice_capture_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
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

@ProviderFor(VoiceCapture)
final voiceCaptureProvider = VoiceCaptureProvider._();

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
final class VoiceCaptureProvider
    extends $NotifierProvider<VoiceCapture, VoiceCaptureState> {
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
  VoiceCaptureProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'voiceCaptureProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$voiceCaptureHash();

  @$internal
  @override
  VoiceCapture create() => VoiceCapture();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VoiceCaptureState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VoiceCaptureState>(value),
    );
  }
}

String _$voiceCaptureHash() => r'91d585431590c3aee16edc8142b845d3add053e0';

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

abstract class _$VoiceCapture extends $Notifier<VoiceCaptureState> {
  VoiceCaptureState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<VoiceCaptureState, VoiceCaptureState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<VoiceCaptureState, VoiceCaptureState>,
              VoiceCaptureState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
