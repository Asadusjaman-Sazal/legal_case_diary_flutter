/// The ten subscription plans and their prices, in one place.
///
/// The paywall shows them and the checkout charges one, so the key that travels
/// in the checkout route's `plan` query parameter, the amount shown in the
/// transfer instructions and the amount submitted with the payment must be the
/// same three facts. The server's `approve_payment` validates the exact amount
/// and the plan key, so a drift here is a rejected payment, not a wrong price.
///
/// **The ladder is ten plans** (Task 21, user ruling): **Pro** sells 1, 3, 6 and
/// 12 months, and **Firm** and **Firm Plus** sell 3, 6 and 12 months — a chamber
/// does not buy a single month. Every price is flat: there is **no struck-through
/// full price, no saving badge and no discount percentage**, which is why this
/// file carries no `undiscountedAmount` or `discountPercent` any more.
///
/// The keys name both the tier and the period (`firm_half_yearly`,
/// `firm_plus_annual`) because the server's allow-list, amount `CASE`, duration
/// `CASE` and generated `plan_name` `CASE` are all driven by the key alone, and
/// a key that named only the period could not say which tier was bought.
library;

import '../../../core/constants/free_tier.dart';

/// Plan key for the Pro 1 Month plan, as sent to the server (`plan_type`).
const String paymentPlanMonthly = 'monthly';

/// Plan key for the Pro 3 Months plan.
const String paymentPlanQuarterly = 'quarterly';

/// Plan key for the Pro 6 Months plan.
const String paymentPlanHalfYearly = 'half_yearly';

/// Plan key for the Pro 1 Year plan.
const String paymentPlanAnnual = 'annual';

/// Plan key for the Firm 3 Months plan.
const String paymentPlanFirmQuarterly = 'firm_quarterly';

/// Plan key for the Firm 6 Months plan.
const String paymentPlanFirmHalfYearly = 'firm_half_yearly';

/// Plan key for the Firm 1 Year plan.
const String paymentPlanFirmAnnual = 'firm_annual';

/// Plan key for the Firm Plus 3 Months plan.
const String paymentPlanFirmPlusQuarterly = 'firm_plus_quarterly';

/// Plan key for the Firm Plus 6 Months plan.
const String paymentPlanFirmPlusHalfYearly = 'firm_plus_half_yearly';

/// Plan key for the Firm Plus 1 Year plan.
const String paymentPlanFirmPlusAnnual = 'firm_plus_annual';

/// Pro prices in BDT: one, three, six and twelve months.
///
/// The annual price moved from the shipped ৳960 to **৳1,000** as a deliberate
/// price rise (Task 21), so the two must change together or a payment is refused.
const int paymentMonthlyPrice = 100;
const int paymentQuarterlyPrice = 285;
const int paymentHalfYearlyPrice = 540;
const int paymentAnnualPrice = 1000;

/// Firm prices in BDT: three, six and twelve months.
const int paymentFirmQuarterlyPrice = 855;
const int paymentFirmHalfYearlyPrice = 1620;
const int paymentFirmAnnualPrice = 3000;

/// Firm Plus prices in BDT: three, six and twelve months.
const int paymentFirmPlusQuarterlyPrice = 1710;
const int paymentFirmPlusHalfYearlyPrice = 3240;
const int paymentFirmPlusAnnualPrice = 6000;

/// The subscription tier a plan belongs to, as stored on `profiles.tier` /
/// `firms.tier` and read by the seat cap and the lapse allowance.
///
/// Each tier carries its two numbers — the **case ceiling it sells** and the
/// **allowance it leaves behind when it lapses** — so the paywall, the write
/// gates and the tests all read one row rather than a number typed at each site.
/// The free ceiling is [freeTierCaseLimit], the same constant the Add Case gate
/// and the server trigger already honour, so 50 is written once.
enum SubscriptionTier {
  /// The free diary: 50 cases, strictly individual. It has no lapse allowance:
  /// a free account was never premium, so it keeps the wall rather than a
  /// read-only set (§5.2).
  free('free', freeTierCaseLimit, 0),

  /// One account, 1,000 cases, cloud backup; a lapsed Pro keeps writing 100.
  pro('pro', 1000, 100),

  /// Up to 5 associates, 2,500 cases; a lapsed Firm keeps writing 500.
  firm('firm', 2500, 500),

  /// Up to 20 associates, 6,000 cases; a lapsed Firm Plus keeps writing 1,000.
  firmPlus('firm_plus', 6000, 1000);

  const SubscriptionTier(this.key, this.caseCeiling, this.lapseAllowance);

  /// The server's own spelling of the tier, as stored in the tier columns.
  final String key;

  /// Cases this tier may hold while it is live — the ceiling §5.3 sells.
  final int caseCeiling;

  /// Cases, notes and case references a **lapsed** holder may still write.
  ///
  /// Zero for [free], which is never "lapsed": its limit is [caseCeiling] and
  /// it has no read-only set. Pro 100, Firm 500, Firm Plus 1,000 (§5.2).
  final int lapseAllowance;

