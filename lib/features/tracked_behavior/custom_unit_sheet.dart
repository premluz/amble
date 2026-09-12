import 'package:flutter/material.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_sheet.dart';
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

/// Opens the small "Custom unit" sheet — requested directly: "Custom >
/// opens small sheet with entry field (Label, Unit (placeholder, times,
/// km, hours, glasses)." Content-sized ([AppSheetSize.small]), not a full
/// [StepScaffold] takeover — this is a two-field accessory to the tracked
/// behavior form, not a flow of its own, matching `showQuickCaptureSheet`'s
/// own "stays small" precedent for a short form.
///
/// [initial] pre-fills both fields when re-opening an already-configured
/// custom unit (e.g. editing an existing custom-type behavior). Returns
/// null if dismissed without saving.
Future<CustomUnit?> showCustomUnitSheet(
  BuildContext context, {
  CustomUnit? initial,
}) {
  return AppSheet.show<CustomUnit>(
    context: context,
    builder: (context) => _CustomUnitForm(initial: initial),
  );
}

class _CustomUnitForm extends StatefulWidget {
  const _CustomUnitForm({this.initial});

  final CustomUnit? initial;

  @override
  State<_CustomUnitForm> createState() => _CustomUnitFormState();
}

class _CustomUnitFormState extends State<_CustomUnitForm> {
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
    Navigator.of(context).pop(
      CustomUnit(
        label: _labelController.text.trim(),
        name: _unitController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Custom unit', style: theme.textTitle),
        SizedBox(height: theme.spacingLg),
        AppTextField(
          controller: _labelController,
          label: 'Label',
          autofocus: true,
        ),
        SizedBox(height: theme.spacingMd),
        // A raw TextField, not AppTextField — this field needs real hint
        // text alongside its own label (AppTextField's resting label
        // doubles as its only placeholder, with no separate hint slot),
        // same reasoning `tracked_behavior_form.dart`'s own `_AmountField`
        // already uses for the identical gap.
        Text('Unit', style: theme.textCaption),
        SizedBox(height: theme.spacingXs),
        TextField(
          controller: _unitController,
          style: theme.textBody.copyWith(color: theme.colorTextPrimary),
          decoration: const InputDecoration(
            isDense: true,
            hintText: 'e.g. times, km, hours, glasses',
          ),
          onSubmitted: (_) => _save(),
        ),
        SizedBox(height: theme.spacingLg),
        AppButton(label: 'Save', onPressed: _canSave ? _save : null),
      ],
    );
  }
}
