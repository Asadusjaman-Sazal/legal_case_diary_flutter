/// Authentication boundary for the whole app.
///
/// Every screen and view model talks to [AuthRepository] only, never to the
/// Supabase SDK, so a build without backend configuration (and every test) runs
/// with [UnavailableAuthRepository] in place of a live backend. Credentials —
/// passwords, recovery codes, tokens — never travel through this API: it deals
/// in signed-in identity and typed failures, and Supabase Auth owns the rest.
library;

import '../../../core/errors/error_log.dart';

/// The signed-in identity, reduced to what the rest of the app needs.
///
/// Deliberately carries no token: the session lives in secure storage behind
/// the SDK, and nothing here is written to the database or to a sync payload.
class AuthIdentity {
  /// Creates an identity.
  const AuthIdentity({
    required this.userId,
    this.email,
    this.emailConfirmed = true,
    this.fullName,
    this.signedInWithGoogle = false,
  });

  /// Supabase `auth.users.id` — the value every ownership column stores.
  final String userId;

  /// Account email, when the provider gave one.
  final String? email;

  /// Whether the email is confirmed. False only while a sign-up is waiting for
  /// the user to open the confirmation link.
  final bool emailConfirmed;

  /// Display name, when the sign-up form or the identity provider supplied one.
  final String? fullName;

  /// Whether this session came from Google sign-in.
  final bool signedInWithGoogle;

  /// This identity with the given fields replaced.
  AuthIdentity copyWith({
    String? userId,
    String? email,
    bool? emailConfirmed,
    String? fullName,
    bool? signedInWithGoogle,
  }) => AuthIdentity(
    userId: userId ?? this.userId,
    email: email ?? this.email,
    emailConfirmed: emailConfirmed ?? this.emailConfirmed,
    fullName: fullName ?? this.fullName,
    signedInWithGoogle: signedInWithGoogle ?? this.signedInWithGoogle,
  );

  @override
  bool operator ==(Object other) =>
      other is AuthIdentity &&
      other.userId == userId &&
      other.email == email &&
      other.emailConfirmed == emailConfirmed &&
      other.fullName == fullName &&
      other.signedInWithGoogle == signedInWithGoogle;

  @override
  int get hashCode =>
      Object.hash(userId, email, emailConfirmed, fullName, signedInWithGoogle);

  /// Never prints the email or name: an identity is PII, and this string can
  /// reach a log or a crash report.
  @override
  String toString() => 'AuthIdentity($userId)';
}

/// Why an auth call failed, in the terms the screens must present.
///
/// The UI maps each kind to its own localized message; the repository never
/// hands a raw server string to the user.
enum AuthFailureKind {
  /// Email/password pair rejected.
  invalidCredentials,

  /// Account exists but the email has not been confirmed yet.
  emailNotConfirmed,

  /// Sign-up attempted for an email that already has an account.
  emailInUse,

  /// Password rejected as too weak by the server's policy.
  weakPassword,

  /// Server-side rate limit (sign-up, recovery emails).
  rateLimited,

  /// Invite code did not match an unused, unrevoked code.
  invalidCode,

  /// Too many failed invite attempts inside the rate-limit window.
  tooManyAttempts,

  /// Firm administration was attempted with no connection.
  ///
  /// Creating or revoking an invite is a server-side decision, so the
  /// owner-side primitives are online-only — and this is the one state that
  /// gets its own sentence instead of the generic network failure, because the
  /// user has to know that managing a firm is simply not an offline feature.
  firmAdminOffline,

  /// Firm mode was attempted without an active premium subscription.
  ///
  /// The plan's rule is that the free plan is strictly individual and
  /// single-device, so becoming a firm owner is a premium step. The screen
  /// checks entitlement first and routes to the Paywall; this kind exists for
  /// the server's own refusal, which is the authoritative one.
  premiumRequired,

  /// The account is already a member of that firm.
  alreadyMember,

  /// The user dismissed the Google sign-in sheet. Not an error to show.
  cancelled,

