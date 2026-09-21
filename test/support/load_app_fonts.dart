import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show FontLoader;

/// Loads the app's real bundled fonts (JetBrains Mono + DM Sans) into the
/// test environment.
///
/// `flutter test` otherwise renders every `Text` in a fallback font whose
/// metrics differ wildly from the real one — docs/ERROR_LOG.md already
/// records a pixel assertion that passed against reverted code for exactly
/// this reason. Any test measuring rendered text WIDTH must call this, or
/// it is measuring a font the app never ships.
///
/// Concretely: "11:00 AM" at `textCaption` measures 96.0 in the fallback
/// font and 57.6 in JetBrains Mono. Tuning a column against the former
/// would size it for a font no user ever sees.
Future<void> loadAppFonts() async {
  final monoLoader = FontLoader('JetBrains Mono');
  for (final weight in const ['Regular', 'Medium', 'Bold']) {
    final bytes = File('assets/fonts/JetBrainsMono-$weight.ttf')
        .readAsBytesSync();
    monoLoader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await monoLoader.load();

  // DM Sans ships as one variable font file (see pubspec.yaml's own `DM
  // Sans` block for why) — a single addFont covers every weight, unlike
  // JetBrains Mono's per-weight static files above.
  final sansLoader = FontLoader('DM Sans');
  final sansBytes = File('assets/fonts/DMSans-Variable.ttf').readAsBytesSync();
  sansLoader.addFont(Future.value(ByteData.sublistView(sansBytes)));
  await sansLoader.load();
}
