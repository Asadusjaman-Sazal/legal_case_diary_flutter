/// Phase 10's lapse allowance, resolved from the device's own ledger.
///
/// §5.2's rule: a lapsed paid account keeps **writing** up to the allowance of the
/// tier it last held — Starter 100, Pro 250, Firm 500, Firm Plus 1,000 and
/// Enterprise 2,000 cases, notes and case references — and everything beyond
/// that is read-only but still readable. A genuinely free account keeps its
/// 50-case add wall and no other ceiling.
///
/// A **premium** account is no longer unlimited: every paid tier sells a case
/// ceiling (Starter 500, Pro 1,000, Firm 2,500, Firm Plus 6,000, Enterprise
/// none), and the Add Case gate reads it from the tier. Notes and references
/// stay uncapped while premium; only the lapse allowance caps those.
///
/// The writable set is the **most recently updated** rows, `updated_at`
/// descending with `id` as the tie-break, so the work a lawyer is on stays
/// editable and the archive is what goes read-only. Nothing here is stored: the
/// set is derived on demand, so renewal lifts it at once and deleting a writable
/// row promotes the next one.
///
/// This is a **device-side UX rule**, not a security boundary: while lapsed the
/// engine cannot push anything, and `push_changes`' entitlement gate remains the
/// server's boundary (§5.2, Phase 10's `Server` field).
library;

import '../../../database/app_database.dart';
import '../../case_reference/data/local/case_references_dao.dart';
import '../../cases/data/local/cases_dao.dart';
import '../../notes/data/local/notes_dao.dart';
import '../../payments/data/payment_plans.dart';

/// What this account may still write, and what is read-only until renewal.
///
/// A **null** ceiling means "no ceiling of this kind"; a **null** writable set
/// means "every row of this kind is editable". Both together describe the three
/// states in one shape:
///
/// * premium — the tier's case ceiling (null only for Enterprise), no writable
///   set, and no note or reference ceiling;
/// * genuinely free — [caseAddCeiling] 50, notes and references uncapped, and
///   every case editable (the wall is on adding, not on editing);
/// * lapsed paid — each ceiling is the tier's [SubscriptionTier.lapseAllowance]
///   and each writable set holds that many most-recently-updated ids.
class WriteAllowance {
  const WriteAllowance._({
    this.caseAddCeiling,
    this.noteAddCeiling,
    this.referenceAddCeiling,
    this.writableCaseIds,
    this.writableNoteIds,
    this.writableReferenceIds,
    this.liveCases = 0,
    this.liveNotes = 0,
    this.liveReferences = 0,
    this.isLapsed = false,
  });

  /// A premium account: the tier's case ceiling, and nothing else capped.
  ///
  /// `caseAddCeiling` is null for Enterprise, whose card sells unlimited cases.
  const WriteAllowance.premium({
    required int liveCases,
    int? caseAddCeiling,
  }) : this._(liveCases: liveCases, caseAddCeiling: caseAddCeiling);

  /// No ceiling of any kind. Used by tests and by an entitlement whose tier
  /// cannot be resolved; a real premium tier uses [WriteAllowance.premium].
  const WriteAllowance.unlimited({required int liveCases})
    : this._(liveCases: liveCases);

  /// A free account that has never been premium: the 50-case add wall only.
  const WriteAllowance.free({
    required int liveCases,
    required int caseAddCeiling,
  }) : this._(liveCases: liveCases, caseAddCeiling: caseAddCeiling);

  /// A lapsed paid account, with its tier's allowance and writable sets.
  WriteAllowance.lapsed({
    required int ceiling,
    required List<String> writableCaseIds,
    required List<String> writableNoteIds,
    required List<String> writableReferenceIds,
    required this.liveCases,
    required this.liveNotes,
    required this.liveReferences,
  }) : caseAddCeiling = ceiling,
       noteAddCeiling = ceiling,
       referenceAddCeiling = ceiling,
       writableCaseIds = writableCaseIds.toSet(),
       writableNoteIds = writableNoteIds.toSet(),
       writableReferenceIds = writableReferenceIds.toSet(),
       isLapsed = true;

  /// Cases a new row may bring the account to, or null when uncapped.
  final int? caseAddCeiling;

