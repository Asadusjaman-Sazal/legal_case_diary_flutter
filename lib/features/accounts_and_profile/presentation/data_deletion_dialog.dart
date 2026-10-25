/// The tick list behind Manage Account's two Delete Data actions.
///
/// **0.0.473 (user request).** Both actions open this one window: the four kinds
/// of the user's own data, each ticked on its own, with the two actions the app's
/// other dialogs wear — a centred Cancel and a red confirm (red background,
/// white text). The
/// confirm is **disabled while nothing is ticked**, so a stray tap can never
/// delete anything, and the sentence at the top says the deletion cannot be
/// recovered. The red button opens the typed confirmation screen
/// (`DeleteDataConfirmScreen`), where `delete my data` must be typed before
/// anything is destroyed.
///
/// **Who opens it decides the wording, not the list.** A premium account's
/// *Delete Local & Cloud Data* and a free account's *Delete Local Data* offer
/// exactly the same four rows — only the title and the sentence naming where the
/// copies come from differ ([cloud]).
///
/// The window returns the ticked set, or `null` when it was dismissed, which the
/// caller treats as a cancellation: a dismissed window deletes nothing.
library;

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../data/data_deletion_service.dart';

/// Opens the data-deletion tick list and returns what the user chose.
Future<Set<DataDeletionCategory>?> showDataDeletionDialog(
  BuildContext context, {
  required bool cloud,
}) => showDialog<Set<DataDeletionCategory>>(
  context: context,
  builder: (context) => _DataDeletionDialog(cloud: cloud),
);

/// The window itself: four tick rows and two actions.
class _DataDeletionDialog extends StatefulWidget {
  /// Creates the window.
  const _DataDeletionDialog({required this.cloud});

  /// Whether the copies come from the account as well as this device.
  final bool cloud;

  @override
  State<_DataDeletionDialog> createState() => _DataDeletionDialogState();
}

class _DataDeletionDialogState extends State<_DataDeletionDialog> {
  /// What the user has ticked; nothing at all until they choose.
  final Set<DataDeletionCategory> _selected = <DataDeletionCategory>{};

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(
        widget.cloud
            ? l.settingsManageAccount_deleteDataTitle
            : l.settingsManageAccount_deleteLocalDataTitle,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.cloud
                  ? l.settingsManageAccount_deleteDataBodyCloud
                  : l.settingsManageAccount_deleteDataBodyLocal,
              style: AppTypography.bodyMd.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            SizedBox(height: AppSpacing.sm),
            for (final category in DataDeletionCategory.values)
              _row(l, category),
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          style: TextButton.styleFrom(
            minimumSize: const Size(112, 48),
            textStyle: const TextStyle(fontSize: 16),
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.sharedActions_cancel),
        ),
        TextButton(
          key: const ValueKey('data-deletion-confirm'),
          style: TextButton.styleFrom(
            minimumSize: const Size(112, 48),
            backgroundColor: AppColors.error,
            foregroundColor: AppColors.onError,
            disabledBackgroundColor: AppColors.error.withValues(alpha: 0.35),
            disabledForegroundColor: AppColors.onError,
            textStyle: const TextStyle(fontSize: 16),
          ),
          // Nothing ticked means nothing to delete, so the red button stays
          // disabled rather than sending an empty request.
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.of(context).pop(_selected),
          child: Text(l.settingsManageAccount_deleteDataConfirm),
        ),
      ],
    );
  }

  /// One tick row: the kind of data, and — for the seed data — what it holds.
  Widget _row(AppLocalizations l, DataDeletionCategory category) =>
      CheckboxListTile(
        key: ValueKey('data-deletion-${category.name}'),
        value: _selected.contains(category),
        onChanged: (checked) => setState(() {
          if (checked ?? false) {
            _selected.add(category);
          } else {
            _selected.remove(category);
          }
        }),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text(_title(l, category), style: AppTypography.titleMd),
        subtitle: category == DataDeletionCategory.customSeedData
            ? Text(
                l.settingsManageAccount_deleteDataCustomSeedDataHint,
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              )
            : null,
      );

  /// The row's title, one label per kind of data.
  String _title(AppLocalizations l, DataDeletionCategory category) =>
      switch (category) {
        DataDeletionCategory.cases => l.settingsManageAccount_deleteDataCases,
        DataDeletionCategory.notes => l.settingsManageAccount_deleteDataNotes,
        DataDeletionCategory.caseReferences =>
          l.settingsManageAccount_deleteDataCaseReferences,
        DataDeletionCategory.customSeedData =>
          l.settingsManageAccount_deleteDataCustomSeedData,
      };
}
