/// The minimal shape the Timeline's shared lane/cluster layout needs from
/// anything it positions in time — implemented by both [Task] and
/// [ExternalCalendarEvent].
///
/// **New 2026-09-07** (confirmed directly — "the imported tasks should
/// also stack in the same way as native tasks... otherwise exactly the
/// same, with different styling"): `layoutOverlappingTasks`/
/// `detectOverlapClusters` (the two algorithms deciding which tasks share
/// a lane, and which runs collapse into an aggregate
/// `OverlapClusterBlock`) used to be hard-typed to [Task] alone, and an
/// imported [ExternalCalendarEvent] positioned itself independently by
/// real time-to-pixel math with no lane/cluster awareness at all — the
/// two could visually overlap. Generalizing those two algorithms to this
/// interface, rather than either duplicating them or converting events
/// into fake [Task] objects, is what lets an event now occupy a lane next
/// to real tasks and be pulled into a cluster's flat row list alongside
/// them.
///
/// Deliberately narrow: only what POSITIONING needs (id + time window),
/// nothing about status, category, or completion — those stay real-Task-
/// only concerns the render layer branches on per slot (see
/// `timeline_screen.dart`'s own `TaskLayoutSlot.block` dispatch), not
/// something this shared layout layer has any business computing or
/// caring about. An event can share a LANE with a task; it never becomes
/// editable, draggable, or renamable by way of implementing this.
abstract interface class ScheduledBlock {
  String get id;
  DateTime get scheduledStart;
  DateTime get scheduledEnd;
}
