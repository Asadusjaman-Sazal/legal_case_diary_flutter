/// The eighteen sellable plans and the six tiers of the revamped ladder.
///
/// The paywall shows them and the checkout charges one, so the key that travels
/// in the checkout route's `plan` query parameter, the amount shown in the
/// transfer instructions and the amount submitted with the payment must be the
/// same three facts. The server's `approve_payment` validates the exact amount
/// and the plan key, so a drift here is a rejected payment, not a wrong price.
///
/// **The ladder is six tiers** (user rulings, 2026-10-19 and 2026-10-20):
///
/// * **Free** — 50 cases, offline only;
/// * **Starter** — 500 cases, one device, ৳80 for one month;
/// * **Pro** — 1,000 cases, two devices, ৳150 for one month;
/// * **Firm** — 2,500 cases, 5 members including the owner, ৳300 for one month
///   or ৳750 for three (৳250 a month);
/// * **Firm Plus** — 6,000 cases, 12 members including the owner, ৳1,500 for
///   three months (৳500 a month);
/// * **Enterprise** — no case or member ceiling, ৳4,500 for three months
///   (৳1,500 a month).
///
/// Starter, Pro and Firm sell 1, 3, 6 and 12 months; Firm's one month is priced
/// 20% above its three-month rate so committing to a quarter still pays. Firm
/// Plus and Enterprise sell 3, 6 and 12. Every price is flat — the total is the
/// only thing charged — and each card prints that total beside its per-month
/// equivalent (total ÷ months, rounded to the taka), which is the only place a
/// saving is stated. There is no struck-through price, no saving badge and no
/// discount percentage.
///
/// The keys name both the tier and the period (`firm_half_yearly`,
/// `enterprise_annual`) because the server's allow-list, amount `CASE`, duration
/// `CASE` and generated `plan_name` `CASE` are all driven by the key alone, and
/// a key that named only the period could not say which tier was bought.
///
/// The four old Pro keys (`monthly`, `quarterly`, `half_yearly`, `annual`) are
/// kept as **legacy read-only keys**: approved rows from before the revamp still
/// carry them, and their tier is now [SubscriptionTier.starter]. They are never
/// sold again and are not in [subscriptionPlans].
library;

import '../../../core/constants/free_tier.dart';

// ---------------------------------------------------------------------------
// Sellable plan keys
// ---------------------------------------------------------------------------

/// Plan key for the Starter 1 Month plan.
const String paymentPlanStarterMonthly = 'starter_monthly';

/// Plan key for the Starter 3 Months plan.
const String paymentPlanStarterQuarterly = 'starter_quarterly';

/// Plan key for the Starter 6 Months plan.
const String paymentPlanStarterHalfYearly = 'starter_half_yearly';

/// Plan key for the Starter 1 Year plan.
const String paymentPlanStarterAnnual = 'starter_annual';

/// Plan key for the Pro 1 Month plan.
const String paymentPlanProMonthly = 'pro_monthly';

/// Plan key for the Pro 3 Months plan.
const String paymentPlanProQuarterly = 'pro_quarterly';

/// Plan key for the Pro 6 Months plan.
const String paymentPlanProHalfYearly = 'pro_half_yearly';

/// Plan key for the Pro 1 Year plan.
const String paymentPlanProAnnual = 'pro_annual';

/// Plan key for the Firm 1 Month plan.
const String paymentPlanFirmMonthly = 'firm_monthly';

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

/// Plan key for the Enterprise 3 Months plan.
const String paymentPlanEnterpriseQuarterly = 'enterprise_quarterly';

/// Plan key for the Enterprise 6 Months plan.
const String paymentPlanEnterpriseHalfYearly = 'enterprise_half_yearly';

/// Plan key for the Enterprise 1 Year plan.
const String paymentPlanEnterpriseAnnual = 'enterprise_annual';

// ---------------------------------------------------------------------------
// Legacy Pro keys (read-only history)
// ---------------------------------------------------------------------------

/// The old Pro 1 Month key. Never sold again; its tier is Starter now.
const String paymentPlanLegacyMonthly = 'monthly';

/// The old Pro 3 Months key.
const String paymentPlanLegacyQuarterly = 'quarterly';

/// The old Pro 6 Months key.
const String paymentPlanLegacyHalfYearly = 'half_yearly';

/// The old Pro 1 Year key.
const String paymentPlanLegacyAnnual = 'annual';

