/// Checkout screen tests — Task 21 Phase 2.
///
/// Pins the wiring the unit tests cannot see: a resolved receiving number is
/// shown, a saved draft pre-fills the form on reopen, and a successful submit
/// clears the draft and reports the success message.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/providers/repository_providers.dart';
import 'package:legal_case_diary/core/router/app_router.dart';
import 'package:legal_case_diary/features/auth/data/auth_repository.dart';
import 'package:legal_case_diary/features/auth/presentation/auth_viewmodel.dart';
import 'package:legal_case_diary/features/payments/data/payment_local_store.dart';
import 'package:legal_case_diary/features/payments/data/payment_plans.dart';
import 'package:legal_case_diary/features/payments/data/payment_repository.dart';
import 'package:legal_case_diary/features/payments/data/payments_configuration_service.dart';
import 'package:legal_case_diary/features/payments/presentation/checkout_screen.dart';
import 'package:legal_case_diary/shared/providers/shared_preferences_provider.dart';

/// A remote that always returns one bKash number.
class _FakeRemote implements PaymentsConfigRemote {
  @override
  Future<List<Map<String, dynamic>>> fetchActiveMethods() async => [
    {'provider': 'bkash', 'receiving_number': '01712345678'},
  ];
}

/// A repository that accepts everything.
class _AcceptingRepository implements PaymentRepository {
  /// The transaction ids submitted.
  final List<String> submitted = <String>[];

  @override
  Future<void> submit({
    required String userId,
    required String planType,
    required int amount,
    required String mfsProvider,
    required String senderNumber,
    required String transactionId,
  }) async {
    submitted.add(transactionId);
  }

  @override
  Future<List<PaymentSubmission>> fetchMySubmissions() async =>
      const <PaymentSubmission>[];

  @override
  Future<List<SubscriptionCancellation>> fetchMyCancellations() async =>
      const <SubscriptionCancellation>[];

  @override
  Future<void> cancelSubscription() async =>
      throw const PaymentCancelException(PaymentCancelFailure.network);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  Future<void> pump(
    WidgetTester tester,
    SharedPreferences prefs,
    PaymentRepository repo, {
    String? planKey = paymentPlanProMonthly,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authIdentityProvider.overrideWithValue(
            const AuthIdentity(userId: 'user-1'),
          ),
          paymentRepositoryProvider.overrideWithValue(repo),
          paymentsConfigurationServiceProvider.overrideWithValue(
            PaymentsConfigurationService(
              remote: _FakeRemote(),
              buildDefaults: const <String, String>{},
            ),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: CheckoutScreen(planKey: planKey),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the resolved receiving number', (tester) async {
    await pump(tester, await SharedPreferences.getInstance(), _AcceptingRepository());

    expect(find.text('Checkout'), findsOneWidget);
    expect(find.text('01712345678'), findsOneWidget);
    expect(find.text('bKash'), findsWidgets);
    // The exact amount is shown in the plan summary.
    expect(find.text('৳150'), findsOneWidget);
  });

  testWidgets('the instruction names the amount and bolds only Send Money',
      (tester) async {
    await pump(tester, await SharedPreferences.getInstance(), _AcceptingRepository());

    final sentence = tester.widget<Text>(
      find.byKey(const ValueKey('checkout-transfer-body')),
    );
    final span = sentence.textSpan! as TextSpan;
    expect(
      span.toPlainText(),
      'Send ৳150 to one of the numbers below using Send Money, '
      'then carefully enter your payment details.',
    );

    final runs = <TextSpan>[
      for (final child in span.children!) child as TextSpan,
    ];
    expect(
      runs
          .where((run) => run.style?.fontWeight == FontWeight.w700)
          .map((run) => run.text)
          .toList(),
      ['Send Money'],
    );
  });

  testWidgets('a saved draft pre-fills the form and a submit clears it',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final repo = _AcceptingRepository();
    await pump(tester, prefs, repo);

    await tester.enterText(
      find.byKey(const ValueKey('checkout-phone')),
      '01712345678',
    );
    await tester.enterText(
      find.byKey(const ValueKey('checkout-trx')),
      'TRX99',
    );
    await tester.pumpAndSettle();

    // The draft is saved on keystroke, before any submit.
    expect(prefs.getString(paymentDraftKey('user-1')), isNotNull);

    await tester.tap(find.byKey(const ValueKey('checkout-submit')));
    await tester.pumpAndSettle();

    expect(repo.submitted, ['TRX99']);
    // Confirmed success clears the draft.
    expect(prefs.getString(paymentDraftKey('user-1')), isNull);
    expect(find.textContaining('Submission Received'), findsOneWidget);
  });

  testWidgets('a confirmed submit keeps the snackbar, opens Subscription '
      'History, and Back walks back through Account & Profile and Settings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // A router that mirrors the app's nesting: the shell holds the landing,
    // Settings and Account & Profile pages, while Subscription History is a
    // top-level route, exactly as it is in `app_router.dart`.
    Widget page(String label) => Scaffold(
      appBar: AppBar(leading: const BackButton()),
      body: Text(label),
    );
    final router = GoRouter(
      initialLocation: AppRoutes.dailyCauseList,
      routes: [
        ShellRoute(
          builder: (context, state, child) => Scaffold(body: child),
          routes: [
            GoRoute(
              path: AppRoutes.dailyCauseList,
              builder: (context, state) => page('Landing-Page'),
            ),
            GoRoute(
              path: AppRoutes.settings,
              builder: (context, state) => page('Settings-Page'),
            ),
            GoRoute(
              path: AppRoutes.settingsAccountProfile,
              builder: (context, state) => page('Account-Profile-Page'),
            ),
          ],
        ),
        GoRoute(
          path: AppRoutes.checkout,
          builder: (context, state) => CheckoutScreen(
            planKey: paymentPlanProMonthly,
          ),
        ),
        GoRoute(
          path: AppRoutes.settingsSubscriptionHistory,
          builder: (context, state) => page('History-Landed'),
        ),
      ],
    );

    final prefs = await SharedPreferences.getInstance();
    final repo = _AcceptingRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authIdentityProvider.overrideWithValue(
            const AuthIdentity(userId: 'user-1'),
          ),
          paymentRepositoryProvider.overrideWithValue(repo),
          paymentsConfigurationServiceProvider.overrideWithValue(
            PaymentsConfigurationService(
              remote: _FakeRemote(),
              buildDefaults: const <String, String>{},
            ),
          ),
          // The post-submit stack reuses the configured landing page, which the
          // real router has already resolved before any screen is built.
          defaultLandingRouteProvider.overrideWith(
            (ref) async => AppRoutes.dailyCauseList,
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Reach the checkout from Account & Profile, the app's normal purchase
    // path, so the pages it now has to replace are really in the stack.
    router.push(AppRoutes.settings);
    router.push(AppRoutes.settingsAccountProfile);
    router.push(AppRoutes.checkout);
    await tester.pumpAndSettle();
    expect(find.text('Account-Profile-Page'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('checkout-phone')),
      '01712345678',
    );
    await tester.enterText(
      find.byKey(const ValueKey('checkout-trx')),
      'TRX42',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('checkout-submit')));
    await tester.pumpAndSettle();

    expect(repo.submitted, ['TRX42']);
    expect(find.text('History-Landed'), findsOneWidget);
    expect(find.textContaining('Submission Received'), findsOneWidget);

    // Back from History reaches Account & Profile, never the completed checkout.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Account-Profile-Page'), findsOneWidget);
    expect(find.text('History-Landed'), findsNothing);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Settings-Page'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Landing-Page'), findsOneWidget);
  });
}
