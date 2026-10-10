/// Non-verified Accounts sub-page tests — 0.0.459.
///
/// The page lists the sign-ups that never confirmed their address, so abandoned
/// ones can be cleaned up. These pin what it promises: a non-admin sees nothing,
/// each card is numbered and carries when the account was created, Delete is
/// **offered only when the server says the account may go** (and refused with a
/// reason otherwise), removing one goes through the repository and then re-reads
/// the list, and the header's search filters the cards.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/providers/repository_providers.dart';
import 'package:legal_case_diary/features/admin/data/admin_repository.dart';
import 'package:legal_case_diary/features/admin/presentation/admin_unconfirmed_accounts_screen.dart';

/// A repository that answers from memory and records what it was asked.
class _FakeAdminRepository implements AdminRepository {
  _FakeAdminRepository({this.admin = true, List<AdminUnconfirmedAccount>? rows})
    : rows = rows ?? <AdminUnconfirmedAccount>[];

  final bool admin;
  final List<AdminUnconfirmedAccount> rows;

  /// Calls the page made, in order.
  final List<String> calls = <String>[];

  /// What [deleteUnconfirmedAccount] answers; null means success.
  AdminActionFailure? failure;

  int listCalls = 0;

  @override
  Future<bool> isAdmin() async => admin;

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
  Future<List<AdminUnconfirmedAccount>> listUnconfirmedAccounts() async {
    listCalls++;
    return rows;
  }

  @override
  Future<AdminActionFailure?> deleteUnconfirmedAccount(String userId) async {
    calls.add('delete:$userId');
    return failure;
  }
}

AdminUnconfirmedAccount _account({
  required String id,
  String name = 'Adv. Rahim Uddin',
  String email = 'rahim@example.com',
  bool canDelete = true,
}) => AdminUnconfirmedAccount(
  id: id,
  email: email,
  fullName: name,
  createdAt: DateTime(2026, 10, 8, 14, 30),
  canDelete: canDelete,
);

void main() {
  Future<void> pump(
    WidgetTester tester,
    _FakeAdminRepository repo, {
    Locale locale = const Locale('en'),
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [adminRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: locale,
          home: const AdminUnconfirmedAccountsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lists each abandoned sign-up with its creation date and time', (
    tester,
  ) async {
    await pump(
      tester,
      _FakeAdminRepository(rows: [_account(id: 'a1'), _account(id: 'a2')]),
    );

    expect(find.text('Non-verified Accounts'), findsOneWidget);
    expect(find.text('Adv. Rahim Uddin'), findsNWidgets(2));
    expect(find.text('Email: rahim@example.com'), findsNWidgets(2));
    // The day AND the clock, so two sign-ups on one day are told apart.
    expect(find.text('Created: 08/10/26, 02:30 PM'), findsNWidgets(2));
  });

  testWidgets('numbers the cards from 1', (tester) async {
    await pump(
      tester,
      _FakeAdminRepository(rows: [_account(id: 'a1'), _account(id: 'a2')]),
    );

    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('an empty list says every account has confirmed', (tester) async {
    await pump(tester, _FakeAdminRepository());

    expect(
      find.text('Every account has confirmed its address.'),
      findsOneWidget,
    );
  });

  testWidgets('deleting asks first, then reaches the repository and reloads', (
    tester,
  ) async {
    final repo = _FakeAdminRepository(rows: [_account(id: 'a1')]);
    await pump(tester, repo);
    final listsBefore = repo.listCalls;

    await tester.tap(find.widgetWithText(OutlinedButton, 'Delete'));
    await tester.pumpAndSettle();
    // Removing an account is permanent, so it is confirmed rather than fired
    // from one tap.
    expect(find.text('Delete This Account?'), findsOneWidget);
    expect(repo.calls, isEmpty);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete Account'));
    await tester.pumpAndSettle();

    expect(repo.calls, <String>['delete:a1']);
    // The server is the only account of what is left, so it is asked again.
    expect(repo.listCalls, greaterThan(listsBefore));
    expect(find.text('Account deleted.'), findsOneWidget);
  });

  testWidgets('cancelling the confirmation deletes nothing', (tester) async {
    final repo = _FakeAdminRepository(rows: [_account(id: 'a1')]);
    await pump(tester, repo);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(repo.calls, isEmpty);
  });

  testWidgets('an account that may not go is not offered a Delete', (
    tester,
  ) async {
    await pump(
      tester,
      _FakeAdminRepository(rows: [_account(id: 'a1', canDelete: false)]),
    );

    // The button is absent and the reason is named, rather than offering an
    // action the server would refuse.
    expect(find.widgetWithText(OutlinedButton, 'Delete'), findsNothing);
    expect(
      find.text(
        'This account has data or is confirmed, so it cannot be deleted from '
        'here.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('search filters the cards', (tester) async {
    await pump(
      tester,
      _FakeAdminRepository(
        rows: [
          _account(id: 'a1', name: 'Abdur Rahim'),
          _account(id: 'a2', name: 'Mojammel Haque'),
        ],
      ),
    );

    await tester.tap(find.byKey(const ValueKey('admin-accounts-search')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Mojammel');
    await tester.pumpAndSettle();

    expect(find.text('Mojammel Haque'), findsOneWidget);
    expect(find.text('Abdur Rahim'), findsNothing);
  });

  testWidgets('a non-admin is offered no accounts at all', (tester) async {
    await pump(
      tester,
      _FakeAdminRepository(admin: false, rows: [_account(id: 'a1')]),
    );

    expect(find.text('Adv. Rahim Uddin'), findsNothing);
    expect(
      find.text('Every account has confirmed its address.'),
      findsOneWidget,
    );
  });

  testWidgets('renders in Bengali', (tester) async {
    await pump(
      tester,
      _FakeAdminRepository(rows: [_account(id: 'a1')]),
      locale: const Locale('bn'),
    );

    expect(find.text('অযাচিত অ্যাকাউন্ট'), findsOneWidget);
    expect(find.text('মুছুন'), findsOneWidget);
  });
}
