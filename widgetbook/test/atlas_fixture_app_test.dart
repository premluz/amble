import 'package:amble/atlas_fixture_app.dart';
import 'package:amble/atlas_fixture_data.dart';
import 'package:amble/atlas_in_memory_repositories.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Atlas launches the real Inbox with synthetic fixture tasks', (
    tester,
  ) async {
    await tester.pumpWidget(
      const AtlasFixtureApp(
        screenId: 'inbox',
        scenarioId: atlasInboxScenarioId,
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Review launch checklist'), findsOneWidget);
    expect(find.text('Book a dentist appointment'), findsOneWidget);
    expect(find.text('Plan a weekend walk'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('a fresh repository restores the seeded task set', () async {
    final now = DateTime(2026, 10, 9, 12);
    final fixture = AtlasInboxFixtureData.seeded(now: now);
    final first = AtlasMemoryTaskRepository(fixture.tasks);

    await first.deleteTask(AtlasInboxFixtureIds.dentistTask);
    expect(first.getTaskById(AtlasInboxFixtureIds.dentistTask), isNull);

    final freshFixture = AtlasInboxFixtureData.seeded(now: now);
    final restarted = AtlasMemoryTaskRepository(freshFixture.tasks);

    expect(
      restarted.getTaskById(AtlasInboxFixtureIds.dentistTask)?.title,
      'Book a dentist appointment',
    );
    expect(restarted.getTasks(), hasLength(3));
  });
}
