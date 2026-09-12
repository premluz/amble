import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The app's haptic vocabulary — a small, named set of *intentions*
/// ("something was selected", "a drag was picked up") rather than raw
/// platform impact strengths, so call sites never encode a physical
/// intensity directly and the whole feel can be retuned in one place.
///
/// Mirrors CONSTITUTION.md design principle 4's reasoning for the
/// adaptive widget layer, applied to touch instead of pixels: features
/// must never reach for `HapticFeedback` themselves, exactly as they must
/// never reach for `Cupertino*`/`Material*`. That keeps iOS/Android feel
/// consistent by construction rather than by after-the-fact inspection.
enum AmbleHaptic {
  /// A discrete value changed — a chip picked, a switch flipped, a drag
  /// crossing a snap increment. The lightest thing available, because it
  /// can fire repeatedly during a single gesture.
  selection,

  /// An ordinary tap on a control landed. Currently mapped to the same
  /// platform call as [selection] — kept as a separate intention anyway so
  /// the two can diverge later without touching a single call site.
  tap,

  /// A gesture picked something up (drag lift, resize grab), or a mode
  /// was entered. Heavier than a tap: the user is now holding something.
  lift,

  /// A gesture put something down and it committed (drop, resize
  /// release).
  drop,

  /// A destructive target became armed — dragging over "delete". The
  /// heaviest weight in the set, since it is the one haptic that warns
  /// rather than confirms.
  warning,

  /// A task was completed. Distinct from [drop] so finishing something
  /// feels different from merely moving it.
  success,
}

/// Plays [AmbleHaptic]s. An interface, not a static utility, so tests can
/// substitute a recording fake and assert *that* a haptic fired without
/// depending on platform channels — `flutter test` has no vibration
/// motor, and `HapticFeedback` is a no-op there.
abstract class Haptics {
  const Haptics();

  void play(AmbleHaptic haptic);
}

/// The real implementation, backed by `package:flutter/services.dart`'s
/// own [HapticFeedback]. No third-party dependency: the built-in set
/// covers every intention above, and adding one would be a
/// flag-as-decision per CLAUDE.md.
class PlatformHaptics implements Haptics {
  const PlatformHaptics();

  @override
  void play(AmbleHaptic haptic) {
    // Fire-and-forget: every HapticFeedback call returns a Future that
    // completes once the platform channel round-trips, but a haptic that
    // is awaited would delay the very interaction it is meant to
    // accompany. Errors are swallowed for the same reason they are on a
    // device with no motor — a missing haptic must never break a tap.
    switch (haptic) {
      case AmbleHaptic.selection:
      case AmbleHaptic.tap:
        _ignore(HapticFeedback.selectionClick());
      case AmbleHaptic.lift:
        _ignore(HapticFeedback.lightImpact());
      case AmbleHaptic.drop:
        _ignore(HapticFeedback.mediumImpact());
      case AmbleHaptic.warning:
        _ignore(HapticFeedback.heavyImpact());
      case AmbleHaptic.success:
        _ignore(HapticFeedback.mediumImpact());
    }
  }

  void _ignore(Future<void> future) {
    future.catchError((Object error, StackTrace stack) {
      // A platform with no haptic engine (a simulator, a tablet, a device
      // with vibration disabled in system settings) throws rather than
      // silently no-oping. Swallowing is correct here and nowhere else:
      // the feature is decorative by definition.
      if (kDebugMode) {
        debugPrint('Haptic unavailable: $error');
      }
    });
  }
}

/// A [Haptics] that does nothing — for tests, and for any future
/// "reduce motion / reduce haptics" accessibility setting, which would
/// swap this in rather than adding a null-check at every call site.
class SilentHaptics implements Haptics {
  const SilentHaptics();

  @override
  void play(AmbleHaptic haptic) {}
}
