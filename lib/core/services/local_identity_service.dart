/// Local identity placeholder service.
///
/// In Part A there is no Supabase auth session, so this service creates a
/// stable per-installation UUID and persists it in [SharedPreferences]. In
/// Part B the same stored value is adopted as the local `last_modified_by`
/// bridge until the user authenticates, at which point rows and queue entries
/// are rewritten to the real `auth.uid()`.
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
  /// Useful during logout / account-switch flows in Part B.
  Future<void> clear() async {
    _cached = null;
    await _prefs.remove(_key);
  }
}

/// Riverpod provider for the singleton [LocalIdentityService].
final localIdentityServiceProvider = Provider<LocalIdentityService>((ref) {
  return LocalIdentityService(ref.watch(sharedPreferencesProvider));
});
