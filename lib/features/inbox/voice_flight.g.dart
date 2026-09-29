// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'voice_flight.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The page under voice mode sweeps away from the bottom as the screen
/// covers it, and returns as it uncovers ([AppSweepFade]). Null while voice
/// mode is not open.

@ProviderFor(VoiceModeSweep)
final voiceModeSweepProvider = VoiceModeSweepProvider._();

/// The page under voice mode sweeps away from the bottom as the screen
/// covers it, and returns as it uncovers ([AppSweepFade]). Null while voice
/// mode is not open.
final class VoiceModeSweepProvider
    extends $NotifierProvider<VoiceModeSweep, Animation<double>?> {
  /// The page under voice mode sweeps away from the bottom as the screen
  /// covers it, and returns as it uncovers ([AppSweepFade]). Null while voice
  /// mode is not open.
  VoiceModeSweepProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'voiceModeSweepProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$voiceModeSweepHash();

  @$internal
  @override
  VoiceModeSweep create() => VoiceModeSweep();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Animation<double>? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Animation<double>?>(value),
    );
  }
}

String _$voiceModeSweepHash() => r'a1b505e470cdc153eb859663dac139346d22b9c3';

/// The page under voice mode sweeps away from the bottom as the screen
/// covers it, and returns as it uncovers ([AppSweepFade]). Null while voice
/// mode is not open.

abstract class _$VoiceModeSweep extends $Notifier<Animation<double>?> {
  Animation<double>? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<Animation<double>?, Animation<double>?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Animation<double>?, Animation<double>?>,
              Animation<double>?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Inbox task ids arriving by flight from voice mode. Their rows open their
/// space as usual; their entrance happens in flight instead (the card flies
/// in while its pill emerges, see [voiceFlightShuttle]).

@ProviderFor(VoiceArrivals)
final voiceArrivalsProvider = VoiceArrivalsProvider._();

/// Inbox task ids arriving by flight from voice mode. Their rows open their
/// space as usual; their entrance happens in flight instead (the card flies
/// in while its pill emerges, see [voiceFlightShuttle]).
final class VoiceArrivalsProvider
    extends $NotifierProvider<VoiceArrivals, Set<String>> {
  /// Inbox task ids arriving by flight from voice mode. Their rows open their
  /// space as usual; their entrance happens in flight instead (the card flies
  /// in while its pill emerges, see [voiceFlightShuttle]).
  VoiceArrivalsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'voiceArrivalsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$voiceArrivalsHash();

  @$internal
  @override
  VoiceArrivals create() => VoiceArrivals();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Set<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Set<String>>(value),
    );
  }
}

String _$voiceArrivalsHash() => r'd79df795a1b2df1a232ae9d842139589fceb7ac7';

/// Inbox task ids arriving by flight from voice mode. Their rows open their
/// space as usual; their entrance happens in flight instead (the card flies
/// in while its pill emerges, see [voiceFlightShuttle]).

abstract class _$VoiceArrivals extends $Notifier<Set<String>> {
  Set<String> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<Set<String>, Set<String>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Set<String>, Set<String>>,
              Set<String>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
