/// Windows the Backup & Restore screen opens (Task 15 Phase 4).
///
/// The mockup defines only the screen body, so these dialogs follow the app's
/// established window style instead: a titled [AlertDialog] with centred
/// actions, the shared Cancel label, and the same action size as the Delete and
/// Exit windows. Two of them are destructive-safe by design —
/// [showRestoreReplaceDialog] must be answered before any data is replaced, and
/// [runWithBackupProgress] cannot be dismissed, so a running export or import
/// can never be cancelled into an unknown state. [showBackupShareDialog] is the
/// only one that cannot affect the data: by the time it appears the backup is
/// already written and recorded.
library;

import 'package:flutter/material.dart';

import '../../../core/backup/backup_restore.dart';
import '../../../core/backup/excel_backup.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/utils/date_utils.dart';
import '../data/backup_file_gateway.dart';

/// Action size used by the shared Delete/Exit windows (112x48, 16 pt).
const Size _actionSize = Size(112, 48);
const TextStyle _actionTextStyle = TextStyle(fontSize: 16);

/// Roomier window geometry for the dialogs that carry fields.
const EdgeInsets _dialogInsetPadding = EdgeInsets.symmetric(
  horizontal: AppSpacing.md,
  vertical: AppSpacing.xl,
);
const EdgeInsets _dialogTitlePadding = EdgeInsets.fromLTRB(
  AppSpacing.lg,
  AppSpacing.lg,
  AppSpacing.lg,
  AppSpacing.sm,
);
const EdgeInsets _dialogContentPadding = EdgeInsets.symmetric(
  horizontal: AppSpacing.lg,
);
const EdgeInsets _dialogActionsPadding = EdgeInsets.fromLTRB(
  AppSpacing.md,
  AppSpacing.sm,
  AppSpacing.md,
  AppSpacing.md,
);

/// Asks the user to set (and confirm) the passphrase a new backup is sealed with.
///
/// Returns the passphrase, or null when the user cancels. Nothing is stored
/// anywhere — the dialog says so — so the confirmation field is what protects
/// the user from locking their own backup.
Future<String?> showBackupPassphraseDialog(BuildContext context) {
  final l = AppLocalizations.of(context);
  return showDialog<String>(
    context: context,
    builder: (context) => _PassphraseDialog(
      title: l.settingsBackupRestore_passphraseTitle,
      body: l.settingsBackupRestore_passphraseBody,
      confirmLabel: l.settingsBackupRestore_encryptAndSave,
      fieldLabel: l.settingsBackupRestore_passphraseLabel,
      confirmFieldLabel: l.settingsBackupRestore_passphraseConfirmLabel,
      requiredLabel: l.settingsBackupRestore_passphraseRequired,
      mismatchLabel: l.settingsBackupRestore_passphraseMismatch,
    ),
  );
}

/// Asks for the passphrase a backup file was created with.
///
/// Returns null when the user cancels, and an **empty string** when they
/// continue without one — which is exactly what a legacy plaintext backup
/// needs, and what an encrypted backup reports as a wrong passphrase.
Future<String?> showRecoveryPassphraseDialog(BuildContext context) {
  final l = AppLocalizations.of(context);
  return showDialog<String>(
    context: context,
    builder: (context) => _PassphraseDialog(
      title: l.settingsBackupRestore_recoveryPassphraseTitle,
      body: l.settingsBackupRestore_recoveryPassphraseBody,
      confirmLabel: l.settingsBackupRestore_openBackup,
      fieldLabel: l.settingsBackupRestore_passphraseLabel,
      requiredLabel: l.settingsBackupRestore_passphraseRequired,
      hintLabel: l.settingsBackupRestore_recoveryPassphraseHint,
      allowEmpty: true,
    ),
  );
}

