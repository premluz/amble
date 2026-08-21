import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_sheet.dart';
import '../../shared/providers/task_providers.dart';

/// Opens the quick-capture sheet — a title-only entry point for adding an
/// item to the Inbox. Per design principle 2 (capture is frictionless,
/// prioritization is deferred): no category, no schedule, no notes — just a
/// title, submitted via [TaskList.captureTask].
Future<void> showQuickCaptureSheet(BuildContext context) {
  return AppSheet.show<void>(
    context: context,
    builder: (context) => const _QuickCaptureForm(),
  );
}

class _QuickCaptureForm extends ConsumerStatefulWidget {
  const _QuickCaptureForm();

  @override
  ConsumerState<_QuickCaptureForm> createState() => _QuickCaptureFormState();
}

class _QuickCaptureFormState extends ConsumerState<_QuickCaptureForm> {
  late final TextEditingController _titleController;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    await ref.read(taskListProvider.notifier).captureTask(title);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add to Inbox', style: theme.textTitle),
          SizedBox(height: theme.spacingMd),
          TextField(
            controller: _titleController,
            focusNode: _focusNode,
            style: theme.textBody,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              hintText: 'What needs doing?',
              hintStyle: theme.textBody.copyWith(
                color: theme.colorTextSecondary,
              ),
              filled: true,
              fillColor: theme.colorSurfaceSecondary,
              contentPadding: EdgeInsets.symmetric(
                horizontal: theme.spacingMd,
                vertical: theme.spacingMd,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(theme.radiusControl),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          SizedBox(height: theme.spacingMd),
          SizedBox(
            width: double.infinity,
            child: AppButton(label: 'Add', onPressed: _submit),
          ),
        ],
      ),
    );
  }
}
