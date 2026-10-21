/// The device's push registration: its row in `device_tokens`.
///
/// Classified **local operational** (Rev 2.4 table classes): per-device state the
/// client writes about itself. It is never synced, never firm-shared, never
/// tombstoned, and legitimately **hard**-deleted, because a device unregisters
/// itself on the way out of an account. The table, its self-only policies and its
/// `on delete cascade` to `auth.users` are the whole of
/// `supabase/migrations/20261012120000_admin_payment_alerts.sql`.
///
/// **The row's `user_id` is never taken from a caller.** RLS admits a row only for
/// `auth.uid()`, so the id this repository writes is the signed-in account's own,
/// read from the client — a caller-supplied id could only ever be refused. The
/// token is the primary key, so re-registering updates the row rather than adding
/// a second one, and a device that changes hands is reassigned to its new account
/// instead of continuing to feed the previous one.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

/// Where this device's push registration lives.
abstract class DeviceTokenRepository {
  /// Upserts [token] for the signed-in account.
  ///
  /// Idempotent: the same device signing in again rewrites its own row.
  Future<void> register(String token, {String? deviceKey});

  /// Removes [token].
  ///
  /// The way a device stops receiving alerts for an account: it runs on every
  /// sign-out, before the session ends, while the row is still its own to delete.
  Future<void> unregister(String token);
}

/// Talks to the `device_tokens` table under the caller's own RLS.
class SupabaseDeviceTokenRepository implements DeviceTokenRepository {
  /// Creates a repository over [client].
  SupabaseDeviceTokenRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<void> register(String token, {String? deviceKey}) async {
    final userId = _client.auth.currentUser?.id;
    if (token.isEmpty || userId == null) return;
    await _client.from('device_tokens').upsert(<String, Object?>{
      'token': token,
      // The account's own id, from the session rather than an argument.
      'user_id': userId,
      // Which device holds this token, so a revocation can delete exactly
      // this device's row rather than the whole account's.
      if (deviceKey != null && deviceKey.isNotEmpty) 'device_key': deviceKey,
    }, onConflict: 'token');
  }

  @override
  Future<void> unregister(String token) async {
    if (token.isEmpty) return;
    await _client.from('device_tokens').delete().eq('token', token);
  }
}

/// The inert repository of a build with no backend.
///
/// A device with no Supabase project has nothing to register with, and saying so
/// silently is better than a row that could never be written — the same choice
/// `UnavailableAdminRepository` makes about the panel.
class UnavailableDeviceTokenRepository implements DeviceTokenRepository {
  /// Creates the inert repository.
  const UnavailableDeviceTokenRepository();

  @override
  Future<void> register(String token, {String? deviceKey}) async {}

  @override
  Future<void> unregister(String token) async {}
}
