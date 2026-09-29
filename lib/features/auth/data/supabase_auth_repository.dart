/// The Supabase-backed [AuthRepository], plus the mapper that turns SDK errors
/// into the typed failures the screens present.
///
/// This is the only file in the app that touches Supabase Auth and the Google
/// sign-in SDK, so a test (or a build without backend configuration) never has
/// to initialize either. No password, recovery code or token is ever stored
/// here: the session goes to secure storage through [SecureSessionStorage], and
/// everything else is the SDK's business.
library;

import 'dart:async';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/supabase_config.dart';
import 'auth_repository.dart';

/// The client `Supabase.initialize()` produced, or null when this build carries
/// no backend configuration (and in every test).
///
/// Set exactly once in `main.dart`; the repository providers read it. Keeping it
/// here rather than reaching for `Supabase.instance` means an unconfigured build
/// never trips the SDK's "you must initialize first" assertion.
SupabaseClient? activeSupabaseClient;

/// Classifies any error an auth call can produce into an [AuthFailure].
///
/// Pure and public so the classification is unit-tested directly, without a
/// server: the screens' error text is only as good as this mapping.
AuthFailure mapAuthFailure(Object error) {
  if (error is AuthFailure) return error;

  if (error is AuthRetryableFetchException) {
    // Supabase wraps every transport-level failure (offline, DNS, timeouts,
    // 5xx) in this type, so "the request never completed" is one case.
    return AuthFailure(
      AuthFailureKind.network,
      serverMessage: error.message,
      cause: error,
    );
  }

  if (error is AuthException) {
    final statusCode = error.statusCode ?? '';
    final code = error.code ?? '';
    final message = error.message.toLowerCase();

    if (statusCode == '429' ||
        code.contains('rate_limit') ||
        message.contains('rate limit')) {
      return AuthFailure(
        AuthFailureKind.rateLimited,
        serverMessage: error.message,
        cause: error,
      );
    }
    if (message.contains('email not confirmed')) {
      return AuthFailure(
        AuthFailureKind.emailNotConfirmed,
        serverMessage: error.message,
        cause: error,
      );
    }
    if (message.contains('invalid login credentials') ||
        message.contains('invalid credentials')) {
      return AuthFailure(
        AuthFailureKind.invalidCredentials,
        serverMessage: error.message,
        cause: error,
      );
    }
    if (code == 'user_already_exists' ||
        message.contains('already registered') ||
        message.contains('already exists')) {
      return AuthFailure(
        AuthFailureKind.emailInUse,
        serverMessage: error.message,
        cause: error,
      );
    }
    if (code == 'weak_password' || message.contains('password should be')) {
      return AuthFailure(
        AuthFailureKind.weakPassword,
        serverMessage: error.message,
        cause: error,
      );
    }
    return AuthFailure(
      AuthFailureKind.unknown,
      serverMessage: error.message,
      cause: error,
    );
  }

  if (error is PostgrestException) {
    // The invite RPCs return most outcomes as data and use an exception only
    // for the rate limit, which is the one the UI must name.
    if (error.message.toLowerCase().contains('too many attempts')) {
      return AuthFailure(
        AuthFailureKind.tooManyAttempts,
        serverMessage: error.message,
        cause: error,
      );
    }
    return AuthFailure(
      AuthFailureKind.unknown,
      serverMessage: error.message,
      cause: error,
    );
  }

  if (error is GoogleSignInException) {
    return AuthFailure(
      error.code == GoogleSignInExceptionCode.canceled
          ? AuthFailureKind.cancelled
          : AuthFailureKind.unavailable,
      serverMessage: error.description,
      cause: error,
    );
  }

  if (error is TimeoutException) {
    return AuthFailure(AuthFailureKind.network, cause: error);
  }

  return AuthFailure(AuthFailureKind.unknown, cause: error);
}

/// [AuthRepository] implemented on Supabase Auth.
class SupabaseAuthRepository implements AuthRepository {
  /// Creates a repository over [client].
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  /// Google sign-in may only be initialized once per process; the SDK says so
  /// explicitly, and calling `initialize` twice is undefined behaviour.
  bool _googleInitialized = false;

  @override
  bool get isAvailable => SupabaseConfig.isConfigured;

  @override
  AuthIdentity? get currentIdentity {
    final user = _client.auth.currentUser;
    return user == null ? null : _identityOf(user);
  }

