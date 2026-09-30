import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/app_sheet_header.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/app_value_chip.dart';
import '../../shared/models/behavior_target_type.dart';
import '../../shared/models/tracked_behavior.dart';
import '../../shared/providers/tracked_behavior_providers.dart';
import 'custom_unit_sheet.dart';
import 'tracked_behavior_unit_sheet.dart';

/// Opens the create/edit screen for a [TrackedBehavior] — [behavior] null
/// to create, non-null to edit that row.
///
/// Compact, single-page sheet matching the quick task add pattern. The
/// measured unit is a value chip that opens its own small picker.
///
/// All writes go through `trackedBehaviorListProvider`; this UI never
/// touches the repository or Hive directly.
///
/// Deliberately offers no delete — create/list/edit only, per SCOPE.md.
/// Deleting a behavior that existing tasks reference via `Task.behaviorId`
/// raises the same orphaned-reference question already deliberately
/// deferred for `Category` and `Zone`, and is not resolved here either.
/// (`TrackedBehaviorList.deleteBehavior` exists on the notifier from the
/// Phase 10 data layer, but no UI reaches it.)
Future<void> showTrackedBehaviorForm(
  BuildContext context, {
  TrackedBehavior? behavior,
}) {
  return AppSheet.show<void>(
    context: context,
    builder: (context) => _TrackedBehaviorForm(behavior: behavior),
  );
}

class _TrackedBehaviorForm extends ConsumerStatefulWidget {
  const _TrackedBehaviorForm({this.behavior});

  /// The row being edited, or null for a create. Save writes back to this
  /// same id when set, rather than creating a second behavior.
  final TrackedBehavior? behavior;

  @override
  ConsumerState<_TrackedBehaviorForm> createState() =>
      _TrackedBehaviorFormState();
}

class _TrackedBehaviorFormState extends ConsumerState<_TrackedBehaviorForm> {
  static const _defaultTitle = 'New habit';

  late final TextEditingController _titleController;

  late BehaviorTargetType _targetType;
  late int _timesPerWeek;
  bool _isSaving = false;

  /// Set only when [_targetType] is [BehaviorTargetType.custom] — the
  /// user-defined label/unit pair from [showCustomUnitSheet]. Null
  /// whenever a non-custom type is selected, mirroring the model's own
  /// `customUnitLabel`/`customUnitName` nullability.
  CustomUnit? _customUnit;

  bool get _isEditing => widget.behavior != null;

