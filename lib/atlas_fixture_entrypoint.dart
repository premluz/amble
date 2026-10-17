import 'package:flutter/widgets.dart';

import 'atlas_fixture_app.dart';
import 'atlas_fixture_data.dart';

void runAtlasFixture() {
  WidgetsFlutterBinding.ensureInitialized();
  final query = Uri.base.queryParameters;
  runApp(
    AtlasFixtureApp(
      screenId: query['atlasScreen'] ?? 'inbox',
      scenarioId: query['atlasScenario'] ?? atlasInboxScenarioId,
    ),
  );
}
