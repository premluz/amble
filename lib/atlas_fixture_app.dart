import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/inbox/inbox_screen.dart';
import 'package:amble/shared/providers/category_providers.dart';
import 'package:amble/shared/providers/section_providers.dart';
import 'package:amble/shared/providers/task_providers.dart';
import 'package:amble/shared/providers/trial_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'atlas_fixture_data.dart';
import 'atlas_in_memory_repositories.dart';

class AtlasFixtureApp extends StatefulWidget {
  const AtlasFixtureApp({
    super.key,
    required this.screenId,
    required this.scenarioId,
  });

  final String screenId;
  final String scenarioId;

  @override
  State<AtlasFixtureApp> createState() => _AtlasFixtureAppState();
}

class _AtlasFixtureAppState extends State<AtlasFixtureApp> {
  late final ProviderContainer _container;

  @override
  void initState() {
    super.initState();
    _container = _createAtlasFixtureContainer(
      screenId: widget.screenId,
      scenarioId: widget.scenarioId,
    );
  }

  @override
  void dispose() {
    _container.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screen = switch (widget.screenId) {
      'inbox' => const InboxScreen(),
      _ => throw StateError(
        'Atlas Amble screen "${widget.screenId}" is not registered.',
      ),
    };

    return UncontrolledProviderScope(
      container: _container,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
        home: Scaffold(body: screen),
      ),
    );
  }
}

ProviderContainer _createAtlasFixtureContainer({
  required String screenId,
  required String scenarioId,
  DateTime? now,
}) {
  if (screenId != 'inbox') {
    throw ArgumentError.value(
      screenId,
      'screenId',
      'Unsupported Atlas screen.',
    );
  }
  if (scenarioId != atlasInboxScenarioId) {
    throw ArgumentError.value(
      scenarioId,
      'scenarioId',
      'Unsupported Atlas Inbox fixture scenario.',
    );
  }

  final fixture = AtlasInboxFixtureData.seeded(now: now);
  return ProviderContainer(
    overrides: [
      taskRepositoryProvider.overrideWithValue(
        AtlasMemoryTaskRepository(fixture.tasks),
      ),
      sectionRepositoryProvider.overrideWithValue(
        AtlasMemorySectionRepository(fixture.sections),
      ),
      categoryRepositoryProvider.overrideWithValue(
        AtlasMemoryCategoryRepository(fixture.categories),
      ),
      canCreateTaskProvider.overrideWithValue(true),
    ],
  );
}
