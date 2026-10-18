/// Who a backup file's rows belong to, and whether this device may restore it.
///
/// User-requested follow-up to Task 15 Phase 3. A backup's envelope says nothing
/// about its owner — only the schema version, the app version and the export
/// time — so ownership is read from the **rows themselves**: every table that
/// holds a person's data carries `user_id` (or `requested_by`, the one column the
/// schema names differently) and, where it applies, `firm_id`.
///
/// The rules the user approved, and why each one is here:
///
/// * A **UUID** owner that is neither this device's identity nor a firm this
///   device belongs to is **another account's file** — it is refused outright,
///   because importing it would put rows on the device that the server will
///   never accept from the restoring account (the reported failure: a restore
///   that "worked" and then refused to sync).
/// * **Blank or typed placeholder text** — an empty cell, `user_id`, `example-…`,
///   or anything a person typed into the sample workbook — names **no owner**,
///   so the file restores and [stampRowOwnership] writes this device's identity
///   onto it. That is the relaxation the user asked for, and it is deliberately
///   narrow: it applies to text that cannot be an id, never to an id.
/// * A row in **this device's own firm** counts as mine. Without that rule an
///   associate's *own* backup would be refused, because a firm's rows are shared
///   and legitimately carry the owner's or a colleague's `user_id`.
/// * A row naming a firm this device is **not** in is refused, whatever its owner
///   column says ([BackupOwnership.anotherFirm]). Such a row can neither be
///   pushed — `sync_can_write` refuses a firm that is not the caller's — nor read
///   back from the server, so accepting the file would leave permanent
///   local-only rows behind, which is the one thing a chamber's ledger may not
///   have (firm-mode §6). An owner column that matches makes no difference: the
///   scope is settled on restore, never inherited from the file.
/// * The device always has an identity to compare with — the bound account after
///   sign-in, or the pre-account placeholder before it — so a file that names an
///   id is refused on a signed-out device too, never accepted blindly. A
///   different device's pre-account backup therefore does not restore into this
///   one, while this device's own does.
///
/// Nothing here touches Flutter, Drift or the file system: the caller supplies
/// the payload and the schema's owner columns, so the whole decision is unit
/// testable and identical for the JSON and Excel paths.
library;

/// The ownership columns of one table, read from the live schema by the caller.
class BackupOwnerColumns {
  /// Creates the column set for one table.
  const BackupOwnerColumns({
    required this.owner,
    this.firm,
    this.audit = const <String>[],
  });

  /// The column that names the row's owner: `user_id`, or `requested_by`.
  final String owner;

  /// The firm scope column (`firm_id`), when the table has one.
  final String? firm;

  /// Attribution columns a fresh row carries beside its owner
  /// (`last_modified_by`, `created_by`, `reviewed_by`).
  final List<String> audit;
}

/// What a file's ownership says about restoring it here.
enum BackupOwnership {
  /// Every row that names an owner names this device's identity or its firm.
  mine,

  /// No row names an id at all: a hand-filled sample workbook, or a file whose
  /// owner cells still hold placeholder text.
  ownerless,

  /// At least one row names an id that is neither this device's identity nor its
  /// firm. The file belongs to somebody else.
  anotherAccount,

  /// At least one row names a **firm** this device is not in. Refused for the
  /// same reason as [anotherAccount], and kept apart from it only so the user is
  /// told the real one: the file was written inside another chamber.
  anotherFirm,
}

/// Whether [value] is a UUID-shaped id.
///
/// Every identity the app can meet is one of these — an account's `auth.uid()`,
/// this device's pre-account placeholder, the server's own rows — so anything
/// else in an owner column is text somebody typed, which is what makes the
/// "fresh template" relaxation safe rather than a hole.
bool isOwnerIdValue(Object? value) {
  if (value is! String) return false;
  return _uuidPattern.hasMatch(value.trim());
}

final RegExp _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
  r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

