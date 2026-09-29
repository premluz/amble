import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_sheet_handle.dart';
import 'package:amble/core/widgets/app_sheet_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}
