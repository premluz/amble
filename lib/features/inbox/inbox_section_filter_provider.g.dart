// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inbox_section_filter_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(InboxSectionFilterState)
final inboxSectionFilterStateProvider = InboxSectionFilterStateProvider._();

final class InboxSectionFilterStateProvider
    extends $NotifierProvider<InboxSectionFilterState, InboxSectionFilter> {
  InboxSectionFilterStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'inboxSectionFilterStateProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$inboxSectionFilterStateHash();

  @$internal
  @override
  InboxSectionFilterState create() => InboxSectionFilterState();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(InboxSectionFilter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<InboxSectionFilter>(value),
    );
  }
}

String _$inboxSectionFilterStateHash() =>
    r'5f7286271d3f9cff4be3a00add73334d6e702af8';

abstract class _$InboxSectionFilterState extends $Notifier<InboxSectionFilter> {
  InboxSectionFilter build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<InboxSectionFilter, InboxSectionFilter>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<InboxSectionFilter, InboxSectionFilter>,
              InboxSectionFilter,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
