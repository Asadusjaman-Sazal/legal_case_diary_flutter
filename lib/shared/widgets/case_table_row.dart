/// Reusable case row for the case-list screens' extended ("table") view.
///
/// This is the horizontal counterpart of [CaseCard]: the host screen supplies
/// exactly the same display values, so switching between the compact card view
/// and the extended view never loses a field. The row chrome follows the table
/// view in `mockup_html_screens/overdueDates/code.html` (`#tableView`): a white
/// row with a bordered Update column, a date/step column, the case number and
/// parties, and the contact actions. The mockup's row carries fewer fields than
/// the app's card, so the row additionally renders the court/judges line and the
/// note the card shows (user-approved full data parity).
library;

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/utils/date_utils.dart';
import 'case_card.dart';

/// A single case laid out as one horizontal row of the extended view.
class CaseTableRow extends StatelessWidget {
  /// Minimum content width of the extended view.
  ///
  /// The mockup scrolls the table horizontally (`min-w-[600px]`) instead of
  /// squeezing its columns, so the host wraps its body in [CaseTableBody] and
  /// this is the width that body is guaranteed.
  static const double minWidth = 600.0;

  /// Width of the leading serial cell. Only rendered when [serial] is set.
  static const double _serialColumnWidth = 32.0;

  /// Width of the Update action column.
  static const double _updateColumnWidth = 56.0;

  /// Width of each labelled detail column (date, step/result).
  static const double _detailColumnWidth = 104.0;

  /// Width of the trailing contact-action column.
  static const double _contactColumnWidth = 44.0;

  /// Ceiling for the on-behalf chip in the case block, so a long role name can
  /// never eat the line the case number lives on.
  static const double _statusLabelMaxWidth = 104.0;

  /// Size of the square icon buttons inside the row.
  static const double _iconButtonSize = 36.0;

  /// The case-list layout to render; drives the overdue accent, exactly as it
  /// does for [CaseCard].
  final CaseCardVariant variant;

  /// 1-based position of this case in the list the screen is currently showing.
  ///
  /// Rendered localized (Bengali digits under বাংলা). Null hides the cell — the
  /// grouped screens (Daily Cause List, Upcoming Cases, Overdue Dates) and the
  /// libraries do not use serial numbers.
  final int? serial;

  /// Case identifier shown as the primary data label.
  final String caseNumber;

  /// Party names or the case title shown beneath [caseNumber].
  final String title;

  /// Optional section, case type, or descriptive subtitle.
  final String? subtitle;

  /// Optional court name displayed beside the judges' name.
  final String? courtName;

  /// Optional role/status badge, such as Plaintiff or Accused.
  final String? statusLabel;

  /// Optional next-hearing date, shown in its own labelled column.
  final String? nextDate;

  /// Step shown in the second detail column.
  final String? step;

  /// AD/HCD result shown in the second detail column when [step] is absent.
  final String? result;

  /// Note shown as the last line of the case block.
  final String? note;

  /// Honorable judges' name, shown beside the court name for AD/HCD cases.
  final String? judgesName;

  /// Called by the phone action, when supplied.
  final VoidCallback? onPhone;

  /// Called by the message action, when supplied.
  final VoidCallback? onMessage;

  /// Called by the Update action, when supplied.
  final VoidCallback? onUpdate;

  /// Called when the whole row is tapped (opens the case detail screen).
  final VoidCallback? onTap;

  /// Whether the phone action is rendered.
  final bool showPhoneButton;

  /// Whether the message action is rendered.
  final bool showMessageButton;

  /// Whether the Update action is rendered.
  final bool showUpdateButton;

  /// Overrides the date label (e.g. "Previous Date" for overdue cases, or the
  /// Disposed screen's "Disposed:").
  final String? dateLabelOverride;

  /// Whether this specific case's date is in the past (overdue). Drives the red
  /// left strip and the red date text. The Overdue screen always sets this.
  final bool isOverdue;

  /// Creates an extended-view case row.
  const CaseTableRow({
    required this.caseNumber,
    required this.title,
    this.variant = CaseCardVariant.list,
    this.serial,
    this.subtitle,
    this.courtName,
    this.statusLabel,
    this.nextDate,
    this.step,
    this.result,
    this.note,
    this.judgesName,
    this.dateLabelOverride,
    this.isOverdue = false,
    this.onPhone,
    this.onMessage,
    this.onUpdate,
    this.onTap,
    this.showPhoneButton = true,
    this.showMessageButton = true,
    this.showUpdateButton = true,
    super.key,
  });

