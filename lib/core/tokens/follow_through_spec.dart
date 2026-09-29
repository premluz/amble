/// Component motion tokens for follow-through: when a page slides, the key
/// items on it (tasks, tracked cards and their dots) trail the page and
/// catch up one after another, in the direction it travels, entering and
/// leaving alike. The page runs over the first [pageShare] of one timeline;
/// each item runs the same motion, delayed within the remaining tail.
class FollowThroughSpec {
  const FollowThroughSpec({
    required this.totalMs,
    required this.pageShare,
    required this.rowWeight,
    required this.nestedShare,
  }) : assert(totalMs > 0),
       assert(pageShare > 0 && pageShare < 1),
       assert(rowWeight >= 0 && rowWeight <= 1),
       assert(nestedShare >= 0 && nestedShare < 1);

  /// The whole timeline: the page's slide plus the items' tail.
  final int totalMs;

  /// Share of the timeline the page itself takes to slide.
  final double pageShare;

  /// How a top-level item's delay splits between its row (top first) and
  /// its position across the page (the edge leading the travel first).
  final double rowWeight;

  /// Share of the tail kept for items nested inside another following item
  /// (a card's dots), which trail their own card rather than the page.
  final double nestedShare;

  /// The tail every delay fits into, so every item lands by the end.
  double get tail => 1 - pageShare;

  /// [pages]' page share, as a constant for `const` curves.
  static const pagesPageShare = .6;

  static const pages = FollowThroughSpec(
    totalMs: 380,
    pageShare: pagesPageShare,
    rowWeight: .75,
    nestedShare: .3,
  );

  Duration get duration => Duration(milliseconds: totalMs);
}
