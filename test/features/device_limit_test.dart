/// Tests for the device limit's surface: the Devices screen and the gate.
///
/// The server owns the limit; these pin the two screens that explain it — a full
/// plan that names the devices holding the slots, and a revoked device that says
/// whether its work was saved before it was erased.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:legal_case_diary/core/constants/app_colors.dart';
import 'package:legal_case_diary/core/devices/device_install_secret.dart';
import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/notifications/notification_scheduler.dart';
import 'package:legal_case_diary/core/providers/device_providers.dart';
import 'package:legal_case_diary/core/providers/notification_providers.dart';
import 'package:legal_case_diary/core/router/app_router.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/database/encryption_key_manager.dart';
import 'package:legal_case_diary/features/accounts_and_profile/presentation/devices_screen.dart';
import 'package:legal_case_diary/features/auth/data/device_registration.dart';
import 'package:legal_case_diary/features/auth/data/logout_flow.dart';
import 'package:legal_case_diary/features/auth/presentation/auth_viewmodel.dart';
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

/// An auth view model that records the sign-out without touching the SDK.
class _FakeAuth extends AuthViewModel {
  /// Sign-outs requested by the gate.
  int signOutCalls = 0;

  @override
  Future<AuthState> build() async => const AuthState();

  @override
  Future<void> signOut() async => signOutCalls++;
}

/// A logout flow that completes without touching a database or the SDK.
class _InstantLogout extends LogoutFlow {
  _InstantLogout({Future<void> Function()? endSession, this.onWipe})
    : super(
        db: AppDatabase(NativeDatabase.memory()),
        premium: true,
        online: true,
        runBacklogPush: () async => null,
        endSession: endSession ?? () async {},
      );

  final void Function()? onWipe;

  @override
  Future<LogoutResult> wipeAndComplete() async {
    onWipe?.call();
    await endSession();
    return LogoutResult.completed;
  }
}

/// The justified first paragraph of the plan-limit screen, as spans.
List<TextSpan> _planBodySpans(WidgetTester tester) {
  final text = tester
      .widgetList<Text>(find.byType(Text))
      .firstWhere((widget) => widget.textSpan is TextSpan);
  return (text.textSpan! as TextSpan).children!.cast<TextSpan>();
}