  /// Google itself refused the sign-in.
  ///
  /// Android's Credential Manager reports a Google-side configuration failure —
  /// a wrong signing SHA, package name or `serverClientId` — as a *cancellation*,
  /// which would otherwise vanish into [cancelled] and leave the user staring at
  /// an unchanged screen. The failure is real and worth a sentence, so it gets
  /// its own kind instead of the dismissal's silence.
  googleSignInFailed,

  /// The request never reached the server.
  ///
  /// Offline, DNS failure, a timeout. A request the server *answered* — even
  /// with a 5xx — is [unknown] instead, because the connection was demonstrably
  /// fine and "check your internet" would then be the one thing certainly wrong.
  network,

  /// The local database already belongs to a different account.
  ///
  /// Adoption fails closed rather than handing one account's diary to another;
  /// the account-switch wipe belongs to the logout flow.
  accountMismatch,

  /// This build has no backend configured, or a platform capability is absent.
  unavailable,

  /// Anything not classified above.
  unknown,
}

/// A typed auth failure.
///
/// [serverMessage] is kept for the log's detail line, so a kind like `unknown`
/// can be acted on — screens render their own localized text from [kind].
class AuthFailure implements Exception, DiagnosableFailure {
  /// Creates a failure of [kind].
  const AuthFailure(this.kind, {this.serverMessage, this.cause});

  /// What went wrong, in screen-level terms.
  final AuthFailureKind kind;

  /// The server's own message, when there was one. Never rendered by a screen;
  /// it exists for the log's detail line.
  final String? serverMessage;

  /// Underlying error, for debugging.
  final Object? cause;

  /// The log's label: the kind, so entries stay scannable and comparable.
  @override
  String get diagnosticLabel => 'AuthFailure(${kind.name})';

