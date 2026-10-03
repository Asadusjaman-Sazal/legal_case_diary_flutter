/// ViewModel for the app's auth state: who is signed in, and every action that
/// changes it.
///
/// It is a thin, typed layer over [AuthRepository] — no screen talks to the
/// Supabase SDK — with two jobs of its own:
///
/// * **The app-wide session state** the sign-in gate and the drawer read:
///   the current identity, whether a session was rejected by the server, and
///   whether the first-run gate has been satisfied.
/// * **The adoption choke point.** Every path that produces a session (sign-in,
///   sign-up, Google, a restored session at startup) runs
///   [IdentityAdoptionService.adopt] before it reports success, so authenticated
///   repositories are never writable over placeholder-owned rows.
///
/// Form submissions deliberately throw [AuthFailure] to the caller: each screen
/// owns its own error text and its own spinner, so one screen's failure can
/// never leak into another's.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_providers.dart';
import '../../../core/services/local_identity_service.dart';
import '../../../shared/providers/database_provider.dart';
import '../../../shared/providers/locale_provider.dart';
import '../../accounts_and_profile/data/firm_repository.dart';
import '../../accounts_and_profile/data/profile_name_store.dart';
import '../../accounts_and_profile/data/profile_picture_store.dart';
import '../../accounts_and_profile/data/profile_repository.dart';
import '../../settings/data/backup_metadata_store.dart';
import '../data/auth_repository.dart';
import '../data/identity_adoption_service.dart';
import '../data/local_auth_service.dart';

/// The session state the rest of the app reads.
class AuthState {
  /// Creates a state.
  const AuthState({
    this.identity,
    this.sessionExpired = false,
    this.adoptionBlocked = false,
    this.passwordRecovery = false,
  });

  /// The signed-in identity, or null when nobody is signed in.
  final AuthIdentity? identity;

  /// True when the server rejected the stored session (revoked, password
  /// changed). The device is online and the user must sign in again; the local
  /// diary is still readable — Phase 4 owns that behaviour, this flag is what
  /// it reads.
  final bool sessionExpired;

  /// True when this device's local data already belongs to another account, so
  /// adoption refused and no ownership was rewritten.
  final bool adoptionBlocked;

  /// True while the user is in the middle of setting a new password, having
  /// arrived through an emailed recovery link. The session is real but not yet
  /// usable for anything else, so the router keeps the user on the reset screen
  /// until the new password is set.
  final bool passwordRecovery;

  /// Whether somebody is signed in.
  bool get isSignedIn => identity != null;

  /// This state with the given fields replaced.
  AuthState copyWith({
    AuthIdentity? identity,
    bool? sessionExpired,
    bool? adoptionBlocked,
    bool? passwordRecovery,
    bool clearIdentity = false,
  }) => AuthState(
    identity: clearIdentity ? null : (identity ?? this.identity),
    sessionExpired: sessionExpired ?? this.sessionExpired,
    adoptionBlocked: adoptionBlocked ?? this.adoptionBlocked,
    passwordRecovery: passwordRecovery ?? this.passwordRecovery,
  );

  @override
  String toString() =>
      'AuthState(${identity ?? 'signed out'}, '
      'sessionExpired: $sessionExpired, adoptionBlocked: $adoptionBlocked)';
}

/// The app's auth state machine.
class AuthViewModel extends AsyncNotifier<AuthState> {
  /// Riverpod provider for [AuthViewModel].
  static final provider = AsyncNotifierProvider<AuthViewModel, AuthState>(
    () => AuthViewModel(),
  );

  /// The authentication boundary this view model drives.
  AuthRepository get _repository => ref.read(authRepositoryProvider);

  /// The local identity cache (last account, first-run gate).
  LocalAuthService get _local => ref.read(localAuthServiceProvider);

