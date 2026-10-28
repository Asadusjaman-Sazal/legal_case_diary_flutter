/// Task 20 Phase 3 — the one delete decision point.
///
/// Every delete in the app goes through `deleteThroughFirmRules`, so its two
/// branches are the whole associate-side rule: a member who may delete does so,
/// exactly as before, and a member who may not raises a `delete_requests` row
/// instead. These tests pin the branch itself — which window is shown, what is
/// written, and what is written *nothing* — against the real permission
/// providers, so the decision is made from the same cached rows production reads.
///
/// The network boundary is the only fake: `deleteRequestsRepositoryProvider`
/// records what a request would carry, and `permissionFreshnessProvider` is a
/// no-op because the refresh it stands for is wired and tested elsewhere.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/core/constants/app_colors.dart';
import 'package:legal_case_diary/core/constants/app_spacing.dart';
import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/providers/repository_providers.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/account_mode.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/local/firm_members_dao.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/local/profiles_dao.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/profile_repository.dart';
import 'package:legal_case_diary/features/auth/data/auth_repository.dart';
import 'package:legal_case_diary/features/auth/presentation/auth_viewmodel.dart';
import 'package:legal_case_diary/features/settings/data/delete_requests_repository.dart';
import 'package:legal_case_diary/features/settings/presentation/delete_request_flow.dart';

import 'auth_test_support.dart';

/// A [DeleteRequestsRepository] that records the requests it was asked to make.
///
/// Nothing here reaches `sync_queue` or Drift: this suite is about the *decision*
/// — whether a request is raised at all and what it would say — and the queueing
/// is pinned by `repositories_test.dart`.
class _RecordingDeleteRequestsRepository implements DeleteRequestsRepository {
  /// Every `createRequest` call, in order.
  final List<Map<String, Object?>> created = <Map<String, Object?>>[];

  /// The open requests the flow already sees on this device.
  List<DeleteRequest> open = <DeleteRequest>[];

  @override
  Future<String> createRequest({
    required String entityType,
    required String entityId,
    required Map<String, dynamic> entitySnapshot,
    required int targetBaseVersion,
    required String firmId,
    required String requesterName,
  }) async {
    created.add(<String, Object?>{
      'entityType': entityType,
      'entityId': entityId,
      'entitySnapshot': entitySnapshot,
      'targetBaseVersion': targetBaseVersion,
      'firmId': firmId,
      'requesterName': requesterName,
    });
    return 'request-1';
  }

  @override
  Future<void> refreshSnapshot({
    required String id,
    required Map<String, dynamic> entitySnapshot,
    required int targetBaseVersion,
  }) async {}

  @override
  Future<void> cancel(String id) async {}

  @override
  Future<void> approve(String id, {String? reviewNote}) async {}

  @override
  Future<void> reject(String id, {String? reviewNote}) async {}

  @override
  Future<List<DeleteRequest>> listAll({int? limit, int? offset}) async => open;

  @override
  Stream<List<DeleteRequest>> watchAll({int? limit, int? offset}) =>
      const Stream<List<DeleteRequest>>.empty();

  @override
  Stream<List<DeleteRequest>> watchMine(String requestedBy) =>
      const Stream<List<DeleteRequest>>.empty();

  @override
  Future<DeleteRequest?> getById(String id) async => null;
}

/// The screen body under test: one button that runs the flow, plus the two
/// callbacks a test uses to see what the flow decided.
class _FlowHost extends ConsumerWidget {
  const _FlowHost({required this.deleteDirectly, required this.onOutcome});

  /// Stands in for the caller's own deletion.
  final Future<void> Function() deleteDirectly;

