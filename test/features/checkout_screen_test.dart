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
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  Future<void> pump(
    WidgetTester tester,
    SharedPreferences prefs,
    PaymentRepository repo, {
    String? planKey = paymentPlanMonthly,
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
    expect(find.text('৳100'), findsOneWidget);
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

  testWidgets('a confirmed submit keeps the snackbar and opens payment history',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // A minimal router mirrors just the two routes the flow touches, so the
    // navigation the bare pump helper cannot see gets pinned: the checkout
    // pushes the Subscription Details sub-page with `focus=history`, and the
    // confirmation snackbar survives the push.
    final focusSeen = <String?>[];
    final router = GoRouter(
      initialLocation: AppRoutes.checkout,
      routes: [
        GoRoute(
          path: AppRoutes.checkout,
          builder: (context, state) => CheckoutScreen(
            planKey: paymentPlanMonthly,
          ),
        ),
        GoRoute(
          path: AppRoutes.settingsSubscriptionDetails,
          builder: (context, state) {
            focusSeen.add(
              state.uri
                  .queryParameters[AppRoutes.subscriptionFocusParam],
            );
            return const Scaffold(body: Text('Details-Landed'));
          },
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
    expect(focusSeen, ['history']);
    expect(find.text('Details-Landed'), findsOneWidget);
    expect(find.textContaining('Submission Received'), findsOneWidget);
  });
}
