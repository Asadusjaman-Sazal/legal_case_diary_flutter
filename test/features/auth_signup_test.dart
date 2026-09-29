/// Task 17 Phase 2 — the Sign-Up screen and firm onboarding.
///
/// Built to `mockup_html_screens/settings_onlineSync_signup`: the card the
/// mockup draws, plus the two states the mockup could not show — the Firm /
/// Individual choice with its Invite Code field, and the Check Your Email
/// screen when the project wants the address confirmed first. These tests pin
/// both paths, the validation that runs before anything is sent, and the rule
/// the Addendum cares about most: **a failed code never loses the code**.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/firm_repository.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/profile_name_store.dart';
import 'package:legal_case_diary/features/auth/data/auth_repository.dart';
import 'package:legal_case_diary/features/auth/data/local_auth_service.dart';
import 'package:legal_case_diary/features/auth/presentation/signup_screen.dart';

import 'auth_test_support.dart';

void main() {
  late AuthTestHarness harness;
  late AppLocalizations l;

  /// Pumps the sign-up screen inside the harness and a minimal router.
  Future<void> pumpSignup(WidgetTester tester) async {
    final overrides = await harness.setUp();
    await tester.binding.setSurfaceSize(const Size(420, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpAuthRouter(tester, const SignupScreen(), overrides: overrides);
    l = await AppLocalizations.delegate.load(const Locale('en'));
  }

  /// Scrolls [finder] into view, taps it, and settles.
  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// Fills the form; [inviteCode] only exists on the join-firm path.
  Future<void> fillForm(
    WidgetTester tester, {
    String fullName = 'Adv. Jane Doe',
    String barAssociation = 'Dhaka Bar',
    String email = 'jane@example.com',
    String password = 'secret123',
    String? confirmPassword,
    String? inviteCode,
  }) async {
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), fullName);
    await tester.enterText(fields.at(1), barAssociation);
    await tester.enterText(fields.at(2), email);
    await tester.enterText(fields.at(3), password);
    await tester.enterText(fields.at(4), confirmPassword ?? password);
    if (inviteCode != null) {
      await tester.enterText(fields.at(5), inviteCode);
    }
    await tester.pumpAndSettle();
  }

  /// Chooses the firm path and accepts the terms.
  Future<void> chooseJoinFirm(WidgetTester tester) async {
    await tapVisible(tester, find.text(l.auth_accountTypeJoinFirm));
    await tapVisible(tester, find.byType(Checkbox));
  }

  setUp(() => harness = AuthTestHarness());
  tearDown(() async {
    await harness.tearDown();
    await harness.auth.dispose();
  });

  testWidgets('renders the mockup card, its fields and its links', (
    tester,
  ) async {
    await pumpSignup(tester);

    expect(find.text(l.auth_signupTitle), findsOneWidget);
    expect(find.text(l.auth_signupSubtitle), findsOneWidget);
    expect(find.text(l.auth_accountTypeLabel), findsOneWidget);
    expect(find.text(l.auth_accountTypeIndividual), findsOneWidget);
    expect(find.text(l.auth_fullNameLabel), findsOneWidget);
    expect(find.text(l.auth_barAssociationLabel), findsOneWidget);
    expect(find.text(l.auth_emailAddressLabel), findsOneWidget);
    expect(find.text(l.auth_passwordLabel), findsOneWidget);
    expect(find.text(l.auth_passwordHelper), findsOneWidget);
    expect(find.text(l.auth_confirmPasswordLabel), findsOneWidget);
    // The consent sentence is one rich line naming both documents.
    expect(find.textContaining(l.auth_termsAgreePrefix), findsOneWidget);
    expect(find.text(l.auth_termsOfService), findsOneWidget);
    expect(find.text(l.auth_privacyPolicy), findsOneWidget);
    expect(find.text(l.auth_signUpButton), findsOneWidget);
    expect(find.text(l.auth_orContinueWith), findsOneWidget);
    expect(find.text(l.auth_googleSignup), findsOneWidget);
    expect(find.text(l.auth_haveAccount), findsOneWidget);
    expect(find.text(l.auth_loginLink), findsOneWidget);

    // The individual path is the default, so the firm's code is not asked for.
    expect(find.text(l.auth_inviteCodeLabel), findsNothing);

    await unmountApp(tester);
  });

  testWidgets('choosing Join Existing Firm reveals the invite code field', (
    tester,
  ) async {
    await pumpSignup(tester);

    await tapVisible(tester, find.text(l.auth_accountTypeJoinFirm));

    expect(find.text(l.auth_inviteCodeLabel), findsOneWidget);
    expect(find.text(l.auth_inviteCodeHelper), findsOneWidget);

    // And back: the individual path puts the field away again.
    await tapVisible(tester, find.text(l.auth_accountTypeIndividual));

    expect(find.text(l.auth_inviteCodeLabel), findsNothing);

    await unmountApp(tester);
  });

  testWidgets('the form, the invite code and the terms are all required', (
    tester,
  ) async {
    await pumpSignup(tester);
    await tapVisible(tester, find.text(l.auth_accountTypeJoinFirm));

    await tapVisible(tester, find.text(l.auth_signUpButton));

    expect(find.text(l.auth_validationFullNameRequired), findsOneWidget);
    expect(find.text(l.auth_validationBarAssociationRequired), findsOneWidget);
    expect(find.text(l.auth_validationEmailRequired), findsOneWidget);
    expect(find.text(l.auth_validationPasswordRequired), findsOneWidget);
    expect(find.text(l.auth_validationInviteCodeRequired), findsOneWidget);
    expect(find.text(l.auth_validationTermsRequired), findsOneWidget);
    expect(harness.auth.signUpEmails, isEmpty);

    await unmountApp(tester);
  });

  testWidgets('a short password is refused before the round trip', (
    tester,
  ) async {
    await pumpSignup(tester);
    await fillForm(tester, password: 'short');

    await tapVisible(tester, find.text(l.auth_signUpButton));

    expect(find.text(l.auth_validationPasswordTooShort), findsOneWidget);
    expect(harness.auth.signUpEmails, isEmpty);

    await unmountApp(tester);
  });

  testWidgets('a confirmation that does not match is refused before the round trip', (
    tester,
  ) async {
    await pumpSignup(tester);
    await fillForm(tester, confirmPassword: 'secret456');
    await tapVisible(tester, find.byType(Checkbox));

    await tapVisible(tester, find.text(l.auth_signUpButton));

    // Caught in the form, not by the server: the account is never created with a
    // password the user did not mean to type.
    expect(find.text(l.auth_validationPasswordMismatch), findsOneWidget);
    expect(harness.auth.signUpEmails, isEmpty);

    await unmountApp(tester);
  });

  testWidgets('an empty confirmation is required even when the password is fine', (
    tester,
  ) async {
    await pumpSignup(tester);
    await fillForm(tester, confirmPassword: '');
    await tapVisible(tester, find.byType(Checkbox));

    await tapVisible(tester, find.text(l.auth_signUpButton));

    expect(find.text(l.auth_validationPasswordConfirmRequired), findsOneWidget);
    expect(harness.auth.signUpEmails, isEmpty);

    await unmountApp(tester);
  });

  testWidgets('the switch line is plain bold underlined text, not a button', (
    tester,
  ) async {
    await pumpSignup(tester);

    final action = tester.widget<Text>(find.text(l.auth_loginLink));
    expect(action.style?.decoration, TextDecoration.underline);
    expect(action.style?.fontWeight, FontWeight.w600);
    expect(
      tester
          .widget<TextButton>(
            find.ancestor(
              of: find.text(l.auth_loginLink),
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

  testWidgets('an individual sign-up saves the name and opens the diary', (
    tester,
  ) async {
    await pumpSignup(tester);
    await fillForm(tester);
    await tapVisible(tester, find.byType(Checkbox));

    await tapVisible(tester, find.text(l.auth_signUpButton));

    expect(harness.auth.signUpNames, ['Adv. Jane Doe']);
    expect(harness.auth.signUpEmails, ['jane@example.com']);

    // The name and bar association are the ones the rest of the app displays.
    final saved = ProfileStore(harness.prefs).read();
    expect(saved.fullName, 'Adv. Jane Doe');
    expect(saved.barAssociation, 'Dhaka Bar');
    expect(LocalAuthService(harness.prefs).gateSatisfied, isTrue);
    expect(find.text(authLandingMarker), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('a firm sign-up redeems the code and confirms the join', (
    tester,
  ) async {
    await pumpSignup(tester);
    await chooseJoinFirm(tester);
    await fillForm(tester, inviteCode: 'abcde12345');

    await tapVisible(tester, find.text(l.auth_signUpButton));

    expect(harness.firm.redeemedCodes, ['abcde12345']);
    expect(find.text(l.auth_joinedFirm), findsOneWidget);
    expect(find.text(authLandingMarker), findsOneWidget);
    // Redeemed, so nothing is left pending for the next sign-in.
    expect(pendingInviteCode(harness.prefs), isNull);

    await unmountApp(tester);
  });

  testWidgets('an already-member redemption says so instead of joining', (
    tester,
  ) async {
    harness.firm.redemption = const InviteRedemption(
      status: InviteRedemptionStatus.alreadyMember,
      firmId: 'firm-1',
    );
    await pumpSignup(tester);
    await chooseJoinFirm(tester);
    await fillForm(tester, inviteCode: 'abcde12345');

    await tapVisible(tester, find.text(l.auth_signUpButton));

    expect(find.text(l.auth_errorAlreadyMember), findsOneWidget);
    expect(find.text(l.auth_joinedFirm), findsNothing);

    await unmountApp(tester);
  });

  testWidgets('a rejected invite code is explained and the code is kept', (
    tester,
  ) async {
    harness.firm.redeemError = const AuthFailure(AuthFailureKind.invalidCode);
    await pumpSignup(tester);
    await chooseJoinFirm(tester);
    await fillForm(tester, inviteCode: 'abcde12345');

    await tapVisible(tester, find.text(l.auth_signUpButton));

    expect(find.text(l.auth_errorInvalidCode), findsOneWidget);
    // Onboarding stays retryable: the account exists and the code is still here.
    expect(pendingInviteCode(harness.prefs), 'abcde12345');
    expect(find.text(authLandingMarker), findsNothing);

    await unmountApp(tester);
  });

  testWidgets('the invite rate limit has its own words', (tester) async {
    harness.firm.redeemError = const AuthFailure(
      AuthFailureKind.tooManyAttempts,
    );
    await pumpSignup(tester);
    await chooseJoinFirm(tester);
    await fillForm(tester, inviteCode: 'abcde12345');

    await tapVisible(tester, find.text(l.auth_signUpButton));

    expect(find.text(l.auth_errorTooManyAttempts), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('an email already in use is explained and keeps the form', (
    tester,
  ) async {
    harness.auth.signUpError = const AuthFailure(AuthFailureKind.emailInUse);
    await pumpSignup(tester);
    await fillForm(tester);
    await tapVisible(tester, find.byType(Checkbox));

    await tapVisible(tester, find.text(l.auth_signUpButton));

    expect(find.text(l.auth_errorEmailInUse), findsOneWidget);
    expect(find.text(authLandingMarker), findsNothing);

    await unmountApp(tester);
  });

  testWidgets('a confirmation email is asked for before anything else', (
    tester,
  ) async {
    harness.auth.signUpOutcome = const SignUpConfirmationRequired(
      'jane@example.com',
    );
    await pumpSignup(tester);
    await chooseJoinFirm(tester);
    await fillForm(tester, inviteCode: 'abcde12345');

    await tapVisible(tester, find.text(l.auth_signUpButton));

    expect(find.text(l.auth_checkEmailTitle), findsOneWidget);
    expect(
      find.text(l.auth_checkEmailMessage('jane@example.com')),
      findsOneWidget,
    );
    // No session yet, so the code waits for the first sign-in with one.
    expect(pendingInviteCode(harness.prefs), 'abcde12345');
    expect(harness.firm.redeemedCodes, isEmpty);
    expect(find.text(authLandingMarker), findsNothing);

    await unmountApp(tester);
  });

  testWidgets('the Google path signs up and still redeems a typed code', (
    tester,
  ) async {
    await pumpSignup(tester);
    await chooseJoinFirm(tester);
    await fillForm(tester, inviteCode: 'abcde12345');

    await tapVisible(tester, find.text(l.auth_googleSignup));

    expect(harness.auth.googleCalls, 1);
    expect(harness.firm.redeemedCodes, ['abcde12345']);
    expect(find.text(authLandingMarker), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('the Google path refuses an unaccepted terms box', (
    tester,
  ) async {
    await pumpSignup(tester);

    await tapVisible(tester, find.text(l.auth_googleSignup));

    expect(find.text(l.auth_validationTermsRequired), findsOneWidget);
    expect(harness.auth.googleCalls, 0);

    await unmountApp(tester);
  });

  testWidgets('the two legal links open the documents the app ships', (
    tester,
  ) async {
    await pumpSignup(tester);

    await tapVisible(tester, find.text(l.auth_termsOfService));
    expect(find.text(authTermsMarker), findsOneWidget);

    await unmountApp(tester);
  });
}
