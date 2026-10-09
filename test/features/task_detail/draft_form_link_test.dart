import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amble/features/task_detail/draft_form_link.dart';
import 'package:amble/features/timeline/pending_task_draft_provider.dart';

/// The wide layout's quick-create panel keeps the Timeline draft's pill and
/// its form as one, like the phone's quick-create sheet does: dragging the
/// pill updates the form, and picking a time or length moves the pill.
void main() {
  final at10 = DateTime(2026, 10, 8, 10);
  final at11 = DateTime(2026, 10, 8, 11);

  late ProviderContainer container;
  late PendingTaskDraftNotifier drafts;
  late DraftFormLink link;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
    drafts = container.read(pendingTaskDraftProvider.notifier)
      ..start(scheduledAt: at10, durationMinutes: 30);
    link = DraftFormLink(
      container.read(pendingTaskDraftProvider)!,
      drafts: drafts,
    );
    addTearDown(() {
      link.dispose();
      link.form.dispose();
    });
  });

  test('starts from the draft, named "New thing"', () {
    expect(link.form.scheduledAt, at10);
    expect(link.form.durationMinutes, 30);
    expect(link.form.title.text, DraftFormLink.defaultName);
    expect(link.hasTypedName, isFalse);
  });

  test('picking a time or length in the form moves the pill', () {
    link.form.setSchedule(at11, 45);

    final draft = container.read(pendingTaskDraftProvider)!;
    expect(draft.scheduledAt, at11);
    expect(draft.durationMinutes, 45);
  });

  test('dragging the pill updates the form', () {
    final moved = PendingTaskDraft(
      id: link.draftId,
      scheduledAt: at11,
      durationMinutes: 60,
    );
    link.follow(moved);

    expect(link.form.scheduledAt, at11);
    expect(link.form.durationMinutes, 60);
  });

  test('first focus clears the default name; a typed name counts', () {
    link.clearDefaultName(true);
    expect(link.form.title.text, isEmpty);

    link.form.title.text = 'Walk';
    expect(link.hasTypedName, isTrue);
    link.clearDefaultName(true);
    expect(link.form.title.text, 'Walk');
  });
}
