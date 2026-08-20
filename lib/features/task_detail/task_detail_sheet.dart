import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_slider.dart';
import '../../shared/models/task.dart';
import '../../shared/models/task_category.dart';
import '../../shared/providers/task_providers.dart';
import '../timeline/task_category_token_mapping.dart';

const _minDurationMinutes = 5;
const _maxDurationMinutes = 120;
const _durationStepMinutes = 5;

/// Opens the task detail screen for creating a new task at
/// [initialScheduledAt], or editing [task] if provided. Presented as a
/// near-full-screen modal (not [AppSheet]'s partial-height bottom sheet —
/// this screen's colored, edge-to-edge header doesn't fit that contract).
/// All writes go through [taskListProvider] — this UI never touches the
/// repository or Hive directly.
Future<void> showTaskDetailSheet(
  BuildContext context, {
  Task? task,
  DateTime? initialScheduledAt,
}) {
  return Navigator.of(context).push<void>(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.transparent,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) => TaskDetailForm(
        task: task,
        initialScheduledAt: initialScheduledAt ?? DateTime.now(),
      ),
    ),
  );
}

class TaskDetailForm extends ConsumerStatefulWidget {
  const TaskDetailForm({
    super.key,
    this.task,
    required this.initialScheduledAt,
  });

  final Task? task;
  final DateTime initialScheduledAt;

  @override
  ConsumerState<TaskDetailForm> createState() => _TaskDetailFormState();
}

class _TaskDetailFormState extends ConsumerState<TaskDetailForm> {
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late DateTime _scheduledAt;
  late int _durationMinutes;
  late TaskCategory _category;

