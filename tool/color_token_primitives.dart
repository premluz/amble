import 'package:amble/core/tokens/color_primitives.dart';
import 'package:flutter/material.dart';

const _categoryNames = <String>[
  'red',
  'orange',
  'amber',
  'yellowGreen',
  'green',
  'teal',
  'cyan',
  'skyBlue',
  'blue',
  'violet',
  'magenta',
  'pinkRose',
  'goldenYellow',
  'lime',
  'ocean',
  'periwinkle',
];

Map<String, Object?> buildPrimitiveColorTokens() => {
  'palette': {
    'sage': colorEntries({
      '50': ColorPrimitives.sage50,
      '100': ColorPrimitives.sage100,
      '300': ColorPrimitives.sage300,
      '500': ColorPrimitives.sage500,
      '700': ColorPrimitives.sage700,
      '900': ColorPrimitives.sage900,
    }),
    'surface': colorEntries({
      '0': ColorPrimitives.surface0,
      '1': ColorPrimitives.surface1,
      '2': ColorPrimitives.surface2,
      '3': ColorPrimitives.surface3,
    }),
    'paper': colorEntries({'default': ColorPrimitives.paper}),
    'cream': colorEntries({
      '0': ColorPrimitives.cream0,
      '1': ColorPrimitives.cream1,
      '2': ColorPrimitives.cream2,
      'overlay': ColorPrimitives.creamOverlay,
    }),
    'sand': colorEntries({
      '50': ColorPrimitives.sand50,
      '100': ColorPrimitives.sand100,
      '200': ColorPrimitives.sand200,
      '300': ColorPrimitives.sand300,
      '350': ColorPrimitives.sand350,
      '400': ColorPrimitives.sand400,
      '500': ColorPrimitives.sand500,
      '700': ColorPrimitives.sand700,
      '900': ColorPrimitives.sand900,
    }),
    'slate': colorEntries({
      '50': ColorPrimitives.slate50,
      '300': ColorPrimitives.slate300,
      '400': ColorPrimitives.slate400,
      '500': ColorPrimitives.slate500,
      '700': ColorPrimitives.slate700,
      '900': ColorPrimitives.slate900,
    }),
    'coral': colorEntries({
      '300': ColorPrimitives.coral300,
      '500': ColorPrimitives.coral500,
      '700': ColorPrimitives.coral700,
    }),
    'crimson': colorEntries({
      '300': ColorPrimitives.crimson300,
      '500': ColorPrimitives.crimson500,
    }),
    'brand': colorEntries({
      '300': ColorPrimitives.brand300,
      '500': ColorPrimitives.brand500,
    }),
    'ink': colorEntries({
      '900': ColorPrimitives.ink900,
      '800': ColorPrimitives.ink800,
      '700': ColorPrimitives.ink700,
      '650': ColorPrimitives.ink650,
      '600': ColorPrimitives.ink600,
      'field': ColorPrimitives.inkField,
      'fieldActive': ColorPrimitives.inkFieldActive,
    }),
  },
  'category': {
    'dark': namedColors(ColorPrimitives.categoryPalette12),
    'light': namedColors(ColorPrimitives.categoryPalette12Light),
    'accentDark': namedColors(ColorPrimitives.categoryAccentsDark),
    'accentLight': namedColors(ColorPrimitives.categoryAccentsLight),
  },
  'special': colorEntries({
    'zoneBackground': ColorPrimitives.zoneBackground,
    'zoneBackgroundDark': ColorPrimitives.zoneBackgroundDark,
    'white': ColorPrimitives.white,
    'black': ColorPrimitives.black,
    'transparent': ColorPrimitives.transparent,
  }),
};

Map<String, Object?> colorEntries(Map<String, Color> colors) => {
  for (final entry in colors.entries)
    entry.key: _colorToken(entry.value, entry.key),
};

Map<String, Object?> namedColors(List<Color> colors) {
  if (colors.length != _categoryNames.length) {
    throw StateError(
      'Expected ${_categoryNames.length} category swatches, found ${colors.length}.',
    );
  }
  return {
    for (var index = 0; index < colors.length; index++)
      _categoryNames[index]: _colorToken(
        colors[index],
        'Category swatch index $index.',
      ),
  };
}

Map<String, Object?> indexedColors(Iterable<Color> colors) {
  final values = colors.toList();
  return {
    for (var index = 0; index < values.length; index++)
      'layer${index + 1}': _colorToken(
        values[index],
        'Shadow layer ${index + 1}.',
      ),
  };
}

Map<String, Object?> _colorToken(Color color, String description) {
  final argb = color.toARGB32();
  final hex = argb.toRadixString(16).padLeft(8, '0').toUpperCase();
  final value = argb >> 24 == 0xFF ? '#${hex.substring(2)}' : '#$hex';
  return {'value': value, 'type': 'color', 'description': description};
}
