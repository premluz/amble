/// Groups ids into runs whose slots overlap one another, directly or through
/// a chain (A overlaps B, B overlaps C → one run), using the half-open
/// convention the rest of the scheduling code uses: back-to-back is not an
/// overlap. Runs come back in start order, members in start order.
List<List<String>> overlapRuns(Map<String, (DateTime, DateTime)> slots) {
  final ids = slots.keys.toList()
    ..sort((a, b) => slots[a]!.$1.compareTo(slots[b]!.$1));
  final runs = <List<String>>[];
  DateTime? runEnd;
  for (final id in ids) {
    final (start, end) = slots[id]!;
    final open = runEnd;
    if (open != null && start.isBefore(open)) {
      runs.last.add(id);
      if (end.isAfter(open)) runEnd = end;
    } else {
      runs.add([id]);
      runEnd = end;
    }
  }
  return runs;
}
