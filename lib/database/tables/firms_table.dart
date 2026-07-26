/// Firms table: local cache of firm information pulled from Supabase.
/// Pull-only cache — populated in Task 17 (Part B), no sync columns needed.
/// Implemented in Task 03 Phase 2.
library;

import 'package:drift/drift.dart';

/// A law firm / chambers record.
@DataClassName('Firm')
class Firms extends Table {
  /// UUID primary key (mirrors Supabase PK).
  TextColumn get id => text()();

  /// Firm display name.
  TextColumn get name => text()();

  /// Firm owner UUID.
  TextColumn get ownerId => text()();

  /// Subscription status (e.g. `active`, `trial`, `expired`).
  TextColumn get subscriptionStatus => text()();

  /// Subscription expiry converted from Supabase TIMESTAMPTZ to epoch ms.
  IntColumn get subscriptionExpiry => integer().nullable()();

  /// Creation timestamp (epoch ms, converted from TIMESTAMPTZ).
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
