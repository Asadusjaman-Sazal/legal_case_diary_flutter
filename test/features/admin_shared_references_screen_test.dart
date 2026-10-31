/// Admin Panel's Server-wide Case Reference page — Phase 6 of the law-list plan.
///
/// The page is a replica of the user's Case Reference library over the live
/// server table: the same law list, the same cards, plus add, edit and delete.
/// These pin what only it can promise — that a save reaches the repository, that
/// an offline save refuses in plain words and sends nothing, and that a
/// non-admin never sees the page.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/providers/repository_providers.dart';
import 'package:legal_case_diary/core/services/local_identity_service.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/shared/providers/database_provider.dart';
import 'package:legal_case_diary/features/admin/data/admin_repository.dart';
import 'package:legal_case_diary/features/admin/presentation/admin_shared_references_screen.dart';
import 'package:legal_case_diary/features/case_reference/presentation/law_picker.dart';
import 'package:legal_case_diary/sync/connectivity_monitor.dart';

/// An in-memory admin repository: the shared library lives in [shared].
class _FakeAdminRepository implements AdminRepository {
  _FakeAdminRepository({
    this.isAdminUser = true,
    List<AdminSharedReference>? rows,
  }) : shared = rows ?? <AdminSharedReference>[];

  final List<AdminSharedReference> shared;

  /// What [isAdmin] answers.
  final bool isAdminUser;

  /// Every save this page made, so a refusal can be told from a write.
  final List<AdminSharedReference> saved = <AdminSharedReference>[];

  /// Every delete this page made.
  final List<String> deleted = <String>[];

  /// What a save answers; null means success.
  AdminActionFailure? saveFailure;

  @override
  Future<bool> isAdmin() async => isAdminUser;

  @override
  Future<List<AdminSharedReference>> listSharedReferences() async =>
      List<AdminSharedReference>.unmodifiable(shared);

  @override
  Future<AdminActionFailure?> saveSharedReference(
    AdminSharedReference reference,
  ) async {
    saved.add(reference);
    if (saveFailure != null) return saveFailure;
    shared
      ..removeWhere((row) => row.id == reference.id)
      ..add(reference);
    return null;
  }

  @override
  Future<AdminActionFailure?> deleteSharedReference(String id) async {
    deleted.add(id);
    shared.removeWhere((row) => row.id == id);
    return null;
  }

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
}

/// One official citation.
AdminSharedReference _citation(
  String id, {
  String citation = '29 DLR (AD) 69',
  String statute = 'The Penal Code, 1860',
  String section = 'Section 54',
  String title = 'Preventive detention.',
}) => AdminSharedReference(
  id: id,
  referenceAndPageNo: citation,
  statute: statute,
  sectionOrArticle: section,
  titleAndDescription: title,
);

/// The two seeded laws these tests need, in seed order.
final List<Law> _laws = <Law>[
  const Law(
    id: 'law-penal',
    name: 'The Penal Code, 1860',
    category: 'criminal_law',
    orderIndex: 0,
    isCustom: false,
    isUserModified: false,
    updatedAt: 0,
    isDeleted: false,
  ),
  const Law(
    id: 'law-crpc',
    name: 'The Code of Criminal Procedure, 1898',
    category: 'criminal_law',
    orderIndex: 1,
    isCustom: false,
    isUserModified: false,
    updatedAt: 0,
    isDeleted: false,
  ),
];

