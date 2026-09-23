import 'package:flutter/widgets.dart' show Key;

/// One option in [AppTabSwitch]/[AppConnectedButtons] — the shared
/// mutually-exclusive-selection primitive both widgets render differently.
/// Generic over [T] so callers pass a real enum/value (e.g. `ZoneGridTab`)
/// rather than reconstructing one from a plain index, matching how
/// [AppButton] takes real callbacks rather than positional indices.
class AppOptionSwitchOption<T> {
  const AppOptionSwitchOption({
    required this.value,
    required this.label,
    this.segmentKey,
    this.isDropTarget = false,
  });

  final T value;
  final String label;

  /// Attached to this option's own rendered segment inside
  /// [AppTabSwitch] — added for a caller that needs to hit-test a live
  /// drag against a specific segment's real on-screen bounds (the
  /// Inbox's own Section tab row, `inbox_section_tabs.dart`), the same
  /// `GlobalKey`-on-a-drop-target pattern `EditModeDeleteTarget` already
  /// establishes for a single fixed target. Null (the default) for every
  /// caller that doesn't need this — [AppConnectedButtons] ignores it
  /// entirely, it is only read by [AppTabSwitch].
  final Key? segmentKey;

  /// Whether a live drag is currently hovering this segment — paints the
  /// same "you're about to drop here" 2px border `ZoneContainerBlock
  /// .isDropTarget` already uses (added over the resting fill, not a
  /// fill-color change), sized for a small tab rather than a large zone
  /// card. Defaults false for every caller that has no drag concept.
  final bool isDropTarget;
}
