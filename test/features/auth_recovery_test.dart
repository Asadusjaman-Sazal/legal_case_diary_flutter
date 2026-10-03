/// Task 17 Phase 2 — the Password Reset screen.
///
/// The Login mockup's "Forgot Password?" link leads here, and no mockup exists
/// for the screen itself, so it is checked against the language the other two
/// auth screens use and against the flow's own promises: the recovery **code**
/// (not a deep link) is what brings the user back, a wrong code never loses the
/// address they typed, and nothing is submitted until it validates.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/router/app_router.dart';
import 'package:legal_case_diary/features/auth/data/auth_repository.dart';
import 'package:legal_case_diary/features/auth/presentation/auth_viewmodel.dart';
import 'package:legal_case_diary/features/auth/presentation/forgot_password_screen.dart';

import 'auth_test_support.dart';
import 'settings_test_support.dart';

/// The stand-in Manage Account route the Settings presentation is opened from,
/// and the marker that says we are back on it.
const String manageAccountStandIn = '/manage-account-stand-in';
const String manageAccountStandInMarker = 'Manage Account Stand-In';

void main() {
  late AuthTestHarness harness;
  late AppLocalizations l;

  /// Pumps the reset screen inside the harness and a minimal router.
  Future<void> pumpReset(WidgetTester tester) async {
    final overrides = await harness.setUp();
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpAuthRouter(tester, const ForgotPasswordScreen(), overrides: overrides);
    l = await AppLocalizations.delegate.load(const Locale('en'));
  }

  /// Pumps the reset screen in its **Settings** presentation, opened from a
  /// stand-in Manage Account screen so the return path can be asserted.
  Future<void> pumpSettingsReset(WidgetTester tester) async {
    final overrides = await harness.setUp();
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpSettingsRouter(
      tester,
      location: manageAccountStandIn,
      overrides: overrides,
      routes: <RouteBase>[
        GoRoute(
          path: manageAccountStandIn,
          builder: (context, _) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => context.push(AppRoutes.settingsChangePassword),
                child: const Text(manageAccountStandInMarker),
              ),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.settingsChangePassword,
          builder: (_, _) =>
              const ForgotPasswordScreen(asSettingsSubPage: true),
        ),
      ],
    );
    l = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.tap(find.text(manageAccountStandInMarker));
    await tester.pumpAndSettle();
  }

  /// Scrolls [finder] into view, taps it, and settles.
  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// Requests a code for [email], leaving the screen on its code step.
  Future<void> requestCode(
    WidgetTester tester, {
    String email = 'counsel@example.com',
  }) async {
    await tester.enterText(find.byType(TextFormField).first, email);
    await tapVisible(tester, find.text(l.auth_sendCodeButton));
  }

  setUp(() => harness = AuthTestHarness());
  tearDown(() async {
    await harness.tearDown();
    await harness.auth.dispose();
  });

  testWidgets('asks for the email address first', (tester) async {
    await pumpReset(tester);

    expect(find.text(l.auth_forgotTitle), findsOneWidget);
    expect(find.text(l.auth_forgotSubtitle), findsOneWidget);
    expect(find.text(l.auth_emailLabel), findsOneWidget);
    expect(find.text(l.auth_sendCodeButton), findsOneWidget);
    expect(find.text(l.auth_backToLogin), findsOneWidget);
    // The code and the new password are the second step, not this one.
    expect(find.text(l.auth_recoveryCodeLabel), findsNothing);
    expect(find.text(l.auth_newPasswordLabel), findsNothing);

    await unmountApp(tester);
  });

  testWidgets('a missing or malformed address never reaches the network', (
    tester,
  ) async {
    await pumpReset(tester);

    await tapVisible(tester, find.text(l.auth_sendCodeButton));
    expect(find.text(l.auth_validationEmailRequired), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'not-an-email');
    await tapVisible(tester, find.text(l.auth_sendCodeButton));
    expect(find.text(l.auth_validationEmailInvalid), findsOneWidget);

    expect(harness.auth.recoveryEmails, isEmpty);
    expect(find.text(l.auth_recoveryCodeLabel), findsNothing);

    await unmountApp(tester);
  });

  testWidgets('a sent code moves on to the code step', (tester) async {
    await pumpReset(tester);

    await requestCode(tester);

    expect(harness.auth.recoveryEmails, ['counsel@example.com']);
    expect(find.text(l.auth_recoverySent), findsOneWidget);
    expect(find.text(l.auth_recoveryCodeLabel), findsOneWidget);
    expect(find.text(l.auth_recoveryCodeHelper), findsOneWidget);
    expect(find.text(l.auth_newPasswordLabel), findsOneWidget);
    expect(find.text(l.auth_setPasswordButton), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('a failing send is explained and the form is kept', (
    tester,
  ) async {
    harness.auth.recoveryError = const AuthFailure(AuthFailureKind.network);
    await pumpReset(tester);

    await requestCode(tester);

    expect(find.text(l.auth_errorNetwork), findsOneWidget);
    // Still step one, so the address can be retried.
    expect(find.text(l.auth_sendCodeButton), findsOneWidget);
    expect(find.text(l.auth_recoveryCodeLabel), findsNothing);

    await unmountApp(tester);
  });

  testWidgets('a correct code sets the new password and opens the app', (
    tester,
  ) async {
    await pumpReset(tester);
    await requestCode(tester);

    // "Code Sent" is still on screen. A real user opens their mail before
    // typing anything, so let the toast live out its four seconds first —
    // ScaffoldMessenger queues messages behind each other.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, '123456');
    await tester.enterText(find.byType(TextFormField).last, 'newsecret123');
    await tapVisible(tester, find.text(l.auth_setPasswordButton));

    expect(harness.auth.verifiedCodes, ['123456']);
    expect(harness.auth.updatedPasswords, ['newsecret123']);
    expect(find.text(l.auth_passwordUpdated), findsOneWidget);
    expect(
      find.text(authLandingMarker),
      findsOneWidget,
      reason: 'the reset ends with the user signed in',
    );

    await unmountApp(tester);
  });

  testWidgets('a typed code never claims a recovery link arrived', (
    tester,
  ) async {
    // The SDK raises the same `passwordRecovery` event for a typed code as for
    // an opened link. Taking that at face value is what dragged an in-app
    // Change Password off the Settings sub-page and left the user parked on the
    // reset screen, so the event must never raise the flag the router reads.
    await pumpReset(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ForgotPasswordScreen)),
    );
    await requestCode(tester);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(
      container.read(passwordRecoveryPendingProvider),
      isFalse,
      reason: 'nothing has verified a session yet',
    );

    await tester.enterText(find.byType(TextFormField).first, '123456');
    await tester.enterText(find.byType(TextFormField).last, 'newsecret123');
    await tapVisible(tester, find.text(l.auth_setPasswordButton));

    expect(
      container.read(passwordRecoveryPendingProvider),
      isFalse,
      reason: 'a typed code is not a link, whatever the event says',
    );
    expect(find.text(l.auth_recoveryLinkSubtitle), findsNothing);

    await unmountApp(tester);
  });

  testWidgets('a rejected code is explained and the password is not set', (
    tester,
  ) async {
    harness.auth.verifyError = const AuthFailure(AuthFailureKind.unknown);
    await pumpReset(tester);
    await requestCode(tester);

    await tester.enterText(find.byType(TextFormField).first, '000000');
    await tester.enterText(find.byType(TextFormField).last, 'newsecret123');
    await tapVisible(tester, find.text(l.auth_setPasswordButton));

    expect(find.text(l.auth_errorUnknown), findsOneWidget);
    expect(harness.auth.updatedPasswords, isEmpty);
    // Still on the code step, so a fresh code can be used.
    expect(find.text(l.auth_setPasswordButton), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('a short new password is refused before the code is sent', (
    tester,
  ) async {
    await pumpReset(tester);
    await requestCode(tester);

    await tester.enterText(find.byType(TextFormField).first, '123456');
    await tester.enterText(find.byType(TextFormField).last, 'short');
    await tapVisible(tester, find.text(l.auth_setPasswordButton));

    expect(find.text(l.auth_validationPasswordTooShort), findsOneWidget);
    expect(harness.auth.verifiedCodes, isEmpty);

    await unmountApp(tester);
  });

  testWidgets('the code itself is required', (tester) async {
    await pumpReset(tester);
    await requestCode(tester);

    await tester.enterText(find.byType(TextFormField).last, 'newsecret123');
    await tapVisible(tester, find.text(l.auth_setPasswordButton));

    expect(find.text(l.auth_validationPasswordRequired), findsOneWidget);
    expect(harness.auth.verifiedCodes, isEmpty);

    await unmountApp(tester);
  });

  testWidgets('the way back to Login is plain underlined text, not a button', (
    tester,
  ) async {
    await pumpReset(tester);

    final back = tester.widget<Text>(find.text(l.auth_backToLogin));
    expect(back.style?.decoration, TextDecoration.underline);
    expect(back.style?.fontWeight, FontWeight.w600);
    expect(
      tester
          .widget<TextButton>(
            find.ancestor(
              of: find.text(l.auth_backToLogin),
              matching: find.byType(TextButton),
            ),
          )
          .style
          ?.backgroundColor
          ?.resolve(<WidgetState>{}),
      Colors.transparent,
    );

    await unmountApp(tester);
  });

  testWidgets('the new password can be revealed and hidden again', (
    tester,
  ) async {
    await pumpReset(tester);
    await requestCode(tester);

    bool obscured() =>
        tester.widget<EditableText>(find.byType(EditableText).last).obscureText;

    expect(obscured(), isTrue);
    await tapVisible(tester, find.byIcon(Icons.visibility_off_outlined));
    expect(obscured(), isFalse);

    await unmountApp(tester);
  });

  testWidgets('in Settings it is a sub-page and returns to Manage Account', (
    tester,
  ) async {
    // The Manage Account row cannot use the Login route: `/forgot-password` is
    // an auth route, so the router bounced the signed-in user to the default
    // landing page. Same screen, Settings presentation.
    await pumpSettingsReset(tester);

    // The same flow Login opens...
    expect(find.text(l.auth_forgotTitle), findsOneWidget);
    expect(find.text(l.auth_sendCodeButton), findsOneWidget);
    // ...under the Settings header, with its own back button, and without the
    // line out to Login — this user is signed in and may not go there.
    expect(
      find.text(l.settingsManageAccount_changePassword),
      findsOneWidget,
    );
    expect(find.byType(BackButton), findsOneWidget);
    expect(find.text(l.auth_backToLogin), findsNothing);

    await requestCode(tester);
    // Let the "Code Sent" toast live out its four seconds before the next one.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '123456');
    await tester.enterText(find.byType(TextFormField).last, 'newsecret123');
    await tapVisible(tester, find.text(l.auth_setPasswordButton));

    expect(harness.auth.updatedPasswords, ['newsecret123']);
    expect(find.text(l.auth_passwordUpdated), findsOneWidget);
    // Back where it was opened from, not on the sign-in route.
    expect(find.text(manageAccountStandInMarker), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('a recovery link asks only for the new password', (tester) async {
    await pumpReset(tester);

    // What the SDK reports after verifying the link in the user's mail: a real
    // session, but one whose only purpose is changing the password.
    harness.auth.emit(
      const AuthSessionEvent(
        identity: AuthIdentity(userId: 'user-9', email: 'counsel@example.com'),
        passwordRecovery: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(l.auth_recoveryLinkSubtitle), findsOneWidget);
    expect(find.text(l.auth_newPasswordLabel), findsOneWidget);
    // The link already proved the address and the identity, so neither the
    // email nor a recovery code is asked for again.
    expect(find.text(l.auth_forgotSubtitle), findsNothing);
    expect(find.text(l.auth_emailLabel), findsNothing);
    expect(find.text(l.auth_recoveryCodeLabel), findsNothing);
    expect(find.text(l.auth_sendCodeButton), findsNothing);
    // And nothing to go back to: this device is signed in as the link's owner.
    expect(find.text(l.auth_backToLogin), findsNothing);

    await tester.enterText(find.byType(TextFormField).first, 'newsecret123');
    await tapVisible(tester, find.text(l.auth_setPasswordButton));

    expect(harness.auth.updatedPasswords, ['newsecret123']);
    expect(harness.auth.verifiedCodes, isEmpty, reason: 'no code was needed');

    await unmountApp(tester);
  });
}
