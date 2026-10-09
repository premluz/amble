import '../models/occurrence_alert.dart';
import '../repositories/occurrence_alert_state_repository.dart';

/// The OS side of alerts. Kept as an interface so the reconciler is
/// testable without a platform channel; the real implementation wraps
/// `NotificationService` when the recurrence model is wired in.
abstract interface class AlertScheduler {
  Future<void> schedule(OccurrenceAlert alert);
  Future<void> cancel(int notificationId);
}

/// One alert operation that failed; it is retried on the next reconcile
/// because its recorded state was left unchanged.
class AlertFailure {
  const AlertFailure(this.notificationId, this.error);
  final int notificationId;
  final Object error;

  @override
  String toString() => 'AlertFailure($notificationId): $error';
}

class ReconcileReport {
  const ReconcileReport({
    required this.scheduled,
    required this.cancelled,
    required this.failures,
  });

  final int scheduled;
  final int cancelled;

  /// Not swallowed: the caller decides how to surface these. Each one is
  /// retried automatically next time.
  final List<AlertFailure> failures;
}

/// Brings registered occurrence alerts in line with [desired] by touching
/// only what differs — never a blanket cancel. State is recorded per alert
/// only after the OS call succeeds, so a failure (or a crash midway) leaves
/// that alert to be retried by the next reconcile instead of being lost
/// (docs/RECURRENCE_CONTRACT.md §12).
class OccurrenceAlertReconciler {
  OccurrenceAlertReconciler({required this._scheduler, required this._state});

  final AlertScheduler _scheduler;
  final OccurrenceAlertStateRepository _state;

  Future<ReconcileReport> reconcile(List<OccurrenceAlert> desired) async {
    final current = _state.getAll();
    final wanted = {for (final a in desired) a.notificationId: a};
    final failures = <AlertFailure>[];
    var cancelled = 0;
    var scheduled = 0;

    for (final id in current.keys.where((id) => !wanted.containsKey(id))) {
      final error = await _attempt(() async {
        await _scheduler.cancel(id);
        await _state.remove(id);
      });
      error == null ? cancelled++ : failures.add(AlertFailure(id, error));
    }
    for (final alert in wanted.values) {
      final existing = current[alert.notificationId];
      if (existing != null && existing.sameAs(alert)) continue;
      final error = await _attempt(() async {
        if (existing != null) await _scheduler.cancel(alert.notificationId);
        await _scheduler.schedule(alert);
        await _state.put(alert);
      });
      error == null
          ? scheduled++
          : failures.add(AlertFailure(alert.notificationId, error));
    }
    return ReconcileReport(
      scheduled: scheduled,
      cancelled: cancelled,
      failures: failures,
    );
  }

  static Future<Object?> _attempt(Future<void> Function() operation) async {
    try {
      await operation();
      return null;
    } on Exception catch (error) {
      return error;
    }
  }
}