/// The four keys the old Pro tier was sold under.
///
/// They stay readable so an approved purchase made before the revamp still has
/// a name in Subscription History. Their tier is [SubscriptionTier.starter],
/// because that is what the stored `pro` tier became.
const Set<String> legacyStarterPlanKeys = <String>{
  paymentPlanLegacyMonthly,
  paymentPlanLegacyQuarterly,
  paymentPlanLegacyHalfYearly,
  paymentPlanLegacyAnnual,
};

// ---------------------------------------------------------------------------
// Prices, in BDT
// ---------------------------------------------------------------------------

/// Starter prices: one, three, six and twelve months.
const int paymentStarterMonthlyPrice = 80;
const int paymentStarterQuarterlyPrice = 180;
const int paymentStarterHalfYearlyPrice = 300;
const int paymentStarterAnnualPrice = 540;

/// Pro prices: one, three, six and twelve months.
const int paymentProMonthlyPrice = 150;
const int paymentProQuarterlyPrice = 360;
const int paymentProHalfYearlyPrice = 660;
const int paymentProAnnualPrice = 1200;

/// Firm prices: one, three, six and twelve months.
///
/// One month is deliberately dearer per month (৳300) than the three-month rate
/// (৳250), so the card's first two rows are not the same offer.
const int paymentFirmMonthlyPrice = 300;
const int paymentFirmQuarterlyPrice = 750;
const int paymentFirmHalfYearlyPrice = 1350;
const int paymentFirmAnnualPrice = 2500;

/// Firm Plus prices: three, six and twelve months.
const int paymentFirmPlusQuarterlyPrice = 1500;
const int paymentFirmPlusHalfYearlyPrice = 2700;
const int paymentFirmPlusAnnualPrice = 5000;

/// Enterprise prices: three, six and twelve months.
const int paymentEnterpriseQuarterlyPrice = 4500;
const int paymentEnterpriseHalfYearlyPrice = 8000;
const int paymentEnterpriseAnnualPrice = 15000;

// ---------------------------------------------------------------------------
// Tiers
// ---------------------------------------------------------------------------

/// Which paywall tab a tier belongs to.
///
/// The split is presentational: both tabs are visible to every account, and
/// any plan may be bought. The audience decides whether a card sits under
/// **Individual** or **Firm**.
enum SubscriptionAudience {
  /// Free, Starter and Pro.
  individual,

  /// Firm, Firm Plus and Enterprise.
  firm,
}

/// The subscription tier a plan belongs to, as stored on `profiles.tier` /
/// `firms.tier` and read by the seat cap, the case ceiling and the lapse
/// allowance.
///
/// Each tier carries the numbers it sells: its **case ceiling** (null for
/// Enterprise), the **allowance it leaves behind when it lapses**, its
/// **monthly anchor** (one month at the tier's shortest sold rate), its **seat
/// cap** (0 for the individual tiers, null for unlimited) and the **audience**
/// whose tab it sits on. The free ceiling is [freeTierCaseLimit], the same
/// constant the Add Case gate and the server trigger honour, so 50 is written
/// once.
enum SubscriptionTier {
  /// The free diary: 50 cases, offline only, strictly individual. It has no
  /// lapse allowance because a free account was never premium.
  free(
    'free',
    freeTierCaseLimit,
    0,
    0,
    null,
    1,
    SubscriptionAudience.individual,
  ),

  /// One account, 500 cases, one device; a lapsed Starter keeps writing 100.
  starter(
    'starter',
    500,
    100,
    80,
    0,
    1,
    SubscriptionAudience.individual,
  ),

  /// One account, 1,000 cases, two devices; a lapsed Pro keeps writing 250.
  pro(
    'pro',
    1000,
    250,
    150,
    0,
    2,
    SubscriptionAudience.individual,
  ),

  /// Five members including the owner, 2,500 cases; a lapse keeps 500.
  firm('firm', 2500, 500, 250, 5, null, SubscriptionAudience.firm),

  /// Twelve members including the owner, 6,000 cases; a lapse keeps 1,000.
  firmPlus('firm_plus', 6000, 1000, 500, 12, null, SubscriptionAudience.firm),

  /// No case or member ceiling; a lapse keeps 2,000.
  enterprise(
    'enterprise',
    null,
    2000,
    1500,
    null,
    null,
    SubscriptionAudience.firm,
  );

