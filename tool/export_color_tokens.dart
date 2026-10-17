// Run with `flutter test tool/export_color_tokens.dart` to regenerate the
// Tokens Studio token set. Add `--dart-define=COLOR_TOKEN_CHECK=true` to
// verify that the checked-in export matches the current Dart tokens.
import 'dart:convert';
import 'dart:io';

import 'package:amble/core/tokens/delete_puff_spec.dart';
import 'package:amble/core/tokens/floating_surface_tokens.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/tokens/task_state_tokens.dart';
import 'package:flutter_test/flutter_test.dart';

import 'color_token_primitives.dart';

const _defaultOutput = 'design_tokens/rios-color-tokens.json';
const _outputPath = String.fromEnvironment(
  'COLOR_TOKEN_OUTPUT',
  defaultValue: _defaultOutput,
);
const _checkOnly = bool.fromEnvironment('COLOR_TOKEN_CHECK');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('export the complete Rios color token set', () async {
    final output = File(_outputPath);
    final json = '${const JsonEncoder.withIndent('  ').convert(_tokenSet())}\n';
    if (_checkOnly) {
      expect(output.existsSync(), isTrue, reason: 'Run the exporter first.');
      expect(await output.readAsString(), json);
      return;
    }

    await output.parent.create(recursive: true);
    await output.writeAsString(json);
    stdout.writeln('Exported color tokens to $_outputPath');
  });
}

Map<String, Object?> _tokenSet() => {
  'primitive': buildPrimitiveColorTokens(),
  'semantic': {
    'light': _semanticTokens(AmbleTheme.light),
    'dark': _semanticTokens(AmbleTheme.dark),
  },
  'component': _componentTokens(),
};

Map<String, Object?> _semanticTokens(AmbleTheme theme) => {
  'surface': colorEntries({
    'base': theme.colorSurfaceBase,
    'primary': theme.colorSurfacePrimary,
    'secondary': theme.colorSurfaceSecondary,
    'timeline': theme.colorSurfaceTimeline,
    'overlay': theme.colorSurfaceOverlay,
    'field': theme.colorSurfaceField,
    'fieldActive': theme.colorSurfaceFieldActive,
    'scrim': theme.colorScrim,
    'blurOverlay': theme.colorSurfaceBlurOverlay,
    'freeWindow': theme.colorFreeWindow,
    'zoneBackground': theme.colorZoneBackground,
    'whatMatters': theme.colorSurfaceWhatMatters,
  }),
  'text': colorEntries({
    'primary': theme.colorTextPrimary,
    'secondary': theme.colorTextSecondary,
    'tertiary': theme.colorTextTertiary,
  }),
  'foreground': colorEntries({'tertiary': theme.colorForegroundTertiary}),
  'border': colorEntries({'default': theme.colorBorder}),
  'accent': colorEntries({'default': theme.colorAccent}),
  'task': colorEntries({
    'completed': theme.colorTaskCompleted,
    'skipped': theme.colorTaskSkipped,
    'alert': theme.colorTaskAlert,
    'destructive': theme.colorDestructive,
  }),
  'category': namedColors(theme.categorySwatches),
  'categoryAccent': namedColors(theme.categoryAccents),
  'categoryTint': namedColors([
    for (final swatch in theme.categorySwatches)
      TaskStateTokens.categoryTint(theme, swatch),
  ]),
  'elevation': {
    'paneShadow': indexedColors(theme.shadowPane.map((shadow) => shadow.color)),
    'liftShadow': indexedColors(theme.shadowLift.map((shadow) => shadow.color)),
  },
};

Map<String, Object?> _componentTokens() {
  const puff = DeletePuffSpec();
  return {
    'floatingSurface': {
      'light': _floatingSurfaceTokens(AmbleTheme.light),
      'dark': _floatingSurfaceTokens(AmbleTheme.dark),
    },
    'taskState': {
      'shared': colorEntries({
        'glyphOnDark': TaskStateTokens.glyphOnDark,
        'glyphOnLight': TaskStateTokens.glyphOnLight,
      }),
      'light': _taskStateTokens(AmbleTheme.light),
      'dark': _taskStateTokens(AmbleTheme.dark),
    },
    'deletePuff': colorEntries({
      'smoke': puff.smokeColor,
      'shadow': puff.shadowColor,
      'highlight': puff.highlightColor,
    }),
  };
}

Map<String, Object?> _floatingSurfaceTokens(AmbleTheme theme) => colorEntries({
  'glassFill': theme.colorSurfaceOverlay.withValues(
    alpha: FloatingSurfaceTokens.fillAlpha,
  ),
  'border': FloatingSurfaceTokens.border(theme),
  'topHighlight': FloatingSurfaceTokens.highlight(theme),
  'selectedFill': FloatingSurfaceTokens.selected(theme),
  'menuShadow': FloatingSurfaceTokens.shadow(
    theme,
    FloatingElevation.menu,
  ).color,
  'dragShadow': FloatingSurfaceTokens.shadow(
    theme,
    FloatingElevation.drag,
  ).color,
});

Map<String, Object?> _taskStateTokens(AmbleTheme theme) {
  final star = TaskStateTokens.importantStarGradient(theme);
  return {
    'doneFill': namedColors(
      theme.categorySwatches
          .map((labelColor) => TaskStateTokens.doneFill(theme, labelColor))
          .toList(),
    ),
    ...colorEntries({
      'doneTitle': TaskStateTokens.doneTitle(theme),
      'unlabeledFill': TaskStateTokens.unlabeledFill(theme),
      'importedHatch': TaskStateTokens.importedHatch(theme),
      'importantTitle': TaskStateTokens.importantTitle(theme),
      'importantStarStart': star.first,
      'importantStarEnd': star.last,
    }),
  };
}