  final _stickyButtonKey = GlobalKey();
  double _stickyButtonReservedHeight = 96;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    _titleController = TextEditingController(text: task?.title ?? '');
    _notesController = TextEditingController(text: task?.notes ?? '');
    _scheduledAt = task?.scheduledAt ?? widget.initialScheduledAt;
    _durationMinutes = task?.durationMinutes ?? 30;
    _category = task?.category ?? TaskCategory.personal;
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureStickyButton());
  }

  // The floating Continue button's exact rendered height (including
  // Scaffold's own FAB margin) isn't knowable in advance — measured after
  // first layout so the scroll content can reserve exactly enough space
  // to never sit underneath it, rather than guessing at Flutter's internal
  // FAB margin constants.
  void _measureStickyButton() {
    final box =
        _stickyButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !mounted) return;
    final height = box.size.height + kFloatingActionButtonMargin * 2;
    if (height != _stickyButtonReservedHeight) {
      setState(() => _stickyButtonReservedHeight = height);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final notes = _notesController.text.trim();
    final notifier = ref.read(taskListProvider.notifier);
    final existing = widget.task;

    if (existing == null) {
      await notifier.createTask(
        title: title,
        notes: notes.isEmpty ? null : notes,
        scheduledAt: _scheduledAt,
        durationMinutes: _durationMinutes,
        category: _category,
      );
    } else {
      existing.title = title;
      existing.notes = notes.isEmpty ? null : notes;
      existing.scheduledAt = _scheduledAt;
      existing.durationMinutes = _durationMinutes;
      existing.category = _category;
      await notifier.updateTask(existing);
    }

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null) return;
    setState(() {
      _scheduledAt = DateTime(
        date.year,
        date.month,
        date.day,
        _scheduledAt.hour,
        _scheduledAt.minute,
      );
    });
  }

  void _setTimeOfDay(TimeOfDay time) {
    setState(() {
      _scheduledAt = DateTime(
        _scheduledAt.year,
        _scheduledAt.month,
        _scheduledAt.day,
        time.hour,
        time.minute,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final categoryColor = theme.categoryColors[_category.token]!;
    final endTime = _scheduledAt.add(Duration(minutes: _durationMinutes));

    return Scaffold(
      backgroundColor: theme.colorSurfaceTimeline,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            top: theme.spacingMd,
            bottom: theme.spacingMd,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(theme.radiusSheet),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: categoryColor,
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(theme.radiusSheet),
                    ),
                  ),
                  padding: EdgeInsets.fromLTRB(
                    theme.spacingLg,
                    theme.spacingMd,
                    theme.spacingLg,
                    theme.spacingLg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: theme.spacingXl,
                          height: theme.spacingXl,
                          decoration: BoxDecoration(
                            color: theme.colorSurfacePrimary.withValues(
                              alpha: 0.3,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            color: theme.colorSurfacePrimary,
                          ),
                        ),
                      ),
                      SizedBox(height: theme.spacingMd),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_formatTime(_scheduledAt)} – '
                            '${_formatTime(endTime)} '
                            '($_durationMinutes min)',
                            style: theme.textCaption.copyWith(
                              color: theme.colorSurfacePrimary.withValues(
                                alpha: 0.85,
                              ),
                            ),
                          ),
                          TextField(
                            controller: _titleController,
                            autofocus: widget.task == null,
                            style: theme.textHeadline.copyWith(
                              color: theme.colorSurfacePrimary,
                            ),
                            cursorColor: theme.colorSurfacePrimary,
                            decoration: InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: theme.colorSurfacePrimary.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: theme.colorSurfacePrimary,
                                ),
                              ),
                              hintText: 'Task name',
                              hintStyle: theme.textHeadline.copyWith(
                                color: theme.colorSurfacePrimary.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    color: theme.colorSurfaceTimeline,
                    child: Stack(
                      children: [
                        SingleChildScrollView(
                          padding: EdgeInsets.all(theme.spacingLg),
                          child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: theme.spacingXl * 1.5,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: TaskCategory.values.length,
                              separatorBuilder: (context, index) =>
                                  SizedBox(width: theme.spacingLg),
                              itemBuilder: (context, index) {
                                final category = TaskCategory.values[index];
                                return _CategoryTag(
                                  category: category,
                                  selected: category == _category,
                                  onSelected: () =>
                                      setState(() => _category = category),
                                );
                              },
                            ),
                          ),
                          SizedBox(height: theme.spacingMd),
                          _Panel(
                            theme: theme,
                            child: InkWell(
                              onTap: _pickDate,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today_rounded,
                                    color: theme.colorTextSecondary,
                                    size: theme.spacingLg,
                                  ),
                                  SizedBox(width: theme.spacingSm),
                                  Expanded(
                                    child: Text(
                                      _formatDate(_scheduledAt),
                                      style: theme.textBody.copyWith(
                                        color: theme.colorTextPrimary,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    color: theme.colorTextSecondary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: theme.spacingMd),
                          Text(
                            'Time',
                            style: theme.textTitle.copyWith(
                              color: theme.colorTextPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: theme.spacingSm),
                          _Panel(
                            theme: theme,
                            padding: EdgeInsets.zero,
                            child: _TimeScroller(
                              theme: theme,
                              value: TimeOfDay.fromDateTime(_scheduledAt),
                              onChanged: _setTimeOfDay,
                            ),
                          ),
                          SizedBox(height: theme.spacingMd),
                          Text(
                            'Duration',
                            style: theme.textTitle.copyWith(
                              color: theme.colorTextPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: theme.spacingSm),
                          _Panel(
                            theme: theme,
                            child: Column(
                              children: [
                                Text(
                                  '$_durationMinutes min',
                                  style: theme.textTitle.copyWith(
                                    color: theme.colorTextPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                AppSlider(
                                  value: _durationMinutes.toDouble(),
                                  min: _minDurationMinutes.toDouble(),
                                  max: _maxDurationMinutes.toDouble(),
                                  divisions:
                                      (_maxDurationMinutes -
                                          _minDurationMinutes) ~/
                                      _durationStepMinutes,
                                  onChanged: (value) => setState(
                                    () => _durationMinutes = value.round(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: theme.spacingMd),
                          _Panel(
                            theme: theme,
                            child: TextField(
                              controller: _notesController,
                              style: theme.textBody.copyWith(
                                color: theme.colorTextPrimary,
                              ),
                              maxLines: 3,
                              decoration: const InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                hintText: 'Notes (optional)',
                              ),
                            ),
                          ),
                          // Reserves exactly the sticky Continue button's
                          // measured height (see _measureStickyButton) so
                          // the last scrollable item never sits under it.
                          SizedBox(height: _stickyButtonReservedHeight),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: theme.spacingLg),
          child: SizedBox(
            key: _stickyButtonKey,
            width: double.infinity,
            child: AppButton(
              label: 'Continue',
              size: AppButtonSize.large,
              shape: AppButtonShape.pill,
              onPressed: _save,
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.theme, required this.child, this.padding});

  final AmbleTheme theme;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? EdgeInsets.all(theme.spacingMd),
      decoration: BoxDecoration(
        color: theme.colorSurfacePrimary,
        borderRadius: BorderRadius.circular(theme.radiusSheet),
      ),
      child: child,
    );
  }
}

class _CategoryTag extends StatelessWidget {
  const _CategoryTag({
    required this.category,
    required this.selected,
    required this.onSelected,
  });

  final TaskCategory category;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final categoryColor = theme.categoryColors[category.token]!;
    final circleSize = theme.spacingXl * 1.5;

    return GestureDetector(
      onTap: onSelected,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: circleSize,
            height: circleSize,
            decoration: BoxDecoration(
              color: categoryColor.withValues(alpha: 0.25),
              shape: BoxShape.circle,
              border: selected
                  ? Border.all(
                      color: categoryColor,
                      width: theme.borderWidthHairline * 1.5,
                    )
                  : null,
            ),
            child: Icon(category.icon, color: categoryColor),
          ),
          SizedBox(width: theme.spacingSm),
          Text(
            category.label,
            style: theme.textBody.copyWith(
              color: theme.colorTextPrimary,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

const _timeScrollerItemExtent = 56.0;
const _timeScrollerStepMinutes = 15;
const _timeScrollerVisibleCount = 3;

class _TimeScroller extends StatefulWidget {
  const _TimeScroller({
    required this.theme,
    required this.value,
    required this.onChanged,
  });

  final AmbleTheme theme;
  final TimeOfDay value;
  final ValueChanged<TimeOfDay> onChanged;

  @override
  State<_TimeScroller> createState() => _TimeScrollerState();
}

class _TimeScrollerState extends State<_TimeScroller> {
  late final FixedExtentScrollController _controller;

  int get _slotsPerDay => (24 * 60) ~/ _timeScrollerStepMinutes;

  int _slotFor(TimeOfDay time) =>
      (time.hour * 60 + time.minute) ~/ _timeScrollerStepMinutes;

  TimeOfDay _timeFor(int slot) {
    final minutes = (slot % _slotsPerDay) * _timeScrollerStepMinutes;
    return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
  }

  @override
  void initState() {
    super.initState();
    _controller = FixedExtentScrollController(
      initialItem: _slotFor(widget.value),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final height = _timeScrollerItemExtent * _timeScrollerVisibleCount;

    return SizedBox(
      height: height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ListWheelScrollView.useDelegate(
            controller: _controller,
            itemExtent: _timeScrollerItemExtent,
            perspective: 0.004,
            diameterRatio: 1.8,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: (index) => widget.onChanged(_timeFor(index)),
            childDelegate: ListWheelChildBuilderDelegate(
              builder: (context, index) {
                if (index < 0) return null;
                final time = _timeFor(index);
                final isSelected = index == _slotFor(widget.value);
                return Center(
                  child: isSelected
                      ? Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: theme.spacingXl * 1.25,
                            vertical: theme.spacingSm * 1.25,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorAccent,
                            borderRadius: BorderRadius.circular(
                              theme.radiusTaskPill,
                            ),
                          ),
                          child: Text(
                            _formatTimeOfDay(time),
                            style: theme.textHeadline.copyWith(
                              color: theme.colorSurfacePrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      : Text(
                          _formatTimeOfDay(time),
                          style: theme.textBody.copyWith(
                            color: theme.colorTextSecondary,
                          ),
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime dateTime) {
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final weekday = weekdays[dateTime.weekday - 1];
  final month = months[dateTime.month - 1];
  return '$weekday $month ${dateTime.day}, ${dateTime.year}';
}

String _formatTimeOfDay(TimeOfDay time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _formatTime(DateTime dateTime) {
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
