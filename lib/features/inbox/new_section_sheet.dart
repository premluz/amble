import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/app_sheet_header.dart';
import '../../core/widgets/app_text_field.dart';
import '../../shared/models/section.dart';
import '../../shared/providers/section_providers.dart';

/// The "+ create Section" prompt — a single name field, opened from the
/// end of the Inbox's own Section tab row (`inbox_section_tabs.dart`).
/// Needed because assignment is drag-only (requested directly): a
/// Section has to already exist as a tab before anything can be dragged
/// onto it.
///
/// Header shape (close left, primary action right, no title text) matches
/// `NewZoneSheet`'s own — unified directly against the Timeline's
/// quick-create pattern — rather than the heavier progressive-disclosure
/// `_AddCategoryScreen` uses, since a Section has only a name, nothing to
/// stage.
Future<Section?> showNewSectionSheet(BuildContext context) {
  return AppSheet.show<Section>(
    context: context,
    builder: (context) => const _NewSectionSheet(existing: null),
  );
}

/// Renames [section] via the same name-field sheet as [showNewSectionSheet]
/// — pre-filled with its current name, "Save" instead of "Create", writing
/// through [SectionList.renameSection] instead of `createSection`. Opened
/// from a Section tab's own long-press menu (`inbox_section_tabs.dart`).
Future<void> showRenameSectionSheet(BuildContext context, Section section) {
  return AppSheet.show<void>(
    context: context,
    builder: (context) => _NewSectionSheet(existing: section),
  );
}

class _NewSectionSheet extends ConsumerStatefulWidget {
  const _NewSectionSheet({required this.existing});

  /// Null when creating a new Section; the Section being renamed otherwise.
  final Section? existing;

  @override
  ConsumerState<_NewSectionSheet> createState() => _NewSectionSheetState();
}

class _NewSectionSheetState extends ConsumerState<_NewSectionSheet> {
  late final _name = TextEditingController(text: widget.existing?.name);
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty || _saving) return;
    setState(() => _saving = true);
    final existing = widget.existing;
    if (existing == null) {
      final section = await ref
          .read(sectionListProvider.notifier)
          .createSection(name: name);
      if (!mounted) return;
      Navigator.of(context).pop(section);
    } else {
      await ref
          .read(sectionListProvider.notifier)
          .renameSection(existing.id, name);
      if (!mounted) return;
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // No `handle` — this sheet has no drag-to-close gesture of its own,
        // so the header renders just its controls at the same shared row
        // height (see AppSheetHeader's own doc comment on why the height is
        // reserved either way).
        AppSheetHeader(
          theme: theme,
          onClose: _saving ? () {} : () => Navigator.of(context).pop(),
          trailing: AppButton(
            label: widget.existing == null ? 'Create' : 'Save',
            size: AppButtonSize.md,
            shape: AppButtonShape.pill,
            isLoading: _saving,
            onPressed: _save,
          ),
        ),
        SizedBox(height: theme.spacingMd),
        AppTextField(
          controller: _name,
          label: 'Section name',
          variant: AppTextFieldVariant.bare,
          autofocus: true,
          onSubmitted: (_) => _save(),
        ),
      ],
    );
  }
}
