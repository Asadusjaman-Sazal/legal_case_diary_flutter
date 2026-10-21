/// Tests for the device limit's surface: the Devices screen and the gate.
///
/// The server owns the limit; these pin the two screens that explain it — a full
/// plan that names the devices holding the slots, and a revoked device that says
/// whether its work was saved before it was erased.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/providers/device_providers.dart';
import 'package:legal_case_diary/features/accounts_and_profile/presentation/devices_screen.dart';
import 'package:legal_case_diary/features/auth/data/device_registration.dart';
import 'package:legal_case_diary/features/auth/presentation/device_gate_scope.dart';

/// A gate whose answer the test decides, with removal recorded.
class _FakeGate extends DeviceGateController {
  _FakeGate(this.currentState);

  /// The state this gate builds with, and after a removal.
  DeviceGateState currentState;

  /// Device ids removed, in order.
  final List<String> removed = <String>[];

  @override
  Future<DeviceGateState> build() async => currentState;

  @override
  Future<void> refresh({bool claim = true}) async {}

  @override
  Future<bool> remove(String deviceId) async {
    removed.add(deviceId);
    currentState = currentState.copyWith(
      devices: currentState.devices
          .where((device) => device.id != deviceId)
          .toList(growable: false),
    );
    // The real controller re-reads the list after a removal; the screen watches
    // this state, so the fake publishes it the same way.
    state = AsyncData(currentState);
    return true;
  }
}

/// One registered device for the fixtures.
RegisteredDevice _device(String id, String label, {bool current = false}) =>
    RegisteredDevice(
      id: id,
      label: label,
      platform: 'android',
      lastSeenAt: DateTime(2026, 10, 20, 9),
      isCurrent: current,
    );

/// Pumps a screen with the gate overridden to [state].
Future<_FakeGate> _pump(
  WidgetTester tester,
  DeviceGateState state, {
  required Widget child,
}) async {
  final gate = _FakeGate(state);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [deviceGateProvider.overrideWith(() => gate)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return gate;
}

void main() {
  testWidgets('the Devices screen lists the slots and frees one', (
    tester,
  ) async {
    final gate = await _pump(
      tester,
      DeviceGateState(
        status: DeviceGateStatus.active,
        cap: 3,
        devices: [
          _device('d1', 'Samsung SM-A525F', current: true),
          _device('d2', 'Xiaomi 13'),
        ],
      ),
      child: const DevicesScreen(),
    );

    expect(find.text('2 of 3 devices in use'), findsOneWidget);
    expect(find.text('Samsung SM-A525F · This device'), findsOneWidget);
    expect(find.text('Xiaomi 13'), findsOneWidget);

    // The current device cannot remove itself; the other can.
    expect(find.text('Remove'), findsOneWidget);
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(find.text('Remove This Device?'), findsOneWidget);

    await tester.tap(find.text('Remove').last);
    await tester.pumpAndSettle();
    expect(gate.removed, ['d2']);
    expect(find.text('Xiaomi 13'), findsNothing);
  });

  testWidgets('a full plan names every device and offers no silent eviction', (
    tester,
  ) async {
    await _pump(
      tester,
      DeviceGateState(
        status: DeviceGateStatus.limitReached,
        cap: 2,
        devices: [
          _device('d1', 'Samsung SM-A525F'),
          _device('d2', 'Xiaomi 13', current: true),
        ],
      ),
      child: DeviceGateScope(
        router: GoRouter(
          routes: [
            GoRoute(path: '/', builder: (context, _) => const SizedBox()),
          ],
        ),
        child: const Scaffold(body: Text('the app')),
      ),
    );

    expect(find.text('Your Plan Is Full'), findsOneWidget);
    expect(find.textContaining('already in use on 2 devices'), findsOneWidget);
    expect(find.text('Samsung SM-A525F'), findsOneWidget);
    expect(find.text('Xiaomi 13'), findsOneWidget);
    // The app itself is not reachable behind the gate.
    expect(find.text('the app'), findsNothing);
  });

  testWidgets('a revoked device says it could not save, and erases nothing', (
    tester,
  ) async {
    await _pump(
      tester,
      const DeviceGateState(
        status: DeviceGateStatus.revoked,
        cap: 2,
        revokedReason: 'cap',
      ),
      child: DeviceGateScope(
        router: GoRouter(
          routes: [
            GoRoute(path: '/', builder: (context, _) => const SizedBox()),
          ],
        ),
        child: const Scaffold(body: Text('the app')),
      ),
    );
    // The push cannot run in a test host, so the screen must stay on the failed
    // branch: nothing has been erased, and the copy says so.
    await tester.pumpAndSettle();

    expect(find.text('This Device Was Signed Out'), findsOneWidget);
    expect(find.text('Try Again'), findsOneWidget);
    expect(find.text('Sign Out and Discard'), findsOneWidget);
    expect(find.text('the app'), findsNothing);
  });

  testWidgets('a revoked device is told why it lost its slot', (tester) async {
    await _pump(
      tester,
      const DeviceGateState(
        status: DeviceGateStatus.revoked,
        cap: 1,
        revokedReason: 'lapse',
      ),
      child: DeviceGateScope(
        router: GoRouter(
          routes: [
            GoRoute(path: '/', builder: (context, _) => const SizedBox()),
          ],
        ),
        child: const Scaffold(body: Text('the app')),
      ),
    );
    await tester.pumpAndSettle();

    // A fallen ceiling is not another device taking the slot: the sentence says
    // the plan changed, and the failed save sits beside it rather than replacing
    // it.
    expect(
      find.textContaining('Your plan changed and now allows 1 device'),
      findsOneWidget,
    );
    expect(find.textContaining('another device took this one'), findsNothing);
    expect(find.textContaining('nothing has been erased'), findsOneWidget);
  });
}
