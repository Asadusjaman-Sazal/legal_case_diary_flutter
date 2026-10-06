/// Tests for `resolveRouteRedirect` — the router's sign-in guard.
///
/// The guard is pure precisely so it can be pinned here without building the
/// whole router. The rule these tests defend is the one the Sign-Up screen
/// depends on: a device that has not signed in is sent away from the diary, but
/// the two legal documents stay readable, because sign-up links to them before
/// there is an account.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/core/router/app_router.dart';

void main() {
  /// Calls the resolver with the two booleans every test varies.
  String? resolve({
    required bool requiresSignIn,
    required bool signedIn,
    bool passwordRecoveryPending = false,
    String location = AppRoutes.dailyCauseList,
    String landingRoute = AppRoutes.dailyCauseList,
  }) => resolveRouteRedirect(
    requiresSignIn: requiresSignIn,
    signedIn: signedIn,
    passwordRecoveryPending: passwordRecoveryPending,
    landingRoute: landingRoute,
    location: location,
  );

  group('the sign-in gate', () {
    test('sends a not-signed-in visitor away from a shell screen', () {
      expect(
        resolve(requiresSignIn: true, signedIn: false, location: AppRoutes.allCases),
        AppRoutes.login,
      );
    });

    test('leaves the auth screens reachable before signing in', () {
      for (final route in <String>[
        AppRoutes.login,
        AppRoutes.signup,
        AppRoutes.forgotPassword,
      ]) {
        expect(
          resolve(requiresSignIn: true, signedIn: false, location: route),
          isNull,
          reason: '$route is where the not-signed-in user must be able to go',
        );
      }
    });

    test('lets the legal documents through before signing in', () {
      // The Sign-Up card links to both, so both must render for a visitor who
      // has no account yet — the same screens Settings > About opens.
      expect(
        resolve(
          requiresSignIn: true,
          signedIn: false,
          location: AppRoutes.settingsTermsOfService,
        ),
        isNull,
      );
      expect(
        resolve(
          requiresSignIn: true,
          signedIn: false,
          location: AppRoutes.settingsPrivacyPolicy,
        ),
        isNull,
      );
    });

    test('does not gate anything once the gate is not required', () {
      expect(
        resolve(
          requiresSignIn: false,
          signedIn: false,
          location: AppRoutes.settingsAbout,
        ),
        isNull,
      );
    });
  });

  group('password recovery', () {
    test('holds the user on the reset screen from anywhere else', () {
      expect(
        resolve(
          requiresSignIn: false,
          signedIn: true,
          passwordRecoveryPending: true,
          location: AppRoutes.dailyCauseList,
        ),
        AppRoutes.forgotPassword,
      );
    });

    test('leaves every auth screen alone while recovery is pending', () {
      for (final route in <String>[
        AppRoutes.login,
        AppRoutes.signup,
        AppRoutes.forgotPassword,
      ]) {
        expect(
          resolve(
            requiresSignIn: false,
            signedIn: true,
            passwordRecoveryPending: true,
            location: route,
          ),
          isNull,
        );
      }
    });
  });

  group('a signed-in user', () {
    test('is sent off the auth screens to their landing page', () {
      expect(
        resolve(
          requiresSignIn: false,
          signedIn: true,
          location: AppRoutes.signup,
          landingRoute: AppRoutes.allCases,
        ),
        AppRoutes.allCases,
      );
    });

    test('stays wherever else they navigated', () {
      expect(
        resolve(
          requiresSignIn: false,
          signedIn: true,
          location: AppRoutes.settingsTermsOfService,
        ),
        isNull,
      );
    });
  });
}
