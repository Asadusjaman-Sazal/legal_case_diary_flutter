/// The two subscription plans and their prices, in one place.
///
/// The paywall shows them and the checkout charges one, so the key that travels
/// in the checkout route's `plan` query parameter, the amount shown in the
/// transfer instructions and the amount submitted with the payment must be the
/// same three facts. Plan §Pricing fixes ৳100 per month and ৳1,000 per year —
/// there is no lifetime plan — and the server's `approve_payment` validates the
/// exact amount, so a drift here would be a rejected payment, not a wrong price.
library;

/// Plan key for the monthly plan, as sent to the server (`plan_type`).
const String paymentPlanMonthly = 'monthly';

/// Plan key for the annual plan, as sent to the server (`plan_type`).
const String paymentPlanAnnual = 'annual';

/// Monthly price in BDT (plan §Pricing).
const int paymentMonthlyPrice = 100;

/// Annual price in BDT (plan §Pricing).
const int paymentAnnualPrice = 1000;

/// The amount for [planKey], or null when it is not a known plan.
int? paymentPlanAmount(String? planKey) => switch (planKey) {
  paymentPlanMonthly => paymentMonthlyPrice,
  paymentPlanAnnual => paymentAnnualPrice,
  _ => null,
};
