/// Settings drawer Share test.
///
/// The navigation drawer offers Print and Share on every screen, but it only
/// knows the callbacks it is handed: Settings passed neither, so its Share tile
/// was a dead tap while the case screens' worked. This pins the Share wiring on
/// the real Settings screen — the action, and the message the clipboard
/// fallback must show — so the same omission cannot come back unnoticed.
library;

import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/providers/print_providers.dart';
import 'package:legal_case_diary/core/providers/repository_providers.dart';
import 'package:legal_case_diary/core/router/app_router.dart';
import 'package:legal_case_diary/core/services/app_share_service.dart';
import 'package:legal_case_diary/core/services/local_identity_service.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/account_mode.dart';
import 'package:legal_case_diary/features/settings/data/local/user_preferences_dao.dart';
import 'package:legal_case_diary/features/settings/data/settings_repository.dart';
import 'package:legal_case_diary/features/settings/data/update_metadata_store.dart';
import 'package:legal_case_diary/features/settings/presentation/settings_about/support_screen.dart';
import 'package:legal_case_diary/features/settings/presentation/settings_controls.dart';
import 'package:legal_case_diary/features/settings/presentation/settings_main_screen.dart';
import 'package:legal_case_diary/shared/providers/database_provider.dart';
import 'package:legal_case_diary/shared/providers/shared_preferences_provider.dart';

import '../core/print_test_support.dart';

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;
  late LocalIdentityService identity;
  late RecordingShareService sharer;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
    identity = LocalIdentityService(prefs);
    db = AppDatabase(NativeDatabase.memory());
    sharer = RecordingShareService();
  });

  tearDown(() async => db.close());

  /// Pumps the real Settings screen, reached through a router because the screen
  /// reads its route for the drawer's active row.
  ///
  /// Nothing here drains framework errors: the Settings rows used to trip
  /// Flutter's ListTile ink assert once per row per layout (its card was a
  /// decorated `Container`, fixed in 0.0.407), and a test that swallows
  /// framework noise cannot report the next one.
  Future<void> pumpSettings(WidgetTester tester, {bool member = false}) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const SettingsMainScreen(),
        ),
        GoRoute(
          path: AppRoutes.settingsSupport,
          builder: (context, state) => const SupportScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWith((_) async => db),
          localIdentityServiceProvider.overrideWith((_) => identity),
          settingsRepositoryProvider.overrideWith(
            (_) async =>
                LocalSettingsRepository(UserPreferencesDao(db), identity),
          ),
          appShareServiceProvider.overrideWithValue(sharer),
          // The chamber-member bar (firm-mode §6) is stated here rather than
          // derived, so the test states only the fact it is about.
          if (member) firmMemberProvider.overrideWithValue(true),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Opens the drawer, scrolls to its Share tile and taps it.
  Future<void> tapDrawerShare(WidgetTester tester) async {
    tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
    await tester.pumpAndSettle();

    final list = find
        .descendant(of: find.byType(Drawer), matching: find.byType(ListView))
        .first;
    // The drawer lists every case screen before its tools, so Share sits below
    // the fold in a test-sized viewport; the list clamps, so one long drag
    // reaches the bottom of it.
    await tester.drag(list, const Offset(0, -600));
    await tester.pumpAndSettle();

    final share = find.descendant(
      of: find.byType(Drawer),
      matching: find.text(
        AppLocalizations.of(
          tester.element(find.byType(SettingsMainScreen)),
        ).nav_share,
      ),
    );
    expect(share, findsOneWidget);
    await tester.tap(share);
    await tester.pumpAndSettle();
  }

  /// Unmounts before the test ends so no screen timer outlives the body.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('a chamber member is not offered Backup & Restore', (
    WidgetTester tester,
  ) async {
    final l = await AppLocalizations.delegate.load(const Locale('en'));

    await pumpSettings(tester);
    expect(find.text(l.settingsScreen_backupAndRestore), findsOneWidget);
    await unmount(tester);

    // The same screen for a member: the entry is the owner's and an individual
    // account's, because a member who could export would hold the chamber's whole
    // ledger in a file they keep (firm-mode §6).
    await pumpSettings(tester, member: true);
    expect(find.text(l.settingsScreen_backupAndRestore), findsNothing);
    // The rest of the General group is untouched by the bar.
    expect(find.text(l.settingsScreen_accountAndProfile), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('the Settings drawer Share hands over the app invite', (
    WidgetTester tester,
  ) async {
    await pumpSettings(tester);

    // Nothing is shared merely by opening the drawer.
    expect(sharer.invites, isEmpty);

    await tapDrawerShare(tester);

    expect(sharer.invites.single.message, contains(appStoreUrl));
    expect(sharer.invites.single.subject, isNotEmpty);

    await unmount(tester);
  });

  testWidgets('Support sits on the Settings root, in the App Info group', (
    WidgetTester tester,
  ) async {
    // Support moved here from About (user request): it is the entry a blocked
    // user reaches for, and two taps deep inside About cost them the most.
    await pumpSettings(tester);

    await tester.scrollUntilVisible(find.text('Support'), 200);
    expect(find.text('Support'), findsOneWidget);
    // It is a row of the App Info group, beside Guidelines & FAQs and About.
    expect(find.text('Guidelines & FAQs'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);

    // And it still goes where it always did — this is the navigation the About
    // suite used to pin before the row moved here.
    await tester.tap(find.text('Support'));
    await tester.pumpAndSettle();
    expect(find.byType(SupportScreen), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('the About row carries the dot only when an update is offered', (
    WidgetTester tester,
  ) async {
    // Seeded *before* the pump: the notifier reads preferences once when it is
    // built, and pumping a second tree over the first reuses the elements, so a
    // value written afterwards would never be seen.
    await prefs.setString(
      updateAvailableReleaseKey,
      jsonEncode(<String, Object?>{
        'version': '99.99.999',
        'url': 'https://example.test/app.apk',
      }),
    );
    await pumpSettings(tester);
    // The row is below the fold, so it has to be scrolled to before it exists.
    await tester.scrollUntilVisible(find.text('About'), 200);

    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text('About'),
          matching: find.byType(ListTile),
        ),
        matching: find.byType(UpdateDot),
      ),
      findsOneWidget,
      reason: 'the dot rides on the About row, not somewhere else',
    );

    await unmount(tester);
  });

  testWidgets('no dot is drawn when nothing is waiting', (
    WidgetTester tester,
  ) async {
    await pumpSettings(tester);
    await tester.scrollUntilVisible(find.text('About'), 200);

    expect(find.byType(UpdateDot), findsNothing);

    await unmount(tester);
  });

  testWidgets('the clipboard fallback from Settings says so', (
    WidgetTester tester,
  ) async {
    sharer.outcome = AppShareOutcome.copiedToClipboard;
    await pumpSettings(tester);

    await tapDrawerShare(tester);

    final l = AppLocalizations.of(
      tester.element(find.byType(SettingsMainScreen)),
    );
    // The invite is never silently lost: with no share target the app says it
    // went to the clipboard.
    expect(find.text(l.appShare_copied), findsOneWidget);

    await unmount(tester);
  });
}
