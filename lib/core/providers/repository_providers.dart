/// Central repository providers.
///
/// Each provider depends on the encrypted database and the sync write helper,
/// so ViewModels can watch a repository without knowing how it is constructed.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/case_reference/data/local/case_references_dao.dart';
import '../../features/case_reference/data/reference_repository.dart';
import '../../features/cases/data/case_history_repository.dart';
import '../../features/cases/data/case_repository.dart';
import '../../features/cases/data/local/case_history_dao.dart';
import '../../features/cases/data/local/cases_dao.dart';
import '../../features/notes/data/local/notes_dao.dart';
import '../../features/notes/data/notes_repository.dart';
import '../../features/settings/data/backup_repository.dart';
import '../../features/settings/data/case_types_repository.dart';
import '../../features/settings/data/court_categories_repository.dart';
import '../../features/settings/data/courts_repository.dart';
import '../../features/settings/data/delete_requests_repository.dart';
import '../../features/settings/data/local/case_types_dao.dart';
import '../../features/settings/data/local/court_categories_dao.dart';
import '../../features/settings/data/local/courts_dao.dart';
import '../../features/settings/data/local/on_behalfs_dao.dart';
import '../../features/settings/data/local/steps_dao.dart';
import '../../features/settings/data/local/user_preferences_dao.dart';
import '../../features/settings/data/on_behalfs_repository.dart';
import '../../features/settings/data/settings_repository.dart';
import '../../features/settings/data/steps_repository.dart';
import '../../sync/delete_requests_dao.dart';
import '../../sync/sync_write_helper.dart';
import '../../shared/providers/database_provider.dart';
import '../backup/backup_cipher.dart';
import '../services/local_identity_service.dart';

/// Provider for the public case repository interface.
final caseRepositoryProvider = FutureProvider<CaseRepository>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  final sync = await ref.watch(syncWriteHelperProvider.future);
  return LocalCaseRepository(CasesDao(db), CaseHistoryDao(db), sync);
});

/// Provider for [CaseHistoryRepository].
///
/// Consumed by the case detail screen's long-press history Edit/Delete flows;
/// automatic history creation still goes through [caseRepositoryProvider].
final caseHistoryRepositoryProvider = FutureProvider<CaseHistoryRepository>((
  ref,
) async {
  final db = await ref.watch(databaseProvider.future);
  final sync = await ref.watch(syncWriteHelperProvider.future);
  return LocalCaseHistoryRepository(CaseHistoryDao(db), sync);
});

/// Provider for the transaction-capable form-write boundary.
///
/// Normal case consumers depend only on [CaseRepository]; form persistence
/// opts into the local transaction contract explicitly through this provider.
final transactionalCaseRepositoryProvider =
    FutureProvider<TransactionalCaseRepository>((ref) async {
      final repository = await ref.watch(caseRepositoryProvider.future);
      if (repository case final TransactionalCaseRepository transactional) {
        return transactional;
      }
      throw StateError(
        'The configured case repository does not support local transactions',
      );
    });

/// Provider for [NotesRepository].
final notesRepositoryProvider = FutureProvider<NotesRepository>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  final sync = await ref.watch(syncWriteHelperProvider.future);
  return LocalNotesRepository(NotesDao(db), sync);
});

/// Provider for [ReferenceRepository].
final referenceRepositoryProvider = FutureProvider<ReferenceRepository>((
  ref,
) async {
  final db = await ref.watch(databaseProvider.future);
  final sync = await ref.watch(syncWriteHelperProvider.future);
  return LocalReferenceRepository(CaseReferencesDao(db), sync);
});

/// Provider for [SettingsRepository].
final settingsRepositoryProvider = FutureProvider<SettingsRepository>((
  ref,
) async {
  final db = await ref.watch(databaseProvider.future);
  final identity = ref.watch(localIdentityServiceProvider);
  return LocalSettingsRepository(UserPreferencesDao(db), identity);
});

/// Provider for the local backup export/restore engine.
///
/// The Backup & Restore screen owns the dialogs, the passphrase and the
/// confirmation; this repository owns the snapshot, the encryption and the
/// single import transaction (Task 15).
final backupRepositoryProvider = FutureProvider<BackupRepository>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return BackupRepository(db);
});

/// PBKDF2 iterations one backup export pays for.
///
/// Production always uses [kBackupKdfIterations]. The default stretch is
/// deliberately slow and yields to the event loop between batches, which the
/// fake clock of a widget test never advances — so widget tests override this
/// with a fast count and keep every other part of the export real.
final backupKdfIterationsProvider = Provider<int>(
  (ref) => kBackupKdfIterations,
);

/// Provider for [DeleteRequestsRepository].
final deleteRequestsRepositoryProvider =
    FutureProvider<DeleteRequestsRepository>((ref) async {
      final db = await ref.watch(databaseProvider.future);
      final sync = await ref.watch(syncWriteHelperProvider.future);
      return LocalDeleteRequestsRepository(DeleteRequestsDao(db), sync);
    });

/// Provider for [CourtCategoriesRepository].
final courtCategoriesRepositoryProvider =
    FutureProvider<CourtCategoriesRepository>((ref) async {
      final db = await ref.watch(databaseProvider.future);
      final sync = await ref.watch(syncWriteHelperProvider.future);
      return LocalCourtCategoriesRepository(CourtCategoriesDao(db), sync);
    });

/// Provider for [CourtsRepository].
final courtsRepositoryProvider = FutureProvider<CourtsRepository>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  final sync = await ref.watch(syncWriteHelperProvider.future);
  return LocalCourtsRepository(CourtsDao(db), sync);
});

/// Provider for [StepsRepository].
final stepsRepositoryProvider = FutureProvider<StepsRepository>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  final sync = await ref.watch(syncWriteHelperProvider.future);
  return LocalStepsRepository(StepsDao(db), sync);
});

/// Provider for [CaseTypesRepository].
final caseTypesRepositoryProvider = FutureProvider<CaseTypesRepository>((
  ref,
) async {
  final db = await ref.watch(databaseProvider.future);
  final sync = await ref.watch(syncWriteHelperProvider.future);
  return LocalCaseTypesRepository(CaseTypesDao(db), sync);
});

/// Provider for [OnBehalfsRepository].
final onBehalfsRepositoryProvider = FutureProvider<OnBehalfsRepository>((
  ref,
) async {
  final db = await ref.watch(databaseProvider.future);
  final sync = await ref.watch(syncWriteHelperProvider.future);
  return LocalOnBehalfsRepository(OnBehalfsDao(db), sync);
});
