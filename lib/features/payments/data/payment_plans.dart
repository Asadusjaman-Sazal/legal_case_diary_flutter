/// The four subscription plans and their prices, in one place.
///
/// The paywall shows them and the checkout charges one, so the key that travels
/// in the checkout route's `plan` query parameter, the amount shown in the
/// transfer instructions and the amount submitted with the payment must be the
/// same three facts. The prices are the configured plan prices (৳100 for a
/// month, ৳285 for three, ৳550 for six, ৳1,000 for a year — there is no
/// lifetime plan) and the server's `approve_payment` validates the exact amount
/// and the plan key, so a drift here would be a rejected payment, not a wrong
/// price.
library;

/// Plan key for the 1 Month plan, as sent to the server (`plan_type`).
const String paymentPlanMonthly = 'monthly';

/// Plan key for the 3 Months plan, as sent to the server (`plan_type`).
const String paymentPlanQuarterly = 'quarterly';

/// Plan key for the 6 Months plan, as sent to the server (`plan_type`).
const String paymentPlanHalfYearly = 'half_yearly';

/// Plan key for the 1 Year plan, as sent to the server (`plan_type`).
const String paymentPlanAnnual = 'annual';

/// 1 Month price in BDT.
const int paymentMonthlyPrice = 100;

/// 3 Months price in BDT.
const int paymentQuarterlyPrice = 285;

/// 6 Months price in BDT.
const int paymentHalfYearlyPrice = 550;

/// 1 Year price in BDT.
const int paymentAnnualPrice = 1000;

/// One sellable plan: its server key, its price and how long it lasts.
///
/// The duration is carried here (and mirrored by the server's interval) so the
/// paywall, the checkout and any future "renew" wording read one description of
/// a plan rather than restating its length.
class SubscriptionPlan {
  /// Creates a plan.
  const SubscriptionPlan({
    required this.key,
    required this.amount,
    required this.months,
  });

  /// The `plan_type` sent to the server.
  final String key;

  /// The price in BDT, which is also the amount submitted.
  final int amount;

  /// How many months the plan extends the subscription by.
  final int months;
}

/// Every plan, in the order the paywall lists them.
const List<SubscriptionPlan> subscriptionPlans = <SubscriptionPlan>[
  SubscriptionPlan(
    key: paymentPlanMonthly,
    amount: paymentMonthlyPrice,
    months: 1,
  ),
  SubscriptionPlan(
    key: paymentPlanQuarterly,
    amount: paymentQuarterlyPrice,
    months: 3,
  ),
  SubscriptionPlan(
    key: paymentPlanHalfYearly,
    amount: paymentHalfYearlyPrice,
    months: 6,
  ),
  SubscriptionPlan(
    key: paymentPlanAnnual,
    amount: paymentAnnualPrice,
    months: 12,
  ),
];

/// The amount for [planKey], or null when it is not a known plan.
int? paymentPlanAmount(String? planKey) => switch (planKey) {
  paymentPlanMonthly => paymentMonthlyPrice,
  paymentPlanQuarterly => paymentQuarterlyPrice,
  paymentPlanHalfYearly => paymentHalfYearlyPrice,
  paymentPlanAnnual => paymentAnnualPrice,
  _ => null,
};
