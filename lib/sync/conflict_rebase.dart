/// The three-way comparison behind every conflict — pure, so the verdict is
/// testable without a database, a server or a widget.
///
/// A rejected mutation carries three payloads (Sync Plan §1, `conflict_log`
/// schema notes): the `base_payload` it was built on, the `submitted_payload` it
/// tried to write, and the authoritative `server_payload` that refused it. The
/// verdict has exactly three answers:
///
/// * **disjoint** — the local edit and the server's change touch different
///   fields, so the local values can be laid over the authoritative row and the
///   mutation retried against the server's version. No person is needed.
/// * **overlapping** — the same field was changed on both sides to different
///   values, or two fields that only mean something *together* were changed on
///   both sides (a quick update writes `next_date`, `last_step` and
///   `notes_results` as one logical step, so editing any one of them is editing
///   the step). A person decides.
/// * **tombstone** — the server row is deleted. The plan's zombie-data rule makes
///   this explicit: never resurrect it silently, never discard the queued work
///   silently. The two legal answers live in the Review screen (copy onto a new
///   record, or confirm the discard).
///
/// The comparison ignores the sync bookkeeping columns (`updated_at`,
/// `last_modified_by`, `synced_at`, `version`, `server_updated_at`): every write
/// touches them, and treating them as content would make every conflict
/// unmergeable.
library;

import 'package:flutter/foundation.dart';

/// What the comparison concluded.
enum ConflictVerdict {
  /// The changes are independent: rebase automatically.
  disjoint,

  /// The changes collide, or are coupled: a person decides.
  overlapping,

  /// The authoritative row is a tombstone: a person decides, explicitly.
  tombstone,
}

/// Fields that are one logical value, and therefore conflict together.
@immutable
class SyncFieldGroup {
  /// Creates a group with a human-readable [name].
  const SyncFieldGroup(this.name, this.fields);

  /// The name the Review screen shows, in Title Case.
  final String name;

  /// The field names, in snake_case, as the payloads and the server use them.
  final List<String> fields;
}

/// The coupled field groups this project actually has.
///
/// Kept deliberately short: a group is a claim that the fields are meaningless
/// apart, which is true of the three below and not of most columns.
const List<SyncFieldGroup> syncFieldGroups = <SyncFieldGroup>[
  SyncFieldGroup(
    'The Next Hearing Step',
    <String>['next_date', 'last_step', 'notes_results'],
  ),
  SyncFieldGroup(
    'The Case Identity',
    <String>['case_number', 'case_type', 'court_id', 'on_behalf_id'],
  ),
  SyncFieldGroup(
    'The Filing Details',
    <String>[
      'case_category_id',
      'honorable_judges',
      'tender_number',
      'previous_court_case',
      'district_of_origin',
      'result',
    ],
  ),
];

/// Columns every write touches, and which therefore carry no content.
///
/// `is_deleted` belongs here too: a live row differs from a tombstone by it, but
/// that case is answered by the tombstone verdict before any field comparison,
/// so counting it as content would only make ordinary conflicts unnmergeable.
const Set<String> syncBookkeepingFields = <String>{
  'id',
  'version',
  'updated_at',
  'synced_at',
  'server_updated_at',
  'last_modified_by',
  'created_at',
  'is_deleted',
};

/// The verdict plus, when the answer is to rebase, the payload to send.
@immutable
class ConflictRebase {
  /// Creates a plan.
  const ConflictRebase({
    required this.verdict,
    required this.mergeable,
    this.payload,
    this.mergedFields = const <String>[],
    this.overlappingFields = const <String>[],
    this.coupledGroup,
  });

  /// What the comparison concluded.
  final ConflictVerdict verdict;

  /// Whether the edits can be rebased without a person.
  final bool mergeable;

  /// The authoritative row with the local values laid over it, in snake_case.
  ///
  /// Null unless [mergeable]: a payload for an ambiguous conflict would be a
  /// guess, and guessing is what this whole file exists to avoid.
  final Map<String, dynamic>? payload;

  /// The local fields carried over — the merged subset of [payload].
  final List<String> mergedFields;

  /// Fields both sides changed to different values.
  final List<String> overlappingFields;

  /// The group that made the conflict ambiguous, when coupling is the reason.
  final String? coupledGroup;

  /// A short machine-readable reason, for the queue row's error copy.
  String get reason {
    if (verdict == ConflictVerdict.tombstone) {
      return 'The record was deleted on the server.';
    }
    if (coupledGroup != null) {
      return 'Both sides changed $coupledGroup.';
    }
    if (overlappingFields.isNotEmpty) {
      return 'Both sides changed ${overlappingFields.join(', ')}.';
    }
    return 'The server has a newer version of this record.';
  }
}

/// Compares a rejected mutation's three payloads.
///
/// [changedFields] is the mutation's own record of what it meant to change; when
/// it is empty (an older row, or a delete) every field that differs from the base
/// is treated as the change, so a legacy row still reaches an answer.
ConflictRebase planConflictRebase({
  required Map<String, dynamic> base,
  required Map<String, dynamic> server,
  required Map<String, dynamic> local,
  required List<String> changedFields,
}) {
  if (server['is_deleted'] == true) {
    return const ConflictRebase(
      verdict: ConflictVerdict.tombstone,
      mergeable: false,
    );
  }

  final localChanges = _changedBetween(base, local, named: changedFields);
  final serverChanges = _changedBetween(base, server, named: const <String>[]);

  final overlapping = <String>[
    for (final field in localChanges)
      if (serverChanges.contains(field) && _differs(server[field], local[field]))
        field,
  ];

  // Coupling: two different fields of one logical value, changed on both sides,
  // are as ambiguous as the same field changed twice.
  String? coupledGroup;
  for (final group in syncFieldGroups) {
    final mine = localChanges.any(group.fields.contains);
    final theirs = serverChanges.any(group.fields.contains);
    if (mine && theirs) {
      coupledGroup = group.name;
      break;
    }
  }

  if (overlapping.isNotEmpty || coupledGroup != null) {
    return ConflictRebase(
      verdict: ConflictVerdict.overlapping,
      mergeable: false,
      overlappingFields: overlapping,
      coupledGroup: coupledGroup,
      mergedFields: localChanges,
    );
  }

  final payload = <String, dynamic>{...server};
  for (final field in localChanges) {
    payload[field] = local[field];
  }
  return ConflictRebase(
    verdict: ConflictVerdict.disjoint,
    mergeable: true,
    payload: payload,
    mergedFields: localChanges,
  );
}

/// The fields that differ between [from] and [to], in a stable order.
///
/// [named] restricts the answer to fields the mutation claims to have changed;
/// when it is empty every differing field counts.
List<String> _changedBetween(
  Map<String, dynamic> from,
  Map<String, dynamic> to, {
  required List<String> named,
}) {
  final candidates = named.isEmpty
      ? <String>{...from.keys, ...to.keys}
      : named.toSet();
  final changed = <String>[
    for (final field in candidates)
      if (!syncBookkeepingFields.contains(field) &&
          _differs(from[field], to[field]))
        field,
  ]..sort();
  return changed;
}

/// Whether two JSON values differ, treating "absent" and `null` as one value.
bool _differs(Object? a, Object? b) {
  if (a == null && b == null) return false;
  if (a is num && b is num) return a != b;
  return a != b;
}
