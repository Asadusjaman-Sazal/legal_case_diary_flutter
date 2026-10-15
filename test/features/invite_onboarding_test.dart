/// Task 17 Phase 5 — the owner-side invite primitives.
///
/// The full Manage Associates UI arrives in Task 20; this phase ships the pieces
/// it will reuse, and these tests pin the three properties that make them safe
/// to reuse:
///
/// * a code carries **≥ 50 bits** of entropy and only its **SHA-256 hash** ever
///   reaches the server or a log;
/// * a **used or revoked** code is refused, and the app's refusal is the same
///   one the server's `invalid_code` produces;
/// * firm administration is **online-only**, and says so in its own words
///   instead of failing a request the device cannot make.
library;

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/theme/app_theme.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/firm_repository.dart';
import 'package:legal_case_diary/features/accounts_and_profile/presentation/manage_associates_screen.dart';
import 'package:legal_case_diary/features/auth/data/auth_repository.dart';
import 'package:legal_case_diary/features/auth/data/local_auth_service.dart';
import 'package:legal_case_diary/features/auth/presentation/auth_viewmodel.dart';
import 'package:legal_case_diary/features/auth/presentation/auth_widgets.dart';
import 'package:legal_case_diary/shared/providers/shared_preferences_provider.dart';
import 'package:legal_case_diary/sync/connectivity_monitor.dart';

import 'auth_test_support.dart';

