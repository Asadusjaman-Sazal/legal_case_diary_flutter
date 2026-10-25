/// The Settings search surface: a deep action is found by its own label, its
/// breadcrumb is shown, and tapping it opens the screen that holds it. A
/// setting the account cannot see is not offered.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/providers/repository_providers.dart';
import 'package:legal_case_diary/core/router/app_router.dart';
import 'package:legal_case_diary/core/services/local_identity_service.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/account_mode.dart';
import 'package:legal_case_diary/features/admin/presentation/admin_viewmodel.dart';
import 'package:legal_case_diary/features/payments/data/payment_plans.dart';
import 'package:legal_case_diary/features/settings/presentation/settings_main_screen.dart';
import 'package:legal_case_diary/shared/providers/database_provider.dart';
import 'package:legal_case_diary/shared/providers/shared_preferences_provider.dart';

import 'settings_test_support.dart';

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;
  late LocalIdentityService identity;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
    identity = LocalIdentityService(prefs);
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async => db.close());

  Future<void> pumpSettings(WidgetTester tester, {bool member = false}) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const SettingsMainScreen()),
        GoRoute(
          path: AppRoutes.settingsSubscriptionDetails,
          builder: (_, _) => const Scaffold(body: Text('Manage Plan Route')),
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
            (_) async => FakeSettingsRepository(),
          ),
          premiumAccessProvider.overrideWith((ref) async => true),
          currentTierProvider.overrideWithValue(SubscriptionTier.pro),
          adminStatusProvider.overrideWith((ref) async => false),
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

  Future<void> search(WidgetTester tester, String query) async {
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.tap(find.byTooltip(l.settingsScreen_searchTooltip));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), query);
    await tester.pump();
  }

  testWidgets('a deep action shows its breadcrumb and opens its screen', (
    tester,
  ) async {
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    await pumpSettings(tester);

    await search(tester, 'cancel');

    final result = find.byKey(
      ValueKey(
        'settings-search-result-${l.settingsSubscription_cancelSubscription}',
      ),
    );
    expect(result, findsOneWidget);
    // The breadcrumb names the screen that holds the button.
    expect(
      find.textContaining(l.settingsSubscription_managePlanTitle),
      findsOneWidget,
    );

    await tester.tap(result);
    await tester.pumpAndSettle();
    expect(find.text('Manage Plan Route'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a member cannot find the hidden backup action', (tester) async {
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    await pumpSettings(tester, member: true);

    await search(tester, 'google drive');

    expect(find.text(l.settingsBackupRestore_backupDrive), findsNothing);
    expect(find.text(l.settingsScreen_noResults), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
