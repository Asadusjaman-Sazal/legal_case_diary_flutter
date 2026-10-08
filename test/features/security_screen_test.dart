/// Security screen — the new home of Change Password.
///
/// The row moved here from Manage Account; these tests pin that it arrived
/// intact (same wording, same destination) and that its destination is the
/// Settings presentation of the reset flow, not Login's auth route — the
/// regression the row originally guarded on Manage Account.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/router/app_router.dart';
import 'package:legal_case_diary/features/accounts_and_profile/presentation/security_screen.dart';
import 'package:legal_case_diary/features/auth/data/auth_repository.dart';
import 'package:legal_case_diary/features/auth/presentation/forgot_password_screen.dart';

import 'auth_test_support.dart';
import 'settings_test_support.dart';

void main() {
  late AuthTestHarness harness;
  late AppLocalizations l;

  setUp(() {
    harness = AuthTestHarness(
      auth: FakeAuthRepository(
        identity: const AuthIdentity(
          userId: 'user-1',
          email: 'advocate.asad@law.com',
        ),
      ),
    );
  });

  tearDown(() async {
    await harness.tearDown();
    await harness.auth.dispose();
  });

  /// Pumps the Security screen on a router.
  Future<void> pumpSecurity(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpSettingsRouter(
      tester,
      location: AppRoutes.settingsSecurity,
      overrides: await harness.setUp(),
      routes: [
        GoRoute(
          path: AppRoutes.settingsSecurity,
          builder: (_, _) => const SecurityScreen(),
        ),
        // The real screen, in the Settings presentation this row asks for:
        // asserting on it rather than on a marker is what pins "a Settings
        // sub-page, not the auth route".
        GoRoute(
          path: AppRoutes.settingsChangePassword,
          builder: (_, _) =>
              const ForgotPasswordScreen(asSettingsSubPage: true),
        ),
      ],
    );
    l = await AppLocalizations.delegate.load(const Locale('en'));
  }

  testWidgets('offers Change Password under the Security title', (tester) async {
    await pumpSecurity(tester);

    expect(find.text(l.settingsAccountProfile_security), findsWidgets);
    expect(find.text(l.settingsManageAccount_changePassword), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('Change Password opens the reset flow as a Settings sub-page', (
    tester,
  ) async {
    // Regression: this row pushed Login's `/forgot-password`, which is an auth
    // route — and the router sends a signed-in user away from every auth route,
    // so the tap landed on the default landing page instead of the screen.
    await pumpSecurity(tester);

    await tester.tap(find.text(l.settingsManageAccount_changePassword));
    await tester.pumpAndSettle();

    // The same screen Login's "Forgot Password?" shows...
    expect(find.text(l.auth_forgotTitle), findsOneWidget);
    expect(find.text(l.auth_sendCodeButton), findsOneWidget);
    expect(find.text(l.auth_emailLabel), findsOneWidget);
    // ...but as a Settings sub-page: the standard header with its back button.
    expect(find.byType(BackButton), findsWidgets);
    // And no way out to Login, where a signed-in user may not go.
    expect(find.text(l.auth_backToLogin), findsNothing);

    await unmountApp(tester);
  });
}
