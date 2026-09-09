/// Shared snap constants/formulas for a Timeline drag/resize gesture —
/// extracted so the new tap-empty-space placeholder's own drag/resize
/// logic (`timeline_screen.dart`'s `_DayTimelineState`) doesn't become a
/// third private copy of values already duplicated once between
/// `_DayTimeline`'s zone-drag block and `_DraggableTaskBlockState`'s own
/// `_snapMinutes`/`_durationSnapMinutes`/`_minDurationMinutes`. Those two
/// existing call sites are left as-is (out of scope, minimizes diff) —
/// only the placeholder's new logic uses these.
const dragSnapMinutes = 5;
const resizeSnapMinutes = 5;
const minTaskDurationMinutes = resizeSnapMinutes;

/// A raw move-drag pixel offset, snapped to [dragSnapMinutes].
int snappedMinutesDelta(double offsetPixels, double pixelsPerMinute) =>
    (offsetPixels / pixelsPerMinute / dragSnapMinutes).round() *
    dragSnapMinutes;

/// A raw resize-drag pixel offset, snapped to [resizeSnapMinutes].
int snappedDurationDelta(double offsetPixels, double pixelsPerMinute) =>
    (offsetPixels / pixelsPerMinute / resizeSnapMinutes).round() *
    resizeSnapMinutes;
