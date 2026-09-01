import 'package:flutter_test/flutter_test.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/zone.dart';
import 'package:amble/shared/services/zone_capacity.dart';

Task _scheduledTask({required String zoneId, required int durationMinutes}) {
  final task = Task.create(
    title: 'T',
    scheduledAt: DateTime(2026, 9, 2, 9),
    durationMinutes: durationMinutes,
    categoryId: BuiltInCategoryIds.general,
  );
  task.zoneId = zoneId;
  return task;
}

void main() {
  group('calculateZoneCapacity', () {
    test('sums durations of only the tasks assigned to this zone', () {
      final zone = Zone(
        id: 'z1',
        title: 'Morning ritual',
        startMinutes: 420,
        endMinutes: 480,
      );
      final tasks = [
        _scheduledTask(zoneId: 'z1', durationMinutes: 20),
        _scheduledTask(zoneId: 'z1', durationMinutes: 15),
        _scheduledTask(zoneId: 'other-zone', durationMinutes: 100),
      ];

      final capacity = calculateZoneCapacity(zone: zone, tasks: tasks);

      expect(capacity.assignedMinutes, 35);
      expect(capacity.capacityMinutes, 60);
      expect(capacity.remainingMinutes, 25);
      expect(capacity.isOverCapacity, isFalse);
    });

    test('a zone-only task with no scheduledAt contributes nothing', () {
      final zone = Zone(id: 'z1', title: 'Z', startMinutes: 0, endMinutes: 60);
      final unscheduled = Task.captured(title: 'Someday');
      unscheduled.zoneId = 'z1';

      final capacity = calculateZoneCapacity(zone: zone, tasks: [unscheduled]);

      expect(capacity.assignedMinutes, 0);
    });

    test('isOverCapacity is true once assigned minutes exceed the zone '
        'duration', () {
      final zone = Zone(id: 'z1', title: 'Z', startMinutes: 0, endMinutes: 30);
      final tasks = [_scheduledTask(zoneId: 'z1', durationMinutes: 45)];

      final capacity = calculateZoneCapacity(zone: zone, tasks: tasks);

      expect(capacity.isOverCapacity, isTrue);
      expect(capacity.remainingMinutes, -15);
    });

    test('no assigned tasks means zero assigned minutes and full remaining '
        'capacity', () {
      final zone = Zone(id: 'z1', title: 'Z', startMinutes: 0, endMinutes: 60);

      final capacity = calculateZoneCapacity(zone: zone, tasks: []);

      expect(capacity.assignedMinutes, 0);
      expect(capacity.remainingMinutes, 60);
      expect(capacity.isOverCapacity, isFalse);
    });
  });
}
