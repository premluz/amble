import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show FontLoader;

/// Loads the app's real bundled JetBrains Mono into the test environment.
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
  final loader = FontLoader('JetBrains Mono');
  for (final weight in const ['Regular', 'Medium', 'Bold']) {
    final bytes = File('assets/fonts/JetBrainsMono-$weight.ttf')
        .readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}
