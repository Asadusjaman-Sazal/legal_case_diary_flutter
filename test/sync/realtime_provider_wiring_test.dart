/// The Realtime-to-device-gate seam.
///
/// The listener's callbacks must never run a provider read inside the socket
/// callback, and must not resurrect a gate after the provider is disposed.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/core/providers/device_providers.dart';
import 'package:legal_case_diary/features/auth/data/device_registration.dart';
import 'package:legal_case_diary/sync/sync_providers.dart';

/// A gate that records each scheduled check.
class _WiringGate extends DeviceGateController {
  final List<bool> touches = <bool>[];

  @override
  Future<DeviceGateState> build() async =>
      const DeviceGateState(status: DeviceGateStatus.unmanaged);

  @override
  Future<void> touch({bool force = false}) async => touches.add(force);
}

void main() {
  test('a scheduled check is deferred and forced', () async {
    final gate = _WiringGate();
    final container = ProviderContainer(
      overrides: [deviceGateProvider.overrideWith(() => gate)],
    );
    addTearDown(container.dispose);

    final probe = Provider<void>((ref) {
      scheduleDeviceCheck(ref, force: true);
    });
    container.read(probe);

    expect(gate.touches, isEmpty);
    await Future<void>.delayed(Duration.zero);
    expect(gate.touches, <bool>[true]);
  });

  test('a check scheduled before disposal does not run afterwards', () async {
    final gate = _WiringGate();
    final container = ProviderContainer(
      overrides: [deviceGateProvider.overrideWith(() => gate)],
    );
    container.read(deviceGateProvider.notifier);

    final probe = Provider<void>((ref) {
      scheduleDeviceCheck(ref, force: true);
    });
    container.read(probe);
    container.dispose();

    await Future<void>.delayed(Duration.zero);
    expect(gate.touches, isEmpty);
  });
}
