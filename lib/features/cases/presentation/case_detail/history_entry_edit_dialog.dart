/// History entry Edit dialog: long-press action from the Case Detail screen.
///
/// Task 10 Phase 2. Edits the values a history row displays — the hearing
/// date on the left (stored as `hearing_date`, the case's previous next date),
/// the court step (`last_step`), and the note/result (`note_result`). Saves
/// through `caseHistoryRepositoryProvider` so sync columns and `sync_queue`
/// stay consistent. The row's `next_date` ordering key is intentionally left
/// untouched.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart' hide Step;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/constants/pre_seeded_data.dart';
import '../../../../core/l10n/app_translations.dart';
import '../../../../core/l10n/generated/app_localizations.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../database/app_database.dart';
import '../../../../features/settings/data/local/courts_dao.dart';
import '../../../../features/settings/data/local/steps_dao.dart';
import '../../../../shared/providers/database_provider.dart';
import '../../../../shared/widgets/custom_dropdown.dart';
import '../../../../shared/widgets/date_picker_helper.dart';

/// Modal form for editing one procedural history entry.
class HistoryEntryEditDialog extends ConsumerStatefulWidget {
  /// Creates the dialog for [entry] of [caseData].
  const HistoryEntryEditDialog({
    required this.entry,
    required this.caseData,
    super.key,
  });

  /// History entry being edited.
  final CaseHistoryRow entry;

  /// Parent case, used to filter Steps by its court category.
  final Case caseData;

  /// Shows the dialog and returns when the repository update completes.
  static Future<void> show(
    BuildContext context, {
    required CaseHistoryRow entry,
    required Case caseData,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (context) =>
          HistoryEntryEditDialog(entry: entry, caseData: caseData),
    );
  }

  @override
  ConsumerState<HistoryEntryEditDialog> createState() =>
      _HistoryEntryEditDialogState();
}

