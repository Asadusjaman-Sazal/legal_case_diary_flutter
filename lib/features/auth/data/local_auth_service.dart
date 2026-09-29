/// Local cache of the last known auth identity.
///
/// Answers one question without any I/O or network: *whose diary is this?* A
/// cold start with no connectivity still needs it, so the sign-in gate can tell
/// "never signed in" from "signed in, session stale", and an offline relaunch
/// can show the account the local data belongs to. It also remembers that the
/// first-run sign-in gate has been satisfied.
///
/// Only the identity — never a token, password or recovery secret. The session
/// itself lives in secure storage (see [SecureSessionStorage]), and Supabase
/// Auth owns credentials.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/providers/shared_preferences_provider.dart';
import 'auth_repository.dart';

/// Preference key holding the last signed-in user id.
const String authUserIdKey = 'auth_last_user_id';

/// Preference key holding the last signed-in email, for display only.
const String authUserEmailKey = 'auth_last_user_email';

/// Preference key recording that the first-run sign-in gate was satisfied.
const String authGateSatisfiedKey = 'auth_gate_satisfied';

/// Preference key holding an invite code that still has to be redeemed.
///
/// A join-a-firm sign-up cannot redeem its code until the account has a session
/// — which it may not have while an email confirmation is pending — so the code
/// is kept until it is redeemed or the user abandons onboarding. The plaintext
/// lives here only until then: it is never stored anywhere else, and the server
/// only ever sees its hash.
const String pendingInviteCodeKey = 'auth_pending_invite_code';

/// Reads and writes the locally cached auth identity.
class LocalAuthService {
  /// Creates a service backed by [prefs].
  LocalAuthService(this._prefs);

  final SharedPreferences _prefs;

  /// The last signed-in user id, or null when this device has never signed in.
  String? get cachedUserId {
    final id = _prefs.getString(authUserIdKey);
    return (id == null || id.isEmpty) ? null : id;
  }

  /// The last signed-in email, for display only.
  String? get cachedEmail => _prefs.getString(authUserEmailKey);

  /// The cached identity, or null when there is none.
  ///
  /// The returned identity is a *record of what was last seen*, not a live
  /// session: [AuthIdentity.emailConfirmed] and the name are not tracked here,
  /// because the authoritative identity comes from the repository.
  AuthIdentity? readIdentity() {
    final id = cachedUserId;
    return id == null ? null : AuthIdentity(userId: id, email: cachedEmail);
  }

  /// Records [identity] as the last signed-in account.
  Future<void> rememberIdentity(AuthIdentity identity) async {
    await _prefs.setString(authUserIdKey, identity.userId);
    final email = identity.email;
    if (email == null || email.isEmpty) {
      await _prefs.remove(authUserEmailKey);
    } else {
      await _prefs.setString(authUserEmailKey, email);
    }
  }

  /// Forgets the cached identity, the gate flag and any pending invite code
  /// (sign-out, account switch).
  Future<void> clear() async {
    await _prefs.remove(authUserIdKey);
    await _prefs.remove(authUserEmailKey);
    await _prefs.remove(authGateSatisfiedKey);
    await _prefs.remove(pendingInviteCodeKey);
  }

  /// The invite code still waiting to be redeemed, or null.
  String? get pendingInviteCode {
    final code = _prefs.getString(pendingInviteCodeKey);
    return (code == null || code.isEmpty) ? null : code;
  }

  /// Remembers the invite code the user entered, until it is redeemed.
  Future<void> setPendingInviteCode(String code) =>
      _prefs.setString(pendingInviteCodeKey, code);

  /// Forgets the pending invite code (redeemed, refused, or abandoned).
  Future<void> clearPendingInviteCode() =>
      _prefs.remove(pendingInviteCodeKey);

  /// Whether the first-run sign-in gate has been satisfied on this device.
  bool get gateSatisfied => _prefs.getBool(authGateSatisfiedKey) ?? false;

  /// Marks the gate satisfied, so it is not shown again.
  Future<void> markGateSatisfied() =>
      _prefs.setBool(authGateSatisfiedKey, true);
}

/// Riverpod provider for the singleton [LocalAuthService].
final localAuthServiceProvider = Provider<LocalAuthService>(
  (ref) => LocalAuthService(ref.watch(sharedPreferencesProvider)),
);
