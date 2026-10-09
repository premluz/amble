import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amble/core/tokens/component_tokens.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_date_picker.dart';
import 'package:amble/core/widgets/app_floating_surface.dart';
import 'package:amble/core/widgets/app_popover_geometry.dart';
import 'package:amble/core/widgets/app_sheet.dart';
import 'package:amble/core/widgets/app_sheet_handle.dart';
import 'package:amble/core/widgets/app_sheet_header.dart';
import 'package:amble/core/widgets/app_sheet_presentation.dart';
import 'package:amble/core/widgets/app_sheet_surface.dart';

/// `AppSheet.show` in an [AppSheetPresentation.popover] scope (the wide
/// layout's task panel) opens a popover beside the control instead of a
/// bottom sheet; outside a scope it is unchanged.

const _anchorKey = Key('anchor');

/// A button at [left] that opens a sheet with [content].
Future<void> _pumpOpener(
  WidgetTester tester, {
  required AppSheetPresentation? presentation,
  required double left,
  required WidgetBuilder content,
  ValueChanged<Object?>? onResult,
}) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final opener = Builder(
    builder: (context) => SizedBox(
      key: _anchorKey,
      width: 200,
      height: 40,
      child: GestureDetector(
        onTap: () async {
          final result = await AppSheet.show<Object>(
            context: context,
            builder: content,
          );
          onResult?.call(result);
        },
      ),
    ),
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
      home: Scaffold(
        body: Stack(
          children: [
            Positioned(
              left: left,
              top: 120,
              child: presentation == null
                  ? opener
                  : AppSheetPresentationScope(
                      presentation: presentation,
                      child: opener,
                    ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _picker(BuildContext context) {
  final theme = Theme.of(context).extension<AmbleTheme>()!;
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      AppSheetHeader(
        theme: theme,
        title: 'Pick',
        onClose: () => Navigator.of(context).pop(),
      ),
      TextButton(
        onPressed: () => Navigator.of(context).pop('chosen'),
        child: const Text('Choose'),
      ),
    ],
  );
}

Rect _popover(WidgetTester tester) =>
    tester.getRect(find.byType(AppFloatingSurface));

void main() {
  testWidgets('outside a popover scope it is still a bottom sheet', (
    tester,
  ) async {
    await _pumpOpener(
      tester,
      presentation: null,
      left: 900,
      content: _picker,
    );
    await tester.tap(find.byKey(_anchorKey));
    await tester.pumpAndSettle();

    expect(find.byType(AppSheetSurface), findsOneWidget);
    expect(find.byType(AppSheetHandle), findsOneWidget);
  });

  testWidgets('in a popover scope it opens beside the control, no handle', (
    tester,
  ) async {
    await _pumpOpener(
      tester,
      presentation: AppSheetPresentation.popover,
      left: 900,
      content: _picker,
    );
    await tester.tap(find.byKey(_anchorKey));
    await tester.pumpAndSettle();

    final anchor = tester.getRect(find.byKey(_anchorKey));
    final popover = _popover(tester);
    expect(find.byType(AppSheetSurface), findsNothing);
    expect(find.text('Pick'), findsOneWidget);
    expect(find.byType(AppSheetHandle), findsNothing);
    expect(popover.width, PopoverTokens.width);
    expect(popover.right, lessThan(anchor.left));
    expect(popover.top, anchor.top);
  });

  testWidgets('returns the picked value, and a tap outside closes it', (
    tester,
  ) async {
    final results = <Object?>[];
    await _pumpOpener(
      tester,
      presentation: AppSheetPresentation.popover,
      left: 900,
      content: _picker,
      onResult: results.add,
    );
    await tester.tap(find.byKey(_anchorKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose'));
    await tester.pumpAndSettle();
    expect(results, ['chosen']);

    await tester.tap(find.byKey(_anchorKey));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(20, 700));
    await tester.pumpAndSettle();
    expect(find.text('Pick'), findsNothing);
    expect(results, ['chosen', null]);
  });

  testWidgets('a control near the left edge gets it on its right', (
    tester,
  ) async {
    await _pumpOpener(
      tester,
      presentation: AppSheetPresentation.popover,
      left: 40,
      content: _picker,
    );
    await tester.tap(find.byKey(_anchorKey));
    await tester.pumpAndSettle();

    expect(
      _popover(tester).left,
      greaterThan(tester.getRect(find.byKey(_anchorKey)).right),
    );
  });

  testWidgets('it resizes when its content grows', (tester) async {
    await _pumpOpener(
      tester,
      presentation: AppSheetPresentation.popover,
      left: 900,
      content: (context) => StatefulBuilder(
        builder: (context, setState) => _Growable(),
      ),
    );
    await tester.tap(find.byKey(_anchorKey));
    await tester.pumpAndSettle();
    final before = _popover(tester).height;

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();

    expect(_popover(tester).height, greaterThan(before));
    expect(find.text('Extra'), findsOneWidget);
  });

  testWidgets('the date picker is a month calendar in the popover', (
    tester,
  ) async {
    final picked = <DateTime?>[];
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topRight,
            child: AppSheetPresentationScope(
              presentation: AppSheetPresentation.popover,
              child: Builder(
                builder: (context) => TextButton(
                  onPressed: () async => picked.add(
                    await showAppDatePicker(
                      context: context,
                      initialDate: DateTime(2026, 10, 4),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    ),
                  ),
                  child: const Text('Date'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Date'));
    await tester.pumpAndSettle();

    expect(find.byType(CalendarDatePicker), findsOneWidget);
    expect(find.byType(DatePickerDialog), findsNothing);
    await tester.tap(find.text('15'));
    await tester.pumpAndSettle();
    expect(picked, [DateTime(2026, 10, 15)]);
    expect(find.byType(CalendarDatePicker), findsNothing);
  });

  group('popoverOrigin', () {
    const bounds = Rect.fromLTRB(8, 8, 1272, 792);
    const size = Size(320, 300);

    test('left of the anchor, top-aligned', () {
      final origin = popoverOrigin(
        anchor: const Rect.fromLTWH(900, 100, 200, 40),
        size: size,
        bounds: bounds,
        gap: 8,
      );
      expect(origin, const Offset(572, 100));
    });

    test('kept on screen when the anchor is low', () {
      final origin = popoverOrigin(
        anchor: const Rect.fromLTWH(900, 700, 200, 40),
        size: size,
        bounds: bounds,
        gap: 8,
      );
      expect(origin.dy, 792 - 300);
    });

    test('below the anchor when neither side has room', () {
      final origin = popoverOrigin(
        anchor: const Rect.fromLTWH(100, 100, 200, 40),
        size: size,
        bounds: const Rect.fromLTRB(8, 8, 500, 792),
        gap: 8,
      );
      expect(origin, const Offset(100, 148));
    });
  });
}

class _Growable extends StatefulWidget {
  @override
  State<_Growable> createState() => _GrowableState();
}

class _GrowableState extends State<_Growable> {
  var _more = false;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      TextButton(
        onPressed: () => setState(() => _more = true),
        child: const Text('More'),
      ),
      if (_more) const SizedBox(height: 200, child: Text('Extra')),
    ],
  );
}
