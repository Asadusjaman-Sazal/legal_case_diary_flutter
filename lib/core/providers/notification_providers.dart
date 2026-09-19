/// Providers for the notification scheduler.
///
/// The app root, the Notifications settings screen and the OEM setup guide all
/// reach the platform through this provider, so no call site imports an
/// Android-only package (Task 13 Phase 1).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../notifications/android_notification_scheduler.dart';
import '../notifications/notification_scheduler.dart';
import 'repository_providers.dart';

/// The platform notification scheduler.
///
/// Reads settings through [settingsRepositoryProvider] on every call so a
/// preference changed elsewhere is always the one the alarm is armed with.
final notificationSchedulerProvider = Provider<NotificationScheduler>((ref) {
  return AndroidNotificationScheduler(
    readSettings: () async {
      final repo = await ref.read(settingsRepositoryProvider.future);
      return repo.getSettings();
    },
  );
});
