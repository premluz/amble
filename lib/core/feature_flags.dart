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
  /// **Default ON as of 2026-09-06, confirmed directly** — reverses the
  /// earlier default-off decision (see docs/DECISIONS.md's Phase 12 entry
  /// and the 2026-09-06 "confirmed as OFF" entry that preceded this one):
  /// an ordinary build, including release, now ships with the Tracked tab
  /// live, same shape `zoneEnabled` already uses below. Still overridable
  /// off for testing:
  ///
  /// ```
  /// flutter run --dart-define=trackedBehavior=false
  /// ```
  ///
  /// A DEBUG-only Settings → Developer toggle (`DevTrackedTabInCycle`, see
  /// `core/dev_config.dart`) can additionally hide the tab again at
  /// runtime without a rebuild — same "ANDs into this flag, never
  /// overrides it on" relationship `DevZoneViewInCycle` has with
  /// `zoneEnabled`. `bool.fromEnvironment` is const-evaluated, so the
  /// gated UI still dead-code-eliminates in a build that opts back off.
  static const bool trackedBehaviorEnabled = bool.fromEnvironment(
    'trackedBehavior',
    defaultValue: true,
  );

  /// Gates every Zone UI surface: Settings' "Zones" section, the zone list,
  /// and add/edit — see CONSTITUTION.md's "Zone" section.
  ///
  /// **Default ON**, confirmed directly — Zone's first UI (list + add/edit)
  /// ships in every build, including release, same as any other finished
  /// feature. Still overridable for testing if ever needed:
  ///
  /// ```
  /// flutter run --dart-define=zone=false
  /// ```
  static const bool zoneEnabled = bool.fromEnvironment(
    'zone',
    defaultValue: true,
  );

  /// Gates the RevenueCat subscription UI surface: Settings' "Subscription"
  /// row and the paywall/Customer Center entry points it reaches. The
  /// underlying `panta_pro` entitlement check itself is not gated — same
  /// "data layer always dormant-active, only the UI entry point is
  /// switched" posture as every other flag here. See docs/SCOPE.md's
  /// subscription entry for why this was confirmed as an explicit scope
  /// addition before building.
  ///
  /// **Default ON**, confirmed directly.
  ///
  /// ```
  /// flutter run --dart-define=subscription=false
  /// ```
  static const bool subscriptionEnabled = bool.fromEnvironment(
    'subscription',
    defaultValue: true,
  );
}
