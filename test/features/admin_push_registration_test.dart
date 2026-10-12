/// The admin payment-alert registration: who gets registered, and who stops.
///
/// The FCM token itself comes from a platform channel that only answers on a
/// device, so the gateway is faked here and the suite asserts what the app does
/// with the answers: an administrator's device joins the server's fan-set, a
/// non-admin's does not, a new token replaces the row, and signing out takes the
/// device back out — all of it best-effort, so a sign-out still succeeds when the
/// registration cannot be removed.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:legal_case_diary/core/providers/repository_providers.dart';
import 'package:legal_case_diary/core/push/admin_push_scope.dart';
import 'package:legal_case_diary/core/push/device_token_repository.dart';
import 'package:legal_case_diary/core/push/push_gateway.dart';
import 'package:legal_case_diary/features/admin/data/admin_repository.dart';
import 'package:legal_case_diary/features/auth/data/auth_repository.dart';
import 'package:legal_case_diary/features/auth/presentation/auth_viewmodel.dart';

import 'auth_test_support.dart';

/// A push gateway whose every answer the test decides.
class _FakePushGateway implements PushGateway {
  /// Creates a fake that reports [tokenValue].
  _FakePushGateway({this.tokenValue = 'device-token-1'});

  /// The token [token] answers with; null stands for a build with no Firebase.
  String? tokenValue;

  /// Times [initialize] was called.
  int initializeCalls = 0;

  /// Tokens the device is handed later, as FCM would.
  final StreamController<String> refreshed = StreamController<String>.broadcast();

  @override
  Future<void> initialize() async => initializeCalls++;

  @override
  Future<String?> token() async => tokenValue;

  @override
  Stream<String> tokenRefreshes() => refreshed.stream;
}

/// A push gateway that is not there at all: every call throws.
class _BrokenPushGateway implements PushGateway {
  @override
  Future<void> initialize() async => throw StateError('no push here');

  @override
  Future<String?> token() async => throw StateError('no push here');

  @override
  Stream<String> tokenRefreshes() => const Stream<String>.empty();
}

/// Records every registration write.
class _FakeDeviceTokens implements DeviceTokenRepository {
  /// Tokens written, in order.
  final List<String> registered = <String>[];

  /// Tokens removed, in order.
  final List<String> unregistered = <String>[];

  @override
  Future<void> register(String token) async => registered.add(token);

  @override
  Future<void> unregister(String token) async => unregistered.add(token);
}

/// An admin repository whose answer the test decides.
class _FakeAdmin implements AdminRepository {
  /// Creates a fake answering [admin].
  _FakeAdmin({this.admin = true});

  /// Whether the server would confirm this account as an administrator.
  bool admin;

  /// Times the status was asked.
  int statusCalls = 0;

  @override
  Future<bool> isAdmin() async {
    statusCalls++;
    return admin;
  }

  @override
  Future<List<AdminPaymentRequest>> listPaymentRequests() async =>
      const <AdminPaymentRequest>[];

  @override
  Future<AdminActionFailure?> approve(String submissionId) async => null;

  @override
  Future<AdminActionFailure?> reject(String submissionId, {String? note}) async =>
      null;

  @override
  Future<List<AdminUnconfirmedAccount>> listUnconfirmedAccounts() async =>
      const <AdminUnconfirmedAccount>[];

  @override
  Future<AdminActionFailure?> deleteUnconfirmedAccount(String userId) async =>
      null;
}

