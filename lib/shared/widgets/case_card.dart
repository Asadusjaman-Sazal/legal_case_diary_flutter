/// Reusable case summary card for the case-list screens.
///
/// The host screen supplies the display values so this widget stays independent
/// of repositories and can be reused by every case-list variant.
library;

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';
import '../../core/l10n/generated/app_localizations.dart';

/// Layout variants used by the case-list screens.
enum CaseCardVariant {
  /// Compact list layout used by All/Active/Upcoming cases.
  list,

  /// Daily Cause List layout with Step and Note rows.
  dailyCauseList,

  /// Overdue layout with the required red left border strip.
  overdue,

  /// Disposed layout with a disposed date line.
  disposed,
}

/// A configurable case card shared by all case-list screens.
class CaseCard extends StatelessWidget {
  /// The case-list layout to render.
  final CaseCardVariant variant;

  /// Case identifier shown as the primary data label.
  final String caseNumber;

  /// Party names or the case title shown beneath [caseNumber].
  final String title;

  /// Optional section, case type, or descriptive subtitle.
  final String? subtitle;

  /// Optional court name displayed in the card metadata.
  final String? courtName;

  /// Optional role/status badge, such as Plaintiff or Accused.
  final String? statusLabel;

  /// Optional next-hearing date shown by list and overdue variants.
  final String? nextDate;

  /// Optional disposed date shown by the disposed variant.
  final String? disposedDate;

  /// Step shown in the Daily Cause List and list metadata.
  final String? step;

  /// Note shown beside the step in the Daily Cause List layout.
  final String? note;

  /// Called by the phone action, when supplied.
  final VoidCallback? onPhone;

  /// Called by the message action, when supplied.
  final VoidCallback? onMessage;

  /// Called by the Update action, when supplied.
  final VoidCallback? onUpdate;

  /// Whether the phone action is rendered.
  final bool showPhoneButton;

  /// Whether the message action is rendered.
  final bool showMessageButton;

  /// Whether the Update action is rendered.
  final bool showUpdateButton;

  /// Creates a case card.
  const CaseCard({
    required this.caseNumber,
    required this.title,
    this.variant = CaseCardVariant.list,
    this.subtitle,
    this.courtName,
    this.statusLabel,
    this.nextDate,
    this.disposedDate,
    this.step,
    this.note,
    this.onPhone,
    this.onMessage,
    this.onUpdate,
    this.showPhoneButton = true,
    this.showMessageButton = true,
    this.showUpdateButton = true,
    super.key,
  });

