import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/app_undo_toast.dart';
import '../../shared/providers/assistant_providers.dart';
import '../../shared/services/assistant/assistant_activity.dart';

/// Shows "Claude added … · Undo" whenever a connected assistant changes the
/// plan, so nothing changes unseen. Wraps the app's home, below the
/// Navigator, where the toast's overlay lives.
class AssistantUndoToaster extends ConsumerStatefulWidget {
  const AssistantUndoToaster({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AssistantUndoToaster> createState() =>
      _AssistantUndoToasterState();
}

class _AssistantUndoToasterState extends ConsumerState<AssistantUndoToaster> {
  late final AssistantActivityLog _activity = ref.read(
    assistantActivityProvider,
  );

  void _show(AssistantActivity entry) {
    if (!mounted) return;
    AppUndoToast.show(
      context: context,
      message: 'Claude: ${entry.summary}',
      onUndo: entry.undo == null ? null : () => _activity.undo(entry),
    );
  }

  @override
  void initState() {
    super.initState();
    _activity.addListener(_show);
  }

  @override
  void dispose() {
    _activity.removeListener(_show);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