  /// The log's detail: the server's reply and the underlying cause — what a
  /// reader fixes from.
  @override
  String? get diagnosticDetail {
    final parts = <String>[
      if (serverMessage != null && serverMessage!.trim().isNotEmpty)
        serverMessage!,
      if (cause != null) cause.toString(),
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  String toString() => 'AuthFailure(${kind.name})';
}

/// A change in the session, in the terms the auth state machine needs.
///
/// The distinction that matters — and that the Supabase SDK already makes for
/// us — is between a refresh that failed for lack of network (the session is
/// kept, the diary stays fully usable) and one the server rejected outright
/// (revoked session, changed password: re-sign-in is required).
class AuthSessionEvent {
  /// Creates an event.
  const AuthSessionEvent({
    this.identity,
    this.sessionExpired = false,
    this.passwordRecovery = false,
  });

  /// The identity after the change; null when signed out.
  final AuthIdentity? identity;

  /// True when the stored session can no longer be used and a sign-in is owed.
  ///
  /// The server rejecting the refresh token is the usual cause but not the only
  /// one: a persisted session that cannot be parsed back at all (the SDK's
  /// `SignOutReason.sessionMissing`) needs the same sign-in, so it is carried
  /// here too and decided in one place, `authSessionNeedsSignIn`.
  final bool sessionExpired;

  /// True when the change came from opening a password-recovery link.
  ///
  /// Such a link signs the user in as a side effect of being verified, so the
  /// session exists but is not for using the app: the user must set a new
  /// password first, which is why the state machine treats this as its own kind
  /// of change rather than as an ordinary sign-in.
  final bool passwordRecovery;

  @override
  bool operator ==(Object other) =>
      other is AuthSessionEvent &&
      other.identity == identity &&
      other.sessionExpired == sessionExpired &&
      other.passwordRecovery == passwordRecovery;

  @override
  int get hashCode => Object.hash(identity, sessionExpired, passwordRecovery);

  @override
  String toString() =>
      'AuthSessionEvent($identity, sessionExpired: $sessionExpired, '
      'passwordRecovery: $passwordRecovery)';
}

/// What a sign-up attempt produced.
///
/// The project's email-confirmation setting decides which of the two happens,
/// and the app handles both — see the Phase 2 Check-Your-Email state.
sealed class SignUpOutcome {
  const SignUpOutcome();
}

/// The account was created and is signed in straight away.
class SignUpSignedIn extends SignUpOutcome {
  /// Creates the outcome with the new [identity].
  const SignUpSignedIn(this.identity);

  /// The new identity.
  final AuthIdentity identity;
}

/// The account was created but must confirm its email before it can sign in.
class SignUpConfirmationRequired extends SignUpOutcome {
  /// Creates the outcome for [email].
  const SignUpConfirmationRequired(this.email);

  /// The address the confirmation mail went to.
  final String email;
}

/// The authentication operations the app performs.
abstract class AuthRepository {
  /// Whether this build can reach a backend at all.
  ///
  /// False in a build without the dart-defines and in every test: the app is
  /// then fully usable offline and sign-in says so instead of failing oddly.
  bool get isAvailable;

  /// The identity of the persisted session, if there is one.
  ///
  /// Synchronous and network-free on purpose: it is read during a cold start to
  /// decide who owns this device without ever blocking the diary (Phase 4).
  AuthIdentity? get currentIdentity;

  /// Emits on every sign-in, sign-out and token-user change.
  Stream<AuthSessionEvent> get sessionEvents;

  /// Restores a persisted session, if the device has one.
  ///
  /// Resolves locally — a session is restored without network, and a refresh
  /// that fails is the Phase 4 state machine's business, not this call's.
  Future<AuthIdentity?> restoreSession();

  /// Signs in with email and password.
  Future<AuthIdentity> signInWithPassword({
    required String email,
    required String password,
  });

  /// Creates an individual account (the plan's "starts as an Individual").
  ///
  /// [fullName] and [barAssociation] are passed as `full_name` and
  /// `bar_association` metadata because the sign-up trigger copies both into the
  /// new `profiles` row — the only moment a confirmation-mail sign-up can put
  /// anything there, since it has no session yet.
  Future<SignUpOutcome> signUpIndividual({
    required String fullName,
    required String email,
    required String password,
    String barAssociation = '',
  });

  /// Signs in with a native Google ID token.
  Future<AuthIdentity> signInWithGoogle();

  /// Sends the password-recovery code to [email].
  Future<void> sendPasswordRecoveryCode(String email);

  /// Verifies the recovery [code] and leaves the user able to set a password.
  Future<void> verifyRecoveryCode({required String email, required String code});

  /// Sets a new password for the signed-in (or recovered) user.
  Future<void> updatePassword(String newPassword);

  /// Signs the current session out on this device.
  Future<void> signOut();
}

/// The repository used when this build has no backend configured.
///
/// Reports an empty identity — so the diary opens and local writes work exactly
/// as they did in Part A — and fails every auth call with
/// [AuthFailureKind.unavailable] rather than reaching for an uninitialized
/// Supabase instance.
class UnavailableAuthRepository implements AuthRepository {
  /// Creates the unavailable repository.
  const UnavailableAuthRepository();

  @override
  bool get isAvailable => false;

  @override
  AuthIdentity? get currentIdentity => null;

  @override
  Stream<AuthSessionEvent> get sessionEvents => const Stream.empty();

  @override
  Future<AuthIdentity?> restoreSession() async => null;

  // Every method is `async` on purpose: a synchronous `throw` would escape an
  // `await`-ing caller's error handling, which is exactly how a screen would
  // crash instead of showing its message.

  @override
  Future<AuthIdentity> signInWithPassword({
    required String email,
    required String password,
  }) async => throw const AuthFailure(AuthFailureKind.unavailable);

  @override
  Future<SignUpOutcome> signUpIndividual({
    required String fullName,
    required String email,
    required String password,
    String barAssociation = '',
  }) async => throw const AuthFailure(AuthFailureKind.unavailable);

  @override
  Future<AuthIdentity> signInWithGoogle() async =>
      throw const AuthFailure(AuthFailureKind.unavailable);

  @override
  Future<void> sendPasswordRecoveryCode(String email) async =>
      throw const AuthFailure(AuthFailureKind.unavailable);

  @override
  Future<void> verifyRecoveryCode({
    required String email,
    required String code,
  }) async => throw const AuthFailure(AuthFailureKind.unavailable);

  @override
  Future<void> updatePassword(String newPassword) async =>
      throw const AuthFailure(AuthFailureKind.unavailable);

  @override
  Future<void> signOut() async {}
}