/// Shows what the chosen backup holds and asks whether to replace local data.
///
/// Always shown before a restore into a database that holds anything, so a
/// restore can never silently merge or overwrite.
Future<bool> showRestoreReplaceDialog(
  BuildContext context, {
  required PickedBackupFile file,
  required OpenedBackup backup,
}) async {
  final l = AppLocalizations.of(context);
  // A workbook replaces only the tables it carries, so this window says which
  // ones those are rather than warning that everything on the device goes — which
  // is true of the encrypted backup and false of a four-sheet file.
  final workbook = backup.kind == BackupFileKind.excel;
  final replaced = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      constraints: const BoxConstraints(minWidth: 300),
      title: Text(
        workbook
            ? l.settingsBackupRestore_restoreExcelTitle
            : l.settingsBackupRestore_restoreDetailsTitle,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(file.name, style: AppTypography.titleMd, maxLines: 2),
          const SizedBox(height: AppSpacing.sm),
          _DetailRow(
            label: l.settingsBackupRestore_restoreDetailsBackedUp,
            value: AppDateUtils.formatNoteCardDate(
              backup.exportedAt,
              locale: l.localeName,
            ),
          ),
          _DetailRow(
            label: l.settingsBackupRestore_restoreDetailsAppVersion,
            value: backup.appVersion,
          ),
          if (workbook)
            _DetailRow(
              label: l.settingsBackupRestore_restoreDetailsSheets,
              value: _sheetsOf(backup),
            ),
          _DetailRow(
            label: l.settingsBackupRestore_restoreDetailsRecords,
            value: AppDateUtils.formatDigits(
              _rowCount(backup),
              l.localeName,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            workbook
                ? l.settingsBackupRestore_restoreExcelWarning
                : l.settingsBackupRestore_restoreDetailsWarning,
            style: AppTypography.bodySm.copyWith(color: AppColors.error),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          style: TextButton.styleFrom(
            minimumSize: _actionSize,
            textStyle: _actionTextStyle,
          ),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l.sharedActions_cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: AppColors.onError,
            minimumSize: _actionSize,
            textStyle: _actionTextStyle,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l.settingsBackupRestore_restoreReplace),
        ),
      ],
    ),
  );
  return replaced == true;
}

/// Reports a completed restore and waits for the user before the app reloads.
Future<void> showRestoreCompleteDialog(
  BuildContext context, {
  required int rowCount,
}) async {
  final l = AppLocalizations.of(context);
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Text(l.settingsBackupRestore_restoreCompleteTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.settingsBackupRestore_restoreCompleteBody(rowCount),
            style: AppTypography.bodyMd,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l.settingsBackupRestore_restoreCompleteNote,
            style: AppTypography.bodySm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: _actionSize,
            textStyle: _actionTextStyle,
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.sharedDialogs_ok),
        ),
      ],
    ),
  );
}

/// Offers to send the backup that was just written through the share sheet.
///
/// Returns true when the user chooses to send it. The file is already saved and
/// the archive already recorded either way, so this window only decides whether
/// the share sheet opens — it never changes what was written, and its answer is
/// not a success or failure of the backup itself.
Future<bool> showBackupShareDialog(
  BuildContext context, {
  required String path,
}) async {
  final l = AppLocalizations.of(context);
  final send = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      constraints: const BoxConstraints(minWidth: 300),
      title: Text(l.settingsBackupRestore_driveShareTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.settingsBackupRestore_driveShareBody,
            style: AppTypography.bodyMd,
          ),
          const SizedBox(height: AppSpacing.sm),
          // The saved location, so the user sees which file is being offered —
          // and knows it is already on their device before any sharing.
          Text(
            path,
            style: AppTypography.bodySm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
            maxLines: 2,
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          style: TextButton.styleFrom(
            minimumSize: _actionSize,
            textStyle: _actionTextStyle,
          ),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l.settingsBackupRestore_driveShareNotNow),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: _actionSize,
            textStyle: _actionTextStyle,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l.settingsBackupRestore_driveShareSend),
        ),
      ],
    ),
  );
  return send == true;
}

/// Runs [task] behind a non-dismissible progress window.
///
/// The window is pushed before [task] starts and is always popped afterwards —
/// including when [task] throws — so a failure can never leave the screen
/// covered by a spinner.
Future<T> runWithBackupProgress<T>(
  BuildContext context,
  String message,
  Future<T> Function() task,
) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  // Not awaited: the window stays up until the route below pops it.
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    ),
  );
  try {
    return await task();
  } finally {
    navigator.pop();
  }
}