  /// Where this tier sits on the ladder: free 0, pro 1, firm 2, firm_plus 3.
  ///
  /// The declaration order **is** the ladder order, so this is the one place a
  /// "this tier or lower" comparison reads its ranking from — the server's
  /// `tier_rank()` answers the same question for SQL. Reordering [values] would
  /// silently reorder every gate, so `paywall_screen_test.dart` pins the order
  /// and `payment_plan_ladder_test.dart` pins the tier the server reads for each
  /// key against this one.
  int get rank => index;

  /// The tier of [tierKey], or [SubscriptionTier.free] when it names nothing —
  /// a null or unknown tier is "no paid tier", which is the safe reading.
  static SubscriptionTier fromKey(String? tierKey) =>
      values.firstWhere((tier) => tier.key == tierKey, orElse: () => free);
}

/// One sellable plan: its server key, its price, its tier and its period.
///
/// The duration is carried here (and mirrored by the server's interval) so the
/// paywall, the checkout and any future "renew" wording read one description of
/// a plan rather than restating its length. [tier] is derived from the key by
/// [planTier] rather than stored twice, so a key can never disagree with its own
/// tier.
class SubscriptionPlan {
  /// Creates a plan.
  const SubscriptionPlan({
    required this.key,
    required this.amount,
    required this.months,
    required this.tier,
  });

  /// The server's `plan_type` key.
  final String key;

  /// The price in BDT, exactly the amount the server validates.
  final int amount;

  /// How many months the plan extends the subscription by.
  final int months;

  /// The tier this plan buys.
  ///
  /// Carried on the plan row rather than restated in a switch over the keys:
  /// the key, its price, its length and its tier are then one row that cannot
  /// disagree with itself, and adding a plan is one row plus its server entry.
  final SubscriptionTier tier;
}

/// Every plan, in the order the paywall lists them.
///
/// Grouped by tier — Pro, then Firm, then Firm Plus — and within a tier by length,
/// so the list reads as three ladders rather than one mixed column. This is the
/// order the paywall renders and the order the tests expect.
const List<SubscriptionPlan> subscriptionPlans = <SubscriptionPlan>[
  SubscriptionPlan(
    key: paymentPlanMonthly,
    amount: paymentMonthlyPrice,
    months: 1,
    tier: SubscriptionTier.pro,
  ),
  SubscriptionPlan(
    key: paymentPlanQuarterly,
    amount: paymentQuarterlyPrice,
    months: 3,
    tier: SubscriptionTier.pro,
  ),
  SubscriptionPlan(
    key: paymentPlanHalfYearly,
    amount: paymentHalfYearlyPrice,
    months: 6,
    tier: SubscriptionTier.pro,
  ),
  SubscriptionPlan(
    key: paymentPlanAnnual,
    amount: paymentAnnualPrice,
    months: 12,
    tier: SubscriptionTier.pro,
  ),
  SubscriptionPlan(
    key: paymentPlanFirmQuarterly,
    amount: paymentFirmQuarterlyPrice,
    months: 3,
    tier: SubscriptionTier.firm,
  ),
  SubscriptionPlan(
    key: paymentPlanFirmHalfYearly,
    amount: paymentFirmHalfYearlyPrice,
    months: 6,
    tier: SubscriptionTier.firm,
  ),
  SubscriptionPlan(
    key: paymentPlanFirmAnnual,
    amount: paymentFirmAnnualPrice,
    months: 12,
    tier: SubscriptionTier.firm,
  ),
  SubscriptionPlan(
    key: paymentPlanFirmPlusQuarterly,
    amount: paymentFirmPlusQuarterlyPrice,
    months: 3,
    tier: SubscriptionTier.firmPlus,
  ),
  SubscriptionPlan(
    key: paymentPlanFirmPlusHalfYearly,
    amount: paymentFirmPlusHalfYearlyPrice,
    months: 6,
    tier: SubscriptionTier.firmPlus,
  ),
  SubscriptionPlan(
    key: paymentPlanFirmPlusAnnual,
    amount: paymentFirmPlusAnnualPrice,
    months: 12,
    tier: SubscriptionTier.firmPlus,
  ),
];

/// The plan [planKey] names, or null when it is not a known plan.
SubscriptionPlan? subscriptionPlan(String? planKey) {
  for (final plan in subscriptionPlans) {
    if (plan.key == planKey) return plan;
  }
  return null;
}

/// The amount for [planKey], or null when it is not a known plan.
///
/// Read by the checkout's transfer instructions and the admin's request list, so
/// the amount shown is the amount the plan row carries, not a second copy of it.
int? paymentPlanAmount(String? planKey) => subscriptionPlan(planKey)?.amount;

/// The tier [planKey] buys, or null when it is not a known plan.
///
/// Read by the paywall's grouping and the checkout's tier note, so a key's tier
/// is decided in exactly one place.
SubscriptionTier? planTier(String? planKey) => subscriptionPlan(planKey)?.tier;
