import 'package:hive_ce/hive_ce.dart';
import 'package:amble/shared/models/section.dart';

/// Opens a uniquely-named, empty [Section] box — mirrors
/// `openSeededCategoryBox`'s shape, minus any seeding: unlike [Category],
/// [Section] has no built-in rows (every Section is user-created). Widget
/// tests that render anything reading `sectionListProvider`/
/// `sectionRepositoryProvider` (any Inbox screen mount, since
/// `InboxScreen` now shows the Section tab row) need a real, open box —
/// `sectionRepositoryProvider` resolves a live `Hive.box<Section>`, not
/// something a plain provider override alone can stand in for.
Future<Box<Section>> openSectionBox(String name) => Hive.openBox<Section>(name);
