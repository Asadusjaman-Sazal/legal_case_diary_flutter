/// Paywall screen: the six-tier ladder as stacked plan cards.
///
/// The page follows the shape the user approved on 2026-10-19:
///
/// * an intro line and an **Individual / Firm** pill toggle;
/// * one full-width card per tier, stacked — never side by side — with the
///   plan's name, badge, description, inherited-feature header, feature rows,
///   monthly price, three term buttons, the free-month notes and one action;
/// * every paid tier's term buttons are grey with dark text; the chosen one
///   takes a **2px ink outline**, the app's one selected-state mark. Individual
///   cards open on **1 Month** and chamber cards on **6 Months**, and selecting
///   is one-way: tapping the chosen term leaves it chosen, so a card always
///   carries a term (and its action) to buy. A 6-month or yearly button also
///   shows its undiscounted price struck in red with the saving in green;
/// * paid cards lead their list with **Includes Everything in X, plus** — the
///   *Includes* heading Free already had, so every card opens its list the same
///   way — and a card takes the ink outline when it is **touched**, keeping it
///   until a different card is touched;
/// * the card the account holds carries **Current Plan** and its action says
///   **Renew**; a queued change carries **Scheduled** and its start date; the
///   Starter and Firm cards carry **Most Popular**.
///
/// **Changing plans never happens immediately.** A different tier bought while
/// the current plan is active is queued to start when that plan ends, and the
/// screen warns with both dates before checkout. A same-tier purchase is a
/// renewal; a lapsed or free account starts at once. One change may be queued:
/// a third tier's action is disabled until the queued one starts.
///
/// No entitlement logic lives here: whether premium is *live* is
/// `resolvePremiumAccess`'s answer, and which tier is *held* is
/// `allowanceTierProvider`'s.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/constants/free_tier.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/date_utils.dart';
import '../../accounts_and_profile/data/account_mode.dart';
import '../data/payment_plans.dart';
import 'current_plan.dart';
import 'payment_plan_labels.dart';

/// One feature row on a card: its icon and its already-localized sentence.
class _PlanFeature {
  const _PlanFeature(this.icon, this.text);

  final IconData icon;
  final String text;
}

/// The subscription-plan screen, optionally carrying a gate's card.
class PaywallScreen extends ConsumerStatefulWidget {
  /// Whether the free-limit card is shown, i.e. the gate's own entry.
  ///
  /// A query parameter decides it (`?reason=limit`) so the 50-case entry opens
  /// the card and every other entry opens the bare route and hides it — the
  /// paywall is one screen with one optional card, not two screens.
  final bool showLimit;

  /// Whether the **lapsed allowance** card is shown (`?reason=lapsed`).
  final bool showLapsed;

  /// Creates the paywall, hiding the gate cards unless their flag is set.
  const PaywallScreen({
    super.key,
    this.showLimit = false,
    this.showLapsed = false,
  });

  /// Whether this entry shows the free-limit card.
  static bool showLimitFor(GoRouterState state) =>
      state.uri.queryParameters['reason'] == 'limit';

  /// Whether this entry is the lapsed allowance's own.
  static bool showLapsedFor(GoRouterState state) =>
      state.uri.queryParameters['reason'] == 'lapsed';

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  /// The tab the user chose, or null before the first tap (the effective
  /// tier's own audience is used until then).
  SubscriptionAudience? _audience;

  /// Each tier's chosen term, or null after the selected term is tapped again.
  /// A tier with no entry defaults to its annual plan.
  final Map<SubscriptionTier, String?> _selectedTerm = {};

  /// The card the user last touched, if any.
  ///
  /// One at a time by design: touching a card inks it and leaves it inked until
  /// another card is touched, so the outline marks the card in hand rather than
  /// only the moment of the press.
  SubscriptionTier? _touchedTier;

  /// The amount rendered with the app's own currency formatting.
  String _amountText(AppLocalizations l, int amount) => l.payments_amountValue(
    AppDateUtils.formatDigits(amount, l.localeName, grouping: amount >= 1000),
  );