  /// Whether an arriving recovery session is the echo of this device's own
  /// [verifyRecoveryCode] call rather than an e-mail link the user opened.
  ///
  /// The SDK reports a typed code as the same `passwordRecovery` event a link
  /// produces, and that event is the only signal either way. Only a link may
  /// raise the flag that sends the app to the reset screen: a typed code was
  /// entered *on* that screen, so raising it would drag the user there — and
  /// off the Settings sub-page a Change Password was started from.
  bool _typedRecoveryInFlight = false;

  @override
  Future<AuthState> build() async {
    final repository = ref.watch(authRepositoryProvider);

    // Session changes arrive from the SDK: a sign-out (including the server
    // rejecting a refresh) and the account-switch cases both land here.
    final subscription = repository.sessionEvents.listen(_onSessionEvent);
    ref.onDispose(subscription.cancel);

    final identity = await repository.restoreSession();
    if (identity == null) {
      return const AuthState();
    }

    final blocked = await _adopt(identity);
    return AuthState(identity: identity, adoptionBlocked: blocked);
  }

  /// Signs in with email and password, adopting any offline data first.
  ///
  /// A join-a-firm sign-up that had to wait for an email confirmation leaves its
  /// code pending; it is redeemed here, on the first sign-in with a session.
  Future<AuthIdentity> signIn({
    required String email,
    required String password,
    String? firmId,
  }) async {
    final identity = await _repository.signInWithPassword(
      email: email,
      password: password,
    );
    await _completeSignIn(identity, firmId: firmId);
    return identity;
  }

  /// Signs in with Google, adopting any offline data first.
  Future<AuthIdentity> signInWithGoogle({String? firmId}) async {
    final identity = await _repository.signInWithGoogle();
    await _completeSignIn(identity, firmId: firmId);
    return identity;
  }

  /// Creates an individual account.
  ///
  /// Returns the outcome unchanged so the screen can show the Check-Your-Email
  /// state when the project has email confirmation on. [inviteCode] is redeemed
  /// *after* the account exists — and after it has a session — because a
  /// confirmation-mail sign-up has no session to redeem with yet; the code is
  /// kept until then so onboarding stays retryable.
  Future<SignUpOutcome> signUpIndividual({
    required String fullName,
    required String email,
    required String password,
    String barAssociation = '',
    String? inviteCode,
  }) async {
    final code = inviteCode?.trim();
    if (code != null && code.isNotEmpty) {
      await _local.setPendingInviteCode(code);
    }

    final outcome = await _repository.signUpIndividual(
      fullName: fullName,
      email: email,
      password: password,
      barAssociation: barAssociation,
    );
    if (outcome is SignUpSignedIn) {
      await _completeSignIn(outcome.identity);
    }
    return outcome;
  }

  /// The invite code still waiting to be redeemed, or null.
  String? get pendingInviteCode => _local.pendingInviteCode;

  /// Remembers an invite code the user typed, so a Google sign-up can redeem it
  /// after the session exists.
  Future<void> rememberInviteCode(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return;
    await _local.setPendingInviteCode(trimmed);
  }

  /// Redeems the pending invite code, clearing it once the firm is joined.
  ///
  /// Throws [AuthFailure] on an invalid code, the rate limit, or no network.
  /// The code is deliberately kept in every failure case: onboarding stays
  /// retryable, which is what the Addendum requires.
  Future<InviteRedemption> redeemPendingInvite() async {
    final code = _local.pendingInviteCode;
    if (code == null) {
      throw const AuthFailure(AuthFailureKind.invalidCode);
    }

    final redemption = await ref.read(firmRepositoryProvider).redeemInvite(code);
    await _local.clearPendingInviteCode();
    // Pull the new membership straight away, so the permission flags and their
    // freshness stamp are cached before the first case write reads them. A
    // failed pull leaves the reachable default (fail closed), and the launch /
    // resume refresh will fill it in.
    await (await ref.read(profileRepositoryProvider.future)).refresh();
    return redemption;
  }

  /// Sends the password-recovery code.
  Future<void> sendPasswordRecoveryCode(String email) =>
      _repository.sendPasswordRecoveryCode(email);

