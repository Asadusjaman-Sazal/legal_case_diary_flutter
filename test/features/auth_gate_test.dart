/// Task 17 Phase 2 — the first-run gate and identity adoption.
///
/// Two rules meet in this file, and both are load-bearing:
///
/// * **Nobody is locked out of their own diary.** A device that already holds
///   the user's own rows opens straight into the diary; only a device with
///   nothing on it is asked to sign in.
/// * **Ownership is rewritten exactly once, atomically, and never across
///   accounts.** Placeholder-owned rows, queue payloads and per-user preferences
///   move to the authenticated id together, the pull-only caches are emptied
///   instead, and a different account is refused with the diary untouched.
library;

import 'dart:convert';

import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:legal_case_diary/core/services/local_identity_service.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/auth/data/auth_repository.dart';
import 'package:legal_case_diary/features/auth/data/identity_adoption_service.dart';
import 'package:legal_case_diary/features/auth/data/local_auth_service.dart';
import 'package:legal_case_diary/features/auth/presentation/auth_gate.dart';
import 'package:legal_case_diary/features/auth/presentation/auth_viewmodel.dart';
import 'package:legal_case_diary/sync/sync_metadata_dao.dart';

import 'auth_test_support.dart';

/// The placeholder id every Part A install wrote its rows under.
const String placeholder = 'placeholder-device-uuid';

/// The id of the case the seeded rows hang off.
const String caseId = 'case-1';

/// Seeds the reference chain a case needs, then the case itself.
Future<void> seedUserCase(AppDatabase db, {String owner = placeholder}) async {
  await db
      .into(db.courtCategories)
      .insert(
        const CourtCategoriesCompanion(
          id: Value('category-1'),
          nameKey: Value('courtCategory_appellateDivision'),
          courtLevel: Value('appellate'),
          orderIndex: Value(1),
          updatedAt: Value(1),
        ),
      );
  await db
      .into(db.courts)
      .insert(
        const CourtsCompanion(
          id: Value('court-1'),
          courtName: Value('Supreme Court'),
          higherLowerCourts: Value('higher_courts'),
          courtCategoryId: Value('category-1'),
          updatedAt: Value(1),
        ),
      );
  await db
      .into(db.onBehalfs)
      .insert(
        const OnBehalfsCompanion(
          id: Value('on-behalf-1'),
          courtCategoryId: Value('category-1'),
          name: Value('Petitioner'),
          orderIndex: Value(1),
          updatedAt: Value(1),
        ),
      );
  await db
      .into(db.cases)
      .insert(
        CasesCompanion(
          id: const Value(caseId),
          userId: Value(owner),
          courtId: const Value('court-1'),
          caseType: const Value('Civil'),
          caseNumber: const Value('GATE/2026'),
          petitioner: const Value('Alice'),
          respondent: const Value('Bob'),
          onBehalfId: const Value('on-behalf-1'),
          lastModifiedBy: Value(owner),
          createdAt: const Value(1),
          updatedAt: const Value(1),
        ),
      );
}

