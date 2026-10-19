/// Subscription Details sub-page, and the payment ledger it now shows.
///
/// The three facts it used to show in a bottom sheet are pinned here unchanged,
/// plus the two the sub-page adds: the plan is named as **Current Plan**, and the
/// history is **one card per purchase** carrying the number, the plan, the amount,
/// the moment it was submitted and the reviewer's verdict. The ledger is the part
/// worth testing carefully — a purchase that loses its number, renumbers from the
/// wrong end, drops its verdict, or prints a UTC timestamp beside a Bangladesh date
/// is exactly the kind of wrong a user cannot easily spot.
///
/// The values in the summary card are pinned as **right-aligned** too, because the
/// bug that fixed was invisible: `Flexible` right-aligns within a box that is
/// only as wide as the text, so every value sat right beside its label and read as
/// a left-aligned column.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:legal_case_diary/core/constants/app_colors.dart';
import 'package:legal_case_diary/core/constants/app_spacing.dart';
import 'package:legal_case_diary/core/constants/free_tier.dart';
import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/providers/repository_providers.dart';
import 'package:legal_case_diary/core/router/app_router.dart';
import 'package:legal_case_diary/core/utils/date_utils.dart';
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

/// A payments boundary whose cancellation the test decides.
///
/// The screen's Cancel action calls the repository directly, so this fake both
/// records the attempt and can refuse it with one of the server's typed answers.
class _FakePaymentsRepository implements PaymentRepository {
  _FakePaymentsRepository({this.refusal});

  /// When set, `cancelSubscription` throws it.
  final PaymentCancelFailure? refusal;

  /// The cancellations `fetchMyCancellations` returns.
  List<SubscriptionCancellation> cancellations =
      const <SubscriptionCancellation>[];

  /// How many cancellations were attempted.
  int cancelCalls = 0;

  @override
  Future<void> cancelSubscription() async {
    cancelCalls++;
    if (refusal != null) throw PaymentCancelException(refusal!);
  }

  @override
  Future<List<SubscriptionCancellation>> fetchMyCancellations() async =>
      cancellations;

  @override
  Future<List<PaymentSubmission>> fetchMySubmissions() async =>
      const <PaymentSubmission>[];

