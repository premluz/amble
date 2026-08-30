import 'package:flutter/material.dart' show ThemeMode;
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/app_theme_mode.dart';
import '../repositories/hive_preferences_repository.dart';
import '../repositories/preferences_repository.dart';

part 'preferences_providers.g.dart';

const preferencesBoxName = 'preferences';

@Riverpod(keepAlive: true)
PreferencesRepository preferencesRepository(Ref ref) {
  final box = Hive.box<dynamic>(preferencesBoxName);
  return HivePreferencesRepository(box);
}

/// The app's theme mode, persisted across launches.
///
/// `keepAlive: true` per the Phase 1 decision in docs/DECISIONS.md — this
/// is session-scoped app state read by the root `MaterialApp`, and
/// `autoDispose` caused a real bug where a notifier's own write could be
/// torn down mid-flight. Same reasoning applies here, and more strongly:
/// the root widget is the only listener, so a screen-scoped provider would
/// be wrong by construction.
///
/// Defaults to [AppThemeMode.system] when nothing is stored — a fresh
/// install follows the OS rather than picking a side.
@Riverpod(keepAlive: true)
class ThemeModeSetting extends _$ThemeModeSetting {
  @override
  AppThemeMode build() {
    return ref
            .read(preferencesRepositoryProvider)
            .getValue<AppThemeMode>(PreferenceKeys.themeMode) ??
        AppThemeMode.system;
  }

  Future<void> set(AppThemeMode mode) async {
    await ref
        .read(preferencesRepositoryProvider)
        .setValue(PreferenceKeys.themeMode, mode);
    state = mode;
  }
}

/// Whether the first-launch splash/carousel has already been shown.
///
/// `keepAlive: true` for the same reason as [ThemeModeSetting] — this is
/// read once by the root `MaterialApp` to decide its `home:`, not
/// screen-scoped state. Defaults to `false` (unseen) when nothing is
/// stored, i.e. every fresh install.
@Riverpod(keepAlive: true)
class HasSeenSplash extends _$HasSeenSplash {
  @override
  bool build() {
    return ref
            .read(preferencesRepositoryProvider)
            .getValue<bool>(PreferenceKeys.hasSeenSplash) ??
        false;
  }

  Future<void> markSeen() async {
    await ref
        .read(preferencesRepositoryProvider)
        .setValue(PreferenceKeys.hasSeenSplash, true);
    state = true;
  }

  /// Debug-only reset so the splash can be re-triggered for screenshots or
  /// manual testing without reinstalling the app or clearing app data.
  /// Never exposed outside a `kDebugMode` gate — see the Settings screen's
  /// "Developer" section.
  Future<void> reset() async {
    await ref
        .read(preferencesRepositoryProvider)
        .setValue(PreferenceKeys.hasSeenSplash, false);
    state = false;
  }
}

/// Whether creating/moving a task into a slot that overlaps an existing task
/// is blocked (reject-and-snap-back) rather than allowed side by side.
///
/// `keepAlive: true` for the same reason as [ThemeModeSetting]/
/// [HasSeenSplash] — read by the interactive create/edit/drag flows, not
/// screen-scoped state. Unlike those two, this **defaults to true** when
/// nothing is stored: this is a deliberate, confirmed reversal of the
/// previous "overlaps always allowed" default (see docs/DECISIONS.md, post-
/// Phase 9 "Drag shows live start/end times" entry, and the opt-out toggle
/// added after it) — a fresh install should get the stricter behavior
/// unless the user turns it off.
@Riverpod(keepAlive: true)
class PreventOverlappingTasksSetting extends _$PreventOverlappingTasksSetting {
  @override
  bool build() {
    return ref
            .read(preferencesRepositoryProvider)
            .getValue<bool>(PreferenceKeys.preventOverlappingTasks) ??
        true;
  }

  Future<void> set(bool value) async {
    await ref
        .read(preferencesRepositoryProvider)
        .setValue(PreferenceKeys.preventOverlappingTasks, value);
    state = value;
  }
}

/// Whether the day view's left-side hour gutter (the grid of clock-hour
/// ticks) is shown.
///
/// `keepAlive: true` for the same reason as the other settings above — read
/// by the Timeline screen, not screen-scoped state. Defaults to **true**
/// when nothing is stored, so a fresh install keeps the existing gutter
/// rather than silently hiding it.
@Riverpod(keepAlive: true)
class ShowHourLabelsSetting extends _$ShowHourLabelsSetting {
  @override
  bool build() {
    return ref
            .read(preferencesRepositoryProvider)
            .getValue<bool>(PreferenceKeys.showHourLabels) ??
        true;
  }

  Future<void> set(bool value) async {
    await ref
        .read(preferencesRepositoryProvider)
        .setValue(PreferenceKeys.showHourLabels, value);
    state = value;
  }
}

/// Maps the persisted [AppThemeMode] onto Flutter's own [ThemeMode].
///
/// Kept as the single translation point between our stored enum and the
/// framework's, so the storage format stays independent of Flutter's
/// declaration order (see [AppThemeMode]'s doc comment).
ThemeMode toFlutterThemeMode(AppThemeMode mode) => switch (mode) {
  AppThemeMode.system => ThemeMode.system,
  AppThemeMode.light => ThemeMode.light,
  AppThemeMode.dark => ThemeMode.dark,
};
