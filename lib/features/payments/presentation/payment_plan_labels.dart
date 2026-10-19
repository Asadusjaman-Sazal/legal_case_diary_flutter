/// The localized name of one subscription plan or tier.
///
/// The plan key is the single source of a plan's identity (see
/// `payment_plans.dart`), and three screens render its name — the paywall, the
/// checkout's plan summary and Subscription Details — so the key-to-name
/// mapping lives here once rather than as a chain of ternaries repeated in
/// each.
///
/// The tier's own name (*Free*, *Starter*, *Pro*, *Firm*, *Firm Plus*,
/// *Enterprise*) comes from [subscriptionTierLabel] beside it: a screen that
/// shows a plan in a tier group needs both, and they must agree on the key that
/// drives them.
library;

import '../../../core/l10n/generated/app_localizations.dart';
import '../data/payment_plans.dart';

/// The localized display name of [planKey], defaulting to the Starter 1 Month
/// plan for a null or unknown key (the same safe default the checkout applies).
///
/// The four old Pro keys are mapped to the Starter labels: their stored tier
/// became Starter, so a historical row reads as the tier the account now holds
/// rather than a plan name the ladder no longer sells.
String paymentPlanLabel(AppLocalizations l, String? planKey) =>
    switch (planKey) {
      paymentPlanStarterMonthly ||
      paymentPlanLegacyMonthly => l.paywall_planStarterMonthly,
      paymentPlanStarterQuarterly ||
      paymentPlanLegacyQuarterly => l.paywall_planStarterQuarterly,
      paymentPlanStarterHalfYearly ||
      paymentPlanLegacyHalfYearly => l.paywall_planStarterHalfYearly,
      paymentPlanStarterAnnual ||
      paymentPlanLegacyAnnual => l.paywall_planStarterAnnual,
      paymentPlanProMonthly => l.paywall_planProMonthly,
      paymentPlanProQuarterly => l.paywall_planProQuarterly,
      paymentPlanProHalfYearly => l.paywall_planProHalfYearly,
      paymentPlanProAnnual => l.paywall_planProAnnual,
      paymentPlanFirmQuarterly => l.paywall_planFirmQuarterly,
      paymentPlanFirmHalfYearly => l.paywall_planFirmHalfYearly,
      paymentPlanFirmAnnual => l.paywall_planFirmAnnual,
      paymentPlanFirmPlusQuarterly => l.paywall_planFirmPlusQuarterly,
      paymentPlanFirmPlusHalfYearly => l.paywall_planFirmPlusHalfYearly,
      paymentPlanFirmPlusAnnual => l.paywall_planFirmPlusAnnual,
      paymentPlanEnterpriseQuarterly => l.paywall_planEnterpriseQuarterly,
      paymentPlanEnterpriseHalfYearly => l.paywall_planEnterpriseHalfYearly,
      paymentPlanEnterpriseAnnual => l.paywall_planEnterpriseAnnual,
      _ => l.paywall_planStarterMonthly,
    };

/// The localized name of [tier] — *Free*, *Starter*, *Pro*, *Firm*, *Firm Plus*
/// or *Enterprise*.
///
/// The server stores the tier as a key (`starter`, `pro`, `firm`, `firm_plus`,
/// `enterprise`), so the stored value never localizes; this is where the app's
/// own words come from.
String subscriptionTierLabel(AppLocalizations l, SubscriptionTier tier) =>
    switch (tier) {
      SubscriptionTier.free => l.paywall_tierFree,
      SubscriptionTier.starter => l.paywall_tierStarter,
      SubscriptionTier.pro => l.paywall_tierPro,
      SubscriptionTier.firm => l.paywall_tierFirm,
      SubscriptionTier.firmPlus => l.paywall_tierFirmPlus,
      SubscriptionTier.enterprise => l.paywall_tierEnterprise,
    };
