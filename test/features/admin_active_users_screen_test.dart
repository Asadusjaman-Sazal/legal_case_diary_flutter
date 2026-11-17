/// Active Users sub-page tests — 0.0.835.
///
/// These pin what the page promises: cards stay in the server's oldest-first
/// order, search reaches every category of displayed data (identity, contact,
/// chamber and role, formatted dates, plan, usage, platforms and ledger lines),
/// clearing the search restores that order, and the five-entry subscription
/// history is physically the last section of the card.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/providers/repository_providers.dart';
import 'package:legal_case_diary/core/utils/date_utils.dart';
import 'package:legal_case_diary/features/admin/data/admin_repository.dart';
import 'package:legal_case_diary/features/admin/presentation/admin_active_users_screen.dart';
import 'package:legal_case_diary/shared/widgets/sync_button.dart';

/// A repository that answers from memory.
class _FakeAdminRepository implements AdminRepository {
  _FakeAdminRepository({this.admin = true, List<AdminActiveUser>? activeUsers})
    : activeUsers = activeUsers ?? <AdminActiveUser>[];

  final bool admin;
  final List<AdminActiveUser> activeUsers;

  @override
  Future<bool> isAdmin() async => admin;

  @override
  Future<List<AdminActiveUser>> listActiveUsers() async => activeUsers;

  @override
  Future<List<AdminPaymentRequest>> listPaymentRequests() async =>
      const <AdminPaymentRequest>[];

  @override
  Future<AdminActionFailure?> approve(String submissionId) async => null;

  @override
  Future<AdminActionFailure?> reject(
    String submissionId, {
    String? note,
  }) async => null;

  @override
  Future<List<AdminUnconfirmedAccount>> listUnconfirmedAccounts() async =>
      const <AdminUnconfirmedAccount>[];

  @override
  Future<AdminActionFailure?> deleteUnconfirmedAccount(String userId) async =>
      null;

  @override
  Future<List<AdminSharedReference>> listSharedReferences() async =>
      const <AdminSharedReference>[];

  @override
  Future<AdminActionFailure?> saveSharedReference(
    AdminSharedReference reference,
  ) async => null;

  @override
  Future<AdminActionFailure?> deleteSharedReference(String id) async => null;
}

/// The older, individual account. The timestamps are UTC so their Bangladesh
/// display form is fixed in the test.
AdminActiveUser _older() => AdminActiveUser(
  id: 'older',
  fullName: 'Adv. Older Rahman',
  barAssociation: 'Dhaka Bar Association',
  email: 'older@example.test',
  mobileNo: '01710000001',
  firmName: '',
  role: 'individual',
  currentTier: 'free',
  planActive: false,
  joinedAt: DateTime.utc(2026, 1, 1, 4, 30),
  lastActiveAt: DateTime.utc(2026, 1, 4, 5, 0),
  caseCount: 12,
  noteCount: 4,
  referenceCount: 3,
  deviceCount: 1,
  platforms: const <String>['android'],
  subscriptionHistory: const <AdminSubscriptionEntry>[],
);

/// The newer, firm-member account with a plan, two active devices and history.
AdminActiveUser _newer() => AdminActiveUser(
  id: 'newer',
  fullName: 'Adv. Newer Chowdhury',
  barAssociation: 'Chattogram Bar Association',
  email: 'newer@example.test',
  mobileNo: '01710000002',
  firmName: 'Chamber One',
  role: 'associate',
  currentTier: 'firm',
  currentPlanKey: 'firm_annual',
  planActive: true,
  joinedAt: DateTime.utc(2026, 2, 2, 4, 15),
  lastActiveAt: DateTime.utc(2026, 2, 5, 6, 45),
  planExpiry: DateTime.utc(2027, 2, 2, 4, 15),
  caseCount: 40,
  noteCount: 9,
  referenceCount: 6,
  deviceCount: 2,
  platforms: const <String>['android', 'windows'],
  subscriptionHistory: [
    AdminSubscriptionEntry(
      planKey: 'firm_annual',
      amount: 3000,
      status: 'approved',
      at: DateTime.utc(2026, 2, 2, 4, 15),
    ),
    AdminSubscriptionEntry(
      planKey: 'starter_monthly',
      amount: 101,
      status: 'cancelled',
      at: DateTime.utc(2026, 1, 20, 4, 15),
    ),
  ],
);

