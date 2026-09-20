/// Shared harness for the Task 12 Phase 4 Settings screen tests.
///
/// The Notifications and View Settings screens read and write the per-user
/// `user_preferences` row through [SettingsRepository], so both suites drive
/// them with [FakeSettingsRepository] and assert what was stored. Plain fakes
/// keep Drift's query-timer machinery out of widget tests.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/providers/repository_providers.dart';
import 'package:legal_case_diary/features/settings/data/settings_repository.dart';

/// In-memory settings repository holding one [UserSettings] value.
class FakeSettingsRepository implements SettingsRepository {
  /// Creates the fake, optionally seeded with [settings].
  FakeSettingsRepository([this.settings = const UserSettings()]);

  /// The stored settings; assertions read this after each interaction.
  UserSettings settings;

  @override
  Future<UserSettings> getSettings() async => settings;

  @override
  Stream<UserSettings> watchSettings() => Stream<UserSettings>.value(settings);

  @override
  Future<void> upsertSettings(UserSettings settings) async {
    this.settings = settings;
  }

  @override
  Future<void> saveLastAddCaseSelection({
    required String? higherLowerCourt,
    required String? division,
    required String? district,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Pumps a GoRouter-rooted Settings surface, for screens that navigate.
///
/// The screens under test push other routes (`context.push`), which needs a
/// real router rather than a plain [Navigator]; [routes] is the minimal route
/// table each test declares. A [ProviderScope] wraps the app because a pushed
/// screen may read providers (Support reads the device facts and the contact
/// launcher); [overrides] seeds them with fakes.
Future<void> pumpSettingsRouter(
  WidgetTester tester, {
  required String location,
  required List<RouteBase> routes,
  Locale locale = const Locale('en'),
  List<Override> overrides = const <Override>[],
}) async {
  final router = GoRouter(initialLocation: location, routes: routes);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Pumps [screen] backed by [repo] with the app's localizations.
///
/// [overrides] adds further provider overrides, for screens that reach beyond
/// settings (the drawer reads the saved profile picture and name).
Future<void> pumpSettingsScreen(
  WidgetTester tester,
  Widget screen, {
  required SettingsRepository repo,
  Locale locale = const Locale('en'),
  List<Override> overrides = const <Override>[],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsRepositoryProvider.overrideWith((ref) async => repo),
        ...overrides,
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        home: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
}
