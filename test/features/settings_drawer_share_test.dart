/// Settings drawer Share test.
///
/// The navigation drawer offers Print and Share on every screen, but it only
/// knows the callbacks it is handed: Settings passed neither, so its Share tile
/// was a dead tap while the case screens' worked. This pins the Share wiring on
/// the real Settings screen — the action, and the message the clipboard
/// fallback must show — so the same omission cannot come back unnoticed.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/providers/print_providers.dart';
import 'package:legal_case_diary/core/providers/repository_providers.dart';
import 'package:legal_case_diary/core/services/app_share_service.dart';
import 'package:legal_case_diary/core/services/local_identity_service.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/settings/data/local/user_preferences_dao.dart';
import 'package:legal_case_diary/features/settings/data/settings_repository.dart';
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
  Future<void> pumpSettings(WidgetTester tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const SettingsMainScreen(),
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