void main() {
  group('First-run gate', () {
    late AuthTestHarness harness;

    setUp(() => harness = AuthTestHarness());
    tearDown(() async {
      await harness.tearDown();
      await harness.auth.dispose();
    });

    /// Seeds [seed] into the harness database, then reads the gate once.
    Future<bool> gateRequired({
      Future<void> Function(AppDatabase db)? seed,
    }) async {
      final overrides = await harness.setUp();
      if (seed != null) await seed(harness.db);
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);
      return container.read(authGateRequiredProvider.future);
    }

    test('a brand-new install is asked to sign in', () async {
      expect(await gateRequired(), isTrue);
    });

    test('an install that already holds its author\'s work is let through', () async {
      expect(await gateRequired(seed: seedUserCase), isFalse);
    });

    test('a satisfied gate is remembered across restarts', () async {
      harness = AuthTestHarness(
        preferences: <String, Object>{authGateSatisfiedKey: true},
      );

      expect(await gateRequired(), isFalse);
    });

    test('a cached account from an earlier launch is not asked again', () async {
      harness = AuthTestHarness(
        preferences: <String, Object>{authUserIdKey: 'user-1'},
      );

      expect(await gateRequired(), isFalse);
    });

    test('a restored session opens the diary', () async {
      harness = AuthTestHarness(
        auth: FakeAuthRepository(
          identity: const AuthIdentity(userId: 'user-1'),
        ),
      );

      expect(await gateRequired(), isFalse);
    });
  });

  group('Identity adoption', () {
    late AuthTestHarness harness;
    late List<Override> overrides;
    late IdentityAdoptionService adoption;

    /// A device whose Part A rows are owned by the placeholder.
    setUp(() async {
      harness = AuthTestHarness(
        preferences: <String, Object>{
          'local_identity_id': placeholder,
        },
      );
      overrides = await harness.setUp();
      adoption = IdentityAdoptionService(
        harness.db,
        LocalIdentityService(harness.prefs),
      );
    });

    tearDown(() async {
      await harness.tearDown();
      await harness.auth.dispose();
    });

    /// Seeds one placeholder-owned row in every class adoption has to handle.
    Future<void> seedEverything() async {
      await seedUserCase(harness.db);
      await harness.db
          .into(harness.db.userPreferences)
          .insert(
            const UserPreferencesCompanion(
              userId: Value(placeholder),
              language: Value('bn'),
              updatedAt: Value(1),
            ),
          );
      await harness.db
          .into(harness.db.caseNotificationPreferences)
          .insert(
            const CaseNotificationPreferencesCompanion(
              userId: Value(placeholder),
              caseId: Value(caseId),
              updatedAt: Value(1),
            ),
          );
      await harness.db
          .into(harness.db.syncQueue)
          .insert(
            SyncQueueCompanion(
              entityType: const Value('cases'),
              entityId: const Value(caseId),
              operation: const Value('insert'),
              mutationId: const Value('mutation-1'),
              basePayload: const Value('{"user_id":"$placeholder"}'),
              changedFields: const Value('["petitioner"]'),
              payload: const Value(
                '{"id":"$caseId","user_id":"$placeholder",'
                '"last_modified_by":"$placeholder","firm_id":null}',
              ),
              preMutationPayload: const Value(
                '{"id":"$caseId","user_id":"$placeholder"}',
              ),
              createdAt: const Value(1),
              state: const Value('pending'),
            ),
          );
      await harness.db
          .into(harness.db.profiles)
          .insert(
            const ProfilesCompanion(
              id: Value('someone-else'),
              fullName: Value('Earlier Account'),
              role: Value('owner'),
              subscriptionStatus: Value('active'),
              createdAt: Value(1),
            ),
          );
      await harness.db
          .into(harness.db.firms)
          .insert(
            const FirmsCompanion(
              id: Value('old-firm'),
              name: Value('Old Firm'),
              ownerId: Value('someone-else'),
              subscriptionStatus: Value('active'),
              createdAt: Value(1),
            ),
          );
      await harness.db
          .into(harness.db.firmMembers)
          .insert(
            const FirmMembersCompanion(
              id: Value('old-member'),
              firmId: Value('old-firm'),
              userId: Value('someone-else'),
              role: Value('member'),
            ),
          );
    }

    test('every class moves in one transaction, and the audit is recorded', () async {
      await seedEverything();

      final outcome = await adoption.adopt(
        const AuthIdentity(userId: 'user-1'),
        firmId: 'firm-1',
      );

      expect(outcome.alreadyBound, isFalse);
      expect(outcome.placeholderUserId, placeholder);
      expect(outcome.rowsChanged, 1, reason: 'the one case row');
      expect(outcome.queueEntriesChanged, 1);
      expect(outcome.preferenceRowsChanged, 2);

      // Domain rows: ownership, firm scope and attribution all follow.
      final caseRow = await (harness.db.select(
        harness.db.cases,
      )..where((t) => t.id.equals(caseId))).getSingle();
      expect(caseRow.userId, 'user-1');
      expect(caseRow.firmId, 'firm-1');
      expect(caseRow.lastModifiedBy, 'user-1');

      // Per-user preferences follow the person, never the firm.
      final prefs = await (harness.db.select(
        harness.db.userPreferences,
      )..where((t) => t.userId.equals('user-1'))).getSingle();
      expect(prefs.language, 'bn');
      final notifications = await harness.db
          .select(harness.db.caseNotificationPreferences)
          .get();
      expect(notifications.single.userId, 'user-1');
      expect(notifications.single.caseId, caseId);

      // Queue payloads would otherwise push placeholder ownership. `firm_id`
      // was already null in Part A and is left exactly as submitted.
      final queued = await harness.db.select(harness.db.syncQueue).getSingle();
      expect(queued.payload, contains('"user_id":"user-1"'));
      expect(queued.payload, contains('"firm_id":null'));
      expect(queued.payload, isNot(contains(placeholder)));
      expect(queued.basePayload, isNot(contains(placeholder)));
      expect(queued.preMutationPayload, isNot(contains(placeholder)));

      // The pull-only caches belong to whoever pulled them; they are emptied.
      expect(await harness.db.select(harness.db.profiles).get(), isEmpty);
      expect(await harness.db.select(harness.db.firms).get(), isEmpty);
      expect(await harness.db.select(harness.db.firmMembers).get(), isEmpty);

      // The binding and the provenance are what make this auditable.
      expect(await adoption.boundUserId(), 'user-1');
      final provenance = jsonDecode(
        (await SyncMetadataDao(harness.db).getValue(adoptionProvenanceKey))!,
      ) as Map<String, dynamic>;
      expect(provenance['placeholderUserId'], placeholder);
      expect(provenance['adoptedUserId'], 'user-1');
      expect(provenance['firmId'], 'firm-1');
      expect((provenance['rows'] as Map)['cases'], 1);
    });

    test('a second account is refused and nothing is rewritten', () async {
      await seedEverything();
      await adoption.adopt(const AuthIdentity(userId: 'user-1'));

      await expectLater(
        adoption.adopt(const AuthIdentity(userId: 'user-2')),
        throwsA(
          isA<AuthFailure>().having(
            (failure) => failure.kind,
            'kind',
            AuthFailureKind.accountMismatch,
          ),
        ),
      );

      final caseRow = await (harness.db.select(
        harness.db.cases,
      )..where((t) => t.id.equals(caseId))).getSingle();
      expect(caseRow.userId, 'user-1', reason: 'the diary stayed put');
      expect(await adoption.boundUserId(), 'user-1');
      // The cache belongs to the bound account, so it was not refilled either.
      expect(await harness.db.select(harness.db.profiles).get(), isEmpty);
    });

    test('adopting the same account twice is a no-op', () async {
      await seedEverything();
      await adoption.adopt(const AuthIdentity(userId: 'user-1'));

      final again = await adoption.adopt(const AuthIdentity(userId: 'user-1'));

      expect(again.wasNoop, isTrue);
      expect(again.rowsChanged, 0);
      expect(again.queueEntriesChanged, 0);
      expect(again.preferenceRowsChanged, 0);
    });

    test('an install that never wrote anything is bound without a placeholder', () async {
      // No `local_identity_id`: the device never minted a Part A identity, so
      // there is nothing to move — only the binding to record.
      final fresh = AuthTestHarness();
      await fresh.setUp();
      addTearDown(() async {
        await fresh.tearDown();
        await fresh.auth.dispose();
      });
      final freshAdoption = IdentityAdoptionService(
        fresh.db,
        LocalIdentityService(fresh.prefs),
      );

      final outcome = await freshAdoption.adopt(
        const AuthIdentity(userId: 'user-1'),
      );

      expect(outcome.placeholderUserId, isNull);
      expect(outcome.rowsChanged, 0);
      expect(await freshAdoption.boundUserId(), 'user-1');
    });

    test('a queue payload that is not JSON is left exactly as it was', () async {
      await harness.db
          .into(harness.db.syncQueue)
          .insert(
            const SyncQueueCompanion(
              entityType: Value('cases'),
              entityId: Value(caseId),
              operation: Value('insert'),
              mutationId: Value('mutation-2'),
              basePayload: Value('not json'),
              changedFields: Value('[]'),
              payload: Value('not json'),
              preMutationPayload: Value('not json'),
              createdAt: Value(1),
              state: Value('pending'),
            ),
          );

      await adoption.adopt(const AuthIdentity(userId: 'user-1'));

      final queued = await harness.db.select(harness.db.syncQueue).getSingle();
      expect(queued.payload, 'not json');
    });

    test('a refused account leaves the diary readable but flagged', () async {
      await seedEverything();
      await adoption.adopt(const AuthIdentity(userId: 'user-1'));

      // A different account now opens this device.
      harness.auth.identity = const AuthIdentity(userId: 'user-2');
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);

      final state = await container.read(authViewModelProvider.future);

      expect(state.identity?.userId, 'user-2');
      expect(state.adoptionBlocked, isTrue);
      expect(
        container.read(authAdoptionBlockedProvider),
        isTrue,
      );
    });
  });

  group('Cached identity after adoption', () {
    test('the gate flag and the account are recorded together', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final local = LocalAuthService(prefs);

      await local.rememberIdentity(const AuthIdentity(userId: 'user-1'));
      await local.markGateSatisfied();
      await local.setPendingInviteCode('ABCDE12345');

      await local.clear();

      expect(local.cachedUserId, isNull);
      expect(local.gateSatisfied, isFalse);
      expect(local.pendingInviteCode, isNull);
    });
  });
}
