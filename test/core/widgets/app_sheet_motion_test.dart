import 'dart:async';

import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_sheet_keyboard.dart';
import 'package:amble/core/widgets/app_sheet_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _surface = ValueKey('test-sheet-surface');
const _sheetHeight = 120.0;
final _theme = AmbleTheme.light;

Future<StreamController<SheetKeyboardFrame>> _mount(
  WidgetTester tester, {
  bool keyboard = true,
}) async {
  final events = StreamController<SheetKeyboardFrame>.broadcast(sync: true);
  final route = AnimationController(
    vsync: tester,
    duration: _theme.motionKeyboardSettle,
  );
  await tester.pumpWidget(
    MaterialApp(
      home: AppSheetMotion(
        theme: _theme,
        routeAnimation: route,
        autofocusesKeyboard: keyboard,
        keyboardFrames: events.stream,
        child: const SizedBox(key: _surface, width: 300, height: _sheetHeight),
      ),
    ),
  );
  route.forward();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await events.close();
    route.dispose();
    tester.view.resetViewInsets();
  });
  return events;
}

Future<void> _frame(
  WidgetTester tester,
  StreamController<SheetKeyboardFrame> events, {
  required double fraction,
  required int duration,
  required double inset,
}) async {
  tester.view.viewInsets = FakeViewPadding(
    bottom: inset * tester.view.devicePixelRatio,
  );
  events.add(
    SheetKeyboardFrame(
      inset: inset,
      fraction: fraction,
      duration: Duration(milliseconds: duration),
      opening: true,
    ),
  );
  await tester.pump();
}

double _visibility(WidgetTester tester) => tester
    .widget<Opacity>(
      find.descendant(
        of: find.byType(AppSheetMotion),
        matching: find.byType(Opacity),
      ),
    )
    .opacity;

void main() {
  for (final duration in [80, 240, 700]) {
    testWidgets('joins the actual $duration ms IME tail and finishes with it', (
      tester,
    ) async {
      final events = await _mount(tester);
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        _visibility(tester),
        0,
        reason: 'late IME must not be replaced by the 260ms estimate',
      );
      await _frame(tester, events, fraction: .2, duration: duration, inset: 80);
      expect(_visibility(tester), duration < _theme.motionSheetSlide.inMilliseconds ? 1 : 0);
      await _frame(
        tester,
        events,
        fraction: .8,
        duration: duration,
        inset: 240,
      );
      expect(_visibility(tester), 1);
      final window = duration < _theme.motionSheetSlide.inMilliseconds
          ? duration : _theme.motionSheetSlide.inMilliseconds;
      final progress = 1 - duration * .2 / window;
      final height =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      final expectedTop =
          height -
          240 -
          _sheetHeight * _theme.curveDecelerate.transform(progress);
      expect(
        tester.getTopLeft(find.byKey(_surface)).dy,
        closeTo(expectedTop, .01),
      );
      await _frame(tester, events, fraction: 1, duration: duration, inset: 300);
      await tester.pump();
      expect(tester.getRect(find.byKey(_surface)).bottom, height - 300);
      await tester.pumpAndSettle();
    });
  }

  testWidgets('plain sheet moves its own height, not a full viewport', (
    tester,
  ) async {
    await _mount(tester, keyboard: false);
    await tester.pump();
    await tester.pump(_theme.motionKeyboardSettle * .5);
    final height =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    final top = tester.getTopLeft(find.byKey(_surface)).dy;
    expect(
      top,
      closeTo(
        height - _sheetHeight * _theme.curveDecelerate.transform(.5),
        .01,
      ),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('an already-open keyboard uses an ordinary sheet slide', (
    tester,
  ) async {
    tester.view.viewInsets = FakeViewPadding(
      bottom: 300 * tester.view.devicePixelRatio,
    );
    final events = await _mount(tester);
    await _frame(tester, events, fraction: 1, duration: 0, inset: 300);
    await tester.pump(_theme.motionSheetSlide * .5);
    expect(_visibility(tester), 1);
    await tester.pumpAndSettle();
    final height =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(tester.getRect(find.byKey(_surface)).bottom, height - 300);
  });

  testWidgets('keyboard closing during entrance cannot leave the sheet hidden', (tester) async {
    final events = await _mount(tester);
    await _frame(tester, events, fraction: .2, duration: 700, inset: 80);
    events.add(const SheetKeyboardFrame(
      inset: 0, fraction: 1, duration: Duration(milliseconds: 700), opening: false,
    ));
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(_visibility(tester), 1);
  });

  testWidgets('plain sheets release keyboard space when the keyboard hides', (tester) async {
    await _mount(tester, keyboard: false);
    tester.view.viewInsets = FakeViewPadding(bottom: 300 * tester.view.devicePixelRatio);
    await tester.pumpAndSettle();
    tester.view.resetViewInsets();
    await tester.pump();
    final height = tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(tester.getRect(find.byKey(_surface)).bottom, height);
  });

  testWidgets('early dismissal preserves the visible entrance position', (tester) async {
    final events = await _mount(tester);
    await tester.pump();
    await tester.pump(_theme.motionKeyboardSettle * .5);
    await _frame(tester, events, fraction: .8, duration: 240, inset: 240);
    final before = tester.getTopLeft(find.byKey(_surface)).dy;
    final motion = tester.widget<AppSheetMotion>(find.byType(AppSheetMotion));
    if (motion.routeAnimation case AnimationController controller) {
      controller.reverse();
    } else {
      fail('The harness must expose its route controller');
    }
    await tester.pump();
    expect(tester.getTopLeft(find.byKey(_surface)).dy, closeTo(before, .01));
    await tester.pumpAndSettle();
  });

  testWidgets('disposing while waiting cancels the no-keyboard timeout', (
    tester,
  ) async {
    await _mount(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });
}
