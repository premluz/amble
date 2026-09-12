import 'package:amble/core/haptics.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_press_feedback.dart';
import 'package:amble/core/widgets/app_switch.dart';
import 'package:amble/features/timeline/completion_checkbox.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'recording_haptics.dart';

Widget _host(Widget child, {TargetPlatform platform = TargetPlatform.android}) {
  return MaterialApp(
    theme: ThemeData(
      useMaterial3: true,
      platform: platform,
      extensions: [AmbleTheme.light],
    ),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('AppPressFeedback', () {
    testWidgets('plays the tap haptic when pressed', (tester) async {
      final haptics = RecordingHaptics();
      await tester.pumpWidget(
        _host(
          AppPressFeedback(
            onTap: () {},
            haptics: haptics,
            child: const SizedBox(width: 200, height: 60),
          ),
        ),
      );

      await tester.tap(find.byType(AppPressFeedback));
      await tester.pumpAndSettle();

      expect(haptics.played, [AmbleHaptic.tap]);
    });

    testWidgets('stays silent when haptic is null', (tester) async {
      final haptics = RecordingHaptics();
      await tester.pumpWidget(
        _host(
          AppPressFeedback(
            onTap: () {},
            haptic: null,
            haptics: haptics,
            child: const SizedBox(width: 200, height: 60),
          ),
        ),
      );

      await tester.tap(find.byType(AppPressFeedback));
      await tester.pumpAndSettle();

      expect(haptics.played, isEmpty);
    });

    testWidgets('fires on press-down, before the tap is released', (
      tester,
    ) async {
      final haptics = RecordingHaptics();
      var tapped = false;
      await tester.pumpWidget(
        _host(
          AppPressFeedback(
            onTap: () => tapped = true,
            haptics: haptics,
            child: const SizedBox(width: 200, height: 60),
          ),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(AppPressFeedback)),
      );
      await tester.pump();

      // The whole point of firing in _startPress rather than onTapUp: the
      // haptic lands with the ripple and the scale dip, not after them.
      expect(haptics.played, [AmbleHaptic.tap]);
      expect(tapped, isFalse);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });
  });

  group('AppSwitch', () {
    testWidgets('plays a selection haptic on the Material branch', (
      tester,
    ) async {
      final haptics = RecordingHaptics();
      await tester.pumpWidget(
        _host(
          AppSwitch(value: false, onChanged: (_) {}, haptics: haptics),
          platform: TargetPlatform.android,
        ),
      );

      await tester.tap(find.byType(AppSwitch));
      await tester.pumpAndSettle();

      expect(haptics.played, [AmbleHaptic.selection]);
    });

    testWidgets('stays silent on iOS, where CupertinoSwitch plays its own', (
      tester,
    ) async {
      final haptics = RecordingHaptics();
      await tester.pumpWidget(
        _host(
          AppSwitch(value: false, onChanged: (_) {}, haptics: haptics),
          platform: TargetPlatform.iOS,
        ),
      );

      await tester.tap(find.byType(AppSwitch));
      await tester.pumpAndSettle();

      expect(haptics.played, isEmpty);
    });
  });

  group('CompletionCheckbox', () {
    Future<void> pumpCheckbox(
      WidgetTester tester, {
      required bool isCompleted,
      required RecordingHaptics haptics,
    }) {
      return tester.pumpWidget(
        _host(
          CompletionCheckbox(
            theme: AmbleTheme.light,
            isCompleted: isCompleted,
            onToggle: () {},
            haptics: haptics,
          ),
        ),
      );
    }

    testWidgets('completing plays success', (tester) async {
      final haptics = RecordingHaptics();
      await pumpCheckbox(tester, isCompleted: false, haptics: haptics);

      await tester.tap(find.byType(CompletionCheckbox));
      await tester.pump();

      expect(haptics.played, [AmbleHaptic.success]);
    });

    testWidgets('un-completing plays the lighter selection, not success', (
      tester,
    ) async {
      final haptics = RecordingHaptics();
      await pumpCheckbox(tester, isCompleted: true, haptics: haptics);

      await tester.tap(find.byType(CompletionCheckbox));
      await tester.pump();

      expect(haptics.played, [AmbleHaptic.selection]);
    });
  });
}
