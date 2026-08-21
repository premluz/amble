// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_tap_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The task id from a notification tap (foreground response or cold-start
/// launch — both funnel through [NotificationService]/`main.dart` into this
/// provider), waiting to be consumed by the UI. `AmbleHome` watches this,
/// switches to the Timeline tab, jumps to the task's day, and clears it via
/// [NotificationTap.consume] so the same tap doesn't re-trigger navigation
/// on a later rebuild.

@ProviderFor(NotificationTap)
final notificationTapProvider = NotificationTapProvider._();

/// The task id from a notification tap (foreground response or cold-start
/// launch — both funnel through [NotificationService]/`main.dart` into this
/// provider), waiting to be consumed by the UI. `AmbleHome` watches this,
/// switches to the Timeline tab, jumps to the task's day, and clears it via
/// [NotificationTap.consume] so the same tap doesn't re-trigger navigation
/// on a later rebuild.
final class NotificationTapProvider
    extends $NotifierProvider<NotificationTap, String?> {
  /// The task id from a notification tap (foreground response or cold-start
  /// launch — both funnel through [NotificationService]/`main.dart` into this
  /// provider), waiting to be consumed by the UI. `AmbleHome` watches this,
  /// switches to the Timeline tab, jumps to the task's day, and clears it via
  /// [NotificationTap.consume] so the same tap doesn't re-trigger navigation
  /// on a later rebuild.
  NotificationTapProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationTapProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationTapHash();

  @$internal
  @override
  NotificationTap create() => NotificationTap();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$notificationTapHash() => r'f1ae7bbe1c18d327fbef6eb1994a9c4b2c98558c';

/// The task id from a notification tap (foreground response or cold-start
/// launch — both funnel through [NotificationService]/`main.dart` into this
/// provider), waiting to be consumed by the UI. `AmbleHome` watches this,
/// switches to the Timeline tab, jumps to the task's day, and clears it via
/// [NotificationTap.consume] so the same tap doesn't re-trigger navigation
/// on a later rebuild.

abstract class _$NotificationTap extends $Notifier<String?> {
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
