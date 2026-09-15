import 'package:amble/hive_registrar.g.dart';
import 'package:amble/shared/models/pill_shape.dart';
import 'package:amble/shared/providers/preferences_providers.dart';
import 'package:amble/shared/repositories/hive_preferences_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';

/// Covers the "Pill shape" setting requested directly: "we have squary
/// rounded shape of pills but rounded on inbox ... let's make it
/// configurable in admin ... we need variable that controls it and
/// rounding tokens that define value. Full (circle) / Rounded / Small
/// rounding (current) ... this should affect globally."
///
/// Mirrors `TaskSizeSetting`'s own (only indirectly tested) persistence
/// contract, made explicit here since this is the first dedicated
/// provider-level test any `PreferencesRepository`-backed setting in this
/// app has.
void main() {
  late Box<dynamic> box;
  late ProviderContainer container;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_pill_shape');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapters();
    }
    box = await Hive.openBox<dynamic>(
      'test_preferences_${DateTime.now().microsecondsSinceEpoch}',
    );
    container = ProviderContainer(
      overrides: [
        preferencesRepositoryProvider.overrideWithValue(
          HivePreferencesRepository(box),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await box.deleteFromDisk();
  });

  test('defaults to PillShape.small on a fresh install — NOT a silent no-op '
      'of the pre-existing hardcoded shape, a deliberate step up (see '
      'PillShapeSetting\'s own doc comment)', () {
    expect(container.read(pillShapeSettingProvider), PillShape.small);
  });

  for (final shape in PillShape.values) {
    test('set($shape) persists and is reflected immediately by the '
        'provider', () async {
      await container.read(pillShapeSettingProvider.notifier).set(shape);

      expect(container.read(pillShapeSettingProvider), shape);
    });
  }

  test('a value set through one container is read back by a FRESH '
      'container reading the same box — genuinely persisted, not just '
      'in-memory state', () async {
    await container.read(pillShapeSettingProvider.notifier).set(PillShape.full);

    final freshContainer = ProviderContainer(
      overrides: [
        preferencesRepositoryProvider.overrideWithValue(
          HivePreferencesRepository(box),
        ),
      ],
    );
    addTearDown(freshContainer.dispose);

    expect(freshContainer.read(pillShapeSettingProvider), PillShape.full);
  });
}
