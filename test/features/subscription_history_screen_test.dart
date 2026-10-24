/// Subscription History — the ledger on its own screen (0.0.624).
///
/// The cases were Subscription Details' until the split: one card per purchase
/// and cancellation, numbered newest first, with the local date and time, the
/// reviewer's verdict and note, and Bengali digits under বাংলা. The screen's
/// AppBar is the only title — the body deliberately draws no second heading.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/providers/repository_providers.dart';
import 'package:legal_case_diary/core/router/app_router.dart';
import 'package:legal_case_diary/core/utils/date_utils.dart';
import 'package:legal_case_diary/features/payments/data/payment_plans.dart';
import 'package:legal_case_diary/features/payments/data/payment_repository.dart';
import 'package:legal_case_diary/features/settings/presentation/subscription_history_screen.dart';

import 'auth_test_support.dart';
import 'settings_test_support.dart';

void main() {
  late AppLocalizations l;

  /// Pumps the history screen with both ledger providers stubbed.
  Future<void> pumpHistory(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
    List<Override> overrides = const <Override>[],
  }) async {
    await tester.binding.setSurfaceSize(const Size(420, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpSettingsRouter(
      tester,
      location: AppRoutes.settingsSubscriptionHistory,
      locale: locale,
      overrides: [
        if (!overrides.any((o) => o.origin == myPaymentSubmissionsProvider))
          myPaymentSubmissionsProvider.overrideWith(
            (ref) async => const <PaymentSubmission>[],
          ),
        if (!overrides.any(
          (o) => o.origin == mySubscriptionCancellationsProvider,
        ))
          mySubscriptionCancellationsProvider.overrideWith(
            (ref) async => const <SubscriptionCancellation>[],
          ),
        ...overrides,
      ],
      routes: [
        GoRoute(
          path: AppRoutes.settingsSubscriptionHistory,
          builder: (_, _) => const SubscriptionHistoryScreen(),
        ),
      ],
    );
    l = await AppLocalizations.delegate.load(locale);
    await tester.pumpAndSettle();
  }

  /// A submission the harness hands to the page's provider.
  PaymentSubmission submission({
    required String id,
    required String planType,
    required int amount,
    required String status,
    required DateTime submittedAt,
    DateTime? approvedAt,
  }) => PaymentSubmission(
    id: id,
    planType: planType,
    amount: amount,
    mfsProvider: 'bkash',
    senderNumber: '01700000000',
    transactionId: 'TX$id',
    status: status,
    submittedAt: submittedAt,
    approvedAt: approvedAt,
  );

  testWidgets('the header names the ledger and the body does not repeat it', (
    tester,
  ) async {
    await pumpHistory(tester);

    expect(find.text(l.payments_historyTitle), findsOneWidget);
  });

  testWidgets('the history is a card per purchase, carrying all five facts', (
    tester,
  ) async {
    await pumpHistory(
      tester,
      overrides: [
        myPaymentSubmissionsProvider.overrideWith(
          (ref) async => [
            submission(
              id: 'older',
              planType: paymentPlanStarterMonthly,
              amount: 60,
              status: 'approved',
              submittedAt: DateTime.utc(2026, 10, 2, 17, 30),
              approvedAt: DateTime.utc(2026, 10, 2, 18, 45),
            ),
            submission(
              id: 'newer',
              planType: paymentPlanStarterQuarterly,
              amount: 180,
              status: 'pending',
              submittedAt: DateTime.utc(2026, 11, 2, 17, 30),
            ),
          ],
        ),
      ],
    );

    // Newest first, numbered from 1.
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    // Each card states its plan, what was paid, when, and the verdict.
    expect(find.text(l.paywall_planStarterQuarterly), findsWidgets);
    expect(find.text(l.paywall_planStarterMonthly), findsWidgets);
    expect(find.text(l.payments_amountValue('180')), findsOneWidget);
    expect(find.text(l.payments_amountValue('60')), findsOneWidget);
    expect(find.text(l.payments_statusPending), findsOneWidget);
    expect(find.text(l.payments_statusApproved), findsOneWidget);
    expect(find.text(l.settingsSubscription_paid), findsNWidgets(2));
    expect(find.text(l.settingsSubscription_dateTime), findsNWidgets(2));

    // An approved purchase stamps its approval; a pending one its submission.
    expect(find.text('03/10/2026, 12:45 AM'), findsOneWidget);
    expect(find.text('02/11/2026, 11:30 PM'), findsOneWidget);
    expect(find.text(l.payments_notesLabel), findsNothing);

    // The timestamp's column is the wider one, as it always was.
    final paidWidth = tester
        .getSize(find.text(l.payments_amountValue('180')))
        .width;
    final stampWidth = tester.getSize(find.text('02/11/2026, 11:30 PM')).width;
    expect(paidWidth, lessThan(stampWidth));

    await unmountApp(tester);
  });

  testWidgets('the card numbers use the locale\'s digits', (tester) async {
    await pumpHistory(
      tester,
      locale: const Locale('bn'),
      overrides: [
        myPaymentSubmissionsProvider.overrideWith(
          (ref) async => [
            submission(
              id: 'older',
              planType: paymentPlanProMonthly,
              amount: 100,
              status: 'approved',
              submittedAt: DateTime.utc(2026, 10, 2, 17, 30),
            ),
            submission(
              id: 'newer',
              planType: paymentPlanProQuarterly,
              amount: 285,
              status: 'pending',
              submittedAt: DateTime.utc(2026, 11, 2, 17, 30),
            ),
          ],
        ),
      ],
    );

    expect(
      find.text(AppDateUtils.formatDigits(1, 'bn', grouping: false)),
      findsOneWidget,
    );
    expect(
      find.text(AppDateUtils.formatDigits(2, 'bn', grouping: false)),
      findsOneWidget,
    );
    expect(find.text('1'), findsNothing);
    expect(find.text('2'), findsNothing);

    await unmountApp(tester);
  });

  testWidgets(
    'a rejected purchase stamps its submission, never a phantom approval',
    (tester) async {
      await pumpHistory(
        tester,
        overrides: [
          myPaymentSubmissionsProvider.overrideWith(
            (ref) async => [
              submission(
                id: 'p1',
                planType: paymentPlanProMonthly,
                amount: 100,
                status: 'rejected',
                submittedAt: DateTime.utc(2026, 11, 2, 17, 30),
                approvedAt: DateTime.utc(2026, 11, 2, 18, 45),
              ),
            ],
          ),
        ],
      );

      expect(find.text('02/11/2026, 11:30 PM'), findsOneWidget);
      expect(find.text('03/11/2026, 12:45 AM'), findsNothing);

      await unmountApp(tester);
    },
  );

  testWidgets('a rejection shows the reviewer\'s note on its card', (
    tester,
  ) async {
    await pumpHistory(
      tester,
      overrides: [
        myPaymentSubmissionsProvider.overrideWith(
          (ref) async => [
            PaymentSubmission(
              id: 'p1',
              planType: paymentPlanProMonthly,
              amount: 100,
              mfsProvider: 'bkash',
              senderNumber: '01700000000',
              transactionId: 'TX1',
              status: 'rejected',
              adminNotes: 'TrxID not found',
              submittedAt: DateTime.utc(2026, 11, 2, 17, 30),
            ),
          ],
        ),
      ],
    );

    expect(find.text(l.payments_statusRejected), findsOneWidget);
    expect(find.text(l.payments_notesLabel), findsOneWidget);
    expect(find.text('TrxID not found'), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('an account with no purchases says so instead of a table', (
    tester,
  ) async {
    await pumpHistory(tester);

    expect(find.text(l.payments_noSubmissions), findsOneWidget);
    expect(find.text(l.settingsSubscription_paid), findsNothing);
    expect(find.text('1'), findsNothing);

    await unmountApp(tester);
  });

  testWidgets('cancellations and purchases share one newest-first ledger', (
    tester,
  ) async {
    await pumpHistory(
      tester,
      overrides: [
        myPaymentSubmissionsProvider.overrideWith(
          (ref) async => [
            submission(
              id: 'p1',
              planType: paymentPlanProQuarterly,
              amount: 285,
              status: 'approved',
              submittedAt: DateTime.utc(2026, 11, 2, 17, 30),
            ),
          ],
        ),
        mySubscriptionCancellationsProvider.overrideWith(
          (ref) async => [
            SubscriptionCancellation(
              id: 'c1',
              planType: paymentPlanProQuarterly,
              amount: 285,
              cancelledAt: DateTime.utc(2026, 12, 2, 17, 30),
            ),
          ],
        ),
      ],
    );

    // Both moments are drawn, newest first: the cancellation is card 1.
    final cancelled = find.text('02/12/2026, 11:30 PM');
    final purchased = find.text('02/11/2026, 11:30 PM');
    expect(cancelled, findsOneWidget);
    expect(purchased, findsOneWidget);
    expect(
      tester.getTopLeft(cancelled).dy,
      lessThan(tester.getTopLeft(purchased).dy),
    );
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text(l.payments_statusCancelled), findsOneWidget);
    expect(find.text(l.payments_statusApproved), findsOneWidget);

    await unmountApp(tester);
  });
}
