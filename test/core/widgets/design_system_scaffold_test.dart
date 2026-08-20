// SCAFFOLDING — not a real screen. Exists only to prove the Tier 1/2/3
// token system and the AppButton/AppSheet adaptive widgets compose
// end-to-end with zero hardcoded values. Delete once Phase 2 exit
// criteria have been reviewed, or once a real screen supersedes it.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_button.dart';
import 'package:amble/core/widgets/app_sheet.dart';

class _DesignSystemScaffold extends StatelessWidget {
  const _DesignSystemScaffold();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;

    return Scaffold(
      backgroundColor: theme.colorSurfacePrimary,
      body: Padding(
        padding: EdgeInsets.all(theme.spacingScreenPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Design system scaffold', style: theme.textHeadline),
            SizedBox(height: theme.spacingMd),
            Text(
              'Proves tokens + adaptive widgets compose.',
              style: theme.textBody,
            ),
            SizedBox(height: theme.spacingLg),
            Wrap(
              spacing: theme.spacingSm,
              children: [
                for (final entry in theme.categoryColors.entries)
                  Container(
                    width: theme.spacingXl,
                    height: theme.spacingXl,
                    decoration: BoxDecoration(
                      color: entry.value,
                      borderRadius: BorderRadius.circular(theme.radiusCard),
                    ),
                  ),
              ],
            ),
            SizedBox(height: theme.spacingLg),
            AppButton(
              label: 'Primary action',
              onPressed: () => AppSheet.show<void>(
                context: context,
                // A TextField (Material widget) here specifically catches
                // the "No Material widget found" crash the Cupertino sheet
                // branch had — a plain Text never exercised that path.
                builder: (context) => const TextField(
                  decoration: InputDecoration(labelText: 'Sheet content'),
                ),
              ),
            ),
            SizedBox(height: theme.spacingSm),
            const AppButton(
              label: 'Secondary action',
              variant: AppButtonVariant.secondary,
              onPressed: null,
            ),
          ],
        ),
      ),
    );
  }
}

Widget _wrap(TargetPlatform platform) {
  return MaterialApp(
    theme: ThemeData(
      useMaterial3: true,
      platform: platform,
      extensions: [AmbleTheme.light],
    ),
    home: const _DesignSystemScaffold(),
  );
}

void main() {
  testWidgets('renders using only tokens and adaptive widgets (Material)', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(TargetPlatform.android));

    expect(find.text('Design system scaffold'), findsOneWidget);
    expect(find.byType(AppButton), findsNWidgets(2));
    expect(find.byType(ElevatedButton), findsNWidgets(2));
  });

  testWidgets('renders using only tokens and adaptive widgets (Cupertino)', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(TargetPlatform.iOS));

    expect(find.text('Design system scaffold'), findsOneWidget);
    expect(find.byType(AppButton), findsNWidgets(2));
    expect(find.byType(CupertinoButton), findsNWidgets(2));
  });

  testWidgets(
    'AppSheet opens using the adaptive layer, not a raw platform call',
    (tester) async {
      await tester.pumpWidget(_wrap(TargetPlatform.android));

      await tester.tap(find.text('Primary action'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
    },
  );

  testWidgets(
    'AppSheet on Cupertino has a Material ancestor for Material sheet content',
    (tester) async {
      await tester.pumpWidget(_wrap(TargetPlatform.iOS));

      await tester.tap(find.text('Primary action'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