  /// Verifies the recovery code, leaving the user able to set a password.
  ///
  /// The session this creates is the one a link creates, and the SDK reports
  /// both as a single `passwordRecovery` event — so the call is latched here
  /// and the event it produces is spent on this rather than taken for a link.
  Future<void> verifyRecoveryCode({
    required String email,
    required String code,
  }) async {
    _typedRecoveryInFlight = true;
    try {
      await _repository.verifyRecoveryCode(email: email, code: code);
    } catch (_) {
      // A refused code creates no session, so no event is coming to spend the
      // latch. Releasing it here is what keeps a link the user opens later
      // from being swallowed as this call's echo.
      _typedRecoveryInFlight = false;
      rethrow;
    }
  }

  /// Sets a new password for the recovered (or signed-in) user.
  ///
  /// Clearing the recovery flag is what lets the router release the user: once
  /// the password is set, the session the recovery link created becomes an
  /// ordinary one and the app opens as usual.
  Future<void> updatePassword(String newPassword) async {
    await _repository.updatePassword(newPassword);
    await _local.markGateSatisfied();
    final current = state.value;
    if (current != null && current.passwordRecovery) {
      state = AsyncData(current.copyWith(passwordRecovery: false));
    }
  }

  /// Signs out of this device.
  ///
  /// The branched flow around it — sync first, auto-export, then wipe — is the
  /// logout task's; this only ends the session and forgets the cached account,
  /// and it never touches local data.
  ///
  /// One thing it does clean up is the *server's* copy of an unfinished
  /// onboarding (see [_abandonProvisionalOnboarding]), which has to happen while
  /// the session still exists.
  Future<void> signOut() async {
    await _abandonProvisionalOnboarding();
    await _repository.signOut();
    // The pull-only caches belong to the account that pulled them: they are
    // emptied rather than left behind for whoever signs in next (Revision 2.4
    // Addendum: the profile cache is invalidated on logout and account switch).
    await (await ref.read(profileRepositoryProvider.future)).invalidate();
    await _local.clear();
    // The per-user caches that live in SharedPreferences are emptied too, so a
    // next account on this device cannot read the previous holder's personal
    // details, picture, language or backup history (Revision 2.4 Addendum: the
    // profile and preference caches are invalidated on logout and account
    // switch). The database wipe the branched logout runs first already clears
    // the per-user rows; these are the values that live outside it.
    await _clearPerUserCaches();
    state = const AsyncData(AuthState());
  }

  /// Empties the SharedPreferences-backed per-user caches.
  Future<void> _clearPerUserCaches() async {
    await ref.read(profileFieldsProvider.notifier).clear();
    await ref.read(profilePictureProvider.notifier).clear();
    await ref.read(backupMetadataProvider.notifier).reset();
    ref.read(localeProvider.notifier).reset();
  }

  /// Removes the server-side provisional account an abandoned onboarding left
  /// behind, if this device has one.
  ///
  /// The signal is the **unredeemed invite code**: it exists only after a
  /// join-firm sign-up created an account and its redemption has not succeeded,
  /// and prefer signing out is where that attempt ends — the code is discarded
  /// in the same breath. Anything less than that state calls nothing, and the
  /// server refuses on its own unless the account is provably empty, so a
  /// signed-in lawyer with a real diary can never be affected by this path.
  Future<void> _abandonProvisionalOnboarding() async {
    if (_local.pendingInviteCode == null) return;
    try {
      await ref.read(firmRepositoryProvider).abandonOnboarding();
    } catch (_) {
      // ponytail: best-effort, because a sign-out must always succeed — it is
      // the one action a user may need precisely when the network is gone. The
      // ceiling is that an offline sign-out leaves an empty provisional account
      // behind; the upgrade path is to retry the call on the next launch while
      // the account is known to be unprovisioned.
    }
  }

  /// Records the identity, adopts offline data, and marks the gate satisfied.
  Future<void> _completeSignIn(AuthIdentity identity, {String? firmId}) async {
    final blocked = await _adopt(identity, firmId: firmId);
    await _local.rememberIdentity(identity);
    await _local.markGateSatisfied();
    state = AsyncData(
      AuthState(identity: identity, adoptionBlocked: blocked),
    );
  }

