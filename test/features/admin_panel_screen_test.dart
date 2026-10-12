/// Admin Panel tests — Task 22 / 0.0.459.
///
/// The panel is now a **menu**: two [SettingsMenuCard] rows opening pages of
/// their own, keeping the case screens' header (hamburger, Sync Status badge,
/// Sync button). These pin what only the panel itself can promise — the two
/// entries and where they go, the header shape, and the bottom-bar gate. The
/// pages themselves are pinned by their own suites
/// (`admin_payment_requests_screen_test.dart`,
/// `admin_unconfirmed_accounts_screen_test.dart`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/providers/repository_providers.dart';
import 'package:legal_case_diary/core/router/app_router.dart';
import 'package:legal_case_diary/features/admin/data/admin_repository.dart';
import 'package:legal_case_diary/features/admin/presentation/admin_panel_screen.dart';
import 'package:legal_case_diary/features/settings/presentation/settings_menu_card.dart';
import 'package:legal_case_diary/shared/widgets/bottom_nav_bar.dart';
import 'package:legal_case_diary/shared/widgets/sync_button.dart';
import 'package:legal_case_diary/sync/sync_status_providers.dart';

/// A repository that answers from memory. The menu itself reads only the two
/// counts, but those come from the same lists the sub-pages show.
class _FakeAdminRepository implements AdminRepository {
  _FakeAdminRepository({
    List<AdminPaymentRequest>? rows,
    List<AdminUnconfirmedAccount>? accounts,
  }) : rows = rows ?? <AdminPaymentRequest>[],
       accounts = accounts ?? <AdminUnconfirmedAccount>[];

  final List<AdminPaymentRequest> rows;
  final List<AdminUnconfirmedAccount> accounts;

  /// Calls [syncServiceProvider]'s drain — not these — so nothing here records
  /// them; a test that needs the drain fakes the service instead.
  @override
  Future<bool> isAdmin() async => true;

  @override
  Future<List<AdminPaymentRequest>> listPaymentRequests() async => rows;

  @override
  Future<AdminActionFailure?> approve(String submissionId) async => null;

  @override
  Future<AdminActionFailure?> reject(
    String submissionId, {
    String? note,
  }) async => null;

  @override
  Future<List<AdminUnconfirmedAccount>> listUnconfirmedAccounts() async =>
      accounts;

  @override
  Future<AdminActionFailure?> deleteUnconfirmedAccount(String userId) async =>
      null;
}

/// One pending submission from a named payer.
AdminPaymentRequest _pending(String id) => AdminPaymentRequest(
  id: id,
  userId: 'user-$id',
  planKey: 'annual',
  amount: 960,
  mfsProvider: 'bkash',
  senderNumber: '01712345678',
  transactionId: 'TRX$id',
  status: 'pending',
  submittedAt: DateTime(2026, 10, 1),
  fullName: 'Adv. Sarah Islam',
);

/// One account that never confirmed its address.
AdminUnconfirmedAccount _unconfirmed(String id) => AdminUnconfirmedAccount(
  id: id,
  email: 'abandoned-$id@example.test',
  fullName: '',
  createdAt: DateTime(2026, 10, 8, 14, 30),
);