  @override
  Stream<AuthSessionEvent> get sessionEvents => _client.auth.onAuthStateChange
      .map(
        (state) => AuthSessionEvent(
          identity: state.session?.user == null
              ? null
              : _identityOf(state.session!.user),
          // The SDK keeps the session when a refresh fails for lack of network
          // and clears it, with this reason, when the server rejects it — which
          // is exactly the offline/online split the state machine needs.
          sessionExpired: state.signOutReason == SignOutReason.sessionExpired,
        ),
      );

  @override
  Future<AuthIdentity?> restoreSession() async {
    // `Supabase.initialize()` already restored the persisted session from secure
    // storage before returning (a local read, no network), so the current
    // session is the restored one. A refresh that is still in flight, or that
    // fails, is handled by the session-event stream — never by blocking here.
    return currentIdentity;
  }

  @override
  Future<AuthIdentity> signInWithPassword({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      final user = response.user;
      if (user == null) {
        throw const AuthFailure(AuthFailureKind.unknown);
      }
      return _identityOf(user);
    } catch (error) {
      throw mapAuthFailure(error);
    }
  }

  @override
  Future<SignUpOutcome> signUpIndividual({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final address = email.trim();
    try {
      final response = await _client.auth.signUp(
        email: address,
        password: password,
        // The Task 16 sign-up trigger copies `full_name` from the user metadata
        // into the new `profiles` row, so this is the only place the name has to
        // be sent.
        data: {'full_name': fullName.trim()},
      );

      final session = response.session;
      if (session != null) {
        return SignUpSignedIn(_identityOf(session.user));
      }

      // An address that already has an account is reported as a user with no
      // identities, so the same e-mail can be tried for both paths without the
      // server revealing whether it is registered.
      final user = response.user;
      if (user != null && (user.identities?.isEmpty ?? false)) {
        throw const AuthFailure(AuthFailureKind.emailInUse);
      }

      // No session and a real user: the project has email confirmation on, and
      // the account is waiting for the link to be opened.
      return SignUpConfirmationRequired(address);
    } catch (error) {
      throw mapAuthFailure(error);
    }
  }

  @override
  Future<AuthIdentity> signInWithGoogle() async {
    if (!SupabaseConfig.hasGoogleClientId) {
      throw const AuthFailure(AuthFailureKind.unavailable);
    }
    try {
      await _ensureGoogleInitialized();
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw const AuthFailure(AuthFailureKind.unavailable);
      }
      final response = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );
      final user = response.user;
      if (user == null) {
        throw const AuthFailure(AuthFailureKind.unknown);
      }
      return _identityOf(user);
    } catch (error) {
      throw mapAuthFailure(error);
    }
  }

  @override
  Future<void> sendPasswordRecoveryCode(String email) async {
    try {
      // The recovery mail must carry the code (`{{ .Token }}` in the template),
      // which is what lets the reset finish inside the app with no deep link.
      await _client.auth.resetPasswordForEmail(email.trim());
    } catch (error) {
      throw mapAuthFailure(error);
    }
  }

  @override
  Future<void> verifyRecoveryCode({
    required String email,
    required String code,
  }) async {
    try {
      await _client.auth.verifyOTP(
        type: OtpType.recovery,
        email: email.trim(),
        token: code.trim(),
      );
    } catch (error) {
      throw mapAuthFailure(error);
    }
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    try {
      await _client.auth.updateUser(UserAttributes(password: newPassword));
    } catch (error) {
      throw mapAuthFailure(error);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      // Local scope on purpose: the device forgets the session immediately,
      // whether or not there is network. Revoking it server-side, and the
      // sync-then-wipe logout flow around it, belong to the logout task.
      await _client.auth.signOut(scope: SignOutScope.local);
    } catch (error) {
      throw mapAuthFailure(error);
    }
  }

  /// Initializes the native Google SDK once, with the Web client ID the
  /// Supabase Auth server is configured to trust.
  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    await GoogleSignIn.instance.initialize(
      serverClientId: SupabaseConfig.googleWebClientId,
    );
    _googleInitialized = true;
  }

  /// Reduces a Supabase user to the identity the app works with.
  static AuthIdentity _identityOf(User user) => AuthIdentity(
    userId: user.id,
    email: user.email,
    // Confirmed means the address is verified; a sign-up waiting for its
    // confirmation link never reaches here, because it has no session.
    emailConfirmed: user.emailConfirmedAt != null,
    fullName: user.userMetadata?['full_name'] as String?,
    signedInWithGoogle: user.appMetadata['provider'] == 'google',
  );
}