  /// A compact localized date for the change dialogs.
  String _dateText(AppLocalizations l, int epochMs) =>
      AppDateUtils.formatDateDDMMYYYY(epochMs, locale: l.localeName);

  /// The term name only — *1 Month*, *3 Months*, *6 Months*, *1 Year*.
  String _termLabel(AppLocalizations l, int months) => switch (months) {
    1 => l.paywall_termMonthly,
    3 => l.paywall_termQuarterly,
    6 => l.paywall_termHalfYearly,
    _ => l.paywall_termAnnual,
  };

  /// The price the action prints: *৳60/month* or *1 Year/৳600*.
  String _actionPrice(AppLocalizations l, SubscriptionPlan plan) {
    final amount = _amountText(l, plan.amount);
    return plan.months == 1
        ? l.paywall_pricePerMonth(amount)
        : '${_termLabel(l, plan.months)}/$amount';
  }

  /// The ceiling a tier sells, in words, for the change dialog.
  String _ceilingText(AppLocalizations l, SubscriptionTier tier) {
    final ceiling = tier.caseCeiling;
    if (ceiling == null) return l.paywall_featureUnlimitedCases;
    return l.paywall_featureCases(
      AppDateUtils.formatDigits(ceiling, l.localeName, grouping: true),
    );
  }

  /// The tier's own feature rows, in display order.
  ///
  /// Only what the tier **adds** is listed: the inherited features sit behind
  /// the card's *Includes Everything in X, plus* header.
  List<_PlanFeature> _features(AppLocalizations l, SubscriptionTier tier) {
    String cases(int count) => l.paywall_featureCases(
      AppDateUtils.formatDigits(count, l.localeName, grouping: true),
    );
    return switch (tier) {
      SubscriptionTier.free => <_PlanFeature>[
        _PlanFeature(Icons.folder_outlined, cases(tier.caseCeiling!)),
        _PlanFeature(Icons.wifi_off_outlined, l.paywall_featureOfflineUse),
        _PlanFeature(Icons.restore_outlined, l.paywall_featureOfflineBackup),
        _PlanFeature(Icons.tune_outlined, l.paywall_featureCustomization),
      ],
      SubscriptionTier.starter => <_PlanFeature>[
        _PlanFeature(Icons.folder_outlined, cases(tier.caseCeiling!)),
        _PlanFeature(
          Icons.cloud_upload_outlined,
          l.paywall_featureCloudBackup,
        ),
        _PlanFeature(
          Icons.cloud_done_outlined,
          l.paywall_featureDisasterRecovery,
        ),
        _PlanFeature(
          Icons.smartphone_outlined,
          l.paywall_featureSingleDevice,
        ),
      ],
      SubscriptionTier.pro => <_PlanFeature>[
        _PlanFeature(Icons.folder_outlined, cases(tier.caseCeiling!)),
        _PlanFeature(
          Icons.devices_outlined,
          l.paywall_featureMultiDevice(
            AppDateUtils.formatDigits(
              tier.deviceCap!,
              l.localeName,
              grouping: false,
            ),
          ),
        ),
      ],
      SubscriptionTier.firm => <_PlanFeature>[
        _PlanFeature(Icons.folder_outlined, cases(tier.caseCeiling!)),
        _PlanFeature(
          Icons.groups_outlined,
          l.paywall_featureCollaboration(
            AppDateUtils.formatDigits(
              tier.seatCap!,
              l.localeName,
              grouping: false,
            ),
          ),
        ),
      ],
      SubscriptionTier.firmPlus => <_PlanFeature>[
        _PlanFeature(Icons.folder_outlined, cases(tier.caseCeiling!)),
        _PlanFeature(
          Icons.groups_outlined,
          l.paywall_featureCollaboration(
            AppDateUtils.formatDigits(
              tier.seatCap!,
              l.localeName,
              grouping: false,
            ),
          ),
        ),
      ],
      SubscriptionTier.enterprise => <_PlanFeature>[
        _PlanFeature(
          Icons.all_inclusive,
          '${l.paywall_featureUnlimitedCases} (${l.paywall_fairUse})',
        ),
        _PlanFeature(
          Icons.groups_outlined,
          l.paywall_featureUnlimitedMembers,
        ),
      ],
    };
  }

