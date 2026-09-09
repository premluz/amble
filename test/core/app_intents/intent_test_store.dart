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
  late ProviderContainer container;

  Future<void> open() async {
    directory = await Directory.systemTemp.createTemp('amble_intent_test_');
    Hive.init(directory.path);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapters();
    tasks = await Hive.openBox<Task>('tasks');
    zones = await Hive.openBox<Zone>('zones');
    categories = await Hive.openBox<Category>('categories');
    container = ProviderContainer(
      overrides: [
        taskRepositoryProvider.overrideWithValue(HiveTaskRepository(tasks)),
        zoneRepositoryProvider.overrideWithValue(HiveZoneRepository(zones)),
        categoryRepositoryProvider.overrideWithValue(
          HiveCategoryRepository(categories),
        ),
        notificationServiceProvider.overrideWithValue(
          FakeNotificationService(),
        ),
      ],
    );
  }

  Future<void> close() async {
    container.dispose();
    await tasks.close();
    await zones.close();
    await categories.close();
    await directory.delete(recursive: true);
  }
}
