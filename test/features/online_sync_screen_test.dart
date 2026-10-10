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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:legal_case_diary/core/constants/app_colors.dart';
import 'package:legal_case_diary/core/providers/repository_providers.dart';
import 'package:legal_case_diary/core/router/app_router.dart';
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

/// Stands in for the Subscription Plans route the free-plan link pushes.
const String _paywallMarker = 'Subscription Plans Route';

/// One queued sync entry, so a test can name the entity whose work is waiting.
SyncQueueRow _queueRow({required String entityType}) => SyncQueueRow(
  id: 1,
  entityType: entityType,
  entityId: 'e1',
  operation: 'update',
  mutationId: 'm1',
  basePayload: '{}',
  changedFields: '[]',
  payload: '{}',
  preMutationPayload: '{}',
  createdAt: 1,
  retryCount: 0,
  state: 'pending',
);

void main() {
  // The card reads the saved profile name, which lives in SharedPreferences.
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  /// The account and engine facts a test names, as the providers the screen
  /// reads.
  ///
  /// Every provider here is the real one the screen reads; only their values
  /// are pinned, so a future refactor that changes which provider feeds the
  /// card fails these tests rather than silently reverting to a stub.
  List<Override> overridesFor({
    AuthIdentity? identity = const AuthIdentity(
      userId: 'user-1',
      email: 'advocate.asad@law.com',
    ),
    bool premium = true,
    bool entitlementKnown = true,
    bool online = true,
    int? lastSuccessEpochMs,
    int attention = 0,
    List<SyncQueueRow> queued = const <SyncQueueRow>[],
  }) {
    return <Override>[
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
      // Whether the cached account row has landed. true here is the settled
      // state every ordinary case is in; only the checking test says false.
      entitlementKnownProvider.overrideWithValue(entitlementKnown),
      isOnlineProvider.overrideWith((ref) => Stream<bool>.value(online)),
      syncLastSuccessProvider.overrideWith(
        (ref) => Stream<int?>.value(lastSuccessEpochMs),
      ),
      syncStatusAttentionProvider.overrideWith(
        (ref) => Stream<int>.value(attention),
      ),
      syncQueueEntriesProvider.overrideWith(
        (ref) => Stream<List<SyncQueueRow>>.value(queued),
      ),
      syncQueuePendingCountProvider.overrideWith(
        (ref) => Stream<int>.value(0),
      ),
      syncHealthProvider.overrideWith(
        (ref) => const Stream<SyncHealth>.empty(),
      ),
    ];
  }

  /// Pumps the screen with the account and engine facts the test names.
  ///
  /// [inRouter] mounts it under a real router instead of a bare app, which is
  /// what a test that taps the free plan's link needs: that link pushes a
  /// route, and a bare app has nowhere to push it.
  Future<void> pump(
    WidgetTester tester, {
    AuthIdentity? identity = const AuthIdentity(
      userId: 'user-1',
      email: 'advocate.asad@law.com',
    ),
    bool premium = true,
    bool entitlementKnown = true,
    bool online = true,
    int? lastSuccessEpochMs,
    int attention = 0,
    List<SyncQueueRow> queued = const <SyncQueueRow>[],
    bool inRouter = false,
    Locale locale = const Locale('en'),
  }) async {
    // Tall viewport: a lazy ListView never builds an off-screen row, so the
    // entity-row assertions would otherwise fail for the wrong reason.
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final overrides = overridesFor(
      identity: identity,
      premium: premium,
      entitlementKnown: entitlementKnown,
      online: online,
      lastSuccessEpochMs: lastSuccessEpochMs,
      attention: attention,
      queued: queued,
    );

    if (!inRouter) {
      await pumpSettingsScreen(
        tester,
        const OnlineSyncScreen(),
        repo: FakeSettingsRepository(),
        locale: locale,
        overrides: overrides,
      );
      return;
    }

    await pumpSettingsRouter(
      tester,
      location: AppRoutes.settingsOnlineSync,
      locale: locale,
      overrides: <Override>[
        settingsRepositoryProvider.overrideWith(
          (ref) async => FakeSettingsRepository(),
        ),
        ...overrides,
      ],
      routes: [
        GoRoute(
          path: AppRoutes.settingsOnlineSync,
          builder: (_, _) => const OnlineSyncScreen(),
        ),
        GoRoute(
          path: AppRoutes.paywall,
          builder: (_, _) => const Scaffold(body: Text(_paywallMarker)),
        ),
      ],
    );
  }

  testWidgets('a signed-in premium account reports every entity synced', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Not signed in'), findsNothing);
    // The account card was removed: who is signed in and which plan they hold
    // are already stated in Settings > Manage Account, so this screen says it
    // once through the entity rows instead.
    expect(find.text('Signed In As advocate.asad@law.com'), findsNothing);
    // Nothing is queued and premium is active, so each row reads Synced.
    expect(find.text('Synced'), findsNWidgets(3));
    expect(find.text('Not synced'), findsNothing);
  });

  testWidgets('a signed-out account is told so, and cannot sync', (
    tester,
  ) async {
    await pump(tester, identity: null);

    // The status pill says so, and every entity row agrees — a row must never
    // claim Synced on an account that cannot reach the server.
    expect(find.text('Not signed in'), findsOneWidget);
    expect(find.text('Synced'), findsNothing);
    expect(find.text('Sign in to sync'), findsNWidgets(3));
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('a free account is told a plan unlocks sync, and how to buy one', (
    tester,
  ) async {
    await pump(tester, premium: false);

    expect(find.text('Free Plan'), findsOneWidget);
    // Regression: the same news twice in one card — the body sentence said
    // premium was required and the line under the Sync Now button repeated it.
    // One card, one telling.
    expect(
      find.textContaining(
        'A subscription plan is required to sync across devices. '
        'Purchase a plan from',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Premium is required to sync'), findsNothing);
    expect(
      find.text('Premium Is Required To Sync Across Devices.'),
      findsNothing,
    );

    // The sentence ends in a word that can be acted on, and looks it.
    final link = tester.widget<Text>(find.text('here'));
    expect(link.style?.fontWeight, FontWeight.w700);
    expect(link.style?.decoration, TextDecoration.underline);

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('the free plan sentence links to Subscription Plans', (
    tester,
  ) async {
    await pump(tester, premium: false, inRouter: true);

    await tester.tap(find.text('here'));
    await tester.pumpAndSettle();

    expect(find.text(_paywallMarker), findsOneWidget);
  });

  testWidgets('the sentence spans the card and is red, from the first word to the link', (
    tester,
  ) async {
    await pump(tester, premium: false);

    final sentence = find.textContaining('A subscription plan is required');
    expect(sentence, findsOneWidget);
    final sentenceText = tester.widget<Text>(sentence);

    // Red (user request): the sentence names what is missing — a plan — so it
    // reads as the reason sync is blocked, the same ink the card's own blocked
    // state uses, rather than the muted grey of an ordinary description. The
    // whole sentence is red, link and all.
    final textSpan = sentenceText.textSpan! as TextSpan;
    // The red is on the sentence's root style; the child text spans inherit it
    // rather than each carrying their own colour copy.
    expect(textSpan.style?.color, AppColors.error);
    final link = tester.widget<Text>(find.text('here'));
    expect(link.style?.color, AppColors.error);
    expect(link.style?.fontWeight, FontWeight.w700);
    expect(link.style?.decoration, TextDecoration.underline);

    // The heading sentence that used to sit above the card is gone (user
    // request), so the card leads the screen.
    expect(find.byType(OnlineSyncScreen), findsOneWidget);
    expect(
      find.textContaining('kept up to date on this device'),
      findsNothing,
    );

    // And it is laid out in the column the Sync Now button fills rather than
    // the header row's column. That one was 64px (48 + the 16 gap) narrower
    // than the card, so a long sentence wrapped early with the space to its
    // right left empty. The column's own width is measured, not the sentence's:
    // a Text reports its intrinsic width once it stops wrapping.
    expect(
      tester
          .getSize(find.ancestor(of: sentence, matching: find.byType(Column)).first)
          .width,
      tester.getSize(find.byType(FilledButton)).width,
    );
  });

  testWidgets('the sentence is Bengali, link and all, under বাংলা', (
    tester,
  ) async {
    // Both languages carry this sentence, and only the Bengali one shows that
    // the link is a translated word rather than the English "here".
    await pump(tester, premium: false, locale: const Locale('bn'));

    expect(
      find.textContaining(
        'ডিভাইসের মধ্যে সিঙ্ক করতে সাবস্ক্রিপশন প্ল্যান প্রয়োজন।',
      ),
      findsOneWidget,
    );
    final link = tester.widget<Text>(find.text('এখান থেকে'));
    expect(link.style?.fontWeight, FontWeight.w700);
    expect(link.style?.decoration, TextDecoration.underline);
  });

  testWidgets('an account whose plan is not known yet is not called free', (
    tester,
  ) async {
    // Regression: after a sign-in the profile pull has not landed, so the
    // entitlement derivation answers false for a premium account too. The card
    // used to print "Free Plan" and "A subscription plan is required to sync
    // across devices" at that moment — a lie about an account that had paid.
    await pump(tester, premium: false, entitlementKnown: false);

    expect(find.text('Free Plan'), findsNothing);
    expect(find.text('Checking Your Subscription…'), findsOneWidget);
    expect(
      find.textContaining('A subscription plan is required'),
      findsNothing,
    );
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('an offline account cannot sync, is told why, and is red', (
    tester,
  ) async {
    // Regression: the tint came from attention alone, so this card was green —
    // a green "No Connection" and a green Wi-Fi-off icon above a Sync Now that
    // cannot run, which is the screen contradicting itself.
    await pump(tester, online: false);

    final labels = tester
        .widgetList<Text>(find.text('No Connection'))
        .toList(growable: false);
    expect(labels, isNotEmpty);
    for (final label in labels) {
      expect(label.style?.color, AppColors.error);
    }

    final icons = tester
        .widgetList<Icon>(find.byIcon(Icons.wifi_off_outlined))
        .toList(growable: false);
    expect(icons, isNotEmpty);
    for (final icon in icons) {
      expect(icon.color, AppColors.error);
    }

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

  testWidgets('a row that cannot sync is red, never green', (tester) async {
    // Regression: a free account with nothing queued used to render "Not
    // synced" in the success green, which read as if it were already sent.
    await pump(tester, premium: false);

    final labels = tester
        .widgetList<Text>(find.text('Not synced'))
        .toList(growable: false);
    expect(labels, hasLength(3));
    for (final label in labels) {
      expect(label.style?.color, AppColors.error);
    }
    expect(find.text('Synced'), findsNothing);
  });

  testWidgets('a synced row is green', (tester) async {
    await pump(tester);

    final labels = tester
        .widgetList<Text>(find.text('Synced'))
        .toList(growable: false);
    expect(labels, hasLength(3));
    for (final label in labels) {
      expect(label.style?.color, AppColors.success);
    }
  });

  testWidgets('queued work outranks the blocker on every row', (tester) async {
    // Regression: the blocker was checked first, so two pending case edits on a
    // free plan read "Not synced" — telling the user nothing was queued when
    // two things were. Queued work is a fact regardless of plan or connection.
    await pump(
      tester,
      premium: false,
      queued: [_queueRow(entityType: 'case')],
    );

    // The Cases row shows the count; the untouched rows still report red.
    expect(find.text('1 Waiting'), findsOneWidget);
    expect(find.text('Not synced'), findsNWidgets(2));
    expect(find.text('Synced'), findsNothing);
  });

  testWidgets('a queued row is amber, never red', (tester) async {
    await pump(tester, queued: [_queueRow(entityType: 'case')]);

    final label = tester.widget<Text>(find.text('1 Waiting'));
    expect(label.style?.color, AppColors.tertiary);
  });

  testWidgets('Pending Sync is the last thing on the screen', (tester) async {
    await pump(tester);

    expect(find.text('Pending Sync'), findsOneWidget);
    // It sits after References, not above the entity rows: it is where held
    // work is reviewed, so it belongs below what it is work *about*.
    final pendingEntry = tester.getTopLeft(find.text('Pending Sync'));
    final references = tester.getTopLeft(find.text('References'));
    expect(pendingEntry.dy, greaterThan(references.dy));
    // And it still opens the Sync Status screen.
    expect(find.text('Every Change Waiting To Be Sent'), findsOneWidget);
  });

  testWidgets('the switch sits below the entity rows, on its own card', (
    tester,
  ) async {
    await pump(tester);

    // Its own card, below the rows it acts on and above the entry that reviews
    // held work — not beside Sync Now, where it would read as a second way to
    // sync (user request).
    final toggle = tester.getTopLeft(find.text('Sync Is On'));
    expect(
      toggle.dy,
      greaterThan(tester.getTopLeft(find.text('References')).dy),
    );
    expect(
      toggle.dy,
      lessThan(tester.getTopLeft(find.text('Pending Sync')).dy),
    );
  });

  testWidgets('the switch turns sync off, and the screen says so', (
    tester,
  ) async {
    await pump(tester);

    // Sync on: the way to turn it off is offered in outline, so it does not
    // compete with Sync Now.
    expect(find.text('Sync Is On'), findsOneWidget);
    expect(find.text('Disable Sync'), findsOneWidget);
    expect(find.text('Sync Now'), findsOneWidget);

    await tester.tap(find.text('Disable Sync'));
    await tester.pumpAndSettle();

    // The switch wrote the engine's own flag: the request asked for a pause, not
    // for anything the screen invents for itself.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(OnlineSyncScreen)),
      listen: false,
    );
    expect(container.read(syncEnabledProvider), isFalse);

    // Everything on the card follows from that one fact: the pill, the body, the
    // disabled CTA with its reason, and rows that no longer claim Synced.
    expect(find.text('Sync Off'), findsOneWidget);
    expect(
      find.textContaining('Turn it back on to send and receive'),
      findsOneWidget,
    );
    expect(find.text('Sync Is Off'), findsOneWidget);
    expect(find.textContaining('Turn It Back On To Sync'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Sync Now'))
          .onPressed,
      isNull,
    );
    expect(find.text('Synced'), findsNothing);
    expect(find.text('Not synced'), findsNWidgets(3));
    // Muted, not red: the user asked for this state, so nothing has failed.
    for (final label in tester.widgetList<Text>(find.text('Not synced'))) {
      expect(label.style?.color, AppColors.onSurfaceVariant);
    }
    expect(
      find.text('Sync Is Off. Your Changes Stay On This Device.'),
      findsOneWidget,
    );

    // Let that toast go, so the next one is the one being read.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    // And back: the switch is the only way out, and it restores the screen.
    await tester.tap(find.text('Enable Sync'));
    await tester.pumpAndSettle();

    expect(container.read(syncEnabledProvider), isTrue);
    expect(find.text('Up To Date'), findsOneWidget);
    expect(find.text('Synced'), findsNWidgets(3));
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Sync Now'))
          .onPressed,
      isNotNull,
    );
    expect(find.text('Sync Is On Again.'), findsOneWidget);
  });
}