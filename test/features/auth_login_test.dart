/// Task 17 Phase 2 — the unified Login screen.
///
/// The screen is built to `mockup_html_screens/settings_onlineSync_login`: one
/// Email + Password form for everyone, the show/hide password control, the
/// "Forgot Password?" link, the Google button and the Sign Up line. These tests
/// pin the behaviour behind that body: every failure the user can hit has its
/// own message, the form is validated before anything is sent, and a success
/// stores the identity the rest of the app then reads.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/core/constants/app_spacing.dart';
import 'package:legal_case_diary/core/constants/app_typography.dart';
import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/firm_repository.dart';
import 'package:legal_case_diary/features/auth/data/auth_repository.dart';
import 'package:legal_case_diary/features/auth/data/local_auth_service.dart';
import 'package:legal_case_diary/features/auth/presentation/auth_widgets.dart';
import 'package:legal_case_diary/features/auth/presentation/login_screen.dart';

import 'auth_test_support.dart';

void main() {
  late AuthTestHarness harness;
  late AppLocalizations l;

  /// Pumps the login screen inside the harness.
  Future<void> pumpLogin(WidgetTester tester) async {
    final overrides = await harness.setUp();
    await tester.binding.setSurfaceSize(const Size(420, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpAuthScreen(tester, const LoginScreen(), overrides: overrides);
    l = await AppLocalizations.delegate.load(const Locale('en'));
  }

  /// The Email field's own decoration, where its placeholder lives.
  InputDecoration emailDecoration(WidgetTester tester) => tester
      .widget<TextField>(
        find.descendant(
          of: find.byType(TextFormField).first,
          matching: find.byType(TextField),
        ),
      )
      .decoration!;

  /// The fill of the language button reading [label].
  Color? languageFill(WidgetTester tester, String label) => tester
      .widget<Material>(
        find.ancestor(of: find.text(label), matching: find.byType(Material)).first,
      )
      .color;

  /// Types [email] and [password] and taps Login.
  Future<void> submitLogin(
    WidgetTester tester, {
    String email = 'counsel@example.com',
    String password = 'secret123',
  }) async {
    await tester.enterText(
      find.byType(TextFormField).first,
      email,
    );
    await tester.enterText(find.byType(TextFormField).last, password);
    await tester.tap(find.text(l.auth_loginButton));
    await tester.pumpAndSettle();
  }

  setUp(() => harness = AuthTestHarness());
  tearDown(() async {
    await harness.tearDown();
    await harness.auth.dispose();
  });

  testWidgets('renders the mockup card, its fields and its links', (
    tester,
  ) async {
    await pumpLogin(tester);

    expect(find.text(l.appName), findsOneWidget);
    // The card's name is set in the large headline token, which is the size the
    // Sign Up card's wordmark now takes from it (user request).
    expect(
      tester.widget<Text>(find.text(l.appName)).style,
      AppTypography.headlineLg,
    );
    expect(find.text(l.auth_loginSubtitle), findsOneWidget);
    // The subtitle's wording is the user's, pinned literally (as the exit
    // window's copy is) so a later copy edit has to be deliberate.
    expect(find.text('Log in to the app'), findsOneWidget);
    expect(find.text(l.auth_emailLabel), findsOneWidget);
    // The placeholder the user asked the field to carry.
    expect(emailDecoration(tester).hintText, 'example@gmail.com');
    expect(find.text(l.auth_passwordLabel), findsOneWidget);
    expect(find.text(l.auth_forgotPassword), findsOneWidget);
    expect(find.text(l.auth_loginButton), findsOneWidget);
    expect(find.text(l.auth_orContinueWith), findsOneWidget);
    expect(find.text(l.auth_googleLogin), findsOneWidget);
    expect(find.byType(GoogleMark), findsOneWidget);
    expect(find.text(l.auth_noAccount), findsOneWidget);
    expect(find.text(l.auth_signUpLink), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('the header shows the bundled app logo, not the placeholder', (
    tester,
  ) async {
    await pumpLogin(tester);

    // The round account_balance chip the header used to draw is gone...
    expect(find.byIcon(Icons.account_balance), findsNothing);

    final logo = find.byWidgetPredicate(
      (widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName ==
              'assets/icons/app_logo.png',
    );
    // ...replaced by the bundled logo, in the chip's own 48 x 48 footprint.
    expect(logo, findsOneWidget);
    expect(tester.getSize(logo), const Size(48, 48));

    // The asset is really bundled (declared under `assets:` in pubspec.yaml),
    // so the image loads instead of falling back to the chip.
    final bytes = await rootBundle.load('assets/icons/app_logo.png');
    expect(bytes.lengthInBytes, greaterThan(0));

    await unmountApp(tester);
  });

  testWidgets('the recovery link opens the reset screen', (tester) async {
    // The moved link still routes, so it is checked inside a router rather than
    // through `pumpLogin`'s bare `home:` tree.
    final overrides = await harness.setUp();
    await tester.binding.setSurfaceSize(const Size(420, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpAuthRouter(tester, const LoginScreen(), overrides: overrides);

    await tester.tap(find.text(l.auth_forgotPassword));
    await tester.pumpAndSettle();

    expect(find.text('auth-route'), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('the language switch re-words the screen before signing in', (
    tester,
  ) async {
    final overrides = await harness.setUp();
    await tester.binding.setSurfaceSize(const Size(420, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    // The shell follows the locale provider here, as the app's own shell does,
    // so this shows the screen changing language rather than only the
    // preference being written.
    await pumpAuthScreen(
      tester,
      const LoginScreen(),
      overrides: overrides,
      followLocale: true,
    );
    final english = await AppLocalizations.delegate.load(const Locale('en'));
    final bengali = await AppLocalizations.delegate.load(const Locale('bn'));

    // Offered before signing in, in the top right corner (user request), with
    // the active language filled black and the other left outlined.
    expect(find.text(english.settingsScreen_languageEnglish), findsOneWidget);
    expect(find.text(english.settingsScreen_languageBengali), findsOneWidget);
    // The screen's own corner, not the centred card's column: flush with the
    // card's edge margin, and outside the scrolling area, so the switch keeps
    // its place while the card below it scrolls.
    final switchRect = tester.getRect(find.byType(AuthLanguageSwitch));
    expect(switchRect.right, closeTo(420 - AppSpacing.edgeMargin, 0.5));
    expect(switchRect.top, closeTo(AppSpacing.edgeMargin, 0.5));
    expect(
      find.descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.byType(AuthLanguageSwitch),
      ),
      findsNothing,
    );
    // And clear of the card, which is centred further down the page.
    expect(
      tester.getTopLeft(find.text(english.appName)).dy,
      greaterThan(switchRect.bottom),
    );
    expect(
      languageFill(tester, english.settingsScreen_languageEnglish),
      Colors.black,
    );
    expect(
      languageFill(tester, english.settingsScreen_languageBengali),
      isNot(Colors.black),
    );

    await tester.tap(find.text(english.settingsScreen_languageBengali));
    await tester.pumpAndSettle();

    expect(find.text(bengali.auth_loginButton), findsOneWidget);
    expect(find.text(english.auth_loginButton), findsNothing);
    // The same preference Settings > Language writes.
    expect(harness.prefs.getString('app_locale'), 'bn');

    // And back, so the choice is not a one-way door.
    await tester.tap(find.text(bengali.settingsScreen_languageEnglish));
    await tester.pumpAndSettle();
    expect(find.text(english.auth_loginButton), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('validates the form before sending anything', (tester) async {
    await pumpLogin(tester);

    await tester.tap(find.text(l.auth_loginButton));
    await tester.pumpAndSettle();

    expect(find.text(l.auth_validationEmailRequired), findsOneWidget);
    expect(find.text(l.auth_validationPasswordRequired), findsOneWidget);
    expect(harness.auth.signInEmails, isEmpty);

    await unmountApp(tester);
  });

  testWidgets('rejects something that is not an email address', (tester) async {
    await pumpLogin(tester);

    await submitLogin(tester, email: 'not-an-email');

    expect(find.text(l.auth_validationEmailInvalid), findsOneWidget);
    expect(harness.auth.signInEmails, isEmpty);

    await unmountApp(tester);
  });

  testWidgets('wrong credentials are reported in their own words', (
    tester,
  ) async {
    harness.auth.signInError = const AuthFailure(
      AuthFailureKind.invalidCredentials,
    );
    await pumpLogin(tester);

    await submitLogin(tester, password: 'wrong-one');

    expect(harness.auth.signInPasswords, ['wrong-one']);
    expect(find.text(l.auth_errorInvalidCredentials), findsOneWidget);
    // The screen stays put so the user can correct the password.
    expect(find.byType(LoginScreen), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('an unconfirmed email is told apart from a wrong password', (
    tester,
  ) async {
    harness.auth.signInError = const AuthFailure(
      AuthFailureKind.emailNotConfirmed,
    );
    await pumpLogin(tester);

    await submitLogin(tester);

    expect(find.text(l.auth_errorEmailNotConfirmed), findsOneWidget);
    expect(find.text(l.auth_errorInvalidCredentials), findsNothing);

    await unmountApp(tester);
  });

  testWidgets('a network failure says so and keeps the form for a retry', (
    tester,
  ) async {
    harness.auth.signInError = const AuthFailure(AuthFailureKind.network);
    await pumpLogin(tester);

    await submitLogin(tester);

    expect(find.text(l.auth_errorNetwork), findsOneWidget);

    // Retry: the second attempt succeeds and clears the message.
    harness.auth.signInError = null;
    await tester.tap(find.text(l.auth_loginButton));
    await tester.pumpAndSettle();

    expect(find.text(l.auth_errorNetwork), findsNothing);

    await unmountApp(tester);
  });

  testWidgets('a successful sign-in remembers the account locally', (
    tester,
  ) async {
    await pumpLogin(tester);

    await submitLogin(tester);

    final local = LocalAuthService(harness.prefs);
    expect(local.cachedUserId, 'user-1');
    expect(local.cachedEmail, 'counsel@example.com');
    expect(local.gateSatisfied, isTrue);

    await unmountApp(tester);
  });

  testWidgets('the Google button signs in and a dismissal is not an error', (
    tester,
  ) async {
    harness.auth.googleError = const AuthFailure(AuthFailureKind.cancelled);
    await pumpLogin(tester);

    await tester.tap(find.text(l.auth_googleLogin));
    await tester.pumpAndSettle();

    expect(harness.auth.googleCalls, 1);
    // A dismissed sheet leaves no red banner behind.
    expect(
      tester
          .widgetList<AuthErrorBanner>(find.byType(AuthErrorBanner))
          .every((banner) => banner.text == null),
      isTrue,
    );

    harness.auth.googleError = null;
    await tester.tap(find.text(l.auth_googleLogin));
    await tester.pumpAndSettle();

    expect(
      LocalAuthService(harness.prefs).cachedUserId,
      'google-1',
    );

    await unmountApp(tester);
  });

  testWidgets('the password toggle switches between hidden and shown', (
    tester,
  ) async {
    await pumpLogin(tester);

    // The field's own state lives in the EditableText it builds.
    bool obscured() =>
        tester.widget<EditableText>(find.byType(EditableText).last).obscureText;

    expect(obscured(), isTrue);

    await tester.tap(find.byIcon(Icons.visibility_off_outlined));
    await tester.pumpAndSettle();

    expect(obscured(), isFalse);

    await unmountApp(tester);
  });

  testWidgets('a pending invite code from an interrupted sign-up is finished', (
    tester,
  ) async {
    // The project had e-mail confirmation on, so the code could not be redeemed
    // at sign-up; the next sign-in redeems it.
    harness = AuthTestHarness(
      preferences: <String, Object>{pendingInviteCodeKey: 'abcde12345'},
    );
    await pumpLogin(tester);

    await submitLogin(tester);

    expect(harness.firm.redeemedCodes, ['abcde12345']);
    expect(pendingInviteCode(harness.prefs), isNull);

    await unmountApp(tester);
  });

  testWidgets('a failed pending redemption keeps the code and says why', (
    tester,
  ) async {
    harness = AuthTestHarness(
      preferences: <String, Object>{pendingInviteCodeKey: 'abcde12345'},
    );
    harness.firm.redeemError = const FirmFailure(FirmFailureKind.invalidInviteCode);
    await pumpLogin(tester);

    await submitLogin(tester);

    // The sign-in itself worked, and the code is still there to retry.
    expect(LocalAuthService(harness.prefs).cachedUserId, 'user-1');
    expect(pendingInviteCode(harness.prefs), 'abcde12345');
    expect(find.text(l.auth_errorInvalidCode), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('the recovery action sits under the password box, as plain bold text', (
    tester,
  ) async {
    await pumpLogin(tester);

    // Under the field, not beside the Password label.
    final field = tester.getRect(find.byType(TextFormField).last);
    final forgot = tester.getRect(find.text(l.auth_forgotPassword));
    expect(forgot.top, greaterThanOrEqualTo(field.bottom));

    final style = tester.widget<Text>(find.text(l.auth_forgotPassword)).style;
    expect(style?.fontWeight, FontWeight.w600);
    // No underline and no filled background: the theme paints every TextButton
    // black unless the link overrides it.
    expect(style?.decoration, isNot(TextDecoration.underline));
    expect(forgotButtonStyle(tester, l.auth_forgotPassword)?.backgroundColor
        ?.resolve(<WidgetState>{}), Colors.transparent);

    await unmountApp(tester);
  });

  testWidgets('the switch line is plain bold underlined text, not a black button', (
    tester,
  ) async {
    await pumpLogin(tester);

    final style = tester.widget<Text>(find.text(l.auth_signUpLink)).style;
    expect(style?.decoration, TextDecoration.underline);
    expect(style?.fontWeight, FontWeight.w600);
    expect(
      forgotButtonStyle(tester, l.auth_signUpLink)?.backgroundColor?.resolve(
        <WidgetState>{},
      ),
      Colors.transparent,
    );

    await unmountApp(tester);
  });
}

/// The style of the [TextButton] wrapping [label].
ButtonStyle? forgotButtonStyle(WidgetTester tester, String label) => tester
    .widget<TextButton>(
      find.ancestor(
        of: find.text(label),
        matching: find.byType(TextButton),
      ),
    )
    .style;
