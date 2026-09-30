import 'package:flutter/material.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_sheet_flow.dart';
import '../../core/widgets/app_text_field.dart';

/// A user-defined unit for a tracked behavior — [label] is the unit's own
/// display name (e.g. "Water"), [name] is the short suffix shown next to
/// amounts (e.g. "glasses", giving "8 glasses"). Both required — the model
/// itself asserts on this (`TrackedBehavior`'s own constructor), so a
/// custom target type is never saved half-filled.
class CustomUnit {
  const CustomUnit({required this.label, required this.name});

  final String label;
  final String name;
}

/// The Custom unit page, pushed inside the habit form's sheet (from the
/// form itself, or from "Measured in"); [onSaved] takes the unit.
class CustomUnitPage extends StatefulWidget {
  const CustomUnitPage({super.key, this.initial, required this.onSaved});

  final CustomUnit? initial;
  final ValueChanged<CustomUnit> onSaved;

  @override
  State<CustomUnitPage> createState() => _CustomUnitPageState();
}

class _CustomUnitPageState extends State<CustomUnitPage> {
  late final TextEditingController _labelController;
  late final TextEditingController _unitController;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.initial?.label ?? '')
      // Save's enabled state must react per-keystroke — AppTextField has
      // no onChanged of its own, so this listens to the controller
      // directly, same pattern `tracked_behavior_form.dart`'s own Name
      // field uses.
      ..addListener(() => setState(() {}));
    _unitController = TextEditingController(text: widget.initial?.name ?? '')
      ..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _labelController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _labelController.text.trim().isNotEmpty &&
      _unitController.text.trim().isNotEmpty;

  void _save() {
    if (!_canSave) return;
    final saved = CustomUnit(
      label: _labelController.text.trim(),
      name: _unitController.text.trim(),
    );
    widget.onSaved(saved);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSheetFlowHeader(
          theme: theme,
          title: 'Custom unit',
          trailing: AppButton(
            icon: Icons.check_rounded,
            shape: AppButtonShape.circle,
            tooltip: 'Save custom unit',
            onPressed: _canSave ? _save : null,
          ),
        ),
        SizedBox(height: theme.spacingMd),
        AppTextField(
          controller: _labelController,
          label: 'Label',
          variant: AppTextFieldVariant.bare,
          autofocus: true,
        ),
        SizedBox(height: theme.spacingMd),
        AppTextField(
          controller: _unitController,
          label: 'Unit (e.g. times, km, hours, glasses)',
          variant: AppTextFieldVariant.bare,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _save(),
        ),
      ],
    );
  }
}
