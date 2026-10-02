/// Online Sync screen tests.
///
/// The screen shipped as a Part A stub that hard-coded "Not signed in" and a
/// snackbar-only Sync Now, and no test noticed — which is why it survived so
/// long while the engine behind it was fully built. These pin the wiring: the
/// card states the account that is actually signed in, the plan that decides
/// whether sync can run, and the engine's real last-sync state; and the button
/// is disabled with a reason rather than firing a no-op.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/account_mode.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/profile_name_store.dart';
import 'package:legal_case_diary/features/auth/data/auth_repository.dart';
import 'package:legal_case_diary/features/auth/presentation/auth_viewmodel.dart';
import 'package:legal_case_diary/features/settings/presentation/online_sync_screen.dart';
import 'package:legal_case_diary/sync/connectivity_monitor.dart';
import 'package:legal_case_diary/sync/sync_health.dart';
import 'package:legal_case_diary/sync/sync_providers.dart';
import 'package:legal_case_diary/sync/sync_status_providers.dart';

import 'settings_test_support.dart';

/// A profile-name store with nothing saved, so no SharedPreferences backend is
/// needed and the card falls through to the session's own name.
class _BlankProfileFields extends ProfileFieldsNotifier {
  @override
  ProfileFields build() => const ProfileFields();
}

void main() {
  // The card reads the saved profile name, which lives in SharedPreferences.
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  /// Pumps the screen with the account and engine facts the test names.
  ///
  /// Every provider here is the real one the screen reads; only their values
  /// are pinned, so a future refactor that changes which provider feeds the
  /// card fails these tests rather than silently reverting to a stub.
  Future<void> pump(
    WidgetTester tester, {
    AuthIdentity? identity = const AuthIdentity(
      userId: 'user-1',
      email: 'advocate.asad@law.com',
    ),
    bool premium = true,
    bool online = true,
    int? lastSuccessEpochMs,
    int attention = 0,
  }) async {
    // Tall viewport: a lazy ListView never builds an off-screen row, so the
    // entity-row assertions would otherwise fail for the wrong reason.
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpSettingsScreen(
      tester,
      const OnlineSyncScreen(),
      repo: FakeSettingsRepository(),
      overrides: <Override>[
        // The saved profile name is the first source the card reads; pinned
        // blank here so the test states the session's own name, not a device's.
        profileFieldsProvider.overrideWith(() => _BlankProfileFields()),
        // The cached server profile is the third name source and reads Drift;
        // pinned empty so the suite needs no database.
        accountProfileProvider.overrideWith(
          (ref) => Stream<Profile?>.value(null),
        ),
        authIdentityProvider.overrideWithValue(identity),
        premiumAccessProvider.overrideWith((ref) async => premium),
        isOnlineProvider.overrideWith((ref) => Stream<bool>.value(online)),
        syncLastSuccessProvider.overrideWith(
          (ref) => Stream<int?>.value(lastSuccessEpochMs),
        ),
        syncStatusAttentionProvider.overrideWith(
          (ref) => Stream<int>.value(attention),
        ),
        syncQueueEntriesProvider.overrideWith(
          (ref) => Stream<List<SyncQueueRow>>.value(const <SyncQueueRow>[]),
        ),
        syncQueuePendingCountProvider.overrideWith(
          (ref) => Stream<int>.value(0),
        ),
        syncHealthProvider.overrideWith(
          (ref) => const Stream<SyncHealth>.empty(),
        ),
      ],
    );
  }

  testWidgets('a signed-in premium account is never told it is signed out', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Not signed in'), findsNothing);
    expect(find.text('Signed In As advocate.asad@law.com'), findsOneWidget);
    expect(
      find.text('Premium Sync Is Active Across Your Devices'),
      findsOneWidget,
    );
  });

  testWidgets('a signed-out account is told so, and cannot sync', (
    tester,
  ) async {
    await pump(tester, identity: null);

    // The account card and the status pill both say so — that is deliberate,
    // because the account answers "who" and the pill answers "what state".
    expect(find.text('Not signed in'), findsNWidgets(2));
    expect(
      find.text('Sign in to sync your data across all your devices'),
      findsOneWidget,
    );
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('a free account is told premium is what unlocks sync', (
    tester,
  ) async {
    await pump(tester, premium: false);

    expect(find.text('Free Plan'), findsOneWidget);
    expect(
      find.text('Premium Is Required To Sync Across Devices.'),
      findsOneWidget,
    );
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('an offline account cannot sync and is told why', (tester) async {
    await pump(tester, online: false);

    expect(find.text('No Connection'), findsWidgets);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('the status card reads the engine, not a fixed string', (
    tester,
  ) async {
    // A completed sync replaces the "never" line with a real relative time.
    await pump(
      tester,
      lastSuccessEpochMs:
          DateTime.now().toUtc().subtract(const Duration(hours: 2))
              .millisecondsSinceEpoch,
    );
    expect(find.text('Last Sync: Never'), findsNothing);
    expect(find.textContaining('Last Sync:'), findsOneWidget);
  });

  testWidgets('a device that has never synced says exactly that', (
    tester,
  ) async {
    await pump(tester, lastSuccessEpochMs: null);
    expect(find.text('Last Sync: Never'), findsOneWidget);
  });

  testWidgets('held work is surfaced, with the pill that says action is needed', (
    tester,
  ) async {
    await pump(tester, attention: 3);

    expect(find.text('Action Required'), findsOneWidget);
    expect(find.textContaining('could not be sent'), findsOneWidget);
  });

  testWidgets('a clean account reads as up to date', (tester) async {
    await pump(tester);

    expect(find.text('Up To Date'), findsOneWidget);
    expect(find.textContaining('backed up to your account'), findsOneWidget);
  });

  testWidgets('a premium, connected account can press Sync Now', (
    tester,
  ) async {
    await pump(tester);

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNotNull);
    expect(find.text('Sync Now'), findsOneWidget);
  });

  testWidgets('the three entity rows keep their counts', (tester) async {
    await pump(tester);

    // The rows read real local counts, which are empty in this harness — the
    // point is that the labels are present and each row is one card.
    expect(find.text('Cases'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('References'), findsOneWidget);
  });
}