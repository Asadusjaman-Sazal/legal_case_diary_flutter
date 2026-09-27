/// Providers for the notification scheduler.
///
/// The app root, the Notifications settings screen and the OEM setup guide all
/// reach the platform through this provider, so no call site imports an
/// Android-only package (Task 13 Phase 1).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/data/local/case_notification_preferences_dao.dart';
import '../../shared/providers/database_provider.dart';
import '../notifications/android_notification_scheduler.dart';
import '../notifications/notification_scheduler.dart';
import '../services/local_identity_service.dart';
import 'repository_providers.dart';

/// The platform notification scheduler.
///
/// Reads settings and the per-case Notification Time overrides on every call so
/// a preference changed elsewhere is always what the alarms are armed with.
final notificationSchedulerProvider = Provider<NotificationScheduler>((ref) {
  return AndroidNotificationScheduler(
    readSettings: () async {
      final repo = await ref.read(settingsRepositoryProvider.future);
      return repo.getSettings();
    },
    readCaseTimes: () async {
      final db = await ref.read(databaseProvider.future);
      final identity = ref.read(localIdentityServiceProvider);
      final rows = await CaseNotificationPreferencesDao(
        db,
      ).getByUserId(identity.getId());
      // Only the cases that may alert: a case the user switched off never does,
      // whatever Settings → Notifications' default is, so its slot — its own
      // time, or the default when it follows that — must not be armed.
      return [
        for (final row in rows)
          if (row.enabled) row.timeMinutes,
      ];
    },
  );
});
