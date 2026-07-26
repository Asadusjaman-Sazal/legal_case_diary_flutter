/// Riverpod provider exposing the AppDatabase instance. Implemented in Task 03.
library;

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/database_factory.dart';

/// Riverpod provider for the async initialization of the encrypted database.
///
/// The factory opens (or creates) the encrypted database and can throw a
/// [DatabaseFactoryException] when the encryption key is missing. UI code
/// should watch this provider through [DatabaseGuard] so that key-loss
/// situations are surfaced as a recovery dialog instead of an unhandled error.
///
/// Note: this currently returns the underlying Drift [QueryExecutor]. In
/// Phase 4 it will return the generated [AppDatabase] class.
final databaseProvider = FutureProvider<QueryExecutor>((ref) async {
  final executor = await DatabaseFactory().createExecutor();
  return executor;
});
