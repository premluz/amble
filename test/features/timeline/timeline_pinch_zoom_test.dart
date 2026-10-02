import 'package:amble/features/timeline/timeline_pinch_zoom.dart';
import 'package:amble/core/dev_config.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/shared/providers/preferences_providers.dart';
import 'package:amble/shared/repositories/hive_preferences_repository.dart';

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
}
