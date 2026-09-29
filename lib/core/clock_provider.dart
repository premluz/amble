import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'clock_provider.g.dart';

/// Reads the current time. A function, not a value, so each read is live.
typedef Now = DateTime Function();

/// The one source of "now" for day-relative UI (today, the current-time
/// line, scroll-to-now). Tests override it with a fixed instant so a run
/// late in the evening doesn't push fixtures across midnight.
@Riverpod(keepAlive: true)
Now now(Ref ref) => DateTime.now;
