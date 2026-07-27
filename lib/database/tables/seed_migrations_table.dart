/// Seed migrations ledger: records which versioned pre-seed migrations have
/// been applied locally. Used by Task 04 to apply seed data idempotently.
/// Local operational table — no sync columns needed.
/// Implemented in Task 03 Phase 3.
library;

import 'package:drift/drift.dart';

/// A record of a successfully applied seed migration.
@DataClassName('SeedMigration')
class SeedMigrations extends Table {
  /// Migration identifier (e.g. `seed_v1`).
  TextColumn get migrationId => text()();

  /// Checksum / hash used to detect tampered or changed migration payloads.
  TextColumn get checksum => text()();

  /// Timestamp when the migration was applied (epoch ms).
  IntColumn get appliedAt => integer()();

  @override
  Set<Column> get primaryKey => {migrationId};
}
