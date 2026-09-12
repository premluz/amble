import 'package:amble/core/haptics.dart';

/// A [Haptics] that records instead of vibrating.
///
/// The only way to assert haptic behaviour at all: `flutter test` has no
/// vibration motor and `HapticFeedback`'s platform channel is an inert
/// no-op there, so a test that called through to the real implementation
/// would pass identically whether or not the production code ever fired
/// anything.
class RecordingHaptics implements Haptics {
  final List<AmbleHaptic> played = [];

  @override
  void play(AmbleHaptic haptic) => played.add(haptic);
}
