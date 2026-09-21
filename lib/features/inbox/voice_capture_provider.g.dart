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
///
/// Two flows now touch the SDK directly rather than one shared instance,
/// confirmed directly rather than assumed: they need genuinely different
/// listen configurations (this one needs `partialResults` and
/// `onSoundLevelChange` for the live waveform; Quick Capture deliberately
/// only surfaces final results, see its own doc comment on why partial
/// text would fight its live token highlighting) and have different
/// session lifetimes (one continuous multi-segment session here vs. one
/// single-shot dictation there). Sharing an instance would couple two
/// screens that should be able to change independently.
///
/// `autoDispose` (the codegen default) — this is screen-local session
/// state, matching [EditModeEnabled]'s own precedent
/// (`edit_mode_provider.dart`): it should not survive past the screen
/// that owns it, and a returning user should never silently resume an
/// old recording session.
///
/// State shape ([VoiceCaptureState]/[VoiceCaptureStatus]) lives in
/// `voice_capture_state.dart`, re-exported here so callers only ever
/// import this one file — split out purely to keep each file under
/// CLAUDE.md's 200-line guidance, not because the state is meant to be
/// used independently of this notifier.

@ProviderFor(VoiceCapture)
final voiceCaptureProvider = VoiceCaptureProvider._();

/// Owns one voice-capture session — the full-screen "speak your tasks"
/// flow's own [stt.SpeechToText] instance, separate from Quick Capture's
/// (`quick_capture_sheet.dart`'s `_QuickCaptureFormState._speech`).
///
/// Two flows now touch the SDK directly rather than one shared instance,
/// confirmed directly rather than assumed: they need genuinely different
/// listen configurations (this one needs `partialResults` and
/// `onSoundLevelChange` for the live waveform; Quick Capture deliberately
/// only surfaces final results, see its own doc comment on why partial
/// text would fight its live token highlighting) and have different
/// session lifetimes (one continuous multi-segment session here vs. one
/// single-shot dictation there). Sharing an instance would couple two
/// screens that should be able to change independently.
///
/// `autoDispose` (the codegen default) — this is screen-local session
/// state, matching [EditModeEnabled]'s own precedent
/// (`edit_mode_provider.dart`): it should not survive past the screen
/// that owns it, and a returning user should never silently resume an
/// old recording session.
///
/// State shape ([VoiceCaptureState]/[VoiceCaptureStatus]) lives in
/// `voice_capture_state.dart`, re-exported here so callers only ever
/// import this one file — split out purely to keep each file under
/// CLAUDE.md's 200-line guidance, not because the state is meant to be
/// used independently of this notifier.
final class VoiceCaptureProvider
    extends $NotifierProvider<VoiceCapture, VoiceCaptureState> {
  /// Owns one voice-capture session — the full-screen "speak your tasks"
  /// flow's own [stt.SpeechToText] instance, separate from Quick Capture's
  /// (`quick_capture_sheet.dart`'s `_QuickCaptureFormState._speech`).
  ///
  /// Two flows now touch the SDK directly rather than one shared instance,
  /// confirmed directly rather than assumed: they need genuinely different
  /// listen configurations (this one needs `partialResults` and
  /// `onSoundLevelChange` for the live waveform; Quick Capture deliberately
  /// only surfaces final results, see its own doc comment on why partial
  /// text would fight its live token highlighting) and have different
  /// session lifetimes (one continuous multi-segment session here vs. one
  /// single-shot dictation there). Sharing an instance would couple two
  /// screens that should be able to change independently.
  ///
  /// `autoDispose` (the codegen default) — this is screen-local session
  /// state, matching [EditModeEnabled]'s own precedent
  /// (`edit_mode_provider.dart`): it should not survive past the screen
  /// that owns it, and a returning user should never silently resume an
  /// old recording session.
  ///
  /// State shape ([VoiceCaptureState]/[VoiceCaptureStatus]) lives in
  /// `voice_capture_state.dart`, re-exported here so callers only ever
  /// import this one file — split out purely to keep each file under
  /// CLAUDE.md's 200-line guidance, not because the state is meant to be
  /// used independently of this notifier.
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

String _$voiceCaptureHash() => r'85d7f4a12be603efe4ce74f80ed543662b67f9c7';

/// Owns one voice-capture session — the full-screen "speak your tasks"
/// flow's own [stt.SpeechToText] instance, separate from Quick Capture's
/// (`quick_capture_sheet.dart`'s `_QuickCaptureFormState._speech`).
///
/// Two flows now touch the SDK directly rather than one shared instance,
/// confirmed directly rather than assumed: they need genuinely different
/// listen configurations (this one needs `partialResults` and
/// `onSoundLevelChange` for the live waveform; Quick Capture deliberately
/// only surfaces final results, see its own doc comment on why partial
/// text would fight its live token highlighting) and have different
/// session lifetimes (one continuous multi-segment session here vs. one
/// single-shot dictation there). Sharing an instance would couple two
/// screens that should be able to change independently.
///
/// `autoDispose` (the codegen default) — this is screen-local session
/// state, matching [EditModeEnabled]'s own precedent
/// (`edit_mode_provider.dart`): it should not survive past the screen
/// that owns it, and a returning user should never silently resume an
/// old recording session.
///
/// State shape ([VoiceCaptureState]/[VoiceCaptureStatus]) lives in
/// `voice_capture_state.dart`, re-exported here so callers only ever
/// import this one file — split out purely to keep each file under
/// CLAUDE.md's 200-line guidance, not because the state is meant to be
/// used independently of this notifier.

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
