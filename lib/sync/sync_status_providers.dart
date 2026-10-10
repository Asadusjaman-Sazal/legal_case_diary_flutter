/// Sync Status providers and the actions the screen performs on a queue entry
/// (Task 19 Phase 4).
///
/// The screen itself is presentational: it reads one stream of every unfinished
/// queue entry here and derives its filter chips and counts from it, so there is
/// exactly one query behind the whole screen and no filter can disagree with the
/// badge that opened it. Retry and Discard live here too, because both are
/// queue operations rather than widget behaviour.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/repository_providers.dart';
import '../database/app_database.dart';
import '../shared/providers/database_provider.dart';
import 'entity_tables.dart';
import 'push_worker.dart';
import 'sync_metadata_dao.dart';
import 'sync_queue_dao.dart';
import 'sync_table_bindings.dart';
import 'sync_transport.dart';

/// The four filter chips the screen offers.
enum SyncStatusFilter {
  /// Every unfinished entry — the safety net, never empty while work is held.
  all,

  /// Work the worker still intends to send (`pending`, `pushing`).
  pending,

  /// Entries frozen because a person must answer a conflict.
  conflicted,

  /// Entries the server refused permanently until the user acts.
  blocked,
}

/// Whether [row] belongs under [filter].
bool syncStatusMatches(SyncQueueRow row, SyncStatusFilter filter) =>
    switch (filter) {
      SyncStatusFilter.all => true,
      SyncStatusFilter.pending =>
        row.state == 'pending' || row.state == 'pushing',
      SyncStatusFilter.conflicted => row.state == 'conflict_pending',
      SyncStatusFilter.blocked => row.state == 'blocked',
    };

/// How many entries each filter would show, for the chip labels.
Map<SyncStatusFilter, int> syncStatusCounts(List<SyncQueueRow> rows) {
  final counts = <SyncStatusFilter, int>{
    for (final filter in SyncStatusFilter.values) filter: 0,
  };
  for (final row in rows) {
    for (final filter in SyncStatusFilter.values) {
      if (syncStatusMatches(row, filter)) counts[filter] = counts[filter]! + 1;
    }
  }
  return counts;
}

/// How many entries are held for a person: everything not merely waiting.
///
/// This is what the header badge counts. `pending` work is normal and needs no
/// badge; a `blocked` or `conflict_pending` entry is the state the user must be
/// told about, because nothing will move it without them.
int syncStatusAttentionCount(List<SyncQueueRow> rows) => rows
    .where((row) => row.state == 'blocked' || row.state == 'conflict_pending')
    .length;

/// Why a blocked entry stopped.
///
/// The queue stores no failure *kind* — only the state, the attempt count and
/// the server's own message — so the reason a card can name is the one the
/// worker's blocking rule leaves behind.
enum SyncBlockCause {
  /// The server refused the mutation outright. A permanent rejection, so
  /// retrying repeats the same answer until something about the record does.
  serverRefused,

  /// A retryable failure (the network, a 5xx) that never went through, so the
  /// worker gave up at its attempt limit.
  gaveUp,
}

/// Why [row] is blocked, read from the row's own facts.
///
/// [SyncBlockCause.gaveUp] is the one distinguishable case, and it is exact: the
/// worker blocks a *retryable* failure only once the attempt count reaches
/// [syncBlockRetryLimit], and blocks anything else — a refusal, or a result it
/// could not read — with the count left as it was. Nothing here is guessed from
/// the message text.
SyncBlockCause syncBlockCause(SyncQueueRow row) =>
    row.retryCount >= syncBlockRetryLimit
    ? SyncBlockCause.gaveUp
    : SyncBlockCause.serverRefused;

/// Every unfinished queue entry, oldest first.
final syncQueueEntriesProvider = StreamProvider<List<SyncQueueRow>>((
  ref,
) async* {
  final db = await ref.watch(databaseProvider.future);
  yield* SyncQueueDao(db).watchOpen();
});

/// The key an entry's subject is stored under: its entity type and its id.
String syncSubjectKey(String entityType, String entityId) =>
    '$entityType\u0000$entityId';

