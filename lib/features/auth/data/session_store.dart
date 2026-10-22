/// Secure, session-only persistence for Supabase Auth.
///
/// The Supabase session (access token + refresh token) is the one credential
/// the app keeps on the device, so it is written to `flutter_secure_storage`
/// instead of plain preferences — Android Keystore, iOS Keychain, Windows DPAPI
/// — with this-device-only options, so a backup cannot carry it elsewhere.
///
/// Nothing else about a session is stored, and no password, recovery code or
/// recovery secret is ever written here: Supabase Auth owns credentials.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../database/encryption_key_manager.dart';

/// Key under which the serialized session is kept in secure storage.
const String sessionStorageKey = 'supabase_session';

/// A [LocalStorage] that persists the session in secure storage.
///
/// Implements the four calls Supabase Auth makes: presence, read, write and
/// remove. The value is the SDK's own serialized session string, so this class
/// never parses or reshapes it.
class SecureSessionStorage extends LocalStorage {
  /// Creates a store backed by [storage], keyed by [key].
  SecureSessionStorage({
    this.storage = const FlutterSecureKeyStorage.sessionOnly(),
    this.key = sessionStorageKey,
  });

  /// The secure key/value store the session is written to.
  final KeyStorage storage;

  /// Secure-storage entry holding the session.
  final String key;

  /// Nothing to initialize: secure storage needs no handle held open.
  @override
  Future<void> initialize() async {}

  /// True when a session is present, so a cold start can restore it offline.
  @override
  Future<bool> hasAccessToken() async {
    final stored = await storage.read(key: key);
    return stored != null && stored.isNotEmpty;
  }

  /// The serialized session, or null when the device has none.
  @override
  Future<String?> accessToken() => storage.read(key: key);

  /// Writes the serialized session.
  @override
  Future<void> persistSession(String persistSessionString) =>
      storage.write(key: key, value: persistSessionString);

  /// Removes the persisted session (sign-out, or an account switch).
  @override
  Future<void> removePersistedSession() => storage.delete(key: key);
}
