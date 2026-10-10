/// Backup & Restore screen: manual backup/restore actions, automatic-backup
/// schedule, and the last-backup status (Task 15 Phase 4).
///
/// Body mirrors `mockup_html_screens/settings_backupRestore/code.html`: the
/// action card, the note, a radio-list schedule card and the status card. The
/// mockup's first three section headings are **sub-menu buttons** (the shared
/// `SettingsMenuCard`, the same control the Account & Profile menu uses) that
/// reveal their options one at a time, because the screen had grown past what
/// fits on a phone at once; Backup Status keeps the mockup's plain heading and is
/// always on screen, since it is a report rather than a set of options.
///
/// Wired to the Task 15 engine: **Backup to Local Storage** asks for a
/// passphrase, exports, and hands the encrypted file to the platform's
/// "Save to…" dialog; **Backup as Excel File** writes the plaintext workbook of
/// the four tables a lawyer edits; **Backup to Google Drive** makes that same
/// local backup and then offers the platform share sheet, which is where Google
/// Drive is a target — the app stays offline, so it never uploads anything
/// itself; **Restore from backup** picks a file, works out whether it is the
/// encrypted container or an Excel workbook, validates it, asks before replacing
/// local data, imports in one transaction and reloads the app.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/backup/backup_restore.dart';
import '../../../core/backup/excel_backup.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/constants/app_version.dart';
import '../../../core/l10n/app_translations.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/providers/backup_providers.dart';
import '../../../core/providers/print_providers.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/services/app_share_service.dart';
import '../../../core/services/local_identity_service.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/providers/database_provider.dart';
import '../../accounts_and_profile/data/account_mode.dart';
import '../data/backup_file_gateway.dart';
import '../data/backup_metadata_store.dart';
import '../data/backup_repository.dart';
import 'backup_dialogs.dart';
import 'edit_court_steps/court_category_label.dart';
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

