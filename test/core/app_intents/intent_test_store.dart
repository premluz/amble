import 'package:amble/shared/providers/preferences_providers.dart';
import 'package:amble/shared/providers/purchases_providers.dart';
import 'package:amble/shared/providers/zone_facet_providers.dart';
import 'package:amble/shared/repositories/hive_preferences_repository.dart';
import 'package:amble/shared/repositories/preferences_repository.dart';

import '../../support/memory_zone_repositories.dart';

import 'dart:io';

import 'package:amble/hive_registrar.g.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/zone.dart';
import 'package:amble/shared/providers/category_providers.dart';
import 'package:amble/shared/providers/notification_providers.dart';
import 'package:amble/shared/providers/task_providers.dart';
import 'package:amble/shared/providers/zone_providers.dart';
import 'package:amble/shared/repositories/hive_category_repository.dart';
import 'package:amble/shared/repositories/hive_task_repository.dart';
import 'package:amble/shared/repositories/hive_zone_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive_ce.dart';

import '../../support/fake_notification_service.dart';

class IntentTestStore {
  late Directory directory;
  late Box<Task> tasks;
  late Box<Zone> zones;
  late Box<Category> categories;
  late Box<dynamic> preferences;
  late ProviderContainer container;

  /// [installDate]/[isPantaPro] default to null/false — meaning no
  /// `installDate` is ever written to [preferences], and
  /// `daysSinceInstallProvider` reads it as "day zero" (trial active).
  /// Every existing caller of this store gets that same untouched
  /// behavior; only a test deliberately exercising the trial gate
  /// (`app_intent_service_test.dart`'s own trial-gate group) passes a
  /// real [installDate].
  Future<void> open({DateTime? installDate, bool isPantaPro = false}) async {
    directory = await Directory.systemTemp.createTemp('amble_intent_test_');
    Hive.init(directory.path);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapters();
    tasks = await Hive.openBox<Task>('tasks');
    zones = await Hive.openBox<Zone>('zones');
    categories = await Hive.openBox<Category>('categories');
    preferences = await Hive.openBox<dynamic>('preferences');
    if (installDate != null) {
      await preferences.put(
        PreferenceKeys.installDate,
        installDate.toIso8601String(),
      );
    }
    container = ProviderContainer(
      overrides: [
        zoneFacetRepositoryProvider.overrideWithValue(
          MemoryZoneFacetRepository(),
        ),
        taskRepositoryProvider.overrideWithValue(HiveTaskRepository(tasks)),
        zoneRepositoryProvider.overrideWithValue(HiveZoneRepository(zones)),
        categoryRepositoryProvider.overrideWithValue(
          HiveCategoryRepository(categories),
        ),
        notificationServiceProvider.overrideWithValue(
          FakeNotificationService(),
        ),
        preferencesRepositoryProvider.overrideWithValue(
          HivePreferencesRepository(preferences),
        ),
        isPantaProProvider.overrideWithValue(isPantaPro),
      ],
    );
  }

  Future<void> close() async {
    container.dispose();
    await tasks.close();
    await zones.close();
    await categories.close();
    await preferences.close();
    await directory.delete(recursive: true);
  }
}
