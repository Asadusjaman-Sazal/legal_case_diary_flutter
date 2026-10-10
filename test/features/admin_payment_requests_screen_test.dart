/// Payment Requests sub-page tests — Task 22 / 0.0.459.
///
/// This is the Admin Panel's old body, moved to a page of its own when the panel
/// became a menu. It pins what that page promises: a non-admin sees no payment
/// data, the two sections open in the right state, an approve or reject reaches
/// the repository and is followed by a reload rather than a local guess, each
/// card is numbered within its section, and the header's search filters both
/// sections — opening a closed one when it holds the match.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/providers/repository_providers.dart';
import 'package:legal_case_diary/features/admin/data/admin_repository.dart';
import 'package:legal_case_diary/features/admin/presentation/admin_payment_requests_screen.dart';
import 'package:legal_case_diary/features/settings/presentation/settings_menu_card.dart';
import 'package:legal_case_diary/shared/widgets/sync_button.dart';

/// A repository that answers from memory, so the page can be driven without a
/// server and every call it makes is recorded.
class _FakeAdminRepository implements AdminRepository {
  _FakeAdminRepository({this.admin = true, List<AdminPaymentRequest>? rows})
    : rows = rows ?? <AdminPaymentRequest>[];

  final bool admin;
  final List<AdminPaymentRequest> rows;

  /// Calls the screen made, in order.
  final List<String> calls = <String>[];

  /// What [approve] and [reject] answer; null means success.
  AdminActionFailure? failure;

  int listCalls = 0;

  @override
  Future<bool> isAdmin() async => admin;

  @override
  Future<List<AdminPaymentRequest>> listPaymentRequests() async {
    listCalls++;
    return rows;
  }

  @override
  Future<AdminActionFailure?> approve(String submissionId) async {
    calls.add('approve:$submissionId');
    return failure;
  }

  @override
  Future<AdminActionFailure?> reject(
    String submissionId, {
    String? note,
  }) async {
    calls.add('reject:$submissionId:${note ?? ''}');
    return failure;
  }

  @override
  Future<List<AdminUnconfirmedAccount>> listUnconfirmedAccounts() async =>
      const <AdminUnconfirmedAccount>[];

  @override
  Future<AdminActionFailure?> deleteUnconfirmedAccount(String userId) async =>
      null;
}

/// One pending submission from a named payer.
AdminPaymentRequest _request({
  required String id,
  String status = 'pending',
  String name = 'Adv. Sarah Islam',
  DateTime? approvedAt,
  DateTime? rejectedAt,
}) => AdminPaymentRequest(
  id: id,
  userId: 'user-$id',
  planKey: 'annual',
  amount: 960,
  mfsProvider: 'bkash',
  senderNumber: '01712345678',
  transactionId: 'TRX$id',
  status: status,
  submittedAt: DateTime(2026, 10, 1),
  approvedAt: approvedAt,
  rejectedAt: rejectedAt,
  fullName: name,
  email: 'sarah@example.com',
  barAssociation: 'Dhaka Bar Council',
  membershipNo: 'DBC-4471',
  mobileNo: '01712345678',
);

