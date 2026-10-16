/// The in-use rule for reference rows, in one place.
///
/// A reference row a **live** dependent row still names cannot be deleted: the
/// server refuses that tombstone (`enforce_reference_not_in_use`, 0.0.530) and
/// the app must not offer it either, or an offline delete would be queued and
/// then rejected — the mismatch "the interface and the server agree" exists to
/// prevent. This file is the single home of that rule: the Manage Account tick
/// list and the Edit Court/Steps screens both read it, so they can never
/// disagree about what is still in use.
///
/// The dependency graph is the same foreign keys the server guard covers, minus
/// the pairs the app cannot act on:
///
///   * `courts`           <- `cases.court_id`
///   * `on_behalfs`       <- `cases.on_behalf_id`
///   * `court_categories` <- `courts`, `steps`, `case_types`, `on_behalfs` and
///     `case_categories`' `court_category_id`
///
/// `case_categories` has no id in the answer because no screen manages one;
/// `steps` and `case_types` reference nothing and nothing references them
/// (`cases.case_type` and `cases.last_step` are text), so neither can be held
/// back and neither needs a set.
///
/// Only a **live** dependent blocks — every branch reads its table with
/// `is_deleted = 0` — because a row that is itself a tombstone is on its way
/// out. Reordering is never governed by this rule, and neither is the built-in
/// baseline (`is_custom = 0`), which the repositories refuse to delete at all.
library;

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/app_database.dart';
import '../../../shared/providers/database_provider.dart';

/// The ids a live dependent row still names, one set per reference table the
/// screens can delete from.
class ReferenceInUse {
  /// Creates the three sets.
  const ReferenceInUse({
    required this.courtIds,
    required this.onBehalfIds,
    required this.courtCategoryIds,
  });

  /// Nothing is held back — the answer while the ledger has not been read, so a
  /// screen renders exactly as it did before this rule existed rather than
  /// hiding an action because of a load order.
  static const ReferenceInUse none = ReferenceInUse(
    courtIds: <String>{},
    onBehalfIds: <String>{},
    courtCategoryIds: <String>{},
  );

  /// Court ids a live case still names.
  final Set<String> courtIds;

  /// On-behalf ids a live case still names.
  final Set<String> onBehalfIds;

  /// Court category ids a live reference row still names.
  final Set<String> courtCategoryIds;
}

/// The rule, as one query: every id a live row still names, tagged by the set it
/// belongs to. Written once so the one-shot read and the reactive watch can never
/// drift apart.
const String _inUseSql = '''
  select 'court' as kind, court_id as id
    from cases where is_deleted = 0
  union
  select 'on_behalf', on_behalf_id
    from cases where is_deleted = 0
  union
  select 'court_category', court_category_id
    from courts where is_deleted = 0
  union
  select 'court_category', court_category_id
    from steps where is_deleted = 0
  union
  select 'court_category', court_category_id
    from case_types where is_deleted = 0
  union
  select 'court_category', court_category_id
    from on_behalfs where is_deleted = 0
  union
  select 'court_category', court_category_id
    from case_categories where is_deleted = 0
''';

/// Every table the rule reads, so Drift re-runs it when any of them changes.
Set<ResultSetImplementation<dynamic, dynamic>> _reads(AppDatabase db) =>
    <ResultSetImplementation<dynamic, dynamic>>{
      db.cases,
      db.courts,
      db.steps,
      db.caseTypes,
      db.onBehalfs,
      db.caseCategories,
    };

/// Reads the in-use sets once, from this device's ledger.
Future<ReferenceInUse> readReferenceInUse(AppDatabase db) async =>
    _collect(await db.customSelect(_inUseSql, readsFrom: _reads(db)).get());

/// Re-reads the in-use sets whenever a table they are derived from changes, so
/// a Delete offered for a row becomes unavailable the moment a case starts
/// naming it — and comes back when the last such case goes.
Stream<ReferenceInUse> watchReferenceInUse(AppDatabase db) =>
    db.customSelect(_inUseSql, readsFrom: _reads(db)).watch().map(_collect);

/// Groups the rule's rows into the three sets.
ReferenceInUse _collect(List<QueryRow> rows) {
  final courtIds = <String>{};
  final onBehalfIds = <String>{};
  final courtCategoryIds = <String>{};

  for (final row in rows) {
    final id = row.read<String>('id');
    switch (row.read<String>('kind')) {
      case 'court':
        courtIds.add(id);
      case 'on_behalf':
        onBehalfIds.add(id);
      case 'court_category':
        courtCategoryIds.add(id);
    }
  }

  return ReferenceInUse(
    courtIds: courtIds,
    onBehalfIds: onBehalfIds,
    courtCategoryIds: courtCategoryIds,
  );
}

/// The in-use sets for the screens, reactive to the ledger.
///
/// [ReferenceInUse.none] until the database is open: the derived-entitlement
/// rules elsewhere in the app treat "not yet known" as the permissive direction
/// for a local UX check, and the server's own guard is what makes the deletion
/// impossible either way.
final referenceInUseProvider = StreamProvider<ReferenceInUse>((ref) async* {
  final db = ref.watch(databaseProvider).value;
  if (db == null) {
    yield ReferenceInUse.none;
    return;
  }
  yield* watchReferenceInUse(db);
});
