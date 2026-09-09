import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amble/features/timeline/edit_selection_provider.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() => container.dispose());

  group('EditSelection', () {
    test('starts empty', () {
      expect(container.read(editSelectionProvider), isEmpty);
    });

    test(
      'toggle adds an unselected id and removes an already-selected one',
      () {
        final notifier = container.read(editSelectionProvider.notifier);

        notifier.toggle('a');
        expect(container.read(editSelectionProvider), {'a'});

        notifier.toggle('b');
        expect(container.read(editSelectionProvider), {'a', 'b'});

        notifier.toggle('a');
        expect(container.read(editSelectionProvider), {'b'});
      },
    );

    test('clear empties the selection', () {
      final notifier = container.read(editSelectionProvider.notifier);
      notifier.toggle('a');
      notifier.toggle('b');

      notifier.clear();

      expect(container.read(editSelectionProvider), isEmpty);
    });

    test('clear on an already-empty selection is a no-op, not a new '
        'identical empty set — listeners should not see a spurious update', () {
      final seen = <Set<String>>[];
      container.listen<Set<String>>(
        editSelectionProvider,
        (previous, next) => seen.add(next),
      );

      container.read(editSelectionProvider.notifier).clear();

      expect(seen, isEmpty);
    });
  });

  group('EditGroupGestureState', () {
    test('starts null', () {
      expect(container.read(editGroupGestureStateProvider), isNull);
    });

    test('update stores and clears the live gesture', () {
      final notifier = container.read(editGroupGestureStateProvider.notifier);

      notifier.update(
        const EditGroupGesture(
          kind: EditGroupGestureKind.move,
          deltaPixels: 42,
        ),
      );
      final stored = container.read(editGroupGestureStateProvider);
      expect(stored?.kind, EditGroupGestureKind.move);
      expect(stored?.deltaPixels, 42);

      notifier.update(null);
      expect(container.read(editGroupGestureStateProvider), isNull);
    });
  });
}
