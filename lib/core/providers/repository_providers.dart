/// Central repository providers.
///
/// Each provider depends on the encrypted database and the sync write helper,
/// so ViewModels can watch a repository without knowing how it is constructed.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/admin/data/admin_repository.dart';
import '../../features/auth/data/supabase_auth_repository.dart';
import '../../features/case_reference/data/local/case_references_dao.dart';
import '../../features/case_reference/data/reference_repository.dart';
import '../../features/cases/data/case_history_repository.dart';
import '../../features/cases/data/case_repository.dart';
import '../../features/cases/data/local/case_history_dao.dart';
import '../../features/cases/data/local/cases_dao.dart';
import '../../features/notes/data/local/notes_dao.dart';
import '../../features/notes/data/notes_repository.dart';
import '../../features/payments/data/payment_repository.dart';
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
import '../../features/settings/data/preference_sync_service.dart';
import '../../features/settings/data/settings_repository.dart';
import '../../features/settings/data/steps_repository.dart';
import '../../sync/delete_requests_dao.dart';
import '../../sync/sync_write_helper.dart';
import '../../shared/providers/database_provider.dart';
import '../backup/backup_cipher.dart';
import '../services/local_identity_service.dart';

/// The Supabase client `main.dart` initialized, or null.
///
/// Null means this build carries no backend configuration — a plain
/// `flutter run` without the dart-defines, and every test. The app is then
/// exactly as usable as it was in Part A; only the auth features report that
/// there is no backend instead of failing oddly.
final activeSupabaseClientProvider = Provider<SupabaseClient?>(
  (ref) => activeSupabaseClient,
);

/// Provider for the authentication boundary.
///
/// Screens depend on [AuthRepository], never on the Supabase SDK, so a test can
/// override this one provider and drive every auth state without a server.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = ref.watch(activeSupabaseClientProvider);
  return client == null
      ? const UnavailableAuthRepository()
      : SupabaseAuthRepository(client);
});

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

/// Provider for the per-user preference sync.
///
/// A service rather than a repository: it moves the two preference tables
/// and nothing else, addressing only the signed-in account's own rows. With
/// no backend configured it is built over the inert remote, so a plain
/// `flutter run` and every test behave exactly as they did before it.
final preferenceSyncServiceProvider = FutureProvider<PreferenceSyncService>((
  ref,
) async {
  final db = await ref.watch(databaseProvider.future);
  final client = ref.watch(activeSupabaseClientProvider);
  return PreferenceSyncService(
    client == null
        ? const OfflinePreferenceRemote()
        : SupabasePreferenceRemote(client),
    db,
  );
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

/// Provider for [PaymentRepository].
///
/// No client means no backend, and an inert repository that reports every
/// submission as a network failure rather than pretending it was queued —
/// `payment_submissions` is server-managed and is never queued locally.
final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  final client = ref.watch(activeSupabaseClientProvider);
  return client == null
      ? const UnavailablePaymentRepository()
      : SupabasePaymentRepository(client);
});

/// Provider for [AdminRepository] (Task 22).
///
/// The inert repository reports "not an admin", which is the panel's truthful
/// answer when there is no backend — the same choice `paymentRepositoryProvider`
/// makes for submissions.
final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  final client = ref.watch(activeSupabaseClientProvider);
  return client == null
      ? const UnavailableAdminRepository()
      : SupabaseAdminRepository(client);
});

/// This account's own payment submissions, newest first (own rows under RLS).
final myPaymentSubmissionsProvider =
    FutureProvider<List<PaymentSubmission>>((ref) async {
      return ref.watch(paymentRepositoryProvider).fetchMySubmissions();
    });
