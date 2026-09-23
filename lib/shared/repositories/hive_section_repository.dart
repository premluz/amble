import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../models/section.dart';
import 'section_repository.dart';

class HiveSectionRepository implements SectionRepository {
  HiveSectionRepository(this._box);

  final Box<Section> _box;

  @override
  List<Section> getSections() => _box.values.toList();

  @override
  Section? getSectionById(String id) => _box.get(id);

  @override
  Future<void> saveSection(Section section) => _box.put(section.id, section);

  @override
  Future<void> deleteSection(String id) => _box.delete(id);
}
