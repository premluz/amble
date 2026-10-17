import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/preferences_repository.dart';
import 'preferences_providers.dart';

/// How the desktop week draws a task: the app's own [pills] (a round badge
/// with the title beside it) or standard calendar [blocks] (a tinted block
/// the height of the task, with a colour rail).
enum WeekTaskStyle { pills, blocks }

/// Settings → Appearance → "Week task style", wide layout only. Defaults to
/// [WeekTaskStyle.pills], the look the week has always had. Stored by name,
/// so reordering the enum can never change a saved choice.
class WeekTaskStyleSetting extends Notifier<WeekTaskStyle> {
  @override
  WeekTaskStyle build() {
    final stored = ref
        .read(preferencesRepositoryProvider)
        .getValue<String>(PreferenceKeys.weekTaskStyle);
    return WeekTaskStyle.values.where((v) => v.name == stored).firstOrNull ??
        WeekTaskStyle.pills;
  }

  Future<void> set(WeekTaskStyle value) async {
    await ref
        .read(preferencesRepositoryProvider)
        .setValue(PreferenceKeys.weekTaskStyle, value.name);
    state = value;
  }
}

final weekTaskStyleSettingProvider =
    NotifierProvider<WeekTaskStyleSetting, WeekTaskStyle>(
      WeekTaskStyleSetting.new,
    );