void main() {
  Future<void> pump(
    WidgetTester tester,
    _FakeAdminRepository repo, {
    Locale locale = const Locale('en'),
  }) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [adminRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: locale,
          home: const AdminPaymentRequestsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows both sections, with Pending open and Resolved closed', (
    tester,
  ) async {
    final repo = _FakeAdminRepository(
      rows: <AdminPaymentRequest>[
        _request(id: '1'),
        _request(id: '2', status: 'approved'),
      ],
    );
    await pump(tester, repo);

    // The page's own header names it; there is no separate heading in the body.
    expect(find.text('Payment Requests'), findsOneWidget);
    // The work needs doing, so it is what the page opens on.
    expect(find.byType(SettingsMenuCard), findsNWidgets(2));
    expect(find.text('TrxID: TRX1'), findsOneWidget);
    // The history is a record, not a to-do, and stays folded away.
    expect(find.text('TrxID: TRX2'), findsNothing);

    await tester.tap(find.text('Resolved'));
    await tester.pumpAndSettle();
    expect(find.text('TrxID: TRX2'), findsOneWidget);
  });

  testWidgets('names the plan and amount, and the payer behind it', (
    tester,
  ) async {
    await pump(tester, _FakeAdminRepository(rows: [_request(id: '1')]));

    expect(find.text('Adv. Sarah Islam'), findsOneWidget);
    expect(find.text('1 Year · ৳960'), findsOneWidget);
    // The sender's number is a number, not an amount: no ৳ prefix.
    expect(find.text('01712345678'), findsOneWidget);
    expect(find.text('৳01712345678'), findsNothing);
    // The method is the brand the payer chose, not the stored key.
    expect(find.text('Method: bKash'), findsOneWidget);
    expect(find.text('TrxID: TRX1'), findsOneWidget);
    expect(find.text('Email: sarah@example.com'), findsOneWidget);
    expect(find.text('Bar Association: Dhaka Bar Council'), findsOneWidget);
    expect(find.text('Membership No: DBC-4471'), findsOneWidget);
  });

  testWidgets('each card is numbered within its own section, from 1', (
    tester,
  ) async {
    await pump(
      tester,
      _FakeAdminRepository(
        rows: <AdminPaymentRequest>[
          _request(id: '1'),
          _request(id: '2'),
          _request(id: '3', status: 'approved'),
        ],
      ),
    );

    // Pending holds the first two requests, numbered 1 and 2.
    expect(find.text('1'), findsWidgets);
    expect(find.text('2'), findsWidgets);
    // Resolved's own first card is numbered 1 again, not 3.
    await tester.tap(find.text('Resolved'));
    await tester.pumpAndSettle();
    expect(find.text('3'), findsNothing);
  });

  testWidgets('search filters and opens a closed section holding the match', (
    tester,
  ) async {
    await pump(
      tester,
      _FakeAdminRepository(
        rows: <AdminPaymentRequest>[
          _request(id: '1', name: 'Abdur Rahim'),
          _request(
            id: '2',
            status: 'approved',
            name: 'Mojammel Haque',
            approvedAt: DateTime(2026, 10, 2),
          ),
        ],
      ),
    );

    // Resolved starts closed, so its card is not on screen.
    expect(find.text('TrxID: TRX2'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('admin-payments-search')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Mojammel');
    await tester.pumpAndSettle();

    // The Resolved section was opened by the search, because it holds the match.
    expect(find.text('TrxID: TRX2'), findsOneWidget);
    // And the Pending card that does not match is gone.
    expect(find.text('TrxID: TRX1'), findsNothing);
  });

  testWidgets('a query that matches nothing says so', (tester) async {
    await pump(tester, _FakeAdminRepository(rows: [_request(id: '1')]));

    await tester.tap(find.byKey(const ValueKey('admin-payments-search')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'zzz-nobody');
    await tester.pumpAndSettle();

    expect(find.text('No results found.'), findsWidgets);
    expect(find.text('TrxID: TRX1'), findsNothing);
  });

  testWidgets('approving reaches the repository and then re-reads the list', (
    tester,
  ) async {
    final repo = _FakeAdminRepository(rows: [_request(id: '1')]);
    await pump(tester, repo);
    final listsBefore = repo.listCalls;

    await tester.tap(find.widgetWithText(FilledButton, 'Approve'));
    await tester.pumpAndSettle();

    expect(repo.calls, <String>['approve:1']);
    // The server is the only account of what is resolved, so it is asked again
    // rather than the row being moved locally.
    expect(repo.listCalls, greaterThan(listsBefore));
    expect(find.textContaining('approved'), findsOneWidget);
  });

  testWidgets('rejecting asks for a note and passes it through', (
    tester,
  ) async {
    final repo = _FakeAdminRepository(rows: [_request(id: '1')]);
    await pump(tester, repo);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Reject'));
    await tester.pumpAndSettle();
    // The window is a decision the payer may query, so it is confirmed.
    expect(find.text('Reject This Payment'), findsOneWidget);
    expect(repo.calls, isEmpty);

    await tester.enterText(find.byType(TextField), 'Amount did not arrive');
    await tester.tap(find.widgetWithText(FilledButton, 'Reject Payment'));
    await tester.pumpAndSettle();

    expect(repo.calls, <String>['reject:1:Amount did not arrive']);
  });

  testWidgets('a refusal is reported and the row keeps its actions', (
    tester,
  ) async {
    final repo = _FakeAdminRepository(rows: [_request(id: '1')])
      ..failure = AdminActionFailure.alreadyResolved;
    await pump(tester, repo);

    await tester.tap(find.widgetWithText(FilledButton, 'Approve'));
    await tester.pumpAndSettle();

    expect(find.text('That payment was already decided.'), findsOneWidget);
    // Nothing was resolved, so the admin can still act on it.
    expect(find.widgetWithText(FilledButton, 'Approve'), findsOneWidget);
  });

  testWidgets('a non-admin is offered no payment data at all', (tester) async {
    await pump(
      tester,
      _FakeAdminRepository(
        admin: false,
        rows: [
          _request(id: '1'),
          _request(id: '2', status: 'approved'),
        ],
      ),
    );

    expect(find.text('TrxID: TRX1'), findsNothing);
    expect(find.text('Adv. Sarah Islam'), findsNothing);
    expect(find.text('No payment is waiting for a decision.'), findsOneWidget);
  });

  testWidgets('renders in Bengali with Bengali digits', (tester) async {
    await pump(
      tester,
      _FakeAdminRepository(rows: [_request(id: '1')]),
      locale: const Locale('bn'),
    );

    expect(find.text('পেমেন্ট অনুরোধ'), findsOneWidget);
    expect(find.text('১ বছর · ৳৯৬০'), findsOneWidget);
    expect(find.text('অনুমোদন'), findsOneWidget);
    expect(find.text('বাতিল'), findsOneWidget);
  });

  testWidgets('Pending and Resolved use the Settings sub-menu button shape', (
    tester,
  ) async {
    await pump(
      tester,
      _FakeAdminRepository(
        rows: [
          _request(id: '1'),
          _request(id: '2', status: 'approved'),
        ],
      ),
    );

    expect(find.byType(SettingsMenuCard), findsNWidgets(2));
    expect(find.byIcon(Icons.chevron_right), findsNothing);
    expect(find.byIcon(Icons.pending_actions), findsOneWidget);
    expect(find.byIcon(Icons.task_alt), findsOneWidget);
    final titles = tester
        .widgetList<SettingsMenuCard>(find.byType(SettingsMenuCard))
        .map((card) => card.title)
        .toList();
    expect(titles, <String>['Pending', 'Resolved']);
  });

  testWidgets('the list can be pulled down to sync', (tester) async {
    await pump(tester, _FakeAdminRepository(rows: [_request(id: '1')]));
    expect(find.byType(RefreshIndicator), findsOneWidget);
  });

  testWidgets('the header carries the shared sync button', (tester) async {
    await pump(tester, _FakeAdminRepository(rows: [_request(id: '1')]));

    // The same control the case screens and the panel header use, so a sync is
    // one tap away from this page too.
    expect(find.byType(SyncButton), findsOneWidget);
    expect(
      find.byKey(const ValueKey('cases-modal-sync-button')),
      findsOneWidget,
    );
  });

  testWidgets('the page wears a back arrow, not the drawer menu', (
    tester,
  ) async {
    await pump(tester, _FakeAdminRepository(rows: [_request(id: '1')]));

    // A pushed sub-page: the back arrow is the way out.
    expect(find.byType(BackButton), findsOneWidget);
    expect(find.byIcon(Icons.menu), findsNothing);
    // The search control lives in the page's own header.
    expect(find.byKey(const ValueKey('admin-payments-search')), findsOneWidget);
  });
}
