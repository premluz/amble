import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/shared/models/behavior_target_type.dart';
import 'package:amble/shared/models/tracked_behavior.dart';
import 'package:amble/shared/repositories/hive_tracked_behavior_repository.dart';

void main() {
  late Box<TrackedBehavior> box;
  late HiveTrackedBehaviorRepository repository;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_behaviors');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapters();
    }
    box = await Hive.openBox<TrackedBehavior>(
      'test_behaviors_${DateTime.now().microsecondsSinceEpoch}',
    );
    repository = HiveTrackedBehaviorRepository(box);
  });

  tearDown(() async {
    await box.deleteFromDisk();
  });

  test('saveBehavior persists and getBehaviorById retrieves it', () async {
    final behavior = TrackedBehavior(
      id: 'behavior-1',
      title: 'Exercise',
      targetType: BehaviorTargetType.duration,
      targetAmount: 60,
      timesPerWeek: 3,
    );

    await repository.saveBehavior(behavior);

    final fetched = repository.getBehaviorById('behavior-1');
    expect(fetched, isNotNull);
    expect(fetched!.title, 'Exercise');
    expect(fetched.targetType, BehaviorTargetType.duration);
    expect(fetched.targetAmount, 60);
    expect(fetched.timesPerWeek, 3);
    expect(fetched.schemaVersion, 1);
  });

  test('an optional minimumAmount round-trips through Hive', () async {
    await repository.saveBehavior(
      TrackedBehavior(
        id: 'with-minimum',
        title: 'Read',
        targetType: BehaviorTargetType.count,
        targetAmount: 20,
        minimumAmount: 5,
        timesPerWeek: 7,
      ),
    );

    expect(repository.getBehaviorById('with-minimum')!.minimumAmount, 5);
  });

  test('minimumAmount is genuinely optional — null round-trips', () async {
    await repository.saveBehavior(
      TrackedBehavior(
        id: 'no-minimum',
        title: 'Meditate',
        targetType: BehaviorTargetType.duration,
        targetAmount: 10,
        timesPerWeek: 5,
      ),
    );

    expect(repository.getBehaviorById('no-minimum')!.minimumAmount, isNull);
  });

  test('a binary behavior persists with a null targetAmount', () async {
    await repository.saveBehavior(
      TrackedBehavior(
        id: 'binary-1',
        title: 'Take vitamins',
        targetType: BehaviorTargetType.binary,
        timesPerWeek: 7,
      ),
    );

    final fetched = repository.getBehaviorById('binary-1')!;
    expect(fetched.targetAmount, isNull);
    expect(fetched.isBinary, isTrue);
  });

  test('getBehaviors returns all saved behaviors', () async {
    await repository.saveBehavior(
      TrackedBehavior(
        id: 'a',
        title: 'A',
        targetType: BehaviorTargetType.binary,
        timesPerWeek: 1,
      ),
    );
    await repository.saveBehavior(
      TrackedBehavior(
        id: 'b',
        title: 'B',
        targetType: BehaviorTargetType.count,
        targetAmount: 3,
        timesPerWeek: 2,
      ),
    );

    expect(repository.getBehaviors().length, 2);
  });

  test('saving an existing id updates rather than duplicating', () async {
    final behavior = TrackedBehavior(
      id: 'update-me',
      title: 'Original',
      targetType: BehaviorTargetType.duration,
      targetAmount: 30,
      timesPerWeek: 2,
    );
    await repository.saveBehavior(behavior);

    behavior.title = 'Edited';
    behavior.targetAmount = 45;
    await repository.saveBehavior(behavior);

    expect(repository.getBehaviors().length, 1);
    expect(repository.getBehaviorById('update-me')!.title, 'Edited');
    expect(repository.getBehaviorById('update-me')!.targetAmount, 45);
  });

  test('deleteBehavior removes the behavior', () async {
    await repository.saveBehavior(
      TrackedBehavior(
        id: 'to-delete',
        title: 'Gone soon',
        targetType: BehaviorTargetType.binary,
        timesPerWeek: 1,
      ),
    );

    await repository.deleteBehavior('to-delete');

    expect(repository.getBehaviorById('to-delete'), isNull);
  });

  test('getBehaviorById returns null for an unknown id', () {
    expect(repository.getBehaviorById('never-saved'), isNull);
  });

  test('TrackedBehavior.create generates a unique client-side UUID', () {
    final a = TrackedBehavior.create(
      title: 'A',
      targetType: BehaviorTargetType.binary,
      timesPerWeek: 1,
    );
    final b = TrackedBehavior.create(
      title: 'B',
      targetType: BehaviorTargetType.binary,
      timesPerWeek: 1,
    );

    expect(a.id, isNotEmpty);
    expect(a.id, isNot(equals(b.id)));
  });

  test('a non-binary behavior without a targetAmount is rejected — the '
      'constructor invariant from CONSTITUTION.md', () {
    expect(
      () => TrackedBehavior(
        id: 'invalid',
        title: 'No amount',
        targetType: BehaviorTargetType.duration,
        timesPerWeek: 3,
      ),
      throwsA(isA<AssertionError>()),
    );
  });
}
