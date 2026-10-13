/// Checkout screen — the MFS transfer instructions and the payment details form.
///
/// Task 21 Phase 1. There is no mockup for this screen (the task file marks it
/// `[Design-deferred]`), so the layout was proposed in the approved plan and
/// follows the Justice Ledger tokens the paywall already uses: surface cards on
/// the background, hairline outlines, the shared spacing scale.
///
/// What lives here:
///
///   * the selected plan and its **exact** amount — the amount shown in the
///     transfer instructions is the amount submitted with the payment, taken
///     from the one shared [paymentPlanAmount] rule;
///   * the receiving numbers, resolved through [paymentsConfigurationProvider]
///     (remote configuration first, validated build defaults otherwise) and
///     copyable to the clipboard — never hardcoded in this widget;
///   * the payment details form: method, sender phone and TrxID;
///   * a Submit action wired to `payment_viewmodel.dart` (Phase 2): it validates
///     the form, applies the best-effort local limit, submits through the
///     repository, and only on a confirmed success clears the draft.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/date_utils.dart';
import '../data/payment_local_store.dart';
import '../data/payment_plans.dart';
import '../data/payment_repository.dart';
import '../data/payments_configuration_service.dart';
import 'payment_plan_labels.dart';
import 'payment_viewmodel.dart';

/// Checkout: pay one plan by MFS transfer and report the transaction.
class CheckoutScreen extends ConsumerStatefulWidget {
  /// The plan key from the route (`monthly`/`annual`), or null.
  final String? planKey;

  /// Creates the checkout.
  const CheckoutScreen({this.planKey, super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _trx = TextEditingController();

  /// The selected MFS provider, or null before the user picks one.
  String? _method;

  @override
  void initState() {
    super.initState();
    // Restore the saved draft, then keep it current on every keystroke.
    final draft = ref.read(paymentDraftProvider);
    _phone.text = draft.phone;
    _trx.text = draft.trx;
    _method = draft.method;
    _phone.addListener(_persistDraft);
    _trx.addListener(_persistDraft);
  }

  @override
  void dispose() {
    _phone.removeListener(_persistDraft);
    _trx.removeListener(_persistDraft);
    _phone.dispose();
    _trx.dispose();
    super.dispose();
  }

  /// The effective plan, defaulting to monthly for a bare/unknown link.
  String get _planKey =>
      paymentPlanAmount(widget.planKey) == null ? paymentPlanMonthly : widget.planKey!;

  /// Saves the current form as the draft. Cheap enough for every keystroke.
  void _persistDraft() {
    ref.read(paymentDraftProvider.notifier).save(
      PaymentDraft(
        planKey: _planKey,
        method: _method,
        phone: _phone.text,
        trx: _trx.text,
      ),
    );
  }

  void _copyNumber(String number, AppLocalizations l) {
    Clipboard.setData(ClipboardData(text: number));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l.payments_copied)));
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// The message for a refused submission.
  String _failureMessage(AppLocalizations l, PaymentState? state) {
    if (state?.signInRequired ?? false) {
      return l.sharedMessages_signInRequired;
    }
    return switch (state?.failure) {
      PaymentSubmitFailure.limitReached => l.payments_limitReached,
      PaymentSubmitFailure.duplicateTransaction => l.payments_duplicateTrx,
      _ => l.payments_submitFailed,
    };
  }

