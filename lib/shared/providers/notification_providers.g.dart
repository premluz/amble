// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The plugin instance and [NotificationService] are both app-lifetime
/// singletons — [NotificationService.initialize] is called once from
/// `main.dart` before this provider is ever read, and permission state
/// (`_permissionRequested`) needs to persist for the whole session, not
/// per-screen. See [TaskList] in task_providers.dart for where scheduling
/// is actually triggered from.

@ProviderFor(notificationService)
final notificationServiceProvider = NotificationServiceProvider._();

/// The plugin instance and [NotificationService] are both app-lifetime
/// singletons — [NotificationService.initialize] is called once from
/// `main.dart` before this provider is ever read, and permission state
/// (`_permissionRequested`) needs to persist for the whole session, not
/// per-screen. See [TaskList] in task_providers.dart for where scheduling
/// is actually triggered from.

final class NotificationServiceProvider
    extends
        $FunctionalProvider<
          NotificationService,
          NotificationService,
          NotificationService
        >
    with $Provider<NotificationService> {
  /// The plugin instance and [NotificationService] are both app-lifetime
  /// singletons — [NotificationService.initialize] is called once from
  /// `main.dart` before this provider is ever read, and permission state
  /// (`_permissionRequested`) needs to persist for the whole session, not
  /// per-screen. See [TaskList] in task_providers.dart for where scheduling
  /// is actually triggered from.
  NotificationServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationServiceHash();

  @$internal
  @override
  $ProviderElement<NotificationService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  NotificationService create(Ref ref) {
    return notificationService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NotificationService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NotificationService>(value),
    );
  }
}

String _$notificationServiceHash() =>
    r'fef1de0f52c3705f4d53793e276614864862bc29';