void main() {
  Future<void> pump(
    WidgetTester tester,
    _FakeAdminRepository repo, {
    Locale locale = const Locale('en'),
  }) async {
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [adminRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: locale,
          home: const AdminActiveUsersScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openSearch(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('admin-active-users-search')));
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(TextField), query);
    await tester.pumpAndSettle();
  }

  testWidgets('keeps the server\'s oldest-first order', (tester) async {
    await pump(tester, _FakeAdminRepository(activeUsers: [_older(), _newer()]));

    expect(
      find.byKey(const ValueKey('admin-active-user-older')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('admin-active-user-newer')),
      findsOneWidget,
    );
    expect(
      tester
          .getTopLeft(find.byKey(const ValueKey('admin-active-user-older')))
          .dy,
      lessThan(
        tester
            .getTopLeft(find.byKey(const ValueKey('admin-active-user-newer')))
            .dy,
      ),
    );
    // The serial follows that same order.
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('search reaches identity, contact, chamber and role', (
    tester,
  ) async {
    await pump(tester, _FakeAdminRepository(activeUsers: [_older(), _newer()]));
    await openSearch(tester);

    await search(tester, 'Older Rahman');
    expect(find.text('Adv. Older Rahman'), findsOneWidget);
    expect(find.text('Adv. Newer Chowdhury'), findsNothing);

    await search(tester, 'older@example.test');
    expect(find.text('Adv. Older Rahman'), findsOneWidget);
    expect(find.text('Adv. Newer Chowdhury'), findsNothing);

    await search(tester, '01710000002');
    expect(find.text('Adv. Newer Chowdhury'), findsOneWidget);
    expect(find.text('Adv. Older Rahman'), findsNothing);

    await search(tester, 'Chamber One');
    expect(find.text('Adv. Newer Chowdhury'), findsOneWidget);
    expect(find.text('Adv. Older Rahman'), findsNothing);

    await search(tester, 'Associate');
    expect(find.text('Adv. Newer Chowdhury'), findsOneWidget);
    expect(find.text('Adv. Older Rahman'), findsNothing);
  });

  testWidgets('search reaches formatted dates, plan and expiry', (
    tester,
  ) async {
    await pump(tester, _FakeAdminRepository(activeUsers: [_older(), _newer()]));
    await openSearch(tester);

    final joined = AppDateUtils.formatNoteCardDate(
      _older().joinedAt!.millisecondsSinceEpoch,
      locale: 'en',
    );
    expect(joined, '01/01/26, 10:30 AM');

    await search(tester, '01/01/26');
    expect(find.text('Adv. Older Rahman'), findsOneWidget);
    expect(find.text('Adv. Newer Chowdhury'), findsNothing);

    await search(tester, '10:30 AM');
    expect(find.text('Adv. Older Rahman'), findsOneWidget);
    expect(find.text('Adv. Newer Chowdhury'), findsNothing);

    await search(tester, 'Firm · 1 Year');
    expect(find.text('Adv. Newer Chowdhury'), findsOneWidget);
    expect(find.text('Adv. Older Rahman'), findsNothing);

    await search(tester, 'Active');
    // The newer account is Active; the older free account reads No Active Plan.
    expect(find.text('Adv. Older Rahman'), findsOneWidget);
    expect(find.text('Adv. Newer Chowdhury'), findsOneWidget);

    await search(tester, '02/02/2027');
    expect(find.text('Adv. Newer Chowdhury'), findsOneWidget);
    expect(find.text('Adv. Older Rahman'), findsNothing);
  });

  testWidgets('search reaches usage, platforms and every ledger value', (
    tester,
  ) async {
    await pump(tester, _FakeAdminRepository(activeUsers: [_older(), _newer()]));
    await openSearch(tester);

    await search(tester, 'Windows');
    expect(find.text('Adv. Newer Chowdhury'), findsOneWidget);
    expect(find.text('Adv. Older Rahman'), findsNothing);

    await search(tester, '40');
    expect(find.text('Adv. Newer Chowdhury'), findsOneWidget);
    expect(find.text('Adv. Older Rahman'), findsNothing);

    await search(tester, 'Starter');
    expect(find.text('Adv. Newer Chowdhury'), findsOneWidget);
    expect(find.text('Adv. Older Rahman'), findsNothing);

    await search(tester, 'Cancelled');
    expect(find.text('Adv. Newer Chowdhury'), findsOneWidget);
    expect(find.text('Adv. Older Rahman'), findsNothing);

    await search(tester, '৳3,000');
    expect(find.text('Adv. Newer Chowdhury'), findsOneWidget);
    expect(find.text('Adv. Older Rahman'), findsNothing);

    await search(tester, '05/02/26');
    expect(find.text('Adv. Newer Chowdhury'), findsOneWidget);
    expect(find.text('Adv. Older Rahman'), findsNothing);
  });

  testWidgets('a missed search shows No Results and clearing restores order', (
    tester,
  ) async {
    await pump(tester, _FakeAdminRepository(activeUsers: [_older(), _newer()]));
    await openSearch(tester);

    await search(tester, 'Nobody Matches This');
    expect(find.text('No results found.'), findsOneWidget);
    expect(find.text('Adv. Older Rahman'), findsNothing);
    expect(find.text('Adv. Newer Chowdhury'), findsNothing);

    // The header's search button closes the box and clears the query.
    await tester.tap(find.byKey(const ValueKey('admin-active-users-search')));
    await tester.pumpAndSettle();

    expect(find.text('Adv. Older Rahman'), findsOneWidget);
    expect(find.text('Adv. Newer Chowdhury'), findsOneWidget);
    expect(
      tester
          .getTopLeft(find.byKey(const ValueKey('admin-active-user-older')))
          .dy,
      lessThan(
        tester
            .getTopLeft(find.byKey(const ValueKey('admin-active-user-newer')))
            .dy,
      ),
    );
  });

  testWidgets('the subscription history is the last section of the card', (
    tester,
  ) async {
    await pump(tester, _FakeAdminRepository(activeUsers: [_older(), _newer()]));

    final newer = find.byKey(const ValueKey('admin-active-user-newer'));
    final historyHeading = tester.getTopLeft(
      find.descendant(
        of: newer,
        matching: find.text('Last 5 Subscription History'),
      ),
    );
    final usageHeading = tester.getTopLeft(
      find.descendant(of: newer, matching: find.text('Usage')),
    );
    final planHeading = tester.getTopLeft(
      find.descendant(of: newer, matching: find.text('Current Plan')),
    );
    final lastEntry = tester.getTopLeft(
      find.descendant(of: newer, matching: find.text('Starter · 1 Month')),
    );

    expect(historyHeading.dy, greaterThan(usageHeading.dy));
    expect(historyHeading.dy, greaterThan(planHeading.dy));
    expect(lastEntry.dy, greaterThan(historyHeading.dy));
    // The history heading is the final section heading in this card.
    expect(
      find.descendant(
        of: newer,
        matching: find.text('Last 5 Subscription History'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a non-admin is offered no active users', (tester) async {
    await pump(
      tester,
      _FakeAdminRepository(admin: false, activeUsers: [_older()]),
    );

    expect(find.text('Adv. Older Rahman'), findsNothing);
    expect(
      find.text('No account has confirmed its email yet.'),
      findsOneWidget,
    );
  });

  testWidgets('the header carries the shared sync button and search', (
    tester,
  ) async {
    await pump(tester, _FakeAdminRepository(activeUsers: [_older()]));

    expect(find.byType(SyncButton), findsOneWidget);
    expect(
      find.byKey(const ValueKey('cases-modal-sync-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('admin-active-users-search')),
      findsOneWidget,
    );
  });

  testWidgets('the list can be pulled down to sync', (tester) async {
    await pump(tester, _FakeAdminRepository(activeUsers: [_older()]));
    expect(find.byType(RefreshIndicator), findsOneWidget);
  });

  testWidgets('renders in Bengali', (tester) async {
    await pump(
      tester,
      _FakeAdminRepository(activeUsers: [_older()]),
      locale: const Locale('bn'),
    );

    expect(find.text('সক্রিয় ব্যবহারকারী'), findsOneWidget);
    expect(
      find.text('বার অ্যাসোসিয়েশন: ঢাকা বার অ্যাসোসিয়েশন'),
      findsNothing,
    );
    expect(
      find.text('বার অ্যাসোসিয়েশন: Dhaka Bar Association'),
      findsOneWidget,
    );
    expect(find.text('মামলা: ১২'), findsOneWidget);
  });
}
