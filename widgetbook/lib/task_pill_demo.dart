import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/timeline/external_event_capsule_block.dart';
import 'package:amble/features/timeline/pending_task_pill.dart';
import 'package:amble/features/timeline/task_capsule_block.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/external_calendar_event.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/task_status.dart';
import 'package:flutter/material.dart';

/// Matches the Timeline's own default scale, so pills read at real size.
const _pixelsPerMinute = 1.5;
const _demoMinutes = 60;
final _nine = DateTime(2026, 9, 28, 9);

/// A real label and the unlabeled "General", so pills resolve their actual
/// colours instead of the neutral "category still loading" fallback.
final _work = Category(
  id: BuiltInCategoryIds.work,
  name: 'Work',
  colorToken: 4,
  emoji: '',
  isBuiltIn: true,
);
final _general = Category(
  id: BuiltInCategoryIds.general,
  name: 'General',
  colorToken: 0,
  emoji: '',
  isBuiltIn: true,
);

Task _task(
  String title, {
  bool important = false,
  bool done = false,
  Category? category,
}) => Task.create(
  title: title,
  scheduledAt: _nine,
  durationMinutes: _demoMinutes,
  categoryId: (category ?? _work).id,
  isImportant: important,
)..status = done ? TaskStatus.completed : TaskStatus.pending;

Widget _pill(Task task, {bool selected = false}) => TaskCapsuleBlock(
  task: task,
  category: task.categoryId == _general.id ? _general : _work,
  isSelected: selected,
);

/// Every task-pill state side by side: the brand's task state grammar.
Widget taskPillGalleryDemo(BuildContext context) {
  final theme = Theme.of(context).extension<AmbleTheme>()!;
  return _Page(
    theme: theme,
    children: [
      _Labeled('Normal', _pill(_task('Deep work'))),
      _Labeled(
        'Unlabeled (new task, no label yet)',
        _pill(_task('New task', category: _general)),
      ),
      _Labeled('Important', _pill(_task('Doctor', important: true))),
      _Labeled('Completed', _pill(_task('Gym', done: true))),
      _Labeled(
        'Completed, unlabeled',
        _pill(_task('Call back', done: true, category: _general)),
      ),
      _Labeled(
        'Completed, important',
        _pill(_task('Doctor', important: true, done: true)),
      ),
      _Labeled('Selected', _pill(_task('Deep work'), selected: true)),
      _Labeled('Imported', _Positioned(child: _imported(theme))),
      _Labeled('Draft (unsaved)', _Positioned(child: _draft(theme))),
    ],
  );
}

/// Tap to select, check (or swipe left) to complete: the liquid select
/// pulse, the stronger completion pulse, the ripple and the bubbles.
Widget taskPillInteractiveDemo(BuildContext context) =>
    const _InteractivePill();

/// Replays a new draft's dot-to-line entrance.
Widget taskPillDraftDemo(BuildContext context) => const _DraftReplay();

class _InteractivePill extends StatefulWidget {
  const _InteractivePill();

  @override
  State<_InteractivePill> createState() => _InteractivePillState();
}

class _InteractivePillState extends State<_InteractivePill> {
  final _pillTask = _task('Tap me, then check me');
  var _selected = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    return _Page(
      theme: theme,
      children: [
        TaskCapsuleBlock(
          task: _pillTask,
          category: _work,
          isSelected: _selected,
          onTap: () => setState(() => _selected = !_selected),
          onToggleComplete: () => setState(() {
            _pillTask.status = _pillTask.status == TaskStatus.completed
                ? TaskStatus.pending
                : TaskStatus.completed;
          }),
        ),
      ],
    );
  }
}

class _DraftReplay extends StatefulWidget {
  const _DraftReplay();

  @override
  State<_DraftReplay> createState() => _DraftReplayState();
}

class _DraftReplayState extends State<_DraftReplay> {
  var _generation = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    return _Page(
      theme: theme,
      children: [
        _Positioned(child: _draft(theme, key: ValueKey(_generation))),
        TextButton(
          onPressed: () => setState(() => _generation++),
          child: Text('Drop again', style: theme.textBody),
        ),
      ],
    );
  }
}

Widget _imported(AmbleTheme theme) => ExternalEventCapsuleBlock(
  theme: theme,
  event: ExternalCalendarEvent(
    id: 'demo',
    title: 'Team sync',
    start: _nine,
    end: _nine.add(const Duration(minutes: _demoMinutes)),
    sourceCalendarId: 'demo',
  ),
  rangeStart: _nine,
  pixelsPerMinute: _pixelsPerMinute,
  left: 0,
  columnOffset: 0,
  textColumnLeft: theme.sizeTaskBadge + theme.spacingSm,
  textColumnRight: 0,
);

Widget _draft(AmbleTheme theme, {Key? key}) => PendingTaskPill(
  key: key,
  theme: theme,
  top: 0,
  left: 0,
  columnOffset: 0,
  width: theme.sizeTaskBadge,
  height: _demoMinutes * _pixelsPerMinute,
  startTime: TimeOfDay.fromDateTime(_nine),
  endTime: TimeOfDay.fromDateTime(
    _nine.add(const Duration(minutes: _demoMinutes)),
  ),
  textColumnLeft: theme.sizeTaskBadge + theme.spacingSm,
  textColumnRight: 0,
  onMoveStart: (_) {},
  onMoveUpdate: (_) {},
  onMoveEnd: () {},
  onResizeStart: (_) {},
  onResizeUpdate: (_) {},
  onResizeEnd: () {},
  onResizeTopStart: (_) {},
  onResizeTopUpdate: (_) {},
  onResizeTopEnd: () {},
);

/// Imported and draft pills position themselves; give them a Stack of the
/// pill's own height.
class _Positioned extends StatelessWidget {
  const _Positioned({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: _demoMinutes * _pixelsPerMinute,
    child: Stack(clipBehavior: Clip.none, children: [child]),
  );
}

class _Labeled extends StatelessWidget {
  const _Labeled(this.label, this.child);

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textCaption),
        SizedBox(height: theme.spacingXs),
        child,
      ],
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({required this.theme, required this.children});

  final AmbleTheme theme;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: theme.colorSurfaceBase,
    child: ListView.separated(
      padding: EdgeInsets.all(theme.spacingScreenPadding),
      itemCount: children.length,
      separatorBuilder: (_, _) => SizedBox(height: theme.spacingLg),
      itemBuilder: (_, index) => children[index],
    ),
  );
}
