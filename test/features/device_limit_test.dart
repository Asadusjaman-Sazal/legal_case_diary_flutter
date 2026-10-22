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

import 'package:legal_case_diary/core/constants/app_colors.dart';
import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/notifications/notification_scheduler.dart';
import 'package:legal_case_diary/core/providers/device_providers.dart';
import 'package:legal_case_diary/core/providers/notification_providers.dart';
import 'package:legal_case_diary/features/accounts_and_profile/presentation/devices_screen.dart';
import 'package:legal_case_diary/features/auth/data/device_registration.dart';
import 'package:legal_case_diary/features/auth/data/logout_flow.dart';
import 'package:legal_case_diary/features/auth/presentation/device_gate_scope.dart';

/// A gate whose answer the test decides, with the actions recorded.
class _FakeGate extends DeviceGateController {
  _FakeGate(this.currentState);

  /// The state this gate builds with, and after an action.
  DeviceGateState currentState;

  /// Device ids removed, in order.
  final List<String> removed = <String>[];

  /// Device ids signed out from the third-device window, in order.
  final List<String> signedOut = <String>[];

  /// Read-only refreshes requested by the Devices screen.
  int readCalls = 0;

  @override
  Future<DeviceGateState> build() async => currentState;

  @override
  Future<void> refresh({bool claim = true}) async {
    if (!claim) readCalls++;
  }

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

  @override
  Future<bool> signOut(String deviceId) async {
    signedOut.add(deviceId);
    currentState = DeviceGateState(
      status: DeviceGateStatus.active,
      cap: currentState.cap,
      devices: currentState.devices
          .where((device) => device.id != deviceId)
          .toList(growable: false),
    );
    state = AsyncData(currentState);
    return true;
  }

  @override
  Future<void> acknowledgeWipe() async {}
}

/// A scheduler that does nothing, for the revoked screen's discard.
class _NoopScheduler implements NotificationScheduler {
  @override
  Future<void> cancelAll() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A gate that cannot reach the server, for the fresh-login check.
class _OfflineGate extends DeviceGateController {
  @override
  Future<DeviceGateState> build() async =>
      throw StateError('offline during the device check');

  @override
  Future<void> refresh({bool claim = true}) async {}
}

/// Makes the first device check after a sign-in fail closed.
class _FreshFlag extends FreshDeviceCheckNotifier {
  @override
  bool build() => true;
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
      overrides: [
        deviceGateProvider.overrideWith(() => gate),
        notificationSchedulerProvider.overrideWithValue(_NoopScheduler()),
        // The revoked screens start an erasure; in a widget test there is no
        // logout flow, so the screen shows its retry rather than spinning.
        logoutFlowProvider.overrideWith(
          (ref) async => throw StateError('no logout flow in a widget test'),
        ),
      ],
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
    // Opening the screen reads the authoritative list from device_state.
    expect(gate.readCalls, 1);

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

  testWidgets('a full plan names every device and warns before signing out', (
    tester,
  ) async {
    final gate = await _pump(
      tester,
      DeviceGateState(
        status: DeviceGateStatus.limitReached,
        cap: 2,
        devices: [
          _device('d1', 'Samsung SM-A525F'),
          _device('d2', 'Xiaomi 13'),
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

    expect(find.text('Device Limit Reached'), findsOneWidget);
    expect(
      find.textContaining('already signed in on 2 devices'),
      findsOneWidget,
    );
    // The warning is its own block, below the explanation.
    final explanation = tester.getBottomLeft(
      find.textContaining('already signed in on 2 devices'),
    );
    final warning = tester.getTopLeft(find.text('Warning:'));
    expect(warning.dy, greaterThan(explanation.dy));
    expect(
      find.text(
        'Any unsaved or unsynced work on the device you sign out from may be lost.',
      ),
      findsOneWidget,
    );
    expect(find.text('Samsung SM-A525F'), findsOneWidget);
    expect(find.text('Xiaomi 13'), findsOneWidget);
    expect(find.text('Sign Out'), findsNWidgets(2));
    expect(find.text('Sign Out This Device'), findsOneWidget);
    // The app itself is not reachable behind the gate.
    expect(find.text('the app'), findsNothing);

    for (final button in tester.widgetList<FilledButton>(
      find.widgetWithText(FilledButton, 'Sign Out'),
    )) {
      expect(
        button.style?.backgroundColor?.resolve(<WidgetState>{}),
        AppColors.error,
      );
      expect(
        button.style?.foregroundColor?.resolve(<WidgetState>{}),
        AppColors.onError,
      );
    }

    // Signing one out revokes it and the fake's fresh check admits this device.
    await tester.tap(find.byKey(const ValueKey('device-sign-out-d1')));
    await tester.pumpAndSettle();
    expect(gate.signedOut, ['d1']);
    expect(find.text('the app'), findsOneWidget);
  });

  testWidgets('an unregistered answer blocks the app', (tester) async {
    await _pump(
      tester,
      const DeviceGateState(status: DeviceGateStatus.unregistered, cap: 2),
      child: DeviceGateScope(
        router: GoRouter(
          routes: [
            GoRoute(path: '/', builder: (context, _) => const SizedBox()),
          ],
        ),
        child: const Scaffold(body: Text('the app')),
      ),
    );

    expect(find.text('Could Not Check This Device'), findsOneWidget);
    expect(find.text('Try Again'), findsOneWidget);
    expect(find.text('the app'), findsNothing);
  });

  testWidgets('a fresh login fails closed when the slot cannot be checked', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceGateProvider.overrideWith(_OfflineGate.new),
          freshDeviceCheckProvider.overrideWith(_FreshFlag.new),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DeviceGateScope(
            router: GoRouter(
              routes: [
                GoRoute(path: '/', builder: (context, _) => const SizedBox()),
              ],
            ),
            child: const Scaffold(body: Text('the app')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could Not Check This Device'), findsOneWidget);
    expect(find.text('the app'), findsNothing);
  });

  testWidgets('a revoked device discards its local copy and offers a retry', (
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
    // The erasure cannot run in a test host, so the screen must stay on the
    // failed branch: nothing has been erased, and the copy says so.
    await tester.pumpAndSettle();

    expect(find.text('This Device Was Signed Out'), findsOneWidget);
    expect(
      find.textContaining('Any unsaved work on this device is discarded'),
      findsOneWidget,
    );
    expect(
      find.text('Could not erase this device. Try again.'),
      findsOneWidget,
    );
    expect(find.text('Try Again'), findsOneWidget);
    expect(find.text('Sign Out and Discard'), findsNothing);
    expect(find.text('the app'), findsNothing);
  });

  testWidgets('a signed-out device discards and offers a retry', (
    tester,
  ) async {
    await _pump(
      tester,
      const DeviceGateState(
        status: DeviceGateStatus.revoked,
        cap: 2,
        revokedReason: 'signed_out',
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

    expect(find.text('This Device Was Signed Out'), findsOneWidget);
    expect(
      find.text(
        'This device was signed out from another device. Its local copy is being erased.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Could not erase this device. Try again.'),
      findsOneWidget,
    );
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
    // the plan changed, and it says the unsaved work is discarded.
    expect(
      find.textContaining('Your plan changed and now allows 1 device'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Any unsaved work on this device is discarded'),
      findsOneWidget,
    );
    expect(find.textContaining('another device took this one'), findsNothing);
    expect(find.textContaining('nothing has been erased'), findsNothing);
  });
}
