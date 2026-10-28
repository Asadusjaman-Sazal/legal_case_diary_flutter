/// The Subscription menu behind its own Settings row (0.0.701).
///
/// The plan, the plans and the ledger moved out of Account & Profile into a
/// Settings entry directly under Firm. These tests pin the three rows, their
/// destinations, and the chamber-member rules that came with them: **Firm
/// Plan** with its own subtitle, the plans read-only, and no History.
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
import 'package:legal_case_diary/features/settings/presentation/settings_menu_card.dart';
import 'package:legal_case_diary/features/settings/presentation/subscription_menu_screen.dart';
import 'package:legal_case_diary/shared/providers/database_provider.dart';
import 'package:legal_case_diary/shared/providers/shared_preferences_provider.dart';

import 'settings_test_support.dart';

const String managePlanMarker = 'Manage Plan Route';
const String plansMarker = 'Subscription Plans Route';
const String historyMarker = 'Subscription History Route';

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

  /// Pumps the Subscription menu on its own route.
  Future<void> pumpMenu(
    WidgetTester tester, {
    bool member = false,
  }) async {
    final router = GoRouter(
      initialLocation: AppRoutes.settingsSubscription,
      routes: [
        GoRoute(
          path: AppRoutes.settingsSubscription,
          builder: (_, _) => const SubscriptionMenuScreen(),
        ),
        GoRoute(
          path: AppRoutes.settingsSubscriptionDetails,
          builder: (_, _) => const Scaffold(body: Text(managePlanMarker)),
        ),
        GoRoute(
          path: AppRoutes.paywall,
          builder: (_, _) => const Scaffold(body: Text(plansMarker)),
        ),
        GoRoute(
          path: AppRoutes.settingsSubscriptionHistory,
          builder: (_, _) => const Scaffold(body: Text(historyMarker)),
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
          firmMemberProvider.overrideWithValue(member),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('an individual sees the plan, the plans and the ledger', (
    tester,
  ) async {
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    await pumpMenu(tester);

    expect(find.text(l.settingsSubscription_managePlanTitle), findsOneWidget);
    expect(
      find.text(l.settingsAccountProfile_managePlanSubtitle),
      findsOneWidget,
    );
    expect(
      find.text(l.settingsManageAccount_purchaseNewSubscription),
      findsOneWidget,
    );
    expect(
      find.text(l.settingsAccountProfile_subscriptionPlansSubtitle),
      findsOneWidget,
    );
    expect(find.text(l.payments_historyTitle), findsOneWidget);
    expect(
      find.text(l.settingsAccountProfile_subscriptionHistorySubtitle),
      findsOneWidget,
    );
    expect(find.byType(SettingsMenuCard), findsNWidgets(3));

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the three rows open their screens', (tester) async {
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    await pumpMenu(tester);

    await tester.tap(find.text(l.settingsSubscription_managePlanTitle));
    await tester.pumpAndSettle();
    expect(find.text(managePlanMarker), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await pumpMenu(tester);
    await tester.tap(
      find.text(l.settingsManageAccount_purchaseNewSubscription),
    );
    await tester.pumpAndSettle();
    expect(find.text(plansMarker), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await pumpMenu(tester);
    await tester.tap(find.text(l.payments_historyTitle));
    await tester.pumpAndSettle();
    expect(find.text(historyMarker), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'a chamber member reads Firm Plan, keeps Plans and loses History',
    (tester) async {
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      await pumpMenu(tester, member: true);

      // The chamber's plan is the one they read, so the row and its line say
      // so (user request, 0.0.698).
      expect(find.text(l.settingsSubscription_firmPlanTitle), findsOneWidget);
      expect(find.text(l.settingsSubscription_managePlanTitle), findsNothing);
      expect(
        find.text(l.settingsAccountProfile_firmPlanSubtitle),
        findsOneWidget,
      );
      expect(
        find.text(l.settingsManageAccount_purchaseNewSubscription),
        findsOneWidget,
      );
      // The ledger is the account's own, and a chamber member is not offered it
      // (0.0.626, owner request).
      expect(find.text(l.payments_historyTitle), findsNothing);
      expect(find.byType(SettingsMenuCard), findsNWidgets(2));

      // The plans are still readable.
      await tester.tap(
        find.text(l.settingsManageAccount_purchaseNewSubscription),
      );
      await tester.pumpAndSettle();
      expect(find.text(plansMarker), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
