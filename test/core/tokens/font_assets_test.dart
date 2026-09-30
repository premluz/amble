import 'dart:io';

import 'package:amble/core/tokens/type_primitives.dart';
import 'package:flutter_test/flutter_test.dart';

/// The numeric font the tokens name is the one pubspec bundles, and every
/// font file pubspec declares is really there — a missing file would fall
/// back silently on a device, not fail.
void main() {
  final pubspec = File('pubspec.yaml').readAsStringSync();

  test('the numeric font is IBM Plex Sans Condensed, and pubspec bundles '
      'that family', () {
    expect(TypePrimitives.fontFamily, 'IBM Plex Sans Condensed');
    expect(pubspec, contains('- family: ${TypePrimitives.fontFamily}'));
    expect(pubspec, contains('- family: ${TypePrimitives.fontFamilySans}'));
  });

  test('every font asset pubspec declares exists', () {
    final assets = RegExp(r'- asset: (assets/fonts/\S+)')
        .allMatches(pubspec)
        .map((m) => m.group(1)!)
        .toList();
    expect(assets, isNotEmpty);
    for (final asset in assets) {
      expect(File(asset).existsSync(), isTrue, reason: '$asset is missing');
    }
  });
}
