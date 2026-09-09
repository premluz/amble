import 'dart:ui';

/// Tier 1 — raw type scale, no semantic meaning.
abstract final class TypePrimitives {
  /// The single source of truth for the app's font — every `TextStyle`
  /// built in `semantic_theme.dart` reads this rather than hardcoding a
  /// family name, and `main.dart`'s own `ThemeData.fontFamily` reads it
  /// too, so any default Material text NOT built from one of our own
  /// tokens (an AlertDialog action, a SnackBar) still matches. Change the
  /// font app-wide by editing this one constant.
  static const fontFamily = 'JetBrains Mono';

  static const size1 = 12.0;
  static const size2 = 14.0;
  static const size3 = 16.0;
  static const size4 = 20.0;
  static const size5 = 24.0;
  static const size6 = 32.0;
  static const size7 = 40.0;

  static const weightRegular = FontWeight.w400;
  static const weightMedium = FontWeight.w500;
  static const weightSemibold = FontWeight.w600;
  static const weightBold = FontWeight.w700;

  static const lineHeightTight = 1.1;
  static const lineHeightNormal = 1.3;
  static const lineHeightRelaxed = 1.5;
}
