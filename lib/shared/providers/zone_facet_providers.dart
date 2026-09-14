import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/zone_facet.dart';
import '../repositories/zone_facet_repository.dart';

final zoneFacetRepositoryProvider = Provider<ZoneFacetRepository>((ref) => HiveZoneFacetRepository.opened());
final zoneFacetListProvider = NotifierProvider<ZoneFacetList, List<ZoneFacet>>(ZoneFacetList.new);

class ZoneFacetList extends Notifier<List<ZoneFacet>> {
  @override
  List<ZoneFacet> build() => ref.watch(zoneFacetRepositoryProvider).getAll();
  Future<ZoneFacet> resolve(String name, {String? id}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('Enter a zone name.');
    final repository = ref.read(zoneFacetRepositoryProvider);
    final facets = repository.getAll();
    if (id != null) {
      final existing = facets.where((f) => f.id == id).firstOrNull;
      if (existing == null) throw StateError('This zone name was removed. Choose another.');
      return existing;
    }
    final existing = facets.where((f) => f.name.toLowerCase() == trimmed.toLowerCase()).firstOrNull;
    if (existing != null) return existing;
    final facet = ZoneFacet.create(trimmed);
    await repository.save(facet);
    state = repository.getAll();
    return facet;
  }
  Future<void> rename(ZoneFacet facet, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('Enter a zone name.');
    if (state.any((f) => f.id != facet.id && f.name.toLowerCase() == trimmed.toLowerCase())) {
      throw ArgumentError('That name already exists.');
    }
    await ref.read(zoneFacetRepositoryProvider).save(ZoneFacet(id: facet.id, name: trimmed));
    state = ref.read(zoneFacetRepositoryProvider).getAll();
  }
  Future<void> importFacets(List<ZoneFacet> facets) async {
    final repository = ref.read(zoneFacetRepositoryProvider);
    for (final facet in facets) {
      if (!repository.getAll().any((f) => f.id == facet.id)) await repository.save(facet);
    }
    state = repository.getAll();
  }
}
