/// The tier actually in force, mirroring the server's `effective_tier`.
///
/// Phase 10's allowance is taken from the tier **in force**, not from the raw
/// column: a downgrade writes the pending pair and switches when the paid period
/// ends, so after that instant the account holds the lower tier even though
/// `tier` still names the one that was bought. The server already answers this
/// in `effective_tier(tier, tier_pending, tier_pending_from)`; this is the same
/// rule on the device, in one place, so no gate re-implements the waiting rule.
library;

import 'payment_plans.dart';

/// The tier in force at [now].
///
/// `tier` is the stored value, [pendingKey] and [pendingFromMs] the waiting
/// downgrade's pair as cached on `profiles` / `firms`. The pending tier applies
/// from [pendingFromMs] inclusive; before that instant, and whenever the pair is
/// incomplete, the stored tier stands. Unknown keys read as
/// [SubscriptionTier.free], the safe direction.
SubscriptionTier effectiveTier({
  required SubscriptionTier tier,
  String? pendingKey,
  int? pendingFromMs,
  DateTime? now,
}) {
  if (pendingKey == null || pendingFromMs == null) return tier;
  final from = DateTime.fromMillisecondsSinceEpoch(pendingFromMs, isUtc: true);
  final instant = (now ?? DateTime.now()).toUtc();
  return instant.isBefore(from) ? tier : SubscriptionTier.fromKey(pendingKey);
}
