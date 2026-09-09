import 'package:amble/core/app_intents/intent_task_queries.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 24, 8);
  Task task(String title, DateTime at) => Task.create(
    title: title,
    scheduledAt: at,
    durationMinutes: 30,
    categoryId: BuiltInCategoryIds.general,
  );

  test('bounds search by calendar days, excluding history and Inbox', () {
    final today = task('Today', DateTime(2026, 10, 24));
    final last = task('Last', DateTime(2026, 11, 6, 23, 59));
    expect(
      intentScheduledTasks([
        task('History', DateTime(2026, 10, 23, 23, 59)),
        Task.captured(title: 'Note'),
        task('Outside', DateTime(2026, 11, 7)),
        last,
        today,
      ], now),
      [today, last],
    );
  });

  test('exact case-insensitive title wins over every partial match', () {
    final exact = task('Walk', now);
    final partial = task('Walk the dog', now);
    expect(matchIntentTasks([partial, exact], ' WALK '), [exact]);
  });

  test('duplicate exact titles remain distinct choices by id and date', () {
    final first = task('Walk', now);
    final second = task('Walk', now.add(const Duration(days: 1)));
    expect(matchIntentTasks([first, second], 'walk'), [first, second]);
  });

  test(
    'substring and all-token fallback return all matches, never first-only',
    () {
      final dog = task('Walk the dog', now);
      final store = task('Walk to store', now);
      final unrelated = task('Call Sam', now);
      expect(matchIntentTasks([dog, store, unrelated], 'walk'), [dog, store]);
      expect(matchIntentTasks([dog, store], 'dog walk'), [dog]);
      expect(matchIntentTasks([dog, store], 'walk cat'), isEmpty);
      expect(matchIntentTasks([dog], '   '), isEmpty);
    },
  );

  test('Unicode titles support case-insensitive token matching', () {
    final visit = task('Café avec Zoé', now);
    expect(matchIntentTasks([visit], 'ZOÉ CAFÉ'), [visit]);
  });

  test('summary is built only from today and chooses next chronologically', () {
    expect(
      buildIntentDaySummary([
        task('Tomorrow', DateTime(2026, 10, 25, 7)),
        task('Lunch', DateTime(2026, 10, 24, 12, 30)),
        Task.captured(title: 'Note'),
        task('Walk', DateTime(2026, 10, 24, 9)),
        task('Breakfast', DateTime(2026, 10, 24, 7)),
      ], now),
      '3 tasks today, next is Walk at 9am.',
    );
  });

  test('empty, singular, and all-past summaries have fixed templates', () {
    expect(buildIntentDaySummary([], now), 'No tasks scheduled today.');
    expect(
      buildIntentDaySummary([task('Walk', now)], now),
      '1 task today, next is Walk at 8am.',
    );
    expect(
      buildIntentDaySummary([task('Walk', DateTime(2026, 10, 24, 7))], now),
      '1 task today, starting with Walk at 7am.',
    );
    expect(intentTimeLabel(DateTime(2026, 10, 24)), '12am');
    expect(intentTimeLabel(DateTime(2026, 10, 24, 12)), '12pm');
  });
}