  /// Validates the form, applies the best-effort local limit, then submits.
  Future<void> _onSubmit() async {
    final l = AppLocalizations.of(context);
    final methods =
        ref.read(paymentsConfigurationProvider).value?.orderedMethods ??
        const <PaymentMethodConfig>[];
    final method = _method != null && methods.any((m) => m.provider == _method)
        ? _method
        : (methods.isEmpty ? null : methods.first.provider);

    if (method == null) {
      _showMessage(l.payments_numberUnavailable);
      return;
    }
    if (!isValidBdMobileNumber(_phone.text)) {
      _showMessage(l.payments_errorPhone);
      return;
    }
    if (_trx.text.trim().isEmpty) {
      _showMessage(l.payments_errorTrx);
      return;
    }
    // Best-effort UX check only; the server's trigger is the real gate.
    if (isLocallyRateLimited(
      ref.read(paymentSubmissionLogProvider),
      DateTime.now(),
    )) {
      _showMessage(l.payments_limitReached);
      return;
    }

    final ok = await ref
        .read(paymentViewModelProvider.notifier)
        .submit(
          planKey: _planKey,
          provider: method,
          phone: _phone.text.trim(),
          trx: _trx.text.trim(),
        );
    if (!mounted) return;
    if (ok) {
      // Keep the confirmation, then take the user to their purchase ledger with
      // the Payment History section in view, so the pending row they just
      // created is shown rather than left behind in Settings.
      _showMessage(l.payments_submitSuccess);
      GoRouter.maybeOf(context)?.push(
        AppRoutes.subscriptionDetailsFromCheckout,
      );
    } else {
      _showMessage(
        _failureMessage(l, ref.read(paymentViewModelProvider).value),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final config = ref.watch(paymentsConfigurationProvider);
    final amount = paymentPlanAmount(_planKey) ?? paymentMonthlyPrice;
    final isSubmitting = ref.watch(
      paymentViewModelProvider.select((s) => s.value?.isSubmitting ?? false),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l.payments_checkoutTitle, style: AppTypography.titleLg),
        backgroundColor: AppColors.surfaceContainerLowest,
      ),
      body: config.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _Unavailable(l: l),
        data: (configuration) {
          if (!configuration.hasAnyMethod) return _Unavailable(l: l);
          final methods = configuration.orderedMethods;
          final selected = _method != null &&
                  methods.any((m) => m.provider == _method)
              ? _method!
              : methods.first.provider;
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.edgeMargin,
              AppSpacing.md,
              AppSpacing.edgeMargin,
              AppSpacing.xl,
            ),
            children: [
              _PlanSummaryCard(l: l, planKey: _planKey, amount: amount),
              const SizedBox(height: AppSpacing.xl),
              _SectionHeader(l.payments_transferTitle),
              _TransferCard(
                l: l,
                amount: amount,
                methods: methods,
                onCopy: (number) => _copyNumber(number, l),
              ),
              const SizedBox(height: AppSpacing.xl),
              _SectionHeader(l.payments_formTitle),
              _FormCard(
                l: l,
                methods: methods,
                selected: selected,
                onMethodChanged: (value) => setState(() => _method = value),
                phone: _phone,
                trx: _trx,
                isSubmitting: isSubmitting,
                onSubmit: _onSubmit,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The plan and its exact amount, before anything is sent.
class _PlanSummaryCard extends StatelessWidget {
  final AppLocalizations l;
  final String planKey;
  final int amount;

  const _PlanSummaryCard({
    required this.l,
    required this.planKey,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) => _Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.payments_planSummaryTitle, style: AppTypography.labelLg.copyWith(
          color: AppColors.onSurfaceVariant,
        )),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Expanded(
              child: Text(
                paymentPlanLabel(l, planKey),
                style: AppTypography.titleMd,
              ),
            ),
            Text(
              l.payments_amountValue(
                AppDateUtils.formatDigits(amount, l.localeName),
              ),
              style: AppTypography.titleMd.copyWith(color: AppColors.primary),
            ),
          ],
        ),
      ],
    ),
  );
}

/// The transfer instructions: the exact amount and each receiving number.
class _TransferCard extends StatelessWidget {
  final AppLocalizations l;
  final int amount;
  final List<PaymentMethodConfig> methods;
  final void Function(String number) onCopy;

  const _TransferCard({
    required this.l,
    required this.amount,
    required this.methods,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) => _Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.payments_transferBody(
            AppDateUtils.formatDigits(amount, l.localeName),
          ),
          style: AppTypography.bodyMd,
        ),
        const SizedBox(height: AppSpacing.md),
        for (var i = 0; i < methods.length; i++) ...[
          if (i > 0) const Divider(height: AppSpacing.lg, color: AppColors.outlineVariant),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _methodLabel(l, methods[i].provider),
                      style: AppTypography.titleMd,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    // Shown exactly as configured — a receiving number is
                    // dialled and copied, so it is never digit-localized.
                    Text(
                      methods[i].receivingNumber,
                      style: AppTypography.bodyMd.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => onCopy(methods[i].receivingNumber),
                icon: const Icon(Icons.copy, color: AppColors.primary),
                tooltip: l.payments_copy,
              ),
            ],
          ),
        ],
      ],
    ),
  );
}

