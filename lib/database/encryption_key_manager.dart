/// Encryption key management for the SQLCipher-backed local database.
/// Implemented in Task 03 Phase 1.
library;

import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Length of the raw database encryption key, in bytes.
const _keyLengthBytes = 32;

/// Default secure-storage key name.
const _defaultKeyName = 'app_database_key';

/// Thrown when a database key operation fails or the key is missing while an
/// encrypted database file already exists.
class DatabaseKeyException implements Exception {
  /// Human-readable explanation.
  final String message;

  /// Creates an exception with [message].
  DatabaseKeyException(this.message);

  @override
  String toString() => 'DatabaseKeyException: $message';
}

/// Abstract storage for the database key. Keeps the key manager testable by
/// allowing in-memory or otherwise custom storage implementations.
abstract class KeyStorage {
  /// Reads the value associated with [key], or returns `null` if absent.
  Future<String?> read({required String key});

  /// Persists [value] under [key].
  Future<void> write({required String key, required String value});

  /// Removes [key] from storage.
  Future<void> delete({required String key});
}

/// Secure storage backed by `flutter_secure_storage` (Android Keystore / iOS
/// Keychain / Windows DPAPI, etc.).
///
/// Public because it is the app's one secure key/value store: Task 17's Supabase
/// session lives in the same place, behind its own key, rather than adding a
/// second adapter for the same plugin.
class FlutterSecureKeyStorage implements KeyStorage {
  final FlutterSecureStorage _storage;

  const FlutterSecureKeyStorage() : _storage = const FlutterSecureStorage();

  /// This-device-only storage for the Supabase session and the install secret.
  ///
  /// iOS keychain items are not migrated by a device backup, and Android's
  /// default Keystore-backed ciphers are not restorable elsewhere, so a
  /// restored copy cannot carry the session to another phone. The database key
  /// keeps the default constructor: its backup behaviour is a separate product
  /// decision.
  const FlutterSecureKeyStorage.sessionOnly()
    : _storage = const FlutterSecureStorage(
        iOptions: IOSOptions(
          accessibility: KeychainAccessibility.first_unlock_this_device,
        ),
      );

  @override
  Future<String?> read({required String key}) => _storage.read(key: key);

  @override
  Future<void> write({required String key, required String value}) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete({required String key}) => _storage.delete(key: key);
}

/// In-memory key storage for testing.
class InMemoryKeyStorage implements KeyStorage {
  final _map = <String, String>{};

  @override
  Future<String?> read({required String key}) async => _map[key];

  @override
  Future<void> write({required String key, required String value}) async {
    _map[key] = value;
  }

  @override
  Future<void> delete({required String key}) async => _map.remove(key);
}

/// Generates, retrieves, and removes the per-installation database key.
///
/// The key is a 256-bit random value, stored as a hex string in secure
/// storage. It is never logged, persisted in plain preferences, or included in
/// any sync payload.
class EncryptionKeyManager {
  /// Underlying secure storage implementation. Replaceable for tests.
  final KeyStorage storage;

  /// Name of the secure-storage entry holding the key.
  final String keyName;

  /// Creates a manager using secure storage by default.
  EncryptionKeyManager({
    this.storage = const FlutterSecureKeyStorage(),
    this.keyName = _defaultKeyName,
  });

  /// Creates a manager backed by in-memory storage for tests.
  factory EncryptionKeyManager.inMemory() =>
      EncryptionKeyManager(storage: InMemoryKeyStorage());

  /// Returns the existing key or creates, stores, and returns a new one.
  Future<String> getOrCreateKey() async {
    final existing = await storage.read(key: keyName);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final newKey = _generateKey();
    await storage.write(key: keyName, value: newKey);
    return newKey;
  }

  /// Returns `true` if a key has been stored.
  Future<bool> hasKey() async {
    final value = await storage.read(key: keyName);
    return value != null && value.isNotEmpty;
  }

  /// Removes the stored key. Useful during recovery/reset flows.
  Future<void> deleteKey() => storage.delete(key: keyName);

  String _generateKey() {
    final random = Random.secure();
    final bytes =
        List<int>.generate(_keyLengthBytes, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
