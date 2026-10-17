import 'package:amble/features/timeline/timeline_pinch_zoom.dart';
import 'package:amble/core/dev_config.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:amble/core/tokens/component_tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/shared/providers/preferences_providers.dart';
import 'package:amble/shared/repositories/hive_preferences_repository.dart';

import '../../support/memory_zone_repositories.dart';

void main() {
  late Box<dynamic> box;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_pinch_zoom');
    box = await Hive.openBox<dynamic>(
      'test_pinch_${DateTime.now().microsecondsSinceEpoch}',
    );
  });

  tearDown(() => box.deleteFromDisk());

  testWidgets('reports two or more fingers down (a pinch) to its owner and '
      'to descendants, and clears when fewer remain', (tester) async {
    final multiTouch = ValueNotifier(false);
    addTearDown(multiTouch.dispose);
    ValueNotifier<bool>? seenBelow;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          devShowTouchesProvider.overrideWithValue(false),
          preferencesRepositoryProvider.overrideWithValue(
            HivePreferencesRepository(box),
          ),
        ],
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: TimelinePinchZoom(
            multiTouch: multiTouch,
            child: Builder(
              builder: (context) {
                seenBelow = TimelineMultiTouch.of(context);
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      ),
    );
    expect(seenBelow, same(multiTouch));

    final a = await tester.startGesture(const Offset(100, 100));
    expect(multiTouch.value, isFalse, reason: 'one finger');
    final b = await tester.startGesture(const Offset(200, 200));
    expect(multiTouch.value, isTrue, reason: 'two fingers: a pinch');
    await b.up();
    expect(multiTouch.value, isFalse);
    await a.up();
  });

  group('Cmd/Ctrl + scroll zooms the timeline (desktop)', () {
    // The key that zooms: Cmd on Apple platforms, Ctrl elsewhere. The tests
    // run under the default (Android) platform, so Ctrl.
    const zoomKey = LogicalKeyboardKey.controlLeft;

    late ScrollController scroll;
    late ProviderContainer container;

    Future<void> pumpZoomable(WidgetTester tester) async {
      scroll = ScrollController();
      addTearDown(scroll.dispose);
      container = ProviderContainer(
        overrides: [
          devShowTouchesProvider.overrideWithValue(false),
          // In memory: zooming writes the scale, and real Hive I/O under fake
          // time stalls the test's teardown.
          preferencesRepositoryProvider.overrideWithValue(
            MemoryPreferencesRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(
              height: 400,
              child: TimelinePinchZoom(
                scrollController: scroll,
                child: SingleChildScrollView(
                  controller: scroll,
                  child: const SizedBox(height: 4000, width: 400),
                ),
              ),
            ),
          ),
        ),
      );
    }

    Future<void> wheel(WidgetTester tester, double dy) async {
      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(pointer.hover(const Offset(100, 200)));
      await tester.sendEventToBinding(pointer.scroll(Offset(0, dy)));
      await tester.pump();
    }

    double scale() => container.read(timelinePixelsPerMinuteSettingProvider);

    testWidgets('wheel without the key scrolls and leaves the scale alone', (
      tester,
    ) async {
      await pumpZoomable(tester);
      final before = scale();
      await wheel(tester, 100);
      expect(scroll.offset, greaterThan(0));
      expect(scale(), before);
    });

    testWidgets('wheel up with the key zooms in; down zooms out; no scroll', (
      tester,
    ) async {
      await pumpZoomable(tester);
      final start = scale();

      await tester.sendKeyDownEvent(zoomKey);
      await tester.pump();
      await wheel(tester, -100);
      expect(scale(), greaterThan(start), reason: 'scroll up zooms in');
      // Anchored on the pointer (200 down, 60 of top clearance), not a scroll
      // by the wheel's 100: (offset + 200 - 60) scales with the zoom.
      expect(
        scroll.offset,
        closeTo((200 - 60) * scale() / start - (200 - 60), .5),
        reason: 'the wheel zoomed instead of scrolling',
      );

      final zoomedIn = scale();
      await wheel(tester, 100);
      expect(scale(), lessThan(zoomedIn), reason: 'scroll down zooms out');
      await tester.sendKeyUpEvent(zoomKey);
    });

    testWidgets('the scale stays within its limits', (tester) async {
      await pumpZoomable(tester);
      await tester.sendKeyDownEvent(zoomKey);
      await tester.pump();
      for (var i = 0; i < 40; i++) {
        await wheel(tester, -400);
      }
      expect(scale(), TimelinePixelsPerMinuteSetting.maxPixelsPerMinute);
      for (var i = 0; i < 80; i++) {
        await wheel(tester, 400);
      }
      expect(scale(), TimelinePixelsPerMinuteSetting.minPixelsPerMinute);
      await tester.sendKeyUpEvent(zoomKey);
    });

    testWidgets('zooming keeps the time under the pointer where it was', (
      tester,
    ) async {
      await pumpZoomable(tester);
      scroll.jumpTo(1000);
      await tester.pump();
      const pointerY = 200.0;
      // The time under the pointer, in minutes, before and after.
      double timeUnder() =>
          (scroll.offset + pointerY - TimelineScrollTokens.topClearance) /
          scale();
      final before = timeUnder();

      await tester.sendKeyDownEvent(zoomKey);
      await tester.pump();
      await wheel(tester, -200);
      await tester.pump();
      expect(timeUnder(), closeTo(before, .5));
      await tester.sendKeyUpEvent(zoomKey);
    });

    testWidgets('releasing the key restores normal scrolling', (tester) async {
      await pumpZoomable(tester);
      await tester.sendKeyDownEvent(zoomKey);
      await tester.pump();
      await tester.sendKeyUpEvent(zoomKey);
      await tester.pump();
      await wheel(tester, 100);
      expect(scroll.offset, greaterThan(0));
    });
  });
}
