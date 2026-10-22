/// The device registry, as the app sees it.
///
/// The server owns the limit: `register_device()` claims the slot for this
/// sign-in and answers with the state below, `device_state()` is the launch
/// check, `revoke_device()` frees one, and `ack_device_wipe()` records that a
/// revoked device has handed over its unsent work and erased itself.
///
/// A device holding no slot is never erased silently: it is either refused (the
/// plan is full and every device is in recent use) or revoked (another device
/// took its place, or the lawyer removed it), and a revoked device erases only
/// after its queued work has reached the account.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/devices/device_identity.dart';

/// What this device's registration says.
enum DeviceGateStatus {
  /// The device holds a slot and may sync.
  active,

  /// The plan is full and every device was used recently: nothing was evicted.
  limitReached,

  /// This device lost its slot; it must flush and erase.
  revoked,

  /// The caller has a session but no device row (a read-only state check).
  unregistered,

  /// The server gave an answer this build does not understand. It never means
  /// "allowed": the gate blocks until the answer can be read again.
  unknown,

  /// This build carries no backend, or the caller has no session claim.
  unmanaged,
}

/// One device in the list the lawyer reads.
class RegisteredDevice {
  /// Creates a device entry.
  const RegisteredDevice({
    required this.id,
    required this.label,
    required this.platform,
    this.lastSeenAt,
    this.isCurrent = false,
  });

  /// The row id, used to remove it.
  final String id;

  /// The device's own label, e.g. *Samsung SM-A525F*.
  final String label;

  /// `android`, `ios`, `windows` or `unknown`.
  final String platform;

  /// When the server last heard from it.
  final DateTime? lastSeenAt;

  /// Whether this is the device showing the list.
  final bool isCurrent;
}

/// The whole answer: state, cap, list, and why a revocation happened.
class DeviceGateState {
  /// Creates a state.
  const DeviceGateState({
    required this.status,
    this.cap = 1,
    this.devices = const <RegisteredDevice>[],
    this.revokedReason,
    this.evictedLabel,
  });

  /// The state.
  final DeviceGateStatus status;

  /// Devices the plan allows at once.
  final int cap;

  /// The account's active devices, newest contact first.
  final List<RegisteredDevice> devices;

  /// `cap`, `user`, `replaced` or `lapse`, for a revoked device.
  final String? revokedReason;

  /// The device this registration evicted, when it evicted one.
  final String? evictedLabel;

  /// Whether the device may sync.
  bool get maySync => status == DeviceGateStatus.active;

  /// A copy with a different state, keeping the rest.
  DeviceGateState copyWith({
    DeviceGateStatus? status,
    int? cap,
    List<RegisteredDevice>? devices,
    String? revokedReason,
    String? evictedLabel,
  }) => DeviceGateState(
    status: status ?? this.status,
    cap: cap ?? this.cap,
    devices: devices ?? this.devices,
    revokedReason: revokedReason ?? this.revokedReason,
    evictedLabel: evictedLabel ?? this.evictedLabel,
  );
}

/// The operations the app needs from the registry.
abstract class DeviceRegistrationRepository {
  /// Claims the slot for this sign-in, or reports why it cannot.
  Future<DeviceGateState> register(DeviceIdentity identity);

  /// Reads this device's state without claiming anything.
  Future<DeviceGateState> state();

  /// Frees another device's slot. Returns true when it was revoked.
  Future<bool> revoke(String deviceId);

  /// Signs out another device from the third-device window (reason
  /// `signed_out`). Returns true when the server revoked it.
  Future<bool> signOut(String deviceId);

  /// Records that this device has flushed its work and erased itself.
  Future<void> acknowledgeWipe(DeviceIdentity identity);
}