  const SubscriptionTier(
    this.key,
    this.caseCeiling,
    this.lapseAllowance,
    this.monthlyPrice,
    this.seatCap,
    this.deviceCap,
    this.audience,
  );

  /// The server's own spelling of the tier, as stored in the tier columns.
  final String key;

  /// Cases this tier may hold while it is live, or null when uncapped.
  ///
  /// Enterprise is the only null: its card says *Unlimited Cases*, with fair
  /// use stated in the Terms. Every other tier has a number, including Free.
  final int? caseCeiling;

  /// Cases, notes and case references a **lapsed** holder may still write.
  ///
  /// Zero for [free], which is never "lapsed": its limit is [caseCeiling] and
  /// it has no read-only set.
  final int lapseAllowance;

  /// The tier's monthly anchor, in BDT: one month at its shortest sold rate.
  ///
  /// Free is 0, which is the one price line a card still prints. Starter and Pro
  /// anchor at their one-month plan. Firm's anchor is its three-month rate
  /// (৳750 ÷ 3), so its one-month plan is sold *above* it at ৳300 — a month is
  /// the no-commitment option, not the base. Firm Plus and Enterprise sell no
  /// month at all and anchor at their three-month rate.
  final int monthlyPrice;

  /// Members a chamber may hold, including the owner; 0 means "no chamber".
  ///
  /// Null means no cap (Enterprise). The server's `firm_seat_cap` answers the
  /// same numbers.
  final int? seatCap;

  /// Devices an individual account may use, or null when the tier's device
  /// rule is **one per member** rather than one number for the account.
  ///
  /// The paywall states these limits; they are not enforced yet (user ruling,
  /// 2026-10-19). Firm, Firm Plus and Enterprise say *one device each* in
  /// their member line instead of using this field.
  final int? deviceCap;

  /// The paywall tab this tier sits on.
  final SubscriptionAudience audience;

  /// Where this tier sits on the ladder, from Free (0) to Enterprise (5).
  ///
  /// The declaration order **is** the ladder order, so this is the one place a
  /// rank comparison reads its ranking from — the server's `tier_rank()`
  /// answers the same question for SQL. Reordering [values] would silently
  /// reorder every gate, so the tests pin the order.
  int get rank => index;

  /// Whether this tier is sold as a paid plan (every tier except Free).
  bool get isSellable => this != free;

  /// The tier of [tierKey], or [SubscriptionTier.free] when it names nothing —
  /// a null or unknown tier is "no paid tier", which is the safe reading.
  static SubscriptionTier fromKey(String? tierKey) =>
      values.firstWhere((tier) => tier.key == tierKey, orElse: () => free);
}

// ---------------------------------------------------------------------------
// Plans
// ---------------------------------------------------------------------------

/// One sellable plan: its server key, its price, its tier and its period.
///
/// The duration is carried here (and mirrored by the server's interval) so the
/// paywall, the checkout and any future "renew" wording read one description of
/// a plan rather than restating its length. [tier] is carried on the row rather
/// than derived from a switch, so a key, its price, its length and its tier are
/// one row that cannot disagree with itself.
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
  final SubscriptionTier tier;

  /// Whether this is a one-month plan.
  bool get isMonthly => months == 1;
}

