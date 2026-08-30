import 'package:hive_ce/hive_ce.dart';

part 'app_theme_mode.g.dart';

/// Which theme the app should use.
///
/// Mirrors Flutter's own `ThemeMode` rather than reusing it directly: this
/// is a *persisted* value, and persisting a framework enum would tie the
/// stored schema to Flutter's declaration order. Its own Hive type keeps
/// the storage format ours, and the mapping to `ThemeMode` lives in one
/// place (see `preferences_providers.dart`).
@HiveType(typeId: 7)
enum AppThemeMode {
  @HiveField(0)
  system,
  @HiveField(1)
  light,
  @HiveField(2)
  dark,
}
