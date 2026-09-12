import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_modal_route.dart';
import '../../core/widgets/app_pane.dart';
import '../../core/widgets/app_staggered_entrance.dart';
import '../../core/widgets/app_step_scaffold.dart';
import '../../core/widgets/app_text_field.dart';
import '../../shared/models/behavior_target_type.dart';
import '../../shared/models/tracked_behavior.dart';
import '../../shared/providers/tracked_behavior_providers.dart';
import 'custom_unit_sheet.dart';

/// Opens the create/edit screen for a [TrackedBehavior] — [behavior] null
/// to create, non-null to edit that row.
///
/// Near-full-screen, built on [StepScaffold] — the exact same chrome (and,
/// on create, the exact same Name-only stage 1 that reveals everything
/// else on "Done") the real task-creation flow and Zone's own add/edit
/// screen already use. Requested directly: "add template and add tracked
/// should follow same modal UI and interaction model as add task and add
/// zone." Reverses this feature's own earlier choice of [AppSheet] (a
/// half-height sheet, reasoned at the time as "five short fields don't
/// justify a full-screen takeover") — that reasoning no longer holds once
/// consistency with every other create flow in the app is the actual
/// requirement.
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
  return pushAppSheetRoute<void>(
    context,
    (context) => _TrackedBehaviorForm(behavior: behavior),
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
  late final TextEditingController _titleController;
  late final TextEditingController _targetController;
  late final TextEditingController _minimumController;

  late BehaviorTargetType _targetType;
  late int _timesPerWeek;
  bool _isSaving = false;

  /// Set only when [_targetType] is [BehaviorTargetType.custom] — the
  /// user-defined label/unit pair from [showCustomUnitSheet]. Null
  /// whenever a non-custom type is selected, mirroring the model's own
  /// `customUnitLabel`/`customUnitName` nullability.
  CustomUnit? _customUnit;

  /// Stage 1 (Name only) vs. stage 2 (everything else) — matches
  /// `task_detail_sheet.dart`/`zone_form_screen.dart`'s own create-flow
  /// pattern exactly. Editing an existing behavior skips straight to
  /// stage 2, same as "Edit task"/"Edit zone" do.
  bool _isNameStage = false;

  bool get _isEditing => widget.behavior != null;

  @override
  void initState() {
    super.initState();
    final behavior = widget.behavior;
    _titleController = TextEditingController(text: behavior?.title ?? '')
      // Same fix `zone_form_screen.dart`'s own Name field needed: nothing
      // here otherwise rebuilds on the controller's own text changing, so
      // the stage-1 Done button stayed disabled while typing. AppTextField
      // has no onChanged of its own, so this listens to the controller
      // directly instead.
      ..addListener(() => setState(() {}));
    // Amounts are `num?` on the model but plain text here — rendered via
    // toString() so an integer target reads "60", not "60.0".
    _targetController = TextEditingController(
      text: _amountText(behavior?.targetAmount),
    );
    _minimumController = TextEditingController(
      text: _amountText(behavior?.minimumAmount),
    );
    _targetType = behavior?.targetType ?? BehaviorTargetType.duration;
    _timesPerWeek = behavior?.timesPerWeek ?? 3;
    _isNameStage = behavior == null;
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
    _targetController.dispose();
    _minimumController.dispose();
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

  bool get _canSave {
    if (_isSaving) return false;
    if (_titleController.text.trim().isEmpty) return false;
    if (_isCustom && _customUnit == null) return false;
    if (_isBinary) return true;
    return num.tryParse(_targetController.text.trim()) != null;
  }

  /// Opens [showCustomUnitSheet] and applies its result — fired by tapping
  /// the "Custom" chip itself (not just once, at selection time: reopening
  /// it lets an already-custom behavior's unit be edited without switching
  /// away and back). Selecting Custom without completing the sheet leaves
  /// [_targetType] set but [_customUnit] null, which [_canSave] blocks on.
  Future<void> _pickCustomUnit() async {
    final result = await showCustomUnitSheet(context, initial: _customUnit);
    if (result != null && mounted) {
      setState(() => _customUnit = result);
    }
  }

  /// Confirms stage 1 (Name) and advances to stage 2 — fired by stage 1's
  /// own Done button or the Name field's keyboard-complete action. Mirrors
  /// `zone_form_screen.dart`'s own `_confirmNameStage` exactly: an empty
  /// name at this point closes the whole screen instead of advancing to a
  /// form with nothing in it.
  void _confirmNameStage() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_titleController.text.trim().isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _isNameStage = false);
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _isSaving = true);
    try {
      final notifier = ref.read(trackedBehaviorListProvider.notifier);
      final title = _titleController.text.trim();
      // A binary behavior has no amount to hit, so none is submitted —
      // matching the model's own constructor invariant rather than writing
      // a value the model would reject.
      final targetAmount = _isBinary
          ? null
          : num.tryParse(_targetController.text.trim());
      final minimumAmount = num.tryParse(_minimumController.text.trim());
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

    // Stage 2's panes, staggered in exactly like task_detail_sheet.dart/
    // zone_form_screen.dart's own `staggeredPanes` — a plain list so the
    // entrance index is each pane's position in it, not hand-numbered at
    // each call site.
    final staggeredPanes = [
      AppPane(
        title: 'Measured in',
        child: Wrap(
          spacing: theme.spacingSm,
          runSpacing: theme.spacingSm,
          children: [
            // Explicit display order — requested directly: "Time,
            // Distance, Reps, Count[, Custom]" plus "Did it" (binary)
            // kept as a 6th option (confirmed via AskUserQuestion), NOT
            // BehaviorTargetType.values' own declaration order (which has
            // binary third, for backward-compatible Hive field indices —
            // see that enum's own doc comment).
            for (final type in _measuredInOrder)
              _TypeChip(
                theme: theme,
                label: _labelFor(type),
                selected: type == _targetType,
                onTap: () {
                  setState(() => _targetType = type);
                  if (type == BehaviorTargetType.custom) _pickCustomUnit();
                },
              ),
          ],
        ),
      ),
      if (!_isBinary)
        AppPane(
          title: 'Target',
          child: Row(
            children: [
              Expanded(
                child: _AmountField(
                  theme: theme,
                  controller: _targetController,
                  label:
                      'Target (${_unitFor(_targetType, customUnitName: _customUnit?.name)})',
                  onChanged: () => setState(() {}),
                ),
              ),
              SizedBox(width: theme.spacingMd),
              Expanded(
                child: _AmountField(
                  theme: theme,
                  controller: _minimumController,
                  label: 'Minimum (optional)',
                  onChanged: () => setState(() {}),
                ),
              ),
            ],
          ),
        ),
      AppPane(
        child: Row(
          children: [
            Text('Times per week', style: theme.textBody),
            const Spacer(),
            _Stepper(
              theme: theme,
              value: _timesPerWeek,
              onChanged: (value) => setState(() => _timesPerWeek = value),
            ),
          ],
        ),
      ),
    ];

    return StepScaffold(
      theme: theme,
      modalTitle: _isEditing ? 'Edit behavior' : 'Track a behavior',
      titleAlignment: TextAlign.left,
      headerColor: theme.colorAccent,
      headerContent: null,
      onClose: () => Navigator.of(context).pop(),
      onBack: null,
      primaryLabel: _isNameStage ? 'Done' : 'Save',
      onPrimaryPressed: _isNameStage
          ? _confirmNameStage
          : (_canSave ? _save : null),
      isPrimaryLoading: !_isNameStage && _isSaving,
      body: SingleChildScrollView(
        // Top reverted to a plain spacingLg — the fade this used to
        // clear now lives INSIDE StepScaffold's own header container,
        // clipped to it, so the body needs no extra top clearance.
        padding: EdgeInsets.fromLTRB(
          theme.spacingLg,
          theme.spacingLg,
          theme.spacingLg,
          theme.spacingXl * 3,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Always in the tree, never rebuilt as a different instance —
            // same reasoning as task_detail_sheet.dart/zone_form_screen.
            // dart's own Name field: its Element (and any keyboard/focus
            // state) must survive the stage 1 -> 2 transition untouched.
            AppPane(
              title: 'Name',
              child: AppTextField(
                controller: _titleController,
                label: 'What are you tracking?',
                autofocus: !_isEditing,
                onSubmitted: (_) => _confirmNameStage(),
              ),
            ),
            if (!_isNameStage) ...[
              SizedBox(height: theme.spacingLg),
              for (final (index, pane) in staggeredPanes.indexed) ...[
                AppStaggeredEntrance(index: index, child: pane),
                SizedBox(height: theme.spacingLg),
              ],
            ],
          ],
        ),
      ),
    );
  }

  String _labelFor(BehaviorTargetType type) => switch (type) {
    BehaviorTargetType.duration => 'Time',
    BehaviorTargetType.distance => 'Distance',
    BehaviorTargetType.reps => 'Reps',
    BehaviorTargetType.count => 'Count',
    BehaviorTargetType.custom => _customUnit?.label ?? 'Custom',
    BehaviorTargetType.binary => 'Did it',
  };
}

