/// Delete Account — the warning, the typed confirmation, and the wired deletion
/// (0.0.411, two gates since 0.0.412).
///
/// The Delete Account card used to warn nothing and do nothing (the last Part A
/// placeholder on the Settings surface). What it does now is one flow with two
/// gates, and each step of it is pinned here against a faked server:
///
/// * **nothing is deleted without the warning** — Cancel, and a dismissed
///   window, leave the account and its data exactly as they were;
/// * **nothing is deleted without the typed phrase** — the confirmation screen's
///   button is disabled until the field holds `delete my account` (trimmed and
///   case-insensitively), a wrong phrase leaves the account alone, and leaving
///   the screen deletes nothing either;
/// * the instruction's **phrase is the only red, bold run** in the sentence, so
///   the words to type are the ones the eye lands on;
/// * the warning is **worded for this account's plan**, because a free
///   account's diary has never left the device while a premium one's is in the
///   cloud as well;
/// * **offline it refuses** — the account row is on the server, so there is no
///   local-only deletion to fall back to and nothing local is touched either;
/// * a **refusal** (a firm account) and a **failure** each stop with their own
///   sentence, and both leave the device as it was;
/// * a confirmed deletion **wipes this device and ends the session**, landing
///   the user on Login with a fresh install's database.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:legal_case_diary/core/constants/app_colors.dart';
import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/providers/repository_providers.dart';
import 'package:legal_case_diary/core/router/app_router.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/account_deletion_repository.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/local/profiles_dao.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/profile_repository.dart';
import 'package:legal_case_diary/features/accounts_and_profile/presentation/delete_account_screen.dart';
import 'package:legal_case_diary/features/accounts_and_profile/presentation/manage_account_screen.dart';
import 'package:legal_case_diary/features/auth/data/auth_repository.dart';
import 'package:legal_case_diary/features/auth/data/local_auth_service.dart';
import 'package:legal_case_diary/sync/connectivity_monitor.dart';

import 'auth_test_support.dart';
import 'settings_test_support.dart';

/// Marker rendered by the stand-in Login route a completed deletion lands on.
const String loginRouteMarker = 'Login Route';

/// The deletion boundary, driven by the test instead of the network.
class FakeAccountDeletionRepository implements AccountDeletionRepository {
  /// Creates the fake, answering [outcome] every time.
  FakeAccountDeletionRepository(this.outcome);

  /// What the server would answer.
  AccountDeletionOutcome outcome;

  /// How many times the server was asked to remove this account.
  int calls = 0;

  @override
  Future<AccountDeletionOutcome> deleteAccount() async {
    calls++;
    return outcome;
  }
}

/// One note, so a wipe has something of the user's to destroy.
Future<void> _seedNote(AppDatabase db) => db
    .into(db.notes)
    .insert(
      NotesCompanion.insert(
        id: 'n1',
        userId: 'user-1',
        title: 'Local',
        body: 'Body',
        createdAt: 0,
        updatedAt: 0,
      ),
    );

