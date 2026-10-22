/// The install's own secret, separate from the Supabase session.
///
/// It is generated once, stored in this-device-only secure storage, and sent
/// with every Supabase request. The server hashes it onto the device row, so a
/// copied session presented from another install is refused even though the
/// access token is valid.
library;

import 'dart:convert';
import 'dart:math';

import '../../database/encryption_key_manager.dart';

/// Secure-storage key holding the install secret.
const String installSecretStorageKey = 'device_install_secret';

/// Reads, or creates and stores, this install's secret.
class DeviceInstallSecretStore {
  /// Creates a store over [storage].
  const DeviceInstallSecretStore(this.storage);

  /// The this-device-only secure store.
  final KeyStorage storage;

  /// Returns the existing secret, or mints and stores a 32-byte one.
  ///
  /// A secure-storage failure is thrown to the caller: an unstable secret
  /// generated per launch would lock the install out of its own session.
  Future<String> loadOrCreate() async {
    final existing = await storage.read(key: installSecretStorageKey);
    if (existing != null && existing.length >= 32) return existing;

    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    final secret = base64UrlEncode(bytes);
    await storage.write(key: installSecretStorageKey, value: secret);
    return secret;
  }
}
