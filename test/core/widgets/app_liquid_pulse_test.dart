import 'package:amble/core/tokens/liquid_pulse_spec.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_liquid_pulse.dart';
import 'package:amble/features/timeline/task_capsule_block.dart';
import 'package:amble/features/timeline/task_compact_controls.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/task_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _spec = LiquidPulseSpec.select;
const _frame = Duration(milliseconds: 8);

Widget _host({
  required bool active,
  bool reduceMotion = false,
  bool suppressed = false,
}) {
  return MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: AppLiquidPulse(
        active: active,
        suppressed: suppressed,
        child: const _Counter(),
      ),
    ),
  );
}

final _selectPulse = find.byWidgetPredicate(
  (w) => w is AppLiquidPulse && w.spec == LiquidPulseSpec.select,
);

Matrix4 _matrix(WidgetTester tester) => tester
    .widget<Transform>(
      find.descendant(of: _selectPulse, matching: find.byType(Transform)).first,
    )
    .transform;

double _scaleY(WidgetTester tester) => _matrix(tester).storage[5];
double _scaleX(WidgetTester tester) => _matrix(tester).storage[0];

/// Samples the vertical scale every frame until the pulse settles.
Future<List<double>> _record(WidgetTester tester) async {
  final samples = <double>[];
  for (
    var elapsed = Duration.zero;
    elapsed < _spec.compressDuration + _spec.springDuration * 3;
    elapsed += _frame
  ) {
    await tester.pump(_frame);
    samples.add(_scaleY(tester));
  }
  return samples;
}

