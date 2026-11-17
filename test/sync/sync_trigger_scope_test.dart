/// `SyncTriggerScope` tests — the user's sync switch (user request).
///
/// The Online Sync screen turns sync off for this app run, and the scope is what
/// acts on that outside the screen: the Realtime channel is closed at once and
/// held closed, so a paused app receives nothing from other devices either. The
/// engine's own refusal to run is pinned in `sync_service_test.dart`; this is the
/// half a socket test can see.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:legal_case_diary/core/providers/device_providers.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/account_mode.dart';
import 'package:legal_case_diary/features/auth/data/device_registration.dart';
import 'package:legal_case_diary/features/payments/data/subscription_activation.dart';
import 'package:legal_case_diary/shared/providers/shared_preferences_provider.dart';
import 'package:legal_case_diary/sync/connectivity_monitor.dart';
import 'package:legal_case_diary/sync/realtime_listener.dart';
import 'package:legal_case_diary/sync/sync_providers.dart';
import 'package:legal_case_diary/sync/sync_service.dart';
import 'package:legal_case_diary/sync/sync_trigger_scope.dart';

/// A socket that joins successfully and counts what it was asked to do.
class _FakeSocket implements RealtimeSocket {
  /// Whether a subscribe is accepted.
  bool authorized = true;

  /// Joins, in order.
  int subscribes = 0;

  @override
  Future<bool> subscribe(
    String topic, {
    required void Function(SyncPing ping) onPing,
    required void Function(RealtimeStatus status) onStatus,
  }) async {
    subscribes++;
    onStatus(authorized ? RealtimeStatus.subscribed : RealtimeStatus.failed);
    return authorized;
  }

  @override
  Future<void> unsubscribe() async {}
}

/// An activation detector that does nothing, so the scope's upgrade path needs
/// no preferences, no database and no backlog pass.
class _SilentActivation extends SubscriptionActivation {
  _SilentActivation()
    : super(prefs: _prefs, userId: 'user-1', runBacklogPush: () async {});

  @override
  Future<bool> observe(bool premium) async => false;
}

/// A gate that records the slot checks the scope asks for.
class _TouchGate extends DeviceGateController {
  /// Each check, with whether it was forced.
  final List<bool> touches = <bool>[];

  @override
  Future<DeviceGateState> build() async =>
      const DeviceGateState(status: DeviceGateStatus.unmanaged);

  @override
  Future<void> touch({bool force = false}) async => touches.add(force);
}

/// A service that records what the scope asks it to do.
class _CountingService extends SyncService {
  _CountingService(super.ref);

  /// Sync requests received.
  int requests = 0;

  @override
  void requestSync({bool pull = false}) => requests++;
}

/// Sync is off for this probe; the reconnect listener still records its ask.
class _OffSwitch extends SyncEnabledNotifier {
  @override
  bool build() => false;
}

/// Stands in for the device's preferences; the silent detector never reads it.
late SharedPreferences _prefs;

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    _prefs = await SharedPreferences.getInstance();
  });

  /// Pumps the scope with a listener over [socket], and returns the container so
  /// a test can flip the switch the way the screen does.
  Future<ProviderContainer> pumpScope(
    WidgetTester tester,
    _FakeSocket socket, {
    List<Override> extra = const <Override>[],
    Stream<bool>? onlineChanges,
    SyncService Function(Ref ref)? service,
  }) async {
    final overrides = <Override>[
      ...extra,
      // The three facts that decide whether the channel may open at all.
      premiumAccessProvider.overrideWith((ref) async => true),
      isOnlineProvider.overrideWith(
        (ref) => onlineChanges ?? Stream<bool>.value(true),
      ),
      accountProfileProvider.overrideWith(
        (ref) => Stream<Profile?>.value(null),
      ),
      sharedPreferencesProvider.overrideWithValue(_prefs),
      subscriptionActivationProvider.overrideWithValue(_SilentActivation()),
      // The channel under test: the app's own listener over a socket that needs
      // no server, wired the way production wires it.
      realtimeListenerProvider.overrideWith(
        (ref) => RealtimeListener(
          socket: socket,
          topic: () => 'user:user-1',
          onPings: (_) {},
        ),
      ),
      // No transport, so the launch drain asks for nothing while this test is
      // about the channel rather than the workers.
      syncServiceProvider.overrideWith(
        (ref) =>
            service?.call(ref) ??
            SyncService(ref, transportOverride: () => null),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: const MaterialApp(
          home: SyncTriggerScope(child: SizedBox.shrink()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    return ProviderScope.containerOf(
      tester.element(find.byType(SyncTriggerScope)),
      listen: false,
    );
  }

  testWidgets('a resume forces the slot check', (tester) async {
    final socket = _FakeSocket();
    final gate = _TouchGate();
    await pumpScope(
      tester,
      socket,
      extra: [deviceGateProvider.overrideWith(() => gate)],
    );
    gate.touches.clear();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(gate.touches, <bool>[true]);
  });

  testWidgets('a reconnect asks the engine to sync', (tester) async {
    final online = StreamController<bool>();
    addTearDown(online.close);
    late _CountingService service;
    await pumpScope(
      tester,
      _FakeSocket(),
      onlineChanges: online.stream,
      service: (ref) => service = _CountingService(ref),
      extra: [syncEnabledProvider.overrideWith(_OffSwitch.new)],
    );
    final before = service.requests;

    online.add(false);
    await tester.pumpAndSettle();
    online.add(true);
    await tester.pumpAndSettle();

    expect(service.requests, before + 1);
  });

  testWidgets('switching sync off closes the channel, and on reopens it', (
    tester,
  ) async {
    final socket = _FakeSocket();
    final container = await pumpScope(tester, socket);
    final listener = container.read(realtimeListenerProvider);

    // Launch: entitlement is there, so the channel is open and receiving.
    expect(listener.isSubscribed, isTrue);

    // The screen's switch, turned off.
    container.read(syncEnabledProvider.notifier).setEnabled(false);
    await tester.pumpAndSettle();

    // Closed at once: a paused app holds no socket, so nothing arrives from
    // another device while sync is off.
    expect(listener.isSubscribed, isFalse);
    expect(listener.status.value, RealtimeStatus.stopped);

    // And back on is a fresh join.
    final joins = socket.subscribes;
    container.read(syncEnabledProvider.notifier).setEnabled(true);
    await tester.pumpAndSettle();

    expect(listener.isSubscribed, isTrue);
    expect(socket.subscribes, joins + 1);
  });
}