void main() {
  Future<void> pump(
    WidgetTester tester,
    _FakeAdminRepository repo, {
    Locale locale = const Locale('en'),
    int attention = 0,
    List<String>? routeMarker,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: AppRoutes.adminPanel,
      routes: [
        GoRoute(
          path: AppRoutes.adminPanel,
          builder: (_, _) => const AdminPanelScreen(),
        ),
        for (final marker in routeMarker ?? const <String>[])
          GoRoute(
            path: marker,
            builder: (_, _) => Scaffold(body: Text('at $marker')),
          ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminRepositoryProvider.overrideWithValue(repo),
          syncStatusAttentionProvider.overrideWith(
            (ref) => Stream<int>.value(attention),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: locale,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Taps the panel's row for a page and checks where it lands.
  ///
  /// One page per test rather than a loop: the panel now reads the two counts,
  /// so it holds providers that are still resolving when the first frame is
  /// pumped — and pumping a second whole tree into the same tester while those
  /// are in flight trips Riverpod's "marked as needing to build during build"
  /// assert. That is a test-harness artifact (the app never rebuilds its root
  /// scope), so the fix is one pump per test.
  Future<void> opensPage(
    WidgetTester tester, {
    required String marker,
    required String title,
  }) async {
    await pump(
      tester,
      _FakeAdminRepository(),
      routeMarker: <String>[marker],
    );

    await tester.tap(find.text(title));
    await tester.pumpAndSettle();

    expect(find.text('at $marker'), findsOneWidget, reason: marker);
  }

  testWidgets('offers the two pages the panel holds', (tester) async {
    await pump(tester, _FakeAdminRepository());

    expect(find.byType(SettingsMenuCard), findsNWidgets(2));
    final cards = tester
        .widgetList<SettingsMenuCard>(find.byType(SettingsMenuCard))
        .toList();
    expect(
      cards.map((card) => card.title),
      <String>['Payment Requests', 'Non-verified Accounts'],
    );
    expect(
      cards.map((card) => card.subtitle),
      <String>[
        'Approve Or Reject Submitted Payments',
        'Sign-Ups Unconfirmed For Over 72 Hours',
      ],
    );
  });

  testWidgets('the Payment Requests entry opens its own page', (tester) async {
    await opensPage(
      tester,
      marker: '/admin-panel/payment-requests',
      title: 'Payment Requests',
    );
  });

  testWidgets('the Non-verified Accounts entry opens its own page', (
    tester,
  ) async {
    await opensPage(
      tester,
      marker: '/admin-panel/unverified-accounts',
      title: 'Non-verified Accounts',
    );
  });

  testWidgets('each row carries the count of what is waiting in it', (
    tester,
  ) async {
    await pump(
      tester,
      _FakeAdminRepository(
        // Two pending payments (the third is already decided, so it must not
        // count) and three abandoned sign-ups.
        rows: [
          _pending('1'),
          _pending('2'),
          AdminPaymentRequest(
            id: '3',
            userId: 'user-3',
            planKey: 'annual',
            amount: 960,
            mfsProvider: 'bkash',
            senderNumber: '01712345678',
            transactionId: 'TRX3',
            status: 'approved',
            submittedAt: DateTime(2026, 10, 1),
            approvedAt: DateTime(2026, 10, 2),
          ),
        ],
        accounts: [_unconfirmed('a'), _unconfirmed('b'), _unconfirmed('c')],
      ),
    );

    final cards = tester
        .widgetList<SettingsMenuCard>(find.byType(SettingsMenuCard))
        .toList();
    // The count sits in the trailing slot, beside the row's text, where the
    // shared chevron would otherwise be.
    for (final card in cards) {
      expect(card.trailing, isA<Text>());
    }
    expect((cards[0].trailing as Text).data, '2', reason: 'pending payments');
    expect((cards[1].trailing as Text).data, '3', reason: 'unconfirmed');
  });

  testWidgets('the panel can be pulled down to sync', (tester) async {
    await pump(tester, _FakeAdminRepository());
    expect(find.byType(RefreshIndicator), findsOneWidget);
  });

  testWidgets('the header is the case screens\', without their own controls', (
    tester,
  ) async {
    await pump(tester, _FakeAdminRepository());

    // The drawer menu is present and there is no back arrow beside it — this is
    // a top-level destination, not one of its own sub-pages.
    expect(find.byIcon(Icons.menu), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);

    // Search and the view toggle belong to a case list; neither has anything
    // to act on here. (The search lives on the two sub-pages instead.)
    expect(find.byIcon(Icons.search), findsNothing);
    expect(find.byKey(const ValueKey('cases-modal-view-toggle')), findsNothing);
  });

  testWidgets('no Sync Status badge when nothing is held', (tester) async {
    await pump(tester, _FakeAdminRepository());
    expect(find.byKey(const ValueKey('admin-panel-sync-status')), findsNothing);
  });

  testWidgets('the Sync Status badge appears when work is held', (
    tester,
  ) async {
    await pump(tester, _FakeAdminRepository(), attention: 2);
    expect(
      find.byKey(const ValueKey('admin-panel-sync-status')),
      findsOneWidget,
    );
  });

  testWidgets("the Sync Status badge counts in the language's own digits", (
    tester,
  ) async {
    await pump(
      tester,
      _FakeAdminRepository(),
      locale: const Locale('bn'),
      attention: 2,
    );

    // The panel carries the case screens' badge, digits and all: `Badge.count`
    // would paint Latin ones, which a Bengali admin must never be shown.
    final badge = find.descendant(
      of: find.byKey(const ValueKey('admin-panel-sync-status')),
      matching: find.byType(Badge),
    );
    expect(badge, findsOneWidget);
    expect(
      find.descendant(of: badge, matching: find.text('২')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: badge, matching: find.text('2')),
      findsNothing,
      reason: 'the count was painted in Latin digits',
    );
  });

  testWidgets('the header carries the shared sync button', (tester) async {
    await pump(tester, _FakeAdminRepository());

    // The same widget the case screens use, so one change fixes both headers.
    expect(find.byType(SyncButton), findsOneWidget);
    expect(
      find.byKey(const ValueKey('cases-modal-sync-button')),
      findsOneWidget,
    );
  });

  testWidgets('renders in Bengali', (tester) async {
    await pump(tester, _FakeAdminRepository(), locale: const Locale('bn'));

    expect(find.text('অ্যাডমিন প্যানেল'), findsOneWidget);
    expect(find.text('পেমেন্ট অনুরোধ'), findsOneWidget);
    expect(find.text('অযাচিত অ্যাকাউন্ট'), findsOneWidget);
  });

  test('the panel is offered in the bottom bar only to an admin', () {
    final adminTab = bottomNavTabDefs.singleWhere(
      (def) => def.route == '/admin-panel',
    );
    expect(adminTab.adminOnly, isTrue);
    // Last in the canonical order, so enabling it never displaces a case
    // screen an admin already arranged.
    expect(bottomNavTabDefs.last.key, 'admin_panel');
  });
}