/// Classifies the rows in [tables] against the identity restoring them.
///
/// [tables] is the payload's table section (`table name -> rows`) and [columns]
/// the schema's ownership columns; a table absent from [columns] is not
/// consulted, which is how the pull-only caches (whose account columns are not
/// authored data) stay out of the decision.
///
/// [ownerId] is this device's identity — never empty — and [firmId] its firm,
/// when it has one. A row counts as mine when its owner is [ownerId], or its
/// firm is [firmId]; anything else that names an id makes the whole file
/// [BackupOwnership.anotherAccount], because one foreign row is enough to put
/// unpushable data on the device. A row that names a firm at all, when that firm
/// is not [firmId] — including when this device has no firm — is
/// [BackupOwnership.anotherFirm], which is the same refusal with its own reason.
BackupOwnership classifyBackupOwnership({
  required Map<String, dynamic> tables,
  required Map<String, BackupOwnerColumns> columns,
  required String ownerId,
  String? firmId,
}) {
  var sawMine = false;
  for (final entry in tables.entries) {
    final tableColumns = columns[entry.key];
    if (tableColumns == null) continue;
    final rows = entry.value;
    if (rows is! List) continue;
    for (final raw in rows) {
      if (raw is! Map) continue;
      final owner = _uuidOrNull(raw[tableColumns.owner]);
      final firmColumn = tableColumns.firm;
      final firm = firmColumn == null ? null : _uuidOrNull(raw[firmColumn]);
      // Nothing id-shaped in this row: either no owner column value at all, or
      // placeholder text. Neither names anybody.
      if (owner == null && firm == null) continue;
      // A row that names a firm is mine only when that firm is this device's,
      // whatever its owner column says: the chamber's scope is settled on
      // restore rather than inherited, and a foreign one could never be pushed.
      final mineFirm = firm != null && firmId != null && firm == firmId;
      if (firm != null && !mineFirm) return BackupOwnership.anotherFirm;
      final mine = (owner != null && owner == ownerId) || mineFirm;
      if (!mine) return BackupOwnership.anotherAccount;
      sawMine = true;
    }
  }
  return sawMine ? BackupOwnership.mine : BackupOwnership.ownerless;
}

/// Writes this device's identity into one row that names **no** owner.
///
/// Called only for a file that passed the gate, and it touches only a row whose
/// owner cell is not id-shaped — a hand-filled template row, or one whose cell
/// still holds placeholder text. A row that already names an id keeps it: this
/// device's own rows keep their owner, and a firm colleague's row keeps its
/// author and its attribution, because none of that is this device's to rewrite
/// (adoption exists for the pre-account case, and it runs at sign-in rather than
/// here).
///
/// Returns true when the row was stamped, so the caller can count them.
///
/// The audit columns follow the owner only where they too name nothing. The
/// **scope** is [settleRestoredScope]'s, not this function's: one column, one
/// writer, so a row naming a colleague cannot end up half-stamped.
bool stampRowOwnership(
  Map<String, dynamic> row,
  BackupOwnerColumns columns, {
  required String ownerId,
}) {
  if (isOwnerIdValue(row[columns.owner])) return false;

  row[columns.owner] = ownerId;
  for (final column in columns.audit) {
    if (!isOwnerIdValue(row[column])) row[column] = ownerId;
  }
  return true;
}

/// Settles one restored row's **scope**: the chamber it belongs to.
///
/// Called for **every** restored row, not only the ownerless ones. A restore
/// settles the scope rather than inheriting it from the file (firm-mode §6): a
/// row written before this account joined a chamber names no firm, and a row
/// written inside one names the chamber it was written in — which the gate has
/// already proved is this one. Writing this device's firm onto both makes the
/// restored ledger one chamber's, rather than the mixed ledger §1 forbids.
///
/// Nothing here rewrites a colleague's work. The owner and audit columns are not
/// touched — that is [stampRowOwnership]'s narrower job — so a colleague's row
/// keeps its author and attribution and only gains a scope it already had.
///
/// `scope_owner_id` needs no code: it is a **server** column, present on the
/// ledger tables there and absent from this device's schema, and the push strips
/// it from every payload (`20261015110000`), so a restored row reaches the server
/// with no scope owner by construction. A local schema that ever grows the column
/// must clear it here.
void settleRestoredScope(
  Map<String, dynamic> row,
  BackupOwnerColumns columns, {
  String? firmId,
}) {
  final firmColumn = columns.firm;
  if (firmColumn == null || firmId == null) return;
  row[firmColumn] = firmId;
}

/// The row's value when it is an id, trimmed; null for anything else.
String? _uuidOrNull(Object? value) {
  if (!isOwnerIdValue(value)) return null;
  return (value! as String).trim();
}
