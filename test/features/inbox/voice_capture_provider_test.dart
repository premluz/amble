import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/features/inbox/voice_capture_provider.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/providers/category_providers.dart';
import 'package:amble/shared/providers/task_providers.dart';
import 'package:amble/shared/repositories/hive_category_repository.dart';
import 'package:amble/shared/providers/notification_providers.dart';
import 'package:amble/shared/repositories/hive_task_repository.dart';

import '../../support/fake_notification_service.dart';
import '../../support/seeded_category_box.dart';

SpeechRecognitionResult _result(String words, {bool isFinal = true}) {
  return SpeechRecognitionResult([
    SpeechRecognitionWords(words, null, -1),
  ], isFinal ? ResultType.finalResult.value : ResultType.partial.value);
}

/// Covers [VoiceCapture]'s state machine and, per direct confirmation
/// this session, its reuse of the SAME task-creation path Quick Capture
/// already uses (`quick_capture_sheet.dart`'s own `_submit`) — every
/// segment goes through `parseQuickCapture` and
/// `TaskList.createTask`/`captureTask` exactly as a typed capture would.
///
/// [VoiceCapture.startListening]/[pause]/[resume] are NOT exercised here:
/// they drive a real `speech_to_text` platform channel with no mock
/// registered in this test environment — the same constraint
/// `quick_capture_sheet_test.dart` already works around by never calling
/// `_speech.listen` directly either. [submit]'s own logic is tested via
/// [VoiceCapture.debugSetCommittedSegments], a `@visibleForTesting` seam
/// added specifically because the real segment list only ever grows
/// through that live session.
void main() {
  late Box<Task> box;
  late Box<Category> categoryBox;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_voice_capture');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapters();
    }
    final stamp = DateTime.now().microsecondsSinceEpoch;
    box = await Hive.openBox<Task>('test_tasks_$stamp');
    categoryBox = await openSeededCategoryBox('test_categories_$stamp');
  });

  tearDown(() async {
    await box.close();
    await categoryBox.close();
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        taskRepositoryProvider.overrideWithValue(HiveTaskRepository(box)),
        categoryRepositoryProvider.overrideWithValue(
          HiveCategoryRepository(categoryBox),
        ),
        notificationServiceProvider.overrideWithValue(
          FakeNotificationService(),
        ),
      ],
    );
    addTearDown(container.dispose);
    // `voiceCaptureProvider` is `autoDispose` (screen-local session state
    // — see its own doc comment), so with nothing watching it the
    // container disposes it the instant the microtask after each `read`
    // finishes. A real screen keeps it alive by watching it in `build()`
    // for as long as the screen is mounted; this listener is that same
    // keep-alive, scoped to the test.
    container.listen(voiceCaptureProvider, (_, _) {});
    return container;
  }

  test('starts idle, empty, and not submittable', () {
    final container = makeContainer();
    final state = container.read(voiceCaptureProvider);

    expect(state.status, VoiceCaptureStatus.idle);
    expect(state.committedSegments, isEmpty);
    expect(state.canSubmit, isFalse);
  });

  test('canSubmit turns true once a segment exists', () {
    final container = makeContainer();
    container.read(voiceCaptureProvider.notifier).debugSetCommittedSegments([
      'Call John',
    ]);

    expect(container.read(voiceCaptureProvider).canSubmit, isTrue);
  });

  test('submit creates one task per committed segment, in order, via the '
      'same parseQuickCapture + createTask/captureTask path Quick Capture '
      'uses', () async {
    final container = makeContainer();
    container.read(voiceCaptureProvider.notifier).debugSetCommittedSegments([
      'Call John',
      'Book the flight',
    ]);

    await container.read(voiceCaptureProvider.notifier).submit();

    final tasks = container.read(taskListProvider);
    expect(tasks.length, 2);
    expect(
      tasks.map((t) => t.title),
      containsAll(['Call John', 'Book the flight']),
    );
  });

  test('a segment with a confident date/time anchor is scheduled, not '
      'left as a bare Inbox capture', () async {
    final container = makeContainer();
    container.read(voiceCaptureProvider.notifier).debugSetCommittedSegments([
      'Call John tomorrow at 3pm',
    ]);

    await container.read(voiceCaptureProvider.notifier).submit();

    final tasks = container.read(taskListProvider);
    expect(tasks.length, 1);
    expect(
      tasks.single.scheduledAt,
      isNotNull,
      reason:
          'a confident parse must schedule the task, matching what '
          'typing the same text into Quick Capture would do',
    );
  });

  test('submit resets state back to idle/empty afterwards', () async {
    final container = makeContainer();
    container.read(voiceCaptureProvider.notifier).debugSetCommittedSegments([
      'Call John',
    ]);

    await container.read(voiceCaptureProvider.notifier).submit();

    final state = container.read(voiceCaptureProvider);
    expect(state.status, VoiceCaptureStatus.idle);
    expect(state.committedSegments, isEmpty);
  });

  test('submit is a no-op with zero committed segments — nothing is '
      'created', () async {
    final container = makeContainer();

    await container.read(voiceCaptureProvider.notifier).submit();

    expect(container.read(taskListProvider), isEmpty);
  });

  group('a second, SHORTER utterance after the first segment commits', () {
    // Reported directly: "added note (it's spinning) confirmed added
    // note as spinner ends and then still listening but even if talking
    // not creating new note." The platform keeps delivering the running
    // session transcript on every callback (see `_onResult`'s own doc
    // comment) — `_committedText` tracks what's already been turned into
    // a segment so that re-delivered text isn't adopted a second time.
    // The guard compared it by raw STRING LENGTH
    // (`words.length <= _committedText.length`), which silently drops
    // any later utterance no longer than everything committed so far —
    // not just the platform's own stale re-delivery of already-committed
    // words.
    test('is recognized as new speech, not silently dropped', () {
      final container = makeContainer();
      final notifier = container.read(voiceCaptureProvider.notifier);
      notifier.debugSetListening();

      // First segment: a long sentence.
      notifier.debugFeedResult(
        _result('Reply to Laura\'s email about the quarterly report'),
      );
      notifier.debugCommitSegmentNow();
      expect(container.read(voiceCaptureProvider).committedSegments, [
        'Reply to Laura\'s email about the quarterly report',
      ]);

      // Second utterance: much shorter than the first — a real,
      // ordinary thing to say next, not an edge case.
      notifier.debugFeedResult(_result('Buy milk'));

      expect(
        container.read(voiceCaptureProvider).partialText,
        'Buy milk',
        reason:
            'a short second utterance must still surface as live '
            'partial text — the bug silently dropped it because its '
            'own length never exceeded the first (longer) committed '
            'segment\'s length',
      );
    });

    test('still becomes its own committed segment on the next silence gap', () {
      final container = makeContainer();
      final notifier = container.read(voiceCaptureProvider.notifier);
      notifier.debugSetListening();

      notifier.debugFeedResult(
        _result('Reply to Laura\'s email about the quarterly report'),
      );
      notifier.debugCommitSegmentNow();

      notifier.debugFeedResult(_result('Buy milk'));
      notifier.debugCommitSegmentNow();

      expect(container.read(voiceCaptureProvider).committedSegments, [
        'Reply to Laura\'s email about the quarterly report',
        'Buy milk',
      ]);
    });
  });

  test('a stale re-delivery of already-committed words is still ignored, not '
      're-adopted as a duplicate segment', () {
    // The other half of the same guard — removing the length check must
    // not reopen the original "duplicate the task" bug this guard
    // exists to prevent (see `_onResult`'s own doc comment).
    final container = makeContainer();
    final notifier = container.read(voiceCaptureProvider.notifier);
    notifier.debugSetListening();

    notifier.debugFeedResult(_result('Buy milk'));
    notifier.debugCommitSegmentNow();

    // The platform re-delivers the exact same transcript it already
    // committed — nothing new was said.
    notifier.debugFeedResult(_result('Buy milk'));

    expect(container.read(voiceCaptureProvider).partialText, isEmpty);
    expect(container.read(voiceCaptureProvider).committedSegments, [
      'Buy milk',
    ]);
  });
}
