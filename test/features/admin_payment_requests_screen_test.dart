/// Payment Requests sub-page tests — Task 22 / 0.0.459.
///
/// This is the Admin Panel's old body, moved to a page of its own when the panel
/// became a menu. It pins what that page promises: a non-admin sees no payment
/// data, the two sections open in the right state, an approve or reject reaches
/// the repository and is followed by a reload rather than a local guess, each
/// card is numbered within its section, the header's search filters both
/// sections — opening a closed one when it holds the match — and each section's
/// button holds the top of the list while the admin scrolls that section's own
/// cards.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/core/constants/app_colors.dart';
import 'package:legal_case_diary/core/constants/app_spacing.dart';
import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/providers/repository_providers.dart';
import 'package:legal_case_diary/features/admin/data/admin_repository.dart';
import 'package:legal_case_diary/features/admin/presentation/admin_payment_requests_screen.dart';
import 'package:legal_case_diary/features/settings/data/settings_repository.dart';
import 'package:legal_case_diary/features/settings/presentation/settings_menu_card.dart';
import 'package:legal_case_diary/shared/widgets/sync_button.dart';

import '../test_utils.dart';
import 'settings_test_support.dart';

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
  /// Pumps the page and returns the settings fake behind it.
  ///
  /// The reject window reads and writes the admin's own pre-fill messages through
  /// the per-user preference row, so the fake is what a test asserts against.
  Future<FakeSettingsRepository> pump(
    WidgetTester tester,
    _FakeAdminRepository repo, {
    Locale locale = const Locale('en'),
    FakeSettingsRepository? settings,
    Size size = const Size(1080, 3000),
  }) async {
    final settingsRepo = settings ?? FakeSettingsRepository();
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: withErrorLog([
          adminRepositoryProvider.overrideWithValue(repo),
          settingsRepositoryProvider.overrideWith((ref) async => settingsRepo),
        ]),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: locale,
          home: const AdminPaymentRequestsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return settingsRepo;
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
    // No notice at all (user request): the admin made the decision, so the page
    // does not tell them what they just did. The row leaving Pending is what the
    // server's own re-read says about it.
    expect(
      find.text('Payment approved. The payer is now premium.'),
      findsNothing,
    );
  });

  testWidgets('rejecting asks for a note and passes it through', (
    tester,
  ) async {
    final repo = _FakeAdminRepository(rows: [_request(id: '1')]);
    await pump(tester, repo);

    await tester.tap(find.widgetWithText(FilledButton, 'Reject'));
    await tester.pumpAndSettle();
    // The window is a decision the payer may query, so it is confirmed.
    expect(find.text('Reject the Payment'), findsOneWidget);
    expect(repo.calls, isEmpty);

    await tester.enterText(find.byType(TextField), 'Amount did not arrive');
    await tester.tap(find.widgetWithText(FilledButton, 'Reject Payment'));
    await tester.pumpAndSettle();

    expect(repo.calls, <String>['reject:1:Amount did not arrive']);
  });

  testWidgets('the pre-fill list offers every message the app ships', (
    tester,
  ) async {
    await pump(tester, _FakeAdminRepository(rows: [_request(id: '1')]));

    await tester.tap(find.widgetWithText(FilledButton, 'Reject'));
    await tester.pumpAndSettle();
    // The note is the window's first business, so the list starts folded away.
    expect(find.text('Mobile number is wrong.'), findsNothing);

    await tester.tap(find.text('Pre-Fill Message'));
    await tester.pumpAndSettle();

    for (final message in <String>[
      "Mobile number & Transaction ID didn't match.",
      'Mobile number is wrong.',
      'Transaction ID is wrong.',
      'Please enter the correct info.',
      'You have 2 tries left today.',
      'You have 1 try left today.',
      'Please be careful typing the info next time.',
      'Add Your Own',
    ]) {
      expect(find.text(message), findsOneWidget, reason: message);
    }
  });

  testWidgets('picking several appends them in order, after the typed note', (
    tester,
  ) async {
    final repo = _FakeAdminRepository(rows: [_request(id: '1')]);
    await pump(tester, repo);

    await tester.tap(find.widgetWithText(FilledButton, 'Reject'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Amount did not arrive');
    await tester.tap(find.text('Pre-Fill Message'));
    await tester.pumpAndSettle();

    // Picked out of order on purpose: the one picked first comes first.
    await tester.tap(
      find.byKey(const ValueKey('admin-reject-message-Transaction ID is wrong.')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('admin-reject-message-Mobile number is wrong.')),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Amount did not arrive Transaction ID is wrong. Mobile number is wrong.',
    );
    // Both picked rows carry their tick.
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byIcon(Icons.check_circle),
      ),
      findsNWidgets(2),
    );

    // Picking one back out takes that message and its joining space with it.
    await tester.tap(
      find.byKey(const ValueKey('admin-reject-message-Transaction ID is wrong.')),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Amount did not arrive Mobile number is wrong.',
    );

    // What the admin sees is what the rejection sends.
    await tester.tap(find.widgetWithText(FilledButton, 'Reject Payment'));
    await tester.pumpAndSettle();
    expect(repo.calls, <String>[
      'reject:1:Amount did not arrive Mobile number is wrong.',
    ]);
  });

  testWidgets('Add Your Own saves the wording and puts it in the note', (
    tester,
  ) async {
    final settings = await pump(
      tester,
      _FakeAdminRepository(rows: [_request(id: '1')]),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Reject'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pre-Fill Message'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('admin-reject-add-own')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'Send the money again');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    // Kept for next time (the user's request) and in the note now.
    expect(settings.settings.adminRejectMessages, <String>[
      'Send the money again',
    ]);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Send the money again',
    );
    // And it is one of the list's own rows, with a way to delete it.
    expect(
      find.byKey(
        const ValueKey('admin-reject-own-remove-Send the money again'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('removing an own message deletes it from the list', (
    tester,
  ) async {
    final settings = await pump(
      tester,
      _FakeAdminRepository(rows: [_request(id: '1')]),
      settings: FakeSettingsRepository(
        const UserSettings(
          adminRejectMessages: <String>['Send the money again'],
        ),
      ),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Reject'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pre-Fill Message'));
    await tester.pumpAndSettle();
    // The saved one is offered beside the app's own messages.
    expect(find.text('Send the money again'), findsOneWidget);

    await tester.tap(
      find.byKey(
        const ValueKey('admin-reject-own-remove-Send the money again'),
      ),
    );
    await tester.pumpAndSettle();
    // Behind the app's own delete window, so one stray tap cannot lose it.
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(settings.settings.adminRejectMessages, isEmpty);
    expect(find.text('Send the money again'), findsNothing);
  });

  testWidgets('the window and its list fit a phone', (tester) async {
    await pump(
      tester,
      _FakeAdminRepository(rows: [_request(id: '1')]),
      size: const Size(390, 844),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Reject'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pre-Fill Message'));
    await tester.pumpAndSettle();

    // The list scrolls inside a ceiling of its own rather than stretching the
    // window off the phone: note, list and both decisions all stay on screen.
    expect(tester.takeException(), isNull);
    final dialog = tester.getRect(find.byType(AlertDialog));
    expect(dialog.top, greaterThanOrEqualTo(0));
    expect(dialog.bottom, lessThanOrEqualTo(844));
    expect(find.widgetWithText(FilledButton, 'Reject Payment'), findsOneWidget);
  });

  testWidgets('the window lays out under the keyboard Your Own Message opens', (
    tester,
  ) async {
    await pump(
      tester,
      _FakeAdminRepository(rows: [_request(id: '1')]),
      // A small phone, deliberately: the shorter the screen, the less the window
      // has to lay out in once the keyboard arrives.
      size: const Size(360, 640),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Reject'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pre-Fill Message'));
    await tester.pumpAndSettle();
    // The list's last row is below the fold on a small phone, so it is scrolled
    // to before it is tapped — otherwise the tap lands on nothing and the second
    // window never opens, which is not the case being tested.
    await tester.ensureVisible(
      find.byKey(const ValueKey('admin-reject-add-own')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('admin-reject-add-own')));
    await tester.pumpAndSettle();
    // Both windows really are up, which is the state the report describes.
    expect(find.byType(TextField), findsNWidgets(2));

    // The own-message field autofocuses, so the keyboard comes up over both
    // windows at once. The rejection window behind it is laid out in what is
    // left, and it used to overflow off its own box there (reported on a phone).
    tester.view.viewInsets = const FakeViewPadding(bottom: 336);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // Still usable rather than merely not throwing: the note, the picker and
    // both decisions are all on the phone, so a rejection is still possible with
    // the keyboard up.
    expect(find.text('Pre-Fill Message'), findsOneWidget);
    final reject = tester.getRect(
      find.widgetWithText(FilledButton, 'Reject Payment'),
    );
    expect(reject.bottom, lessThanOrEqualTo(640));
    expect(reject.top, greaterThanOrEqualTo(0));
  });

  testWidgets('Reject is the red decision, worded in white', (tester) async {
    final repo = _FakeAdminRepository(rows: [_request(id: '1')]);
    await pump(tester, repo);

    // User request: the reject control reads as the outcome it produces — a
    // filled error button with a white label — rather than as an outlined twin
    // of Approve.
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Reject'),
    );
    expect(button.style?.backgroundColor?.resolve(<WidgetState>{}), AppColors.error);
    expect(button.style?.foregroundColor?.resolve(<WidgetState>{}), AppColors.onError);
  });

  testWidgets('the rejection window centres two app-height buttons', (
    tester,
  ) async {
    final repo = _FakeAdminRepository(rows: [_request(id: '1')]);
    await pump(tester, repo);
    // A phone width, unlike the tall viewport the list tests use: the pair has
    // to fit side by side and sit in the middle of the dialog they share.
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Reject'));
    await tester.pumpAndSettle();

    final cancel = tester.getRect(find.widgetWithText(TextButton, 'Cancel'));
    final confirm = tester.getRect(
      find.widgetWithText(FilledButton, 'Reject Payment'),
    );
    // The app's own control height, not the platform's smaller dialog default.
    expect(cancel.height, greaterThanOrEqualTo(48));
    expect(confirm.height, greaterThanOrEqualTo(48));

    // Middle aligned: each decision sits on the window's own centre line, so the
    // pair reads as one centred group. (The test font is wider than the app's, so
    // a narrow phone wraps the two onto separate lines here — centred either way,
    // which is what the overflow alignment is for.)
    final window = tester.getRect(find.byType(AlertDialog));
    expect(cancel.center.dx, closeTo(window.center.dx, 1));
    expect(confirm.center.dx, closeTo(window.center.dx, 1));
  });

  testWidgets("a refusal leaves the row's actions in place", (tester) async {
    final repo = _FakeAdminRepository(rows: [_request(id: '1')])
      ..failure = AdminActionFailure.alreadyResolved;
    await pump(tester, repo);

    await tester.tap(find.widgetWithText(FilledButton, 'Approve'));
    await tester.pumpAndSettle();

    // The whole notice went (user request), a refusal included — so the point of
    // this case is that nothing was resolved behind the admin's back: the row is
    // still there and still actionable.
    expect(find.text('That payment was already decided.'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Approve'), findsOneWidget);
    expect(repo.listCalls, 1);
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

  testWidgets('a section button holds the top of the list for its own cards', (
    tester,
  ) async {
    // A few pending cards to scroll inside, and a long Resolved section to hand
    // the top over to — the shape the admin works in, where one section is
    // hundreds of cards long.
    await pump(
      tester,
      _FakeAdminRepository(
        rows: <AdminPaymentRequest>[
          for (var i = 1; i <= 6; i++) _request(id: 'p$i'),
          for (var i = 1; i <= 20; i++)
            _request(
              id: 'r$i',
              status: 'approved',
              approvedAt: DateTime(2026, 10, 2),
            ),
        ],
      ),
    );
    await tester.tap(find.text('Resolved'));
    await tester.pumpAndSettle();

    final list = find.byType(CustomScrollView);
    expect(list, findsOneWidget);
    final listTop = tester.getTopLeft(list).dy;

    /// The section's own button — not the "Pending" status chip each pending
    /// card carries.
    Finder sectionButton(String title) =>
        find.widgetWithText(SettingsMenuCard, title);
    double buttonTop(String title) =>
        tester.getTopLeft(sectionButton(title)).dy;

    Future<void> scrollList(double dy) async {
      final rect = tester.getRect(list);
      await tester.dragFrom(
        Offset(rect.left + 100, rect.top + rect.height / 2),
        Offset(0, dy),
      );
      await tester.pumpAndSettle();
    }

    // Scrolling through Pending's own cards leaves its button holding the top of
    // the list, so the admin can still read which section he is in.
    await scrollList(-400);
    expect(
      buttonTop('Pending'),
      closeTo(listTop + AppSpacing.sm, 1.0),
      reason: 'the Pending button is pinned',
    );
    expect(buttonTop('Resolved'), greaterThan(listTop + 400));

    // Scrolling on to the next section hands the top over: the Pending button is
    // pushed out and Resolved takes its place.
    await scrollList(-20000);
    expect(
      buttonTop('Resolved'),
      closeTo(listTop + AppSpacing.sm, 1.0),
      reason: 'the Resolved button took the top',
    );
    // Pending's cards are behind the reader by now, so the button on screen is
    // the only thing naming the section being worked in.
    expect(find.text('TrxID: TRXp1'), findsNothing);
    final pushedOut = sectionButton('Pending');
    if (pushedOut.evaluate().isNotEmpty) {
      expect(tester.getTopLeft(pushedOut).dy, lessThan(listTop));
    }
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