/// The court a subject case sits in.
///
/// The id travels with the name so the widget can resolve a pre-seeded court
/// the way every case screen does (`seedLabel`), while the stored name keeps a
/// court the user added readable.
class SyncSubjectCourt {
  /// Creates the court facts for one subject.
  const SyncSubjectCourt({
    required this.id,
    required this.name,
    required this.courtCategoryId,
  });

  /// Court id, for the localized seed label.
  final String id;

  /// Court name as stored, the fallback for a court with no seed label.
  final String name;

  /// Court category, which picks the right case-type label for the case.
  final String courtCategoryId;
}

/// What one queue entry is about, read from the local rows.
///
/// The queue itself carries only an entity type and an id, so a card built from
/// it alone names nothing the user can recognise. This is that identity, and it
/// stays unlocalized on purpose: the widget resolves [caseType] through
/// `caseTypeLabel`, [court] through `seedLabel` and a court category's `nameKey`
/// through `courtCategoryName`, exactly as the screens that already show these
/// names do.
class SyncEntrySubject {
  /// Creates a subject.
  const SyncEntrySubject({
    this.caseType,
    this.caseNumber,
    this.court,
    this.entityName,
  });

  /// The case's stored type name (`cases.case_type`).
  final String? caseType;

  /// The case's own number, e.g. `110/2021`.
  final String? caseNumber;

  /// The case's court, when the entry names a case whose court is known.
  final SyncSubjectCourt? court;

  /// The local row's own display name, for an entry that is not a case.
  final String? entityName;

  /// Whether this entry is about a case, directly or through a history row.
  bool get isCase => caseNumber != null;

  /// Whether there is anything here to show at all.
  bool get isEmpty => caseNumber == null && entityName == null;
}

/// Resolves what every open entry is about, from the local rows.
///
/// One query per table rather than one per row: the queue is short but its rows
/// are not cheap to ask about, and the whole map is rebuilt when the queue
/// changes — which is also the only way the rows behind it can change.
///
/// A row whose local record is **gone** (a discarded insert, a record another
/// account owns) resolves to nothing rather than to a guessed identity, so its
/// card simply carries no identity line.
Future<Map<String, SyncEntrySubject>> resolveSyncEntrySubjects(
  AppDatabase db,
  List<SyncQueueRow> entries,
) async {
  if (entries.isEmpty) return const <String, SyncEntrySubject>{};
  final subjects = <String, SyncEntrySubject>{};
  await _addCaseSubjects(db, entries, subjects);
  await _addNamedSubjects(db, entries, subjects);
  return subjects;
}

/// Case entries, and case-history entries through the case they belong to.
Future<void> _addCaseSubjects(
  AppDatabase db,
  List<SyncQueueRow> entries,
  Map<String, SyncEntrySubject> subjects,
) async {
  final caseIds = <String>{};
  final historyIds = <String>{};
  for (final entry in entries) {
    if (entry.entityType == 'case') caseIds.add(entry.entityId);
    if (entry.entityType == 'case_history') historyIds.add(entry.entityId);
  }

  // A history row names its case; the case is what the card must identify.
  final caseIdByHistoryId = <String, String>{};
  if (historyIds.isNotEmpty) {
    final history = await (db.select(db.caseHistory)
      ..where((row) => row.id.isIn(historyIds))).get();
    for (final item in history) {
      caseIdByHistoryId[item.id] = item.caseId;
      caseIds.add(item.caseId);
    }
  }
  if (caseIds.isEmpty) return;

  final casesById = <String, Case>{};
  for (final item in await (db.select(
    db.cases,
  )..where((row) => row.id.isIn(caseIds))).get()) {
    casesById[item.id] = item;
  }

  final courtIds = {for (final item in casesById.values) item.courtId};
  final courtsById = <String, Court>{};
  if (courtIds.isNotEmpty) {
    for (final court in await (db.select(
      db.courts,
    )..where((row) => row.id.isIn(courtIds))).get()) {
      courtsById[court.id] = court;
    }
  }

  SyncEntrySubject? subjectFor(String? caseId) {
    final item = caseId == null ? null : casesById[caseId];
    if (item == null) return null;
    final court = courtsById[item.courtId];
    return SyncEntrySubject(
      caseType: item.caseType,
      caseNumber: item.caseNumber,
      court: court == null
          ? null
          : SyncSubjectCourt(
              id: court.id,
              name: court.courtName,
              courtCategoryId: court.courtCategoryId,
            ),
    );
  }

  for (final entry in entries) {
    final subject = switch (entry.entityType) {
      'case' => subjectFor(entry.entityId),
      'case_history' => subjectFor(caseIdByHistoryId[entry.entityId]),
      _ => null,
    };
    if (subject != null) {
      subjects[syncSubjectKey(entry.entityType, entry.entityId)] = subject;
    }
  }
}

