import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_layout_reveal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _opacity = ValueKey('reveal-opacity');
final _theme = AmbleTheme.light;

double _progress(WidgetTester tester) => tester
    .widget<Opacity>(
      find.descendant(
        of: find.byType(AppLayoutReveal),
        matching: find.byType(Opacity),
      ),
    )
    .opacity;

Future<void> _open(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(extensions: [_theme]),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push<void>(
              layoutRevealRoute(context, (_) => Scaffold(body: child)),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pump();
  await tester.pump();
}

void main() {
  for (final scrollOffset in [120.0, 640.0]) {
    testWidgets('positions at $scrollOffset before fading over the old page', (
      tester,
    ) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      final child = _PositionedList(scroll: scroll, offset: scrollOffset);
      await _open(tester, child);
      expect(_progress(tester), 0);
      expect(find.text('Open'), findsOneWidget);
      await tester.pump();
      expect(scroll.offset, scrollOffset);
      final positioned = tester.getTopLeft(find.text('Row 10'));
      await tester.pump(_theme.motionFast * .5);
      expect(_progress(tester), allOf(greaterThan(0), lessThan(1)));
      expect(tester.getTopLeft(find.text('Row 10')), positioned);
      await tester.pumpAndSettle();
      expect(_progress(tester), 1);
      Navigator.of(tester.element(find.byType(_PositionedList))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(AppLayoutReveal), findsNothing);
      expect(find.text('Open'), findsOneWidget);
    });
  }

  testWidgets(
    'zero-duration gate reveals next frame and does not replay on rebuild',
    (tester) async {
      Widget page(String label) => MaterialApp(
        home: AppLayoutReveal(opacityKey: _opacity, child: Text(label)),
      );
      await tester.pumpWidget(page('First'));
      expect(_progress(tester), 0);
      await tester.pump();
      expect(_progress(tester), 1);
      await tester.pumpWidget(page('Updated'));
      expect(_progress(tester), 1);
      expect(find.text('Updated'), findsOneWidget);
    },
  );

  testWidgets('reduced motion retains layout gate but skips fade', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: AppLayoutReveal(
            duration: _theme.motionFast,
            child: const Text('Ready'),
          ),
        ),
      ),
    );
    expect(_progress(tester), 0);
    await tester.pump();
    expect(_progress(tester), 1);
  });

  testWidgets(
    'input is blocked until reveal completes',
    (tester) async {
      var taps = 0;
      await _open(
        tester,
        TextButton(onPressed: () => taps++, child: const Text('Act')),
      );
      final position = tester.getCenter(find.text('Act'));
      await tester.tapAt(position);
      expect(taps, 0);
      await tester.pumpAndSettle();
      await tester.tapAt(position);
      expect(taps, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('unmounting during the fade disposes the animation', (tester) async {
    await _open(tester, const Text('Incoming'));
    await tester.pump(_theme.motionFast * .5);
    expect(_progress(tester), allOf(greaterThan(0), lessThan(1)));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

class _PositionedList extends StatefulWidget {
  const _PositionedList({required this.scroll, required this.offset});
  final ScrollController scroll;
  final double offset;

  @override
  State<_PositionedList> createState() => _PositionedListState();
}

class _PositionedListState extends State<_PositionedList> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.scroll.jumpTo(widget.offset);
    });
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    controller: widget.scroll,
    child: Column(
      children: [
        for (var index = 0; index < 40; index++)
          SizedBox(height: 80, child: Text('Row $index')),
      ],
    ),
  );
}
