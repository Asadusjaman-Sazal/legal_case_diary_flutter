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

import 'package:drift/drift.dart' show InsertMode, Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:legal_case_diary/core/constants/app_colors.dart';
import 'package:legal_case_diary/core/constants/app_spacing.dart';
import 'package:legal_case_diary/core/constants/app_typography.dart';
import 'package:legal_case_diary/core/constants/free_tier.dart';
import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/providers/device_providers.dart';
import 'package:legal_case_diary/core/providers/repository_providers.dart';
import 'package:legal_case_diary/core/router/app_router.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/account_mode.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/local/firms_dao.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/local/profiles_dao.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/profile_repository.dart';
import 'package:legal_case_diary/features/auth/data/auth_repository.dart';
import 'package:legal_case_diary/features/auth/data/device_registration.dart';
import 'package:legal_case_diary/features/payments/data/payment_plans.dart';
import 'package:legal_case_diary/features/payments/data/payment_repository.dart';
import 'package:legal_case_diary/features/payments/presentation/current_plan.dart';
import 'package:legal_case_diary/features/settings/presentation/settings_menu_card.dart';
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

/// A device gate whose answer the test fixes.
class _ActiveGate extends DeviceGateController {
  _ActiveGate(this.currentState);

  /// The state this gate builds with.
  final DeviceGateState currentState;

  @override
  Future<DeviceGateState> build() async => currentState;
}

