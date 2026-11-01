/// Add/edit window for a case type: an English name, an optional Bengali name,
/// and — for the CJM and CMM categories — the district the type belongs to.
///
/// Only the district is stored. The division field narrows the district list
/// and is shown for orientation, because a district already identifies its
/// division.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/constants/pre_seeded_data.dart';
import '../../../../core/l10n/app_translations.dart';
import '../../../../core/l10n/generated/app_localizations.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../database/app_database.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../../../shared/widgets/app_dialog_actions.dart';
import '../../../../shared/widgets/custom_dropdown.dart';

/// The values the window returns to the list.
class CaseTypeDraft {
  const CaseTypeDraft({required this.name, this.nameBn, this.district});

  /// The English name stored in `case_types.name` and quoted by cases.
  final String name;

  /// The Bengali label, or null when the user left it blank.
  final String? nameBn;

  /// The district stable id, or null for a type shown in every district.
  final String? district;
}

/// Add/edit window for one case type.
///
/// Pops a [CaseTypeDraft], or `null` when the user cancels.
class CaseTypeNameDialog extends ConsumerStatefulWidget {
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
  ConsumerState<CaseTypeNameDialog> createState() => _CaseTypeNameDialogState();
}

class _CaseTypeNameDialogState extends ConsumerState<CaseTypeNameDialog> {
  // A null selection cannot be offered by CustomDropdown, so "All …" travels
  // as this sentinel and is turned back into null before saving.
  static const _allOption = '__all__';

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _englishController;
  late final TextEditingController _bengaliController;
  String? _division;
  String? _district;

  /// Null while the courts are loading; an empty list when they could not be
  /// read, in which case the type can still be saved as global.
  List<Court>? _courts;

  /// The district scope belongs to the magistrate categories only.
  bool get _showsDistrictScope =>
      widget.categoryId == chiefJudicialMagistrateId ||
      widget.categoryId == chiefMetropolitanMagistrateId;

  @override
  void initState() {
    super.initState();
    _englishController = TextEditingController(
      text: widget.initial?.name ?? '',
    );
    _bengaliController = TextEditingController(
      text: widget.initial?.nameBn ?? '',
    );
    _district = widget.initial?.district;
    _division = _divisionForDistrict(_district);
    if (_showsDistrictScope) _loadCourts();
  }

  @override
  void dispose() {
    _englishController.dispose();
    _bengaliController.dispose();
    super.dispose();
  }

  Future<void> _loadCourts() async {
    try {
      final repo = await ref.read(courtsRepositoryProvider.future);
      final courts = await repo.listAll();
      if (mounted) setState(() => _courts = courts);
    } catch (_) {
      if (mounted) setState(() => _courts = const <Court>[]);
    }
  }

  /// Districts that have a court in this category, in division order.
  List<String> get _courtDistricts {
    final courts = _courts;
    if (courts == null) return const <String>[];
    final present = <String>{
      for (final court in courts)
        if (court.courtCategoryId == widget.categoryId &&
            court.higherLowerCourts == lowerCourtsOption &&
            court.district != null)
          court.district!,
    };
    return <String>[
      for (final division in allDivisionIds)
        for (final district
            in districtIdsByDivision[division] ?? const <String>[])
          if (present.contains(district)) district,
    ];
  }

  List<String> get _divisionOptions {
    final districts = _courtDistricts.toSet();
    return <String>[
      for (final division in allDivisionIds)
        if ((districtIdsByDivision[division] ?? const <String>[]).any(
          districts.contains,
        ))
          division,
    ];
  }

  List<String> get _districtOptions {
    final division = _division;
    if (division == null) return _courtDistricts;
    final inDivision = (districtIdsByDivision[division] ?? const <String>[])
        .toSet();
    return _courtDistricts.where(inDivision.contains).toList(growable: false);
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
              key: const ValueKey('case-type-english-name'),
              controller: _englishController,
              autofocus: true,
              style: AppTypography.bodyLg,
              decoration: InputDecoration(
                labelText: l.settingsItemList_englishNameLabel,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.md,
                ),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? l.sharedDialogs_requiredField
                  : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              key: const ValueKey('case-type-bengali-name'),
              controller: _bengaliController,
              style: AppTypography.bodyLg,
              decoration: InputDecoration(
                labelText: l.settingsItemList_bengaliNameLabel,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.md,
                ),
              ),
            ),
            if (_showsDistrictScope) ...[
              const SizedBox(height: AppSpacing.md),
              if (_courts == null)
                const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else ...[
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
            final bengali = _bengaliController.text.trim();
            Navigator.of(dialogContext).pop(
              CaseTypeDraft(
                name: _englishController.text.trim(),
                nameBn: bengali.isEmpty ? null : bengali,
                district: _district,
              ),
            );
          },
        ),
      ],
    );
  }
}