void main() {
  Future<void> pump(
    WidgetTester tester,
    _FakeAdminRepository repo, {
    bool online = true,
    Locale locale = const Locale('en'),
    // A local diary, only for the test that adds a law name: the picker's
    // add route writes a real `laws` row, so it needs the database.
    AppDatabase? db,
    LocalIdentityService? identity,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminRepositoryProvider.overrideWithValue(repo),
          lawListProvider.overrideWith((ref) => Stream.value(_laws)),
          isOnlineProvider.overrideWith((ref) => Stream.value(online)),
          if (db != null) databaseProvider.overrideWith((_) async => db),
          if (identity != null)
            localIdentityServiceProvider.overrideWithValue(identity),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: locale,
          home: const AdminSharedReferencesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lists the laws that hold citations, then opens one', (
    tester,
  ) async {
    await pump(tester, _FakeAdminRepository(rows: [_citation('o1')]));

    // Level 1: the law, under its category, with a count — the user's screen's
    // own shape.
    expect(find.text('Criminal Law'), findsOneWidget);
    expect(find.text('The Penal Code, 1860'), findsOneWidget);
    expect(find.textContaining('29 DLR'), findsNothing);

    await tester.tap(find.text('The Penal Code, 1860'));
    await tester.pumpAndSettle();

    expect(find.textContaining('29 DLR'), findsOneWidget);
    // An admin's row is server-owned, so it wears the Official chip.
    expect(find.text('Official'), findsOneWidget);
  });

  testWidgets('publishing a citation sends it to the repository', (
    tester,
  ) async {
    final repo = _FakeAdminRepository();
    await pump(tester, repo);

    await tester.tap(find.byKey(const ValueKey('admin-shared-add')));
    await tester.pumpAndSettle();

    expect(find.text('Add Official Reference'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('reference-form-citation')),
      '45 DLR (AD) 1',
    );
    await tester.tap(find.byKey(const ValueKey('reference-form-save')));
    await tester.pumpAndSettle();

    expect(repo.saved, hasLength(1));
    expect(repo.saved.single.referenceAndPageNo, '45 DLR (AD) 1');
    // The page re-read the server rows after the save, so the new citation is
    // now in its law list.
    expect(find.textContaining('45 DLR'), findsNothing);
    expect(find.text('Saved'), findsNothing);
  });

  testWidgets('an offline save refuses and sends nothing', (tester) async {
    final repo = _FakeAdminRepository();
    await pump(tester, repo, online: false);

    await tester.tap(find.byKey(const ValueKey('admin-shared-add')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('reference-form-citation')),
      '45 DLR (AD) 1',
    );
    await tester.tap(find.byKey(const ValueKey('reference-form-save')));
    await tester.pumpAndSettle();

    expect(repo.saved, isEmpty);
    expect(
      find.text(
        'You are offline. Publishing a citation needs the server, so try '
        'again when you are connected.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('the official form puts its labels above the boxes', (
    tester,
  ) async {
    await pump(tester, _FakeAdminRepository());
    await tester.tap(find.byKey(const ValueKey('admin-shared-add')));
    await tester.pumpAndSettle();
    final l = await AppLocalizations.delegate.load(const Locale('en'));

    // The label's own bottom edge sits above the box's top edge (user request),
    // not floating on the border.
    final citationLabel = tester.getRect(
      find.text(l.caseReferenceScreen_referenceAndPageNo),
    );
    final citationBox = tester.getRect(
      find.descendant(
        of: find.byKey(const ValueKey('reference-form-citation')),
        matching: find.byType(TextField),
      ),
    );
    expect(citationLabel.bottom, lessThanOrEqualTo(citationBox.top));

    final statuteLabel = tester.getRect(
      find.text(l.caseReferenceScreen_statute),
    );
    final statuteBox = tester.getRect(
      find.descendant(
        of: find.byKey(const ValueKey('reference-form-statute')),
        matching: find.byType(InputDecorator),
      ),
    );
    expect(statuteLabel.bottom, lessThanOrEqualTo(statuteBox.top));
  });

  testWidgets('a non-admin is shown no library at all', (tester) async {
    await pump(
      tester,
      _FakeAdminRepository(isAdminUser: false, rows: [_citation('o1')]),
    );

    expect(find.text('Criminal Law'), findsNothing);
    expect(find.textContaining('29 DLR'), findsNothing);
  });

  testWidgets('a citation can be edited and deleted from its card', (
    tester,
  ) async {
    final repo = _FakeAdminRepository(rows: [_citation('o1')]);
    await pump(tester, repo);

    await tester.tap(find.text('The Penal Code, 1860'));
    await tester.pumpAndSettle();

    // Edit: the card opens the form with the citation already filled in.
    await tester.tap(find.textContaining('29 DLR'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Official Reference'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('reference-form-citation')),
      '29 DLR (AD) 70',
    );
    await tester.tap(find.byKey(const ValueKey('reference-form-save')));
    await tester.pumpAndSettle();
    expect(repo.saved.single.referenceAndPageNo, '29 DLR (AD) 70');

    // Delete: the menu's Delete asks first, then removes the row.
    await tester.tap(find.byKey(const ValueKey('reference-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reference-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('admin-shared-delete-confirm')));
    await tester.pumpAndSettle();

    expect(repo.deleted, ['o1']);
  });

  testWidgets('the search reads the whole library, whichever law is open', (
    tester,
  ) async {
    await pump(
      tester,
      _FakeAdminRepository(
        rows: [
          _citation('o1'),
          _citation(
            'o2',
            citation: '32 DLR (AD) 102',
            statute: 'The Code of Criminal Procedure, 1898',
            section: 'Article 31',
            title: 'Writ petition on unlawful detention.',
          ),
        ],
      ),
    );

    // Open the first law: only its own citation is on the page.
    await tester.tap(find.text('The Penal Code, 1860'));
    await tester.pumpAndSettle();
    expect(find.textContaining('29 DLR'), findsOneWidget);
    expect(find.textContaining('32 DLR'), findsNothing);

    // The header's search reads the whole library, so another law's citation is
    // found from here (user request).
    await tester.tap(find.byKey(const ValueKey('admin-shared-search')));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'writ');
    await tester.pumpAndSettle();
    expect(find.textContaining('29 DLR'), findsNothing);
    expect(find.textContaining('32 DLR'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'nothing matches');
    await tester.pumpAndSettle();
    expect(find.text('No results found.'), findsOneWidget);

    // Closing the search clears it and brings this law's citations back.
    await tester.tap(find.byIcon(Icons.close).last);
    await tester.pumpAndSettle();
    expect(find.textContaining('29 DLR'), findsOneWidget);
    expect(find.textContaining('32 DLR'), findsNothing);
  });

  testWidgets('Add a Law Name in the picker adds it and selects it', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final identity = LocalIdentityService(prefs);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = _FakeAdminRepository();

    await pump(tester, repo, db: db, identity: identity);
    await tester.tap(find.byKey(const ValueKey('admin-shared-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reference-form-statute')));
    await tester.pumpAndSettle();

    // The shared picker's last row used to close the window and do nothing.
    await tester.tap(find.byKey(const ValueKey('law-picker-add')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('law-name-field')),
      'The Test Act, 2026',
    );
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    final laws = await db.select(db.laws).get();
    expect(laws.single.name, 'The Test Act, 2026');
    expect(laws.single.isCustom, isTrue);
    // The new name is chosen in the form, so the citation can be saved under it.
    expect(find.text('The Test Act, 2026'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('reference-form-citation')),
      '1 Test LR 1',
    );
    await tester.tap(find.byKey(const ValueKey('reference-form-save')));
    await tester.pumpAndSettle();

    expect(repo.saved.single.statute, 'The Test Act, 2026');

    // The form's ScaffoldMessenger schedules the save snackbar's dismissal;
    // tearing the tree down and letting that timer fire keeps the test binding
    // from reporting a pending timer at the end.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));
  });
}
