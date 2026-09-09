// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'armed_edit_task_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The single task id currently "armed" for editing via a long-press —
/// requested directly: "long press on task should enable its edit mode
/// (duration) wiggle, tapping outside closes that mode, keep single tap to
/// open edit sheet."
///
/// Deliberately separate from [EditModeEnabled] (`edit_mode_provider.dart`)
/// rather than reusing it — that provider is a single GLOBAL switch which,
/// once on, wiggles every task on the Timeline at once via its own toolbar
/// button. This is the opposite shape: exactly one task (or none) is armed
/// at a time, entered by long-pressing that one task specifically, and the
/// rest of the Timeline stays in its ordinary single-tap-opens-sheet state
/// throughout — confirmed via AskUserQuestion as new, per-task behavior,
/// not a second way to trigger the existing global toggle.
///
/// Screen-local, ephemeral UI state — same reasoning and shape as
/// [EditModeEnabled]/[EditSelection]: plain `autoDispose`, never persisted,
/// so a returning user always lands on the ordinary Timeline rather than
/// reopening with a task still armed.

@ProviderFor(ArmedEditTask)
final armedEditTaskProvider = ArmedEditTaskProvider._();

/// The single task id currently "armed" for editing via a long-press —
/// requested directly: "long press on task should enable its edit mode
/// (duration) wiggle, tapping outside closes that mode, keep single tap to
/// open edit sheet."
///
/// Deliberately separate from [EditModeEnabled] (`edit_mode_provider.dart`)
/// rather than reusing it — that provider is a single GLOBAL switch which,
/// once on, wiggles every task on the Timeline at once via its own toolbar
/// button. This is the opposite shape: exactly one task (or none) is armed
/// at a time, entered by long-pressing that one task specifically, and the
/// rest of the Timeline stays in its ordinary single-tap-opens-sheet state
/// throughout — confirmed via AskUserQuestion as new, per-task behavior,
/// not a second way to trigger the existing global toggle.
///
/// Screen-local, ephemeral UI state — same reasoning and shape as
/// [EditModeEnabled]/[EditSelection]: plain `autoDispose`, never persisted,
/// so a returning user always lands on the ordinary Timeline rather than
/// reopening with a task still armed.
final class ArmedEditTaskProvider
    extends $NotifierProvider<ArmedEditTask, String?> {
  /// The single task id currently "armed" for editing via a long-press —
  /// requested directly: "long press on task should enable its edit mode
  /// (duration) wiggle, tapping outside closes that mode, keep single tap to
  /// open edit sheet."
  ///
  /// Deliberately separate from [EditModeEnabled] (`edit_mode_provider.dart`)
  /// rather than reusing it — that provider is a single GLOBAL switch which,
  /// once on, wiggles every task on the Timeline at once via its own toolbar
  /// button. This is the opposite shape: exactly one task (or none) is armed
  /// at a time, entered by long-pressing that one task specifically, and the
  /// rest of the Timeline stays in its ordinary single-tap-opens-sheet state
  /// throughout — confirmed via AskUserQuestion as new, per-task behavior,
  /// not a second way to trigger the existing global toggle.
  ///
  /// Screen-local, ephemeral UI state — same reasoning and shape as
  /// [EditModeEnabled]/[EditSelection]: plain `autoDispose`, never persisted,
  /// so a returning user always lands on the ordinary Timeline rather than
  /// reopening with a task still armed.
  ArmedEditTaskProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'armedEditTaskProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$armedEditTaskHash();

  @$internal
  @override
  ArmedEditTask create() => ArmedEditTask();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$armedEditTaskHash() => r'ea4f5ad0b441968f13c38154f9fcc699e98e162d';

/// The single task id currently "armed" for editing via a long-press —
/// requested directly: "long press on task should enable its edit mode
/// (duration) wiggle, tapping outside closes that mode, keep single tap to
/// open edit sheet."
///
/// Deliberately separate from [EditModeEnabled] (`edit_mode_provider.dart`)
/// rather than reusing it — that provider is a single GLOBAL switch which,
/// once on, wiggles every task on the Timeline at once via its own toolbar
/// button. This is the opposite shape: exactly one task (or none) is armed
/// at a time, entered by long-pressing that one task specifically, and the
/// rest of the Timeline stays in its ordinary single-tap-opens-sheet state
/// throughout — confirmed via AskUserQuestion as new, per-task behavior,
/// not a second way to trigger the existing global toggle.
///
/// Screen-local, ephemeral UI state — same reasoning and shape as
/// [EditModeEnabled]/[EditSelection]: plain `autoDispose`, never persisted,
/// so a returning user always lands on the ordinary Timeline rather than
/// reopening with a task still armed.

abstract class _$ArmedEditTask extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String?, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String?, String?>,
              String?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
