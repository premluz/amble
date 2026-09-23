import 'package:flutter_test/flutter_test.dart';
import 'package:amble/shared/models/section.dart';

void main() {
  test('Section.create generates a unique client-side UUID', () {
    final a = Section.create(name: 'Errands');
    final b = Section.create(name: 'Errands');

    expect(a.id, isNotEmpty);
    expect(a.id, isNot(equals(b.id)));
  });

  test('Section.create defaults schemaVersion to 1', () {
    final section = Section.create(name: 'Projects');

    expect(section.schemaVersion, 1);
  });

  test('toJson -> fromJson round-trips a section', () {
    final section = Section.create(name: 'Groceries');

    final restored = Section.fromJson(section.toJson());

    expect(restored.id, section.id);
    expect(restored.name, section.name);
    expect(restored.schemaVersion, section.schemaVersion);
  });

  test('fromJson throws FormatException for a missing id', () {
    final json = Section.create(name: 'x').toJson()..remove('id');

    expect(() => Section.fromJson(json), throwsFormatException);
  });

  test('fromJson throws FormatException for a missing name', () {
    final json = Section.create(name: 'x').toJson()..remove('name');

    expect(() => Section.fromJson(json), throwsFormatException);
  });

  test('fromJson throws FormatException for a missing schemaVersion', () {
    final json = Section.create(name: 'x').toJson()..remove('schemaVersion');

    expect(() => Section.fromJson(json), throwsFormatException);
  });
}