/// A router that knows both the gate's home and the Login screen.
GoRouter _router() => GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, _) => const SizedBox()),
    GoRoute(
      path: AppRoutes.login,
      builder: (context, _) => const Scaffold(body: Text('login')),
    ),
  ],
);

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

  testWidgets('a plan-limit revocation states the cap and the discard', (
    tester,
  ) async {
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

    // A cap of one is not Pro, so the plan is named generically.
    expect(find.text('Device Limit Reached'), findsOneWidget);
    final spans = _planBodySpans(tester);
    expect(spans[0].text, 'Your plan allows a maximum of ');
    expect(spans[1].text, '1 device to be signed in at the same time');
    expect(spans[1].style?.fontWeight, FontWeight.w700);
    expect(
      spans[2].text,
      '. You’re already signed in on 1 device, so you’ve been signed out on this device.',
    );

    final discarded = tester.widget<Text>(
      find.text(
        'Any unsaved or unsynced work on this device has been discarded.',
      ),
    );
    expect(discarded.textAlign, TextAlign.justify);
    expect(discarded.style?.fontWeight, FontWeight.w700);
    expect(
      find.text(
        'To continue using this device, please log in again using the button below.',
      ),
      findsOneWidget,
    );

    // The widget-test erase fails, so the screen must not offer a way out that
    // would leave the local copy behind.
    expect(
      find.text('Could not erase this device. Try again.'),
      findsOneWidget,
    );
    expect(find.text('Try Again'), findsOneWidget);
    expect(find.text('Back to Login'), findsNothing);
  });

  testWidgets('after the discard, the plan screen offers Back to Login', (
    tester,
  ) async {
    late final GoRouter router;
    router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => DeviceGateScope(
            router: router,
            child: const Scaffold(body: Text('the app')),
          ),
        ),
        GoRoute(
          path: AppRoutes.login,
          builder: (context, _) => const Scaffold(body: Text('login')),
        ),
      ],
    );
    final gate = _FakeGate(
      const DeviceGateState(
        status: DeviceGateStatus.revoked,
        cap: 2,
        revokedReason: 'cap',
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceGateProvider.overrideWith(() => gate),
          notificationSchedulerProvider.overrideWithValue(_NoopScheduler()),
          logoutFlowProvider.overrideWith(
            (ref) async => _InstantLogout(
              // A real sign-out turns the gate provider `unmanaged`; the
              // explanation must survive that rebuild.
              endSession: () async {
                gate.currentState = const DeviceGateState(
                  status: DeviceGateStatus.unmanaged,
                );
                gate.state = const AsyncData(
                  DeviceGateState(status: DeviceGateStatus.unmanaged),
                );
              },
            ),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Two devices is Pro, so the plan is named; the limit phrase stays bold.
    expect(find.text('Device Limit Reached'), findsOneWidget);
    final spans = _planBodySpans(tester);
    expect(spans[0].text, 'Your Pro plan allows a maximum of ');
    expect(spans[1].text, '2 devices to be signed in at the same time');
    expect(spans[1].style?.fontWeight, FontWeight.w700);
    expect(
      spans[2].text,
      '. You’re already signed in on 2 devices, so you’ve been signed out on this device.',
    );
    expect(find.text('the app'), findsNothing);

    // The discard completed, so the way out is offered.
    expect(find.text('Could not erase this device. Try again.'), findsNothing);
    final backToLogin = find.text('Back to Login');
    expect(backToLogin, findsOneWidget);

    await tester.tap(backToLogin);
    await tester.pumpAndSettle();
    expect(find.text('login'), findsOneWidget);
  });

  testWidgets('a later sign-in is gated from scratch', (tester) async {
    var wipes = 0;
    final gate = _FakeGate(
      const DeviceGateState(
        status: DeviceGateStatus.revoked,
        cap: 2,
        revokedReason: 'cap',
      ),
    );
    late final GoRouter router;
    router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => const Scaffold(body: Text('the app')),
        ),
        GoRoute(
          path: AppRoutes.login,
          builder: (context, _) => const Scaffold(body: Text('login')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceGateProvider.overrideWith(() => gate),
          notificationSchedulerProvider.overrideWithValue(_NoopScheduler()),
          logoutFlowProvider.overrideWith(
            (ref) async => _InstantLogout(
              onWipe: () => wipes++,
              endSession: () async {
                gate.currentState = const DeviceGateState(
                  status: DeviceGateStatus.unmanaged,
                );
                gate.state = const AsyncData(
                  DeviceGateState(status: DeviceGateStatus.unmanaged),
                );
              },
            ),
          ),
        ],
        // The gate sits above the navigator, as it does in `app.dart`, so it
        // survives the move to Login.
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) =>
              DeviceGateScope(router: router, child: child ?? const SizedBox()),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(wipes, 1);

    await tester.tap(find.text('Back to Login'));
    await tester.pumpAndSettle();
    expect(find.text('login'), findsOneWidget);

    // A new sign-in is refused again: the gate must discard this session too,
    // not remember the previous one as already handled.
    gate.currentState = const DeviceGateState(
      status: DeviceGateStatus.revoked,
      cap: 2,
      revokedReason: 'cap',
    );
    gate.state = AsyncData(gate.currentState);
    await tester.pumpAndSettle();

    expect(wipes, 2);
    expect(find.text('Device Limit Reached'), findsOneWidget);
  });

  testWidgets('a device removed from the list discards and offers a retry', (
    tester,
  ) async {
    await _pump(
      tester,
      const DeviceGateState(
        status: DeviceGateStatus.revoked,
        cap: 2,
        revokedReason: 'user',
      ),
      child: DeviceGateScope(
        router: _router(),
        child: const Scaffold(body: Text('the app')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('This Device Was Signed Out'), findsOneWidget);
    expect(
      find.text(
        'You removed this device from your device list. Any unsaved work on this device is discarded.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Could not erase this device. Try again.'),
      findsOneWidget,
    );
    expect(find.text('the app'), findsNothing);
  });

  testWidgets('a same-install re-login ends the old sign-in and keeps data', (
    tester,
  ) async {
    var logoutReads = 0;
    // The gate navigates on this path, so the router must actually drive the
    // app rather than sit beside a plain MaterialApp.
    late final GoRouter router;
    router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => DeviceGateScope(
            router: router,
            child: const Scaffold(body: Text('the app')),
          ),
        ),
        GoRoute(
          path: AppRoutes.login,
          builder: (context, _) => const Scaffold(body: Text('login')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceGateProvider.overrideWith(
            () => _FakeGate(
              const DeviceGateState(
                status: DeviceGateStatus.revoked,
                cap: 2,
                revokedReason: 'replaced',
              ),
            ),
          ),
          authViewModelProvider.overrideWith(_FakeAuth.new),
          // The keep-data path must never reach the erasure.
          logoutFlowProvider.overrideWith((ref) async {
            logoutReads++;
            throw StateError('a replaced sign-in must not wipe');
          }),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pump();

    final auth =
        ProviderScope.containerOf(
              tester.element(find.byType(DeviceGateScope)),
            ).read(authViewModelProvider.notifier)
            as _FakeAuth;

    expect(find.text('This Sign-In Has Ended'), findsOneWidget);
    expect(find.textContaining('Your local data is kept.'), findsOneWidget);
    expect(find.text('the app'), findsNothing);

    await tester.pumpAndSettle();

    expect(auth.signOutCalls, 1);
    expect(logoutReads, 0);
    expect(find.text('Could not erase this device. Try again.'), findsNothing);
    expect(find.text('login'), findsOneWidget);
  });

  testWidgets('a cloned session is ended and its local copy discarded', (
    tester,
  ) async {
    await _pump(
      tester,
      const DeviceGateState(
        status: DeviceGateStatus.sessionInUse,
        cap: 2,
        revokedReason: 'session_in_use',
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

    expect(find.text('This Sign-In Was Ended'), findsOneWidget);
    expect(
      find.text(
        "This sign-in was opened somewhere else, so the app ended it here to protect your diary. This device's local copy is being erased.",
      ),
      findsOneWidget,
    );
    expect(
      find.text('Could not erase this device. Try again.'),
      findsOneWidget,
    );
    expect(find.text('the app'), findsNothing);
  });

  group('DeviceInstallSecretStore', () {
    test('mints one secret and reuses it', () async {
      final storage = InMemoryKeyStorage();
      final store = DeviceInstallSecretStore(storage);

      final first = await store.loadOrCreate();
      final second = await store.loadOrCreate();

      // 32 random bytes in base64url are 44 characters, all safe in a header.
      expect(first.length, greaterThanOrEqualTo(32));
      expect(first, matches(RegExp(r'^[A-Za-z0-9_=-]+$')));
      expect(second, first);
      expect(await storage.read(key: installSecretStorageKey), first);
    });

    test('replaces a value too short to be a secret', () async {
      final storage = InMemoryKeyStorage();
      await storage.write(key: installSecretStorageKey, value: 'short');

      final secret = await DeviceInstallSecretStore(storage).loadOrCreate();

      expect(secret, isNot('short'));
      expect(secret.length, greaterThanOrEqualTo(32));
    });
  });
}
