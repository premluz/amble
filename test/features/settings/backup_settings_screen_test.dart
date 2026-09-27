import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_button.dart';
import 'package:amble/features/settings/backup_settings_screen.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/providers/category_providers.dart';
import 'package:amble/shared/providers/purchases_providers.dart';
import 'package:amble/shared/providers/task_providers.dart';
import 'package:amble/shared/providers/zone_facet_providers.dart';
import 'package:amble/shared/providers/zone_providers.dart';
import 'package:amble/shared/repositories/hive_category_repository.dart';
import 'package:amble/shared/repositories/hive_task_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';

import '../../support/memory_zone_repositories.dart';
import '../../support/seeded_category_box.dart';

/// Requested directly: "No export/import only available when panta
/// purchased, not available during trial" — Export/Import require an
/// active `panta_pro` entitlement outright, with no free trial window at
/// all. Covers the locked/unlocked button states and copy; the actual
/// paywall-presentation call (`PurchasesRepository.presentPaywallIfNeeded`)
/// is exercised by `RevenueCatConfig.isAvailable` being false in this test
/// binary (no `--dart-define` API keys), matching real behavior for any
/// build/test run without them — `_ensureUnlocked` shows its own
/// "Purchases are not available" message rather than reaching the SDK.
void main() {
  late Box<Task> taskBox;
  late Box<Category> categoryBox;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_backup_settings');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapters();
    }
    final stamp = DateTime.now().microsecondsSinceEpoch;
    taskBox = await Hive.openBox<Task>('test_tasks_$stamp');
    categoryBox = await openSeededCategoryBox('test_categories_$stamp');
  });

  tearDown(() async {
    await taskBox.close();
    await categoryBox.close();
  });

  Future<void> pumpScreen(WidgetTester tester, {required bool isPro}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskRepositoryProvider.overrideWithValue(HiveTaskRepository(taskBox)),
          categoryRepositoryProvider.overrideWithValue(
            HiveCategoryRepository(categoryBox),
          ),
          zoneRepositoryProvider.overrideWithValue(MemoryZoneRepository()),
          zoneFacetRepositoryProvider.overrideWithValue(
            MemoryZoneFacetRepository(),
          ),
          isPantaProProvider.overrideWithValue(isPro),
        ],
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
          home: const BackupSettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'without panta_pro, Export and Import show as locked and say so',
    (tester) async {
      await pumpScreen(tester, isPro: false);

      expect(find.text('Export backup (Unlock)'), findsOneWidget);
      expect(find.text('Import backup (Unlock)'), findsOneWidget);
      expect(find.text('Requires Panta Pro.'), findsOneWidget);
    },
  );

  testWidgets('with panta_pro active, Export and Import show unlocked', (
    tester,
  ) async {
    await pumpScreen(tester, isPro: true);

    expect(find.text('Export backup'), findsOneWidget);
    expect(find.text('Import backup'), findsOneWidget);
    expect(find.text('Requires Panta Pro.'), findsNothing);
  });

  testWidgets(
    'tapping Export while locked shows the unavailable message instead of '
    'exporting — this test binary has no RevenueCat API keys, so the '
    'paywall itself cannot be presented, matching real behavior for any '
    'unconfigured build',
    (tester) async {
      await pumpScreen(tester, isPro: false);

      await tester.tap(
        find.widgetWithText(AppButton, 'Export backup (Unlock)'),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Purchases are not available'),
        findsOneWidget,
      );
    },
  );
}
