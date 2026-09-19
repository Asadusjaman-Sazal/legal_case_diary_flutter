/// The dataset predicate a case-list screen's search runs inside.
///
/// Plan §12.1 makes search scoped: the same query means different things on the
/// Active and the Overdue list, so each screen hands its own dataset predicate
/// to `CaseRepository.searchScoped` and the text query is applied by SQL
/// *after* it, never against whatever rows the screen happened to load.
///
/// These types live here rather than in the DAO so the screens can name the
/// dataset they list without importing a data-access class.
library;

/// Which disposal state a scoped case search is restricted to.
enum CaseSearchDisposal {
  /// Every non-deleted case, whatever its disposal state.
  any,

  /// Only cases not disposed by a seeded Step or AD/HCD Result.
  activeOnly,

  /// Only cases disposed by a seeded Step or AD/HCD Result.
  disposedOnly,
}

/// The dataset predicate a case screen applies **before** its text query.
class CaseSearchScope {
  /// Creates a scope; the defaults search every non-deleted case.
  const CaseSearchScope({
    this.disposal = CaseSearchDisposal.any,
    this.nextDateStart,
    this.nextDateEnd,
  });

  /// The disposal predicate.
  final CaseSearchDisposal disposal;

  /// Inclusive lower bound for `next_date`; `null` leaves the window open.
  final int? nextDateStart;

  /// Inclusive upper bound for `next_date`; `null` leaves the window open.
  final int? nextDateEnd;
}
