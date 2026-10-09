import 'dart:async';
import 'dart:io' show pid;

import 'package:amble/shared/providers/series_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:timezone/data/latest.dart' as tz_data;

/// Runs around every test file (Flutter's per-directory test config).
///
/// The Timeline's day list always reads the series model, whose
/// repositories default to the real Hive boxes — so every test gets fresh,
/// empty series boxes, the same as a new install. Tests that need specific
/// series data override the repository providers instead.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  tz_data.initializeTimeZones();
  // Test files run in parallel processes; each needs its own directory or
  // their same-named series boxes collide.
  final directory = './.dart_tool/test_hive_series_model/$pid';
  setUp(() async {
    Hive.init(directory);
    await openSeriesModelBoxes();
  });
  tearDown(deleteSeriesModelBoxes);
  await testMain();
}