/// The payment-details form: method, sender phone and TrxID.
class _FormCard extends StatelessWidget {
  final AppLocalizations l;
  final List<PaymentMethodConfig> methods;
  final String selected;
  final ValueChanged<String?> onMethodChanged;
  final TextEditingController phone;
  final TextEditingController trx;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  const _FormCard({
    required this.l,
    required this.methods,
    required this.selected,
    required this.onMethodChanged,
    required this.phone,
    required this.trx,
    required this.isSubmitting,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) => _Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.payments_methodLabel, style: AppTypography.labelLg),
        const SizedBox(height: AppSpacing.xs),
        DropdownButtonFormField<String>(
          key: const ValueKey('checkout-method'),
          initialValue: selected,
          decoration: _fieldDecoration,
          items: [
            for (final method in methods)
              DropdownMenuItem<String>(
                value: method.provider,
                child: Text(_methodLabel(l, method.provider)),
              ),
          ],
          onChanged: onMethodChanged,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(l.payments_phoneLabel, style: AppTypography.labelLg),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          key: const ValueKey('checkout-phone'),
          controller: phone,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: _fieldDecoration.copyWith(
            hintText: l.payments_phoneHint,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(l.payments_trxLabel, style: AppTypography.labelLg),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          key: const ValueKey('checkout-trx'),
          controller: trx,
          textCapitalization: TextCapitalization.characters,
          decoration: _fieldDecoration.copyWith(
            hintText: l.payments_trxHint,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          key: const ValueKey('checkout-submit'),
          onPressed: isSubmitting ? null : onSubmit,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            // The app's primary action height (the paywall's Subscribe), so the
            // checkout's one action matches the rest of the app rather than the
            // platform's smaller default.
            textStyle: AppTypography.titleMd,
            minimumSize: const Size.fromHeight(52),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
            ),
          ),
          child: Text(l.payments_submit),
        ),
      ],
    ),
  );
}

/// Shown when no receiving number can be resolved at all.
class _Unavailable extends StatelessWidget {
  final AppLocalizations l;

  const _Unavailable({required this.l});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Text(
        l.payments_numberUnavailable,
        textAlign: TextAlign.center,
        style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
      ),
    ),
  );
}

/// The shared surface card used by every block on this screen.
class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
      border: Border.all(color: AppColors.outlineVariant),
    ),
    padding: const EdgeInsets.all(AppSpacing.cardPadding),
    child: child,
  );
}

/// The shared section heading, matching the paywall's.
class _SectionHeader extends StatelessWidget {
  final String text;

  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(
      left: AppSpacing.xs,
      right: AppSpacing.xs,
      bottom: AppSpacing.md,
    ),
    child: Text(
      text,
      style: AppTypography.labelLg.copyWith(
        color: AppColors.onSurfaceVariant,
        letterSpacing: 0.7,
      ),
    ),
  );
}

/// The localized name of one MFS provider.
String _methodLabel(AppLocalizations l, String provider) => switch (provider) {
  'bkash' => l.payments_methodBkash,
  'nagad' => l.payments_methodNagad,
  'rocket' => l.payments_methodRocket,
  _ => provider,
};

/// The shared input decoration for the form fields.
InputDecoration get _fieldDecoration => InputDecoration(
  filled: true,
  fillColor: AppColors.surface,
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppSpacing.sm),
    borderSide: const BorderSide(color: AppColors.outlineVariant),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppSpacing.sm),
    borderSide: const BorderSide(color: AppColors.outlineVariant),
  ),
  contentPadding: const EdgeInsets.symmetric(
    horizontal: AppSpacing.md,
    vertical: AppSpacing.sm,
  ),
);