void main() {
  _completionPulseTest();
  _resizeDotsMoveWithPillTest();

  testWidgets('rest: identity transform', (tester) async {
    await tester.pumpWidget(_host(active: true));
    expect(_scaleY(tester), 1);
    expect(_scaleX(tester), 1);
  });

  testWidgets('turning active compresses, overshoots once, then settles', (
    tester,
  ) async {
    await tester.pumpWidget(_host(active: false));
    await tester.pumpWidget(_host(active: true));
    final samples = await _record(tester);

    final lowest = samples.reduce((a, b) => a < b ? a : b);
    final highest = samples.reduce((a, b) => a > b ? a : b);
    expect(lowest, closeTo(1 - _spec.depth, .005));
    expect(highest, greaterThan(1.005), reason: 'spring must overshoot');
    expect(highest, lessThan(1 + _spec.depth), reason: 'never cartoonish');
    expect(samples.last, closeTo(1, .001));
  });

  testWidgets('complete is elastic: a clear overshoot, then one visible '
      'wobble back below rest before settling', (tester) async {
    const spec = LiquidPulseSpec.complete;
    Widget host(bool active) => Directionality(
      textDirection: TextDirection.ltr,
      child: AppLiquidPulse(
        active: active,
        spec: spec,
        child: const _Counter(),
      ),
    );
    double scaleY() => tester
        .widget<Transform>(
          find.descendant(
            of: find.byType(AppLiquidPulse),
            matching: find.byType(Transform),
          ),
        )
        .transform
        .storage[5];

    await tester.pumpWidget(host(false));
    await tester.pumpWidget(host(true));
    final samples = <double>[];
    for (var i = 0; i < 200; i++) {
      await tester.pump(_frame);
      samples.add(scaleY());
    }
    final peak = samples.indexWhere(
      (s) => s == samples.reduce((a, b) => a > b ? a : b),
    );
    expect(samples[peak], greaterThan(1.03), reason: 'visible overshoot');
    final afterPeak = samples.sublist(peak);
    expect(
      afterPeak.reduce((a, b) => a < b ? a : b),
      lessThan(.995),
      reason: 'one return wobble below rest',
    );
    await tester.pumpAndSettle();
    expect(scaleY(), 1, reason: 'lands exactly at rest');
  });

  testWidgets('horizontal axis deforms less than vertical (liquid squash)', (
    tester,
  ) async {
    await tester.pumpWidget(_host(active: false));
    await tester.pumpWidget(_host(active: true));
    await tester.pump(_spec.compressDuration);

    final dy = 1 - _scaleY(tester);
    final dx = 1 - _scaleX(tester);
    expect(dx, closeTo(dy * (1 - _spec.squash), .0001));
  });

  testWidgets('turning inactive never pulses', (tester) async {
    await tester.pumpWidget(_host(active: true));
    await tester.pumpWidget(_host(active: false));
    final samples = await _record(tester);
    expect(samples.every((s) => s == 1), isTrue);
  });

  testWidgets('reduced motion: no pulse', (tester) async {
    await tester.pumpWidget(_host(active: false, reduceMotion: true));
    await tester.pumpWidget(_host(active: true, reduceMotion: true));
    final samples = await _record(tester);
    expect(samples.every((s) => s == 1), isTrue);
  });

  testWidgets('suppressed: activation is swallowed and never pulses', (
    tester,
  ) async {
    await tester.pumpWidget(_host(active: false, suppressed: true));
    await tester.pumpWidget(_host(active: true, suppressed: true));
    final samples = await _record(tester);
    expect(samples.every((s) => s == 1), isTrue);
  });

  testWidgets('suppressed mid-pulse: snaps straight to rest', (tester) async {
    await tester.pumpWidget(_host(active: false));
    await tester.pumpWidget(_host(active: true));
    await tester.pump(_spec.compressDuration);
    expect(_scaleY(tester), lessThan(1));
    await tester.pumpWidget(_host(active: true, suppressed: true));
    expect(_scaleY(tester), 1);
    final samples = await _record(tester);
    expect(samples.every((s) => s == 1), isTrue, reason: 'no late spring');
  });

  testWidgets('child state survives the pulse', (tester) async {
    await tester.pumpWidget(_host(active: false));
    await tester.tap(find.byType(_Counter));
    await tester.pumpWidget(_host(active: true));
    await _record(tester);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('TaskCapsuleBlock pulses its pill when selected', (tester) async {
    final task = Task.create(
      title: 'Deep work',
      scheduledAt: DateTime(2026, 9, 4, 9),
      durationMinutes: 90,
      categoryId: BuiltInCategoryIds.work,
    );
    Widget capsule({required bool selected}) => MaterialApp(
      theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
      home: Scaffold(
        body: TaskCapsuleBlock(task: task, isSelected: selected),
      ),
    );

    await tester.pumpWidget(capsule(selected: false));
    expect(tester.widget<AppLiquidPulse>(_selectPulse).active, isFalse);
    await tester.pumpWidget(capsule(selected: true));
    expect(tester.widget<AppLiquidPulse>(_selectPulse).active, isTrue);
    await tester.pump(_spec.compressDuration);
    expect(_scaleY(tester), lessThan(1));
    await tester.pumpAndSettle();
    expect(_scaleY(tester), 1);
  });
}

void _resizeDotsMoveWithPillTest() {
  testWidgets('selected in Edit: the resize dots and rings bounce with the '
      'pill, pivoting on the pill centre', (tester) async {
    final task = Task.create(
      title: 'Deep work',
      scheduledAt: DateTime(2026, 9, 4, 9),
      durationMinutes: 90,
      categoryId: BuiltInCategoryIds.work,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
        home: Scaffold(
          body: TaskCapsuleBlock(
            task: task,
            isSelected: true,
            editModeEnabled: true,
            onResizeEnd: (_) {},
            onResizeTopEnd: (_) {},
          ),
        ),
      ),
    );

    expect(
      find.descendant(
        of: _selectPulse,
        matching: find.byType(TaskCompactResizeCell),
      ),
      findsNWidgets(2),
      reason: 'dots inside the pulse move with the pill, not float',
    );
    final theme = AmbleTheme.light;
    final pulse = tester.widget<AppLiquidPulse>(_selectPulse);
    final hitWidth = theme.sizeTaskBadge > theme.spacingMinTapTarget
        ? theme.sizeTaskBadge
        : theme.spacingMinTapTarget;
    expect(
      pulse.alignment,
      Alignment(theme.sizeTaskBadge / hitWidth - 1, 0),
      reason: 'pivot on the pill, not the wider hit box',
    );
  });
}

void _completionPulseTest() {
  testWidgets('TaskCapsuleBlock pulses with the complete spec on completion', (
    tester,
  ) async {
    final pending = Task.create(
      title: 'Deep work',
      scheduledAt: DateTime(2026, 9, 4, 9),
      durationMinutes: 90,
      categoryId: BuiltInCategoryIds.work,
    );
    Widget capsule(Task task) => MaterialApp(
      theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
      home: Scaffold(body: TaskCapsuleBlock(task: task)),
    );
    final completionPulse = find.byWidgetPredicate(
      (w) => w is AppLiquidPulse && w.spec == LiquidPulseSpec.complete,
    );

    await tester.pumpWidget(capsule(pending));
    expect(tester.widget<AppLiquidPulse>(completionPulse).active, isFalse);

    final done = pending..status = TaskStatus.completed;
    await tester.pumpWidget(capsule(done));
    expect(tester.widget<AppLiquidPulse>(completionPulse).active, isTrue);
    await tester.pump(LiquidPulseSpec.complete.compressDuration);
    final scaleY = tester
        .widget<Transform>(
          find
              .descendant(of: completionPulse, matching: find.byType(Transform))
              .first,
        )
        .transform
        .storage[5];
    expect(scaleY, closeTo(1 - LiquidPulseSpec.complete.depth, .005));
    await tester.pumpAndSettle();
  });
}

class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  var _count = 0;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => setState(() => _count++),
    child: SizedBox(width: 40, height: 80, child: Text('$_count')),
  );
}
