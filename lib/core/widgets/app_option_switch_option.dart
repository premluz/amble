/// One option in [AppTabSwitch]/[AppConnectedButtons] — the shared
/// mutually-exclusive-selection primitive both widgets render differently.
/// Generic over [T] so callers pass a real enum/value (e.g. `ZoneGridTab`)
/// rather than reconstructing one from a plain index, matching how
/// [AppButton] takes real callbacks rather than positional indices.
class AppOptionSwitchOption<T> {
  const AppOptionSwitchOption({required this.value, required this.label});

  final T value;
  final String label;
}
