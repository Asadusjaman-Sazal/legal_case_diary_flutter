/// Tests for the monthly backup nudge (Task 15 Phase 6).
///
/// The banner is mounted above the app's navigator, so these tests mount it the
/// same way `app.dart` does — as `MaterialApp.router`'s builder — and drive it
/// against a real encrypted-schema database and real preferences. What they pin
/// is when a free user is asked, when they are deliberately *not* asked, that
/// the ask is recorded once for the month, and that tapping it lands on Backup &
/// Restore.
library;

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/router/app_router.dart';
import 'package:legal_case_diary/core/services/local_identity_service.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/settings/data/backup_metadata_store.dart';
import 'package:legal_case_diary/features/settings/presentation/backup_nudge_banner.dart';
import 'package:legal_case_diary/shared/providers/database_provider.dart';
import 'package:legal_case_diary/shared/providers/shared_preferences_provider.dart';

/// The nudge message, as the English ARB words it.
const String _message =
    'You have not backed up this month. Your cases live only on this phone — '
    'save a backup to keep them safe.';

/// Seeds the minimum a live case needs: a category, its court, an on-behalf
/// option and the case itself (foreign keys are enforced).
Future<void> _seedOneCase(AppDatabase db) async {
  await db
      .into(db.courtCategories)
      .insert(
        const CourtCategoriesCompanion(
          id: Value('nudge-category'),
          nameKey: Value('courtCategory_appellateDivision'),
          courtLevel: Value('appellate'),
          orderIndex: Value(1),
          updatedAt: Value(1),
        ),
      );
  await db
      .into(db.courts)
      .insert(
        const CourtsCompanion(
          id: Value('nudge-court'),
          courtName: Value('Nudge Court'),
          higherLowerCourts: Value('higher_courts'),
          courtCategoryId: Value('nudge-category'),
          updatedAt: Value(1),
        ),
      );
  await db
      .into(db.onBehalfs)
      .insert(
        const OnBehalfsCompanion(
          id: Value('nudge-on-behalf'),
          courtCategoryId: Value('nudge-category'),
          name: Value('Plaintiff'),
          orderIndex: Value(1),
          updatedAt: Value(1),
        ),
      );
  await db
      .into(db.cases)
      .insert(
        const CasesCompanion(
          id: Value('nudge-case'),
          userId: Value('user-1'),
          courtId: Value('nudge-court'),
          caseType: Value('Civil'),
          caseNumber: Value('NUDGE/2026'),
          petitioner: Value('Alice'),
          respondent: Value('Bob'),
          onBehalfId: Value('nudge-on-behalf'),
          createdAt: Value(1),
          updatedAt: Value(1),
        ),
      );
}

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;
  late LocalIdentityService identity;
  late GoRouter router;

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
    identity = LocalIdentityService(prefs);
    db = AppDatabase(NativeDatabase.memory());
    await _seedOneCase(db);

    router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              const Scaffold(body: Text('Home screen')),
        ),
        // The banner pushes this route, so the target stands in for the screen.
        GoRoute(
          path: AppRoutes.settingsBackupRestore,
          builder: (context, state) =>
              const Scaffold(body: Text('Backup and Restore screen')),
        ),
      ],
    );
    addTearDown(router.dispose);
  });

  tearDown(() async => db.close());

  Future<void> pumpApp(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWith((_) async => db),
          localIdentityServiceProvider.overrideWith((_) => identity),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: locale,
          routerConfig: router,
          builder: (context, child) => BackupNudgeBanner(
            router: router,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a free user with cases and no backup this month is asked', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.text(_message), findsOneWidget);
    expect(find.text('Back up to local storage'), findsOneWidget);
    // The ask is recorded as soon as it appears, so it cannot appear twice.
    expect(prefs.getInt(lastBackupNudgeAtKey), isNotNull);
  });

  testWidgets('dismissing the banner takes it away', (tester) async {
    await pumpApp(tester);
    expect(find.text(_message), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('backup-nudge-dismiss')));
    await tester.pumpAndSettle();

    expect(find.text(_message), findsNothing);
    // Dismissing does not undo the record: the month's one ask was made.
    expect(prefs.getInt(lastBackupNudgeAtKey), isNotNull);
  });

  testWidgets('a nudge already shown this month does not come back', (
    tester,
  ) async {
    await prefs.setInt(
      lastBackupNudgeAtKey,
      DateTime.now().toUtc().millisecondsSinceEpoch,
    );

    await pumpApp(tester);

    expect(find.text(_message), findsNothing);
  });

  testWidgets('a backup this month cancels the nudge', (tester) async {
    await prefs.setInt(
      lastSuccessfulBackupAtKey,
      DateTime.now().toUtc().millisecondsSinceEpoch,
    );

    await pumpApp(tester);

    expect(find.text(_message), findsNothing);
  });

  testWidgets('a premium user is never asked', (tester) async {
    // Premium is derived from the expiry plus the 48-hour grace window, so a
    // profile that expires tomorrow is still premium today.
    await db
        .into(db.profiles)
        .insert(
          ProfilesCompanion(
            id: Value(identity.getId()),
            fullName: const Value('Premium User'),
            role: const Value('individual'),
            subscriptionStatus: const Value('premium'),
            subscriptionExpiry: Value(
              DateTime.now()
                  .toUtc()
                  .add(const Duration(days: 1))
                  .millisecondsSinceEpoch,
            ),
            createdAt: const Value(1),
          ),
        );

    await pumpApp(tester);

    expect(find.text(_message), findsNothing);
    expect(prefs.getInt(lastBackupNudgeAtKey), isNull);
  });

  testWidgets('an empty diary is not asked to back anything up', (
    tester,
  ) async {
    await db.delete(db.cases).go();

    await pumpApp(tester);

    expect(find.text(_message), findsNothing);
    // Nothing was recorded either, so the first real case still gets asked.
    expect(prefs.getInt(lastBackupNudgeAtKey), isNull);
  });

  testWidgets('tapping the banner opens Backup & Restore', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text(_message));
    await tester.pumpAndSettle();

    expect(find.text('Backup and Restore screen'), findsOneWidget);
    expect(find.text(_message), findsNothing);
  });

  testWidgets('the nudge is localized', (tester) async {
    await pumpApp(tester, locale: const Locale('bn'));

    expect(
      find.textContaining('এই মাসে কোনো ব্যাকআপ নেওয়া হয়নি'),
      findsOneWidget,
    );
    expect(find.text('লোকাল স্টোরেজে ব্যাকআপ'), findsOneWidget);
  });
}
