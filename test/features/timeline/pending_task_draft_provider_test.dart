import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amble/features/timeline/pending_task_draft_provider.dart';

void main() {
  test('starts null — no draft until start() is called', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(pendingTaskDraftProvider), isNull);
  });

  test('start() creates a draft with the given position/duration and a '
      'real id', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final scheduledAt = DateTime(2026, 9, 7, 9);
    container
        .read(pendingTaskDraftProvider.notifier)
        .start(scheduledAt: scheduledAt, durationMinutes: 30);

    final draft = container.read(pendingTaskDraftProvider);
    expect(draft, isNotNull);
    expect(draft!.scheduledAt, scheduledAt);
    expect(draft.durationMinutes, 30);
    expect(draft.id, isNotEmpty);
  });

  test('start() called twice produces two different ids — a fresh draft, '
      'not an update to the old one', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(pendingTaskDraftProvider.notifier);

    notifier.start(scheduledAt: DateTime(2026, 9, 7, 9), durationMinutes: 30);
    final firstId = container.read(pendingTaskDraftProvider)!.id;

    notifier.start(scheduledAt: DateTime(2026, 9, 7, 14), durationMinutes: 60);
    final secondId = container.read(pendingTaskDraftProvider)!.id;

    expect(firstId, isNot(secondId));
  });

  test('updatePosition() changes scheduledAt, keeps the same id/duration', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(pendingTaskDraftProvider.notifier);

    notifier.start(scheduledAt: DateTime(2026, 9, 7, 9), durationMinutes: 30);
    final originalId = container.read(pendingTaskDraftProvider)!.id;

    final moved = DateTime(2026, 9, 7, 10, 30);
    notifier.updatePosition(moved);

    final draft = container.read(pendingTaskDraftProvider);
    expect(draft!.scheduledAt, moved);
    expect(draft.durationMinutes, 30);
    expect(draft.id, originalId);
  });

  test('updateDuration() changes durationMinutes, keeps the same id/'
      'scheduledAt', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(pendingTaskDraftProvider.notifier);

    final scheduledAt = DateTime(2026, 9, 7, 9);
    notifier.start(scheduledAt: scheduledAt, durationMinutes: 30);
    final originalId = container.read(pendingTaskDraftProvider)!.id;

    notifier.updateDuration(90);

    final draft = container.read(pendingTaskDraftProvider);
    expect(draft!.durationMinutes, 90);
    expect(draft.scheduledAt, scheduledAt);
    expect(draft.id, originalId);
  });

  test('updatePosition()/updateDuration() are no-ops when there is no '
      'active draft', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(pendingTaskDraftProvider.notifier);

    notifier.updatePosition(DateTime(2026, 9, 7, 9));
    notifier.updateDuration(45);

    expect(container.read(pendingTaskDraftProvider), isNull);
  });

  test('clear() removes the draft entirely', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(pendingTaskDraftProvider.notifier);

    notifier.start(scheduledAt: DateTime(2026, 9, 7, 9), durationMinutes: 30);
    expect(container.read(pendingTaskDraftProvider), isNotNull);

    notifier.clear();
    expect(container.read(pendingTaskDraftProvider), isNull);
  });
}
