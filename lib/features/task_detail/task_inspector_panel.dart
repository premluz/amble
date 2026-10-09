import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/component_tokens.dart';
import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_sheet_presentation.dart';
import '../timeline/pending_task_draft_provider.dart';
import 'task_editor.dart';
import 'task_inspector.dart';
import '../../core/widgets/app_hairline.dart';

/// The wide layout's right-hand panel: the shared [TaskEditor] for the
/// current [taskInspectorProvider] request, or nothing (no width at all)
/// while closed, so the content keeps the full width.
///
/// It also takes over the Timeline's quick-create: when a draft's sheet
/// would appear (released long-press, or "+"), the draft opens here
/// instead, still linked to its pill. If the open editor's user chooses
/// "Keep editing" over that, the new draft is cancelled.
class TaskInspectorPanel extends ConsumerStatefulWidget {
  const TaskInspectorPanel({super.key});

  @override
  ConsumerState<TaskInspectorPanel> createState() => _TaskInspectorPanelState();
}

class _TaskInspectorPanelState extends ConsumerState<TaskInspectorPanel> {
  late final TaskInspectorNotifier _inspector = ref.read(
    taskInspectorProvider.notifier,
  );

  @override
  void initState() {
    super.initState();
    _inspector.attachHost();
  }

  @override
  void dispose() {
    _inspector.detachHost();
    super.dispose();
  }

  /// A draft whose sheet would now be showing, not yet in the panel.
  void _syncDraft() {
    final draft = ref.read(pendingTaskDraftProvider);
    final shown = ref.read(taskInspectorProvider)?.draft;
    if (draft == null) {
      if (shown != null) _inspector.close();
      return;
    }
    if (!ref.read(quickAddSheetVisibleProvider) || shown?.id == draft.id) {
      return;
    }
    _openDraft(draft);
  }

  Future<void> _openDraft(PendingTaskDraft draft) async {
    if (await _inspector.open(draft: draft)) return;
    _clearDraft(draft);
  }

  /// Clears [draft] from the Timeline, unless a newer draft replaced it.
  void _clearDraft(PendingTaskDraft draft) {
    if (ref.read(pendingTaskDraftProvider)?.id != draft.id) return;
    ref.read(pendingTaskDraftProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(pendingTaskDraftProvider, (_, _) => _syncDraft());
    ref.listen(quickAddSheetVisibleProvider, (_, _) => _syncDraft());
    final request = ref.watch(taskInspectorProvider);
    if (request == null) return const SizedBox.shrink();
    final requestDraft = request.draft;
    final liveDraft = ref.watch(pendingTaskDraftProvider);
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorSurfaceTimeline,
        border: Border(
          left: AppHairline.side(context, ShellLayoutTokens.dividerAlpha),
        ),
      ),
      child: SizedBox(
        width: ShellLayoutTokens.inspectorWidth,
        // Pickers open beside the field, not as a sheet over the screen.
        child: AppSheetPresentationScope(
          presentation: AppSheetPresentation.popover,
          child: SingleChildScrollView(
            // Desktop panel inset, as in Notion Calendar's (~16pt).
            padding: EdgeInsets.all(theme.spacingMd).copyWith(
              // Below the top safe area (macOS: the title bar).
              top: theme.spacingMd + MediaQuery.paddingOf(context).top,
            ),
            child: TaskEditor(
              key: ValueKey(request.serial),
              // The panel outlives each editor, so the undo toast and the
              // repeating-task question anchor here.
              rootContext: context,
              dialogContext: context,
              onFinished: () {
                _inspector.close();
                if (requestDraft != null) _clearDraft(requestDraft);
              },
              inspector: _inspector,
              task: request.task,
              duplicateFrom: request.duplicateFrom,
              templateId: request.templateId,
              initialScheduledAt: request.initialScheduledAt,
              initialTimeOfDay: request.initialTimeOfDay,
              // The live draft, so dragging its pill updates the fields.
              draft: requestDraft == null
                  ? null
                  : (liveDraft?.id == requestDraft.id
                        ? liveDraft
                        : requestDraft),
            ),
          ),
        ),
      ),
    );
  }
}
