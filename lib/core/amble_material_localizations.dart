import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The app's own Material localizations: Flutter's English defaults, with
/// the day-period in lower case — "9:00 pm", not "9:00 PM" — everywhere a
/// time is formatted through `TimeOfDay.format` (requested directly: "make
/// pm lower case everywhere"). Registered first in `MaterialApp`, so it
/// wins over the default it extends.
class AmbleMaterialLocalizations extends DefaultMaterialLocalizations {
  const AmbleMaterialLocalizations();

  @override
  String get anteMeridiemAbbreviation => 'am';

  @override
  String get postMeridiemAbbreviation => 'pm';

  static const LocalizationsDelegate<MaterialLocalizations> delegate =
      _AmbleMaterialLocalizationsDelegate();
}

class _AmbleMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const _AmbleMaterialLocalizationsDelegate();

  // English, like the default it extends — the app ships English only.
  @override
  bool isSupported(Locale locale) => locale.languageCode == 'en';

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      SynchronousFuture(const AmbleMaterialLocalizations());

  @override
  bool shouldReload(_AmbleMaterialLocalizationsDelegate old) => false;
}