class _HistoryEntryEditDialogState
    extends ConsumerState<HistoryEntryEditDialog> {
  final _noteController = TextEditingController();
  final _resultController = TextEditingController();
  DateTime? _date;
  List<Step> _steps = const [];
  List<Step> _selectedSteps = const [];
  bool _isHigherCourt = false;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Next Date starts at the date shown on the row (the previous next date).
    _date = DateTime.fromMillisecondsSinceEpoch(widget.entry.hearingDate);
    _noteController.text = widget.entry.noteResult ?? '';
    _resultController.text = widget.entry.result ?? '';
    _loadSteps();
  }

  @override
  void dispose() {
    _noteController.dispose();
    _resultController.dispose();
    super.dispose();
  }

  /// Steps are category-filtered exactly like the Quick Update window: they
  /// come from the court category of the case's court.
  Future<void> _loadSteps() async {
    try {
      final db = await ref.read(databaseProvider.future);
      final court = await CourtsDao(db).getById(widget.caseData.courtId);
      final steps = court == null
          ? <Step>[]
          : await StepsDao(db).getByCategory(court.courtCategoryId);
      if (!mounted) return;
      setState(() {
        _steps = steps;
        // AD/HCD courts expose no Steps; their rows show the Result snapshot
        // instead, so the dialog offers a Result box for exactly those cases.
        _isHigherCourt =
            court != null &&
            (court.courtCategoryId == appellateDivisionId ||
                court.courtCategoryId == highCourtDivisionId);
        final storedSteps = (widget.entry.lastStep ?? '')
            .split(',')
            .map((step) => step.trim())
            .where((step) => step.isNotEmpty)
            .toSet();
        _selectedSteps = steps
            .where(
              (item) =>
                  storedSteps.contains(item.id) ||
                  storedSteps.contains(item.stepName),
            )
            .toList(growable: false);
        _loading = false;
      });
    } catch (_) {
      // Without steps the form still edits date and note; the step field is
      // hidden below when the category offers no steps.
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate() async {
    final date = await showPlainDatePicker(
      context,
      initialDate: _date,
      styleActions: true,
    );
    if (date != null && mounted) setState(() => _date = date);
  }

  String _formatDate(BuildContext context, DateTime date) => DateFormat(
    'dd/MM/yy, EEE',
    Localizations.localeOf(context).toLanguageTag(),
  ).format(date);

  Future<void> _commit() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final repository = await ref.read(caseHistoryRepositoryProvider.future);
      final note = _noteController.text.trim();
      final result = _resultController.text.trim();
      final hearingMs = _date!.millisecondsSinceEpoch;
      if (_steps.isEmpty) {
        // AD/HCD-style categories expose no Steps list. For AD/HCD cases the
        // row's main content is the Result snapshot, so expose it for editing;
        // otherwise leave the stored step untouched rather than infer one.
        await repository.updateHistory(
          CaseHistoryCompanion(
            id: Value(widget.entry.id),
            hearingDate: Value(hearingMs),
            noteResult: Value<String?>(
              note.isEmpty ? null : note,
            ),
            result: _isHigherCourt
                ? Value<String?>(result.isEmpty ? null : result)
                : const Value<String?>.absent(),
          ),
          baseEntry: widget.entry,
        );
      } else {
        await repository.updateHistory(
          CaseHistoryCompanion(
            id: Value(widget.entry.id),
            hearingDate: Value(hearingMs),
            lastStep: Value<String?>(
              _selectedSteps.isEmpty
                  ? null
                  : _selectedSteps.map((item) => item.stepName).join(','),
            ),
            noteResult: Value<String?>(
              note.isEmpty ? null : note,
            ),
          ),
          baseEntry: widget.entry,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save the history entry: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Material(
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        color: AppColors.surfaceContainerLowest,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 680),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                color: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 40),
                    Expanded(
                      child: Text(
                        l.caseDetailsScreen_editHistoryEntry,
                        textAlign: TextAlign.center,
                        style: AppTypography.titleLg.copyWith(
                          color: AppColors.onPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).closeButtonTooltip,
                      onPressed: () => Navigator.of(context).pop(),
                      color: AppColors.onPrimary,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              if (_loading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withValues(alpha: .06),
                            borderRadius: BorderRadius.circular(
                              AppSpacing.cardRadius,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '${widget.caseData.caseType} ${widget.caseData.caseNumber}',
                                key: const ValueKey(
                                  'history-edit-case-number',
                                ),
                                style: AppTypography.titleLg.copyWith(
                                  color: AppColors.primary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                '${l.caseDetailsScreen_editHistoryEntry}: ${_formatDate(context, _date!)}',
                                style: AppTypography.bodySm,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          l.addEditCaseSheet_nextDate,
                          style: AppTypography.labelLg,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        InkWell(
                          key: const ValueKey('history-edit-next-date'),
                          onTap: _saving ? null : _pickDate,
                          child: InputDecorator(
                            isEmpty: false,
                            decoration: InputDecoration(
                              fillColor: AppColors.surfaceVariant,
                              enabledBorder: const UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: AppColors.outlineVariant,
                                ),
                              ),
                              suffixIcon: const Icon(
                                Icons.calendar_month_outlined,
                              ),
                            ),
                            child: Text(
                              _formatDate(context, _date!),
                              style: AppTypography.bodyMd.copyWith(
                                color: AppColors.onSurface,
                              ),
                            ),
                          ),
                        ),
                        if (_steps.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.md),
                          CustomDropdown<Step>(
                            fieldKey: const ValueKey('history-edit-step'),
                            label: l.addEditCaseSheet_step,
                            items: _steps,
                            selectedValues: _selectedSteps,
                            multiSelect: true,
                            itemLabel: (item) => context.l10n.seedLabel(
                              item.id,
                              fallbackEn: item.stepName,
                            ),
                            enabled: !_saving,
                            emptyFillColor: AppColors.surface,
                            selectedFillColor: AppColors.surfaceVariant,
                            outlined: true,
                            onMultiChanged: (values) => setState(
                              () => _selectedSteps = values,
                            ),
                          ),
                        ],
                        if (_isHigherCourt) ...[
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            l.addEditCaseSheet_result,
                            style: AppTypography.labelLg,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          TextField(
                            key: const ValueKey('history-edit-result'),
                            controller: _resultController,
                            enabled: !_saving,
                            maxLines: 3,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: _resultController.text.trim().isEmpty
                                  ? AppColors.surface
                                  : AppColors.surfaceVariant,
                              isCollapsed: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.sm,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              focusedErrorBorder: InputBorder.none,
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          l.addEditCaseSheet_note,
                          style: AppTypography.labelLg,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        TextField(
                          key: const ValueKey('history-edit-note'),
                          controller: _noteController,
                          enabled: !_saving,
                          maxLines: 4,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: _noteController.text.trim().isEmpty
                                ? AppColors.surface
                                : AppColors.surfaceVariant,
                            isCollapsed: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppColors.outlineVariant),
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const ValueKey('history-edit-save'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                    ),
                    onPressed: _loading || _saving ? null : _commit,
                    child: Text(l.sharedActions_save),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
