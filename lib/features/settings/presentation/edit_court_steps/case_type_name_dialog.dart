/// Add/edit window for a case type: an English name, an optional Bengali name,
/// and — for the CJM and CMM categories — the district the type belongs to.
///
/// Only the district is stored. The division narrows the district list to all
/// districts of that division, because a district already identifies its
/// division; it does not depend on which courts are seeded.
library;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/constants/pre_seeded_data.dart';
import '../../../../core/l10n/app_translations.dart';
import '../../../../core/l10n/generated/app_localizations.dart';
import '../../../../database/app_database.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../../../shared/widgets/app_dialog_actions.dart';
import '../../../../shared/widgets/custom_dropdown.dart';

/// The values the window returns to the list.
class CaseTypeDraft {
  const CaseTypeDraft({required this.name, this.district});

  /// The name stored in `case_types.name` and quoted by cases.
  final String name;

  /// The district stable id, or null for a type shown in every district.
  final String? district;
}

/// Add/edit window for one case type.
///
/// Pops a [CaseTypeDraft], or `null` when the user cancels.
class CaseTypeNameDialog extends StatefulWidget {
  /// Window title, e.g. "Add Item".
  final String title;

  /// The court category the type belongs to.
  final String categoryId;

  /// The row being edited; null when adding.
  final CaseType? initial;

  const CaseTypeNameDialog({
    super.key,
    required this.title,
    required this.categoryId,
    this.initial,
  });

  @override
  State<CaseTypeNameDialog> createState() => _CaseTypeNameDialogState();
}

class _CaseTypeNameDialogState extends State<CaseTypeNameDialog> {
  // A null selection cannot be offered by CustomDropdown, so "All …" travels
  // as this sentinel and is turned back into null before saving.
  static const _allOption = '__all__';

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  String? _division;
  String? _district;

  /// The district scope belongs to the magistrate categories only.
  bool get _showsDistrictScope =>
      widget.categoryId == chiefJudicialMagistrateId ||
      widget.categoryId == chiefMetropolitanMagistrateId;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initial?.name ?? '');
    _district = widget.initial?.district;
    _division = _divisionForDistrict(_district);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Every division is offered, even one with no court in this category.
  List<String> get _divisionOptions => allDivisionIds;

  /// Every district of the selected division. With All Divisions selected the
  /// list is the whole country, in division order. This is the geographic list,
  /// not the districts that happen to have a seeded court in the category.
  List<String> get _districtOptions {
    final division = _division;
    if (division != null) {
      return districtIdsByDivision[division] ?? const <String>[];
    }
    return <String>[
      for (final id in allDivisionIds)
        ...districtIdsByDivision[id] ?? const <String>[],
    ];
  }

  String? _divisionForDistrict(String? district) {
    if (district == null) return null;
    for (final entry in districtIdsByDivision.entries) {
      if (entry.value.contains(district)) return entry.key;
    }
    return null;
  }

  String _divisionLabel(BuildContext context, String id) =>
      context.l10n.seedLabel(id, fallbackEn: divisionLabelEn[id] ?? id);

  String _districtLabel(BuildContext context, String id) =>
      context.l10n.seedLabel(id, fallbackEn: districtLabelEn[id] ?? id);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AppDialogFrame(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xl,
      ),
      titlePadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md,
      ),
      title: Text(widget.title, style: AppTypography.titleLg),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              key: const ValueKey('case-type-name'),
              controller: _nameController,
              autofocus: true,
              style: AppTypography.bodyLg,
              decoration: InputDecoration(
                labelText: l.settingsItemList_nameLabel,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.md,
                ),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? l.sharedDialogs_requiredField
                  : null,
            ),
            if (_showsDistrictScope) ...[
              const SizedBox(height: AppSpacing.md),
              CustomDropdown<String>(
                fieldKey: const ValueKey('case-type-division'),
                label: l.addEditCaseSheet_division,
                modalTitle: l.addEditCaseSheet_division,
                items: <String>[_allOption, ..._divisionOptions],
                value: _division ?? _allOption,
                itemLabel: (id) => id == _allOption
                    ? l.settingsItemList_allDivisions
                    : _divisionLabel(context, id),
                outlined: true,
                emptyFillColor: AppColors.surface,
                selectedFillColor: AppColors.surfaceVariant,
                onChanged: (value) => setState(() {
                  _division = value == _allOption ? null : value;
                  _district = null;
                }),
              ),
              const SizedBox(height: AppSpacing.md),
              CustomDropdown<String>(
                fieldKey: const ValueKey('case-type-district'),
                label: l.addEditCaseSheet_district,
                modalTitle: l.addEditCaseSheet_district,
                items: <String>[_allOption, ..._districtOptions],
                value: _district ?? _allOption,
                itemLabel: (id) => id == _allOption
                    ? l.settingsItemList_allDistricts
                    : _districtLabel(context, id),
                outlined: true,
                emptyFillColor: AppColors.surface,
                selectedFillColor: AppColors.surfaceVariant,
                onChanged: (value) => setState(
                  () => _district = value == _allOption ? null : value,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: (dialogContext) => [
        AppDialogAction(
          label: l.sharedActions_cancel,
          onPressed: () => Navigator.of(dialogContext).pop(),
        ),
        AppDialogAction(
          label: l.sharedActions_save,
          kind: AppDialogActionKind.primary,
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(dialogContext).pop(
              CaseTypeDraft(
                name: _nameController.text.trim(),
                district: _district,
              ),
            );
          },
        ),
      ],
    );
  }
}
