/// A write was based on an outdated version of the stored value — another
/// caller (e.g. Siri while the UI was open) changed it first. The write is
/// rejected rather than silently overwriting the newer change
/// (docs/RECURRENCE_CONTRACT.md §12).
class StaleWriteException implements Exception {
  const StaleWriteException({
    required this.entity,
    required this.id,
    required this.storedVersion,
    required this.attemptedVersion,
  });

  final String entity;
  final String id;
  final int? storedVersion;
  final int attemptedVersion;

  @override
  String toString() =>
      'StaleWriteException: $entity $id is at version '
      '${storedVersion ?? 'none'}, write expected to produce '
      'version $attemptedVersion';
}

/// Throws [StaleWriteException] unless [attemptedVersion] is exactly one
/// past [storedVersion] (or the initial version for a new value).
void checkNextVersion({
  required String entity,
  required String id,
  required int? storedVersion,
  required int attemptedVersion,
  required int initialVersion,
}) {
  final expected = storedVersion == null ? initialVersion : storedVersion + 1;
  if (attemptedVersion != expected) {
    throw StaleWriteException(
      entity: entity,
      id: id,
      storedVersion: storedVersion,
      attemptedVersion: attemptedVersion,
    );
  }
}
