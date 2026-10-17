import 'package:flutter/services.dart';

/// Opens the operating system's own settings for this app, through the
/// small native handler each runner registers on [channelName] (iOS and
/// Android: Amble's page in Settings; macOS: Privacy > Calendars). A plain
/// class over a [MethodChannel], like the other services, so tests can
/// override it without a platform.
class SystemSettingsService {
  const SystemSettingsService();

  static const channelName = 'com.amble/system_settings';
  static const _channel = MethodChannel(channelName);

  /// Opens the page where the user can allow Amble to read calendars.
  /// Returns false when this platform has no such page or the call failed,
  /// so the caller can fall back to telling the user where to go.
  Future<bool> openCalendarSettings() async {
    try {
      return await _channel.invokeMethod<bool>('openCalendarSettings') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
