/// ViewModel for the delete requests feature.
///
/// Exposes a reactive list of delete requests and a creation helper. Since
/// Task 20 Phase 3 the request is **not** raised by a screen: every delete runs
/// through `deleteThroughFirmRules`, which raises one when the signed-in member
/// has no delete permission. This view model is the list side of the feature —
/// the requester's own requests and, from Phase 4, the reviewer's queue — plus
/// the two writers a reviewer uses ([approve] and [reject]). UI code should use
/// `.select()` to subscribe only to the fields it needs.
///
/// A requester's own pending request is also editable here (Phase 3 item 3):
/// [refreshSnapshot] re-takes the snapshot from the record as it stands now, and
/// [cancel] withdraws it. Both are ordinary queued writes on the request row, and
/// both read the target back through the owning feature's repository, so the
/// screen never has to know how a case or a note is loaded.
///
/// The Phase 4 screens read from **two** local streams, split on the one thing
/// that decides what a person may see. The **reviewer's** queue and the review
/// screen need the whole firm's requests, so they come off
/// [deleteRequestsStreamProvider] (`watchAll`). The **requester's** own list and
/// their badge are their own rows and nothing else, so they come off
/// [myDeleteRequestsStreamProvider] (`watchMine`) — the scoped query rather than
/// a client-side filter of the firm-wide stream, which is both cheaper and the
/// same scope the server grants that account. The badge for a requester is the
/// one piece of state that is not a row — *which decisions have I already seen* —
/// and that is a per-user preference, so it lives in `SharedPreferences` under
/// the account's own id.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/presentation/base_list_viewmodel.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../database/app_database.dart';
import '../../../shared/providers/database_provider.dart';
import '../../../shared/providers/shared_preferences_provider.dart';
import '../../accounts_and_profile/data/account_mode.dart';
import '../../accounts_and_profile/data/local/profiles_dao.dart';
import '../data/delete_requests_repository.dart';
import 'delete_request_flow.dart';

