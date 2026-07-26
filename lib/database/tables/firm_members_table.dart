/// Firm members table: local cache of firm membership and permission flags.
/// Pull-only cache — populated in Task 17 (Part B), no sync columns needed.
/// Implemented in Task 03 Phase 2.
library;

import 'package:drift/drift.dart';

/// A user's membership in a law firm with role-based permissions.
@DataClassName('FirmMember')
class FirmMembers extends Table {
  /// UUID primary key (mirrors Supabase PK).
  TextColumn get id => text()();

  /// Parent firm.
  TextColumn get firmId => text()();

  /// Member user UUID.
  TextColumn get userId => text()();

  /// Role within the firm (e.g. `owner`, `admin`, `associate`).
  TextColumn get role => text()();

  /// Permission: can add cases/records.
  BoolColumn get canAdd => boolean().withDefault(const Constant(false))();

  /// Permission: can edit existing records.
  BoolColumn get canEdit => boolean().withDefault(const Constant(false))();

  /// Permission: can delete (subject to delete-request approval workflow).
  BoolColumn get canDelete => boolean().withDefault(const Constant(false))();

  /// Last time this member row was synced from Supabase (epoch ms).
  IntColumn get syncedAt => integer().nullable()();

  /// Last time permissions were re-fetched from Supabase (epoch ms).
  IntColumn get permissionsSyncedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