/// The screen's collapsible sections, in the order they are drawn.
///
/// Backup Status is deliberately not a member: it is a report the user reads at a
/// glance, not a set of options, so it is always on screen and never collapses.
enum _Section { backup, encryption, automaticBackup, excelFormat }

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

  /// Which section is open; null when every section is closed.
  ///
  /// Every section starts closed, so the screen opens as a short list of
  /// headings and reveals its options only when the user taps one. Kept in
  /// memory rather than stored: which section the user last looked at is not
  /// worth a preference, and a remembered answer would be the wrong one the next
  /// time they come here to do something else.
  _Section? _openSection;

  /// Opens [section] and closes whichever was open, so only one is ever open.
  void _toggleSection(_Section section) => setState(
    () => _openSection = _openSection == section ? null : section,
  );

  /// Runs the export every backup action shares.
  ///
  /// [sink] is the only difference between the backup buttons: all three write
  /// into the diary folder (the folder-first composite, which falls back to the
  /// save dialog only when the folder cannot be written). A dismissed save
  /// dialog writes nothing and records nothing, because the archive is only
  /// recorded once the sink reported success.
  ///
  /// A passphrase is asked for **only when encryption is on** (off by default):
  /// with it off the backup is written as readable JSON and needs nothing from
  /// the user. Returns the export receipt, or null when nothing was written — a
  /// cancelled passphrase window or a failure that has already been reported —
  /// so the caller stops instead of offering the next step for a file that is
  /// not there.
  Future<BackupExportResult?> _exportBackup(BackupArchiveSink sink) async {
    final l = AppLocalizations.of(context);
    final String? secret;
    if (ref.read(backupMetadataProvider).encryptBackups) {
      secret = await showBackupPassphraseDialog(context);
      if (secret == null || !mounted) return null;
    } else {
      secret = null;
    }

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

  /// Backup to Local Storage: the export into the diary folder, then the saved
  /// location. If the folder cannot be created, fall back to the save dialog.
  Future<void> _backupToLocalStorage() async {
    final result = await _exportBackup(ref.read(backupFolderSinkProvider));
    if (result == null || !mounted) return;
    _showMessage(
      AppLocalizations.of(context).settingsBackupRestore_backupSaved(
        result.path,
      ),
    );
  }

  /// Backup to Google Drive: the same folder backup, then an offer to send it.
  ///
  /// The diary is offline (Part A), so the Drive button cannot upload anything
  /// itself. It does the one thing that is honest and useful: writes the same
  /// encrypted backup the other actions write — automatically into the same
  /// public folder, with no save dialog — and then offers the platform share
  /// sheet, which is where Google Drive appears as a target. The file is a real
  /// path on the device's public storage, so the sheet attaches it as it is.
  Future<void> _backupToDrive() async {
    final result = await _exportBackup(ref.read(backupFolderFirstSinkProvider));
    if (result == null || !mounted) return;

    // The backup is saved and recorded by now, so this window only decides
    // whether the share sheet opens — declining it is not a failed backup.
    final send = await showBackupShareDialog(context, path: result.path);
    if (!send || !mounted) return;

    final l = AppLocalizations.of(context);
    final outcome = await ref
        .read(appShareServiceProvider)
        .shareFile(
          path: result.path,
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

  /// Backup as Excel File: the plaintext workbook, then its saved location.
  ///
  /// It asks for no passphrase, because the file is a spreadsheet the user opens
  /// in Excel and cannot be sealed in the app's container. The note under the
  /// card says so before the file is written, and the export says the same thing
  /// when it is read back.
  Future<void> _backupToExcel() async {
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final repository = await ref.read(backupRepositoryProvider.future);
      if (!mounted) return;
      final result = await runWithBackupProgress(
        context,
        l.settingsBackupRestore_excelProgress,
        () => repository.exportExcelWorkbook(
          sink: ref.read(backupFolderFirstSinkProvider),
          appVersion: appVersion,
        ),
      );
      await ref
          .read(backupMetadataProvider.notifier)
          .recordSuccess(at: result.exportedAt, path: result.path);
      _showMessage(l.settingsBackupRestore_excelSaved(result.path));
    } on BackupSaveCancelledException {
      // The save dialog was dismissed: nothing was written, nothing to say.
      return;
    } catch (error, stack) {
      debugPrint('Excel backup failed: $error\n$stack');
      _showMessage(l.settingsBackupRestore_backupFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Saves the sample workbook that shows the format a restore expects.
  ///
  /// Generated from the same column list the reader validates, so the sample can
  /// never show a header the app would refuse.
  Future<void> _saveExcelTemplate() async {
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final repository = await ref.read(backupRepositoryProvider.future);
      final bytes = await repository.buildExcelTemplateWorkbook(
        appVersion: appVersion,
        // Court categories are stored as localization keys, so the sample shows
        // the same label the rest of the app shows. Guarded because the label is
        // resolved after the repository's queries, by which time the screen may
        // have left the tree.
        categoryLabel: (nameKey) =>
            mounted ? courtCategoryName(context, nameKey) : nameKey,
        // Districts are stored as stable ids as well; the Courts sheet shows the
        // same name the app shows, so the column filters in the user's language.
        districtLabel: (districtId) => mounted
            ? context.l10n.seedLabel(districtId, fallbackEn: districtId)
            : districtId,
      );
      if (!mounted) return;
      final path = await ref
          .read(backupFileGatewayProvider)
          .write(fileName: 'legal-case-diary-template.xlsx', bytes: bytes);
      _showMessage(l.settingsBackupRestore_excelTemplateSaved(path));
    } on BackupSaveCancelledException {
      return;
    } catch (error, stack) {
      debugPrint('Excel template save failed: $error\n$stack');
      _showMessage(l.settingsBackupRestore_backupFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Picks a file, opens it, confirms, then imports it in one transaction.
  ///
  /// One flow serves both formats. A workbook is recognised by its ZIP signature
  /// and never asked for a passphrase it does not have; the encrypted container
  /// takes the passphrase route as before. From there both become an
  /// [OpenedBackup] and share the confirm-and-replace step, the transaction and
  /// the reload.
  Future<void> _restoreFromBackup() async {
    final l = AppLocalizations.of(context);

    // Whose diary this is, read **before** the first await (Riverpod 3 refuses a
    // widget ref once the widget is on its way out). The identity is the bound
    // account after sign-in, or this device's own placeholder before it — the
    // same value every local write is stamped with — and the firm decides which
    // rows count as this diary's own.
    final identity = ref.read(localIdentityServiceProvider).getId();
    final firmId = ref.read(accountProfileProvider).value?.firmId;

    // Inside the diary folder: one backup restores directly, more than one
    // offers a choice. The picker is the folder's replacement when the folder
    // is missing or inaccessible.
    PickedBackupFile? picked;
    try {
      picked = await _pickFromFolderOrPicker();
    } catch (error, stack) {
      debugPrint('Backup source unavailable: $error\n$stack');
      _showMessage(l.settingsBackupRestore_errorOpenFile);
      return;
    }
    if (picked == null || !mounted) return;

    final isSpreadsheet = looksLikeSpreadsheet(picked.bytes);
    final String secret;
    if (isSpreadsheet) {
      secret = '';
    } else if (looksLikeEncryptedBackup(picked.bytes)) {
      // Only an encrypted container needs a passphrase. A plaintext backup —
      // written with encryption off, or from before encryption existed — opens
      // without one.
      final entered = await showRecoveryPassphraseDialog(context);
      if (entered == null || !mounted) return;
      secret = entered;
    } else {
      secret = '';
    }

    setState(() => _busy = true);
    try {
      final repository = await ref.read(backupRepositoryProvider.future);
      if (!mounted) return;
      // Decrypt and authenticate before anything else: a file that fails here
      // cannot have touched the database.
      final opened = isSpreadsheet
          ? repository.openExcelBackup(picked.bytes)
          : await runWithBackupProgress(
              context,
              l.settingsBackupRestore_restoreProgress,
              () => openBackupFile(bytes: picked!.bytes, recoverySecret: secret),
            );
      if (!mounted) return;

      // Whose file is this? Asked before the replace question, so a backup that
      // belongs to another account is refused without ever offering to wipe this
      // diary for it. A file naming no owner (a sample workbook filled in by
      // hand) passes and has this device's identity stamped onto its rows.
      repository.checkRestorable(
        opened,
        ownerId: identity,
        firmId: firmId,
      );
      if (!mounted) return;

      // Restores never merge silently: existing data asks first. The check is
      // scoped to the tables the file carries, so a four-sheet workbook never
      // asks about — and never replaces — anything outside its own scope.
      final hasExistingData = await repository.hasDataInTables(
        opened.tables.keys.toList(),
      );
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
          ownerId: identity,
          firmId: firmId,
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
    } on ExcelBackupRefusal catch (error) {
      // A workbook that is off-format names the sheet, the column and the row, so
      // the user can go and correct exactly that cell.
      debugPrint('Excel restore refused: $error');
      _showMessage(_excelRefusalMessage(l, error));
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

  /// Finds the backup(s) the restore should use, dialog-free.
  ///
  /// One backup in the folder restores directly. Several are offered in a
  /// choice dialog (the "slightly rounder corner popup" the user asked for), and
  /// the system file picker remains the fallback when the folder is missing,
  /// inaccessible, or holds no backup.
  ///
  /// Files are read synchronously: a backup is a few megabytes at most, and this
  /// keeps the folder path free of the async I/O a widget test's fake clock
  /// cannot complete.
  Future<PickedBackupFile?> _pickFromFolderOrPicker() async {
    final directory = await ref.read(backupFolderDirectoryProvider)();
    final files = await listBackupFiles(directory);
    if (files.length == 1) {
      final bytes = files.single.readAsBytesSync();
      return PickedBackupFile(
        name: p.basename(files.single.path),
        path: files.single.path,
        bytes: bytes,
      );
    }
    if (files.length > 1) {
      if (!mounted) return null;
      final picked = await showDialog<PickedBackupFile?>(
        context: context,
        builder: (_) => _BackupFilePickerDialog(
          files: files,
          onPick: (File f) async => PickedBackupFile(
            name: p.basename(f.path),
            path: f.path,
            bytes: f.readAsBytesSync(),
          ),
        ),
      );
      if (picked != null) return picked;
      return null; // The choice was cancelled; nothing to restore.
    }
    // The folder is missing, empty or holds no app backup: ask the platform.
    final picked = await ref.read(backupFileGatewayProvider).pick();
    if (picked == null || !mounted) return null;
    return picked;
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
    BackupRestoreFailure.anotherAccount =>
      l.settingsBackupRestore_errorAnotherAccount,
    BackupRestoreFailure.importFailed =>
      l.settingsBackupRestore_errorImportFailed,
  };

  /// The user-facing message for one workbook refusal.
  ///
  /// The sheet, the column and the spreadsheet row are interpolated into the
  /// message: the whole point of validating the workbook rather than letting the
  /// database refuse it is that the user is told which cell to fix.
  String _excelRefusalMessage(AppLocalizations l, ExcelBackupRefusal refusal) {
    final sheet = refusal.sheet ?? '';
    final column = refusal.column ?? '';
    return switch (refusal.reason) {
      ExcelRefusalReason.notASpreadsheet =>
        l.settingsBackupRestore_excelNotSpreadsheet,
      ExcelRefusalReason.notABackup => l.settingsBackupRestore_excelNotBackup,
      ExcelRefusalReason.newerVersion =>
        l.settingsBackupRestore_excelNewerVersion,
      ExcelRefusalReason.unknownSheet =>
        l.settingsBackupRestore_excelUnknownSheet(sheet),
      ExcelRefusalReason.missingSheet =>
        l.settingsBackupRestore_excelMissingSheet(sheet),
      ExcelRefusalReason.unknownColumn =>
        l.settingsBackupRestore_excelUnknownColumn(sheet, column),
      ExcelRefusalReason.missingColumn =>
        l.settingsBackupRestore_excelMissingColumn(sheet, column),
      ExcelRefusalReason.emptySheet =>
        l.settingsBackupRestore_excelEmptySheet(sheet),
      ExcelRefusalReason.missingValue =>
        l.settingsBackupRestore_excelMissingValue(
          sheet,
          refusal.row ?? 0,
          column,
        ),
    };
  }

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
          _CollapsibleSection(
            id: 'backup',
            icon: Icons.backup_outlined,
            title: l.settingsBackupRestore_sectionBackup,
            subtitle: l.settingsBackupRestore_sectionBackupSubtitle,
            open: _openSection == _Section.backup,
            onToggle: () => _toggleSection(_Section.backup),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ActionCard(
                  onBackupLocal: _busy ? null : _backupToLocalStorage,
                  onBackupExcel: _busy ? null : _backupToExcel,
                  onBackupDrive: _busy ? null : _backupToDrive,
                  onRestore: _busy ? null : _restoreFromBackup,
                ),
                const _BackupNote(),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Section 2: passphrase encryption of backups. Off until enabled.
          _CollapsibleSection(
            id: 'encryption',
            icon: Icons.lock_outline,
            title: l.settingsBackupRestore_sectionEncryption,
            subtitle: l.settingsBackupRestore_sectionEncryptionSubtitle,
            open: _openSection == _Section.encryption,
            onToggle: () => _toggleSection(_Section.encryption),
            child: _EncryptionCard(
              enabled: metadata.encryptBackups,
              onEnable: _busy
                  ? null
                  : () => ref
                        .read(backupMetadataProvider.notifier)
                        .setEncryptBackups(true),
              onDisable: _busy
                  ? null
                  : () => ref
                        .read(backupMetadataProvider.notifier)
                        .setEncryptBackups(false),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Section 3: automatic-backup schedule.
          _CollapsibleSection(
            id: 'automatic',
            icon: Icons.schedule,
            title: l.settingsBackupRestore_sectionAutomaticBackup,
            subtitle: l.settingsBackupRestore_sectionAutomaticBackupSubtitle,
            open: _openSection == _Section.automaticBackup,
            onToggle: () => _toggleSection(_Section.automaticBackup),
            child: _ScheduleCard(
              selectedDays: metadata.scheduleDays,
              onChanged: (days) async {
                await ref
                    .read(backupMetadataProvider.notifier)
                    .setScheduleDays(days);
                // Re-arm the daily alarm for the new interval (or cancel it for
                // Off), so the choice takes effect immediately.
                await ref.read(backupSchedulerProvider).syncSchedule();
              },
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Section 4: the workbook format a restore expects.
          _CollapsibleSection(
            id: 'excel',
            icon: Icons.grid_on,
            title: l.settingsBackupRestore_sectionExcelFormat,
            subtitle: l.settingsBackupRestore_sectionExcelFormatSubtitle,
            open: _openSection == _Section.excelFormat,
            onToggle: () => _toggleSection(_Section.excelFormat),
            child: _ExcelFormatCard(
              onTemplate: _busy ? null : _saveExcelTemplate,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Section 5: last successful backup. Always open — the mockup's plain
          // heading, never a button.
          _SectionHeading(l.settingsBackupRestore_sectionStatus),
          const SizedBox(height: AppSpacing.sm),
          _StatusCard(metadata: metadata),
        ],
      ),
    );
  }
}

/// The "slightly rounder corner popup" listing the backup files in the diary
/// folder, shown when a restore finds more than one.
///
/// Each row is a tappable backup file; tapping one reads it into the same
/// [PickedBackupFile] the platform picker would have produced, so the rest of
/// the restore flow is unchanged. The corner radius is a little rounder than
/// the app's default dialogs — `sheetRadius + radiusSm` — as the user asked.
class _BackupFilePickerDialog extends StatelessWidget {
  /// The backup files to choose from, pre-sorted.
  final List<File> files;

  /// Reads one chosen file into an opened backup.
  final Future<PickedBackupFile> Function(File file) onPick;

  const _BackupFilePickerDialog({required this.files, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          AppSpacing.sheetRadius + AppSpacing.radiusSm,
        ),
        side: const BorderSide(color: AppColors.outlineVariant),
      ),
      title: Text(
        l.settingsBackupRestore_chooseBackupTitle,
        style: AppTypography.titleLg,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final file in files)
            ListTile(
              key: ValueKey('backup-file-${p.basename(file.path)}'),
              title: Text(p.basename(file.path)),
              onTap: () async {
                final opened = await onPick(file);
                if (context.mounted) {
                  Navigator.of(context).pop(opened);
                }
              },
            ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.sharedActions_cancel),
        ),
      ],
    );
  }
}

/// One collapsible section: a sub-menu button that reveals its options.
///
/// The header is the app's shared [SettingsMenuCard] — the very control the
/// Account & Profile menu draws its sub-menus with — so a section here reads as
/// one more menu entry, with the expand chevron standing in for that card's
/// "open a screen" arrow. Tapping it opens its options and closes whichever
/// section was open, so the screen shows one set of options at a time. A closed
/// section is not built at all, so it costs nothing.
class _CollapsibleSection extends StatelessWidget {
  /// Stable id, used for the widget keys the tests drive.
  final String id;

  /// Leading icon of the header button.
  final IconData icon;
  final String title;
  final String subtitle;
  final bool open;
  final VoidCallback onToggle;
  final Widget child;

  const _CollapsibleSection({
    required this.id,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.open,
    required this.onToggle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => Column(
    key: ValueKey('backup-section-$id'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SettingsMenuCard(
        key: ValueKey('backup-section-toggle-$id'),
        icon: icon,
        title: title,
        subtitle: subtitle,
        onTap: onToggle,
        trailing: Icon(
          open ? Icons.expand_less : Icons.expand_more,
          key: ValueKey('backup-section-chevron-$id'),
          color: AppColors.tertiary,
        ),
      ),
      // The reveal animates so the list below does not jump when a section opens
      // under the reader's thumb.
      AnimatedSize(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
        child: open
            ? Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: child,
              )
            : const SizedBox(width: double.infinity),
      ),
    ],
  );
}

/// A plain, non-interactive section heading.
///
/// Backup Status keeps the mockup's static heading rather than becoming a
/// button: it is a report that should already be readable when the screen opens.
class _SectionHeading extends StatelessWidget {
  /// Heading text, written in Title Case like every other label in the app.
  final String title;

  const _SectionHeading(this.title);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.xs,
      vertical: AppSpacing.sm,
    ),
    child: Text(
      title,
      style: AppTypography.labelLg.copyWith(
        color: AppColors.onSurfaceVariant,
        letterSpacing: 0.7, // tracking-wider — 0.05em at 14 px.
      ),
    ),
  );
}

/// The manual actions stacked in one card, per the mockup's order with the Excel
/// backup added directly after the local one.
class _ActionCard extends StatelessWidget {
  /// Runs the local backup flow; null while one is already running.
  final VoidCallback? onBackupLocal;

  /// Runs the plaintext Excel export; null while one is already running.
  final VoidCallback? onBackupExcel;

  /// Reports that cloud backup is not available yet.
  final VoidCallback? onBackupDrive;

  /// Runs the restore flow; null while one is already running.
  final VoidCallback? onRestore;

  const _ActionCard({
    required this.onBackupLocal,
    required this.onBackupExcel,
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
            key: const ValueKey('backup-excel'),
            icon: Icons.grid_on,
            label: l.settingsBackupRestore_backupExcel,
            onPressed: onBackupExcel,
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
///
/// These lines are paragraphs rather than labels, so their strings are written in
/// **sentence case** in the ARB — Title Case is kept for headings, button labels
/// and menu entries only.
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
          // The Excel exception to the line above, stated where the user is about
          // to press the button rather than buried in a help page.
          Text(
            l.settingsBackupRestore_excelNote,
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

/// The Encryption on Backup section: why to turn it on, what it costs, and the
/// Enable / Disable pair that changes the preference.
///
/// Encryption is **off until the user enables it**, so the copy states both
/// halves plainly — the protection a passphrase gives and the risk of forgetting
/// it — and the two choices sit on one line in the section's own button
/// geometry. The current state is named in a short caption and the selected
/// button is filled while the other is outlined, so which way the switch is set
/// reads at a glance.
///
/// The why / cost / state copy is paragraph text, so the ARB holds it in sentence
/// case; only the section's own heading, subtitle and button labels are Title Case.
class _EncryptionCard extends StatelessWidget {
  /// Whether encryption is currently on.
  final bool enabled;

  /// Turns encryption on; null while another action is running.
  final VoidCallback? onEnable;

  /// Turns encryption off; null while another action is running.
  final VoidCallback? onDisable;

  const _EncryptionCard({
    required this.enabled,
    required this.onEnable,
    required this.onDisable,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final hint = AppTypography.bodySm.copyWith(
      color: AppColors.onSurfaceVariant,
    );
    return Container(
      decoration: _cardDecoration(color: AppColors.surfaceBright),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.settingsBackupRestore_encryptionWhy, style: AppTypography.bodyMd),
          const SizedBox(height: AppSpacing.sm),
          Text(l.settingsBackupRestore_encryptionCost, style: hint),
          const SizedBox(height: AppSpacing.md),
          Text(
            enabled
                ? l.settingsBackupRestore_encryptionStateOn
                : l.settingsBackupRestore_encryptionStateOff,
            key: const ValueKey('backup-encryption-state'),
            style: AppTypography.bodySm.copyWith(color: AppColors.primary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _ChoiceButton(
                  key: const ValueKey('backup-encryption-enable'),
                  label: l.settingsBackupRestore_encryptionEnable,
                  selected: enabled,
                  onPressed: onEnable,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _ChoiceButton(
                  key: const ValueKey('backup-encryption-disable'),
                  label: l.settingsBackupRestore_encryptionDisable,
                  selected: !enabled,
                  onPressed: onDisable,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One half of the Enable / Disable pair.
///
/// Filled in the section's primary style when it is the current choice, outlined
/// otherwise, with the same height and corner radius [settingsPrimaryButtonHeight]
/// and [_ActionButton] use, so the pair reads as part of the same screen.
class _ChoiceButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onPressed;

  const _ChoiceButton({
    required this.label,
    required this.selected,
    required this.onPressed,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
    );
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(
        Size.fromHeight(settingsPrimaryButtonHeight),
      ),
      shape: WidgetStatePropertyAll(shape),
      textStyle: const WidgetStatePropertyAll(AppTypography.labelLg),
    );
    return selected
        ? FilledButton(
            onPressed: onPressed,
            style: style.copyWith(
              backgroundColor: const WidgetStatePropertyAll(AppColors.primary),
              foregroundColor: const WidgetStatePropertyAll(AppColors.onPrimary),
            ),
            child: Text(label),
          )
        : OutlinedButton(
            onPressed: onPressed,
            style: style,
            child: Text(label),
          );
  }
}

/// The Excel-format section: what the workbook has to look like, and the sample.
///
/// The requirement is stated up front because a restore matches the sheets by
/// name and the columns by header row, so a renamed sheet or column is refused —
/// saying so here is what makes that refusal unsurprising. The template is
/// generated from the very column list the reader validates, so what it shows can
/// never be something the app would reject.
class _ExcelFormatCard extends StatelessWidget {
  /// Saves the sample workbook; null while another action is running.
  final VoidCallback? onTemplate;

  const _ExcelFormatCard({required this.onTemplate});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final hint = AppTypography.bodySm.copyWith(
      color: AppColors.onSurfaceVariant,
    );
    return Container(
      decoration: _cardDecoration(color: AppColors.surfaceBright),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.settingsBackupRestore_excelIntro, style: AppTypography.bodyMd),
          const SizedBox(height: AppSpacing.sm),
          Text(l.settingsBackupRestore_excelIdNote, style: hint),
          const SizedBox(height: AppSpacing.sm),
          Text(l.settingsBackupRestore_excelPartialNote, style: hint),
          const SizedBox(height: AppSpacing.sm),
          // The template's extra reference sheets, stated where the button is, so
          // the reader knows why the sample has more sheets than a backup does.
          Text(l.settingsBackupRestore_excelTemplateNote, style: hint),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            height: settingsPrimaryButtonHeight,
            child: FilledButton.icon(
              key: const ValueKey('backup-excel-template'),
              onPressed: onTemplate,
              icon: const Icon(Icons.download, size: 20),
              label: Text(l.settingsBackupRestore_excelTemplate),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                textStyle: AppTypography.labelLg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
                ),
              ),
            ),
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
