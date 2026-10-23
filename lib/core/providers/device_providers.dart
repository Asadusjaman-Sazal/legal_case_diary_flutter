/// The device registry's providers.
///
/// One controller owns the answer: it registers this install once, re-registers
/// on a sign-in, and exposes the device list the lawyer can edit. Nothing else
/// reads `user_devices` — the table is server-managed and only these RPCs reach
/// it.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/encryption_key_manager.dart';
import '../../features/auth/data/device_registration.dart';
import '../../features/auth/presentation/auth_viewmodel.dart';
import '../devices/device_identity.dart';
import '../devices/device_install_secret.dart';
import 'repository_providers.dart';

/// Resolves and caches this install's identity.
final deviceIdentityServiceProvider = Provider<DeviceIdentityService>(
  (ref) => DeviceIdentityService(),
);

/// This install's identity, resolved on first read.
final deviceIdentityProvider = FutureProvider<DeviceIdentity>(
  (ref) => ref.watch(deviceIdentityServiceProvider).resolve(),
);

/// This install's secret, read once from this-device-only secure storage.
final deviceInstallSecretProvider = FutureProvider<String>(
  (ref) => const DeviceInstallSecretStore(
    FlutterSecureKeyStorage.sessionOnly(),
  ).loadOrCreate(),
);

/// The registry, or the inert one when this build carries no backend.
final deviceRegistrationRepositoryProvider =
    Provider<DeviceRegistrationRepository>((ref) {
      final client = ref.watch(activeSupabaseClientProvider);
      if (client == null) {
        return const UnavailableDeviceRegistrationRepository();
      }
      return SupabaseDeviceRegistrationRepository(
        client,
        installSecret: () => ref.read(deviceInstallSecretProvider.future),
      );
    });

/// True between a fresh sign-in and the first device answer.
///
/// A cold start with an existing session may work offline, but a **new login**
/// must wait for the server's slot answer; this flag is what tells the gate the
/// difference.
class FreshDeviceCheckNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  /// A sign-in just completed; wait for the server.
  void mark() => state = true;

  /// The server answered (whatever it said); stop blocking on the flag.
  void clear() => state = false;
}

final freshDeviceCheckProvider =
    NotifierProvider<FreshDeviceCheckNotifier, bool>(
      FreshDeviceCheckNotifier.new,
    );

/// This device's registration state, the app's one source for the limit.
final deviceGateProvider =
    AsyncNotifierProvider<DeviceGateController, DeviceGateState>(
      DeviceGateController.new,
    );

/// Registers the device and answers what it is allowed to do.
class DeviceGateController extends AsyncNotifier<DeviceGateState> {
  /// The last heartbeat sent, so a busy sync does not call the server each time.
  DateTime? _lastTouch;

  @override
  Future<DeviceGateState> build() async {
    // Watched, not read: a sign-out or a new account rebuilds this and registers
    // the device against the new session.
    if (ref.watch(activeSupabaseClientProvider) == null) {
      return const DeviceGateState(status: DeviceGateStatus.unmanaged);
    }
    // Signed out is not a device state: the Login screen is the whole app. A new
    // sign-in rebuilds this provider, so the gate answers for the new session.
    if (ref.watch(authIdentityProvider) == null) {
      return const DeviceGateState(status: DeviceGateStatus.unmanaged);
    }
    final identity = await ref.watch(deviceIdentityProvider.future);
    return ref.watch(deviceRegistrationRepositoryProvider).register(identity);
  }

  /// Re-asks the server. `claim` false only reads, for a device that must not
  /// try to take a slot it has lost.
  Future<void> refresh({bool claim = true}) async {
    // Signed out: the Login screen is the whole app, and an RPC here would run
    // as `anon` and be refused.
    if (ref.read(authIdentityProvider) == null) {
      state = const AsyncData(
        DeviceGateState(status: DeviceGateStatus.unmanaged),
      );
      return;
    }
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

  /// Signs out another device from the third-device window, then re-checks this
  /// device's own slot. Returns true when this device is now active.
  Future<bool> signOut(String deviceId) async {
    final signedOut = await ref
        .read(deviceRegistrationRepositoryProvider)
        .signOut(deviceId);

    // Always re-ask: another device may have taken the freed slot first.
    await refresh(claim: true);
    return signedOut || state.value?.status == DeviceGateStatus.active;
  }

  /// Records that this device has flushed its work and erased itself.
  Future<void> acknowledgeWipe() async {
    final identity = await ref.read(deviceIdentityProvider.future);
    await ref
        .read(deviceRegistrationRepositoryProvider)
        .acknowledgeWipe(identity);
  }

  /// How often an ordinary check may ask the server about this device.
  ///
  /// [touch] also runs after a successful sync drain, which can happen often in
  /// a busy session; this window keeps that from repeating the same query. It is
  /// not a heartbeat: forced checks bypass it, and no timer polls in between.
  static const touchInterval = Duration(seconds: 30);

  /// Marks this device as really used and notices a revocation.
  ///
  /// The seven-day idle eviction must measure contact, not app launches; a
  /// device used all day without being restarted would otherwise look idle.
  /// [force] bypasses [touchInterval] for a resume, a channel rejoin or a
  /// device-row ping, where a recent ordinary check must not hide a change.
  Future<void> touch({bool force = false}) async {
    // A resume on the Login screen has no session to mark.
    if (ref.read(authIdentityProvider) == null) return;
    final now = DateTime.now();
    final last = _lastTouch;
    if (!force && last != null && now.difference(last) < touchInterval) return;
    _lastTouch = now;
    try {
      // A launch whose model lookup timed out wrote "Unknown device" onto the
      // server row. The app is warm now, so ask again and re-register to put
      // the real model on the row; the next launch is not needed.
      final identity = await ref.read(deviceIdentityProvider.future);
      if (identity.label == DeviceIdentity.fallback.label) {
        final refreshed = await ref
            .read(deviceIdentityServiceProvider)
            .resolve(refresh: true);
        if (refreshed.label != DeviceIdentity.fallback.label) {
          ref.invalidate(deviceIdentityProvider);
          await refresh(claim: true);
          return;
        }
      }

      final used = await ref.read(deviceRegistrationRepositoryProvider).touch();
      // The server says this device no longer holds a slot: the gate must show
      // the revocation and start the discard now, not when a push happens.
      if (!used) await refresh(claim: false);
    } on Object {
      // A failed check is not a reason to fail anything else; retry later.
      _lastTouch = null;
    }
  }
}