/// Every other entry: the local row's own name, where the row has one.
///
/// A delete request and a conflict log have no name of their own — naming them
/// means following the record they point at, which this screen does not do — so
/// they resolve to nothing and keep the plain card rather than a guessed label.
Future<void> _addNamedSubjects(
  AppDatabase db,
  List<SyncQueueRow> entries,
  Map<String, SyncEntrySubject> subjects,
) async {
  final names = <String, String>{};

  /// Loads one entity type's ids, keeping only the names that say something.
  Future<void> collect(
    String entityType,
    Future<Map<String, String>> Function(Set<String> ids) load,
  ) async {
    final ids = <String>{
      for (final entry in entries)
        if (entry.entityType == entityType) entry.entityId,
    };
    if (ids.isEmpty) return;
    for (final item in (await load(ids)).entries) {
      final name = item.value.trim();
      if (name.isNotEmpty) {
        names[syncSubjectKey(entityType, item.key)] = name;
      }
    }
  }

  await collect('note', (ids) async => {
    for (final row in await (db.select(
      db.notes,
    )..where((r) => r.id.isIn(ids))).get())
      row.id: row.title,
  });
  await collect('reference', (ids) async => {
    for (final row in await (db.select(
      db.caseReferences,
    )..where((r) => r.id.isIn(ids))).get())
      row.id: row.referenceAndPageNo.isEmpty
          ? (row.titleAndDescription ?? '')
          : row.referenceAndPageNo,
  });
  await collect('court', (ids) async => {
    for (final row in await (db.select(
      db.courts,
    )..where((r) => r.id.isIn(ids))).get())
      row.id: row.courtName,
  });
  await collect('case_type', (ids) async => {
    for (final row in await (db.select(
      db.caseTypes,
    )..where((r) => r.id.isIn(ids))).get())
      row.id: row.name,
  });
  await collect('step', (ids) async => {
    for (final row in await (db.select(
      db.steps,
    )..where((r) => r.id.isIn(ids))).get())
      row.id: row.stepName,
  });
  await collect('on_behalf', (ids) async => {
    for (final row in await (db.select(
      db.onBehalfs,
    )..where((r) => r.id.isIn(ids))).get())
      row.id: row.name,
  });
  await collect('case_category', (ids) async => {
    for (final row in await (db.select(
      db.caseCategories,
    )..where((r) => r.id.isIn(ids))).get())
      row.id: row.name,
  });
  // A court category stores a localization key, not a name; it is resolved the
  // same way its own screen resolves it.
  await collect('court_category', (ids) async => {
    for (final row in await (db.select(
      db.courtCategories,
    )..where((r) => r.id.isIn(ids))).get())
      row.id: row.nameKey,
  });

  for (final item in names.entries) {
    if (subjects.containsKey(item.key)) continue;
    subjects[item.key] = SyncEntrySubject(entityName: item.value);
  }
}

/// The identity of every open entry, keyed by [syncSubjectKey].
///
/// Derived from [syncQueueEntriesProvider] so the screen still has one queue
/// query behind it: the subjects are re-resolved on every queue change, which is
/// also the only moment a row behind them can have changed.
final syncEntrySubjectsProvider =
    FutureProvider<Map<String, SyncEntrySubject>>((ref) async {
      final entries = await ref.watch(syncQueueEntriesProvider.future);
      final db = await ref.watch(databaseProvider.future);
      return resolveSyncEntrySubjects(db, entries);
    });

/// When this device last completed a successful sync, from the durable
/// `sync_metadata` value the pull records.
///
/// It is watched rather than read once so the line on the screen updates the
/// moment a sync lands, exactly like every other live fact here.
final syncLastSuccessProvider = StreamProvider<int?>((ref) async* {
  final db = await ref.watch(databaseProvider.future);
  await for (final raw in SyncMetadataDao(
    db,
  ).watchValue(lastSuccessfulSyncAtKey)) {
    yield raw == null ? null : int.tryParse(raw);
  }
});

