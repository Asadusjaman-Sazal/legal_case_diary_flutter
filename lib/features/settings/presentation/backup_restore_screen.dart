/// Backup & Restore screen: manual backup/restore actions, automatic-backup
/// schedule, and the last-backup status (Task 15 Phase 4).
///
/// Body mirrors `mockup_html_screens/settings_backupRestore/code.html`: three
/// primary action buttons inside one card, the encrypted-backup note, a
/// radio-list schedule card, and the status card.
///
/// Wired to the Task 15 engine: **Backup to Local Storage** asks for a
/// passphrase, exports, and hands the encrypted file to the platform's
/// "Save to…" dialog; **Backup to Google Drive** makes that same local backup
/// and then offers the platform share sheet, which is where Google Drive is a
/// target — the app stays offline, so it never uploads anything itself;
/// **Restore from backup** picks a file, decrypts and validates it, asks before
/// replacing local data, imports in one transaction and reloads the app.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backup/backup_restore.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/constants/app_version.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/providers/print_providers.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/services/app_share_service.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/providers/database_provider.dart';
import '../data/backup_file_gateway.dart';
import '../data/backup_metadata_store.dart';
import '../data/backup_repository.dart';
import 'backup_dialogs.dart';
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

/// Backup & Restore screen per `settings_backupRestore`.
class BackupRestoreScreen extends ConsumerStatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  ConsumerState<BackupRestoreScreen> createState() =>
      _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends ConsumerState<BackupRestoreScreen> {
  /// Whether an export or a restore is running, so the actions cannot be
  /// started twice from a double tap.
  bool _busy = false;

  /// Runs the export every backup action shares.
  ///
  /// [sink] is the only difference between the two backup buttons: the platform
  /// gateway for a local backup, or a [ShareableBackupSink] when the flow goes
  /// on to the share sheet. A dismissed save dialog writes nothing and records
  /// nothing, because the archive is only recorded once the sink reported
  /// success.
  ///
  /// Returns the export receipt, or null when nothing was written — a
  /// cancelled dialog or a failure that has already been reported — so the
  /// caller stops instead of offering the next step for a file that is not
  /// there.
  Future<BackupExportResult?> _exportBackup(BackupArchiveSink sink) async {
    final l = AppLocalizations.of(context);
    final secret = await showBackupPassphraseDialog(context);
    if (secret == null || !mounted) return null;

    setState(() => _busy = true);
    try {
      final repository = await ref.read(backupRepositoryProvider.future);
      // The progress window needs a context that is still in the tree, and the
      // export below it can take a second (the key derivation is deliberately
      // slow), so the user sees why nothing responded yet.
      if (!mounted) return null;
      final result = await runWithBackupProgress(
        context,
        l.settingsBackupRestore_backupProgress,
        () => repository.exportSnapshot(
          sink: sink,
          appVersion: appVersion,
          recoverySecret: secret,
          kdfIterations: ref.read(backupKdfIterationsProvider),
        ),
      );
      await ref
          .read(backupMetadataProvider.notifier)
          .recordSuccess(at: result.envelope.exportedAt, path: result.path);
      return result;
    } on BackupSaveCancelledException {
      // The user closed the save dialog: nothing was written, nothing to say.
      return null;
    } catch (error, stack) {
      debugPrint('Backup failed: $error\n$stack');
      _showMessage(l.settingsBackupRestore_backupFailed);
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Backup to Local Storage: the export, then the saved location.
  Future<void> _backupToLocalStorage() async {
    final result = await _exportBackup(ref.read(backupFileGatewayProvider));
    if (result == null || !mounted) return;
    _showMessage(
      AppLocalizations.of(context).settingsBackupRestore_backupSaved(
        result.path,
      ),
    );
  }

  /// Backup to Google Drive: the same local backup, then an offer to send it.
  ///
  /// The diary is offline (Part A), so the Drive button cannot upload anything
  /// itself. It does the one thing that is honest and useful: writes the same
  /// encrypted backup the local action writes — through the same save dialog, so
  /// the file the user keeps is the file the status card reports — and then
  /// offers the platform share sheet, which is where Google Drive appears as a
  /// target.
  Future<void> _backupToDrive() async {
    final sink = ShareableBackupSink(ref.read(backupFileGatewayProvider));
    final result = await _exportBackup(sink);
    if (result == null || !mounted) return;

    // The backup is saved and recorded by now, so this window only decides
    // whether the share sheet opens — declining it is not a failed backup.
    final send = await showBackupShareDialog(context, path: result.path);
    if (!send || !mounted) return;

    final l = AppLocalizations.of(context);
    final outcome = await ref
        .read(appShareServiceProvider)
        .shareFile(
          // The sink's copy when the platform returned a content URI no share
          // sheet can attach, otherwise the user's own file.
          path: sink.sharePath ?? result.path,
          subject: l.settingsBackupRestore_shareSubject,
        );
    if (!mounted) return;
    switch (outcome) {
      case AppShareOutcome.failed:
        _showMessage(l.settingsBackupRestore_shareFailed);
      // A sheet the user dismissed needs no message, and a completed share is
      // self-evident: the file is already on their device either way.
      case AppShareOutcome.shared:
      case AppShareOutcome.dismissed:
      case AppShareOutcome.copiedToClipboard:
        break;
    }
  }

  /// Picks a file, opens it, confirms, then imports it in one transaction.
  Future<void> _restoreFromBackup() async {
    final l = AppLocalizations.of(context);

    final PickedBackupFile? picked;
    try {
      picked = await ref.read(backupFileGatewayProvider).pick();
    } catch (error, stack) {
      debugPrint('Backup file picker failed: $error\n$stack');
      _showMessage(l.settingsBackupRestore_errorOpenFile);
      return;
    }
    if (picked == null || !mounted) return;

    // Asked before opening: a legacy plaintext backup opens with an empty
    // passphrase, and an encrypted one reports a wrong passphrase.
    final secret = await showRecoveryPassphraseDialog(context);
    if (secret == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final repository = await ref.read(backupRepositoryProvider.future);
      if (!mounted) return;
      // Decrypt and authenticate before anything else: a file that fails here
      // cannot have touched the database.
      final opened = await runWithBackupProgress(
        context,
        l.settingsBackupRestore_restoreProgress,
        () => openBackupFile(bytes: picked!.bytes, recoverySecret: secret),
      );
      if (!mounted) return;

      // Restores never merge silently: existing data asks first.
      final hasExistingData = await repository.hasExistingData();
      if (!mounted) return;
      if (hasExistingData) {
        final confirmed = await showRestoreReplaceDialog(
          context,
          file: picked,
          backup: opened,
        );
        if (!confirmed || !mounted) return;
      }

      final result = await runWithBackupProgress(
        context,
        l.settingsBackupRestore_restoreProgress,
        () => repository.restoreSnapshot(
          backup: opened,
          replaceExisting: hasExistingData,
        ),
      );
      if (!mounted) return;
      await showRestoreCompleteDialog(context, rowCount: result.rowCount);
      if (!mounted) return;
      // The whole database was replaced, so every provider holding rows is
      // stale. Re-opening the database is the app's own reload lever (the same
      // one the key-loss recovery path uses) and rebuilds every screen's data.
      ref.invalidate(databaseProvider);
    } on BackupRestoreException catch (error) {
      debugPrint('Restore refused: ${error.failure.name} — ${error.message}');
      _showMessage(_restoreFailureMessage(l, error.failure));
    } catch (error, stack) {
      debugPrint('Restore failed: $error\n$stack');
      _showMessage(l.settingsBackupRestore_errorImportFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The user-facing message for one engine refusal.
  String _restoreFailureMessage(
    AppLocalizations l,
    BackupRestoreFailure failure,
  ) => switch (failure) {
    BackupRestoreFailure.invalidFile =>
      l.settingsBackupRestore_errorInvalidFile,
    BackupRestoreFailure.unsupportedVersion =>
      l.settingsBackupRestore_errorUnsupportedVersion,
    BackupRestoreFailure.wrongSecretOrTampered =>
      l.settingsBackupRestore_errorWrongSecret,
    BackupRestoreFailure.damagedFile => l.settingsBackupRestore_errorDamaged,
    BackupRestoreFailure.conflictNeedsConfirmation =>
      l.settingsBackupRestore_errorConflict,
    BackupRestoreFailure.importFailed =>
      l.settingsBackupRestore_errorImportFailed,
  };

  /// Shows [message] unless the screen has already left the tree.
  ///
  /// The guard lives here rather than at each call site, so a flow that ends
  /// after an await (or after the app reloads itself following a restore) can
  /// report its outcome without touching a dead context.
  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final metadata = ref.watch(backupMetadataProvider);
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
          _ActionCard(
            onBackupLocal: _busy ? null : _backupToLocalStorage,
            onBackupDrive: _busy ? null : _backupToDrive,
            onRestore: _busy ? null : _restoreFromBackup,
          ),
          const _BackupNote(),
          const SizedBox(height: AppSpacing.xl),
          // Section 2: automatic-backup schedule.
          _SectionHeader(l.settingsBackupRestore_sectionAutomaticBackup),
          _ScheduleCard(
            selectedDays: metadata.scheduleDays,
            onChanged: (days) => ref
                .read(backupMetadataProvider.notifier)
                .setScheduleDays(days),
          ),
          const SizedBox(height: AppSpacing.xl),
          // Section 3: last successful backup.
          _SectionHeader(l.settingsBackupRestore_sectionStatus),
          _StatusCard(metadata: metadata),
        ],
      ),
    );
  }
}

/// Section heading (mockup `label-lg` + `tracking-wider`).
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
        letterSpacing: 0.7, // tracking-wider — 0.05em at 14 px.
      ),
    ),
  );
}