/// AsyncNotifier for the delete requests feature.
class DeleteRequestsViewModel
    extends BaseListViewModel<DeleteRequest, DeleteRequestsRepository> {
  /// Riverpod provider for [DeleteRequestsViewModel].
  static final provider =
      AsyncNotifierProvider<DeleteRequestsViewModel, ListState<DeleteRequest>>(
    () => DeleteRequestsViewModel(),
  );

  @override
  FutureProvider<DeleteRequestsRepository> get repositoryProvider =>
      deleteRequestsRepositoryProvider;

  @override
  Future<List<DeleteRequest>> loadItems(DeleteRequestsRepository repo) =>
      repo.listAll();

  @override
  Stream<List<DeleteRequest>> watchItems(DeleteRequestsRepository repo) =>
      repo.watchAll();

  /// Creates a delete request for the given entity and refreshes the list.
  ///
  /// [firmId] is the account's own firm and is required rather than inferred:
  /// the request is firm-scoped and the server refuses one without it. The UI
  /// path passes it — `deleteThroughFirmRules` reads it from the cached profile —
  /// so this stays a plain passthrough.
  Future<void> createRequest({
    required String entityType,
    required String entityId,
    required Map<String, dynamic> entitySnapshot,
    required int targetBaseVersion,
    required String firmId,
  }) async {
    await withRepo(
      (repo) async => await repo.createRequest(
        entityType: entityType,
        entityId: entityId,
        entitySnapshot: entitySnapshot,
        targetBaseVersion: targetBaseVersion,
        firmId: firmId,
      ),
    );
  }

  /// Re-takes the snapshot and the observed version of one of this account's
  /// own pending requests.
  ///
  /// The requester's own edit: the record moved on after the request was raised,
  /// so the request is refreshed to the version that exists now — the one a
  /// reviewer would otherwise see as stale. Returns false when nothing was
  /// refreshed, which happens when the request is no longer pending (a reviewer
  /// decided it elsewhere) or the record is not on this device; the screen says
  /// so rather than claiming an update that never happened.
  Future<bool> refreshSnapshot(String id) async {
    var refreshed = false;
    await withRepo((repo) async {
      final request = await repo.getById(id);
      if (request == null || request.status != 'pending') return;
      final json = await _targetJson(request);
      if (json == null) return;
      final version = json['version'];
      await repo.refreshSnapshot(
        id: id,
        entitySnapshot: deleteRequestSnapshot(json),
        targetBaseVersion: deletionBaseVersion(version is int ? version : null),
      );
      refreshed = true;
    });
    return refreshed;
  }

  /// Withdraws one of this account's own pending requests.
  ///
  /// Returns false when there is nothing to withdraw — the request is already
  /// decided (audit history is never rewritten) or gone — so the screen can say
  /// that nothing changed rather than that something failed.
  Future<bool> cancel(String id) async {
    var withdrawn = false;
    await withRepo((repo) async {
      final request = await repo.getById(id);
      if (request == null || request.status != 'pending') return;
      await repo.cancel(id);
      withdrawn = true;
    });
    return withdrawn;
  }

  /// Approves a request, or reconfirms one the server parked as stale.
  Future<void> approve(String id, {String? reviewNote}) async {
    await withRepo((repo) async => repo.approve(id, reviewNote: reviewNote));
  }

  /// Rejects a request, keeping the record it names.
  Future<void> reject(String id, {String? reviewNote}) async {
    await withRepo((repo) async => repo.reject(id, reviewNote: reviewNote));
  }

  /// The record a request names, as it stands on this device right now.
  ///
  /// Read through the owning feature's own repository — the same row the
  /// original snapshot was taken from — rather than off whichever screen the
  /// requester last had open, which may hold stale state. Null when this device
  /// does not hold the record: already deleted, authored elsewhere and never
  /// pulled here, or a kind a request cannot name. That is an answer the caller
  /// has to handle, not a silent no-op.
  Future<Map<String, dynamic>?> _targetJson(DeleteRequest request) async {
    switch (request.entityType) {
      case 'case':
        final row = await (await ref.read(
          caseRepositoryProvider.future,
        )).getById(request.entityId);
        return row?.toJson();
      case 'case_history':
        final row = await (await ref.read(
          caseHistoryRepositoryProvider.future,
        )).getById(request.entityId);
        return row?.toJson();
      case 'note':
        final row = await (await ref.read(
          notesRepositoryProvider.future,
        )).getById(request.entityId);
        return row?.toJson();
      case 'reference':
        final row = await (await ref.read(
          referenceRepositoryProvider.future,
        )).getById(request.entityId);
        return row?.toJson();
    }
    return null;
  }
}

/// Global provider alias for the delete requests ViewModel.
final deleteRequestsViewModelProvider = DeleteRequestsViewModel.provider;

/// Every delete request this device holds, live.
///
/// The one stream the Phase 4 screens and the Settings badge are all cut from.
final deleteRequestsStreamProvider =
    StreamProvider<List<DeleteRequest>>((ref) async* {
      final repo = await ref.watch(deleteRequestsRepositoryProvider.future);
      yield* repo.watchAll();
    });

/// This account's own delete requests, live, straight from the scoped query.
///
/// `watchMine(requested_by)` is the requester's own view and the exact scope RLS
/// grants them (their own rows, while non-deleted), so the list the requester
/// reads and the badge that counts their unread decisions are the same rows the
/// server would let them act on — read from the query rather than sliced out of
/// the firm-wide stream, which every reviewer in the firm shares.
final myDeleteRequestsStreamProvider =
    StreamProvider<List<DeleteRequest>>((ref) async* {
      final userId = ref.watch(accountCacheUserIdProvider);
      final repo = await ref.watch(deleteRequestsRepositoryProvider.future);
      yield* repo.watchMine(userId);
    });

/// Whether [request] is one a reviewer still has something to do about.
///
/// `stale_review_required` counts: the server parked it precisely because the
/// record moved under the request, so it is waiting for a reconfirm.
bool deleteRequestNeedsReview(DeleteRequest request) =>
    request.status == 'pending' ||
    request.status == 'stale_review_required';

