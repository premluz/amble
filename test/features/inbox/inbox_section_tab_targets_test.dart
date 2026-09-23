import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amble/features/inbox/inbox_section_filter_provider.dart';
import 'package:amble/features/inbox/inbox_section_tabs.dart';

/// `InboxSectionTabTargets.hitTest` is the geometry `_DraggableInboxRow`
/// (`inbox_screen.dart`) checks a live drag's pointer position against to
/// decide which Section tab it's hovering — the actual novel logic this
/// feature adds (mirroring `isInsideDeleteTarget`'s single-target
/// geometry, generalized to N tabs). Covered directly here, independent
/// of any gesture simulation, since a full long-press-then-drag
/// `WidgetTester` simulation proved unreliable in this harness (see
/// `inbox_sections_test.dart`'s own remaining coverage for what that file
/// covers instead: filtering and the plain-tap-is-unaffected guard).
void main() {
  testWidgets(
    'hitTest resolves to the filter whose rendered tab contains the point',
    (tester) async {
      const all = InboxSectionFilterAll();
      const section = InboxSectionFilterSection('groceries');
      const unfiled = InboxSectionFilterUnfiled();
      final targets = InboxSectionTabTargets([all, section, unfiled]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                SizedBox(
                  key: targets.keys[all],
                  width: 50,
                  height: 50,
                  child: const Text('All'),
                ),
                SizedBox(
                  key: targets.keys[section],
                  width: 50,
                  height: 50,
                  child: const Text('Groceries'),
                ),
                SizedBox(
                  key: targets.keys[unfiled],
                  width: 50,
                  height: 50,
                  child: const Text('Unfiled'),
                ),
              ],
            ),
          ),
        ),
      );

      final groceriesCenter = tester.getCenter(find.text('Groceries'));
      expect(targets.hitTest(groceriesCenter), section);

      final unfiledCenter = tester.getCenter(find.text('Unfiled'));
      expect(targets.hitTest(unfiledCenter), unfiled);
    },
  );

  testWidgets('hitTest never matches "All" — it is not a real assignment '
      'target (see _DraggableInboxRowState.onLongPressEnd\'s own doc '
      'comment)', (tester) async {
    const all = InboxSectionFilterAll();
    final targets = InboxSectionTabTargets([all]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            key: targets.keys[all],
            width: 50,
            height: 50,
            child: const Text('All'),
          ),
        ),
      ),
    );

    final allCenter = tester.getCenter(find.text('All'));
    expect(targets.hitTest(allCenter), isNull);
  });

  testWidgets('hitTest returns null for a point outside every tab', (
    tester,
  ) async {
    const section = InboxSectionFilterSection('groceries');
    final targets = InboxSectionTabTargets([section]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              key: targets.keys[section],
              width: 50,
              height: 50,
              child: const Text('Groceries'),
            ),
          ),
        ),
      ),
    );

    expect(targets.hitTest(const Offset(700, 700)), isNull);
  });
}
