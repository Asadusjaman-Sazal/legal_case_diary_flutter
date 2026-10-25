/// Profiles table: local cache of the authenticated user's Supabase profile.
/// Pull-only cache — populated in Task 17 (Part B), no sync columns needed.
/// Implemented in Task 03 Phase 3.
///
/// Table class: **pull-only cache**. The server decides every value here;
/// the app never writes back, so the tier column below cannot be forged from
/// the device. Column names are `snake_case` in SQL and Drift maps this class's
/// `camelCase` getter onto them automatically.
library;

import 'package:drift/drift.dart';

/// A cached Supabase user profile.
@DataClassName('Profile')
class Profiles extends Table {
  /// UUID primary key (mirrors auth.users / profiles.id).
  TextColumn get id => text()();

  /// Display name.
  TextColumn get fullName => text()();

  /// Object name of the profile picture in the `individual-avatars` bucket,
  /// or null.
  ///
  /// Server-written by the storage trigger, never by a device. The local
  /// picture stays the offline truth; this is how another device learns that
  /// it exists and changed (0.0.630).
  TextColumn get avatarPath => text().nullable()();

  /// Bumped by the server on every profile-picture write or delete.
  IntColumn get avatarVersion => integer().withDefault(const Constant(0))();

  /// Firm membership; null for individual lawyers.
  TextColumn get firmId => text().nullable()();

  /// Role: `owner`, `associate`, `viewer`, or `individual`.
  TextColumn get role => text()();

  /// Subscription status (`free`/`premium`) — display/analytics only.
  TextColumn get subscriptionStatus => text()();

  /// Premium subscription expiry converted from TIMESTAMPTZ to epoch ms.
  IntColumn get subscriptionExpiry => integer().nullable()();

  /// The subscription tier this account holds: `free`, `pro`, `firm` or
  /// `firm_plus`, as the server stores it.
  ///
  /// The server writes it at approval and **never clears it on expiry**, so the
  /// column is the record of the last tier held — which is what the lapse
  /// allowance needs. Defaults to `free` so every row cached before this column
  /// existed reads as "no paid tier", the safe answer.
  TextColumn get tier => text().withDefault(const Constant('free'))();

  /// The tier a mid-term downgrade will fall to when the paid period ends, or
  /// null when no downgrade is waiting.
  TextColumn get tierPending => text().nullable()();

  /// The expiry at which [tierPending] starts, epoch ms. A downgrade waits for
  /// the period it was bought for, so the tier in force is never replaced early.
  IntColumn get tierPendingFrom => integer().nullable()();

  /// Profile creation timestamp (epoch ms, converted from TIMESTAMPTZ).
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