  /// Receives what the flow ended as.
  final void Function(DeleteOutcome outcome) onOutcome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keeps the permission chain alive and recalculating as the test seeds the
    // cache: the flow under test *reads* the provider at tap time, and a read
    // that finds the stream un-emitted would answer with the pre-seed default.
    ref.watch(canDeleteDirectlyProvider);
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          key: const ValueKey('run-delete'),
          onPressed: () async {
            final outcome = await deleteThroughFirmRules(
              context,
              ref,
              entityType: 'note',
              entityId: 'note-1',
              entitySnapshot: const <String, dynamic>{'id': 'note-1'},
              targetBaseVersion: 7,
              deleteDirectly: deleteDirectly,
            );
            onOutcome(outcome);
          },
          // Deliberately not "Delete": the confirmation window has its own
          // Delete button, and a duplicate label would make the tap ambiguous.
          child: const Text('Run Flow'),
        ),
      ),
    );
  }
}

void main() {
  late AuthTestHarness harness;
  late AppDatabase db;
  late _RecordingDeleteRequestsRepository requests;
  var directCalls = 0;
  DeleteOutcome? outcome;

  setUp(() {
    directCalls = 0;
    outcome = null;
    requests = _RecordingDeleteRequestsRepository();
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

  /// Writes the cached profile the permission providers read.
  Future<void> seedProfile({String? firmId, String role = 'individual'}) =>
      ProfilesDao(db).upsert(
        ProfilesCompanion(
          id: const Value('user-1'),
          fullName: const Value('Adv. Karim'),
          role: Value(role),
          firmId: Value(firmId),
          subscriptionStatus: const Value('free'),
          createdAt: const Value(1),
        ),
      );

  /// Writes this account's cached membership row, with its delete flag.
  Future<void> seedMembership({bool canDelete = false}) =>
      FirmMembersDao(db).upsert(
        FirmMembersCompanion(
          id: const Value('firm-1:user-1'),
          firmId: const Value('firm-1'),
          userId: const Value('user-1'),
          role: const Value(AccountRole.associate),
          canAdd: const Value(true),
          canEdit: const Value(true),
          canDelete: Value(canDelete),
          permissionsSyncedAt: const Value(1),
        ),
      );

  /// Pumps the flow host over the harness database.
  Future<void> pumpFlow(WidgetTester tester) async {
    final overrides = await harness.setUp(
      extra: <Override>[
        // The refresh the flow performs is pinned by `account_mode_test.dart`;
        // here it is a no-op so the decision is the only thing under test.
        permissionFreshnessProvider.overrideWithValue(() async {}),
        deleteRequestsRepositoryProvider.overrideWith((ref) async => requests),
        // The identity the caches are keyed by, stated directly: the real
        // `AuthViewModel` also runs identity adoption on its first read, which
        // is not what this suite is about.
        authIdentityProvider.overrideWithValue(
          const AuthIdentity(userId: 'user-1', email: 'advocate.asad@law.com'),
        ),
      ],
    );
    db = harness.db;
    await pumpAuthScreen(
      tester,
      _FlowHost(
        deleteDirectly: () async => directCalls++,
        onOutcome: (value) => outcome = value,
      ),
      overrides: overrides,
    );
  }

  testWidgets('an individual deletes directly through the shared window', (
    tester,
  ) async {
    await pumpFlow(tester);
    await seedProfile();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('run-delete')));
    await tester.pumpAndSettle();

    final l = await AppLocalizations.delegate.load(const Locale('en'));
    // Own diary: the ordinary delete window, not the request one.
    expect(find.text(l.sharedDialogs_confirmDeleteTitle), findsOneWidget);
    expect(find.text(l.deleteRequest_confirmTitle), findsNothing);

    await tester.tap(find.text(l.sharedActions_delete));
    await tester.pumpAndSettle();

    expect(directCalls, 1);
    expect(outcome, DeleteOutcome.deleted);
    expect(
      requests.created,
      isEmpty,
      reason: 'an individual has nobody to ask',
    );

    await unmountApp(tester);
  });

  testWidgets('an owner deletes directly', (tester) async {
    await pumpFlow(tester);
    await seedProfile(firmId: 'firm-1', role: AccountRole.owner);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('run-delete')));
    await tester.pumpAndSettle();

    final l = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l.sharedDialogs_confirmDeleteTitle), findsOneWidget);
    await tester.tap(find.text(l.sharedActions_delete));
    await tester.pumpAndSettle();

    expect(directCalls, 1);
    expect(outcome, DeleteOutcome.deleted);
    expect(requests.created, isEmpty);

    await unmountApp(tester);
  });

  testWidgets('a member without delete permission raises a request', (
    tester,
  ) async {
    await pumpFlow(tester);
    await seedProfile(firmId: 'firm-1', role: AccountRole.associate);
    await seedMembership(canDelete: false);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('run-delete')));
    await tester.pumpAndSettle();

    final l = await AppLocalizations.delegate.load(const Locale('en'));
    // The request wording, never the delete one: nothing is removed yet.
    expect(find.text(l.deleteRequest_confirmTitle), findsOneWidget);
    expect(find.text(l.sharedDialogs_confirmDeleteTitle), findsNothing);

    // The action is worded literally, so a later edit to the label cannot pass
    // unnoticed; the wording itself is the request's, and nothing else changes.
    expect(find.text('Send'), findsOneWidget);

    // The title is worded literally, so a later edit to it cannot pass
    // unnoticed, and it is centred; the sentence below it is sentence case —
    // the first word only — and likewise pinned literally.
    expect(find.text('Request Deletion'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text(l.deleteRequest_confirmTitle)).textAlign,
      TextAlign.center,
    );
    expect(
      find.text(
        'A firm member with delete permission has to approve it before the '
        'record is removed.',
      ),
      findsOneWidget,
    );
    // The sentence reaches both edges in this window only (user request),
    // read from the painted paragraph rather than the widget's own argument.
    expect(
      tester
          .renderObject<RenderParagraph>(find.text(l.deleteRequest_confirmBody))
          .textAlign,
      TextAlign.justify,
    );

    // The Exit App window's geometry: its 8 px corner, its centred actions and
    // its 112 x 48 buttons at 16 pt.
    final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
    expect(
      (dialog.shape! as RoundedRectangleBorder).borderRadius,
      BorderRadius.circular(AppSpacing.cardRadius * 2),
    );
    expect(dialog.actionsAlignment, MainAxisAlignment.center);
    // The Exit App window's action style — a 112 x 48 minimum at 16 pt — is
    // asserted on the style the window asks for rather than on the laid-out
    // pixels: this harness runs the app's `VisualDensity.compact` theme, which
    // shaves the same 8 px off both buttons as it does off the Exit window's.
    final cancelButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, l.sharedActions_cancel),
    );
    final sendButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, l.deleteRequest_confirmSend),
    );
    for (final style in <ButtonStyle>[cancelButton.style!, sendButton.style!]) {
      expect(style.minimumSize!.resolve(<WidgetState>{}), const Size(112, 48));
      expect(style.textStyle!.resolve(<WidgetState>{})!.fontSize, 16);
    }
    // Send is red with white text (user request).
    expect(
      sendButton.style?.backgroundColor?.resolve(const <WidgetState>{}),
      AppColors.error,
    );
    expect(
      sendButton.style?.foregroundColor?.resolve(const <WidgetState>{}),
      AppColors.onError,
    );
    // Both actions are the same height, one Cancel and one Send.
    expect(
      tester
          .getSize(find.widgetWithText(TextButton, l.sharedActions_cancel))
          .height,
      tester
          .getSize(
            find.widgetWithText(FilledButton, l.deleteRequest_confirmSend),
          )
          .height,
    );

    await tester.tap(find.text(l.deleteRequest_confirmSend));
    await tester.pumpAndSettle();

    expect(directCalls, 0);
    expect(outcome, DeleteOutcome.requested);
    expect(requests.created, hasLength(1));
    final request = requests.created.single;
    expect(request['entityType'], 'note');
    expect(request['entityId'], 'note-1');
    expect(request['targetBaseVersion'], 7);
    expect(
      request['firmId'],
      'firm-1',
      reason: 'a request with no firm is one the server refuses',
    );
    // The requester's own cached name rides on the request, so a reviewer can
    // read who asked even before the request reaches the server.
    expect(request['requesterName'], 'Adv. Karim');
    // The toast is a sentence, so only its first word is capitalised, and it
    // names no role: the request reaches whoever in the chamber may delete, not
    // necessarily its owner, and no admin screen shows these at all.
    expect(l.deleteRequest_sent, 'Deletion request sent for approval.');
    expect(find.text(l.deleteRequest_sent), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('a member with delete permission deletes directly', (
    tester,
  ) async {
    await pumpFlow(tester);
    await seedProfile(firmId: 'firm-1', role: AccountRole.associate);
    await seedMembership(canDelete: true);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('run-delete')));
    await tester.pumpAndSettle();

    final l = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l.sharedDialogs_confirmDeleteTitle), findsOneWidget);
    await tester.tap(find.text(l.sharedActions_delete));
    await tester.pumpAndSettle();

    expect(directCalls, 1);
    expect(outcome, DeleteOutcome.deleted);
    expect(requests.created, isEmpty);

    await unmountApp(tester);
  });

  testWidgets('declining the request window changes nothing', (tester) async {
    await pumpFlow(tester);
    await seedProfile(firmId: 'firm-1', role: AccountRole.associate);
    await seedMembership(canDelete: false);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('run-delete')));
    await tester.pumpAndSettle();

    final l = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l.deleteRequest_confirmTitle), findsOneWidget);
    await tester.tap(find.text(l.sharedActions_cancel));
    await tester.pumpAndSettle();

    expect(directCalls, 0);
    expect(outcome, DeleteOutcome.cancelled);
    expect(requests.created, isEmpty);
    expect(find.text(l.deleteRequest_sent), findsNothing);

    await unmountApp(tester);
  });

  testWidgets('a second request for a record that already has one is refused', (
    tester,
  ) async {
    await pumpFlow(tester);
    await seedProfile(firmId: 'firm-1', role: AccountRole.associate);
    await seedMembership(canDelete: false);
    // A colleague already asked to delete this exact record. The server enforces
    // one open request per record with a unique index; the flow says so first.
    requests.open = <DeleteRequest>[
      const DeleteRequest(
        id: 'open-1',
        entityType: 'note',
        entityId: 'note-1',
        entitySnapshot: '{}',
        targetBaseVersion: 1,
        requestedBy: 'user-2',
        requesterName: 'Jannatul',
        status: 'pending',
        createdAt: 1,
        updatedAt: 1,
        isDeleted: false,
      ),
    ];
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('run-delete')));
    await tester.pumpAndSettle();

    final l = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.tap(find.text(l.deleteRequest_confirmSend));
    await tester.pumpAndSettle();

    expect(requests.created, isEmpty);
    expect(outcome, DeleteOutcome.cancelled);
    expect(find.text(l.deleteRequest_alreadyOpen), findsOneWidget);
    expect(find.text(l.deleteRequest_sent), findsNothing);

    await unmountApp(tester);
  });

  testWidgets('a firm member with no cached permissions fails closed', (
    tester,
  ) async {
    await pumpFlow(tester);
    // Firm mode, but the membership row has not been pulled yet: this is the
    // advisory-cache rule's safe direction — ask rather than delete.
    await seedProfile(firmId: 'firm-1', role: AccountRole.associate);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('run-delete')));
    await tester.pumpAndSettle();

    final l = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l.deleteRequest_confirmTitle), findsOneWidget);
    await tester.tap(find.text(l.deleteRequest_confirmSend));
    await tester.pumpAndSettle();

    expect(directCalls, 0);
    expect(outcome, DeleteOutcome.requested);
    expect(requests.created, hasLength(1));
    expect(requests.created.single['firmId'], 'firm-1');

    await unmountApp(tester);
  });
}
