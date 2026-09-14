import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_icon_button.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/app_press_feedback.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/app_subtle_icon_button.dart';
import '../../shared/models/zone_facet.dart';
import '../../shared/providers/zone_facet_providers.dart';
import '../../shared/providers/zone_providers.dart';

Future<void> showZoneListScreen(BuildContext context) => Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => const ZoneListScreen()));
Future<void> showZoneNameSheet(BuildContext context, {ZoneFacet? facet}) => AppSheet.show<void>(context: context,
  builder: (_) => _ZoneNameForm(facet: facet));

class ZoneListScreen extends StatelessWidget {
  const ZoneListScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    return Scaffold(backgroundColor: theme.colorSurfacePrimary, body: SafeArea(child: Column(children: [
      Padding(padding: EdgeInsets.all(theme.spacingScreenPadding), child: Row(children: [
        AppIconButton(icon: Icons.arrow_back_rounded, onPressed: () => Navigator.of(context).pop()),
        SizedBox(width: theme.spacingMd), Expanded(child: Text('Zone names', style: theme.textTitle)),
        AppIconButton(icon: Icons.add_rounded, onPressed: () => showZoneNameSheet(context)),
      ])),
      Padding(padding: EdgeInsets.all(theme.spacingMd), child: Text('Reusable names for your week. Set times by painting zones in the grid.',
        style: theme.textCaption.copyWith(color: theme.colorTextSecondary))),
      const Expanded(child: ZoneListBody()),
    ])));
  }
}
class ZoneListBody extends ConsumerWidget {
  const ZoneListBody({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final names = [...ref.watch(zoneFacetListProvider)]..sort((a,b) => a.name.compareTo(b.name));
    if (names.isEmpty) return Center(child: Text('No zone names yet', style: theme.textBody));
    return ListView.separated(padding: EdgeInsets.symmetric(horizontal: theme.spacingScreenPadding),
      itemCount: names.length, separatorBuilder: (_,_) => SizedBox(height: theme.spacingSm), itemBuilder: (context,index) {
        final name = names[index];
        return AppPressFeedback(onTap: () => showZoneNameSheet(context, facet: name),
          borderRadius: BorderRadius.circular(theme.radiusXl), child: Container(
            padding: EdgeInsets.all(theme.spacingMd), decoration: BoxDecoration(color: theme.colorSurfaceSecondary,
              borderRadius: BorderRadius.circular(theme.radiusXl)), child: Text(name.name, style: theme.textBody)));
      });
  }
}
class _ZoneNameForm extends ConsumerStatefulWidget {
  const _ZoneNameForm({this.facet});
  final ZoneFacet? facet;
  @override
  ConsumerState<_ZoneNameForm> createState() => _ZoneNameFormState();
}
class _ZoneNameFormState extends ConsumerState<_ZoneNameForm> {
  late final _name = TextEditingController(text: widget.facet?.name ?? '');
  String? _error;
  bool _saving = false;
  @override
  void dispose() { _name.dispose(); super.dispose(); }
  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final notifier = ref.read(zoneFacetListProvider.notifier);
      final facet = widget.facet;
      if (facet == null) { await notifier.resolve(_name.text); }
      else {
        await notifier.rename(facet, _name.text);
        await ref.read(zoneListProvider.notifier).renameFacetPlacements(facet.id, _name.text.trim());
      }
      if (mounted) Navigator.of(context).pop();
    } catch (error) { if (mounted) setState(() => _error = error is ArgumentError ? '${error.message}' : 'Could not save this name.'); }
    finally { if (mounted) setState(() => _saving = false); }
  }
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    return Padding(padding: EdgeInsets.all(theme.spacingMd), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [Expanded(child: Text(widget.facet == null ? 'New zone name' : 'Edit zone name', style: theme.textTitle)),
        if (widget.facet != null) AppSubtleIconButton(icon: Icons.delete_outline_rounded, tooltip: 'Remove name', onTap: _saving ? null : () async {
          try { await ref.read(zoneListProvider.notifier).deleteUnusedFacet(widget.facet!.id);
            if (context.mounted) Navigator.of(context).pop();
          } catch (error) { if (mounted) setState(() => _error = error is StateError ? error.message : 'Could not remove this name.'); }
        }),
      ]),
      SizedBox(height: theme.spacingMd), AppTextField(controller: _name, label: 'Name'),
      if (_error != null) Text(_error!, style: theme.textCaption),
      SizedBox(height: theme.spacingMd), AppButton(label: 'Save', onPressed: _save, isLoading: _saving),
    ]));
  }
}