/// The three manual actions stacked in one card, per the mockup.
class _ActionCard extends StatelessWidget {
  /// Runs the local backup flow; null while one is already running.
  final VoidCallback? onBackupLocal;

  /// Reports that cloud backup is not available yet.
  final VoidCallback? onBackupDrive;

  /// Runs the restore flow; null while one is already running.
  final VoidCallback? onRestore;

  const _ActionCard({
    required this.onBackupLocal,
    required this.onBackupDrive,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          _ActionButton(
            key: const ValueKey('backup-local'),
            icon: Icons.cloud_upload,
            label: l.settingsBackupRestore_backupLocal,
            onPressed: onBackupLocal,
          ),
          const SizedBox(height: AppSpacing.md),
          _ActionButton(
            key: const ValueKey('backup-drive'),
            icon: Icons.add_to_drive,
            label: l.settingsBackupRestore_backupDrive,
            onPressed: onBackupDrive,
          ),
          // The mockup wraps Restore in an extra `pt-sm`, so it sits one
          // step further down than the other two.
          const SizedBox(height: AppSpacing.lg),
          _ActionButton(
            key: const ValueKey('restore-backup'),
            icon: Icons.settings_backup_restore,
            label: l.settingsBackupRestore_restore,
            onPressed: onRestore,
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
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    super.key,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: settingsPrimaryButtonHeight,
    child: FilledButton.icon(
      onPressed: onPressed,
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

/// Last successful backup card: the stored date and location, or the note that
/// no backup has been made yet.
class _StatusCard extends StatelessWidget {
  final BackupMetadata metadata;

  const _StatusCard({required this.metadata});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final at = metadata.lastSuccessfulAt;
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
            child: Icon(
              at == null ? Icons.backup_outlined : Icons.verified,
              color: AppColors.secondary,
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
                  at == null
                      ? l.settingsBackupRestore_lastBackupPlaceholder
                      : AppDateUtils.formatNoteCardDate(
                          at,
                          locale: l.localeName,
                        ),
                  key: const ValueKey('backup-status-line'),
                  style: AppTypography.bodyMd.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                if (metadata.lastPath != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    metadata.lastPath!,
                    key: const ValueKey('backup-status-path'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.tertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
