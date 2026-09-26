/// Case-form write service: atomically persists case data and notification settings.
///
/// The form uses this boundary so a preference failure cannot leave a partially
/// saved case behind.
library;

import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../database/app_database.dart';
import '../../../features/settings/data/local/case_notification_preferences_dao.dart';
import 'case_repository.dart';

/// Coordinates an Add/Edit case write with its per-user notification preference.
class CaseFormRepository {
  /// Creates a form writer backed by the local database and case repository.
  CaseFormRepository(this.db, this._caseRepository);

  /// Database used for the encompassing transaction.
  final AppDatabase db;
  final TransactionalCaseRepository _caseRepository;

  /// Saves the case and notification preference as one local transaction.
  ///
  /// [notificationTimeMinutes] is the case's own alert time; null means the
  /// case follows the user's default time in Settings → Notifications.
  Future<String> save({
    required CasesCompanion companion,
    required Case? initialCase,
    required String userId,
    required bool notificationEnabled,
    required List<int> notificationOffsets,
    int? notificationTimeMinutes,
    required int updatedAt,
  }) async {
    return db.transaction(() async {
      final id = initialCase == null
          ? await _caseRepository.insertCaseInTransaction(companion)
          : initialCase.id;

      if (initialCase != null) {
        await _caseRepository.updateCaseInTransaction(
          companion,
          baseCase: initialCase,
        );
      }

      await CaseNotificationPreferencesDao(db).upsert(
        CaseNotificationPreferencesCompanion(
          userId: Value(userId),
          caseId: Value(id),
          enabled: Value(notificationEnabled),
          offsets: Value(jsonEncode(notificationOffsets)),
          timeMinutes: Value(notificationTimeMinutes),
          updatedAt: Value(updatedAt),
        ),
      );
      return id;
    });
  }
}
