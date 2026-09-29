/// The user id every local write is stamped with, and the account it follows.
///
/// The invariant this file exists for: a row the app creates after sign-in, the
/// `sync_queue` payload that carries it, and the per-user preference keys must
/// all name the **same UUID** Supabase Auth issued at sign-up — the one visible
/// in `Authentication > Users` — so anything that reaches the server is
/// traceable to exactly one account. Before an account exists the id is the
/// per-install placeholder, and adoption binds the device id to the account, so
/// the placeholder stops being used from that moment on.
library;

import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/core/providers/repository_providers.dart';
import 'package:legal_case_diary/core/services/local_identity_service.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/account_mode.dart';
import 'package:legal_case_diary/features/auth/data/auth_repository.dart';
import 'package:legal_case_diary/features/auth/data/identity_adoption_service.dart';
import 'package:legal_case_diary/features/auth/presentation/auth_viewmodel.dart';
import 'package:legal_case_diary/features/settings/data/local/case_notification_preferences_dao.dart';
import 'package:legal_case_diary/features/settings/data/settings_repository.dart';
import 'package:legal_case_diary/sync/sync_metadata_dao.dart';

import 'auth_test_support.dart';

/// The placeholder id a Part A install wrote its rows under.
const String placeholder = 'placeholder-device-uuid';

/// The account Supabase Auth issued the device.
const String accountId = 'auth-user-uuid';

