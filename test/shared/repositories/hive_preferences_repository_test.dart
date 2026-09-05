import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/shared/models/app_theme_mode.dart';
import 'package:amble/shared/models/task_size.dart';
import 'package:amble/shared/repositories/hive_preferences_repository.dart';
import 'package:amble/shared/repositories/preferences_repository.dart';

void main() {
  late Box<dynamic> box;
  late HivePreferencesRepository repository;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_preferences');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapters();
    }
    box = await Hive.openBox<dynamic>(
      'test_prefs_${DateTime.now().microsecondsSinceEpoch}',
    );
    repository = HivePreferencesRepository(box);
  });

  tearDown(() async {
    await box.deleteFromDisk();
  });

  test('getValue returns null for a key that was never set', () {
    expect(repository.getValue<String>('never-set'), isNull);
  });

  test('setValue persists and getValue retrieves it', () async {
    await repository.setValue('greeting', 'hello');
    expect(repository.getValue<String>('greeting'), 'hello');
  });

  test('setValue overwrites an existing key rather than duplicating', () async {
    await repository.setValue('greeting', 'hello');
    await repository.setValue('greeting', 'goodbye');

    expect(repository.getValue<String>('greeting'), 'goodbye');
    expect(repository.keys().where((k) => k == 'greeting'), hasLength(1));
  });

  test('removeValue deletes the key', () async {
    await repository.setValue('temporary', 42);
    await repository.removeValue('temporary');

    expect(repository.getValue<int>('temporary'), isNull);
  });

  test('keys lists every stored key', () async {
    await repository.setValue('a', 1);
    await repository.setValue('b', 2);

    expect(repository.keys()..sort(), ['a', 'b']);
  });

  test('the store is generic — it holds mixed primitive types', () async {
    await repository.setValue('aString', 'text');
    await repository.setValue('anInt', 7);
    await repository.setValue('aBool', true);
    await repository.setValue('aDouble', 1.5);

    expect(repository.getValue<String>('aString'), 'text');
    expect(repository.getValue<int>('anInt'), 7);
    expect(repository.getValue<bool>('aBool'), isTrue);
    expect(repository.getValue<double>('aDouble'), 1.5);
  });

  test('an adapter-backed enum round-trips', () async {
    // Theme mode is the first real consumer, and it's a Hive-adapter type
    // rather than a primitive — so this proves the generic store handles
    // registered types too, not just primitives.
    await repository.setValue(PreferenceKeys.themeMode, AppThemeMode.dark);

    expect(
      repository.getValue<AppThemeMode>(PreferenceKeys.themeMode),
      AppThemeMode.dark,
    );
  });

  test('TaskSize (a second, independently-registered adapter enum) also '
      'round-trips — confirms its own Hive adapter registration, not just '
      'the generic mechanism AppThemeMode already proves', () async {
    await repository.setValue(PreferenceKeys.taskSize, TaskSize.lg);

    expect(repository.getValue<TaskSize>(PreferenceKeys.taskSize), TaskSize.lg);
  });

  test('a value stored under a different type reads as null rather than '
      'throwing — a changed preference schema must not break launch', () async {
    await repository.setValue('themeish', 'not-an-enum');

    expect(repository.getValue<AppThemeMode>('themeish'), isNull);
  });
}