  /// Notes a new row may bring the account to, or null when uncapped.
  final int? noteAddCeiling;

  /// References a new row may bring the account to, or null when uncapped.
  final int? referenceAddCeiling;

  /// Cases the allowance keeps editable, or null when every case is editable.
  final Set<String>? writableCaseIds;

  /// Notes the allowance keeps editable, or null when every note is editable.
  final Set<String>? writableNoteIds;

  /// References the allowance keeps editable, or null when every one is.
  final Set<String>? writableReferenceIds;

  /// Live (non-deleted) cases on the device.
  final int liveCases;

  /// Live notes on the device.
  final int liveNotes;

  /// Live references on the device.
  final int liveReferences;

  /// Whether the account is a lapsed paid account rather than free or premium.
  final bool isLapsed;

  /// Whether another case may be added.
  bool canAddCase() => caseAddCeiling == null || liveCases < caseAddCeiling!;

  /// Whether another note may be added.
  bool canAddNote() => noteAddCeiling == null || liveNotes < noteAddCeiling!;

  /// Whether another reference may be added.
  bool canAddReference() =>
      referenceAddCeiling == null || liveReferences < referenceAddCeiling!;

  /// Whether [caseId] may be edited.
  bool isCaseWritable(String caseId) =>
      writableCaseIds?.contains(caseId) ?? true;

  /// Whether [noteId] may be edited.
  bool isNoteWritable(String noteId) =>
      writableNoteIds?.contains(noteId) ?? true;

  /// Whether [referenceId] may be edited.
  bool isReferenceWritable(String referenceId) =>
      writableReferenceIds?.contains(referenceId) ?? true;

  /// Cases kept read-only by the allowance (0 when nothing is restricted).
  int get readOnlyCases =>
      writableCaseIds == null ? 0 : liveCases - writableCaseIds!.length;

  /// Notes kept read-only by the allowance.
  int get readOnlyNotes =>
      writableNoteIds == null ? 0 : liveNotes - writableNoteIds!.length;

  /// References kept read-only by the allowance.
  int get readOnlyReferences =>
      writableReferenceIds == null ? 0 : liveReferences - writableReferenceIds!.length;

  /// Whether any kind is over its allowance, which is when the banner shows.
  bool get hasReadOnlyRows =>
      readOnlyCases > 0 || readOnlyNotes > 0 || readOnlyReferences > 0;
}

/// Resolves what [tier] (the tier **in force**) and [premium] may still write.
///
/// Queries run only when the answer is restricted: a premium account costs one
/// count, a free account one count, and a lapsed account six small reads. The
/// caller passes the effective tier from `effectiveTier(...)`, so a started
/// downgrade is already honoured here.
Future<WriteAllowance> resolveWriteAllowance(
  AppDatabase db, {
  required SubscriptionTier tier,
  required bool premium,
}) async {
  final cases = CasesDao(db);
  final liveCases = await cases.getNonDeletedCaseCount();

  if (premium) {
    // A live entitlement whose stored tier is still `free` — a period granted
    // from the dashboard, or a row the ladder has not named — keeps no wall:
    // the paid ceilings belong to a tier, and inventing the free one for an
    // account that has paid would take away what it already had.
    return WriteAllowance.premium(
      liveCases: liveCases,
      caseAddCeiling: tier == SubscriptionTier.free ? null : tier.caseCeiling,
    );
  }
  if (tier == SubscriptionTier.free) {
    return WriteAllowance.free(
      liveCases: liveCases,
      caseAddCeiling: tier.caseCeiling!,
    );
  }

  final notes = NotesDao(db);
  final references = CaseReferencesDao(db);
  final allowance = tier.lapseAllowance;
  return WriteAllowance.lapsed(
    ceiling: allowance,
    writableCaseIds: await cases.getMostRecentlyUpdatedIds(allowance),
    writableNoteIds: await notes.getMostRecentlyUpdatedIds(allowance),
    writableReferenceIds: await references.getMostRecentlyUpdatedIds(allowance),
    liveCases: liveCases,
    liveNotes: await notes.getNonDeletedCount(),
    liveReferences: await references.getNonDeletedCount(),
  );
}
