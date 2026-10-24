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

import '../../../core/errors/error_log.dart';
import '../../../core/errors/error_log_provider.dart';
import '../../../core/providers/device_providers.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/push/push_gateway.dart';
import '../../../core/services/local_identity_service.dart';
import '../../../shared/providers/database_provider.dart';
import '../../../shared/providers/locale_provider.dart';
import '../../accounts_and_profile/data/firm_logo_store.dart';
import '../../accounts_and_profile/data/firm_repository.dart';
import '../../accounts_and_profile/data/profile_name_store.dart';
import '../../accounts_and_profile/data/profile_picture_store.dart';
import '../../accounts_and_profile/data/profile_repository.dart';
import '../../admin/presentation/admin_viewmodel.dart';
import '../../../core/providers/backup_providers.dart';
import '../../settings/data/backup_metadata_store.dart';
import '../../settings/data/backup_repository.dart';
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

  /// Runs [action] under [area], recording anything it lets out before letting
  /// it out.
  ///
  /// **This is where a failure the user saw is remembered.** Screens catch
  /// [AuthFailure] to raise their own banner, so nothing here escapes to the
  /// global capture in `error_capture.dart` — a wrong password, a rate limit or
  /// a dead network reaches the user as a message and leaves no trace at all.
  /// The edge of the layer that owns the operation is therefore the one point
  /// every banner passes through.
  ///
  /// A cancelled Google sheet is excluded deliberately: it is the user closing
  /// a sheet, not a fault, and a log full of their own decisions is a log
  /// nobody can read.
  Future<T> _guard<T>(String area, Future<T> Function() action) async {
    try {
      return await action();
    } on Object catch (error) {
      if (error is! AuthFailure || error.kind != AuthFailureKind.cancelled) {
        recordFailure(ref.read(errorLogProvider), area, error);
      }
      rethrow;
    }
  }

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
  }) => _guard('auth.signIn', () async {
    _markFreshDeviceCheck();
    final identity = await _repository.signInWithPassword(
      email: email,
      password: password,
    );
    await _completeSignIn(identity, firmId: firmId);
    return identity;
  });

  /// Signs in with Google, adopting any offline data first.
  Future<AuthIdentity> signInWithGoogle({String? firmId}) =>
      _guard('auth.signInWithGoogle', () async {
        _markFreshDeviceCheck();
        final identity = await _repository.signInWithGoogle();
        await _completeSignIn(identity, firmId: firmId);
        return identity;
      });

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
  }) => _guard('auth.signUpIndividual', () async {
    _markFreshDeviceCheck();
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
    } else if (outcome is SignUpConfirmationRequired) {
      // The one record that survives the screen: without it a restart while the
      // user is in their mailbox lands them on an empty sign-up form.
      await _local.setPendingConfirmationEmail(outcome.email);
    }
    return outcome;
  });

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
  Future<InviteRedemption>
  redeemPendingInvite() => _guard('auth.redeemInvite', () async {
    final code = _local.pendingInviteCode;
    if (code == null) {
      throw const AuthFailure(AuthFailureKind.invalidCode);
    }

    final redemption = await ref
        .read(firmRepositoryProvider)
        .redeemInvite(code);
    await _local.clearPendingInviteCode();
    // Pull the new membership straight away, so the permission flags and their
    // freshness stamp are cached before the first case write reads them. A
    // failed pull leaves the reachable default (fail closed), and the launch /
    // resume refresh will fill it in.
    await (await ref.read(profileRepositoryProvider.future)).refresh();
    return redemption;
  });

  /// Sends the sign-up confirmation mail for [email] again.
  ///
  /// The mail can simply not arrive — a spam folder, a typo in the domain, a
  /// provider that ate it — and the only other way forward for a pending sign-up
  /// is the typed cleanup in [discardUnconfirmedSignup]. The server's own limit
  /// is the limit here, so a refusal arrives as
  /// [AuthFailureKind.rateLimited] and the screen words it.
  Future<void> resendConfirmationEmail(String email) =>
      _guard('auth.resendConfirmationEmail', () async {
        await _repository.resendConfirmationEmail(email);
      });

  /// Whether the address of a just-made sign-up is confirmed **now**.
  ///
  /// Never throws and never signs the device in: the screen's only reaction to
  /// "no" is to keep showing the screen it already has, so an unconfirmed
  /// address, a dead socket and a server refusal are one answer. A "yes" ends
  /// the wait — the pending record is spent, because the address is confirmed
  /// and the only thing left for the user is Login.
  Future<bool> isEmailConfirmed({
    required String email,
    required String password,
  }) async {
    try {
      final confirmed = await _repository.isEmailConfirmed(
        email: email,
        password: password,
      );
      if (confirmed) await _local.clearPendingConfirmationEmail();
      return confirmed;
    } catch (error) {
      // Recorded rather than thrown: a failed check is exactly the state the
      // user is left standing in, and the log is where it can be explained.
      recordFailure(ref.read(errorLogProvider), 'auth.isEmailConfirmed', error);
      return false;
    }
  }

  /// Removes an unconfirmed sign-up so its (mistyped) address can be used again.
  ///
  /// The password is the server's own check that the caller is the person who
  /// made the account; on success the pending record goes with it, because there
  /// is no longer a sign-up waiting to be confirmed.
  Future<DiscardSignupOutcome> discardUnconfirmedSignup({
    required String email,
    required String password,
  }) async {
    final outcome = await _repository.discardUnconfirmedSignup(
      email: email,
      password: password,
    );
    if (outcome == DiscardSignupOutcome.removed) {
      await _local.clearPendingConfirmationEmail();
    }
    return outcome;
  }

  /// Forgets a waiting confirmation the user has finished with.
  ///
  /// Called when they go to Login instead: the screen is over either way, and
  /// the next launch must not open on a sign-up they have left.
  Future<void> forgetPendingConfirmation() =>
      _local.clearPendingConfirmationEmail();

  /// Sends the password-recovery code.
  Future<void> sendPasswordRecoveryCode(String email) =>
      _guard('auth.sendRecoveryCode', () async {
        await _repository.sendPasswordRecoveryCode(email);
      });

  /// Verifies the recovery code, leaving the user able to set a password.
  ///
  /// The session this creates is the one a link creates, and the SDK reports
  /// both as a single `passwordRecovery` event — so the call is latched here
  /// and the event it produces is spent on this rather than taken for a link.
  Future<void> verifyRecoveryCode({
    required String email,
    required String code,
  }) => _guard('auth.verifyRecoveryCode', () async {
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
  });

  /// Sets a new password for the recovered (or signed-in) user.
  ///
  /// Clearing the recovery flag is what lets the router release the user: once
  /// the password is set, the session the recovery link created becomes an
  /// ordinary one and the app opens as usual.
  Future<void> updatePassword(String newPassword) =>
      _guard('auth.updatePassword', () async {
        await _repository.updatePassword(newPassword);
        await _local.markGateSatisfied();
        final current = state.value;
        if (current != null && current.passwordRecovery) {
          state = AsyncData(current.copyWith(passwordRecovery: false));
        }
      });

  /// Signs out of this device.
  ///
  /// The branched flow around it — sync first, auto-export, then wipe — is the
  /// logout task's; this only ends the session and forgets the cached account,
  /// and it never touches local data.
  ///
  /// Two things it does clean up are the *server's* copies of this device — an
  /// unfinished onboarding (see [_abandonProvisionalOnboarding]) and the device's
  /// push registration (see [_unregisterDeviceToken]) — and both have to happen
  /// while the session still exists.
  Future<void> signOut() async {
    await _abandonProvisionalOnboarding();
    // Before `_repository.signOut()`: the `device_tokens` row is this device's
    // own to delete only while it is still signed in.
    await _unregisterDeviceToken();
    await _repository.signOut();
    await _forgetAccount();
    await _local.clear();
    state = const AsyncData(AuthState());
  }

  /// Removes this device's push registration, so the account that is leaving
  /// stops being pushed to here.
  ///
  /// Best-effort on purpose, like the abandoned-onboarding cleanup below it: a
  /// sign-out must always succeed — it is the one action a user may need
  /// precisely when the network is gone. The ceiling is that an offline sign-out
  /// leaves the row behind; the upgrade path is to remove it on the next launch
  /// while the previous account is still known. Nothing is leaked by that: the
  /// token is the row's primary key, so the next account to register on this
  /// device takes the row over rather than sitting beside it.
  Future<void> _unregisterDeviceToken() async {
    try {
      final token = await ref.read(pushGatewayProvider).token();
      if (token == null) return;
      await ref.read(deviceTokenRepositoryProvider).unregister(token);
    } catch (error) {
      recordFailure(
        ref.read(errorLogProvider),
        'auth.unregisterDeviceToken',
        error,
      );
    }
  }

  /// Drops everything that belongs to the account that is leaving.
  ///
  /// The database wipe clears the local rows; every one of these lives outside
  /// it, and each is read by a screen that must never show it to the next person
  /// on this device. On an account switch the database is cleared too —
  /// [_wipeLocalDiary] — so the two together leave nothing of the previous
  /// holder behind.
  ///
  /// * **The pull-only caches** belong to the account that pulled them: they are
  ///   emptied rather than left behind for whoever signs in next (Revision 2.4
  ///   Addendum: the profile cache is invalidated on logout and account switch).
  /// * **The per-user caches that live in SharedPreferences** — personal
  ///   details, picture, language, backup history — are the same promise for the
  ///   values that live outside the database (the same Addendum, for the
  ///   preference caches).
  /// * **The account-scoped live reads** are the part no wipe can reach: a
  ///   server read is held in memory by a provider, so this account's payment
  ///   history, the admin panel's status and its queue, and an owner's firm
  ///   roster and invite codes would otherwise keep answering with the previous
  ///   account's rows — an Admin Panel that stayed open to a non-admin, and a
  ///   *Payment History* that was somebody else's ledger. A provider added later
  ///   that reads the server on this account's behalf belongs in this list too.
  Future<void> _forgetAccount() async {
    await (await ref.read(profileRepositoryProvider.future)).invalidate();
    await _clearPerUserCaches();
    _reaskAccountScopedReads();
  }

  /// Re-asks the server reads that answer for whoever holds the session.
  ///
  /// Called from **both** ends of a session, and the arriving end is the one
  /// that is easy to miss. Leaving drops the previous account's answers. But
  /// [signOut] ends the session *before* it drops them, so a screen still
  /// watching one re-asks at that instant with no JWT — and `isAdmin()` answers
  /// **false** by design there rather than throwing, which is exactly what a
  /// non-admin looks like. That false then outlived the sign-out, because
  /// signing back in as the **same** account is not a switch (the logout has
  /// just forgotten the remembered id, so [_completeSignIn]'s switch branch does
  /// nothing) and nothing re-asked: the administrator's own Admin Panel entry
  /// stayed gone — no drawer row, no bottom tab — until the app was restarted.
  ///
  /// Only the live reads are dropped here, never local rows: a cold start or a
  /// token refresh is a sign-in too, and those must drop nothing of the
  /// account's own. A provider added later that reads the server on this
  /// account's behalf belongs in this list as well.
  void _reaskAccountScopedReads() {
    ref.invalidate(myPaymentSubmissionsProvider);
    ref.invalidate(adminStatusProvider);
    ref.invalidate(firmMembersListProvider);
    ref.invalidate(firmInvitesListProvider);
  }

  /// Wipes this device's local diary, and puts the baseline data back.
  ///
  /// The second half of an account switch, and the one the caches above cannot
  /// reach. Plan §5 and its Revision 2.4 Addendum require the **account switch**
  /// to follow the same complete wipe scope as the Logout button, because the
  /// wipe is what binds the local rows to one account. A switch that began with
  /// the Logout button has already been wiped by the branched flow; this is the
  /// other way a switch begins — a session the server revoked, or one that
  /// expired or could not be parsed back at all, which clears nothing on its own
  /// and (unlike the logout) is never prompted for a safety copy.
  ///
  /// Without it the arriving account opened the diary onto the previous
  /// holder's cases, notes and reference rows — and onto their `sync_queue`, so
  /// the header counted work that no longer had an owner on this device while
  /// `IdentityAdoptionService` refused to hand the rows over. The wipe restores
  /// the seeded baseline in the same step, so what follows is a fresh install's
  /// database plus the arriving account's own initial pull.
  Future<void> _wipeLocalDiary() async {
    final db = await ref.read(databaseProvider.future);
    await BackupRepository(db).wipeToFreshInstall();
  }

  /// Empties the SharedPreferences-backed per-user caches.
  Future<void> _clearPerUserCaches() async {
    await ref.read(profileFieldsProvider.notifier).clear();
    await ref.read(profilePictureProvider.notifier).clear();
    // The chamber logo is the next account's to download, not this one's.
    await ref.read(firmLogoProvider.notifier).reset();
    await ref.read(backupMetadataProvider.notifier).reset();
    // The next account must not inherit the previous holder's automatic-backup
    // schedule, so its daily alarm is dropped too. Fire-and-forget: cancelling an
    // alarm is best-effort cleanup (it is re-armed from scratch at the next
    // launch), so it must never gate a logout on a platform call answering.
    unawaited(ref.read(backupSchedulerProvider).cancelAll());
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
    } catch (error) {
      // ponytail: best-effort, because a sign-out must always succeed — it is
      // the one action a user may need precisely when the network is gone. The
      // ceiling is that an offline sign-out leaves an empty provisional account
      // behind; the upgrade path is to retry the call on the next launch while
      // the account is known to be unprovisioned.
      //
      // Swallowed, but not forgotten: this is the one failure in the app that
      // reaches nobody at all, and "signed out, yet the abandoned account is
      // still on the server" is exactly what the log exists to explain.
      recordFailure(
        ref.read(errorLogProvider),
        'auth.abandonOnboarding',
        error,
      );
    }
  }

  /// Records the identity, adopts offline data, and marks the gate satisfied.
  Future<void> _completeSignIn(AuthIdentity identity, {String? firmId}) async {
    // A session can end without the Logout button — the server revokes it, or
    // it expires, and the SDK reports that by itself — and that path empties
    // nothing. So a sign-in **as somebody else** is the other moment the
    // previous account has to go: the remembered account id is exactly what says
    // this device's record and its in-memory reads belong to another person. A
    // cold start, or the same account arriving again (a token refresh, a
    // restored session), is not a switch and drops nothing.
    final previousUserId = _local.cachedUserId;
    if (previousUserId != null && previousUserId != identity.userId) {
      await _forgetAccount();
      await _wipeLocalDiary();
    }
    final blocked = await _adopt(identity, firmId: firmId);
    await _local.rememberIdentity(identity);
    await _local.markGateSatisfied();
    // Arriving: whatever the status was read as while this device had no
    // session — including the `false` the sign-out itself caused (see
    // [_reaskAccountScopedReads]) — must not be what the arriving account sees.
    _reaskAccountScopedReads();
    // A session can only exist for a confirmed address, so any sign-up that was
    // waiting for its confirmation mail is finished.
    await _local.clearPendingConfirmationEmail();
    state = AsyncData(AuthState(identity: identity, adoptionBlocked: blocked));
  }

  /// Marks this as a fresh login, so the gate waits for the server's slot answer
  /// instead of opening the cached diary while the check is in flight.
  void _markFreshDeviceCheck() {
    ref.read(freshDeviceCheckProvider.notifier).mark();
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
      state = AsyncData(AuthState(sessionExpired: event.sessionExpired));
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
    _markFreshDeviceCheck();
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