/// Explicit "Measured in" chip order — requested directly: "Unit of
/// measure: Time, Distance, Reps, Count[, Custom]", with "Did it" kept as
/// a 6th option (confirmed via AskUserQuestion) rather than
/// [BehaviorTargetType.values]' own declaration order, which exists only
/// to keep old Hive field indices stable. Reps and Count are two distinct
/// options (confirmed via AskUserQuestion), not one relabeled variant.
const _measuredInOrder = [
  BehaviorTargetType.duration,
  BehaviorTargetType.distance,
  BehaviorTargetType.reps,
  BehaviorTargetType.count,
  BehaviorTargetType.custom,
  BehaviorTargetType.binary,
];

/// Renders a `num?` amount for a text field: an integer-valued amount
/// reads "60" rather than "60.0", so reopening an edit form shows the
/// value back exactly as it was typed.
String _amountText(num? amount) {
  if (amount == null) return '';
  if (amount is int) return amount.toString();
  if (amount == amount.roundToDouble()) return amount.round().toString();
  return amount.toString();
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

class _AmountField extends StatelessWidget {
  const _AmountField({
    required this.theme,
    required this.controller,
    required this.label,
    required this.onChanged,
  });

  final AmbleTheme theme;
  final TextEditingController controller;
  final String label;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    // A raw TextField, not AppTextField — AppTextField has no
    // keyboardType hook, and a numeric amount genuinely needs the
    // numeric keypad rather than the default text one. Kept as its own
    // small field (styled from Tier 2 tokens directly, same as before)
    // rather than widening the shared component's API for one caller.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textCaption),
        SizedBox(height: theme.spacingXs),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: theme.textBody.copyWith(color: theme.colorTextPrimary),
          decoration: const InputDecoration(isDense: true, hintText: '—'),
          onChanged: (_) => onChanged(),
        ),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.theme,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final AmbleTheme theme;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacingMd,
          vertical: theme.spacingSm,
        ),
        decoration: BoxDecoration(
          color: selected ? theme.colorAccent : theme.colorSurfaceTimeline,
          borderRadius: BorderRadius.circular(theme.radiusTaskPill),
        ),
        child: Text(
          label,
          style: theme.textBody.copyWith(
            color: selected
                ? theme.colorSurfacePrimary
                : theme.colorTextSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// Minimal −/+ stepper, mirroring the recurrence interval stepper's shape
/// so the two settings-style controls read consistently.
class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.theme,
    required this.value,
    required this.onChanged,
  });

  final AmbleTheme theme;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorSurfaceTimeline,
        borderRadius: BorderRadius.circular(theme.radiusTaskPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepperButton(
            theme: theme,
            icon: Icons.remove_rounded,
            onTap: value > 1 ? () => onChanged(value - 1) : null,
          ),
          Text(
            '$value',
            style: theme.textBody.copyWith(
              color: theme.colorTextPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          _StepperButton(
            theme: theme,
            icon: Icons.add_rounded,
            // 7 is every day — more than that isn't a weekly frequency.
            onTap: value < 7 ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.theme,
    required this.icon,
    required this.onTap,
  });

  final AmbleTheme theme;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.all(theme.spacingSm),
        child: Icon(
          icon,
          size: theme.spacingMd,
          color: onTap == null ? theme.colorTextSecondary : theme.colorAccent,
        ),
      ),
    );
  }
}