/// The reviewer's queue: every request in the firm still awaiting a decision.
final deleteReviewQueueProvider = Provider<List<DeleteRequest>>((ref) {
  final all = ref.watch(deleteRequestsStreamProvider).value;
  if (all == null) return const <DeleteRequest>[];
  return all.where(deleteRequestNeedsReview).toList(growable: false);
});

/// This account's own requests, newest first (the current value of the stream).
///
/// A plain value alias over [myDeleteRequestsStreamProvider] so a screen or a
/// badge can read it synchronously; `watchMine` already scopes it to this
/// account, so no further filtering happens here.
final myDeleteRequestsProvider = Provider<List<DeleteRequest>>(
  (ref) =>
      ref.watch(myDeleteRequestsStreamProvider).value ??
      const <DeleteRequest>[],
);

/// Preference key holding when this account last looked at its own requests.
///
/// Per-user, like every other preference: it is stored under the account's own
/// id so one holder's "seen" moment can never silence another's badge.
String deleteRequestsSeenKey(String userId) => 'delete_requests_seen_$userId';

/// The moment this account last opened the Delete Requests screen.
///
/// Defaults to 0, so a fresh install counts every decision as unseen rather than
/// silently swallowing the first one.
class DeleteRequestsSeenNotifier extends Notifier<int> {
  late final SharedPreferences _prefs;

  @override
  int build() {
    _prefs = ref.watch(sharedPreferencesProvider);
    final userId = ref.watch(accountCacheUserIdProvider);
    return _prefs.getInt(deleteRequestsSeenKey(userId)) ?? 0;
  }

  /// Records that everything decided up to [at] has been seen.
  Future<void> markSeen(int at) async {
    if (at <= state) return;
    await _prefs.setInt(deleteRequestsSeenKey(ref.read(accountCacheUserIdProvider)), at);
    state = at;
  }
}

/// State for [DeleteRequestsSeenNotifier].
final deleteRequestsSeenProvider =
    NotifierProvider<DeleteRequestsSeenNotifier, int>(
      DeleteRequestsSeenNotifier.new,
    );

/// Decisions on this account's own requests it has not looked at yet.
///
/// This is the requester's half of the review notification (Phase 4 item 4):
/// the server's decision reaches the device through the ordinary pull, and this
/// is what tells the requester there is something new to read — a pending
/// request of their own is not news, so it is not counted.
final deleteRequestsUnseenProvider = Provider<List<DeleteRequest>>((ref) {
  final seen = ref.watch(deleteRequestsSeenProvider);
  // Scoped to this account already by `watchMine`, so only the *decision* and
  // the *unread* half need filtering here.
  return ref
      .watch(myDeleteRequestsProvider)
      .where(
        (request) => request.status != 'pending' && request.updatedAt > seen,
      )
      .toList(growable: false);
});

/// The requester's display name, as far as this device already knows it.
///
/// A reviewer reads the requester's name off the locally cached profile when the
/// pull happens to hold one and falls back to a neutral label when it does not —
/// deliberately, because the alternative is an online roster fetch, and a review
/// has to be stageable offline. The request still names the requester by id in
/// every case; only the display is best-effort.
final deleteRequestRequesterNameProvider =
    FutureProvider.family<String?, String>((ref, userId) async {
      final db = await ref.watch(databaseProvider.future);
      final profile = await ProfilesDao(db).getById(userId);
      final name = profile?.fullName.trim() ?? '';
      return name.isEmpty ? null : name;
    });

/// What the Settings entry's badge counts for this account.
///
/// A reviewer counts the queue in front of them; a requester counts decisions
/// they have not read. An individual never sees the entry at all, so this
/// answers 0 for them rather than inventing a number.
final deleteRequestsBadgeCountProvider = Provider<int>((ref) {
  if (!ref.watch(firmModeProvider)) return 0;
  if (ref.watch(canDeleteDirectlyProvider)) {
    return ref.watch(deleteReviewQueueProvider).length;
  }
  return ref.watch(deleteRequestsUnseenProvider).length;
});
