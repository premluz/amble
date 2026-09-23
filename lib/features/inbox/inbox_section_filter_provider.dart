import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'inbox_section_filter_provider.g.dart';

/// Which tab of the Inbox's own Section row is currently selected — "All"
/// (every task, the default), "Unfiled" (no [Section] assigned), or one
/// real [Section]'s id. Screen-local UI state, same precedent as
/// [DateAccordionExpanded] (`timeline/date_accordion_expanded_provider
/// .dart`) — not `shared/providers/`, since nothing outside the Inbox
/// screen reads this.
///
/// A small sealed set rather than a bare `String?`, deliberately: `null`
/// is ALSO the natural value for "a task has no section"
/// (`Task.sectionId`), so using `null` here too would make "All" and
/// "Unfiled" indistinguishable at the type level — see
/// [InboxSectionFilter.matches].
sealed class InboxSectionFilter {
  const InboxSectionFilter();

  /// Whether [sectionId] (a task's own `Task.sectionId`) belongs under
  /// this filter.
  bool matches(String? sectionId) => switch (this) {
    InboxSectionFilterAll() => true,
    InboxSectionFilterUnfiled() => sectionId == null,
    InboxSectionFilterSection(:final id) => sectionId == id,
  };
}

class InboxSectionFilterAll extends InboxSectionFilter {
  const InboxSectionFilterAll();

  @override
  bool operator ==(Object other) => other is InboxSectionFilterAll;

  @override
  int get hashCode => (InboxSectionFilterAll).hashCode;
}

class InboxSectionFilterUnfiled extends InboxSectionFilter {
  const InboxSectionFilterUnfiled();

  @override
  bool operator ==(Object other) => other is InboxSectionFilterUnfiled;

  @override
  int get hashCode => (InboxSectionFilterUnfiled).hashCode;
}

class InboxSectionFilterSection extends InboxSectionFilter {
  const InboxSectionFilterSection(this.id);

  final String id;

  @override
  bool operator ==(Object other) =>
      other is InboxSectionFilterSection && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

@riverpod
class InboxSectionFilterState extends _$InboxSectionFilterState {
  @override
  InboxSectionFilter build() => const InboxSectionFilterAll();

  void select(InboxSectionFilter filter) => state = filter;
}