/// Talks to the registry RPCs under the caller's own session.
class SupabaseDeviceRegistrationRepository
    implements DeviceRegistrationRepository {
  /// Creates a repository over [client].
  SupabaseDeviceRegistrationRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<DeviceGateState> register(DeviceIdentity identity) async => _read(
    () => _client.rpc<Map<String, dynamic>>(
      'register_device',
      params: <String, Object?>{
        'p_device_key': identity.key,
        'p_platform': identity.platform,
        'p_label': identity.label,
      },
    ),
  );

  @override
  Future<DeviceGateState> state() async =>
      _read(() => _client.rpc<Map<String, dynamic>>('device_state'));

  /// Runs one registry call and tolerates a server that has no registry yet.
  ///
  /// `PGRST202` is PostgREST's "no such function": the migrations behind this
  /// feature have not been applied to that project. That is a build without the
  /// device limit, not a refusal, and reading it as a refusal would stop sync on
  /// every install — so it answers [DeviceGateStatus.unmanaged], the same answer
  /// a build with no backend gives.
  Future<DeviceGateState> _read(
    Future<Map<String, dynamic>> Function() call,
  ) async {
    try {
      return _fromJson(await call());
    } on PostgrestException catch (error) {
      if (error.code == 'PGRST202') {
        return const DeviceGateState(status: DeviceGateStatus.unmanaged);
      }
      rethrow;
    }
  }

  @override
  Future<bool> revoke(String deviceId) async {
    final data = await _client.rpc<Map<String, dynamic>>(
      'revoke_device',
      params: <String, Object?>{'p_id': deviceId},
    );
    return data['status'] == 'revoked';
  }

  @override
  Future<bool> signOut(String deviceId) async {
    final data = await _client.rpc<Map<String, dynamic>>(
      'sign_out_device',
      params: <String, Object?>{'p_id': deviceId},
    );
    return data['status'] == 'revoked';
  }

  @override
  Future<void> acknowledgeWipe(DeviceIdentity identity) async {
    await _client.rpc<Object?>(
      'ack_device_wipe',
      params: <String, Object?>{'p_device_key': identity.key},
    );
  }

  /// Maps one RPC answer onto the app's state.
  DeviceGateState _fromJson(Map<String, dynamic> data) {
    final status = switch (data['status']) {
      'ok' || 'active' => DeviceGateStatus.active,
      'device_limit_reached' => DeviceGateStatus.limitReached,
      'revoked' => DeviceGateStatus.revoked,
      'unregistered' => DeviceGateStatus.unregistered,
      'unmanaged' => DeviceGateStatus.unmanaged,
      _ => DeviceGateStatus.unknown,
    };
    final evicted = data['evicted'];
    return DeviceGateState(
      status: status,
      cap: (data['cap'] as num?)?.toInt() ?? 1,
      revokedReason: data['reason'] as String?,
      evictedLabel: evicted is Map<String, dynamic>
          ? evicted['label'] as String?
          : null,
      devices: _devices(data['devices']),
    );
  }

  /// Reads the `devices` array, tolerating an absent or empty one.
  List<RegisteredDevice> _devices(Object? raw) {
    if (raw is! List) return const <RegisteredDevice>[];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(
          (row) => RegisteredDevice(
            id: row['id'] as String? ?? '',
            label: (row['label'] as String?)?.trim().isNotEmpty == true
                ? row['label'] as String
                : 'This device',
            platform: row['platform'] as String? ?? 'unknown',
            lastSeenAt: DateTime.tryParse(
              row['last_seen_at'] as String? ?? '',
            )?.toLocal(),
            isCurrent: row['is_current'] == true,
          ),
        )
        .toList(growable: false);
  }
}

/// The inert repository of a build with no backend.
class UnavailableDeviceRegistrationRepository
    implements DeviceRegistrationRepository {
  /// Creates the inert repository.
  const UnavailableDeviceRegistrationRepository();

  @override
  Future<DeviceGateState> register(DeviceIdentity identity) async =>
      const DeviceGateState(status: DeviceGateStatus.unmanaged);

  @override
  Future<DeviceGateState> state() async =>
      const DeviceGateState(status: DeviceGateStatus.unmanaged);

  @override
  Future<bool> revoke(String deviceId) async => false;

  @override
  Future<bool> signOut(String deviceId) async => false;

  @override
  Future<void> acknowledgeWipe(DeviceIdentity identity) async {}
}