/// One label/value line inside the restore confirmation.
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: AppTypography.bodySm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(child: Text(value, style: AppTypography.bodySm)),
      ],
    ),
  );
}

/// One- or two-field passphrase window.
class _PassphraseDialog extends StatefulWidget {
  final String title;
  final String body;
  final String confirmLabel;
  final String fieldLabel;

  /// Second field's label; null when the window has a single field.
  final String? confirmFieldLabel;

  /// Message shown when nothing was typed (single-field windows only).
  final String requiredLabel;

  /// Message shown when the two fields differ.
  final String? mismatchLabel;

  /// Extra guidance under the fields.
  final String? hintLabel;

  /// Whether continuing without a passphrase is allowed.
  final bool allowEmpty;

  const _PassphraseDialog({
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.fieldLabel,
    required this.requiredLabel,
    this.confirmFieldLabel,
    this.mismatchLabel,
    this.hintLabel,
    this.allowEmpty = false,
  });

  @override
  State<_PassphraseDialog> createState() => _PassphraseDialogState();
}

class _PassphraseDialogState extends State<_PassphraseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passphrase = TextEditingController();
  final _confirmation = TextEditingController();

  @override
  void dispose() {
    _passphrase.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      constraints: const BoxConstraints(minWidth: 300),
      insetPadding: _dialogInsetPadding,
      titlePadding: _dialogTitlePadding,
      contentPadding: _dialogContentPadding,
      actionsPadding: _dialogActionsPadding,
      actionsAlignment: MainAxisAlignment.center,
      title: Text(widget.title, style: AppTypography.titleLg),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.body,
              style: AppTypography.bodySm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _PassphraseField(
              controller: _passphrase,
              label: widget.fieldLabel,
              autofocus: true,
              // Only emptiness here: a mismatch is reported under the field the
              // user has to correct, not under both of them.
              validator: (value) => (value ?? '').isEmpty && !widget.allowEmpty
                  ? widget.requiredLabel
                  : null,
            ),
            if (widget.confirmFieldLabel != null) ...[
              const SizedBox(height: AppSpacing.md),
              _PassphraseField(
                controller: _confirmation,
                label: widget.confirmFieldLabel!,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return widget.requiredLabel;
                  }
                  return value == _passphrase.text
                      ? null
                      : widget.mismatchLabel;
                },
              ),
            ],
            if (widget.hintLabel != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                widget.hintLabel!,
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(
            minimumSize: _actionSize,
            textStyle: _actionTextStyle,
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.sharedActions_cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: _actionSize,
            textStyle: _actionTextStyle,
          ),
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop(_passphrase.text);
          },
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

/// Obscured passphrase field with a show/hide toggle.
class _PassphraseField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? Function(String?) validator;
  final bool autofocus;

  const _PassphraseField({
    required this.controller,
    required this.label,
    required this.validator,
    this.autofocus = false,
  });

  @override
  State<_PassphraseField> createState() => _PassphraseFieldState();
}

class _PassphraseFieldState extends State<_PassphraseField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: widget.controller,
    obscureText: _obscured,
    autofocus: widget.autofocus,
    validator: widget.validator,
    style: AppTypography.bodyLg,
    decoration: InputDecoration(
      labelText: widget.label,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      suffixIcon: IconButton(
        icon: Icon(_obscured ? Icons.visibility_off : Icons.visibility),
        onPressed: () => setState(() => _obscured = !_obscured),
      ),
    ),
  );
}

/// Total number of rows a backup carries.
int _rowCount(OpenedBackup backup) {
  var total = 0;
  for (final rows in backup.tables.values) {
    if (rows is List) total += rows.length;
  }
  return total;
}

/// The workbook's data-sheet names, in the order the sheets are written.
String _sheetsOf(OpenedBackup backup) {
  final tables = backup.tables.keys.toSet();
  return <String>[
    for (final entry in excelSheetTables.entries)
      if (tables.contains(entry.value)) entry.key,
  ].join(', ');
}
