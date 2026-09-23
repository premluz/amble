import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/shared/models/section.dart';
import 'package:amble/shared/repositories/hive_section_repository.dart';

void main() {
  late Box<Section> box;
  late HiveSectionRepository repository;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_sections');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapters();
    }
    box = await Hive.openBox<Section>(
      'test_sections_${DateTime.now().microsecondsSinceEpoch}',
    );
    repository = HiveSectionRepository(box);
  });

  tearDown(() async {
    await box.deleteFromDisk();
  });

  test('saveSection persists and getSectionById retrieves it', () async {
    final section = Section.create(name: 'Errands');

    await repository.saveSection(section);

    final fetched = repository.getSectionById(section.id);
    expect(fetched, isNotNull);
    expect(fetched!.name, 'Errands');
    expect(fetched.schemaVersion, 1);
  });

  test('getSectionById returns null for an unknown id', () {
    expect(repository.getSectionById('never-saved'), isNull);
  });

  test('getSections returns all saved sections', () async {
    await repository.saveSection(Section.create(name: 'A'));
    await repository.saveSection(Section.create(name: 'B'));

    expect(repository.getSections().length, 2);
  });

  test('saving an existing id updates rather than duplicating', () async {
    final section = Section.create(name: 'Original');
    await repository.saveSection(section);

    section.name = 'Edited';
    await repository.saveSection(section);

    expect(repository.getSections().length, 1);
    expect(repository.getSectionById(section.id)!.name, 'Edited');
  });

  test('deleteSection removes the row', () async {
    final section = Section.create(name: 'Groceries');
    await repository.saveSection(section);
    expect(repository.getSectionById(section.id), isNotNull);

    await repository.deleteSection(section.id);

    expect(repository.getSectionById(section.id), isNull);
  });

  test('deleteSection on an unknown id is a no-op, not an error', () async {
    await repository.deleteSection('never-saved');
    expect(repository.getSections(), isEmpty);
  });
}
