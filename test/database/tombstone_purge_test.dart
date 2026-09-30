/// Tombstone purge guard — Task 19 Phase 3 item 6.
///
/// The 90-day purge is only ever allowed to remove a tombstone that has actually
/// been **acknowledged** by the server (`synced_at IS NOT NULL AND synced_at >=
/// updated_at`). A regression here would delete local work that never reached the
/// server, which is unrecoverable, so each arm of the guard gets its own test.
library;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legal_case_diary/database/app_database.dart';

void main() {
  late AppDatabase db;

  /// A day in milliseconds.
  const int day = 24 * 60 * 60 * 1000;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.customSelect('select 1').get();
  });

  tearDown(() => db.close());

  Future<void> note({
    required String id,
    required int updatedAt,
    required bool isDeleted,
    int? syncedAt,
  }) => db.into(db.notes).insert(
        NotesCompanion.insert(
          id: id,
          userId: 'user-1',
          title: id,
          body: 'Body',
          createdAt: 0,
          updatedAt: updatedAt,
          isDeleted: Value(isDeleted),
          syncedAt: Value(syncedAt),
        ),
      );

  Future<List<Note>> survivors() => db.select(db.notes).get();

  test('a synced tombstone older than 90 days is purged', () async {
    final old = DateTime.now().toUtc().millisecondsSinceEpoch - 100 * day;
    await note(id: 'synced', updatedAt: old, isDeleted: true, syncedAt: old);

    await db.purgeSoftDeletedRecords();

    expect(await survivors(), isEmpty);
  });

  test('an unsynced tombstone is never purged, however old', () async {
    final old = DateTime.now().toUtc().millisecondsSinceEpoch - 400 * day;
    await note(id: 'unsynced', updatedAt: old, isDeleted: true);

    await db.purgeSoftDeletedRecords();

    expect((await survivors()).single.id, 'unsynced');
  });

  test('a tombstone edited after its last sync is never purged', () async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final old = now - 100 * day;
    // The row was synced, then edited again: synced_at is behind updated_at, so
    // the newer local change has not reached the server.
    await note(
      id: 'stale',
      updatedAt: old,
      isDeleted: true,
      syncedAt: old - day,
    );

    await db.purgeSoftDeletedRecords();

    expect((await survivors()).single.id, 'stale');
  });

  test('a recent synced tombstone is kept until the retention window passes',
      () async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await note(id: 'fresh', updatedAt: now, isDeleted: true, syncedAt: now);

    await db.purgeSoftDeletedRecords();

    expect((await survivors()).single.id, 'fresh');
  });

  test('live rows are never touched, however old', () async {
    final old = DateTime.now().toUtc().millisecondsSinceEpoch - 400 * day;
    await note(id: 'live', updatedAt: old, isDeleted: false, syncedAt: old);

    await db.purgeSoftDeletedRecords();

    expect((await survivors()).single.id, 'live');
  });
}
