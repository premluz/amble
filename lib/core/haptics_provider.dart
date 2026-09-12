import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'haptics.dart';

part 'haptics_provider.g.dart';

/// The app's [Haptics] implementation.
///
/// A provider rather than a plain `const PlatformHaptics()` at each call
/// site so a widget test can override it with a recording fake — the only
/// way to assert haptic behavior at all, since `flutter test` has no
/// vibration motor and `HapticFeedback`'s platform channel is a no-op
/// there (see docs/DECISIONS.md's own note that device haptics can't be
/// verified off real hardware).
///
/// `keepAlive: true`, matching every other app-level singleton in this
/// codebase: it holds no per-screen state and re-creating it per listener
/// would be pure churn.
@Riverpod(keepAlive: true)
Haptics haptics(Ref ref) => const PlatformHaptics();