void main() {
  group('invite codes', () {
    test('ten Crockford Base32 symbols are exactly fifty bits', () {
      // Entropy is a property of the alphabet and the length, not of the
      // generator's mood: 32 symbols is 5 bits, ten of them is 2^50.
      expect(inviteCodeAlphabet.length, 32);
      expect(inviteCodeLength, 10);
      expect(inviteCodeLength * 5, greaterThanOrEqualTo(50));

      // Crockford drops the four letters a hand-read code confuses with 1, 0
      // and V.
      for (final excluded in <String>['I', 'L', 'O', 'U']) {
        expect(
          inviteCodeAlphabet.contains(excluded),
          isFalse,
          reason: '$excluded must not be in a Crockford alphabet',
        );
      }
    });

    test('generated codes are alphabet-only and unique', () {
      final code = generateInviteCode();
      expect(code.length, inviteCodeLength);
      expect(code.split('').every(inviteCodeAlphabet.contains), isTrue);

      // A thousand draws from a 2^50 space sharing no value: a collision here
      // would mean the source is not the independent draw it claims to be.
      final drawn = <String>{
        for (var index = 0; index < 1000; index++) generateInviteCode(),
      };
      expect(drawn, hasLength(1000));
    });

    test('a seeded source is reproducible, so a failing draw can be replayed', () {
      expect(
        generateInviteCode(random: Random(7)),
        generateInviteCode(random: Random(7)),
      );
    });

    test('the hash is sha256 of the normalized code, which is what the server compares', () {
      // `join_firm` hashes `upper(btrim(code))`; anything else would produce a
      // code that never matches the row it was stored in.
      expect(
        inviteCodeHash('abcdefghjk'),
        sha256.convert(utf8.encode('ABCDEFGHJK')).toString(),
      );
      expect(inviteCodeHash('  AbCdEfGhJk '), inviteCodeHash('ABCDEFGHJK'));
      expect(normalizeInviteCode('  abc '), 'ABC');
    });

    test('the insert row carries the hash and never the plaintext', () {
      final row = inviteInsertRow(
        firmId: 'firm-1',
        code: 'abcdefghjk',
        createdBy: 'user-1',
        createdAt: 1700000000000,
      );

      expect(row.keys.toSet(), <String>{
        'firm_id',
        'code_hash',
        'created_by',
        'created_at',
      });
      expect(row['code_hash'], inviteCodeHash('ABCDEFGHJK'));
      // The whole point of the phase: no shape of the plaintext is in the row
      // that goes to `firm_invites`.
      for (final value in row.values) {
        expect('$value'.toUpperCase(), isNot(contains('ABCDEFGHJK')));
      }
    });

    test('a generated invite never prints its code', () {
      const invite = GeneratedInvite(
        code: 'ABCDEFGHJK',
        inviteId: 'invite-1',
        firmId: 'firm-1',
      );

      // Interpolating the result of createInvite into a log line is the one way
      // the plaintext could leak, so the string is deliberately code-free.
      expect(invite.toString(), isNot(contains('ABCDEFGHJK')));
      expect(invite.toString(), contains('invite-1'));
    });
  });

  group('redemption outcomes', () {
    test('a valid code joins, from a jsonb map and from a JSON string', () {
      expect(
        parseInviteRedemption(<String, dynamic>{
          'status': 'joined',
          'firm_id': 'firm-1',
        }).status,
        InviteRedemptionStatus.joined,
      );
      expect(
        parseInviteRedemption('{"status":"already_member","firm_id":"firm-1"}')
            .status,
        InviteRedemptionStatus.alreadyMember,
      );
    });

    test('a used or a revoked code is refused, and the app cannot tell which', () {
      // `join_firm` only matches `used_by is null and revoked = false`, so both
      // cases arrive as `invalid_code` — and that is exactly what must happen:
      // the client must not let a stranger probe which codes once existed.
      expect(
        () => parseInviteRedemption(<String, dynamic>{'status': 'invalid_code'}),
        throwsA(
          isA<FirmFailure>().having(
            (failure) => failure.kind,
            'kind',
            FirmFailureKind.invalidInviteCode,
            ),
        ),
      );
    });

    test('an unknown status is not shown as an invite problem', () {
      expect(
        () => parseInviteRedemption(<String, dynamic>{'status': 'unauthenticated'}),
        throwsA(
          isA<FirmFailure>().having(
            (failure) => failure.kind,
            'kind',
            FirmFailureKind.unknown,
            ),
        ),
      );
    });

    test('a seat with a diary is refused with the count the sentence needs', () {
      // The refusal is deliberately not a `FirmFailure`: nothing went wrong and
      // the account is untouched, so a screen that showed it as a system error
      // would be lying about what happened.
      expect(
        () => parseInviteRedemption(<String, dynamic>{
          'status': 'has_own_diary',
          'cases': 12,
        }),
        throwsA(
          isA<InviteRefusal>()
              .having((r) => r.kind, 'kind', InviteRefusalKind.ownDiary)
              .having((r) => r.count, 'count', 12),
        ),
      );
    });

    test('a full chamber is refused with the cap it quoted', () {
      expect(
        () => parseInviteRedemption(<String, dynamic>{
          'status': 'seats_full',
          'firm_id': 'firm-1',
          'seats': 5,
        }),
        throwsA(
          isA<InviteRefusal>()
              .having((r) => r.kind, 'kind', InviteRefusalKind.seatsFull)
              .having((r) => r.count, 'count', 5),
        ),
      );
    });

    test('a seat refusal with no count still has a sentence', () {
      // A malformed or older response, or the tenant-blocked case where the
      // count is unknowable, must still say something useful rather than drop to
      // "Something went wrong".
      expect(
        () => parseInviteRedemption(<String, dynamic>{'status': 'has_own_diary'}),
        throwsA(
          isA<InviteRefusal>()
              .having((r) => r.kind, 'kind', InviteRefusalKind.ownDiary)
              .having((r) => r.count, 'count', isNull),
        ),
      );
    });

    test('a refusal never logs a detail, only its kind', () {
      // The count is user-facing copy, not diagnostics; the log stays scannable.
      const refusal = InviteRefusal(InviteRefusalKind.seatsFull, count: 5);
      expect(refusal.diagnosticLabel, 'InviteRefusal(seatsFull)');
      expect(refusal.diagnosticDetail, isNull);
      expect(refusal.toString(), isNot(contains('5')));
    });
  });

  group('the online-only rule', () {
    /// A repository whose client points at a closed port: if the guard ever let
    /// a request through, the failure would be a network error, not this kind.
    SupabaseFirmRepository offlineRepository() => SupabaseFirmRepository(
      SupabaseClient('http://127.0.0.1:1', 'test-anon-key'),
      isOnline: () async => false,
    );

    Matcher throwsFirmAdminOffline() => throwsA(
      isA<FirmFailure>().having(
        (failure) => failure.kind,
        'kind',
        FirmFailureKind.firmAdminOffline,
        ),
    );

    test('creating an invite offline asks for a connection', () async {
      await expectLater(offlineRepository().createInvite(), throwsFirmAdminOffline());
    });

    test('revoking an invite offline asks for a connection', () async {
      await expectLater(
        offlineRepository().revokeInvite('invite-1'),
        throwsFirmAdminOffline(),
      );
    });

    test('establishing a firm offline asks for a connection', () async {
      await expectLater(
        offlineRepository().ensureFirm('Chambers'),
        throwsFirmAdminOffline(),
      );
    });

    test('the message the rule shows is the one the task asks for', () async {
      final l = await AppLocalizations.delegate.load(const Locale('en'));

      expect(
        firmErrorText(l, FirmFailureKind.firmAdminOffline),
        'Connect to the internet to manage your firm.',
      );
      // And the refusal a used code produces reaches the user in its own words.
      expect(
        firmErrorText(l, FirmFailureKind.invalidInviteCode),
        l.auth_errorInvalidCode,
      );
    });

    testWidgets('the Manage Associates surface shows it when offline', (
      tester,
    ) async {
      final l = await AppLocalizations.delegate.load(const Locale('en'));

      await pumpManageAssociates(tester, online: false);

      expect(find.text(l.auth_errorFirmAdminOffline), findsOneWidget);
    });

    testWidgets('online, the surface is unchanged by the rule', (tester) async {
      final l = await AppLocalizations.delegate.load(const Locale('en'));

      await pumpManageAssociates(tester, online: true);

      // The rule adds nothing to the working state: this is still the Task 20
      // placeholder, not an offline notice.
      expect(find.text(l.auth_errorFirmAdminOffline), findsNothing);
    });
  });

  group('abandoned onboarding', () {
    test('removing the provisional account is refused offline', () async {
      final repository = SupabaseFirmRepository(
        SupabaseClient('http://127.0.0.1:1', 'test-anon-key'),
        isOnline: () async => false,
      );

      // The cleanup is one server decision, like every other firm operation, so
      // it asks for a connection rather than failing a request.
      await expectLater(
        repository.abandonOnboarding(),
        throwsA(
          isA<FirmFailure>().having(
            (failure) => failure.kind,
            'kind',
            FirmFailureKind.firmAdminOffline,
            ),
        ),
      );
    });

    /// A container over the harness fakes, with an unredeemed invite code on the
    /// device when [pendingCode] says so — the state a failed join-firm sign-up
    /// leaves behind.
    Future<ProviderContainer> container({required bool pendingCode}) async {
      final harness = AuthTestHarness(
        preferences: pendingCode
            ? const <String, Object>{pendingInviteCodeKey: 'abcde12345'}
            : const <String, Object>{},
      );
      final container = ProviderContainer(overrides: await harness.setUp());
      addTearDown(() async {
        container.dispose();
        await harness.tearDown();
        await harness.auth.dispose();
      });
      await container.read(authViewModelProvider.future);
      return container;
    }

    testWidgets('signing out asks the server to remove it, then discards the code', (
      tester,
    ) async {
      final c = await container(pendingCode: true);
      final harnessFirm = c.read(firmRepositoryProvider) as FakeFirmRepository;

      await c.read(authViewModelProvider.notifier).signOut();

      // The order matters: the call needs the session that sign-out ends.
      expect(harnessFirm.abandonCalls, 1);
      expect(c.read(authViewModelProvider).value?.identity, isNull);
      // The code goes with the account it was created for.
      expect(pendingInviteCode(c.read(sharedPreferencesProvider)), isNull);
    });

    testWidgets('a sign-out with no unfinished onboarding calls nothing', (
      tester,
    ) async {
      final c = await container(pendingCode: false);
      final harnessFirm = c.read(firmRepositoryProvider) as FakeFirmRepository;

      await c.read(authViewModelProvider.notifier).signOut();

      // No unredeemed code means no provisional account to remove; the server
      // guard would refuse anyway, so the request is not worth making.
      expect(harnessFirm.abandonCalls, 0);
    });

    testWidgets('a server refusal leaves sign-out intact', (tester) async {
      final c = await container(pendingCode: true);
      final harnessFirm = c.read(firmRepositoryProvider) as FakeFirmRepository;
      // The safe answer for an account that has actually been used.
      harnessFirm.abandonRemoved = false;

      await c.read(authViewModelProvider.notifier).signOut();

      expect(harnessFirm.abandonCalls, 1);
      expect(c.read(authViewModelProvider).value?.identity, isNull);
    });

    testWidgets('an unreachable server leaves sign-out intact', (tester) async {
      final c = await container(pendingCode: true);
      final harnessFirm = c.read(firmRepositoryProvider) as FakeFirmRepository;
      // A sign-out is the one action a user may need precisely when the network
      // is gone, so the cleanup can never be allowed to fail it.
      harnessFirm.abandonError = const AuthFailure(AuthFailureKind.network);

      await c.read(authViewModelProvider.notifier).signOut();

      expect(harnessFirm.abandonCalls, 1);
      expect(c.read(authViewModelProvider).value?.identity, isNull);
    });
  });
}

/// Pumps the Manage Associates surface with the device's link state decided.
Future<void> pumpManageAssociates(
  WidgetTester tester, {
  required bool online,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        isOnlineProvider.overrideWith((ref) => Stream<bool>.value(online)),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme(const Locale('en')),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: const ManageAssociatesScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