/// An admitted device list: [count] active devices under a [cap]-device plan.
DeviceGateState activeGate({int cap = 2, int count = 1}) => DeviceGateState(
  status: DeviceGateStatus.active,
  cap: cap,
  devices: [
    for (var i = 0; i < count; i++)
      RegisteredDevice(
        id: 'device-$i',
        label: 'Device $i',
        platform: 'android',
        isCurrent: i == 0,
      ),
  ],
);

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
        GoRoute(
          path: AppRoutes.paywall,
          builder: (_, _) => const Scaffold(body: Text('Plans-Landed')),
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

  const cancelKey = ValueKey('subscription-details-cancel');
  final renewKey = const ValueKey('manage-plan-renew');

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
        tier: const Value('firm'),
        subscriptionStatus: const Value('active'),
        subscriptionExpiry: Value(
          DateTime.utc(2026, 12, 1, 17, 30).millisecondsSinceEpoch,
        ),
        createdAt: const Value(1),
      ),
    );
  }

  /// A paid individual whose period is over but whose tier is kept: Pro's 250
  /// is what Limited Access still allows.
  Future<void> seedIndividualEnded(AppDatabase db) => ProfilesDao(db).upsert(
    ProfilesCompanion(
      id: const Value('user-1'),
      fullName: const Value('Adv. Rahim Uddin'),
      role: const Value(AccountRole.individual),
      tier: const Value('pro'),
      subscriptionStatus: const Value('expired'),
      subscriptionExpiry: Value(
        DateTime.utc(2026, 10, 1, 17, 30).millisecondsSinceEpoch,
      ),
      createdAt: const Value(1),
    ),
  );

  /// Payments that bought the Pro quarter a cancellation later ended.
  List<Override> paidProOverrides() => <Override>[
    myPaymentSubmissionsProvider.overrideWith(
      (ref) async => [
        submission(
          id: 'p1',
          planType: paymentPlanProQuarterly,
          amount: 360,
          status: 'approved',
          submittedAt: DateTime.utc(2026, 10, 1, 10),
          approvedAt: DateTime.utc(2026, 10, 1, 12),
        ),
      ],
    ),
  ];

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
    expect(find.text(l.settingsSubscription_freePlanLimitations), findsNothing);

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
      // own approved Starter row is ignored, and the card names the chamber's
      // own plan rather than the generic *Premium* (user request, 0.0.699).
      expect(find.text(l.paywall_tierFirm), findsWidgets);
      expect(find.text(l.settingsManageAccount_planPremium), findsNothing);

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
    // Every limitation is listed; the case ceiling comes from the one constant
    // and is the bold phrase in its row.
    expect(
      find.textContaining(
        l.settingsSubscription_freeLimitCasesBold('$freeTierCaseLimit'),
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        l.settingsSubscription_freeLimitCloud,
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        l.settingsSubscription_freeLimitRecoveryBold,
        findRichText: true,
      ),
      findsOneWidget,
    );

    // The upgrade offer follows the limitations: the three per-month rates
    // (3-month ৳60, 6-month ৳50, 1-year ৳45 — the last is why it says
    // "starting at"), the hint and the centred button.
    expect(find.text(l.settingsSubscription_upgradeTitle), findsOneWidget);
    expect(find.text(l.settingsSubscription_upgradeBody), findsOneWidget);
    expect(
      find.textContaining(
        l.settingsSubscription_upgradeRate('60'),
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        l.settingsSubscription_upgradeRate('50'),
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        l.settingsSubscription_upgradeRate('45'),
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(find.text(l.settingsSubscription_upgradeHint), findsOneWidget);
    expect(find.byKey(const ValueKey('manage-plan-upgrade')), findsOneWidget);
    // Usage and the subscription actions belong to a live paid plan only.
    expect(find.text(l.settingsSubscription_planUsage), findsNothing);
    expect(find.byKey(renewKey), findsNothing);
    expect(find.byKey(cancelKey), findsNothing);

    await unmountApp(tester);
  });

  testWidgets('the upgrade button opens Subscription Plans', (tester) async {
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

    final button = find.byKey(const ValueKey('manage-plan-upgrade'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(find.text('Plans-Landed'), findsOneWidget);

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
    expect(find.text(l.settingsSubscription_freePlanLimitations), findsNothing);

    await unmountApp(tester);
  });

  testWidgets('the expiry row gives its value the space it needs', (
    tester,
  ) async {
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

  testWidgets(
    'the Free Plan Limitations heading has no bullet and its bullets are black',
    (tester) async {
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

      // The three limitation dots and the three rate dots are black; the heading
      // carries no dot at all, so exactly six 6 px circles remain and none of
      // them is the error red.
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
      expect(
        dots,
        hasLength(6),
        reason: 'three limitations and three rates, no heading bullet',
      );
      for (final dot in dots) {
        expect(dotColor(dot), AppColors.secondary, reason: 'bullets are black');
      }

      await unmountApp(tester);
    },
  );

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

  /// [count] live cases in the diary the tier limits, [firmId] for a chamber.
  ///
  /// The reference rows a case points at are seeded once: this harness's
  /// database enforces the foreign keys, which the case-count query itself
  /// never touches.
  Future<void> seedCases(AppDatabase db, int count, {String? firmId}) async {
    await db
        .into(db.courtCategories)
        .insert(
          const CourtCategoriesCompanion(
            id: Value('cat-1'),
            nameKey: Value('catKey'),
            courtLevel: Value('lower'),
            orderIndex: Value(0),
            updatedAt: Value(1),
          ),
          mode: InsertMode.insertOrIgnore,
        );
    await db
        .into(db.courts)
        .insert(
          const CourtsCompanion(
            id: Value('court-1'),
            courtName: Value('Court'),
            higherLowerCourts: Value('lower_courts'),
            courtCategoryId: Value('cat-1'),
            updatedAt: Value(1),
          ),
          mode: InsertMode.insertOrIgnore,
        );
    await db
        .into(db.onBehalfs)
        .insert(
          const OnBehalfsCompanion(
            id: Value('role-1'),
            courtCategoryId: Value('cat-1'),
            name: Value('Plaintiff'),
            orderIndex: Value(0),
            updatedAt: Value(1),
          ),
          mode: InsertMode.insertOrIgnore,
        );
    for (var i = 0; i < count; i++) {
      await db
          .into(db.cases)
          .insert(
            CasesCompanion(
              id: Value('case-$firmId-$i'),
              userId: const Value('user-1'),
              firmId: Value(firmId),
              courtId: const Value('court-1'),
              caseType: const Value('Civil'),
              caseNumber: Value('N$i'),
              petitioner: const Value('Petitioner'),
              respondent: const Value('Respondent'),
              onBehalfId: const Value('role-1'),
              createdAt: Value(i + 1),
              updatedAt: Value(i + 1),
              isDeleted: const Value(false),
            ),
          );
    }
  }

  testWidgets('a paid plan shows its usage and both full-width actions', (
    tester,
  ) async {
    await pumpDetails(
      tester,
      overrides: [
        deviceGateProvider.overrideWith(
          () => _ActiveGate(activeGate(cap: 2, count: 1)),
        ),
      ],
      seed: (db) async {
        await seedIndividualPaid(db);
        await seedCases(db, 3);
      },
    );

    expect(find.text(l.settingsSubscription_planUsage), findsOneWidget);
    expect(
      find.text(l.settingsSubscription_manageSubscription),
      findsOneWidget,
    );

    // Pro holds 1,000 cases: three live rows leave 997.
    expect(
      find.text(l.settingsSubscription_usageOfLimit('3', '1,000')),
      findsOneWidget,
    );
    expect(
      find.text(l.settingsSubscription_usageRemaining('997')),
      findsOneWidget,
    );
    // Pro holds two devices, one of which is signed in.
    expect(
      find.text(l.settingsSubscription_usageOfLimit('1', '2')),
      findsOneWidget,
    );
    expect(
      find.text(l.settingsSubscription_usageRemaining('1')),
      findsOneWidget,
    );

    // Both actions are the page's primary size and span its full width, so the
    // old header Cancel is gone rather than restyled.
    for (final action in [renewKey, cancelKey]) {
      final rect = tester.getRect(find.byKey(action));
      expect(rect.left, closeTo(AppSpacing.edgeMargin, 1.0));
      expect(rect.right, closeTo(420 - AppSpacing.edgeMargin, 1.0));
      expect(rect.height, closeTo(settingsPrimaryButtonHeight, 1.0));
    }
    expect(
      tester
          .widget<FilledButton>(find.byKey(renewKey))
          .style
          ?.backgroundColor
          ?.resolve(<WidgetState>{}),
      AppColors.primary,
    );
    // A filled red action with white text (user request).
    final cancel = tester.widget<FilledButton>(find.byKey(cancelKey));
    expect(
      cancel.style?.backgroundColor?.resolve(<WidgetState>{}),
      AppColors.error,
    );
    expect(
      cancel.style?.foregroundColor?.resolve(<WidgetState>{}),
      AppColors.onError,
    );

    await unmountApp(tester);
  });

  testWidgets('Renew opens Subscription Plans', (tester) async {
    await pumpDetails(tester, seed: seedIndividualPaid);

    await tester.ensureVisible(find.byKey(renewKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(renewKey));
    await tester.pumpAndSettle();

    expect(find.text('Plans-Landed'), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('a chamber member sees usage and the owner note, no actions', (
    tester,
  ) async {
    await pumpDetails(
      tester,
      overrides: [
        firmMemberProvider.overrideWithValue(true),
        deviceGateProvider.overrideWith(
          () => _ActiveGate(activeGate(cap: 1, count: 1)),
        ),
      ],
      seed: (db) async {
        await seedMember(db);
        // The chamber's own tier, which the member's ceiling comes from.
        await FirmsDao(db).upsert(
          FirmsCompanion(
            id: const Value('firm-1'),
            name: const Value('Rahman & Associates'),
            ownerId: const Value('user-2'),
            tier: const Value('firm'),
            subscriptionStatus: const Value('active'),
            subscriptionExpiry: Value(
              DateTime.utc(2026, 12, 1, 17, 30).millisecondsSinceEpoch,
            ),
            createdAt: const Value(1),
          ),
        );
        await seedCases(db, 2, firmId: 'firm-1');
      },
    );

    expect(find.text(l.settingsSubscription_planUsage), findsOneWidget);
    // The chamber's Firm tier: 2,500 cases, counted across the chamber.
    expect(
      find.text(l.settingsSubscription_usageOfLimit('2', '2,500')),
      findsOneWidget,
    );
    expect(
      find.text(l.settingsSubscription_usageRemaining('2,498')),
      findsOneWidget,
    );
    // A chamber always holds one device, and it is this one.
    expect(
      find.text(l.settingsSubscription_usageRemaining('0')),
      findsOneWidget,
    );
    expect(find.text(l.settingsSubscription_usageFirmNote), findsOneWidget);

    // The chamber's plan is the one they read, so the page is named for it
    // (user request, 0.0.698) and the card names the chamber's own tier rather
    // than the generic *Premium* (0.0.699).
    expect(find.text(l.settingsSubscription_firmPlanTitle), findsOneWidget);
    expect(find.text(l.settingsSubscription_managePlanTitle), findsNothing);
    expect(find.text(l.paywall_tierFirm), findsWidgets);
    expect(find.text(l.settingsManageAccount_planPremium), findsNothing);

    // The owner buys for the chamber: the note replaces both actions, and it
    // reads as a justified paragraph.
    expect(find.text(l.paywall_memberPlanBody), findsOneWidget);
    expect(
      tester.widget<Text>(find.text(l.paywall_memberPlanBody)).textAlign,
      TextAlign.justify,
    );
    expect(find.byKey(renewKey), findsNothing);
    expect(find.byKey(cancelKey), findsNothing);

    await unmountApp(tester);
  });

  testWidgets('a chamber owner counts the chamber\'s cases only', (
    tester,
  ) async {
    await pumpDetails(
      tester,
      overrides: [
        deviceGateProvider.overrideWith(
          () => _ActiveGate(activeGate(cap: 1, count: 1)),
        ),
      ],
      seed: (db) async {
        await seedOwner(db);
        await FirmsDao(db).upsert(
          FirmsCompanion(
            id: const Value('firm-1'),
            name: const Value('Rahman & Associates'),
            ownerId: const Value('user-1'),
            tier: const Value('firm'),
            subscriptionStatus: const Value('active'),
            subscriptionExpiry: Value(
              DateTime.utc(2026, 12, 1, 17, 30).millisecondsSinceEpoch,
            ),
            createdAt: const Value(1),
          ),
        );
        await seedCases(db, 2, firmId: 'firm-1');
        await seedCases(db, 1);
      },
    );

    // The server counts a chamber's ceiling by `firm_id`, so the private row
    // is not part of the number.
    expect(
      find.text(l.settingsSubscription_usageOfLimit('2', '2,500')),
      findsOneWidget,
    );
    expect(
      find.text(l.settingsSubscription_usageRemaining('2,498')),
      findsOneWidget,
    );
    expect(find.text(l.settingsSubscription_usageFirmNote), findsOneWidget);
    expect(find.byKey(renewKey), findsOneWidget);
    expect(find.byKey(cancelKey), findsOneWidget);

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

      await tester.ensureVisible(find.byKey(cancelKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(cancelKey));
      await tester.pumpAndSettle();

      expect(find.text(l.payments_cancelTitle), findsOneWidget);
      expect(find.text(l.payments_cancelWarning), findsOneWidget);
      expect(find.text(l.payments_goBack), findsOneWidget);
      expect(find.text(l.payments_confirmCancellation), findsOneWidget);

      // The shared frame's 8 px corner, this window's own ~10% wider inset,
      // its extra body room, and the shared 48 px stacked actions.
      final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
      expect(
        (dialog.shape! as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(AppSpacing.cardRadius * 2),
      );
      // The title is middle aligned, like the Exit App window's (0.0.628).
      expect(
        tester.widget<Text>(find.text(l.payments_cancelTitle)).textAlign,
        TextAlign.center,
      );
      final window = tester.getRect(
        find
            .descendant(
              of: find.byType(Dialog),
              matching: find.byWidgetPredicate(
                (w) => w is Material && w.type == MaterialType.card,
              ),
            )
            .first,
      );
      // The 24 px side insets on this 420 px surface.
      expect(window.width, closeTo(420 - 48, 0.5));
      expect(window.left, closeTo(24, 0.5));
      // The body room keeps the window taller than the plain default.
      expect(window.height, closeTo(464, 2));
      expect(window.height, greaterThan(448));

      final goBackRect = tester.getRect(
        find.byKey(const ValueKey('subscription-details-cancel-go-back')),
      );
      final confirmRect = tester.getRect(
        find.byKey(const ValueKey('subscription-details-cancel-confirm')),
      );
      expect(goBackRect.height, 48);
      expect(confirmRect.height, 48);
      // Both actions span the window's inside width, as they always have.
      expect(goBackRect.width, closeTo(window.width - 48, 0.5));
      expect(confirmRect.width, closeTo(window.width - 48, 0.5));

      // The way out is black, the destructive choice is red, both with white
      // text — the two colours the request names.
      Color? background(String key) => tester
          .widget<FilledButton>(find.byKey(ValueKey(key)))
          .style
          ?.backgroundColor
          ?.resolve(<WidgetState>{});
      Color? foreground(String key) => tester
          .widget<FilledButton>(find.byKey(ValueKey(key)))
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

  testWidgets('a confirmed cancellation ends the plan', (tester) async {
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
          (ref) async => repo.cancelCalls == 0
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
    await tester.ensureVisible(find.byKey(cancelKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(cancelKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.payments_confirmCancellation));
    await tester.pumpAndSettle();

    expect(repo.cancelCalls, 1);
    expect(refreshes, 1);

    // The plan is on Limited Access: the tier it held still names it, with
    // the red tag beside it, and the block's own title says what that means.
    // `find.text` would match both the `Text.rich` and the `RichText` it
    // builds, so the label itself is the finder.
    expect(
      find.byWidgetPredicate((w) => w is CurrentPlanLabel && w.showTag),
      findsOneWidget,
    );
    expect(find.text(l.settingsSubscription_lapsedTitle), findsOneWidget);
    // The reason is a cancellation, so the card says when rather than showing
    // the backdated expiry the server moved behind the grace window.
    expect(find.text(l.settingsManageAccount_expiry), findsNothing);
    expect(
      find.text(l.settingsSubscription_lapsedBodyCancelled('250')),
      findsOneWidget,
    );

    // The cancellation shows in the card's own Cancelled row; its ledger
    // entry now lives on Subscription History.
    expect(find.text(l.payments_statusCancelled), findsOneWidget);
    expect(find.text('02/12/2026, 11:30 PM'), findsOneWidget);

    // Nothing is left to cancel, so the action is gone with the live plan.
    expect(find.byKey(cancelKey), findsNothing);

    await unmountApp(tester);
  });

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

    await tester.ensureVisible(find.byKey(cancelKey));
    await tester.pumpAndSettle();
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

  testWidgets('a cancelled plan says Cancelled, with the moment it happened', (
    tester,
  ) async {
    await pumpDetails(
      tester,
      overrides: [
        ...paidProOverrides(),
        mySubscriptionCancellationsProvider.overrideWith(
          (ref) async => [
            SubscriptionCancellation(
              id: 'c1',
              planType: paymentPlanProQuarterly,
              amount: 360,
              cancelledAt: DateTime.utc(2026, 12, 2, 17, 30),
            ),
          ],
        ),
      ],
      seed: seedIndividualEnded,
    );

    // The row is the cancellation, not the expiry the server backdated behind
    // the grace window: the moment it happened is what the user came for. It
    // appears once here; the ledger's own entry is on Subscription History.
    expect(find.text(l.payments_statusCancelled), findsOneWidget);
    expect(find.text(l.settingsManageAccount_expiry), findsNothing);
    expect(find.text('02/12/2026, 11:30 PM'), findsOneWidget);

    // And the block says why the access is limited, in the cancelled words.
    expect(find.text(l.settingsSubscription_lapsedTitle), findsOneWidget);
    expect(
      find.text(l.settingsSubscription_lapsedBodyCancelled('250')),
      findsOneWidget,
    );
    expect(find.text(l.settingsSubscription_lapsedBody('250')), findsNothing);

    await unmountApp(tester);
  });

  testWidgets('a plan that simply ran out keeps Expiry and says it expired', (
    tester,
  ) async {
    await pumpDetails(tester, seed: seedIndividualEnded);

    // No cancellation in the ledger, so nothing was cancelled: the expiry is
    // the honest fact and the row stays.
    expect(find.text(l.payments_statusCancelled), findsNothing);
    expect(find.text(l.settingsManageAccount_expiry), findsOneWidget);
    expect(find.text('01/10/2026, 11:30 PM'), findsOneWidget);
    expect(find.text(l.settingsSubscription_lapsedBody('250')), findsOneWidget);
    expect(
      find.text(l.settingsSubscription_lapsedBodyCancelled('250')),
      findsNothing,
    );
    // A lapsed plan has no live usage to report and nothing to cancel.
    expect(find.text(l.settingsSubscription_planUsage), findsNothing);
    expect(find.byKey(renewKey), findsNothing);
    expect(find.byKey(cancelKey), findsNothing);

    await unmountApp(tester);
  });

  testWidgets('every value shares one size, and the plan keeps its weight', (
    tester,
  ) async {
    await pumpDetails(tester, seed: seedIndividualPaid);

    // The section body's size on every value: the card is a list of facts, not
    // a headline above four footnotes (user request).
    for (final value in <String>[
      l.settingsManageAccount_roleIndividual,
      '01/12/2026, 11:30 PM',
    ]) {
      final text = tester.widget<Text>(find.text(value).first);
      expect(
        text.style?.fontSize,
        AppTypography.bodyMd.fontSize,
        reason: value,
      );
    }

    final planLabel = tester.widget<CurrentPlanLabel>(
      find.byWidgetPredicate((w) => w is CurrentPlanLabel && w.showTag),
    );
    expect(planLabel.style?.fontSize, AppTypography.bodyMd.fontSize);
    // Bold, as it was: only the size came down.
    expect(planLabel.style?.fontWeight, FontWeight.w600);

    await unmountApp(tester);
  });

  testWidgets('the Limited Access tag is red and a little smaller', (
    tester,
  ) async {
    await pumpDetails(
      tester,
      overrides: [
        ...paidProOverrides(),
        mySubscriptionCancellationsProvider.overrideWith(
          (ref) async => [
            SubscriptionCancellation(
              id: 'c1',
              planType: paymentPlanProQuarterly,
              amount: 360,
              cancelledAt: DateTime.utc(2026, 12, 2, 17, 30),
            ),
          ],
        ),
      ],
      seed: seedIndividualEnded,
    );

    // The row prints the tier, then the tag as its own span — which is what lets
    // the words be red and smaller than the name beside them. The card's
    // heading carries the name alone, so the tag is stated once.
    final label = find.byWidgetPredicate(
      (w) => w is CurrentPlanLabel && w.showTag,
    );
    expect(label, findsOneWidget);
    final rich = tester.widget<RichText>(
      find.descendant(of: label, matching: find.byType(RichText)),
    );
    // `Text` wraps the span it is given in one carrying the style, so the two
    // printed spans are found by walking the tree rather than by index.
    final spans = <TextSpan>[];
    (rich.text as TextSpan).visitChildren((span) {
      if (span is TextSpan && span.text != null) spans.add(span);
      return true;
    });
    expect(spans.map((span) => span.text), <String>[
      l.paywall_tierPro,
      ' ${l.settingsManageAccount_planLimitedAccessTag}',
    ]);
    expect(spans[1].style?.color, AppColors.error);
    expect(spans[1].style!.fontSize!, lessThan(AppTypography.bodyMd.fontSize!));

    await unmountApp(tester);
  });
}