void main() {
  late AuthTestHarness harness;

  /// A harness whose device already holds a Part A placeholder, optionally with
  /// an account restored.
  AuthTestHarness device({bool signedIn = false}) => AuthTestHarness(
    preferences: const <String, Object>{'local_identity_id': placeholder},
    auth: signedIn
        ? FakeAuthRepository(identity: const AuthIdentity(userId: accountId))
        : null,
  );

  tearDown(() async {
    await harness.tearDown();
    await harness.auth.dispose();
  });

  group('The device id follows the account', () {
    /// A container over the harness, with the session already resolved (which is
    /// what runs adoption and the binding).
    Future<ProviderContainer> container() async {
      final container = ProviderContainer(overrides: await harness.setUp());
      addTearDown(container.dispose);
      await container.read(authViewModelProvider.future);
      return container;
    }

    test('a row written after sign-in carries the Auth UUID, payload included', () async {
      harness = device(signedIn: true);
      final c = await container();

      final notes = await c.read(notesRepositoryProvider.future);
      await notes.insertNote(
        const NotesCompanion(title: Value('Hearing'), body: Value('Bring the file')),
      );

      final note = (await harness.db.select(harness.db.notes).getSingle());
      expect(note.userId, accountId);
      expect(note.lastModifiedBy, accountId);
      expect(note.userId, isNot(placeholder));

      // The payload is what actually leaves the device on a push, so it has to
      // agree with the row — and with RLS, which refuses a foreign owner.
      final queued = (await harness.db.select(harness.db.syncQueue).getSingle());
      expect(queued.payload, contains('"user_id":"$accountId"'));
      expect(queued.payload, contains('"last_modified_by":"$accountId"'));
      expect(queued.payload, isNot(contains(placeholder)));
    });

    test('a row written before sign-in still carries the placeholder', () async {
      harness = device();
      final c = await container();

      // Nobody signed in: this is exactly a Part A install.
      final notes = await c.read(notesRepositoryProvider.future);
      await notes.insertNote(
        const NotesCompanion(title: Value('Hearing'), body: Value('Bring the file')),
      );

      expect(
        (await harness.db.select(harness.db.notes).getSingle()).userId,
        placeholder,
      );
    });

    test('the account id is what every direct reader of the device id sees', () async {
      harness = device(signedIn: true);
      final c = await container();

      // The writers that reach for the identity service directly — the settings
      // repository, the case notification preferences, the backup nudge — and
      // the background notification isolate (which can only read preferences)
      // all read one of these.
      expect(LocalIdentityService(harness.prefs).getId(), accountId);
      expect(LocalIdentityService(harness.prefs).peekId(), accountId);
      expect(c.read(accountCacheUserIdProvider), accountId);
    });

    test('the settings and per-case notification writers land under the account', () async {
      harness = device(signedIn: true);
      final c = await container();

      // These two writers reach for the identity service directly instead of
      // through a sync-aware repository, so nothing else pins them: the settings
      // row the Settings screen saves, and the per-case notification preference
      // the Add/Edit Case sheet writes.
      final settings = await c.read(settingsRepositoryProvider.future);
      await settings.upsertSettings(const UserSettings(language: 'bn'));
      await CaseNotificationPreferencesDao(harness.db).upsert(
        CaseNotificationPreferencesCompanion(
          userId: Value(LocalIdentityService(harness.prefs).getId()),
          caseId: Value('case-1'),
          updatedAt: Value(3),
        ),
      );

      final stored = await harness.db
          .select(harness.db.userPreferences)
          .getSingle();
      expect(stored.userId, accountId);
      expect(stored.language, 'bn');

      final perCase = await harness.db
          .select(harness.db.caseNotificationPreferences)
          .getSingle();
      expect(perCase.userId, accountId);
    });

    test('signing out ends the session but not who the diary belongs to', () async {
      harness = device(signedIn: true);
      final c = await container();

      await c.read(authViewModelProvider.notifier).signOut();

      // Deliberate: the rows on this device are still that account's work, and
      // the account-switch refusal depends on the binding surviving. Clearing it
      // would quietly re-own the diary to a brand-new placeholder.
      expect(c.read(authViewModelProvider).value?.identity, isNull);
      expect(LocalIdentityService(harness.prefs).getId(), accountId);
    });

    test('a refused account switch binds nothing', () async {
      harness = device();
      await harness.setUp();
      final adoption = IdentityAdoptionService(
        harness.db,
        LocalIdentityService(harness.prefs),
      );
      await adoption.adopt(const AuthIdentity(userId: 'user-1'));

      await expectLater(
        adoption.adopt(const AuthIdentity(userId: 'user-2')),
        throwsA(isA<AuthFailure>()),
      );

      // A failed switch has to leave the device exactly as it was.
      expect(LocalIdentityService(harness.prefs).getId(), 'user-1');
    });
  });

  group('Preference rows left under the old id', () {
    late IdentityAdoptionService adoption;

    setUp(() async {
      harness = AuthTestHarness(
        preferences: const <String, Object>{'local_identity_id': placeholder},
      );
      await harness.setUp();
      adoption = IdentityAdoptionService(
        harness.db,
        LocalIdentityService(harness.prefs),
      );
    });

    Future<void> seedPreferences({
      required String userId,
      required int updatedAt,
      String language = 'en',
    }) => harness.db
        .into(harness.db.userPreferences)
        .insert(
          UserPreferencesCompanion(
            userId: Value(userId),
            language: Value(language),
            updatedAt: Value(updatedAt),
          ),
        );

    Future<void> seedNotificationPreferences({
      required String userId,
      required int updatedAt,
      String caseId = 'case-1',
    }) => harness.db
        .into(harness.db.caseNotificationPreferences)
        .insert(
          CaseNotificationPreferencesCompanion(
            userId: Value(userId),
            caseId: Value(caseId),
            updatedAt: Value(updatedAt),
          ),
        );

    test('a placeholder row moves onto the account', () async {
      await seedPreferences(userId: placeholder, updatedAt: 5, language: 'bn');

      await adoption.adopt(const AuthIdentity(userId: accountId));

      final rows = await harness.db.select(harness.db.userPreferences).get();
      expect(rows.single.userId, accountId);
      expect(rows.single.language, 'bn');
    });

    test('when both keys exist the newer row wins and the older is dropped', () async {
      await seedPreferences(userId: placeholder, updatedAt: 5, language: 'bn');
      await seedPreferences(userId: accountId, updatedAt: 9, language: 'en');

      await adoption.adopt(const AuthIdentity(userId: accountId));

      // One person, one row: the account's newer choice survives, and the move
      // never collides with the primary key the way a plain UPDATE would.
      final rows = await harness.db.select(harness.db.userPreferences).get();
      expect(rows.single.userId, accountId);
      expect(rows.single.language, 'en');
    });

    test('the placeholder row wins when it is the newer of the two', () async {
      await seedPreferences(userId: placeholder, updatedAt: 9, language: 'bn');
      await seedPreferences(userId: accountId, updatedAt: 5, language: 'en');

      await adoption.adopt(const AuthIdentity(userId: accountId));

      final rows = await harness.db.select(harness.db.userPreferences).get();
      expect(rows.single.userId, accountId);
      expect(rows.single.language, 'bn');
    });

    test('per-case notification rows follow the same rule, case by case', () async {
      await seedNotificationPreferences(
        userId: placeholder,
        updatedAt: 5,
        caseId: 'case-old',
      );
      await seedNotificationPreferences(
        userId: placeholder,
        updatedAt: 5,
        caseId: 'case-shared',
      );
      await seedNotificationPreferences(
        userId: accountId,
        updatedAt: 9,
        caseId: 'case-shared',
      );

      await adoption.adopt(const AuthIdentity(userId: accountId));

      final rows = await harness.db
          .select(harness.db.caseNotificationPreferences)
          .get();
      expect(rows, hasLength(2));
      expect(rows.every((row) => row.userId == accountId), isTrue);
      expect(
        rows.map((row) => row.caseId).toSet(),
        <String>{'case-old', 'case-shared'},
      );
    });

    test('a stray placeholder row is merged even on an already-bound device', () async {
      // The device is already bound to this account, and a later write left a
      // second key behind: the repair has to run on an ordinary launch.
      await SyncMetadataDao(
        harness.db,
      ).setValue(boundUserIdKey, accountId, updatedAt: 1);
      await seedPreferences(userId: placeholder, updatedAt: 5, language: 'bn');

      final outcome = await adoption.adopt(const AuthIdentity(userId: accountId));

      expect(outcome.alreadyBound, isTrue);
      expect(outcome.preferenceRowsChanged, 1);
      final rows = await harness.db.select(harness.db.userPreferences).get();
      expect(rows.single.userId, accountId);
      expect(rows.single.language, 'bn');
    });
  });
}
