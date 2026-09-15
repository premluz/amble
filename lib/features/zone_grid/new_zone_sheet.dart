import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_press_feedback.dart';
import '../../core/widgets/app_step_scaffold.dart' show HeaderCircleButton;
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/app_segmented_time_field.dart';
import '../../shared/providers/zone_providers.dart';
import '../../shared/providers/zone_facet_providers.dart';

class NewZoneTarget {
  const NewZoneTarget({
    required this.day,
    required this.startMinutes,
    required this.endMinutes,
    this.days,
  });
  final DateTime day;
  final int startMinutes, endMinutes;
  final Set<int>? days;
  Set<int> get weekdays => days ?? {day.weekday};
}

/// In-tree sheet: the selected area stays visible while naming it. Its height
/// is bounded by the keyboard-adjusted viewport, including large text sizes.
class NewZoneSheet extends ConsumerStatefulWidget {
  const NewZoneSheet({
    super.key,
    required this.target,
    required this.onDismiss,
  });
  final NewZoneTarget target;
  final VoidCallback onDismiss;
  @override
  ConsumerState<NewZoneSheet> createState() => _NewZoneSheetState();
}

class _NewZoneSheetState extends ConsumerState<NewZoneSheet> {
  final _title = TextEditingController();
  @override
  void initState() {
    super.initState();
    _title.addListener(() {
      _facetId = null;
    });
  }

  String? _facetId, _error;
  bool _saving = false;
  late int _start = widget.target.startMinutes;
  late int _end = widget.target.endMinutes;
  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(zoneListProvider.notifier)
          .paintWeeklyZones(
            title: _title.text,
            facetId: _facetId,
            weekdays: widget.target.weekdays,
            startMinutes: _start,
            endMinutes: _end,
          );
      if (mounted) widget.onDismiss();
    } catch (error) {
      if (mounted)
        setState(
          () => _error = error is StateError
              ? error.message
              : error is ArgumentError
              ? '${error.message}'
              : 'Could not save. Please try again.',
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final names = [...ref.watch(zoneFacetListProvider)]
      ..sort((a, b) => a.name.compareTo(b.name));
    const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final days = widget.target.weekdays.toList()..sort();
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: theme.motionFast,
        curve: theme.curveDecelerate,
        builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, theme.spacingMd * (1 - value)),
            child: child,
          ),
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .62,
          ),
          // `colorSurfaceOverlay` — the top of the elevation ramp, matching
          // every other sheet in the app (see `AppSheet`). Requested directly.
          decoration: BoxDecoration(
            color: theme.colorSurfaceOverlay,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(theme.radiusXl),
            ),
            boxShadow: theme.shadowPane,
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: EdgeInsets.all(theme.spacingMd),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('New zone', style: theme.textTitle)),
                      HeaderCircleButton(
                        theme: theme,
                        icon: Icons.close,
                        onTap: _saving ? () {} : widget.onDismiss,
                      ),
                    ],
                  ),
                  SizedBox(height: theme.spacingSm),
                  Text(
                    'Every ${days.map((d) => dayLabels[d - 1]).join(', ')}',
                    style: theme.textCaption.copyWith(
                      color: theme.colorTextSecondary,
                    ),
                  ),
                  SizedBox(height: theme.spacingSm),
                  AppTextField(controller: _title, label: 'Zone name'),
                  if (names.isNotEmpty) ...[
                    SizedBox(height: theme.spacingSm),
                    Wrap(
                      spacing: theme.spacingXs,
                      runSpacing: theme.spacingXs,
                      children: [
                        for (final name in names)
                          AppPressFeedback(
                            onTap: () => setState(() {
                              _title.text = name.name;
                              _facetId = name.id;
                            }),
                            borderRadius: BorderRadius.circular(theme.radiusMd),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: theme.spacingSm,
                                vertical: theme.spacingXs,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorSurfaceSecondary,
                                borderRadius: BorderRadius.circular(
                                  theme.radiusMd,
                                ),
                              ),
                              child: Text(name.name, style: theme.textCaption),
                            ),
                          ),
                      ],
                    ),
                  ],
                  SizedBox(height: theme.spacingMd),
                  Row(
                    children: [
                      Expanded(
                        child: AppSegmentedTimeField(
                          label: 'Start',
                          first: _start ~/ 60,
                          second: _start % 60,
                          firstMax: 23,
                          onChanged: (h, m) =>
                              setState(() => _start = h * 60 + m),
                        ),
                      ),
                      SizedBox(width: theme.spacingSm),
                      Expanded(
                        child: AppSegmentedTimeField(
                          label: 'End',
                          first: _end ~/ 60,
                          second: _end % 60,
                          firstMax: 24,
                          onChanged: (h, m) =>
                              setState(() => _end = h * 60 + m),
                        ),
                      ),
                    ],
                  ),
                  if (_error != null)
                    Padding(
                      padding: EdgeInsets.only(top: theme.spacingSm),
                      child: Text(
                        _error!,
                        style: theme.textCaption.copyWith(
                          color: theme.colorTextSecondary,
                        ),
                      ),
                    ),
                  SizedBox(height: theme.spacingMd),
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      label: 'Add zone',
                      isLoading: _saving,
                      onPressed: _save,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
