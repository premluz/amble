import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/tokens/component_tokens.dart';
import 'package:amble/core/widgets/app_sheet_handle.dart';
import 'package:amble/core/widgets/app_step_scaffold.dart'
    show HeaderCircleButton;
import 'package:amble/core/widgets/app_text_field.dart';
import 'package:amble/core/widgets/app_sheet_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Requested directly against a screenshot: "the sheets side padding
  // match top padding so the circular buttons on left and right are
  // precisely same padding top and left" — ratified as a rule for every
  // `HeaderCircleButton` sited at a fixed-height header's own edge (see
  // docs/DESIGN_SYSTEM.md's "Sheet header circle buttons" section).
  testWidgets(
    "the close button's top inset equals the sheet's own side inset — not "
    'vertically centred in the (taller, for other reasons) header row',
    (tester) async {
      final theme = AmbleTheme.light;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [theme]),
          home: Scaffold(
            // The real caller shape: `AppSheet.show`'s own
            // `EdgeInsets.symmetric(horizontal: spacingLg)` around the
            // header, which is where the "side" half of this rule's
            // value actually comes from.
            body: Padding(
              padding: EdgeInsets.symmetric(horizontal: theme.spacingLg),
              child: AppSheetHeader(theme: theme, onClose: () {}),
            ),
          ),
        ),
      );
      final headerTop = tester.getTopLeft(find.byType(AppSheetHeader)).dy;
      final buttonRect = tester.getRect(find.byType(HeaderCircleButton));
      final sheetLeft = tester.getTopLeft(find.byType(Padding).first).dx;

      expect(
        buttonRect.top - headerTop,
        theme.spacingLg,
        reason: 'top inset from the header row',
      );
      expect(
        buttonRect.left - sheetLeft,
        theme.spacingLg,
        reason: 'side inset from the sheet edge',
      );
    },
  );

  testWidgets('every sheet header shows the handle bar, as decoration only '
      '— the whole sheet is the drag target', (tester) async {
    final theme = AmbleTheme.light;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [theme]),
        home: Scaffold(
          body: AppSheetHeader(theme: theme, onClose: () {}),
        ),
      ),
    );
    expect(find.byType(AppSheetHandle), findsOneWidget);
    final ignoring = tester
        .widgetList<IgnorePointer>(
          find.ancestor(
            of: find.byType(AppSheetHandle),
            matching: find.byType(IgnorePointer),
          ),
        )
        .any((widget) => widget.ignoring);
    expect(ignoring, isTrue);
  });

  testWidgets('a sheet\'s title and its name fields share one size, a step '
      'below textTitle', (tester) async {
    final theme = AmbleTheme.light;
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [theme]),
        home: Scaffold(
          body: Column(
            children: [
              AppSheetHeader(theme: theme, title: 'Label', onClose: () {}),
              AppTextField(
                controller: controller,
                label: 'Add title',
                variant: AppTextFieldVariant.bare,
              ),
            ],
          ),
        ),
      ),
    );
    final size = SheetTokens.titleStyle(theme).fontSize;
    expect(size, lessThan(theme.textTitle.fontSize!));
    expect(tester.widget<Text>(find.text('Label')).style!.fontSize, size);
    expect(
      tester.widget<TextField>(find.byType(TextField)).style!.fontSize,
      size,
    );
  });
}