/// Every sellable plan, in paywall order.
///
/// Grouped by tier — Starter, Pro, Firm, Firm Plus, Enterprise — and within a
/// tier by length. Starter, Pro and Firm lead with one month; Firm Plus and
/// Enterprise start at three, because those chambers buy a quarter at a time.
const List<SubscriptionPlan> subscriptionPlans = <SubscriptionPlan>[
  SubscriptionPlan(
    key: paymentPlanStarterMonthly,
    amount: paymentStarterMonthlyPrice,
    months: 1,
    tier: SubscriptionTier.starter,
  ),
  SubscriptionPlan(
    key: paymentPlanStarterQuarterly,
    amount: paymentStarterQuarterlyPrice,
    months: 3,
    tier: SubscriptionTier.starter,
  ),
  SubscriptionPlan(
    key: paymentPlanStarterHalfYearly,
    amount: paymentStarterHalfYearlyPrice,
    months: 6,
    tier: SubscriptionTier.starter,
  ),
  SubscriptionPlan(
    key: paymentPlanStarterAnnual,
    amount: paymentStarterAnnualPrice,
    months: 12,
    tier: SubscriptionTier.starter,
  ),
  SubscriptionPlan(
    key: paymentPlanProMonthly,
    amount: paymentProMonthlyPrice,
    months: 1,
    tier: SubscriptionTier.pro,
  ),
  SubscriptionPlan(
    key: paymentPlanProQuarterly,
    amount: paymentProQuarterlyPrice,
    months: 3,
    tier: SubscriptionTier.pro,
  ),
  SubscriptionPlan(
    key: paymentPlanProHalfYearly,
    amount: paymentProHalfYearlyPrice,
    months: 6,
    tier: SubscriptionTier.pro,
  ),
  SubscriptionPlan(
    key: paymentPlanProAnnual,
    amount: paymentProAnnualPrice,
    months: 12,
    tier: SubscriptionTier.pro,
  ),
  SubscriptionPlan(
    key: paymentPlanFirmMonthly,
    amount: paymentFirmMonthlyPrice,
    months: 1,
    tier: SubscriptionTier.firm,
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
  SubscriptionPlan(
    key: paymentPlanEnterpriseQuarterly,
    amount: paymentEnterpriseQuarterlyPrice,
    months: 3,
    tier: SubscriptionTier.enterprise,
  ),
  SubscriptionPlan(
    key: paymentPlanEnterpriseHalfYearly,
    amount: paymentEnterpriseHalfYearlyPrice,
    months: 6,
    tier: SubscriptionTier.enterprise,
  ),
  SubscriptionPlan(
    key: paymentPlanEnterpriseAnnual,
    amount: paymentEnterpriseAnnualPrice,
    months: 12,
    tier: SubscriptionTier.enterprise,
  ),
];

/// The plan [planKey] names, or null when it is not a sellable plan.
///
/// Legacy Pro keys deliberately resolve to null here: they are history, not
/// offers, and no checkout should ever charge one again.
SubscriptionPlan? subscriptionPlan(String? planKey) {
  for (final plan in subscriptionPlans) {
    if (plan.key == planKey) return plan;
  }
  return null;
}

/// The amount for [planKey], or null when it is not a sellable plan.
///
/// Read by the checkout's transfer instructions and the admin's request list, so
/// the amount shown is the amount the plan row carries, not a second copy of it.
int? paymentPlanAmount(String? planKey) => subscriptionPlan(planKey)?.amount;

/// The tier [planKey] buys, or null when it names nothing.
///
/// The four legacy Pro keys answer [SubscriptionTier.starter], because that is
/// what their stored `pro` tier became. This keeps an old approved purchase
/// named consistently in Subscription History.
SubscriptionTier? planTier(String? planKey) {
  final plan = subscriptionPlan(planKey);
  if (plan != null) return plan.tier;
  if (legacyStarterPlanKeys.contains(planKey)) {
    return SubscriptionTier.starter;
  }
  return null;
}

/// Whether [planKey] is one of the four old Pro keys.
bool isLegacyStarterPlan(String? planKey) =>
    legacyStarterPlanKeys.contains(planKey);

/// Every sellable plan of [tier], shortest term first.
List<SubscriptionPlan> plansForTier(SubscriptionTier tier) => subscriptionPlans
    .where((plan) => plan.tier == tier)
    .toList(growable: false);

/// Every sellable plan on [audience]'s tab, in paywall order.
List<SubscriptionPlan> plansForAudience(SubscriptionAudience audience) =>
    subscriptionPlans
        .where((plan) => plan.tier.audience == audience)
        .toList(growable: false);

/// The one-month plan of [tier], or null when the tier does not sell one.
SubscriptionPlan? monthlyPlanFor(SubscriptionTier tier) {
  for (final plan in plansForTier(tier)) {
    if (plan.isMonthly) return plan;
  }
  return null;
}

/// The shortest plan [tier] sells — the base price when no term is selected.
///
/// Starter, Pro and Firm answer their one-month plan; Firm Plus and Enterprise
/// answer their three-month plan. Free has no paid plan and answers null.
SubscriptionPlan? shortestPlanFor(SubscriptionTier tier) {
  final plans = plansForTier(tier);
  return plans.isEmpty ? null : plans.first;
}

/// The tier labels in paywall order, for the audience tabs.
List<SubscriptionTier> tiersForAudience(SubscriptionAudience audience) =>
    SubscriptionTier.values
        .where((tier) => tier.audience == audience)
        .toList(growable: false);