  /// Runs adoption, turning a cross-account refusal into a flag.
  ///
  /// Adoption also binds the device id to the account (see
  /// [IdentityAdoptionService.adopt]), which is what makes every later local
  /// write carry the same UUID the server shows in `Authentication > Users`.
  Future<bool> _adopt(AuthIdentity identity, {String? firmId}) async {
    final database = await ref.read(databaseProvider.future);
    final service = IdentityAdoptionService(
      database,
      ref.read(localIdentityServiceProvider),
    );
    try {
      await service.adopt(identity, firmId: firmId);
      return false;
    } on AuthFailure catch (failure) {
      if (failure.kind != AuthFailureKind.accountMismatch) rethrow;
      // Fail closed: the diary stays as it is and the screen explains why.
      return true;
    }
  }

  /// Applies a session change from the SDK.
  void _onSessionEvent(AuthSessionEvent event) {
    final current = state.value ?? const AuthState();
    if (event.identity == null) {
      state = AsyncData(
        AuthState(sessionExpired: event.sessionExpired),
      );
      return;
    }
    // A recovery session: adopt the identity like any other sign-in. Whether it
    // raises the flag that holds the user on the reset screen depends on where
    // it came from — an opened link, or a code typed into this device. Checked
    // before the identity-equality guard below, because the flag is the change.
    if (event.passwordRecovery) {
      final typed = _typedRecoveryInFlight;
      _typedRecoveryInFlight = false;
      unawaited(_beginPasswordRecovery(event.identity!, raiseFlag: !typed));
      return;
    }
    // A token refresh carries the same identity; only real changes matter.
    if (current.identity == event.identity) return;
    unawaited(_completeSignIn(event.identity!));
  }

  /// Completes the sign-in a recovery session implies.
  ///
  /// [raiseFlag] is true only for a link. A link lands the user on the app's
  /// ordinary route, so the flag is what takes them to the reset screen and
  /// keeps them there until the new password is set. A typed code was entered
  /// on that screen already, so it signs in silently: the user is released to
  /// the app as any other sign-in, and a Change Password started in Settings
  /// returns to Manage Account instead of being dragged to the auth screen.
  Future<void> _beginPasswordRecovery(
    AuthIdentity identity, {
    required bool raiseFlag,
  }) async {
    await _completeSignIn(identity);
    if (!raiseFlag) return;
    final completed = state.value;
    if (completed == null) return;
    state = AsyncData(completed.copyWith(passwordRecovery: true));
  }
}

/// Global provider alias for the auth ViewModel.
final authViewModelProvider = AuthViewModel.provider;

/// The signed-in identity, or null.
///
/// A narrow selector, so a screen that only needs "who is signed in" (the
/// drawer header, the gate, the account cards) never rebuilds on an unrelated
/// auth change.
final authIdentityProvider = Provider<AuthIdentity?>(
  (ref) => ref.watch(authViewModelProvider.select((s) => s.value?.identity)),
);

/// The restored session identity, awaited.
///
/// The sign-in gate reads this rather than the synchronous selector: it must
/// know whether a session exists *before the first frame*, and restoring one is
/// a local read — no network, so it never delays the diary.
final authSessionProvider = FutureProvider<AuthIdentity?>(
  (ref) async => (await ref.watch(authViewModelProvider.future)).identity,
);

/// Whether the user is setting a new password after opening a recovery link.
///
/// A narrow selector: the router and the reset screen both need it, and neither
/// should rebuild on an unrelated auth change.
final passwordRecoveryPendingProvider = Provider<bool>(
  (ref) => ref.watch(
    authViewModelProvider.select((s) => s.value?.passwordRecovery ?? false),
  ),
);

/// Whether this device's local data belongs to another account.
final authAdoptionBlockedProvider = Provider<bool>(
  (ref) => ref.watch(
    authViewModelProvider.select((s) => s.value?.adoptionBlocked ?? false),
  ),
);
