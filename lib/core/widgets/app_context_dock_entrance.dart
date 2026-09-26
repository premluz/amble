part of 'app_context_dock.dart';

extension _DockEntrance on _AppContextDockState {
  void _scheduleEntrance(int generation) {
    for (final timer in _entranceTimers) {
      timer.cancel();
    }
    _entranceTimers.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _transitionGeneration) return;
      final incoming = _entries.values
          .where((entry) => entry.present && entry.entering)
          .toList();
      final reduced = MediaQuery.disableAnimationsOf(context);
      final outgoing = _entries.values.where((entry) => !entry.present).toList();
      for (var index = 0; index < outgoing.length; index++) {
        final entry = outgoing[index];
        if (reduced || index == 0) {
          _hideEntry(entry, generation);
        } else {
          _entranceTimers.add(Timer(Duration(milliseconds:
            index * MotionPrimitives.durationContextDockStaggerMs),
            () => _hideEntry(entry, generation)));
        }
      }
      for (var index = 0; index < incoming.length; index++) {
        final entry = incoming[index];
        final delay = Duration(
          milliseconds: reduced ? 0 : index * MotionPrimitives.durationContextDockStaggerMs,
        );
        if (delay == Duration.zero) {
          _revealEntry(entry, generation);
        } else {
          _entranceTimers.add(Timer(delay, () => _revealEntry(entry, generation)));
        }
      }
    });
  }

}