/// The count the app-wide header badge shows.
final syncStatusAttentionProvider = StreamProvider<int>((ref) async* {
  final entries = ref.watch(syncQueueEntriesProvider);
  yield entries.value == null ? 0 : syncStatusAttentionCount(entries.value!);
});

/// How a Discard ended, so the screen can tell the user what it did.
enum SyncDiscardOutcome {
  /// The authoritative row was fetched and put back in the record's place.
  rolledBackFromServer,

  /// The server has no such record, so the provisional local row was removed.
  removed,

  /// Offline: the pre-mutation snapshot was restored instead.
  rolledBackLocally,

  /// Nothing was written locally; the queued mutation was simply dropped.
  dropped,
}

/// Retry and Discard for one queue entry.
///
/// Both are deliberately local-only operations. Retry returns an entry to
/// `pending` and lets the ordinary trigger send it; Discard drops the mutation
/// and restores the record from the authoritative row (or, offline, from the
/// pre-mutation snapshot a permission rejection would also use). Neither can
/// bypass the entitlement gate or the push pipeline.
class SyncStatusActions {
  /// Creates the actions over [db], its [queue] and an optional [transport].
  SyncStatusActions({required this.db, required this.queue, this.transport});

  /// The local database the record is rolled back in.
  final AppDatabase db;

  /// The outbound queue the entry is dropped from.
  final SyncQueueDao queue;

  /// The REST transport used to fetch the authoritative row; null offline or in
  /// a build with no backend, in which case Discard falls back to the snapshot.
  final SyncTransport? transport;

  /// Retry: make a `blocked` entry eligible again with a clean retry count.
  Future<void> retry(SyncQueueRow row) => queue.retry(row.id);

  /// Discard: stop retrying this mutation and put the record back to a state the
  /// server agrees with.
  ///
  /// Order matters. The entry is dropped first so nothing can retry it while the
  /// rollback runs; then the authoritative row is preferred, because it is the
  /// only source that is true for *every* operation — an update goes back to the
  /// server's version, and a provisional insert the server never received
  /// disappears, which is what discarding it means. Offline there is no such
  /// source, so the pre-mutation snapshot is restored; when even that is absent
  /// (an insert this device only ever knew about) nothing local is invented and
  /// the mutation is merely dropped.
  Future<SyncDiscardOutcome> discard(SyncQueueRow row) async {
    final binding = syncBindingFor(row.entityType);
    await queue.delete(row.id);
    if (binding == null) return SyncDiscardOutcome.dropped;

    final table = syncTableForEntity(row.entityType);
    final transport = this.transport;
    if (table != null && transport != null) {
      final probe = await _tryFetch(transport, table, row.entityId);
      if (probe != null) {
        final authoritative = probe.row;
        if (authoritative != null) {
          await binding.applyServerRow(db, authoritative);
          return SyncDiscardOutcome.rolledBackFromServer;
        }
        await binding.deleteLocal(db, row.entityId);
        return SyncDiscardOutcome.removed;
      }
    }

    final snapshot = decodeJsonObject(row.preMutationPayload);
    if (snapshot.isNotEmpty) {
      await binding.applyServerRow(db, snapshot);
      return SyncDiscardOutcome.rolledBackLocally;
    }
    return SyncDiscardOutcome.dropped;
  }

  /// Asks the server for the row, answering null when the question itself could
  /// not be asked (offline, or no client) rather than when the row is absent.
  Future<({Map<String, dynamic>? row})?> _tryFetch(
    SyncTransport transport,
    String table,
    String id,
  ) async {
    try {
      return (row: await transport.fetchRow(table, id));
    } on Exception {
      return null;
    }
  }
}

/// The actions provider, wired to the active backend when there is one.
final syncStatusActionsProvider = FutureProvider<SyncStatusActions>((
  ref,
) async {
  final db = await ref.watch(databaseProvider.future);
  final client = ref.watch(activeSupabaseClientProvider);
  return SyncStatusActions(
    db: db,
    queue: SyncQueueDao(db),
    transport: client == null ? null : SupabaseSyncTransport(client),
  );
});