  bool get _isOverdue => variant == CaseCardVariant.overdue;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isOverdue)
              Container(
                key: const ValueKey('case-card-overdue-strip'),
                width: 4,
                color: AppColors.error,
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CaseHeading(
                      caseNumber: caseNumber,
                      title: title,
                      subtitle: subtitle,
                      statusLabel: statusLabel,
                      isOverdue: _isOverdue,
                    ),
                    if (courtName != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(courtName!, style: AppTypography.bodySm),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    if (variant == CaseCardVariant.dailyCauseList)
                      _DailyCauseDetails(l: l, step: step, note: note)
                    else
                      _ListDetails(
                        l: l,
                        variant: variant,
                        nextDate: nextDate,
                        disposedDate: disposedDate,
                        step: step,
                      ),
                    if (_hasActions) ...[
                      const SizedBox(height: AppSpacing.md),
                      _CaseActions(
                        l: l,
                        onPhone: onPhone,
                        onMessage: onMessage,
                        onUpdate: onUpdate,
                        showPhoneButton: showPhoneButton,
                        showMessageButton: showMessageButton,
                        showUpdateButton: showUpdateButton,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _hasActions =>
      showPhoneButton || showMessageButton || showUpdateButton;
}

class _CaseHeading extends StatelessWidget {
  final String caseNumber;
  final String title;
  final String? subtitle;
  final String? statusLabel;
  final bool isOverdue;

  const _CaseHeading({
    required this.caseNumber,
    required this.title,
    required this.subtitle,
    required this.statusLabel,
    required this.isOverdue,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                caseNumber,
                style: AppTypography.caseNumber.copyWith(
                  color: isOverdue ? AppColors.error : AppColors.secondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(title, style: AppTypography.titleMd),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(subtitle!, style: AppTypography.bodySm),
              ],
            ],
          ),
        ),
        if (statusLabel != null) ...[
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Text(
                statusLabel!,
                style: AppTypography.labelMd,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _DailyCauseDetails extends StatelessWidget {
  final AppLocalizations l;
  final String? step;
  final String? note;

  const _DailyCauseDetails({
    required this.l,
    required this.step,
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    return _DetailsRow(
      children: [
        _DetailValue(label: l.addEditCaseSheet_step, value: step),
        _DetailValue(label: l.addEditCaseSheet_note, value: note),
      ],
    );
  }
}

class _ListDetails extends StatelessWidget {
  final AppLocalizations l;
  final CaseCardVariant variant;
  final String? nextDate;
  final String? disposedDate;
  final String? step;

  const _ListDetails({
    required this.l,
    required this.variant,
    required this.nextDate,
    required this.disposedDate,
    required this.step,
  });

  @override
  Widget build(BuildContext context) {
    final details = <Widget>[];
    if (variant == CaseCardVariant.disposed && disposedDate != null) {
      details.add(
        _DetailValue(
          label: l.disposedCasesScreen_disposed,
          value: disposedDate,
        ),
      );
    } else if (nextDate != null) {
      details.add(
        _DetailValue(label: l.allCasesScreen_nextDate, value: nextDate),
      );
    }
    if (step != null) {
      details.add(_DetailValue(label: l.allCasesScreen_lastStep, value: step));
    }

    if (details.isEmpty) return const SizedBox.shrink();
    return _DetailsRow(children: details);
  }
}

class _DetailsRow extends StatelessWidget {
  final List<Widget> children;

  const _DetailsRow({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: const BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(color: AppColors.cardBorder),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: SizedBox(
                  height: 32,
                  child: VerticalDivider(color: AppColors.outlineVariant),
                ),
              ),
            Expanded(child: children[index]),
          ],
        ],
      ),
    );
  }
}

class _DetailValue extends StatelessWidget {
  final String label;
  final String? value;

  const _DetailValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.labelMd),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value ?? '—',
          style: AppTypography.labelLg.copyWith(
            color: AppColors.onSurface,
            fontWeight: FontWeight.w700,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _CaseActions extends StatelessWidget {
  final AppLocalizations l;
  final VoidCallback? onPhone;
  final VoidCallback? onMessage;
  final VoidCallback? onUpdate;
  final bool showPhoneButton;
  final bool showMessageButton;
  final bool showUpdateButton;

  const _CaseActions({
    required this.l,
    required this.onPhone,
    required this.onMessage,
    required this.onUpdate,
    required this.showPhoneButton,
    required this.showMessageButton,
    required this.showUpdateButton,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (showPhoneButton)
          IconButton(
            tooltip: l.allCasesScreen_phone,
            onPressed: onPhone,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surfaceContainerLow,
              foregroundColor: AppColors.secondary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
            ),
            icon: const Icon(Icons.call_outlined),
          ),
        if (showMessageButton) ...[
          const SizedBox(width: AppSpacing.sm),
          IconButton(
            tooltip: l.allCasesScreen_message,
            onPressed: onMessage,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surfaceContainerLow,
              foregroundColor: AppColors.success,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
            ),
            icon: const Icon(Icons.chat_outlined),
          ),
        ],
        const Spacer(),
        if (showUpdateButton)
          FilledButton.icon(
            onPressed: onUpdate,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: Text(l.allCasesScreen_update),
          ),
      ],
    );
  }
}