  /// Whether the red urgency strip is drawn for this row.
  bool get _showStrip => isOverdue || variant == CaseCardVariant.overdue;

  bool get _hasContacts => showPhoneButton || showMessageButton;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    final content = IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_showStrip)
            Container(
              key: const ValueKey('case-row-overdue-strip'),
              width: 4,
              color: AppColors.error,
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.gutter),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (serial != null) ...[
                    _SerialCell(serial: serial!, locale: l.localeName),
                    const _RowDivider(),
                  ],
                  if (showUpdateButton) ...[
                    _UpdateCell(l: l, onUpdate: onUpdate),
                    const _RowDivider(),
                  ],
                  if (nextDate != null)
                    _DetailCell(
                      label:
                          dateLabelOverride ??
                          (isOverdue
                              ? l.caseCard_previousDate
                              : l.caseCard_nextDate),
                      value: nextDate!,
                      isOverdue: isOverdue,
                    ),
                  if (step != null || result != null)
                    _DetailCell(
                      label: step != null
                          ? l.caseCard_lastStep
                          : l.addEditCaseSheet_result,
                      value: (step ?? result)!,
                    ),
                  Expanded(
                    child: _CaseBlock(
                      caseNumber: caseNumber,
                      title: title,
                      subtitle: subtitle,
                      courtName: courtName,
                      judgesName: judgesName,
                      statusLabel: statusLabel,
                      note: note,
                      isOverdue: isOverdue,
                      l: l,
                    ),
                  ),
                  if (_hasContacts) ...[
                    const _RowDivider(),
                    _ContactCell(
                      l: l,
                      onPhone: onPhone,
                      onMessage: onMessage,
                      showPhoneButton: showPhoneButton,
                      showMessageButton: showMessageButton,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );

    // Same shape as [CaseCard]: the row follows the app-wide card radius token
    // rather than the mockup's `rounded-r-xl`, and the overdue strip squares the
    // left corners it is drawn against.
    final radius = BorderRadius.only(
      topLeft: Radius.circular(_showStrip ? 0 : AppSpacing.cardRadius),
      bottomLeft: Radius.circular(_showStrip ? 0 : AppSpacing.cardRadius),
      topRight: const Radius.circular(AppSpacing.cardRadius),
      bottomRight: const Radius.circular(AppSpacing.cardRadius),
    );

    if (onTap == null) {
      return Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          border: Border.all(color: AppColors.cardBorder),
          borderRadius: radius,
        ),
        child: content,
      );
    }

    return Material(
      color: AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: content),
    );
  }
}

/// Wraps an extended-view body so its fixed columns always fit.
///
/// The mockup gives the table a 600 px minimum width and lets it scroll
/// sideways rather than squeeze its columns; on a phone that is the only way a
/// row stays readable, so the body is laid out at the wider of the viewport and
/// [CaseTableRow.minWidth] inside a horizontal scroll view.
class CaseTableBody extends StatelessWidget {
  /// The vertically scrolling body (list, groups and rows) to wrap.
  final Widget child;

