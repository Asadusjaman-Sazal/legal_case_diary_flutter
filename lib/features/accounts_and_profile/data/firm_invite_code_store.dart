/// The plaintext invite codes **this device** generated, for the roster.
///
/// An invite's code exists once, in the Invite Code window: the server keeps
/// only its SHA-256 hash, so nothing can read a code back out of `firm_invites`
/// (user ruling 2026-10-26 — see `docs/implementation_plan.md`). Remembering it
/// here is what lets the Outstanding Invites list print it under the date and
/// copy it on a tap.
///
/// Two limits are deliberate and are shown in the list rather than hidden:
/// a code generated on **another phone** is not here, and neither is one made
/// **before this device remembered them** — those rows say the code is not
/// available. Entries are dropped when their invite is revoked.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/providers/shared_preferences_provider.dart';

/// Prefix of one invite's code: the invite's own id follows it.
///
/// Scoped by id rather than by firm, because an invite id is unique across firms
/// and a revoked invite's entry is removed by the same id.
const String _inviteCodeKeyPrefix = 'firm_invite_code_';

/// Reads and writes this device's remembered invite codes.
class FirmInviteCodeStore {
  /// Creates a store backed by [prefs].
  FirmInviteCodeStore(this._prefs);

  final SharedPreferences _prefs;

  /// The code remembered for [inviteId], or null when this device never had it.
  ///
  /// Synchronous on purpose: the roster's row reads it as it builds, so the code
  /// is on screen in the first frame rather than a moment later.
  String? codeFor(String inviteId) =>
      _prefs.getString('$_inviteCodeKeyPrefix$inviteId');

  /// Remembers [code] as [inviteId]'s, at the moment it is generated.
  Future<void> remember(String inviteId, String code) =>
      _prefs.setString('$_inviteCodeKeyPrefix$inviteId', code);

  /// Drops [inviteId]'s code, because the invite was revoked and nothing can
  /// redeem it any more.
  ///
  /// ponytail: a code whose invite is *used* rather than revoked stays in the
  /// preferences — the row it belonged to is gone, so nothing reads it, and the
  /// entry is a few bytes. Pruning by the live roster is the upgrade path if
  /// that ever matters.
  Future<void> forget(String inviteId) =>
      _prefs.remove('$_inviteCodeKeyPrefix$inviteId');
}

/// The one store every reader and writer shares.
final firmInviteCodeStoreProvider = Provider<FirmInviteCodeStore>(
  (ref) => FirmInviteCodeStore(ref.watch(sharedPreferencesProvider)),
);
