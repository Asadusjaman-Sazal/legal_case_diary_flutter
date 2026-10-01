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
}
