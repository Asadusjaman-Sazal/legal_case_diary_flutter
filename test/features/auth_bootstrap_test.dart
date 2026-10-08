/// Task 17 Phase 1 — Supabase client integration.
///
/// These tests pin the three promises the bootstrap makes: a build with no
/// backend configured is fully usable and reports *no backend* instead of
/// failing oddly, the session lives in secure storage rather than preferences,
/// and every SDK error is classified into the kind of failure a screen shows.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:legal_case_diary/core/constants/supabase_config.dart';
import 'package:legal_case_diary/core/providers/repository_providers.dart';
import 'package:legal_case_diary/database/encryption_key_manager.dart';
import 'package:legal_case_diary/features/auth/data/auth_data.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A transport failure, exactly as the SDK raises it for no connectivity.
AuthRetryableFetchException _offline() =>
    AuthRetryableFetchException(message: 'SocketException: failed host lookup');

void main() {
  group('Supabase configuration', () {
    test('only the one writable project is accepted', () {
      // AGENTS.md rule 12, enforced by code: the app may talk to exactly one
      // project, and the off-limits one is refused even if it is typed in.
      expect(
        SupabaseConfig.isAllowedUrl(
          'https://lsthasywrdrhuuxnykau.supabase.co',
        ),
        isTrue,
      );
      expect(
        SupabaseConfig.isAllowedUrl(
          'https://ykbwzodadijtiizobehk.supabase.co',
        ),
        isFalse,
      );
      expect(
        SupabaseConfig.isAllowedUrl('https://some-other-project.supabase.co'),
        isFalse,
      );
      expect(SupabaseConfig.isAllowedUrl(''), isFalse);
    });

    test('an unconfigured build reports no backend and needs no credentials', () {
      // The test VM carries no dart-defines, which is also how a plain
      // `flutter run` without env.json behaves.
      expect(SupabaseConfig.isConfigured, isFalse);
      expect(SupabaseConfig.hasGoogleClientId, isFalse);
    });
  });

  group('Auth repository in a build with no backend', () {
    test('resolves to the unavailable repository and stays inert', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final repository = container.read(authRepositoryProvider);

      expect(repository, isA<UnavailableAuthRepository>());
      expect(repository.isAvailable, isFalse);
      expect(repository.currentIdentity, isNull);
      expect(await repository.restoreSession(), isNull);
    });

    test('every auth call fails as unavailable rather than reaching the SDK', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final repository = container.read(authRepositoryProvider);

      Future<void> expectUnavailable(Future<Object?> Function() call) async {
        await expectLater(
          call(),
          throwsA(
            isA<AuthFailure>().having(
              (failure) => failure.kind,
              'kind',
              AuthFailureKind.unavailable,
            ),
          ),
        );
      }

      await expectUnavailable(
        () => repository.signInWithPassword(
          email: 'counsel@example.com',
          password: 'secret123',
        ),
      );
      await expectUnavailable(
        () => repository.signUpIndividual(
          fullName: 'Adv. Counsel',
          email: 'counsel@example.com',
          password: 'secret123',
        ),
      );
      await expectUnavailable(repository.signInWithGoogle);
      await expectUnavailable(
        () => repository.sendPasswordRecoveryCode('counsel@example.com'),
      );
      await expectUnavailable(
        () => repository.verifyRecoveryCode(
          email: 'counsel@example.com',
          code: '123456',
        ),
      );
      await expectUnavailable(() => repository.updatePassword('newsecret123'));
      await expectUnavailable(
        () => repository.resendConfirmationEmail('counsel@example.com'),
      );
      // These two answer instead of throwing: "not confirmed" and "nothing to
      // remove" are ordinary answers, and on a build with no backend neither
      // may claim otherwise.
      expect(
        await repository.isEmailConfirmed(
          email: 'counsel@example.com',
          password: 'secret123',
        ),
        isFalse,
      );
      expect(
        await repository.discardUnconfirmedSignup(
          email: 'counsel@example.com',
          password: 'secret123',
        ),
        DiscardSignupOutcome.unavailable,
      );

      // Sign-out is a no-op, not a failure: nothing is signed in.
      await repository.signOut();
    });
  });

  group('Secure session storage', () {
    test('round-trips the session through the secure store only', () async {
      final secureStorage = InMemoryKeyStorage();
      final store = SecureSessionStorage(storage: secureStorage);

      await store.initialize();
      expect(await store.hasAccessToken(), isFalse);
      expect(await store.accessToken(), isNull);

      await store.persistSession('{"access_token":"a","refresh_token":"b"}');

      expect(await store.hasAccessToken(), isTrue);
      expect(await store.accessToken(), contains('refresh_token'));

      await store.removePersistedSession();

      expect(await store.hasAccessToken(), isFalse);
      expect(await secureStorage.read(key: sessionStorageKey), isNull);
    });

    test('an empty stored value does not count as a session', () async {
      final secureStorage = InMemoryKeyStorage();
      await secureStorage.write(key: sessionStorageKey, value: '');
      final store = SecureSessionStorage(storage: secureStorage);

      expect(await store.hasAccessToken(), isFalse);
    });
  });

  group('Auth failure classification', () {
    test('wrong credentials and unconfirmed email are told apart', () {
      expect(
        mapAuthFailure(
          AuthException('Invalid login credentials', statusCode: '400'),
        ).kind,
        AuthFailureKind.invalidCredentials,
      );
      expect(
        mapAuthFailure(const AuthException('Email not confirmed')).kind,
        AuthFailureKind.emailNotConfirmed,
      );
    });

    test('transport failures, server rate limits and weak passwords', () {
      expect(mapAuthFailure(_offline()).kind, AuthFailureKind.network);
      expect(
        mapAuthFailure(
          AuthException('Email rate limit exceeded', statusCode: '429'),
        ).kind,
        AuthFailureKind.rateLimited,
      );
      expect(
        mapAuthFailure(
          AuthException(
            'Password should be at least 6 characters',
            code: 'weak_password',
          ),
        ).kind,
        AuthFailureKind.weakPassword,
      );
    });

    test('a server error is not reported as a missing connection', () {
      // Regression: the SDK raises `AuthRetryableFetchException` for any HTTP
      // 5xx as well as for a dead socket, and the classifier called both
      // `network`. A recovery mail the server could not send — a mail relay
      // rejecting its own credentials — was therefore reported to a user on a
      // perfect connection as "No Connection. Check Your Internet And Try
      // Again." The status code is the only thing that tells them apart, and the
      // transport case above (no status) still is one.
      expect(
        mapAuthFailure(
          AuthRetryableFetchException(
            message: '{"message":"Error sending recovery email"}',
            statusCode: '500',
          ),
        ).kind,
        AuthFailureKind.unknown,
      );
    });

    test('an invite rate limit arrives as its own kind', () {
      // `join_firm` raises this message; the associate must see the friendly
      // "try again later" copy, not a generic failure.
      expect(
        mapAuthFailure(
          const PostgrestException(message: 'Too many attempts — try again later'),
        ).kind,
        AuthFailureKind.tooManyAttempts,
      );
    });

    test('a dismissed Google sheet is a cancellation, not an error', () {
      expect(
        mapAuthFailure(
          const GoogleSignInException(
            code: GoogleSignInExceptionCode.canceled,
          ),
        ).kind,
        AuthFailureKind.cancelled,
      );
    });

    test('a Google-side failure wearing a cancellation is not silent', () {
      // Android's Credential Manager reports a broken Google setup (a wrong
      // signing SHA, package name or serverClientId) as a cancellation. This is
      // the exact string an instrumented build produced, and it must reach the
      // screen as a real failure — the whole point is that the user is told
      // instead of watching the sheet close and nothing happen.
      final failure = mapAuthFailure(
        const GoogleSignInException(
          code: GoogleSignInExceptionCode.canceled,
          description: '[16] Account reauth failed.',
        ),
      );
      expect(failure.kind, AuthFailureKind.googleSignInFailed);
    });

    test('a Google client configuration error is a Google failure', () {
      expect(
        mapAuthFailure(
          const GoogleSignInException(
            code: GoogleSignInExceptionCode.clientConfigurationError,
          ),
        ).kind,
        AuthFailureKind.googleSignInFailed,
      );
    });

    test('an already-typed failure passes through unchanged', () {
      const failure = AuthFailure(AuthFailureKind.invalidCredentials);
      expect(identical(mapAuthFailure(failure), failure), isTrue);
    });

    test('anything unrecognized is unknown, never a raw server string', () {
      final failure = mapAuthFailure(StateError('boom'));
      expect(failure.kind, AuthFailureKind.unknown);
      expect(failure.serverMessage, isNull);
    });
  });

  group('Session-end classification', () {
    test('a rejected session and an unreadable one both need a sign-in', () {
      expect(authSessionNeedsSignIn(SignOutReason.sessionExpired), isTrue);
      // Corruption, not rejection: the persisted session never parsed back into
      // a session, so no request was made and nothing was revoked. Treating it
      // as anything less than a sign-in means the device signs out silently and
      // the user is never told why their sync stopped.
      expect(authSessionNeedsSignIn(SignOutReason.sessionMissing), isTrue);
    });

    test('a deliberate sign-out is not a reason to ask for one', () {
      expect(authSessionNeedsSignIn(SignOutReason.userInitiated), isFalse);
      expect(authSessionNeedsSignIn(null), isFalse);
    });
  });

  group('Google sign-in network pre-flight', () {
    test('an unreachable host is reported unreachable', () async {
      // A loopback port nothing listens on refuses the connection at once —
      // the same answer a phone gets on a Wi-Fi network with no uplink, which
      // is the case `ConnectivityMonitor` cannot see (it reports the link).
      expect(
        await probeSupabaseReachable(base: 'http://127.0.0.1:1/'),
        isFalse,
      );
    });

    test('a build with no project URL is never probed', () async {
      expect(SupabaseConfig.url, isEmpty);
      expect(await probeSupabaseReachable(), isFalse);
    });
  });

  group('Cached identity', () {
    test('remembers an identity across restarts and forgets it on sign-out', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = LocalAuthService(prefs);

      expect(service.cachedUserId, isNull);
      expect(service.readIdentity(), isNull);
      expect(service.gateSatisfied, isFalse);

      await service.rememberIdentity(
        const AuthIdentity(userId: 'user-1', email: 'counsel@example.com'),
      );
      await service.markGateSatisfied();

      // A fresh service over the same preferences is a restarted app.
      final restarted = LocalAuthService(prefs);
      expect(restarted.cachedUserId, 'user-1');
      expect(restarted.cachedEmail, 'counsel@example.com');
      expect(restarted.readIdentity()?.userId, 'user-1');
      expect(restarted.gateSatisfied, isTrue);

      await restarted.clear();

      expect(restarted.cachedUserId, isNull);
      expect(restarted.gateSatisfied, isFalse);
    });

    test('a missing email is not remembered as an empty string', () async {
      SharedPreferences.setMockInitialValues({
        authUserEmailKey: 'stale@example.com',
      });
      final prefs = await SharedPreferences.getInstance();
      final service = LocalAuthService(prefs);

      await service.rememberIdentity(const AuthIdentity(userId: 'user-1'));

      expect(service.cachedUserId, 'user-1');
      expect(service.cachedEmail, isNull);
    });
  });

  group('the waiting confirmation record', () {
    test('survives a restart, and stops being read after a week', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final service = LocalAuthService(prefs);

      await service.setPendingConfirmationEmail('jane@example.com');

      // A restarted app is a fresh service over the same preferences — which is
      // exactly the launch the screen has to come back to.
      expect(
        LocalAuthService(prefs).pendingConfirmationEmail,
        'jane@example.com',
      );

      // An old record is ignored: Sign Up is not a screen to open a week later.
      SharedPreferences.setMockInitialValues(<String, Object>{
        pendingConfirmationEmailKey: 'jane@example.com',
        pendingConfirmationAtKey: DateTime.now()
            .subtract(const Duration(days: 8))
            .millisecondsSinceEpoch,
      });
      final stale = LocalAuthService(await SharedPreferences.getInstance());
      expect(stale.pendingConfirmationEmail, isNull);
    });

    test('is forgotten with the account it belongs to', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final service = LocalAuthService(prefs);

      await service.setPendingConfirmationEmail('jane@example.com');
      await service.clear();

      expect(service.pendingConfirmationEmail, isNull);

      await service.setPendingConfirmationEmail('jane@example.com');
      await service.clearPendingConfirmationEmail();

      expect(service.pendingConfirmationEmail, isNull);
    });
  });

  group('the discard envelope', () {
    test('removed is the only success', () {
      expect(
        outcomeFromDiscardResponse(<String, Object>{'status': 'removed'}),
        DiscardSignupOutcome.removed,
      );
    });

    test('a refusal names its reason, and an unknown one is a failure', () {
      expect(
        outcomeFromDiscardResponse(<String, Object>{
          'status': 'refused',
          'reason': 'confirmed',
        }),
        DiscardSignupOutcome.refusedConfirmed,
      );
      expect(
        outcomeFromDiscardResponse(<String, Object>{
          'status': 'refused',
          'reason': 'not_provisional',
        }),
        DiscardSignupOutcome.refusedUsed,
      );
      expect(
        outcomeFromDiscardResponse(<String, Object>{
          'status': 'refused',
          'reason': 'something new',
        }),
        DiscardSignupOutcome.failed,
      );
    });

    test('the rate limit is its own answer, and anything else is a failure', () {
      expect(
        outcomeFromDiscardResponse(<String, Object>{'status': 'rate_limited'}),
        DiscardSignupOutcome.rateLimited,
      );
      expect(outcomeFromDiscardResponse(null), DiscardSignupOutcome.failed);
      expect(
        outcomeFromDiscardResponse(<String, Object>{'status': 'unexpected'}),
        DiscardSignupOutcome.failed,
      );
    });
  });
}
