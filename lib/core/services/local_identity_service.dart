/// Local identity service: the user id every local write is stamped with.
///
/// It answers one question — *whose rows are these?* — and it has exactly two
/// answers:
///
/// * **no account yet** (a Part A install, or a device nobody has signed in on):
///   a stable per-installation UUID, minted once and kept in [SharedPreferences];
/// * **an account is bound** ([bindAccount]): the real `auth.uid()`, so the rows,
///   the `sync_queue` payloads that carry them and the per-user preference keys
///   all name the same UUID the server's `Authentication > Users` shows.
///
/// The placeholder is only ever a *bridge*: adoption rewrites the rows and queue
/// entries that predate the account, and binding makes every later write use the
/// account id — which is also what the background notification isolate reads
/// (it can reach [peekId], not a Riverpod session).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../shared/providers/shared_preferences_provider.dart';

/// Generates and caches the placeholder local user identity.
class LocalIdentityService {
  /// Key used to store the identity in [SharedPreferences].
  static const _key = 'local_identity_id';

  final SharedPreferences _prefs;
  String? _cached;

  /// Creates a service backed by [prefs].
  LocalIdentityService(this._prefs);

  /// Returns the stable local identity UUID, creating and persisting one if
  /// necessary.
  String getId() {
    _cached ??= _prefs.getString(_key);
    if (_cached == null || _cached!.isEmpty) {
      _cached = const Uuid().v4();
      // Fire-and-forget persistence; the in-memory cache is authoritative.
      _prefs.setString(_key, _cached!);
    }
    return _cached!;
  }

  /// Binds this device's data to the authenticated account.
  ///
  /// Called once per sign-in (and on every restored session, which is
  /// idempotent), because every local write from here on is stamped with the
  /// value this stores. It is deliberately the only way the stored value becomes
  /// anything other than a freshly minted placeholder, and it is not cleared by
  /// a sign-out: ending the session does not change who the diary belongs to, and
  /// the account-switch refusal depends on that staying true.
  Future<void> bindAccount(String userId) async {
    if (userId.isEmpty) return;
    _cached = userId;
    await _prefs.setString(_key, userId);
  }

  /// Reads the stored identity **without creating one**.
  ///
  /// Background isolates (the notification job) must never mint an identity,
  /// so they use this and simply do nothing when the app has not stored one yet.
  String? peekId() {
    final stored = _prefs.getString(_key);
    return (stored == null || stored.isEmpty) ? null : stored;
  }

  /// Clears the cached identity and removes it from persistent storage.
  ///
  /// **Not** part of signing out: the rows on this device are still the bound
  /// account's work, and clearing the binding would both re-own the diary to a
  /// fresh placeholder and disarm the account-switch refusal. The only flow that
  /// may use this is the branched logout of Task 19, and only once the rows it
  /// belongs to have been synced, wiped or exported with the user.
  Future<void> clear() async {
    _cached = null;
    await _prefs.remove(_key);
  }
}

/// Riverpod provider for the singleton [LocalIdentityService].
final localIdentityServiceProvider = Provider<LocalIdentityService>((ref) {
  return LocalIdentityService(ref.watch(sharedPreferencesProvider));
});