  /// Creates the extended-view body wrapper.
  const CaseTableBody({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth > CaseTableRow.minWidth
            ? constraints.maxWidth
            : CaseTableRow.minWidth;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(width: width, child: child),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Cells
// ---------------------------------------------------------------------------

/// The 1-based position of the case in the list, in the active language's
/// digits.
class _SerialCell extends StatelessWidget {
  final int serial;
  final String locale;

  const _SerialCell({required this.serial, required this.locale});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: CaseTableRow._serialColumnWidth,
      child: Center(
        child: Text(
          AppDateUtils.formatDigits(serial, locale),
          key: const ValueKey('case-row-serial'),
          style: AppTypography.labelLg.copyWith(
            color: AppColors.outline,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// The bordered Update (edit) column the mockup gives every table row.
class _UpdateCell extends StatelessWidget {
  final AppLocalizations l;
  final VoidCallback? onUpdate;

  const _UpdateCell({required this.l, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: CaseTableRow._updateColumnWidth,
      child: Center(
        child: IconButton(
          key: const ValueKey('case-row-update'),
          tooltip: l.allCasesScreen_update,
          onPressed: onUpdate,
          style: IconButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
          ),
          constraints: const BoxConstraints.tightFor(width: 40, height: 40),
          icon: const Icon(Icons.edit_outlined, size: 20),
        ),
      ),
    );
  }
}

/// A labelled detail column, the row's counterpart of the card's detail block.
class _DetailCell extends StatelessWidget {
  final String label;
  final String value;
  final bool isOverdue;

  const _DetailCell({
    required this.label,
    required this.value,
    this.isOverdue = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isOverdue ? AppColors.error : AppColors.onSurface;
    return SizedBox(
      width: CaseTableRow._detailColumnWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.labelMd.copyWith(color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: AppTypography.labelLg.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// The case number, parties, court, judges and note — everything the card's
/// heading and body lines carry.
class _CaseBlock extends StatelessWidget {
  final String caseNumber;
  final String title;
  final String? subtitle;
  final String? courtName;
  final String? judgesName;
  final String? statusLabel;
  final String? note;
  final bool isOverdue;
  final AppLocalizations l;

  const _CaseBlock({
    required this.caseNumber,
    required this.title,
    required this.subtitle,
    required this.courtName,
    required this.judgesName,
    required this.statusLabel,
    required this.note,
    required this.isOverdue,
    required this.l,
  });

  @override
  Widget build(BuildContext context) {
    final trimmedNote = note?.trim();
    final trimmedCourt = courtName?.trim();
    final trimmedJudges = judgesName?.trim();
    final courtLine = [
      if (trimmedCourt != null && trimmedCourt.isNotEmpty) trimmedCourt,
      if (trimmedJudges != null && trimmedJudges.isNotEmpty) trimmedJudges,
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                caseNumber,
                style: AppTypography.caseNumber.copyWith(
                  color: isOverdue ? AppColors.onSurface : AppColors.secondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (statusLabel != null) ...[
              const SizedBox(width: AppSpacing.sm),
              // Width-capped rather than flexible: the on-behalf label can be a
              // user's own long role name, and the case number is the primary
              // label, so the chip gives way (ellipsising) instead of pushing
              // the number out or overflowing the row on a narrow screen.
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: CaseTableRow._statusLabelMaxWidth,
                ),
                child: Container(
                  key: const ValueKey('case-row-status-label'),
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(title, style: AppTypography.titleMd, maxLines: 1),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(subtitle!, style: AppTypography.bodySm, maxLines: 1),
        ],
        if (courtLine.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(courtLine, style: AppTypography.bodySm, maxLines: 1),
        ],
        if (trimmedNote != null && trimmedNote.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${l.addEditCaseSheet_note}: $trimmedNote',
            key: const ValueKey('case-row-note'),
            style: AppTypography.bodySm,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}

/// The phone and message actions, stacked in their own trailing column.
class _ContactCell extends StatelessWidget {
  final AppLocalizations l;
  final VoidCallback? onPhone;
  final VoidCallback? onMessage;
  final bool showPhoneButton;
  final bool showMessageButton;

  const _ContactCell({
    required this.l,
    required this.onPhone,
    required this.onMessage,
    required this.showPhoneButton,
    required this.showMessageButton,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: CaseTableRow._contactColumnWidth,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (showPhoneButton)
            _ContactButton(
              tooltip: l.allCasesScreen_phone,
              icon: Icons.call_outlined,
              onPressed: onPhone,
            ),
          if (showPhoneButton && showMessageButton)
            const SizedBox(height: AppSpacing.sm),
          if (showMessageButton)
            _ContactButton(
              tooltip: l.allCasesScreen_message,
              icon: Icons.chat_outlined,
              onPressed: onMessage,
            ),
        ],
      ),
    );
  }
}

class _ContactButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  const _ContactButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
      ),
      constraints: const BoxConstraints.tightFor(
        width: CaseTableRow._iconButtonSize,
        height: CaseTableRow._iconButtonSize,
      ),
      padding: EdgeInsets.zero,
      icon: Icon(icon, size: 18),
    );
  }
}

/// The vertical rule between two row columns.
///
/// The rules are the table's structure, but three of them at [AppSpacing.md]
/// each would cost more width than the case block can spare on the mockup's
/// 600 px minimum, so they sit on the tighter gutter.
class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: VerticalDivider(width: 1, color: AppColors.outlineVariant),
    );
  }
}