  @override
  void initState() {
    super.initState();
    final behavior = widget.behavior;
    _titleController = TextEditingController(
      text: behavior?.title ?? _defaultTitle,
    )..addListener(() => setState(() {}));
    _targetType = behavior?.targetType ?? BehaviorTargetType.duration;
    _timesPerWeek = behavior?.timesPerWeek ?? 3;
    if (behavior?.customUnitLabel != null && behavior?.customUnitName != null) {
      _customUnit = CustomUnit(
        label: behavior!.customUnitLabel!,
        name: behavior.customUnitName!,
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  /// A binary behavior has no amount to hit, so its target field is hidden
  /// and no amount is submitted — matching the model's own invariant
  /// (`targetAmount` is required unless the type is binary).
  bool get _isBinary => _targetType == BehaviorTargetType.binary;

  /// A custom target type has no meaningful unit until the sheet has been
  /// filled in — matching the model's own assert (`customUnitLabel`/
  /// `customUnitName` are required whenever `targetType` is custom).
  bool get _isCustom => _targetType == BehaviorTargetType.custom;

  /// No longer waits on a target amount — requested directly: "hide
  /// target and times per week and its dependency to be filled in order
  /// to save." A name (and, for a custom type, its unit) is all that's
  /// required now.
  bool get _canSave {
    if (_isSaving) return false;
    if (_titleController.text.trim().isEmpty) return false;
    if (_isCustom && _customUnit == null) return false;
    return true;
  }

  /// Opens [showCustomUnitSheet] and applies its result after the unit picker
  /// has selected Custom. Selecting Custom without completing the sheet leaves
  /// [_targetType] set but [_customUnit] null, which [_canSave] blocks on.
  Future<void> _pickCustomUnit() async {
    final result = await showCustomUnitSheet(context, initial: _customUnit);
    if (result != null && mounted) {
      setState(() => _customUnit = result);
    }
  }

  void _clearDefaultTitle(bool hasFocus) {
    if (hasFocus && _titleController.text == _defaultTitle) {
      _titleController.clear();
    }
  }

  Future<void> _pickMeasuredIn() async {
    if (_isCustom) {
      await _pickCustomUnit();
      return;
    }
    final choice = await showTrackedBehaviorUnitSheet(
      context,
      initial: _targetType,
    );
    if (choice == null || !mounted) return;
    setState(() {
      _targetType = choice.type;
      _customUnit = choice.customUnit;
    });
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _isSaving = true);
    try {
      final notifier = ref.read(trackedBehaviorListProvider.notifier);
      final title = _titleController.text.trim();
      // Carried through from whatever this behavior was already saved
      // with, not read from a field — the compact sheet does not expose
      // Target/Minimum inputs. A create leaves both null; an edit preserves
      // the existing row's values rather than silently clearing amounts the
      // user has no way to re-enter here.
      final targetAmount = _isBinary ? null : widget.behavior?.targetAmount;
      final minimumAmount = widget.behavior?.minimumAmount;
      // Only ever set for a custom target type — matching the model's own
      // constructor invariant, and clearing them out if a behavior is
      // edited AWAY from custom to something else.
      final customUnitLabel = _isCustom ? _customUnit?.label : null;
      final customUnitName = _isCustom ? _customUnit?.name : null;
      final existing = widget.behavior;

      if (existing == null) {
        await notifier.createBehavior(
          title: title,
          targetType: _targetType,
          targetAmount: targetAmount,
          minimumAmount: minimumAmount,
          timesPerWeek: _timesPerWeek,
          customUnitLabel: customUnitLabel,
          customUnitName: customUnitName,
        );
      } else {
        existing.title = title;
        existing.targetType = _targetType;
        existing.targetAmount = targetAmount;
        existing.minimumAmount = minimumAmount;
        existing.timesPerWeek = _timesPerWeek;
        existing.customUnitLabel = customUnitLabel;
        existing.customUnitName = customUnitName;
        await notifier.updateBehavior(existing);
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSheetHeader(
          theme: theme,
          title: _isEditing ? 'Edit habit' : null,
          onClose: () => Navigator.of(context).pop(),
          trailing: AppButton(
            label: _isEditing ? 'Save' : 'Add',
            shape: AppButtonShape.pill,
            isLoading: _isSaving,
            onPressed: _canSave ? _save : null,
          ),
        ),
        SizedBox(height: theme.spacingMd),
        AppTextField(
          controller: _titleController,
          label: 'Add title',
          variant: AppTextFieldVariant.bare,
          autofocus: false,
          onFocusChanged: _clearDefaultTitle,
          onSubmitted: (_) {
            if (_canSave) _save();
          },
        ),
        SizedBox(height: theme.spacingMd),
        Align(
          alignment: Alignment.centerLeft,
          child: AppValueChip(
            label: trackedBehaviorTypeLabel(
              _targetType,
              customLabel: _customUnit?.label,
            ),
            hasValue: true,
            size: AppValueChipSize.sm,
            onTap: _pickMeasuredIn,
          ),
        ),
      ],
    );
  }
}

/// The unit a target amount is expressed in, for labels and prompts.
/// [customUnitName] is required only for [BehaviorTargetType.custom] — a
/// custom behavior's own real unit (e.g. "glasses"), never a placeholder,
/// per the model's own invariant that `customUnitName` is always set
/// whenever `targetType` is custom.
String _unitFor(BehaviorTargetType type, {String? customUnitName}) =>
    switch (type) {
      BehaviorTargetType.duration => 'min',
      BehaviorTargetType.distance => 'km',
      BehaviorTargetType.reps => 'reps',
      BehaviorTargetType.count => 'times',
      BehaviorTargetType.custom => customUnitName ?? '',
      BehaviorTargetType.binary => '',
    };

/// Shared so the outcome prompt/row labels read the same unit the create
/// form did — a "60 min" target should read back as minutes, not a bare
/// number, and a custom behavior's own unit (e.g. "glasses") rather than
/// a generic placeholder.
String unitLabelFor(BehaviorTargetType type, {String? customUnitName}) =>
    _unitFor(type, customUnitName: customUnitName);
