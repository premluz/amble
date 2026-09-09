import 'package:flutter/material.dart' show Color;

import 'scheduled_block.dart';

// Deliberately no @immutable annotation — `hive_ce_generator` scans every
// file for its own annotations and fails to resolve @immutable's import on
// this plain (non-Hive) class. Every field below is already `final`, which
// is the actual guarantee that matters; the annotation was only cosmetic.

/// A read-only, non-persisted view of one event on an external (device)
/// calendar — Feature 1 of CONSTITUTION.md's "Calendar" section.
///
/// Deliberately NOT a [Task], NOT a Hive object, and NEVER stored in any
/// repository: fetched fresh from the device each time the Timeline
/// loads/refreshes for the visible day(s), and discarded once that fetch's
/// result has been rendered. Persisting these would mean Amble owns a
/// stale, potentially-diverging copy of data it doesn't control — the
/// device calendar is always the single source of truth for its own
/// events, and Amble's job here is strictly "display what's there right
/// now," never "remember what was there."
final class ExternalCalendarEvent implements ScheduledBlock {
  const ExternalCalendarEvent({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    required this.sourceCalendarId,
    this.sourceCalendarName,
    this.sourceCalendarColor,
  });

  /// The device calendar's own event id. Only ever used to key a widget or
  /// de-duplicate within one fetch — never written back anywhere.
  @override
  final String id;

  final String title;
  final DateTime start;
  final DateTime end;

  /// [ScheduledBlock] conformance — see that interface's own doc comment
  /// for why the Timeline's shared lane/cluster layout reads through
  /// these rather than [start]/[end] directly.
  @override
  DateTime get scheduledStart => start;

  @override
  DateTime get scheduledEnd => end;

  /// The device calendar this event came from — always present, since
  /// every fetch is scoped to a specific calendar id (see
  /// `ExternalCalendarService.fetchEvents`).
  final String sourceCalendarId;

  /// Display-only; null if the device calendar had no name (rare, but the
  /// `device_calendar` plugin's own [Calendar.name] is nullable).
  final String? sourceCalendarName;

  /// Display-only; null if the device calendar had no color, or the
  /// plugin's raw ARGB int failed to parse into a [Color].
  final Color? sourceCalendarColor;
}
