import '../models/section.dart';

/// Persistence interface for [Section], mirroring [CategoryRepository]'s
/// shape. UI and state never call Hive directly — see CONSTITUTION.md's
/// access-pattern rule.
abstract class SectionRepository {
  List<Section> getSections();
  Section? getSectionById(String id);
  Future<void> saveSection(Section section);
  Future<void> deleteSection(String id);
}