  @override
  Future<void> submit({
    required String userId,
    required String planType,
    required int amount,
    required String mfsProvider,
    required String senderNumber,
    required String transactionId,
  }) async {}
}

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
    Locale locale = const Locale('en'),
    Future<void> Function(AppDatabase db)? seed,
    List<Override> overrides = const <Override>[],
  }) async {
    await tester.binding.setSurfaceSize(const Size(420, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpSettingsRouter(
      tester,
      location: AppRoutes.settingsSubscriptionDetails,
      locale: locale,
      overrides: await harness.setUp(
        extra: <Override>[
          // Only when the test does not pin its own: overriding a provider
          // twice in one container is an error the container raises, not a
          // silent last-one-wins.
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
      ),
      routes: [
        GoRoute(
          path: AppRoutes.settingsSubscriptionDetails,
          builder: (_, _) => const SubscriptionDetailsScreen(),
        ),
      ],
    );
    l = await AppLocalizations.delegate.load(locale);

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
        // A paid account holds its tier even when the period ends, which is what
        // gives a lapsed plan its allowance instead of the free 50.
        tier: const Value('pro'),
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
        tier: const Value('pro'),
        subscriptionStatus: const Value('active'),
        subscriptionExpiry: Value(
          DateTime.utc(2026, 12, 1, 17, 30).millisecondsSinceEpoch,
        ),
        createdAt: const Value(1),
      ),
    );
  }

  /// A chamber member's profile and the same firm row: the member's own paid
  /// period runs to 01/06/2027, deliberately different from the chamber's, so a
  /// screen that showed the wrong one is visible rather than coincidental.
  Future<void> seedMember(AppDatabase db) async {
    await ProfilesDao(db).upsert(
      ProfilesCompanion(
        id: const Value('user-1'),
        fullName: const Value('Adv. Rahim Uddin'),
        role: const Value(AccountRole.associate),
        firmId: const Value('firm-1'),
        subscriptionStatus: const Value('active'),
        subscriptionExpiry: Value(
          DateTime.utc(2027, 6, 1, 17, 30).millisecondsSinceEpoch,
        ),
        createdAt: const Value(1),
      ),
    );
    await FirmsDao(db).upsert(
      FirmsCompanion(
        id: const Value('firm-1'),
        name: const Value('Rahman & Associates'),
        ownerId: const Value('user-2'),
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
                  planType: paymentPlanProQuarterly,
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
    // A paid plan keeps its Expiry row and shows no limitations section.
    expect(find.text(l.settingsManageAccount_expiry), findsOneWidget);
    expect(
      find.text(l.settingsSubscription_freePlanLimitations),
      findsNothing,
    );

    // The plan is named, not "Premium": a firm member on an approved plan is
    // told which plan they are running.
    expect(find.text(l.settingsSubscription_currentPlan), findsWidgets);
    expect(find.text(l.paywall_planProQuarterly), findsWidgets);

    // 01/12/2026, 17:30 UTC is 23:30 on the same day in Bangladesh civil time,
    // so the expiry reads 11:30 PM rather than 5:30 PM: the date and the clock
    // have to come from the same shifted instant, or they disagree by six
    // hours and the user reconciles a subscription against the wrong moment.
    expect(find.text('01/12/2026, 11:30 PM'), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets(
    'a member reads Premium, not the plan they bought before joining',
    (tester) async {
      await pumpDetails(
        tester,
        overrides: [
          myPaymentSubmissionsProvider.overrideWith(
            (ref) async => [
                  submission(
                    id: 'p1',
                    planType: paymentPlanStarterQuarterly,
                    amount: 180,
                    status: 'approved',
                    submittedAt: DateTime.utc(2026, 11, 2, 17, 30),
                  ),
            ],
          ),
          firmMemberProvider.overrideWithValue(true),
        ],
        seed: seedMember,
      );

      // The chamber's subscription is the one running (Phase 9): the member's
      // own approved Starter row is ignored, so the plan reads Premium rather
      // than naming a plan that is not in force on this account. The one
      // remaining Starter label is the purchase in Payment History, not the plan
      // label — the ledger is a record of what was bought, not what is running.
      expect(find.text(l.settingsManageAccount_planPremium), findsWidgets);
      expect(find.text(l.paywall_planStarterQuarterly), findsOneWidget);

      // The expiry is the chamber's, not the member's own (01/06/2027).
      expect(find.text('01/12/2026, 11:30 PM'), findsOneWidget);
      expect(find.text('01/06/2027, 11:30 PM'), findsNothing);

      await unmountApp(tester);
    },
  );

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

    // A Free plan shows its limitations, in place of an expiry it does not have.
    expect(
      find.text(l.settingsSubscription_freePlanLimitations),
      findsOneWidget,
    );
    expect(find.text(l.settingsManageAccount_expiry), findsNothing);
    // Every limitation is listed, the case ceiling named from the one constant.
    expect(
      find.text(
        l.settingsSubscription_freeLimitCases('$freeTierCaseLimit'),
      ),
      findsOneWidget,
    );
    expect(
      find.text(l.settingsSubscription_freeLimitCloud),
      findsOneWidget,
    );
    expect(
      find.text(l.settingsSubscription_freeLimitRecovery),
      findsOneWidget,
    );
    // The section sits above Payment History.
    expect(
      tester.getTopLeft(find.text(l.settingsSubscription_freePlanLimitations)).dy,
      lessThan(
        tester
            .getTopLeft(find.text(l.payments_historyTitle))
            .dy,
      ),
    );

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
    // A dash is neither Free nor premium, so neither the expiry-hiding (the row
    // stays, for a premium plan still in flight) nor the limitations apply.
    expect(find.text(l.settingsManageAccount_expiry), findsOneWidget);
    expect(
      find.text(l.settingsSubscription_freePlanLimitations),
      findsNothing,
    );

    await unmountApp(tester);
  });

  testWidgets('the history is a card per purchase, carrying all five facts', (
    tester,
  ) async {
    await pumpDetails(
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

    // Newest first, numbered from 1: the purchase a user came about is first.
    // English, so the numbers are Latin digits here; the Bengali rendering is
    // pinned by its own test below.
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    // Each card states its plan, what was paid, when, and the verdict.
    expect(find.text(l.paywall_planStarterQuarterly), findsWidgets);
    expect(find.text(l.paywall_planStarterMonthly), findsWidgets);
    expect(find.text(l.payments_amountValue('180')), findsOneWidget);
    expect(find.text(l.payments_amountValue('60')), findsOneWidget);
    expect(find.text(l.payments_statusPending), findsOneWidget);
    expect(find.text(l.payments_statusApproved), findsOneWidget);

    // The captions are the field names, so nothing from the old table's columns
    // is lost: each card still says which figure is the payment and which is the
    // moment.
    expect(find.text(l.settingsSubscription_paid), findsNWidgets(2));
    expect(find.text(l.settingsSubscription_dateTime), findsNWidgets(2));

    // The moment each purchase happened: the approved one stamps its
    // *approval* (18:45 UTC → 00:45 on 03/10 Bangladesh time — a different
    // date than its submission, which proves the stamp is not the submission),
    // and the pending one has no approval, so it falls back to its submission.
    expect(find.text('03/10/2026, 12:45 AM'), findsOneWidget);
    expect(find.text('02/11/2026, 11:30 PM'), findsOneWidget);

    // A reviewer's note is shown rather than swallowed: a rejection always
    // carries a reason, and a ledger that hid it leaves the user guessing.
    expect(find.text(l.payments_notesLabel), findsNothing);

    // The card's two figures are not an equal split: Paid takes its natural
    // width and Date & Time takes everything left, because two Expanded halves
    // boxed the timestamp into the narrower column and it wrapped its AM/PM.
    // The test font is too wide to measure wrapping itself, so the contract is
    // what is pinned: the timestamp's column is the wider one.
    final paidWidth = tester.getSize(find.text(l.payments_amountValue('180'))).width;
    final stampWidth =
        tester.getSize(find.text('02/11/2026, 11:30 PM')).width;
    expect(paidWidth, lessThan(stampWidth));

    await unmountApp(tester);
  });

  testWidgets('the card numbers use the locale\'s digits', (tester) async {
    // Regression: the number was a raw interpolation (`'$number'`), which is
    // always ASCII, so বাংলা read "1" and "2" beside Bengali amounts and
    // dates — the same defect the calendars and the case serials each got a
    // `formatDigits` call to fix.
    await pumpDetails(
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

    // বাংলা reads ১ and ২, through the same helper the amounts already use.
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

  testWidgets('a rejected purchase stamps its submission, never a phantom approval', (
    tester,
  ) async {
    // The regression this pins: an approved purchase shows the approval, but a
    // rejected one has no approval to show — falling back to the submission is
    // the only honest moment it has, and a stale server-approved_at must not
    // resurrect on a card the verdict says never became a subscription.
    await pumpDetails(
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

    expect(find.text('02/11/2026, 11:30 PM'), findsOneWidget);
    expect(find.text('03/11/2026, 12:45 AM'), findsNothing);

    await unmountApp(tester);
  });

  testWidgets('the expiry row gives its value the space it needs', (tester) async {
    // Regression: the label was `Expanded`, so it took half the row even when
    // the label is one word, and "01/12/2026, 11:30 PM" wrapped its AM/PM onto
    // a second line. The test font is wider than Inter, so wrapping cannot be
    // measured directly here; what the fix changes and this pins is the
    // *contract*: the value is no longer boxed into half the row. The label is
    // as wide as its text; the value gets everything else.
    await pumpDetails(
      tester,
      overrides: [
        myPaymentSubmissionsProvider.overrideWith(
          (ref) async => const <PaymentSubmission>[],
        ),
      ],
      seed: seedOwner,
    );

    final label = find.text(l.settingsManageAccount_expiry);
    final value = find.text('01/12/2026, 11:30 PM');
    expect(value, findsOneWidget);
    final row = tester.getRect(label).width + tester.getRect(value).width;
    final labelWidth = tester.getRect(label).width;
    // Half the row would be `row / 2`; the label must take strictly less, so
    // the value owns more than half — the space the wrap used to steal.
    expect(labelWidth, lessThan(row / 2));

    await unmountApp(tester);
  });

  testWidgets('a rejection shows the reviewer\'s note on its card', (
    tester,
  ) async {
    await pumpDetails(
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

    expect(find.text(l.payments_statusRejected), findsOneWidget);
    expect(find.text(l.payments_notesLabel), findsOneWidget);
    expect(find.text('TrxID not found'), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('the summary values sit at the right edge of the card', (
    tester,
  ) async {
    // Regression: the value was in a `Flexible`, so `TextAlign.right` aligned it
    // inside a box only as wide as the text — it sat immediately after its
    // label and the card read as one left-aligned column. Asserting the
    // `textAlign` property proves nothing here, because the property is correct
    // in both layouts; what differs is *where the text lands*, so this measures
    // the edge instead.
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

    // The card's content edge: the screen width less the page margin and the
    // card's own padding. Every right-aligned value has to finish exactly there.
    final edge = 420 - AppSpacing.edgeMargin - AppSpacing.md;
    for (final value in [
      // Role and Current Plan; the plan also names the card's header, so the
      // last one is the row's value.
      l.settingsManageAccount_roleIndividual,
      l.settingsManageAccount_planFree,
    ]) {
      final right = tester.getTopRight(find.text(value).last).dx;
      expect(right, closeTo(edge, 1.0), reason: value);
    }

    // A free plan hides the expiry row entirely: no Expiry label, no dash.
    expect(find.text(l.settingsManageAccount_expiry), findsNothing);
    expect(find.text('—'), findsNothing);

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
    expect(find.text(l.settingsSubscription_paid), findsNothing);
    expect(find.text('1'), findsNothing);

    await unmountApp(tester);
  });

  testWidgets('the Free Plan Limitations heading has no bullet and its bullets are black', (
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

    // The three limitation dots are black; the heading carries no dot at all,
    // so exactly three 6 px circles remain and none of them is the error red.
    Color? dotColor(Widget w) =>
        ((w as Container).decoration as BoxDecoration).color;
    final dots = tester
        .widgetList<Container>(
          find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration! as BoxDecoration).shape == BoxShape.circle &&
                w.constraints?.maxWidth == 6,
          ),
        )
        .toList();
    expect(dots, hasLength(3), reason: 'one bullet per limitation, no heading bullet');
    for (final dot in dots) {
      expect(dotColor(dot), AppColors.secondary, reason: 'bullets are black');
    }

    await unmountApp(tester);
  });

  /// A paid individual: no chamber, so the Cancel action is the account's own
  /// decision and the lapsed landing after it is observable.
  Future<void> seedIndividualPaid(AppDatabase db) => ProfilesDao(db).upsert(
        ProfilesCompanion(
          id: const Value('user-1'),
          fullName: const Value('Adv. Rahim Uddin'),
          role: const Value(AccountRole.individual),
          tier: const Value('pro'),
          subscriptionStatus: const Value('active'),
          subscriptionExpiry: Value(
            DateTime.utc(2026, 12, 1, 17, 30).millisecondsSinceEpoch,
          ),
          createdAt: const Value(1),
        ),
      );

  const cancelKey = ValueKey('subscription-details-cancel');

  testWidgets('a paid plan carries Cancel at the right of the plan card', (
    tester,
  ) async {
    await pumpDetails(tester, seed: seedIndividualPaid);

    expect(find.byKey(cancelKey), findsOneWidget);
    expect(find.text(l.payments_cancelPlan), findsOneWidget);

    // A filled red action with white text (user request).
    final button = tester.widget<TextButton>(find.byKey(cancelKey));
    expect(
      button.style?.backgroundColor?.resolve(<WidgetState>{}),
      AppColors.error,
    );
    expect(
      button.style?.foregroundColor?.resolve(<WidgetState>{}),
      AppColors.onError,
    );

    // It sits at the card's content edge, not beside the plan's name: the same
    // edge every right-aligned value on this page finishes at.
    final edge = 420 - AppSpacing.edgeMargin - AppSpacing.md;
    expect(
      tester.getTopRight(find.byKey(cancelKey)).dx,
      closeTo(edge, 1.0),
    );

    await unmountApp(tester);
  });

  testWidgets('the page starts below the phone status bar', (tester) async {
    // This page is a top-level route, so the shell's own inset does not reach
    // it. Without its own `SafeArea` the Scaffold painted its app bar up behind
    // the status bar and the phone's clock sat on that white instead of on the
    // app's own black — the Subscription Plans screen is the reference.
    // Pixels are physical: one logical pixel per pixel keeps the 24 a round
    // number on every device the suite runs on.
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = const FakeViewPadding(top: 24);
    addTearDown(tester.view.reset);

    await pumpDetails(tester, seed: seedIndividualPaid);

    expect(tester.getTopLeft(find.byType(AppBar)).dy, 24);

    await unmountApp(tester);
  });

  testWidgets('a Free plan has nothing to cancel', (tester) async {
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

    expect(find.byKey(cancelKey), findsNothing);

    await unmountApp(tester);
  });

  testWidgets('a lapsed plan has nothing left to cancel', (tester) async {
    // The tier is kept and the period has ended: the account holds a lapse
    // allowance, but there is no live plan for the action to end.
    await pumpDetails(
      tester,
      seed: (db) => ProfilesDao(db).upsert(
        ProfilesCompanion(
          id: const Value('user-1'),
          fullName: const Value('Adv. Rahim Uddin'),
          role: const Value(AccountRole.individual),
          tier: const Value('pro'),
          subscriptionStatus: const Value('cancelled'),
          subscriptionExpiry: Value(
            DateTime.utc(2026, 10, 1, 17, 30).millisecondsSinceEpoch,
          ),
          createdAt: const Value(1),
        ),
      ),
    );

    expect(find.text(l.settingsSubscription_lapsedTitle), findsOneWidget);
    expect(find.byKey(cancelKey), findsNothing);

    await unmountApp(tester);
  });

  testWidgets('a chamber member cannot cancel the chamber\'s plan', (
    tester,
  ) async {
    // The server refuses this case (`firm_member`), so the action is never
    // offered: their entitlement is the chamber's, and the owner is the one who
    // may end it.
    await pumpDetails(tester, seed: seedMember);

    expect(find.text('01/12/2026, 11:30 PM'), findsOneWidget);
    expect(find.byKey(cancelKey), findsNothing);

    await unmountApp(tester);
  });

  testWidgets(
    'the warning says the plan cannot be restored and Go Back sends nothing',
    (tester) async {
      final repo = _FakePaymentsRepository();
      await pumpDetails(
        tester,
        overrides: [paymentRepositoryProvider.overrideWithValue(repo)],
        seed: seedIndividualPaid,
      );

      await tester.tap(find.byKey(cancelKey));
      await tester.pumpAndSettle();

      expect(find.text(l.payments_cancelTitle), findsOneWidget);
      expect(find.text(l.payments_cancelWarning), findsOneWidget);
      expect(find.text(l.payments_goBack), findsOneWidget);
      expect(find.text(l.payments_confirmCancellation), findsOneWidget);

      // The way out is black, the destructive choice is red, both with white
      // text — the two colours the request names.
      Color? background(String key) => tester
          .widget<TextButton>(find.byKey(ValueKey(key)))
          .style
          ?.backgroundColor
          ?.resolve(<WidgetState>{});
      Color? foreground(String key) => tester
          .widget<TextButton>(find.byKey(ValueKey(key)))
          .style
          ?.foregroundColor
          ?.resolve(<WidgetState>{});
      expect(
        background('subscription-details-cancel-go-back'),
        AppColors.secondary,
      );
      expect(
        foreground('subscription-details-cancel-go-back'),
        AppColors.onSecondary,
      );
      expect(
        background('subscription-details-cancel-confirm'),
        AppColors.error,
      );
      expect(
        foreground('subscription-details-cancel-confirm'),
        AppColors.onError,
      );

      await tester.tap(find.text(l.payments_goBack));
      await tester.pumpAndSettle();

      expect(find.text(l.payments_cancelTitle), findsNothing);
      expect(repo.cancelCalls, 0);
      expect(find.byKey(cancelKey), findsOneWidget);

      await unmountApp(tester);
    },
  );

  testWidgets(
    'a confirmed cancellation ends the plan and lands in the ledger',
    (tester) async {
      var refreshes = 0;
      final repo = _FakePaymentsRepository()
        ..cancellations = <SubscriptionCancellation>[
          SubscriptionCancellation(
            id: 'c1',
            planType: paymentPlanProQuarterly,
            amount: 285,
            cancelledAt: DateTime.utc(2026, 12, 2, 17, 30),
          ),
        ];

      await pumpDetails(
        tester,
        overrides: [
          paymentRepositoryProvider.overrideWithValue(repo),
          // The ledger stays empty until the server has recorded the change, so
          // the entry asserted below is the one the cancellation created.
          mySubscriptionCancellationsProvider.overrideWith(
            (ref) async =>
                repo.cancelCalls == 0
                    ? const <SubscriptionCancellation>[]
                    : repo.cancellations,
          ),
          // The pull the action runs after the RPC; it carries the server's new
          // expiry, which is what moves the page to the lapsed stage.
          accountRefreshProvider.overrideWithValue(() async {
            refreshes++;
            await ProfilesDao(harness.db).upsert(
              ProfilesCompanion(
                id: const Value('user-1'),
                fullName: const Value('Adv. Rahim Uddin'),
                role: const Value(AccountRole.individual),
                tier: const Value('pro'),
                subscriptionStatus: const Value('cancelled'),
                // Behind the 48-hour grace, exactly where the server's own
                // cancellation puts it.
                subscriptionExpiry: Value(
                  DateTime.utc(2026, 10, 1, 12).millisecondsSinceEpoch,
                ),
                createdAt: const Value(1),
              ),
            );
            return true;
          }),
        ],
        seed: seedIndividualPaid,
      );

      expect(find.text(l.payments_statusCancelled), findsNothing);
      await tester.tap(find.byKey(cancelKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.payments_confirmCancellation));
      await tester.pumpAndSettle();

      expect(repo.cancelCalls, 1);
      expect(refreshes, 1);

      // The plan lapsed, and the tier it held still names it.
      expect(
        find.text(l.settingsManageAccount_planLapsed(l.paywall_tierPro)),
        findsWidgets,
      );
      expect(find.text(l.settingsSubscription_lapsedTitle), findsOneWidget);

      // The cancellation is an entry of its own: plan and amount repeated, a
      // red verdict, and the moment it happened rather than the purchase's.
      expect(find.text(l.payments_statusCancelled), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.text(l.payments_statusCancelled))
            .style
            ?.color,
        AppColors.error,
      );
      expect(find.text('02/12/2026, 11:30 PM'), findsOneWidget);

      // Nothing is left to cancel, so the action is gone with the live plan.
      expect(find.byKey(cancelKey), findsNothing);

      await unmountApp(tester);
    },
  );

  testWidgets('a refused cancellation keeps the plan and says why', (
    tester,
  ) async {
    final repo = _FakePaymentsRepository(
      refusal: PaymentCancelFailure.noActivePlan,
    );
    var refreshes = 0;
    await pumpDetails(
      tester,
      overrides: [
        paymentRepositoryProvider.overrideWithValue(repo),
        accountRefreshProvider.overrideWithValue(() async {
          refreshes++;
          return true;
        }),
      ],
      seed: seedIndividualPaid,
    );

    await tester.tap(find.byKey(cancelKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.payments_confirmCancellation));
    await tester.pumpAndSettle();

    expect(repo.cancelCalls, 1);
    expect(refreshes, 0, reason: 'a refusal changed nothing to pull');
    expect(find.text(l.payments_cancelNoActivePlan), findsOneWidget);
    // The plan is still running, so the action is still offered.
    expect(find.byKey(cancelKey), findsOneWidget);
    expect(find.text(l.payments_statusCancelled), findsNothing);

    await unmountApp(tester);
  });

  testWidgets('cancellations and purchases share one newest-first ledger', (
    tester,
  ) async {
    await pumpDetails(
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
      seed: seedIndividualPaid,
    );

    // Both moments are drawn, newest first: the cancellation is card 1 and the
    // purchase it ended is card 2.
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