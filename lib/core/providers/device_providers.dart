/// The device registry's providers.
///
/// One controller owns the answer: it registers this install once, re-registers
/// on a sign-in, and exposes the device list the lawyer can edit. Nothing else
/// reads `user_devices` — the table is server-managed and only these RPCs reach
/// it.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/device_registration.dart';
import '../devices/device_identity.dart';
import 'repository_providers.dart';

/// Resolves and caches this install's identity.
final deviceIdentityServiceProvider = Provider<DeviceIdentityService>(
  (ref) => DeviceIdentityService(),
);

/// This install's identity, resolved on first read.
final deviceIdentityProvider = FutureProvider<DeviceIdentity>(
  (ref) => ref.watch(deviceIdentityServiceProvider).resolve(),
);

/// The registry, or the inert one when this build carries no backend.
final deviceRegistrationRepositoryProvider =
    Provider<DeviceRegistrationRepository>((ref) {
      final client = ref.watch(activeSupabaseClientProvider);
      if (client == null) {
        return const UnavailableDeviceRegistrationRepository();
      }
      return SupabaseDeviceRegistrationRepository(client);
    });

/// This device's registration state, the app's one source for the limit.
final deviceGateProvider =
    AsyncNotifierProvider<DeviceGateController, DeviceGateState>(
      DeviceGateController.new,
    );

/// Registers the device and answers what it is allowed to do.
class DeviceGateController extends AsyncNotifier<DeviceGateState> {
  @override
  Future<DeviceGateState> build() async {
    // Watched, not read: a sign-out or a new account rebuilds this and registers
    // the device against the new session.
    if (ref.watch(activeSupabaseClientProvider) == null) {
      return const DeviceGateState(status: DeviceGateStatus.unmanaged);
    }
    final identity = await ref.watch(deviceIdentityProvider.future);
    return ref.watch(deviceRegistrationRepositoryProvider).register(identity);
  }

  /// Re-asks the server. `claim` false only reads, for a device that must not
  /// try to take a slot it has lost.
  Future<void> refresh({bool claim = true}) async {
    final repository = ref.read(deviceRegistrationRepositoryProvider);
    final identity = await ref.read(deviceIdentityProvider.future);
    state = await AsyncValue.guard(
      () => claim ? repository.register(identity) : repository.state(),
    );
  }

  /// Frees another device's slot and refreshes the list.
  Future<bool> remove(String deviceId) async {
    final removed = await ref
        .read(deviceRegistrationRepositoryProvider)
        .revoke(deviceId);
    if (removed) await refresh(claim: false);
    return removed;
  }

  /// Records that this device has flushed its work and erased itself.
  Future<void> acknowledgeWipe() async {
    final identity = await ref.read(deviceIdentityProvider.future);
    await ref
        .read(deviceRegistrationRepositoryProvider)
        .acknowledgeWipe(identity);
  }
}
