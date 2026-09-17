/// Backup & Restore screen: manual backup/restore actions, automatic-backup
/// schedule, and the last-backup status.
///
/// Body mirrors `mockup_html_screens/settings_backupRestore/code.html`: three
/// primary action buttons inside one card, the encrypted-backup note, a
/// radio-list schedule card, and the status card.
/// Part A renders the offline shell (Task 12 Phase 2); the export/import engine
/// is wired in Task 15.
library;

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import 'settings_menu_card.dart';
import 'settings_sub_page_modal.dart';

/// White bordered card shell shared by the mockup's three sections.
BoxDecoration _cardDecoration({
  Color color = AppColors.surfaceContainerLowest,
}) => BoxDecoration(
  color: color,
  // Radius matches the mockup's `rounded-xl`.
  borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
  border: Border.all(color: AppColors.outlineVariant),
);

/// Part A: the backup engine lands in Task 15, so the actions only say so.
void _backupNotice(BuildContext context, AppLocalizations l) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(l.settingsBackupRestore_enginePending)),
  );
}

/// One selectable automatic-backup interval.
class _BackupInterval {
  /// Days between automatic backups; 0 means "Off".
  final int days;
  final IconData icon;
  final String label;

  const _BackupInterval({
    required this.days,
    required this.icon,
    required this.label,
  });
}

/// Automatic-backup options in mockup order.
List<_BackupInterval> _intervals(AppLocalizations l) => [
  _BackupInterval(
    days: 0,
    icon: Icons.block,
    label: l.settingsBackupRestore_scheduleOff,
  ),
  _BackupInterval(
    days: 1,
    icon: Icons.today,
    label: l.settingsBackupRestore_scheduleEveryday,
  ),
  _BackupInterval(
    days: 3,
    icon: Icons.calendar_view_week,
    label: l.settingsBackupRestore_scheduleEvery3Days,
  ),
  _BackupInterval(
    days: 7,
    icon: Icons.event_repeat,
    label: l.settingsBackupRestore_scheduleEvery7Days,
  ),
  _BackupInterval(
    days: 30,
    icon: Icons.calendar_month,
    label: l.settingsBackupRestore_scheduleEveryMonth,
  ),
];

/// Backup & Restore screen (Part A offline shell) per `settings_backupRestore`.
class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  /// Selected automatic-backup interval in days; the mockup has "Everyday"
  /// checked. Part A keeps the choice in memory only — Task 15 owns the
  /// per-user schedule and its persistence.
  int _intervalDays = 1;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SettingsSubPageModal(
      title: l.settingsBackupRestore_title,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.edgeMargin,
          AppSpacing.md,
          AppSpacing.edgeMargin,
          AppSpacing.xl,
        ),
        children: [
          // Section 1: manual backup / restore actions.
          _SectionHeader(l.settingsBackupRestore_sectionBackup),
          const _ActionCard(),
          const _BackupNote(),
          const SizedBox(height: AppSpacing.xl),
          // Section 2: automatic-backup schedule.
          _SectionHeader(l.settingsBackupRestore_sectionAutomaticBackup),
          _ScheduleCard(
            selectedDays: _intervalDays,
            onChanged: (days) => setState(() => _intervalDays = days),
          ),
          const SizedBox(height: AppSpacing.xl),
          // Section 3: last successful backup.
          _SectionHeader(l.settingsBackupRestore_sectionStatus),
          const _StatusCard(),
        ],
      ),
    );
  }
}

/// Uppercase section heading (mockup `label-lg` + `tracking-wider`).
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
      // Section headings are upper-cased for style, so the translations
      // stay in normal sentence case.
      text.toUpperCase(),
      style: AppTypography.labelLg.copyWith(
        color: AppColors.onSurfaceVariant,
        letterSpacing: 0.7, // tracking-wider — 0.05em at 14 px.
      ),
    ),
  );
}

