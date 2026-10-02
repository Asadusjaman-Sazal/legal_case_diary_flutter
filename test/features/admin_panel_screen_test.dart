/// Admin Panel tests — Task 22.
///
/// These pin the three things the panel promises and that nothing else in the
/// suite would notice: a non-admin sees no payment data at all, the two sections
/// open in the right state, and an approve or reject reaches the repository and
/// is followed by a reload from the server rather than a local guess.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/providers/repository_providers.dart';
import 'package:legal_case_diary/features/admin/data/admin_repository.dart';
import 'package:legal_case_diary/features/admin/presentation/admin_panel_screen.dart';
import 'package:legal_case_diary/features/settings/presentation/settings_menu_card.dart';
import 'package:legal_case_diary/shared/widgets/sync_button.dart';
import 'package:legal_case_diary/sync/sync_status_providers.dart';
import 'package:legal_case_diary/shared/widgets/bottom_nav_bar.dart';

/// A repository that answers from memory, so the panel can be driven without a
/// server and every call it makes is recorded.
class _FakeAdminRepository implements AdminRepository {
  _FakeAdminRepository({
    this.admin = true,
    List<AdminPaymentRequest>? rows,
    this.attention = 0,
  }) : rows = rows ?? <AdminPaymentRequest>[];

  final bool admin;
  final List<AdminPaymentRequest> rows;

  /// Blocked/conflicted work the header badge counts.
  final int attention;

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
        overrides: [
          adminRepositoryProvider.overrideWithValue(repo),
          // The header's Sync Status badge reads the real provider, as the
          // case screens do, so the suite pins its value rather than the
          // header's behaviour around it.
          syncStatusAttentionProvider.overrideWith(
            (ref) => Stream<int>.value(repo.attention),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: locale,
          home: const AdminPanelScreen(),
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

    expect(find.text('Payment Requests'), findsOneWidget);
    // The work needs doing, so it is what the screen opens on.
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

  testWidgets('cancelling the reject window rejects nothing', (tester) async {
    final repo = _FakeAdminRepository(rows: [_request(id: '1')]);
    await pump(tester, repo);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Reject'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(repo.calls, isEmpty);
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

    expect(find.text('অ্যাডমিন প্যানেল'), findsOneWidget);
    expect(find.text('পেমেন্ট অনুরোধ'), findsOneWidget);
    expect(find.text('১ বছর · ৳৯৬০'), findsOneWidget);
    expect(find.text('অনুমোদন'), findsOneWidget);
    expect(find.text('বাতিল'), findsOneWidget);
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

  testWidgets('the header is the case screens\', without their own controls', (
    tester,
  ) async {
    await pump(tester, _FakeAdminRepository(rows: [_request(id: '1')]));

    // The drawer menu is present and there is no back arrow beside it — the
    // drawer and the back gesture are already two ways out.
    expect(find.byIcon(Icons.menu), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);

    // Search and the view toggle belong to a case list; neither has anything
    // to act on here.
    expect(find.byIcon(Icons.search), findsNothing);
    expect(find.byKey(const ValueKey('cases-modal-view-toggle')), findsNothing);
  });

  testWidgets('no Sync Status badge when nothing is held', (tester) async {
    await pump(tester, _FakeAdminRepository(rows: [_request(id: '1')]));
    expect(find.byKey(const ValueKey('admin-panel-sync-status')), findsNothing);
  });

  testWidgets('the Sync Status badge appears when work is held', (
    tester,
  ) async {
    // Its own pump, not a second one after another: the header reads a Stream
    // provider, and re-pumping into the same container would leave the first
    // stream in place.
    await pump(
      tester,
      _FakeAdminRepository(rows: [_request(id: '1')], attention: 2),
    );
    expect(
      find.byKey(const ValueKey('admin-panel-sync-status')),
      findsOneWidget,
    );
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

    // Each section is the shared Settings sub-menu card — the same control the
    // Backup & Restore sections draw — so the two are the same size.
    expect(find.byType(SettingsMenuCard), findsNWidgets(2));
    // Neither header draws a trailing arrow.
    expect(find.byIcon(Icons.chevron_right), findsNothing);
    // The two sections are told apart by different leading icons.
    expect(find.byIcon(Icons.pending_actions), findsOneWidget);
    expect(find.byIcon(Icons.task_alt), findsOneWidget);
    // "Pending" is both a section title and the status chip on the open row, so
    // the section titles are read off the cards themselves.
    final titles = tester
        .widgetList<SettingsMenuCard>(find.byType(SettingsMenuCard))
        .map((card) => card.title)
        .toList();
    expect(titles, <String>['Pending', 'Resolved']);
  });

  testWidgets('the header carries the shared sync button', (tester) async {
    await pump(tester, _FakeAdminRepository(rows: [_request(id: '1')]));

    // The same widget the case screens use, so one change fixes both headers.
    expect(find.byType(SyncButton), findsOneWidget);
    expect(
      find.byKey(const ValueKey('cases-modal-sync-button')),
      findsOneWidget,
    );
  });

  testWidgets('the panel can be pulled down to sync', (tester) async {
    await pump(tester, _FakeAdminRepository(rows: [_request(id: '1')]));
    expect(find.byType(RefreshIndicator), findsOneWidget);
  });
}
