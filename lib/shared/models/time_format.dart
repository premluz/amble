/// How times read across the app: following the device, or always 12-hour
/// ("9:00 PM") or 24-hour ("21:00"). A preference in Settings → Appearance.
///
/// Stored by [name] (a plain string), not as its own Hive type: nothing
/// about it needs an adapter, and a name survives reordering this enum.
enum TimeFormatPreference {
  /// Whatever the device is set to — the default on a fresh install.
  system,
  twelveHour,
  twentyFourHour;

  /// The `MediaQuery.alwaysUse24HourFormat` to impose, or null to leave the
  /// device's own setting in place.
  bool? get use24Hour => switch (this) {
    TimeFormatPreference.system => null,
    TimeFormatPreference.twelveHour => false,
    TimeFormatPreference.twentyFourHour => true,
  };

  /// The stored value back to a preference; anything unknown (or absent)
  /// is [system].
  static TimeFormatPreference fromName(String? name) =>
      values.where((value) => value.name == name).firstOrNull ?? system;
}