/// The three manual actions stacked in one card, per the mockup.
class _ActionCard extends StatelessWidget {
  const _ActionCard();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          _ActionButton(
            icon: Icons.cloud_upload,
            label: l.settingsBackupRestore_backupLocal,
          ),
          const SizedBox(height: AppSpacing.md),
          _ActionButton(
            icon: Icons.add_to_drive,
            label: l.settingsBackupRestore_backupDrive,
          ),
          // The mockup wraps Restore in an extra `pt-sm`, so it sits one
          // step further down than the other two.
          const SizedBox(height: AppSpacing.lg),
          _ActionButton(
            icon: Icons.settings_backup_restore,
            label: l.settingsBackupRestore_restore,
          ),
        ],
      ),
    );
  }
}

/// One full-width primary action button, sized by [settingsPrimaryButtonHeight]
/// so every Settings sub-menu CTA is the same height.
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ActionButton({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: settingsPrimaryButtonHeight,
    child: FilledButton.icon(
      onPressed: () => _backupNotice(context, AppLocalizations.of(context)),
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        textStyle: AppTypography.labelLg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
        ),
      ),
    ),
  );
}

/// The mockup's note under the action card.
class _BackupNote extends StatelessWidget {
  const _BackupNote();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.xs,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.settingsBackupRestore_encryptionNote,
            style: AppTypography.bodySm,
          ),
          Text(
            l.settingsBackupRestore_offlineNote,
            style: AppTypography.bodySm,
          ),
        ],
      ),
    );
  }
}

/// Automatic-backup schedule: one radio row per interval, in a white card.
class _ScheduleCard extends StatelessWidget {
  /// Currently selected interval in days.
  final int selectedDays;

  /// Called with the newly selected interval.
  final ValueChanged<int> onChanged;

  const _ScheduleCard({required this.selectedDays, required this.onChanged});

  @override
  // A shaped Material (not a decorated Container) so each row's ink splash and
  // background paint on it — a DecoratedBox in between trips a ListTile assert.
  Widget build(BuildContext context) {
    final intervals = _intervals(AppLocalizations.of(context));
    return Material(
      color: AppColors.surfaceContainerLowest,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
        side: BorderSide(color: AppColors.outlineVariant),
      ),
      child: RadioGroup<int>(
        groupValue: selectedDays,
        onChanged: (days) {
          if (days != null) onChanged(days);
        },
        child: Column(
          children: [
            // Mockup `data-strip` rows: divided, last one border-less.
            for (var i = 0; i < intervals.length; i++) ...[
              if (i > 0)
                const Divider(height: 1, color: AppColors.outlineVariant),
              _IntervalRow(interval: intervals[i]),
            ],
          ],
        ),
      ),
    );
  }
}

/// One schedule row: interval icon + label on the left, radio on the right.
/// The whole row selects, matching the mockup's `<label>` wrapper.
class _IntervalRow extends StatelessWidget {
  final _BackupInterval interval;

  const _IntervalRow({required this.interval});

  @override
  Widget build(BuildContext context) => RadioListTile<int>(
    value: interval.days,
    controlAffinity: ListTileControlAffinity.trailing,
    activeColor: AppColors.secondary,
    secondary: Icon(interval.icon, color: AppColors.onSurfaceVariant),
    title: Text(interval.label, style: AppTypography.bodyMd),
    contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
    horizontalTitleGap: AppSpacing.md,
    minTileHeight: 56,
  );
}

/// Last successful backup card; Part A shows the mockup's placeholder value.
class _StatusCard extends StatelessWidget {
  const _StatusCard();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      decoration: _cardDecoration(color: AppColors.surfaceBright),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.secondary.withValues(alpha: 0.1),
            ),
            child: const Center(
              child: Icon(Icons.verified, color: AppColors.secondary),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.settingsBackupRestore_lastSuccessfulBackup,
                  style: AppTypography.titleMd.copyWith(
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l.settingsBackupRestore_lastBackupPlaceholder,
                  style: AppTypography.bodyMd.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
