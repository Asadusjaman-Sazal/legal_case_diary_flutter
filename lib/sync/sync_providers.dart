/// Sync-facing Riverpod providers.
///
/// The service itself lives in `sync_service.dart`; this file exposes the small
/// reactive facts the trigger scope needs without leaking Drift into widgets.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared/providers/database_provider.dart';

/// The number of queue entries still waiting to be pushed.
///
/// It counts only `pending`, so the worker's own `pending -> pushing ->
/// resolved` churn does not look like new work.
final syncQueuePendingCountProvider = StreamProvider<int>((ref) async* {
  final db = await ref.watch(databaseProvider.future);
  yield* (db.select(db.syncQueue)
        ..where((row) => row.state.equals('pending')))
      .watch()
      .map((rows) => rows.length);
});
