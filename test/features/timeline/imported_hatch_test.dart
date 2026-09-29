import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/tokens/task_state_tokens.dart';
import 'package:amble/core/widgets/app_hatch.dart';
import 'package:amble/features/timeline/external_event_capsule_block.dart'
    show DashedPillRail;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Imported events carry faint 45° hatching inside their flat rail —
/// BRAND.md's provenance texture — clipped to the pill, with no outline.
void main() {
  for (final MapEntry(key: name, value: theme) in {
    'light': AmbleTheme.light,
    'dark': AmbleTheme.dark,
  }.entries) {
    testWidgets('$name: the imported rail is hatched, clipped to the pill, '
        'in the quiet provenance colour', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [theme]),
          home: Scaffold(
            body: Center(
              child: DashedPillRail(theme: theme, width: 24, height: 90),
            ),
          ),
        ),
      );

      final hatch = tester.widget<AppHatch>(find.byType(AppHatch));
      expect(hatch.color, TaskStateTokens.importedHatch(theme));
      expect(hatch.color.a, lessThan(.2), reason: 'informative but quiet');
      final clip = tester.widget<ClipRRect>(
        find.ancestor(
          of: find.byType(AppHatch),
          matching: find.byType(ClipRRect),
        ),
      );
      expect(clip.borderRadius, BorderRadius.circular(theme.radiusPill));
      expect(tester.getSize(find.byType(AppHatch)), const Size(24, 90));
    });
  }
}
