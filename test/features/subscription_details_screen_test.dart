/// Subscription Details sub-page, and the payment ledger it now shows.
///
/// The three facts it used to show in a bottom sheet are pinned here unchanged,
/// plus the two the sub-page adds: the plan is named as **Current Plan**, and the
/// history is a **table** with a serial number, the amount, the moment it was
/// submitted and the reviewer's verdict on each row. The table is the part worth
/// testing carefully — a ledger that loses a column, renumbers from the wrong
/// end, or prints a UTC timestamp beside a Bangladesh date is exactly the kind of
/// wrong a user cannot easily spot.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/providers/repository_providers.dart';
import 'package:legal_case_diary/core/router/app_router.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/account_mode.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/local/firms_dao.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/local/profiles_dao.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/profile_repository.dart';
import 'package:legal_case_diary/features/auth/data/auth_repository.dart';
import 'package:legal_case_diary/features/payments/data/payment_plans.dart';
import 'package:legal_case_diary/features/payments/data/payment_repository.dart';
import 'package:legal_case_diary/features/settings/presentation/subscription_details_screen.dart';

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

  /// Pumps the sub-page on a router, then seeds [seed] once the account caches
  /// are already being read — nothing on this screen watches them in its build,
  /// so the pull-only caches would otherwise be read after the seed.
  Future<void> pumpDetails(
    WidgetTester tester, {
    Future<void> Function(AppDatabase db)? seed,
    List<Override> overrides = const <Override>[],
  }) async {
    await tester.binding.setSurfaceSize(const Size(420, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpSettingsRouter(
      tester,
      location: AppRoutes.settingsSubscriptionDetails,
      overrides: await harness.setUp(
        extra: <Override>[
          // Only when the test does not pin its own: overriding a provider
          // twice in one container is an error the container raises, not a
          // silent last-one-wins.
          if (!overrides.any((o) => o.origin == myPaymentSubmissionsProvider))
            myPaymentSubmissionsProvider.overrideWith(
              (ref) async => const <PaymentSubmission>[],
            ),
          ...overrides,
        ],
      ),
      routes: [
        GoRoute(
          path: AppRoutes.settingsSubscriptionDetails,
          builder: (_, _) => const SubscriptionDetailsScreen(),
        ),
      ],
    );
    l = await AppLocalizations.delegate.load(const Locale('en'));

    ProviderScope.containerOf(
      tester.element(find.byType(SubscriptionDetailsScreen)),
    ).read(accountProfileProvider);
    await tester.pumpAndSettle();

    if (seed != null) {
      await seed(harness.db);
      await tester.pumpAndSettle();
    }
  }

  /// A submission the harness hands to the page's provider.
  PaymentSubmission submission({
    required String id,
    required String planType,
    required int amount,
    required String status,
    required DateTime submittedAt,
  }) => PaymentSubmission(
        id: id,
        planType: planType,
        amount: amount,
        mfsProvider: 'bkash',
        senderNumber: '01700000000',
        transactionId: 'TX$id',
        status: status,
        submittedAt: submittedAt,
      );

  /// A firm owner's profile and firm row, both expiring at one fixed instant:
  /// 01/12/2026, 17:30 UTC — 11:30 PM the same day in Bangladesh civil time,
  /// which is the value the assertions below name.
  Future<void> seedOwner(AppDatabase db) async {
    await ProfilesDao(db).upsert(
      ProfilesCompanion(
        id: const Value('user-1'),
        fullName: const Value('Adv. Rahim Uddin'),
        role: const Value(AccountRole.owner),
        firmId: const Value('firm-1'),
        subscriptionStatus: const Value('active'),
        subscriptionExpiry: Value(
          DateTime.utc(2026, 12, 1, 17, 30).millisecondsSinceEpoch,
        ),
        createdAt: const Value(1),
      ),
    );
    await FirmsDao(db).upsert(
      FirmsCompanion(
        id: const Value('firm-1'),
        name: const Value('Rahman & Associates'),
        ownerId: const Value('user-1'),
        subscriptionStatus: const Value('active'),
        subscriptionExpiry: Value(
          DateTime.utc(2026, 12, 1, 17, 30).millisecondsSinceEpoch,
        ),
        createdAt: const Value(1),
      ),
    );
  }

  testWidgets('a firm owner sees role, firm, plan and an expiry to the minute', (
    tester,
  ) async {
    await pumpDetails(
      tester,
      overrides: [
        myPaymentSubmissionsProvider.overrideWith(
          (ref) async => [
                submission(
                  id: 'p1',
                  planType: paymentPlanQuarterly,
                  amount: 285,
                  status: 'approved',
                  submittedAt: DateTime.utc(2026, 11, 2, 17, 30),
                ),
          ],
        ),
      ],
      seed: seedOwner,
    );

    expect(find.text(l.settingsManageAccount_role), findsOneWidget);
    expect(find.text(l.settingsManageAccount_roleOwner), findsWidgets);
    expect(find.text(l.settingsManageAccount_firm), findsOneWidget);
    expect(find.text('Rahman & Associates'), findsOneWidget);

    // The plan is named, not "Premium": a firm member on an approved plan is
    // told which plan they are running.
    expect(find.text(l.settingsSubscription_currentPlan), findsWidgets);
    expect(find.text(l.paywall_planQuarterly), findsWidgets);

    // 01/12/2026, 17:30 UTC is 23:30 on the same day in Bangladesh civil time,
    // so the expiry reads 11:30 PM rather than 5:30 PM: the date and the clock
    // have to come from the same shifted instant, or they disagree by six
    // hours and the user reconciles a subscription against the wrong moment.
    expect(find.text('01/12/2026, 11:30 PM'), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('an individual on the free plan reads Free, not a dash', (
    tester,
  ) async {
    // A pulled profile row with no expiry: the account is *known* to be free.
    await pumpDetails(
      tester,
      seed: (db) => ProfilesDao(db).upsert(
        const ProfilesCompanion(
          id: Value('user-1'),
          fullName: Value('Adv. Rahim Uddin'),
          role: Value(AccountRole.individual),
          subscriptionStatus: Value('free'),
          createdAt: Value(1),
        ),
      ),
    );

    expect(find.text(l.settingsManageAccount_roleIndividual), findsWidgets);
    expect(find.text(l.settingsManageAccount_planFree), findsWidgets);
    // No firm in individual mode, so no Firm row.
    expect(find.text(l.settingsManageAccount_firm), findsNothing);

    await unmountApp(tester);
  });

  testWidgets('an account whose row has not landed says nothing, not Free', (
    tester,
  ) async {
    // Regression, carried across from the sheet: it read the entitlement the
    // moment the session existed, so a premium account that had just signed in
    // was told "Free" while the expiry beside it already named a date. With no
    // cached row there is no plan to report, and a dash is the honest value.
    await pumpDetails(tester);

    expect(find.text(l.settingsManageAccount_planFree), findsNothing);
    expect(find.text('—'), findsWidgets, reason: 'the entitlement is unknown');

    await unmountApp(tester);
  });

  testWidgets('the history is a table: number, plan, paid, when, status', (
    tester,
  ) async {
    await pumpDetails(
      tester,
      overrides: [
        myPaymentSubmissionsProvider.overrideWith(
          (ref) async => [
                submission(
                  id: 'older',
                  planType: paymentPlanMonthly,
                  amount: 100,
                  status: 'approved',
                  submittedAt: DateTime.utc(2026, 10, 2, 17, 30),
                ),
                submission(
                  id: 'newer',
                  planType: paymentPlanQuarterly,
                  amount: 285,
                  status: 'pending',
                  submittedAt: DateTime.utc(2026, 11, 2, 17, 30),
                ),
          ],
        ),
      ],
      seed: (db) => ProfilesDao(db).upsert(
        const ProfilesCompanion(
          id: Value('user-1'),
          fullName: Value('Adv. Rahim Uddin'),
          role: Value(AccountRole.individual),
          subscriptionStatus: Value('free'),
          createdAt: Value(1),
        ),
      ),
    );

    // The header row names the five columns.
    expect(find.text(l.settingsSubscription_serial), findsOneWidget);
    expect(find.text(l.settingsManageAccount_plan), findsWidgets);
    expect(find.text(l.settingsSubscription_paid), findsOneWidget);
    expect(find.text(l.settingsSubscription_dateTime), findsOneWidget);
    expect(find.text(l.settingsSubscription_status), findsOneWidget);

    // Newest first, so the row a user came about is row 1.
    expect(find.text('1.'), findsOneWidget);
    expect(find.text('2.'), findsOneWidget);

    // Both plans, both amounts, both verdicts.
    expect(find.text(l.paywall_planQuarterly), findsWidgets);
    expect(find.text(l.paywall_planMonthly), findsWidgets);
    expect(find.text(l.payments_amountValue('285')), findsOneWidget);
    expect(find.text(l.payments_amountValue('100')), findsOneWidget);
    expect(find.text(l.payments_statusPending), findsOneWidget);
    expect(find.text(l.payments_statusApproved), findsOneWidget);

    // The moment each purchase was submitted, in Bangladesh civil time: 17:30
    // UTC is 23:30 the same day, so both rows read 11:30 PM on their own date.
    expect(find.text('02/11/2026, 11:30 PM'), findsOneWidget);
    expect(find.text('02/10/2026, 11:30 PM'), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('an account with no purchases says so instead of a table', (
    tester,
  ) async {
    await pumpDetails(
      tester,
      seed: (db) => ProfilesDao(db).upsert(
        const ProfilesCompanion(
          id: Value('user-1'),
          fullName: Value('Adv. Rahim Uddin'),
          role: Value(AccountRole.individual),
          subscriptionStatus: Value('free'),
          createdAt: Value(1),
        ),
      ),
    );

    expect(find.text(l.payments_noSubmissions), findsOneWidget);
    expect(find.text(l.settingsSubscription_serial), findsNothing);
    expect(find.text('1.'), findsNothing);

    await unmountApp(tester);
  });
}