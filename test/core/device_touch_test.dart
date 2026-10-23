/// `DeviceGateController.touch` — the light slot check.
///
/// The 30-second interval is a de-duplication window for ordinary checks, not a
/// heartbeat: a resume, a channel rejoin and a device ping force it, and a
/// not-active answer must re-read the state so the gate shows the revocation.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:legal_case_diary/core/devices/device_identity.dart';
import 'package:legal_case_diary/core/providers/device_providers.dart';
import 'package:legal_case_diary/core/providers/repository_providers.dart';
import 'package:legal_case_diary/features/auth/data/auth_repository.dart';
import 'package:legal_case_diary/features/auth/data/device_registration.dart';
import 'package:legal_case_diary/features/auth/presentation/auth_viewmodel.dart';

/// A registry that records the calls the gate makes.
class _FakeDeviceRepository implements DeviceRegistrationRepository {
  DeviceGateState stateResult = const DeviceGateState(
    status: DeviceGateStatus.active,
  );
  DeviceGateState registerResult = const DeviceGateState(
    status: DeviceGateStatus.active,
  );
  bool touchResult = true;
  bool throwOnTouch = false;
  int touchCalls = 0;
  int registerCalls = 0;
  int stateCalls = 0;

  @override
  Future<DeviceGateState> register(DeviceIdentity identity) async {
    registerCalls++;
    return registerResult;
  }

  @override
  Future<DeviceGateState> state() async {
    stateCalls++;
    return stateResult;
  }

  @override
  Future<bool> revoke(String deviceId) async => true;

  @override
  Future<bool> signOut(String deviceId) async => true;

  @override
  Future<void> acknowledgeWipe(DeviceIdentity identity) async {}

  @override
  Future<bool> touch() async {
    touchCalls++;
    if (throwOnTouch) throw StateError('touch failed');
    return touchResult;
  }
}

/// A container with a signed-in identity, a real model label and a fake registry.
ProviderContainer _container(
  _FakeDeviceRepository repository, {
  AuthIdentity? identity = const AuthIdentity(userId: 'u1'),
}) {
  final container = ProviderContainer(
    overrides: [
      activeSupabaseClientProvider.overrideWithValue(
        SupabaseClient('https://example.supabase.co', 'test-key'),
      ),
      authIdentityProvider.overrideWithValue(identity),
      deviceIdentityProvider.overrideWith(
        (ref) async => const DeviceIdentity(
          key: 'install-key',
          platform: 'android',
          label: 'Xiaomi M2101K6G',
        ),
      ),
      deviceRegistrationRepositoryProvider.overrideWithValue(repository),
    ],
  );
  // Keep the notifier alive while the test reads it through the container.
  container.listen(deviceGateProvider, (_, _) {}, fireImmediately: true);
  return container;
}

void main() {
  test('ordinary checks are de-duplicated, a forced one always runs', () async {
    final repository = _FakeDeviceRepository();
    final container = _container(repository);
    addTearDown(container.dispose);
    await container.read(deviceGateProvider.future);
    final gate = container.read(deviceGateProvider.notifier);

    await gate.touch();
    await gate.touch();
    expect(repository.touchCalls, 1);

    await gate.touch(force: true);
    expect(repository.touchCalls, 2);
  });

  test('a phone with no slot is never checked by a stray signal', () async {
    final repository = _FakeDeviceRepository()
      ..registerResult = const DeviceGateState(
        status: DeviceGateStatus.limitReached,
        cap: 2,
      );
    final container = _container(repository);
    addTearDown(container.dispose);
    await container.read(deviceGateProvider.future);
    expect(
      container.read(deviceGateProvider).value?.status,
      DeviceGateStatus.limitReached,
    );

    // A channel join or another device's revocation arriving on this phone
    // must not turn the full-plan window into "unregistered".
    await container.read(deviceGateProvider.notifier).touch(force: true);

    expect(repository.touchCalls, 0);
    expect(
      container.read(deviceGateProvider).value?.status,
      DeviceGateStatus.limitReached,
    );
  });

  test('a not-active answer re-reads the state and revokes the gate', () async {
    final repository = _FakeDeviceRepository()
      ..stateResult = const DeviceGateState(
        status: DeviceGateStatus.revoked,
        cap: 2,
        revokedReason: 'signed_out',
      );
    final container = _container(repository);
    addTearDown(container.dispose);
    await container.read(deviceGateProvider.future);

    repository.touchResult = false;
    await container.read(deviceGateProvider.notifier).touch(force: true);

    expect(repository.stateCalls, 1);
    expect(
      container.read(deviceGateProvider).value?.status,
      DeviceGateStatus.revoked,
    );
  });

  test('a failed check resets the de-duplication window', () async {
    final repository = _FakeDeviceRepository();
    final container = _container(repository);
    addTearDown(container.dispose);
    await container.read(deviceGateProvider.future);
    final gate = container.read(deviceGateProvider.notifier);

    await gate.touch();
    expect(repository.touchCalls, 1);

    repository.throwOnTouch = true;
    await gate.touch(force: true);
    expect(repository.touchCalls, 2);

    repository.throwOnTouch = false;
    await gate.touch();
    expect(repository.touchCalls, 3);
  });

  test('a signed-out app never asks the server', () async {
    final repository = _FakeDeviceRepository();
    final container = _container(repository, identity: null);
    addTearDown(container.dispose);

    await container.read(deviceGateProvider.future);
    await container.read(deviceGateProvider.notifier).touch();

    expect(repository.touchCalls, 0);
    expect(repository.registerCalls, 0);
  });
}
