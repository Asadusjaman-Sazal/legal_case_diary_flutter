/// Task 17 Phase 2 — the Sign-Up screen and firm onboarding.
///
/// Built to `mockup_html_screens/settings_onlineSync_signup`: the card the
/// mockup draws, plus the two states the mockup could not show — the Firm /
/// Individual choice with its Invite Code field, and the Check Your Email
/// screen when the project wants the address confirmed first. These tests pin
/// both paths, the validation that runs before anything is sent, and the rule
/// the Addendum cares about most: **a failed code never loses the code**.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/core/constants/app_colors.dart';
import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/providers/contact_providers.dart';
import 'package:legal_case_diary/core/services/contact_launcher.dart';
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
  ///
  /// [extra] appends the seams a particular case needs — the mail-app launcher,
  /// for instance, which is the only way to see which URI Open Mail would open.
  Future<void> pumpSignup(
    WidgetTester tester, {
    List<Override> extra = const <Override>[],
  }) async {
    final overrides = await harness.setUp(extra: extra);
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

  /// Signs up and lands on the Check Your Email state.
  Future<void> reachCheckEmailState(WidgetTester tester) async {
    harness.auth.signUpOutcome = const SignUpConfirmationRequired(
      'jane@example.com',
    );
    await chooseJoinFirm(tester);
    await fillForm(tester, inviteCode: 'abcde12345');
    await tapVisible(tester, find.text(l.auth_signUpButton));
  }

  /// The user leaves for the mail app and comes back to this screen.
  ///
  /// A return is a lifecycle event, not a navigation one — which is exactly the
  /// moment the confirmation check hangs off.
  Future<void> leaveAndReturn(WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
  }

  /// The colour actually painted behind [field], sampled at its centre.
  ///
  /// The decoration's `fillColor` is what the painter is *told* to use; this
  /// reads what came out of it, so a theme default or an enclosing Material that
  /// painted over the field would fail here where the property check cannot.
  Future<Color> paintedFillBehind(WidgetTester tester, Finder field) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.ancestor(of: field, matching: find.byType(RepaintBoundary)).first,
    );
    final centre = boundary.globalToLocal(tester.getCenter(field));
    late final Color colour;
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final bytes = data!;
      final offset = (centre.dy.round() * image.width + centre.dx.round()) * 4;
      colour = Color.fromARGB(
        bytes.getUint8(offset + 3),
        bytes.getUint8(offset),
        bytes.getUint8(offset + 1),
        bytes.getUint8(offset + 2),
      );
      image.dispose();
    });
    return colour;
  }

  /// The darkest pixel painted inside [finder]'s own box, read off the frame.
  ///
  /// One sample cannot tell an artwork from a blank box: this mark's centre is
  /// white by design. Scanning the box for its darkest pixel is what shows ink
  /// is really painted where the placeholder used to sit.
  Future<Color> darkestPaintedInside(WidgetTester tester, Finder finder) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.ancestor(of: finder, matching: find.byType(RepaintBoundary)).first,
    );
    final rect = Rect.fromPoints(
      boundary.globalToLocal(tester.getTopLeft(finder)),
      boundary.globalToLocal(tester.getBottomRight(finder)),
    );
    late final Color darkest;
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final bytes = data!;
      var best = 1.0;
      var colour = const Color(0xFFFFFFFF);
      for (var y = rect.top.ceil(); y < rect.bottom.floor(); y++) {
        for (var x = rect.left.ceil(); x < rect.right.floor(); x++) {
          final offset = (y * image.width + x) * 4;
          final pixel = Color.fromARGB(
            bytes.getUint8(offset + 3),
            bytes.getUint8(offset),
            bytes.getUint8(offset + 1),
            bytes.getUint8(offset + 2),
          );
          if (pixel.computeLuminance() < best) {
            best = pixel.computeLuminance();
            colour = pixel;
          }
        }
      }
      darkest = colour;
      image.dispose();
    });
    return darkest;
  }

  /// The Confirm Password field's background, read off the [TextField] the
  /// [TextFormField] builds (`TextFormField` itself keeps no public decoration),
  /// which is the decoration with the theme's defaults already merged — so the
  /// neutral state reads as the app's pale field fill, exactly as it is drawn.
  Color? confirmFill(WidgetTester tester) => tester
      .widget<TextField>(
        find.descendant(
          of: find.byType(TextFormField).at(4),
          matching: find.byType(TextField),
        ),
      )
      .decoration
      ?.fillColor;

  /// The text a form field holds, by position in the form.
  String fieldText(WidgetTester tester, int index) =>
      tester
          .widget<TextFormField>(find.byType(TextFormField).at(index))
          .controller
          ?.text ??
      '';

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

  testWidgets('the header shows the bundled app logo, not the placeholder', (
    tester,
  ) async {
    await pumpSignup(tester);

    // The placeholder gavel the header used to draw is gone...
    expect(find.byIcon(Icons.gavel), findsNothing);

    final logo = find.byWidgetPredicate(
      (widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName ==
              'assets/icons/app_logo.png',
    );
    // ...replaced by the bundled logo, in the gavel's own 28 x 28 footprint.
    expect(logo, findsOneWidget);
    expect(tester.getSize(logo), const Size(28, 28));

    // The asset is really bundled (declared under `assets:` in pubspec.yaml),
    // so the image loads instead of falling back to the gavel.
    final bytes = await rootBundle.load('assets/icons/app_logo.png');
    expect(bytes.lengthInBytes, greaterThan(0));

    // And the artwork really reaches the frame: the mark's box holds its navy
    // ink, which a blank or unloaded box could not.
    await tester.runAsync(
      () => precacheImage(
        const AssetImage('assets/icons/app_logo.png'),
        tester.element(find.byType(SignupScreen)),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      (await darkestPaintedInside(tester, logo)).computeLuminance(),
      lessThan(0.2),
      reason: 'the mark itself must be painted, not just placed in the tree',
    );

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

  testWidgets('the Confirm Password box tints as it is typed into', (
    tester,
  ) async {
    await pumpSignup(tester);

    // Empty: the theme's own pale field fill, so an untouched form never looks
    // like a mistake. (`TextFormField` merges the theme's defaults in, so the
    // neutral state reads as that fill rather than as null.)
    expect(confirmFill(tester), AppColors.surfaceVariant);

    // One character in, differing from the (still empty) password: light red,
    // which is the answer the user asked for on the spot.
    await tester.enterText(find.byType(TextFormField).at(4), 's');
    await tester.pump();
    expect(confirmFill(tester), AppColors.errorContainer);

    // Matching turns it green.
    await tester.enterText(find.byType(TextFormField).at(3), 'secret123');
    await tester.enterText(find.byType(TextFormField).at(4), 'secret123');
    await tester.pump();
    expect(confirmFill(tester), AppColors.successContainer);

    // Editing the password afterwards takes it back to red, because the tint is
    // the pair's state and not a one-time stamp.
    await tester.enterText(find.byType(TextFormField).at(3), 'secret124');
    await tester.pump();
    expect(confirmFill(tester), AppColors.errorContainer);

    // Cleared, it goes back to the theme's neutral fill rather than staying red.
    await tester.enterText(find.byType(TextFormField).at(4), '');
    await tester.pump();
    expect(confirmFill(tester), AppColors.surfaceVariant);

    await unmountApp(tester);
  });

  testWidgets('the Confirm Password box is really painted that colour', (
    tester,
  ) async {
    await pumpSignup(tester);
    await tester.enterText(find.byType(TextFormField).at(4), 's');
    await tester.pump();
    final field = find.byType(TextFormField).at(4);

    // The centre of the field is fill, not glyph: a single character sits at the
    // left edge. Light red on the spot, green once the two agree — read off the
    // frame rather than off the widget, so a theme that painted over the field
    // could not pass this.
    expect(await paintedFillBehind(tester, field), AppColors.errorContainer);

    await tester.enterText(find.byType(TextFormField).at(3), 's');
    await tester.pump();
    expect(await paintedFillBehind(tester, field), AppColors.successContainer);

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
    // The Bar Association rides along as sign-up metadata, which is the trigger's
    // only chance to write it for a sign-up that still has to confirm its
    // address.
    expect(harness.auth.signUpBarAssociations, ['Dhaka Bar']);

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
    harness.firm.redeemError = const FirmFailure(FirmFailureKind.invalidInviteCode);
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
    harness.firm.redeemError = const FirmFailure(FirmFailureKind.tooManyAttempts);
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

  testWidgets('the Terms of Service link opens the document the app ships', (
    tester,
  ) async {
    await pumpSignup(tester);

    await tapVisible(tester, find.text(l.auth_termsOfService));
    expect(find.text(authTermsMarker), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('the Privacy Policy link opens the document the app ships', (
    tester,
  ) async {
    await pumpSignup(tester);

    await tapVisible(tester, find.text(l.auth_privacyPolicy));
    expect(find.text(authPrivacyMarker), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('Open Mail asks for the mail app, not a compose window', (
    tester,
  ) async {
    final launcher = _RecordingLauncher();
    await pumpSignup(
      tester,
      extra: [contactLauncherProvider.overrideWithValue(launcher)],
    );
    await reachCheckEmailState(tester);

    await tapVisible(tester, find.text(l.auth_openMail));

    // The seam is asked for the mail app itself, and no URI at all is opened:
    // a `mailto:` is a *compose* request (RFC 6068), so a screen that opened one
    // drops the user into an empty draft instead of their mailbox.
    expect(launcher.mailAppCalls, 1);
    expect(launcher.opened, isEmpty);

    await unmountApp(tester);
  });

  testWidgets('a mail app that cannot be opened says so', (tester) async {
    final launcher = _RecordingLauncher()..answers = false;
    await pumpSignup(
      tester,
      extra: [contactLauncherProvider.overrideWithValue(launcher)],
    );
    await reachCheckEmailState(tester);

    await tapVisible(tester, find.text(l.auth_openMail));

    expect(find.text(l.auth_unableToOpenMail), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('coming back after confirming turns the card green', (
    tester,
  ) async {
    harness.auth.emailConfirmed = true;
    await pumpSignup(tester);
    await reachCheckEmailState(tester);
    expect(pendingConfirmation(harness.prefs), 'jane@example.com');

    await leaveAndReturn(tester);

    // The check uses the credentials the sign-up screen is still holding, and
    // signs nothing in: the session belongs to the user, not to this screen.
    expect(harness.auth.confirmationChecks, ['jane@example.com']);
    expect(harness.auth.confirmationCheckPasswords, ['secret123']);
    expect(harness.auth.identity, isNull);
    expect(find.text(l.auth_emailConfirmedTitle), findsOneWidget);
    expect(
      find.text(l.auth_emailConfirmedMessage('jane@example.com')),
      findsOneWidget,
    );
    // One action only, and none of the waiting screen's three, is offered. It
    // is the label the user asked for: pressing it lands them in the app, so it
    // does not offer Login.
    expect(find.text(l.auth_useTheApp), findsOneWidget);
    expect(find.text(l.auth_backToLogin), findsNothing);
    expect(find.text(l.auth_openMail), findsNothing);
    expect(find.text(l.auth_resendEmail), findsNothing);
    expect(find.text(l.auth_changeEmail), findsNothing);
    // The wait is spent, so nothing reopens this screen.
    expect(pendingConfirmation(harness.prefs), isNull);

    await unmountApp(tester);
  });

  testWidgets('Use The App signs in and leaves for the diary', (tester) async {
    harness.auth.emailConfirmed = true;
    await pumpSignup(tester);
    await reachCheckEmailState(tester);
    await leaveAndReturn(tester);
    expect(find.text(l.auth_useTheApp), findsOneWidget);

    await tapVisible(tester, find.text(l.auth_useTheApp));

    // A real sign-in with the credentials the form was still holding — not a
    // navigation to Login — which is what makes the label honest.
    expect(harness.auth.signInEmails, ['jane@example.com']);
    expect(harness.auth.signInPasswords, ['secret123']);
    expect(harness.auth.identity?.email, 'jane@example.com');
    // Parity with Login: the join-a-firm sign-up this card came from left its
    // code pending, and the first sign-in with a session redeems it.
    expect(harness.firm.redeemedCodes, ['abcde12345']);
    expect(pendingInviteCode(harness.prefs), isNull);
    expect(pendingConfirmation(harness.prefs), isNull);
    expect(find.text(authLandingMarker), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('a refused sign-in keeps the card and says so', (tester) async {
    harness.auth.emailConfirmed = true;
    harness.auth.signInError = const AuthFailure(AuthFailureKind.network);
    await pumpSignup(tester);
    await reachCheckEmailState(tester);
    await leaveAndReturn(tester);

    await tapVisible(tester, find.text(l.auth_useTheApp));

    // Nothing was adopted, the card is still the screen, and the failure was
    // said rather than left silent behind a button that looks like it did
    // nothing.
    expect(harness.auth.identity, isNull);
    expect(find.text(l.auth_emailConfirmedTitle), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('coming back before confirming leaves the screen as it was', (
    tester,
  ) async {
    await pumpSignup(tester);
    await reachCheckEmailState(tester);

    await leaveAndReturn(tester);

    expect(harness.auth.confirmationChecks, ['jane@example.com']);
    expect(find.text(l.auth_checkEmailTitle), findsOneWidget);
    expect(find.text(l.auth_openMail), findsOneWidget);
    expect(find.text(l.auth_resendEmail), findsOneWidget);
    expect(find.text(l.auth_changeEmail), findsOneWidget);
    expect(find.text(l.auth_emailConfirmedTitle), findsNothing);
    // Still waiting, so a restart must still find it.
    expect(pendingConfirmation(harness.prefs), 'jane@example.com');

    await unmountApp(tester);
  });

  testWidgets('a restart comes back to the waiting screen, not the form', (
    tester,
  ) async {
    harness = AuthTestHarness(
      preferences: <String, Object>{
        pendingConfirmationEmailKey: 'jane@example.com',
        pendingConfirmationAtKey: DateTime.now().millisecondsSinceEpoch,
      },
    );
    await pumpSignup(tester);

    expect(find.text(l.auth_checkEmailTitle), findsOneWidget);
    expect(
      find.text(l.auth_checkEmailMessage('jane@example.com')),
      findsOneWidget,
    );
    expect(find.text(l.auth_openMail), findsOneWidget);
    expect(find.text(l.auth_signUpButton), findsNothing);

    // The password was never stored, so there is nothing to check with — the
    // screen is restored, and the other three actions still work.
    await leaveAndReturn(tester);
    expect(harness.auth.confirmationChecks, isEmpty);
    expect(find.text(l.auth_checkEmailTitle), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('Back To Login ends the wait', (tester) async {
    await pumpSignup(tester);
    await reachCheckEmailState(tester);

    await tapVisible(tester, find.text(l.auth_backToLogin));

    expect(pendingConfirmation(harness.prefs), isNull);
    expect(find.text('auth-route'), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('Resend Email asks the server again and says so', (tester) async {
    await pumpSignup(tester);
    await reachCheckEmailState(tester);

    await tapVisible(tester, find.text(l.auth_resendEmail));

    expect(harness.auth.resendEmails, ['jane@example.com']);
    expect(find.text(l.auth_resendSent), findsOneWidget);
    // Nothing about the screen changed: it is still waiting.
    expect(find.text(l.auth_checkEmailTitle), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('a rate-limited resend keeps the screen and says why', (
    tester,
  ) async {
    harness.auth.resendError = const AuthFailure(AuthFailureKind.rateLimited);
    await pumpSignup(tester);
    await reachCheckEmailState(tester);

    await tapVisible(tester, find.text(l.auth_resendEmail));

    expect(find.text(l.auth_errorRateLimited), findsOneWidget);
    expect(find.text(l.auth_checkEmailTitle), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('Change Email Address removes the sign-up and reopens the form', (
    tester,
  ) async {
    await pumpSignup(tester);
    await reachCheckEmailState(tester);

    await tapVisible(tester, find.text(l.auth_changeEmail));

    expect(harness.auth.discardedEmails, ['jane@example.com']);
    expect(pendingConfirmation(harness.prefs), isNull);
    expect(find.text(l.auth_checkEmailTitle), findsNothing);
    expect(find.text(l.auth_signUpButton), findsOneWidget);
    // Only the address was wrong, so only the address is cleared.
    expect(fieldText(tester, 0), 'Adv. Jane Doe');
    expect(fieldText(tester, 2), '');
    expect(fieldText(tester, 3), 'secret123');

    await unmountApp(tester);
  });

  testWidgets('an already-confirmed address refuses the change', (tester) async {
    harness.auth.discardOutcome = DiscardSignupOutcome.refusedConfirmed;
    await pumpSignup(tester);
    await reachCheckEmailState(tester);

    await tapVisible(tester, find.text(l.auth_changeEmail));

    expect(find.text(l.auth_changeEmailAlreadyConfirmed), findsOneWidget);
    expect(find.text(l.auth_checkEmailTitle), findsOneWidget);
    expect(find.text(l.auth_signUpButton), findsNothing);

    await unmountApp(tester);
  });

  testWidgets('after a restart the address change asks for the password', (
    tester,
  ) async {
    harness = AuthTestHarness(
      preferences: <String, Object>{
        pendingConfirmationEmailKey: 'jane@example.com',
        pendingConfirmationAtKey: DateTime.now().millisecondsSinceEpoch,
      },
    );
    await pumpSignup(tester);

    await tapVisible(tester, find.text(l.auth_changeEmail));

    // The password is the server's proof that the caller owns the account, and
    // a restored screen no longer holds one.
    expect(find.text(l.auth_changeEmailPasswordTitle), findsOneWidget);
    expect(harness.auth.discardedEmails, isEmpty);

    await tester.enterText(find.byType(TextField).last, 'secret123');
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.sharedActions_save));
    await tester.pumpAndSettle();

    expect(harness.auth.discardedEmails, ['jane@example.com']);
    expect(pendingConfirmation(harness.prefs), isNull);
    expect(find.text(l.auth_signUpButton), findsOneWidget);

    await unmountApp(tester);
  });
}

/// A [ContactLauncher] that records what every tap asked for and opens nothing.
class _RecordingLauncher implements ContactLauncher {
  /// Every URI the screen asked to open, in order.
  final List<Uri> opened = <Uri>[];

  /// How many times the screen asked for the mail app itself.
  int mailAppCalls = 0;

  /// What [open] and [openMailApp] answer; false stands in for a device with no
  /// mail app.
  bool answers = true;

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return answers;
  }

  @override
  Future<bool> openMailApp() async {
    mailAppCalls++;
    return answers;
  }
}
