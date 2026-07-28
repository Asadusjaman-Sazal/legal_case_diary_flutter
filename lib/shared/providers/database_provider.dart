/// Riverpod provider exposing the encrypted [AppDatabase] instance.
/// Implemented in Task 03 Phase 4.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/app_database.dart';
import '../../database/database_factory.dart';

/// Riverpod provider for the async initialization of the encrypted database.
///
/// The factory opens (or creates) the encrypted database and can throw a
/// [DatabaseFactoryException] when the encryption key is missing. UI code
/// should watch this provider through [DatabaseGuard] so that key-loss
/// situations are surfaced as a recovery dialog instead of an unhandled error.
final databaseProvider = FutureProvider<AppDatabase>((ref) async {
  final executor = await DatabaseFactory().createExecutor();
  return AppDatabase(executor);
});
