/// Profiles table: local cache of the authenticated user's Supabase profile.
/// Pull-only cache — populated in Task 17 (Part B), no sync columns needed.
/// Implemented in Task 03 Phase 3.
library;

import 'package:drift/drift.dart';

/// A cached Supabase user profile.
@DataClassName('Profile')
class Profiles extends Table {
  /// UUID primary key (mirrors auth.users / profiles.id).
  TextColumn get id => text()();

  /// Display name.
  TextColumn get fullName => text()();

  /// Firm membership; null for individual lawyers.
  TextColumn get firmId => text().nullable()();

  /// Role: `owner`, `associate`, `viewer`, or `individual`.
  TextColumn get role => text()();

  /// Subscription status (`free`/`premium`) — display/analytics only.
  TextColumn get subscriptionStatus => text()();

  /// Premium subscription expiry converted from TIMESTAMPTZ to epoch ms.
  IntColumn get subscriptionExpiry => integer().nullable()();

  /// Profile creation timestamp (epoch ms, converted from TIMESTAMPTZ).
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
