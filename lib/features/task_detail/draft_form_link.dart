import 'package:flutter/material.dart';

import '../timeline/pending_task_draft_provider.dart';
import 'task_sheet_form.dart';

/// Keeps a Timeline quick-create draft's pill and a [TaskSheetForm] as one:
/// dragging the pill updates the form's date, time and length, and picking
/// them in the form moves the pill. The same two-way link
/// `QuickCreateOverlay` keeps for the phone sheet, for the wide layout's
/// right-hand panel.
class DraftFormLink {
  DraftFormLink(this._draft, {required this.drafts}) : form = formFor(_draft) {
    form.addListener(_moveDraftToForm);
  }

  /// The name a fresh draft starts with, so Add works untouched. The first
  /// focus clears it ([clearDefaultName]).
  static const defaultName = 'New thing';

  /// A form seeded from [draft], named [defaultName]. [form] is one; the
  /// caller still owns disposing it.
  static TaskSheetForm formFor(PendingTaskDraft draft) => TaskSheetForm(
    title: defaultName,
    date: draft.scheduledAt,
    time: TimeOfDay.fromDateTime(draft.scheduledAt),
    durationMinutes: draft.durationMinutes,
  );

  final TaskSheetForm form;
  final PendingTaskDraftNotifier drafts;
  PendingTaskDraft _draft;

  String get draftId => _draft.id;

  /// Whether the user typed a name — the one thing in a draft worth asking
  /// about before throwing it away (its time is just where they pressed).
  bool get hasTypedName {
    final title = form.title.text.trim();
    return title.isNotEmpty && title != defaultName;
  }

  /// The pill moved or was resized: follow it. [_draft] is updated first,
  /// so the form's resulting change already matches the pill and isn't sent
  /// back to it.
  void follow(PendingTaskDraft draft) {
    final moved =
        draft.scheduledAt != _draft.scheduledAt ||
        draft.durationMinutes != _draft.durationMinutes;
    _draft = draft;
    if (moved) form.setSchedule(draft.scheduledAt, draft.durationMinutes);
  }

  void _moveDraftToForm() {
    final at = form.scheduledAt;
    final minutes = form.durationMinutes;
    if (at == null || minutes == null) return;
    if (at != _draft.scheduledAt) drafts.updatePosition(at);
    if (minutes != _draft.durationMinutes) drafts.updateDuration(minutes);
  }

  /// The first focus into the name clears the default, so typing starts
  /// fresh; a typed name or a preset's stays.
  void clearDefaultName(bool hasFocus) {
    if (hasFocus && form.title.text == defaultName) form.title.clear();
  }

  void dispose() => form.removeListener(_moveDraftToForm);
}
