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
      // Carried through from whatever this behavior was already saved
      // with, NOT read from a field — the Target/Minimum inputs are gone
      // (see the form body's own comment). A create leaves both null; an
      // edit preserves the existing row's values rather than silently
      // clearing amounts the form no longer shows and the user therefore
      // has no way to re-enter.
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
      // The "Target"/"Minimum" pane and the "Times per week" stepper both
      // used to sit here — removed directly: "from settings track hide
      // target and times per week and its dependency to be filled in
      // order to save."
      //
      // Both fields are still on the model and still written on save
      // (`timesPerWeek` from its own default, `targetAmount` as null);
      // the model's "targetAmount is required unless binary" assert is
      // gone, and `_canSave` no longer waits on an amount. Existing
      // behaviors keep whatever they were saved with — nothing rewrites
      // them.
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
                // Bare — the shared style for every entity's name. The
                // placeholder wording stays this form's own question
                // rather than a generic "Add title".
                variant: AppTextFieldVariant.bare,
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
