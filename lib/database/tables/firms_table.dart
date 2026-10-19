/// Firms table: local cache of firm information pulled from Supabase.
/// Pull-only cache — populated in Task 17 (Part B), no sync columns needed.
/// Implemented in Task 03 Phase 2.
///
/// Table class: **pull-only cache**. The server decides every value here, so a
/// member's device cannot claim a chamber tier its owner does not hold. The
/// chamber's tier reaches this row only because the server mirrors the owner's
/// plan onto it (`mirror_owner_subscription_to_firm`).
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

  /// The chamber's subscription tier, mirrored from its owner's plan:
  /// `free`, `starter`, `pro`, `firm`, `firm_plus` or `enterprise`.
  ///
  /// This row is the chamber's **source of the seat cap** — Starter and Pro 0,
  /// Firm 5, Firm Plus 12, Enterprise unlimited — and the allowance a lapsed
  /// member falls back to, so it is read rather than re-derived from the owner's
  /// expiry. Defaults to `free`, the safe answer for a row cached before the
  /// column existed.
  TextColumn get tier => text().withDefault(const Constant('free'))();

  /// The tier a mid-term downgrade will fall to, or null when none is waiting.
  TextColumn get tierPending => text().nullable()();

  /// The expiry at which [tierPending] starts, epoch ms.
  IntColumn get tierPendingFrom => integer().nullable()();

  /// Creation timestamp (epoch ms, converted from TIMESTAMPTZ).
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
