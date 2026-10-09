import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/preferences_repository.dart';
import 'preferences_providers.dart';

/// Whether the week and month grids draw their faint day and hour lines
/// (Settings → Appearance). Defaults to on.
class CalendarGridLinesSetting extends Notifier<bool> {
  @override
  bool build() =>
      ref
          .read(preferencesRepositoryProvider)
          .getValue<bool>(PreferenceKeys.calendarGridLines) ??
      true;

  Future<void> set(bool value) async {
    await ref
        .read(preferencesRepositoryProvider)
        .setValue(PreferenceKeys.calendarGridLines, value);
    state = value;
  }
}

final calendarGridLinesSettingProvider =
    NotifierProvider<CalendarGridLinesSetting, bool>(
      CalendarGridLinesSetting.new,
    );