  /// The tier a paid tier inherits from, for its *Everything in X, plus* line
  /// (which the card prints under *Includes*).
  SubscriptionTier _previousTier(SubscriptionTier tier) =>
      SubscriptionTier.values[tier.index - 1];

  /// The term selected for [tier]; the audience's own by default.
  ///
  /// Individual plans open on **1 Month** (the tier's base price, so no term
  /// button is ticked), chamber plans on **6 Months**. A chamber tier has no
  /// one-month plan, so it cannot open on the base price the way Starter does.
  String? _selectedKey(SubscriptionTier tier) {
    if (_selectedTerm.containsKey(tier)) return _selectedTerm[tier];
    final plans = plansForTier(tier);
    if (plans.isEmpty) return null;
    return tier.audience == SubscriptionAudience.individual
        ? plans.first.key
        : plans.firstWhere((plan) => plan.months == 6).key;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isMember = ref.watch(firmMemberProvider);
    final currentPlan = ref.watch(currentPlanProvider);
    final effectiveTier = ref.watch(allowanceTierProvider);
    final profile = ref.watch(accountProfileProvider).value;
    final firm = ref.watch(accountFirmProvider).value;

    final isFirmAccount = profile?.firmId != null;
    final expiryMs = isFirmAccount
        ? firm?.subscriptionExpiry
        : profile?.subscriptionExpiry;
    final pendingKey = isFirmAccount
        ? firm?.tierPending
        : profile?.tierPending;
    final pendingFrom = isFirmAccount
        ? firm?.tierPendingFrom
        : profile?.tierPendingFrom;
    final pendingTier = pendingKey == null
        ? null
        : SubscriptionTier.fromKey(pendingKey);
    final pendingInstant = pendingFrom == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(pendingFrom, isUtc: true);
    final hasScheduled =
        pendingTier != null &&
        pendingTier != effectiveTier &&
        pendingInstant != null &&
        DateTime.now().toUtc().isBefore(pendingInstant);
    final isActive =
        currentPlan.known &&
        currentPlan.premium &&
        expiryMs != null &&
        expiryMs > DateTime.now().millisecondsSinceEpoch;

    final audience =
        _audience ?? effectiveTier.audience;

    return SafeArea(
      top: true,
      bottom: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        // The default leading is a back arrow on a pushed route, which is the
        // way out of the gate: Cancel means "keep my cases as they are".
        appBar: AppBar(
          title: Text(l.paywall_title, style: AppTypography.titleLg),
          backgroundColor: AppColors.surfaceContainerLowest,
        ),
        body: CustomScrollView(
          slivers: [
            if (!isMember)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.edgeMargin,
                  AppSpacing.md,
                  AppSpacing.edgeMargin,
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l.paywall_intro,
                        style: AppTypography.bodyMd.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      // The toggle scrolls with the page: it is a one-time
                      // choice, not a control to keep on screen.
                      Center(
                        child: _AudienceToggle(
                          selected: audience,
                          onChanged: (value) =>
                              setState(() => _audience = value),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.edgeMargin,
                AppSpacing.sm,
                AppSpacing.edgeMargin,
                AppSpacing.xl,
              ),
              sliver: SliverList.list(
                children: [
                  if (isMember) ..._memberNotice(l) else ..._offer(
                    l: l,
                    audience: audience,
                    effectiveTier: effectiveTier,
                    pendingTier: pendingTier,
                    pendingFrom: pendingFrom,
                    hasScheduled: hasScheduled,
                    isActive: isActive,
                    expiryMs: expiryMs,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A chamber member has nothing to buy here (Phase 9).
  List<Widget> _memberNotice(AppLocalizations l) => <Widget>[
    Text(
      l.paywall_memberPlanTitle,
      style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.w700),
    ),
    const SizedBox(height: AppSpacing.sm),
    Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Text(
        l.paywall_memberPlanBody,
        style: AppTypography.bodyMd.copyWith(color: AppColors.onSurface),
      ),
    ),
  ];

  /// The gate card, the intro, the toggle, the scheduled banner and the cards.
  List<Widget> _offer({
    required AppLocalizations l,
    required SubscriptionAudience audience,
    required SubscriptionTier effectiveTier,
    required SubscriptionTier? pendingTier,
    required int? pendingFrom,
    required bool hasScheduled,
    required bool isActive,
    required int? expiryMs,
  }) {
    final tiers = tiersForAudience(audience);
    return <Widget>[
      if (widget.showLimit || widget.showLapsed) ...<Widget>[
        _LimitCard(lapsed: widget.showLapsed),
        const SizedBox(height: AppSpacing.lg),
      ],
      if (hasScheduled) ...<Widget>[
        _ScheduledBanner(
          key: const ValueKey('paywall-scheduled-banner'),
          label: l.paywall_scheduledBadge,
          body: l.paywall_startsOn(
            _dateText(l, pendingFrom!),
          ),
          tier: subscriptionTierLabel(l, pendingTier!),
        ),
      ],
      const SizedBox(height: AppSpacing.md),
      for (var i = 0; i < tiers.length; i++) ...<Widget>[
        // Roomier than the old `md`: six full cards in a row read as one block
        // without it, and the 16px gutter made neighbouring terms look paired.
        if (i > 0) const SizedBox(height: AppSpacing.lg),
        _buildCard(
          l: l,
          tier: tiers[i],
          effectiveTier: effectiveTier,
          pendingTier: pendingTier,
          pendingFrom: pendingFrom,
          hasScheduled: hasScheduled,
          isActive: isActive,
          expiryMs: expiryMs,
        ),
      ],
    ];
  }

  /// One plan card.
  Widget _buildCard({
    required AppLocalizations l,
    required SubscriptionTier tier,
    required SubscriptionTier effectiveTier,
    required SubscriptionTier? pendingTier,
    required int? pendingFrom,
    required bool hasScheduled,
    required bool isActive,
    required int? expiryMs,
  }) {
    final isCurrent = tier == effectiveTier;
    final isScheduled = hasScheduled && tier == pendingTier;
    final isBlocked =
        hasScheduled && !isCurrent && !isScheduled;
    final isPopular =
        !isCurrent && !isScheduled &&
        (tier == SubscriptionTier.starter || tier == SubscriptionTier.firm);

    final selectedKey = tier.isSellable ? _selectedKey(tier) : null;
    final selectedPlan = selectedKey == null
        ? null
        : subscriptionPlan(selectedKey);
    final basePlan = selectedPlan ?? shortestPlanFor(tier);

    final badge = isCurrent
        ? l.paywall_currentPlanBadge
        : isScheduled
        ? l.paywall_scheduledBadge
        : isPopular
        ? l.paywall_mostPopular
        : null;

    final ctaLabel = _ctaLabel(
      l,
      tier: tier,
      isCurrent: isCurrent,
      isScheduled: isScheduled,
      plan: basePlan,
    );

    return _PlanCardFrame(
      key: ValueKey('paywall-plan-${tier.key}'),
      // Inked once touched and kept inked until another card is touched. Only
      // one card can hold the mark, so the state lives on the screen.
      isTouched: _touchedTier == tier,
      onTouched: () => setState(() => _touchedTier = tier),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  subscriptionTierLabel(l, tier),
                  style: AppTypography.titleLg,
                ),
              ),
              if (badge != null) ...<Widget>[
                const SizedBox(width: AppSpacing.sm),
                _Badge(label: badge),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(
            _description(l, tier),
            // 1.5 line height instead of bodyMd's 20/14: the card is a column
            // of short lines, and the default reads as tight there.
            style: AppTypography.bodyMd.copyWith(
              color: AppColors.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          if (isScheduled) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              l.paywall_startsOn(
                _dateText(l, _pendingStart(pendingFrom, expiryMs)),
              ),
              style: AppTypography.labelLg.copyWith(
                color: AppColors.primary,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(
            // Every card's feature list opens with *Includes*. On a paid card
            // it runs straight into the inherited line — *Includes Everything
            // in Free, plus* — so no comma: the phrase is one sentence.
            tier == SubscriptionTier.free
                ? l.paywall_includes
                : '${l.paywall_includes} '
                      '${l.paywall_everythingIn(
                        subscriptionTierLabel(l, _previousTier(tier)),
                      )}',
            style: AppTypography.titleMd,
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final feature in _features(l, tier)) ...<Widget>[
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    feature.icon,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      feature.text,
                      style: AppTypography.bodyMd.copyWith(
                        color: AppColors.onSurface,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (tier == SubscriptionTier.free) ...<Widget>[
            // The one price line left on the screen: Free sells no term, so it
            // has no rows to carry a total and its price lives here.
            const SizedBox(height: AppSpacing.xs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  _amountText(l, tier.monthlyPrice),
                  style: AppTypography.headlineLg,
                ),
                const SizedBox(width: 2),
                Text(
                  l.paywall_perMonth,
                  style: AppTypography.bodyMd.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
          if (tier.isSellable) ...<Widget>[
            // Each term is a row carrying its own total and its per-month
            // equivalent, so the card needs no headline price and no note.
            const SizedBox(height: AppSpacing.md),
            _TermSelector(
              tier: tier,
              selectedKey: selectedKey,
              // Selecting is one-way: a tap on the chosen term leaves it chosen,
              // so a card always carries a term to buy.
              onSelected: (planKey) => setState(() {
                _selectedTerm[tier] = planKey;
              }),
            ),
          ],
          // The gap under the last term — or under Free's price line — before
          // the action: a row touching the button reads as part of it.
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            key: ValueKey('paywall-subscribe-${tier.key}'),
            onPressed: tier.isSellable && !isBlocked
                ? () => _onCta(
                    l: l,
                    tier: tier,
                    planKey: basePlan!.key,
                    isCurrent: isCurrent,
                    isScheduled: isScheduled,
                    hasScheduled: hasScheduled,
                    isActive: isActive,
                    expiryMs: expiryMs,
                    pendingTier: pendingTier,
                  )
                : null,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              disabledBackgroundColor: AppColors.surfaceContainerHigh,
              disabledForegroundColor: AppColors.onSurfaceVariant,
              textStyle: AppTypography.titleMd,
              minimumSize: const Size.fromHeight(54),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
              ),
            ),
            child: Text(ctaLabel, textAlign: TextAlign.center),
          ),
          if (isBlocked) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              l.paywall_changePendingBody(
                subscriptionTierLabel(l, pendingTier!),
                _dateText(l, _pendingStart(pendingFrom, expiryMs)),
              ),
              style: AppTypography.bodySm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// The card's one-line description.

  String _description(AppLocalizations l, SubscriptionTier tier) =>
      switch (tier) {
        SubscriptionTier.free => l.paywall_tierFreeNote,
        SubscriptionTier.starter => l.paywall_tierStarterNote,
        SubscriptionTier.pro => l.paywall_tierProNote,
        SubscriptionTier.firm => l.paywall_tierFirmNote,
        SubscriptionTier.firmPlus => l.paywall_tierFirmPlusNote,
        SubscriptionTier.enterprise => l.paywall_tierEnterpriseNote,
      };

  /// The action's label, including the selected term and its price.
  String _ctaLabel(
    AppLocalizations l, {
    required SubscriptionTier tier,
    required bool isCurrent,
    required bool isScheduled,
    required SubscriptionPlan? plan,
  }) {
    if (tier == SubscriptionTier.free) {
      return isCurrent ? l.paywall_currentPlanBadge : l.paywall_included;
    }
    final price = _actionPrice(l, plan!);
    if (isScheduled) return l.paywall_renewScheduledPlan(price);
    if (isCurrent) return l.paywall_renewPlan(price);
    return l.paywall_subscribePlan(price);
  }

  /// The start instant a scheduled plan shows. The server stores it as the
  /// current expiry; when it has not landed yet, the current expiry is the best
  /// answer the device has.
  int _pendingStart(int? pendingFrom, int? expiryMs) =>
      pendingFrom ?? expiryMs ?? DateTime.now().millisecondsSinceEpoch;

  /// Runs the action: warn for a different tier, then push the checkout.
  Future<void> _onCta({
    required AppLocalizations l,
    required SubscriptionTier tier,
    required String planKey,
    required bool isCurrent,
    required bool isScheduled,
    required bool hasScheduled,
    required bool isActive,
    required int? expiryMs,
    required SubscriptionTier? pendingTier,
  }) async {
    if (hasScheduled && !isCurrent && !isScheduled) return;

    final plan = subscriptionPlan(planKey);
    if (plan == null) return;

    if (isCurrent && hasScheduled && isActive && expiryMs != null) {
      final confirmed = await _showRenewShiftDialog(
        l,
        current: subscriptionTierLabel(l, tier),
        next: subscriptionTierLabel(l, pendingTier!),
        endMs: _addMonths(expiryMs, plan.months),
      );
      if (!confirmed) return;
    } else if (!isCurrent && !isScheduled && isActive && expiryMs != null) {
      final confirmed = await _showChangeDialog(
        l,
        current: subscriptionTierLabel(l, _currentTierForLabel()),
        next: subscriptionTierLabel(l, tier),
        startMs: expiryMs,
        termMonths: plan.months,
        ceiling: _ceilingText(l, tier),
      );
      if (!confirmed) return;
    }

    if (!mounted) return;
    context.push('${AppRoutes.checkout}?plan=$planKey');
  }

  /// The effective tier for the warning's "your current plan" sentence.
  ///
  /// Kept as a helper so the dialog and the cards read the same state.
  SubscriptionTier _currentTierForLabel() =>
      ref.read(allowanceTierProvider);

  /// Adds [months] to an epoch-ms instant, in UTC.
  int _addMonths(int epochMs, int months) {
    final dt = DateTime.fromMillisecondsSinceEpoch(epochMs, isUtc: true);
    return DateTime.utc(
      dt.year,
      dt.month + months,
      dt.day,
      dt.hour,
      dt.minute,
    ).millisecondsSinceEpoch;
  }

  Future<bool> _showChangeDialog(
    AppLocalizations l, {
    required String current,
    required String next,
    required int startMs,
    required int termMonths,
    required String ceiling,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('paywall-change-dialog'),
        title: Text(l.paywall_changeTitle),
        content: Text(
          l.paywall_changeBody(
            current,
            _dateText(l, startMs),
            next,
            _dateText(l, startMs),
            _termLabel(l, termMonths),
            ceiling,
          ),
          style: AppTypography.bodyMd,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextButton(
                key: const ValueKey('paywall-change-go-back'),
                style: _dialogSecondaryStyle(),
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l.paywall_changeGoBack),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                key: const ValueKey('paywall-change-continue'),
                style: _dialogPrimaryStyle(),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l.paywall_changeContinue),
              ),
            ],
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<bool> _showRenewShiftDialog(
    AppLocalizations l, {
    required String current,
    required String next,
    required int endMs,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('paywall-renew-shift-dialog'),
        title: Text(l.paywall_renewShiftTitle),
        content: Text(
          l.paywall_renewShiftBody(
            current,
            _dateText(l, endMs),
            next,
          ),
          style: AppTypography.bodyMd,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextButton(
                key: const ValueKey('paywall-renew-shift-go-back'),
                style: _dialogSecondaryStyle(),
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l.paywall_changeGoBack),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                key: const ValueKey('paywall-renew-shift-continue'),
                style: _dialogPrimaryStyle(),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l.paywall_renewShiftConfirm),
              ),
            ],
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  ButtonStyle _dialogSecondaryStyle() => TextButton.styleFrom(
    minimumSize: const Size.fromHeight(48),
    backgroundColor: AppColors.secondary,
    foregroundColor: AppColors.onSecondary,
    textStyle: const TextStyle(fontSize: 16),
  );

  ButtonStyle _dialogPrimaryStyle() => TextButton.styleFrom(
    minimumSize: const Size.fromHeight(48),
    backgroundColor: AppColors.primary,
    foregroundColor: AppColors.onPrimary,
    textStyle: const TextStyle(fontSize: 16),
  );
}

/// A plan card's surface: 1px grey until touched, 2px ink once it is.
///
/// Touching any part of the card inks it, and the ink **stays** after the finger
/// lifts, until a different card is touched — so the outline marks the card the
/// user is looking at, not just the moment of the press.
///
/// The touched tier lives in the screen's state, not here: only one card may be
/// inked at a time, and a card cannot know when a sibling is touched.
class _PlanCardFrame extends StatelessWidget {
  const _PlanCardFrame({
    required this.isTouched,
    required this.onTouched,
    required this.child,
    super.key,
  });

  final bool isTouched;
  final VoidCallback onTouched;
  final Widget child;

  @override
  Widget build(BuildContext context) => Listener(
    // `Listener` rather than `GestureDetector`: the card's own buttons must
    // keep their taps, and a raw pointer listener never competes with them for
    // the gesture arena.
    onPointerDown: (_) => onTouched(),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
        border: Border.all(
          color: isTouched ? AppColors.primary : AppColors.outlineVariant,
          width: isTouched ? 2 : 1,
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: child,
    ),
  );
}

/// The plan card's small status pill.
class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: 3,
    ),
    decoration: BoxDecoration(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
    ),
    child: Text(
      label,
      style: AppTypography.labelMd.copyWith(color: AppColors.onPrimary),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
  );
}

/// The Individual / Firm pill toggle.
class _AudienceToggle extends StatelessWidget {
  const _AudienceToggle({required this.selected, required this.onChanged});

  final SubscriptionAudience selected;
  final ValueChanged<SubscriptionAudience> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment(
            key: const ValueKey('paywall-audience-individual'),
            label: l.paywall_audienceIndividual,
            value: SubscriptionAudience.individual,
            isSelected: selected == SubscriptionAudience.individual,
          ),
          _segment(
            key: const ValueKey('paywall-audience-firm'),
            label: l.paywall_audienceFirm,
            value: SubscriptionAudience.firm,
            isSelected: selected == SubscriptionAudience.firm,
          ),
        ],
      ),
    );
  }

  Widget _segment({
    required Key key,
    required String label,
    required SubscriptionAudience value,
    required bool isSelected,
  }) => Semantics(
    button: true,
    selected: isSelected,
    label: label,
    child: Material(
      color: isSelected ? AppColors.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      child: InkWell(
        key: key,
        onTap: () => onChanged(value),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 112),
          child: Center(
            child: Text(
              label,
              style: AppTypography.labelLg.copyWith(
                color: isSelected
                    ? AppColors.onPrimary
                    : AppColors.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// The card's term rows: every plan the tier sells, in ladder order.
///
/// A row carries the term and its per-month price on the left and the total it
/// is charged on the right, so the card needs no headline price line, no
/// struck-through full price and no note — the ladder is legible from the
/// numbers themselves, and every one of them comes from `payment_plans.dart`.
class _TermSelector extends StatelessWidget {
  const _TermSelector({
    required this.tier,
    required this.selectedKey,
    required this.onSelected,
  });

  final SubscriptionTier tier;
  final String? selectedKey;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    // Every term the tier sells is a row, including a one-month plan where the
    // tier has one: the price line that used to stand for the month is gone, so
    // the month must be selectable like any other term.
    final plans = plansForTier(tier);
    final l = AppLocalizations.of(context);

    return Column(
      children: [
        for (var i = 0; i < plans.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          _TermRow(
            key: ValueKey('paywall-term-${tier.key}-${plans[i].key}'),
            label: _termLabel(l, plans[i]),
            perMonth: _perMonth(l, plans[i]),
            amount: l.payments_amountValue(
              AppDateUtils.formatDigits(
                plans[i].amount,
                l.localeName,
                grouping: plans[i].amount >= 1000,
              ),
            ),
            isSelected: selectedKey == plans[i].key,
            onTap: () => onSelected(plans[i].key),
          ),
        ],
      ],
    );
  }

  /// A plan's price per month, localized: its total split over its months.
  ///
  /// Rounded to the taka, so ৳2,500 a year reads ৳208 a month rather than a
  /// fraction. The total beside it stays the exact amount the server validates.
  String _perMonth(AppLocalizations l, SubscriptionPlan plan) {
    final perMonth = (plan.amount / plan.months).round();
    return l.payments_amountValue(
      AppDateUtils.formatDigits(
        perMonth,
        l.localeName,
        grouping: perMonth >= 1000,
      ),
    );
  }

  String _termLabel(AppLocalizations l, SubscriptionPlan plan) =>
      switch (plan.months) {
        1 => l.paywall_termMonthly,
        3 => l.paywall_termQuarterly,
        6 => l.paywall_termHalfYearly,
        _ => l.paywall_termAnnual,
      };
}

/// One term row: term and per-month price on the left, total and the round
/// chosen mark on the right.
class _TermRow extends StatelessWidget {
  const _TermRow({
    required this.label,
    required this.perMonth,
    required this.amount,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  final String label;

  /// The per-month equivalent, already localized (৳45).
  final String perMonth;

  /// The total the term is charged, already localized (৳540).
  final String amount;

  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final perMonthText = '$perMonth${l.paywall_perMonth}';
    return Semantics(
      button: true,
      selected: isSelected,
      label: '$label, $perMonthText, $amount',
      child: Material(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
          child: Container(
            constraints: const BoxConstraints(minHeight: 60),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
              border: Border.all(
                // The app's one "chosen" mark is the ink outline (the same 2px
                // used by the pressed card and the app's selected pills). Green
                // belongs to savings and success, not to a selection.
                color: isSelected ? AppColors.primary : AppColors.outlineVariant,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: AppTypography.titleMd.copyWith(
                          color: AppColors.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        perMonthText,
                        style: AppTypography.bodySm.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  amount,
                  style: AppTypography.titleMd.copyWith(
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                _SelectionDot(isSelected: isSelected),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The round mark on a term row: a hollow ring at rest, a filled ink circle with
/// a tick when the row is the card's chosen term.
class _SelectionDot extends StatelessWidget {
  const _SelectionDot({required this.isSelected});

  final bool isSelected;

  @override
  Widget build(BuildContext context) => Container(
    width: 20,
    height: 20,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: isSelected ? AppColors.primary : Colors.transparent,
      border: Border.all(
        color: isSelected ? AppColors.primary : AppColors.outlineVariant,
        width: 2,
      ),
    ),
    child: isSelected
        ? const Icon(Icons.check, size: 14, color: AppColors.onPrimary)
        : null,
  );
}

/// A small line above the cards naming the queued plan and its start.
class _ScheduledBanner extends StatelessWidget {
  const _ScheduledBanner({
    required this.label,
    required this.body,
    required this.tier,
    super.key,
  });

  final String label;
  final String body;
  final String tier;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.sm),
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
      border: Border.all(color: AppColors.outlineVariant),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.schedule_outlined,
          size: 18,
          color: AppColors.primary,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            '$tier · $label · $body',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Why the screen opened, and what is still free.
///
/// Two gates share the card's shape: the free 50 wall, and a lapsed allowance.
/// The second names the allowance of the tier in force rather than the free
/// wall, because telling a lapsed Starter they hold 50 cases would be a
/// different rule from the one the app enforces.
class _LimitCard extends ConsumerWidget {
  const _LimitCard({required this.lapsed});

  final bool lapsed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final limit = lapsed
        ? ref.watch(allowanceTierProvider).lapseAllowance
        : freeTierCaseLimit;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
      ),
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline,
                size: 20,
                color: AppColors.onErrorContainer,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  lapsed ? l.paywall_lapsedTitle : l.paywall_limitTitle,
                  style: AppTypography.titleMd.copyWith(
                    color: AppColors.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            (lapsed ? l.paywall_lapsedBody : l.paywall_limitBody)(
              AppDateUtils.formatDigits(
                limit,
                l.localeName,
                grouping: limit >= 1000,
              ),
            ),
            style: AppTypography.bodySm.copyWith(
              color: AppColors.onErrorContainer,
            ),
          ),
        ],
      ),
    );
  }
}
