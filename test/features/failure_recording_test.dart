/// What the app remembers when a failure reaches the user.
///
/// The global capture in `error_capture.dart` only sees what escaped, and this
/// app lets almost nothing escape: a wrong password, a rate limit, a payment
/// refusal and a list that will not load are all caught, turned into a typed
/// failure and shown as a message. Without the view models recording what they
/// let out, the log would be empty for exactly the faults a user reports.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/features/auth/data/auth_repository.dart';
import 'package:legal_case_diary/features/auth/data/local_auth_service.dart';
import 'package:legal_case_diary/features/auth/presentation/auth_viewmodel.dart';
import 'package:legal_case_diary/features/auth/presentation/login_screen.dart';

import 'auth_test_support.dart';

void main() {
  late AuthTestHarness harness;
  late AppLocalizations l;

  /// Pumps the login screen inside the harness.
  Future<void> pumpLogin(WidgetTester tester, List<Override> overrides) async {
    await tester.binding.setSurfaceSize(const Size(420, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpAuthScreen(tester, const LoginScreen(), overrides: overrides);
    l = await AppLocalizations.delegate.load(const Locale('en'));
  }

  /// Signs in with credentials the fake has been told to refuse.
  Future<void> signIn(WidgetTester tester) async {
    await tester.enterText(
      find.byType(TextFormField).first,
      'counsel@example.com',
    );
    await tester.enterText(find.byType(TextFormField).last, 'secret123');
    await tester.tap(find.text(l.auth_loginButton));
    await tester.pumpAndSettle();
  }

  setUp(() => harness = AuthTestHarness());
  tearDown(() async {
    await harness.tearDown();
    await harness.auth.dispose();
  });

  testWidgets('a refused sign-in is remembered under the operation', (
    tester,
  ) async {
    harness.auth.signInError = const AuthFailure(
      AuthFailureKind.invalidCredentials,
    );
    await pumpLogin(tester, await harness.setUp());

    // Nothing has been tried yet, so nothing is recorded: the log is not a
    // countdown to the first sign-in.
    expect(harness.log.entries, isEmpty);

    await signIn(tester);

    // The user saw a banner, and nothing escaped to the global capture.
    expect(find.text(l.auth_errorInvalidCredentials), findsOneWidget);
    final entry = harness.log.entries.single;
    expect(entry.area, 'auth.signIn');
    expect(entry.label, 'AuthFailure(invalidCredentials)');
  });

  testWidgets('a Google sheet the user closes is not a fault', (tester) async {
    harness.auth.googleError = const AuthFailure(AuthFailureKind.cancelled);
    await pumpLogin(tester, await harness.setUp());

    await tester.tap(find.text(l.auth_googleLogin));
    await tester.pumpAndSettle();

    // The sheet was dismissed on purpose. Recording every one of those would
    // bury the failures a report is actually about.
    expect(harness.log.entries, isEmpty);
  });

  testWidgets('a failed abandoned-onboarding cleanup is remembered', (
    tester,
  ) async {
    harness.firm.abandonError = const AuthFailure(AuthFailureKind.network);
    // The pending code is what marks this device as holding an unfinished
    // onboarding, and it lives in preferences, so the harness that owns the
    // log is rebuilt around them.
    harness = AuthTestHarness(
      preferences: <String, Object>{
        pendingInviteCodeKey: 'INVITE-1',
        authGateSatisfiedKey: true,
      },
    );
    harness.firm.abandonError = const AuthFailure(AuthFailureKind.network);
    await pumpLogin(tester, await harness.setUp());

    final viewModel = ProviderScope.containerOf(
      tester.element(find.byType(LoginScreen)),
    );
    await viewModel.read(authViewModelProvider.notifier).signOut();
    await tester.pumpAndSettle();

    // This one is swallowed rather than shown: the sign-out still succeeds, so
    // without recording it "signed out, but the abandoned account is still on
    // the server" has no explanation at all.
    final entry = harness.log.entries.single;
    expect(entry.area, 'auth.abandonOnboarding');
    expect(entry.label, 'AuthFailure(network)');
  });
}