void main() {
  late AuthTestHarness harness;
  late _FakePushGateway push;
  late _FakeDeviceTokens tokens;
  late _FakeAdmin admin;

  setUp(() {
    push = _FakePushGateway();
    tokens = _FakeDeviceTokens();
    admin = _FakeAdmin();
  });

  tearDown(() async {
    await harness.tearDown();
    await harness.auth.dispose();
    await push.refreshed.close();
  });

  /// Pumps the scope over the harness, with the push fakes in place.
  Future<ProviderContainer> pumpScope(
    WidgetTester tester, {
    AuthIdentity? identity,
    PushGateway? gateway,
  }) async {
    harness = AuthTestHarness(
      auth: FakeAuthRepository(identity: identity),
    );
    await pumpAuthScreen(
      tester,
      const AdminPushScope(child: SizedBox.shrink()),
      overrides: await harness.setUp(
        extra: <Override>[
          pushGatewayProvider.overrideWithValue(gateway ?? push),
          deviceTokenRepositoryProvider.overrideWithValue(tokens),
          adminRepositoryProvider.overrideWithValue(admin),
        ],
      ),
    );
    return ProviderScope.containerOf(
      tester.element(find.byType(AdminPushScope)),
    );
  }

  testWidgets('an administrator\'s device registers its token', (tester) async {
    await pumpScope(
      tester,
      identity: const AuthIdentity(userId: 'user-a'),
    );
    await tester.pumpAndSettle();

    // One row, for the account the server confirmed, written once even though the
    // post-frame attempt and the identity listener both wanted it.
    expect(tokens.registered, <String>['device-token-1']);
    expect(push.initializeCalls, 1);
  });

  testWidgets('a signed-out device registers nothing', (tester) async {
    await pumpScope(tester);
    await tester.pumpAndSettle();

    // Nobody to register for, so the server is not even asked.
    expect(admin.statusCalls, 0);
    expect(tokens.registered, isEmpty);
    expect(push.initializeCalls, 0);
  });

  testWidgets('a non-administrator registers nothing', (tester) async {
    admin = _FakeAdmin(admin: false);
    await pumpScope(
      tester,
      identity: const AuthIdentity(userId: 'user-b'),
    );
    await tester.pumpAndSettle();

    // The fan-set holds administrators' devices only, and nothing here can put a
    // device in it that the server would never send to.
    expect(admin.statusCalls, greaterThan(0));
    expect(tokens.registered, isEmpty);
  });

  testWidgets('a device with no push channel registers nothing', (tester) async {
    _FakePushGateway tokenless() => _FakePushGateway(tokenValue: null);
    await pumpScope(
      tester,
      identity: const AuthIdentity(userId: 'user-a'),
      gateway: tokenless(),
    );
    await tester.pumpAndSettle();

    // A build with no Firebase configuration, or a token FCM has not handed out
    // yet: nothing is written, so the fan-set never holds a device that could not
    // show what it was sent.
    expect(tokens.registered, isEmpty);
  });

  testWidgets('a session that arrives while the app runs registers', (
    tester,
  ) async {
    final container = await pumpScope(tester);
    await tester.pumpAndSettle();
    expect(tokens.registered, isEmpty);

    // The ordinary way an administrator gets here: sign-in, on a running app.
    harness.auth.signInUserId = 'user-a';
    await container
        .read(authViewModelProvider.notifier)
        .signIn(email: 'counsel@example.com', password: 'secret123');
    await tester.pumpAndSettle();

    expect(tokens.registered, <String>['device-token-1']);
  });

  testWidgets('a rotated token replaces the row', (tester) async {
    await pumpScope(
      tester,
      identity: const AuthIdentity(userId: 'user-a'),
    );
    await tester.pumpAndSettle();
    expect(tokens.registered, <String>['device-token-1']);

    // A reinstall, a restore or a long-idle refresh gives the device a new token;
    // without this the alerts stop silently, which looks like nothing happening.
    push.refreshed.add('device-token-2');
    await tester.pumpAndSettle();

    expect(tokens.registered, <String>['device-token-1', 'device-token-2']);
  });

  testWidgets('signing out takes the device back out of the fan-set', (
    tester,
  ) async {
    final container = await pumpScope(
      tester,
      identity: const AuthIdentity(userId: 'user-a'),
    );
    await tester.pumpAndSettle();
    expect(tokens.registered, <String>['device-token-1']);

    await container.read(authViewModelProvider.notifier).signOut();
    await tester.pumpAndSettle();

    // The row is the device's own to delete only while it is still signed in, so
    // this happens before the session ends.
    expect(tokens.unregistered, <String>['device-token-1']);
    expect(tokens.registered, <String>['device-token-1']);
  });

  testWidgets('a registration that cannot be removed never blocks the sign-out', (
    tester,
  ) async {
    final container = await pumpScope(
      tester,
      identity: const AuthIdentity(userId: 'user-a'),
      gateway: _BrokenPushGateway(),
    );
    await tester.pumpAndSettle();

    await container.read(authViewModelProvider.notifier).signOut();
    await tester.pumpAndSettle();

    // The user is signed out all the same — this is the one action they may need
    // precisely when the network is gone — and the failure is remembered rather
    // than swallowed, because "still being pushed to" is otherwise invisible.
    expect(
      container.read(authViewModelProvider).value?.identity,
      isNull,
    );
    expect(
      harness.log.entries.map((entry) => entry.area),
      contains('auth.unregisterDeviceToken'),
    );
  });
}
