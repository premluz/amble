import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/component_tokens.dart';
import '../repositories/preferences_repository.dart';
import 'preferences_providers.dart';

/// How tall one hour is in the desktop week, changed by zooming (pinch,
/// Cmd/Ctrl+scroll, or the toolbar's − / +). Persisted; always within
/// [min]..[max], whatever was stored.
class WeekHourHeightSetting extends Notifier<double> {
  static const double min =
      CalendarGridTokens.weekHourHeight * CalendarGridTokens.weekZoomMin;
  static const double max =
      CalendarGridTokens.weekHourHeight * CalendarGridTokens.weekZoomMax;

  @override
  double build() {
    final stored = ref
        .read(preferencesRepositoryProvider)
        .getValue<double>(PreferenceKeys.weekHourHeight);
    return (stored ?? CalendarGridTokens.weekHourHeight).clamp(min, max);
  }

  Future<void> set(double value) async {
    final clamped = value.clamp(min, max);
    if (clamped == state) return;
    state = clamped;
    await ref
        .read(preferencesRepositoryProvider)
        .setValue(PreferenceKeys.weekHourHeight, clamped);
  }

  Future<void> zoomBy(double factor) => set(state * factor);
}

final weekHourHeightSettingProvider =
    NotifierProvider<WeekHourHeightSetting, double>(WeekHourHeightSetting.new);
