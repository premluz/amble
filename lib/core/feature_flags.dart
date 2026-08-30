/// Compile-time feature flags.
///
/// Deliberately a plain const class, not a remote-config system — for MVP
/// the only requirement is that a gate exists and is trivially findable
/// (grep the flag name to find every entry point it guards).
///
/// A flag here gates **UI entry points only**. The underlying data model
/// and repository layer are never "turned off," only left dormant — see
/// CONSTITUTION.md ("Additive and inert when unused").
abstract final class FeatureFlags {
  /// Gates every TrackedBehavior UI surface: creating a tracked behavior,
  /// linking a task to one, and recording an outcome on completion.
  ///
  /// **Still default off**, per SCOPE.md — an ordinary build (including any
  /// release build) behaves exactly as it did before the TrackedBehavior UI
  /// existed. A build-time override makes it reachable for testing without
  /// editing this file, so the shipped default can't drift on by accident:
  ///
  /// ```
  /// flutter run --dart-define=trackedBehavior=true
  /// ```
  ///
  /// `bool.fromEnvironment` defaults to `false` when the define is absent,
  /// and is const-evaluated, so gated UI still dead-code-eliminates in
  /// builds that don't opt in.
  static const bool trackedBehaviorEnabled = bool.fromEnvironment(
    'trackedBehavior',
  );
}
