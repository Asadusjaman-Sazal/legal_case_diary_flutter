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

/// A repository that answers from memory; the menu itself reads no payment data,
/// but the badge's count provider does.
class _FakeAdminRepository implements AdminRepository {
  _FakeAdminRepository({List<AdminPaymentRequest>? rows})
    : rows = rows ?? <AdminPaymentRequest>[];

  final List<AdminPaymentRequest> rows;

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
      const <AdminUnconfirmedAccount>[];

  @override
  Future<AdminActionFailure?> deleteUnconfirmedAccount(String userId) async =>
      null;
}

const List<String> _routeMarkers = <String>[
  '/admin-panel/payment-requests',
  '/admin-panel/unverified-accounts',
];

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
        'Sign-Ups That Never Confirmed',
      ],
    );
  });

  testWidgets('each entry opens its own page', (tester) async {
    for (final marker in _routeMarkers) {
      await pump(
        tester,
        _FakeAdminRepository(),
        routeMarker: <String>[marker],
      );

      final title = marker.endsWith('payment-requests')
          ? 'Payment Requests'
          : 'Non-verified Accounts';
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();

      expect(find.text('at $marker'), findsOneWidget, reason: marker);
    }
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