void main() {
  late AuthTestHarness harness;
  late AppLocalizations l;

  setUp(() {
    harness = AuthTestHarness(
      auth: FakeAuthRepository(
        identity: const AuthIdentity(
          userId: 'user-1',
          email: 'advocate.asad@law.com',
        ),
      ),
    );
  });

  tearDown(() async {
    await harness.tearDown();
    await harness.auth.dispose();
  });

  /// Pumps Manage Account on its own route, with a local profile row and one
  /// note of the user's own, and returns nothing — assertions read the harness.
  Future<void> pumpManageAccount(
    WidgetTester tester, {
    required AccountDeletionRepository deletion,
    bool online = true,
    bool premium = false,
    Locale locale = const Locale('en'),
  }) async {
    await tester.binding.setSurfaceSize(const Size(420, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final overrides = <Override>[
      accountDeletionRepositoryProvider.overrideWithValue(deletion),
      isOnlineProvider.overrideWith((ref) => Stream<bool>.value(online)),
      logoutFlowOverride(premium: premium),
    ];

    await pumpSettingsRouter(
      tester,
      location: AppRoutes.settingsManageAccount,
      overrides: await harness.setUp(extra: overrides),
      locale: locale,
      routes: [
        GoRoute(
          path: AppRoutes.settingsManageAccount,
          builder: (_, _) => const ManageAccountScreen(),
        ),
        GoRoute(
          path: AppRoutes.settingsDeleteAccount,
          builder: (_, _) => const DeleteAccountScreen(),
        ),
        // Where a completed deletion lands: Login is a top-level route, so the
        // screen leaves the shell for it rather than popping back to Settings.
        GoRoute(
          path: AppRoutes.login,
          builder: (_, _) => const Scaffold(body: Text(loginRouteMarker)),
        ),
      ],
    );
    l = await AppLocalizations.delegate.load(locale);
    // A device already in use: the remembered account is what the sign-out at
    // the end of a successful deletion must clear.
    await harness.prefs.setString(authUserIdKey, 'user-1');

    await ProfilesDao(harness.db).upsert(
      ProfilesCompanion(
        id: const Value('user-1'),
        fullName: const Value('Adv. Rahim Uddin'),
        role: const Value(AccountRole.individual),
        subscriptionStatus: Value(premium ? 'active' : 'free'),
        // Entitlement is derived from the expiry + 48 h grace — never from the
        // status flag — so a premium fixture needs a real future date.
        subscriptionExpiry: Value(
          premium
              ? DateTime.now()
                    .toUtc()
                    .add(const Duration(days: 30))
                    .millisecondsSinceEpoch
              : null,
        ),
        createdAt: const Value(1),
      ),
    );
    await _seedNote(harness.db);
    await tester.pumpAndSettle();
  }

  /// Taps the Delete Account card, scrolling it into view first.
  Future<void> tapDeleteCard(WidgetTester tester) async {
    final card = find.text(l.settingsManageAccount_deleteAccount);
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();
    await tester.tap(card);
    await tester.pumpAndSettle();
  }

  /// Answers the warning, landing on the typed confirmation.
  ///
  /// Both gates are asserted where they appear, because each is the only thing
  /// that stands between a tap and a deleted account: a test that skipped them
  /// would pass even if the card went straight to deleting.
  Future<void> answerWarning(WidgetTester tester) async {
    expect(
      find.text(l.settingsManageAccount_deleteDialogTitle),
      findsOneWidget,
      reason: 'the warning comes before anything is destroyed',
    );
    await tester.tap(
      find.widgetWithText(FilledButton, l.settingsManageAccount_deleteAccount),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('delete-account-phrase')),
      findsOneWidget,
      reason: 'the warning opens the typed confirmation, not the deletion',
    );
  }

  /// Types [text] into the confirmation field.
  Future<void> typePhrase(WidgetTester tester, String text) async {
    await tester.enterText(
      find.byKey(const ValueKey('delete-account-phrase')),
      text,
    );
    await tester.pumpAndSettle();
  }

  /// Whether the confirmation screen's destructive button is enabled.
  bool confirmEnabled(WidgetTester tester) {
    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('delete-account-confirm')),
    );
    return button.onPressed != null;
  }

  /// Types the phrase and taps the confirmation screen's button.
  Future<void> submitConfirmation(WidgetTester tester) async {
    await typePhrase(tester, l.settingsManageAccount_deleteConfirmPhrase);
    await tester.tap(find.byKey(const ValueKey('delete-account-confirm')));
    await tester.pumpAndSettle();
  }

  /// The runs the confirmation sentence is built from, in order.
  ///
  /// The sentence is one ARB string with the phrase as its placeholder, so the
  /// screen renders it as rich text; these are the pieces it composed. It is
  /// found by its own text rather than by position, because the card holds other
  /// text as well.
  List<TextSpan> confirmSentenceRuns(WidgetTester tester, AppLocalizations l) {
    final sentence = l.settingsManageAccount_deleteConfirmBody(
      l.settingsManageAccount_deleteConfirmPhrase,
    );
    final instruction = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.textSpan)
        .whereType<TextSpan>()
        .firstWhere((span) => span.toPlainText() == sentence);
    return (instruction.children ?? const <InlineSpan>[]).cast<TextSpan>();
  }

  /// The account's own work is still on the device.
  Future<void> expectNothingDeleted() async {
    expect(await ProfilesDao(harness.db).getAll(), hasLength(1));
    expect(await harness.db.select(harness.db.notes).get(), hasLength(1));
    expect(harness.auth.signOutCalls, 0);
    expect(LocalAuthService(harness.prefs).cachedUserId, 'user-1');
  }

  testWidgets('a free account is warned that its device data goes', (
    tester,
  ) async {
    final deletion = FakeAccountDeletionRepository(
      AccountDeletionOutcome.deleted,
    );
    await pumpManageAccount(tester, deletion: deletion);

    await tapDeleteCard(tester);

    // The free sentence, not the premium one: this diary never reached a cloud.
    expect(
      find.text(l.settingsManageAccount_deleteWarningFree),
      findsOneWidget,
    );
    expect(
      find.text(l.settingsManageAccount_deleteWarningPremium),
      findsNothing,
    );

    await tester.tap(find.widgetWithText(TextButton, l.sharedActions_cancel));
    await tester.pumpAndSettle();

    expect(deletion.calls, 0, reason: 'Cancel deletes nothing');
    await expectNothingDeleted();
    expect(find.text(loginRouteMarker), findsNothing);

    await unmountApp(tester);
  });

  testWidgets('a premium account is warned that its cloud data goes too', (
    tester,
  ) async {
    final deletion = FakeAccountDeletionRepository(
      AccountDeletionOutcome.deleted,
    );
    await pumpManageAccount(tester, deletion: deletion, premium: true);

    await tapDeleteCard(tester);

    expect(
      find.text(l.settingsManageAccount_deleteWarningPremium),
      findsOneWidget,
    );
    expect(find.text(l.settingsManageAccount_deleteWarningFree), findsNothing);

    await tester.tap(find.widgetWithText(TextButton, l.sharedActions_cancel));
    await tester.pumpAndSettle();
    expect(deletion.calls, 0);

    await unmountApp(tester);
  });

  testWidgets('offline it refuses and deletes nothing', (tester) async {
    // The account exists on the server, so there is no local-only deletion: the
    // honest answer is to say a connection is needed and leave the diary alone.
    final deletion = FakeAccountDeletionRepository(
      AccountDeletionOutcome.deleted,
    );
    await pumpManageAccount(tester, deletion: deletion, online: false);

    await tapDeleteCard(tester);
    await answerWarning(tester);
    await submitConfirmation(tester);

    expect(deletion.calls, 0, reason: 'nothing is sent to the server offline');
    await expectNothingDeleted();
    expect(
      find.text(l.settingsManageAccount_deleteNeedsConnection),
      findsOneWidget,
    );

    await unmountApp(tester);
  });

  testWidgets('a refused deletion says why and keeps the account', (
    tester,
  ) async {
    // A firm member's rows are partly the firm's, so the server refuses and the
    // screen passes its reason on. Nothing local is touched either.
    final deletion = FakeAccountDeletionRepository(
      AccountDeletionOutcome.refusedFirm,
    );
    await pumpManageAccount(tester, deletion: deletion);

    await tapDeleteCard(tester);
    await answerWarning(tester);
    await submitConfirmation(tester);

    expect(
      find.text(l.settingsManageAccount_deleteFirmRefused),
      findsOneWidget,
    );
    expect(deletion.calls, 1);
    await expectNothingDeleted();

    await unmountApp(tester);
  });

  testWidgets('a failed deletion is reported and keeps the account', (
    tester,
  ) async {
    final deletion = FakeAccountDeletionRepository(
      AccountDeletionOutcome.failed,
    );
    await pumpManageAccount(tester, deletion: deletion);

    await tapDeleteCard(tester);
    await answerWarning(tester);
    await submitConfirmation(tester);

    expect(find.text(l.settingsManageAccount_deleteFailed), findsOneWidget);
    expect(deletion.calls, 1);
    await expectNothingDeleted();

    await unmountApp(tester);
  });

  testWidgets('a confirmed deletion wipes the device and ends the session', (
    tester,
  ) async {
    final deletion = FakeAccountDeletionRepository(
      AccountDeletionOutcome.deleted,
    );
    await pumpManageAccount(tester, deletion: deletion);

    await tapDeleteCard(tester);
    await answerWarning(tester);
    await submitConfirmation(tester);

    expect(deletion.calls, 1);
    // The server removed the account, so this device goes back to what an
    // install starts from — the logout flow's own wipe — and signs out.
    expect(await harness.db.select(harness.db.notes).get(), isEmpty);
    expect(await ProfilesDao(harness.db).getAll(), isEmpty);
    expect(harness.auth.signOutCalls, 1);
    expect(LocalAuthService(harness.prefs).cachedUserId, isNull);
    expect(find.text(l.settingsManageAccount_deleted), findsOneWidget);
    // And the user lands on the sign-in screen, not on an emptied Settings list.
    expect(find.text(loginRouteMarker), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('the destructive button unlocks only on the typed phrase', (
    tester,
  ) async {
    final deletion = FakeAccountDeletionRepository(
      AccountDeletionOutcome.deleted,
    );
    await pumpManageAccount(tester, deletion: deletion);

    await tapDeleteCard(tester);
    await answerWarning(tester);

    // Nothing typed: the action is not available at all.
    expect(
      confirmEnabled(tester),
      isFalse,
      reason: 'the gate is shut to begin with',
    );

    await typePhrase(tester, 'delete');
    expect(
      confirmEnabled(tester),
      isFalse,
      reason: 'a partial phrase is not the phrase',
    );

    await typePhrase(tester, 'delete my accounts');
    expect(confirmEnabled(tester), isFalse, reason: 'nearly is not the phrase');

    // The same intent in another case, with stray whitespace, is accepted: the
    // gate is there for deliberation, not typing practice.
    await typePhrase(tester, '  Delete My Account ');
    expect(confirmEnabled(tester), isTrue);

    // And leaving without pressing it deletes nothing at all.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text(l.settingsManageAccount_deleteDialogTitle), findsNothing);
    expect(deletion.calls, 0);
    await expectNothingDeleted();

    await unmountApp(tester);
  });

  testWidgets('only the phrase in the instruction is red and bold', (
    tester,
  ) async {
    // The words to type are the only part of the sentence the user must notice,
    // so they carry the app's error ink and weight and the sentence around them
    // stays ordinary body text.
    final deletion = FakeAccountDeletionRepository(
      AccountDeletionOutcome.deleted,
    );
    await pumpManageAccount(tester, deletion: deletion);

    await tapDeleteCard(tester);
    await answerWarning(tester);

    final phrase = l.settingsManageAccount_deleteConfirmPhrase;
    final runs = confirmSentenceRuns(tester, l);
    expect(
      runs.map((run) => run.text).join(),
      l.settingsManageAccount_deleteConfirmBody(phrase),
      reason: 'the styled runs are still the whole sentence',
    );

    final styled = runs.singleWhere((run) => run.text == phrase);
    expect(styled.style?.color, AppColors.error);
    expect(styled.style?.fontWeight, FontWeight.w700);

    // And nothing else in the sentence is either red or bold.
    for (final run in runs.where((run) => run.text != phrase)) {
      expect(run.style?.color, isNot(AppColors.error));
      expect(run.style?.fontWeight, isNot(FontWeight.w700));
    }

    await unmountApp(tester);
  });

  testWidgets('the phrase stays English in Bengali', (tester) async {
    // The user's own instruction: the confirmation words are the same in both
    // languages, so the Bengali instruction and the string the code compares
    // cannot drift apart.
    final deletion = FakeAccountDeletionRepository(
      AccountDeletionOutcome.deleted,
    );
    await pumpManageAccount(
      tester,
      deletion: deletion,
      locale: const Locale('bn'),
    );

    await tapDeleteCard(tester);
    await answerWarning(tester);

    expect(
      find.text(
        l.settingsManageAccount_deleteConfirmBody('delete my account'),
        findRichText: true,
      ),
      findsOneWidget,
      reason: 'the Bengali sentence carries the English phrase',
    );
    expect(
      l.settingsManageAccount_deleteConfirmPhrase,
      'delete my account',
      reason: 'the phrase is not translated',
    );
    // Still the styled run in Bengali — the phrase is the one part that does
    // not follow the language of the sentence around it.
    final styled = confirmSentenceRuns(
      tester,
      l,
    ).singleWhere((run) => run.style?.color == AppColors.error);
    expect(styled.text, 'delete my account');
    expect(styled.style?.fontWeight, FontWeight.w700);
    await typePhrase(tester, 'delete my account');
    expect(confirmEnabled(tester), isTrue);

    await unmountApp(tester);
  });
}
