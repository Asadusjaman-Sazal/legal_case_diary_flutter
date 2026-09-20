/// Free-tier limits (plan §Subscription Model and §6 Subscription Enforcement).
///
/// The number lives in exactly one place because it decides two things that
/// must never disagree: the **gate** in the Add Case flow and the wording the
/// paywall shows the user. A copy that drifted from the rule would tell the user
/// the wrong thing about their own data.
library;

/// Cases a free account may hold at once.
///
/// Counted with `CasesDao.getNonDeletedCaseCount()`, so **soft-deleted rows
/// never count**: deleting a case is how a free user makes room again.
/// `getActiveCaseCount()` has different semantics (it also excludes cases
/// disposed by a seeded step or AD/HCD result) and must not be used for this
/// gate — it would block a user below the limit they were promised.
const int freeTierCaseLimit = 50;
