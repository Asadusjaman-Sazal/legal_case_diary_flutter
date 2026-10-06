/// End-to-end check of the router's sign-in guard for the legal documents.
///
/// `app_router_redirect_test.dart` pins the pure rules; this file proves the
/// real router is wired to them: on a brand-new install (nothing on the device,
/// so the gate demands sign-in) a visitor can still open the Terms of Service
/// and the Privacy Policy, and sees the very screen Settings > About shows.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:legal_case_diary/core/router/app_router.dart';
import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/theme/app_theme.dart';
import 'package:legal_case_diary/features/auth/presentation/login_screen.dart';
import 'package:legal_case_diary/features/auth/presentation/signup_screen.dart';
import 'package:legal_case_diary/features/settings/presentation/legal/legal_document_screen.dart';

import '../features/auth_test_support.dart';

void main() {
  late AuthTestHarness harness;

  setUp(() => harness = AuthTestHarness());
  tearDown(() async {
    await harness.tearDown();
    await harness.auth.dispose();
  });

  /// Builds the app's real router over the harness and pumps it.
  Future<GoRouter> pumpRealRouter(WidgetTester tester) async {
    final overrides = await harness.setUp();
    final container = ProviderContainer(overrides: overrides);
    addTearDown(container.dispose);
    final router = await container.read(appRouterProvider.future);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.lightTheme(const Locale('en')),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('a brand-new install opens Login, not the diary', (tester) async {
    await pumpRealRouter(tester);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('the Terms of Service open before signing in', (tester) async {
    final router = await pumpRealRouter(tester);

    router.go(AppRoutes.settingsTermsOfService);
    await tester.pumpAndSettle();

    expect(find.byType(LegalDocumentScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('the Privacy Policy opens before signing in', (tester) async {
    final router = await pumpRealRouter(tester);

    router.go(AppRoutes.settingsPrivacyPolicy);
    await tester.pumpAndSettle();

    expect(find.byType(LegalDocumentScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  /// Pumps a fixed number of frames instead of `pumpAndSettle`.
  ///
  /// The legal document shows a spinner until its bundled asset loads, and that
  /// is real asynchronous I/O which never completes under the widget tester's
  /// fake clock (see `legal_document_screen_test.dart`), so a settle there times
  /// out. Bounded pumps drive the route transition without waiting on the asset.
  Future<void> pumpFrames(WidgetTester tester, [int frames = 8]) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('the back button returns from a document to Sign Up', (
    tester,
  ) async {
    final router = await pumpRealRouter(tester);

    router.go(AppRoutes.signup);
    await tester.pumpAndSettle();
    expect(find.byType(SignupScreen), findsOneWidget);

    router.push(AppRoutes.settingsTermsOfService);
    await pumpFrames(tester);
    expect(find.byType(LegalDocumentScreen), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await pumpFrames(tester, 16);

    expect(find.byType(SignupScreen), findsOneWidget);
    expect(find.byType(LegalDocumentScreen), findsNothing);
  });
}
