import 'package:device_calendar/device_calendar.dart';

/// Requests device calendar (READ + WRITE) permission lazily, shared by
/// both Calendar features (external event display, sync-out) — see
/// CONSTITUTION.md's "Calendar" section. Matches [NotificationService]'s
/// own precedent: no permission prompt at app launch, request only the
/// first time a feature actually needs it, and degrade silently (never
/// crash, never block) on denial.
///
/// `device_calendar`'s own [DeviceCalendarPlugin.requestPermissions] is
/// itself idempotent (re-asking after a grant is a no-op returning true
/// immediately), so this service adds no extra "already asked" bookkeeping
/// beyond what the plugin already gives for free.
class CalendarPermissionService {
  CalendarPermissionService(this._plugin);

  final DeviceCalendarPlugin _plugin;

  /// True if calendar permission is already granted, without prompting.
  Future<bool> hasPermission() async {
    final result = await _plugin.hasPermissions();
    return result.isSuccess && result.data == true;
  }

  /// Requests permission if not already granted. Returns true if the
  /// caller may proceed (already granted, or just granted); false on
  /// denial or any platform error — callers must treat false as "this
  /// feature simply doesn't activate," never as an exception to surface.
  Future<bool> requestPermission() async {
    if (await hasPermission()) return true;
    final result = await _plugin.requestPermissions();
    return result.isSuccess && result.data == true;
  }
}
