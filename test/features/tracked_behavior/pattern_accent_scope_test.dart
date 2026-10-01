import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amble/core/dev_config.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/tracked_behavior/pattern_accent_scope.dart';

/// Requested directly: Developer → "Accent strength" is for Patterns only,
/// not the whole app.
void main() {
  testWidgets('accent strength changes the accent inside Patterns only', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(devAccentStrengthProvider.notifier).set(.5);
    final theme = AmbleTheme.light;
    late Color outside;
    late Color inside;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData(extensions: [theme]),
          home: Column(
            children: [
              Builder(
                builder: (context) {
                  outside = Theme.of(context)
                      .extension<AmbleTheme>()!
                      .colorAccent;
                  return const SizedBox.shrink();
                },
              ),
              PatternAccentScope(
                child: Builder(
                  builder: (context) {
                    inside = Theme.of(context)
                        .extension<AmbleTheme>()!
                        .colorAccent;
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(outside, theme.colorAccent);
    expect(inside, Color.lerp(theme.colorSurfaceBase, theme.colorAccent, .5));
  });
}
