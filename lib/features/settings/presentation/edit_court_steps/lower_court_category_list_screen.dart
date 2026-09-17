/// Lower Court Categories: the court categories that exist inside one district.
///
/// Reached from Settings → Edit Court/Steps → Lower Court Categories
/// (Divisions → Districts → Court Categories). Only the categories present in
/// the district are listed — a pre-seeded category with no court there is
/// hidden — and they appear in the same order as the Add/Edit Case form's
/// Court Category dropdown.
///
/// Rows reorder with drag & drop, rename through the edit dialog, and delete
/// only when the category was created by the user. The add button matches the
/// Add Case button (bottom-right, black, `+`) and creates a category scoped to
/// this district.
library;

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/constants/pre_seeded_data.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/l10n/app_translations.dart';
import '../../../../core/l10n/generated/app_localizations.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../database/app_database.dart';
import '../../../../shared/providers/locale_provider.dart';
import '../../../../shared/widgets/confirm_dialogs.dart';
import '../../data/court_categories_repository.dart';
import '../../data/courts_repository.dart';
import '../../data/district_court_categories.dart';
import '../settings_sub_page_modal.dart';

/// Court categories available inside a single division + district.
class LowerCourtCategoryListScreen extends ConsumerWidget {
  /// Division id (e.g. `dhaka`).
  final String division;

  /// District id (e.g. `dhaka`).
  final String district;

  const LowerCourtCategoryListScreen({
    super.key,
    required this.division,
    required this.district,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final isBn = locale.languageCode == 'bn';
    final districtLabel = isBn
        ? districtLabelBn[district] ?? district
        : districtLabelEn[district] ?? district;

    final courtsAsync = ref.watch(courtsRepositoryProvider);
    final categoriesAsync = ref.watch(courtCategoriesRepositoryProvider);
    final l = AppLocalizations.of(context);

    return SettingsSubPageModal(
      title: l.settingsLowerCourtCategories_title(districtLabel),
      subtitle: l.settingsEditCourtNames_lowerCourts,
      floatingActionButton: _buildAddButton(context, ref),
      child: _buildBody(context, courtsAsync, categoriesAsync),
    );
  }

  /// The Add Case style button: black circle, white `+`, bottom-right.
  Widget? _buildAddButton(BuildContext context, WidgetRef ref) {
    final courtsRepo = ref
        .watch(courtsRepositoryProvider)
        .whenOrNull(data: (repo) => repo);
    final categoriesRepo = ref
        .watch(courtCategoriesRepositoryProvider)
        .whenOrNull(data: (repo) => repo);
    if (courtsRepo == null || categoriesRepo == null) return null;

    return FloatingActionButton(
      onPressed: () => _addCategory(context, ref),
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      tooltip: AppLocalizations.of(
        context,
      ).settingsLowerCourtCategories_addTooltip,
      child: const Icon(Icons.add, size: 28),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AsyncValue<CourtsRepository> courtsAsync,
    AsyncValue<CourtCategoriesRepository> categoriesAsync,
  ) {
    final error = courtsAsync.error ?? categoriesAsync.error;
    if (error != null) {
      return Center(
        child: Text(
          AppLocalizations.of(context).sharedMessages_error('$error'),
        ),
      );
    }

    final courtsRepo = courtsAsync.whenOrNull(data: (repo) => repo);
    final categoriesRepo = categoriesAsync.whenOrNull(data: (repo) => repo);
    if (courtsRepo == null || categoriesRepo == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return _DistrictCategoryList(
      division: division,
      district: district,
      courtsRepo: courtsRepo,
      categoriesRepo: categoriesRepo,
    );
  }

  Future<void> _addCategory(BuildContext context, WidgetRef ref) async {
    final repo = ref
        .read(courtCategoriesRepositoryProvider)
        .whenOrNull(data: (repo) => repo);
    if (repo == null) return;

    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _CategoryEditDialog(isNew: true),
    );
    if (name == null || !context.mounted) return;

    final existing = await repo.listAll();
    await repo.insert(
      CourtCategoriesCompanion(
        nameKey: Value(name),
        courtLevel: const Value('lower'),
        orderIndex: Value(nextLowerCourtCategoryOrderIndex(existing)),
        division: Value(division),
        district: Value(district),
      ),
    );
  }
}

/// Reactive list of a district's court categories.
class _DistrictCategoryList extends ConsumerWidget {
  final String division;
  final String district;
  final CourtsRepository courtsRepo;
  final CourtCategoriesRepository categoriesRepo;

  const _DistrictCategoryList({
    required this.division,
    required this.district,
    required this.courtsRepo,
    required this.categoriesRepo,
  });

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) => StreamBuilder<List<CourtCategory>>(
    stream: categoriesRepo.watchAll(),
    builder: (context, categorySnapshot) {
      if (categorySnapshot.hasError) {
        return Center(
          child: Text(
            AppLocalizations.of(
              context,
            ).sharedMessages_error('${categorySnapshot.error}'),
          ),
        );
      }
      if (!categorySnapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final categories = categorySnapshot.data!;
      return StreamBuilder<List<Court>>(
        stream: courtsRepo.watchAll(),
        builder: (context, courtSnapshot) {
          if (courtSnapshot.hasError) {
            return Center(
              child: Text(
                AppLocalizations.of(
                  context,
                ).sharedMessages_error('${courtSnapshot.error}'),
              ),
            );
          }
          if (!courtSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = districtCourtCategories(
            categories: categories,
            courts: courtSnapshot.data!,
            division: division,
            district: district,
          );
          if (items.isEmpty) {
            return Center(
              child: Text(
                AppLocalizations.of(context).settingsLowerCourtCategories_empty,
              ),
            );
          }
          final canonical = categories
              .where((item) => item.courtLevel == 'lower')
              .toList(growable: false);
          return ReorderableListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: items.length,
            onReorderItem: (oldIndex, newIndex) =>
                _reorder(context, ref, items, canonical, oldIndex, newIndex),
            itemBuilder: (context, index) {
              final category = items[index];
              return _CategoryTile(
                key: ValueKey(category.id),
                category: category,
                label: _categoryLabel(context, category),
                onEdit: () => _rename(context, ref, category),
                // Built-in categories cannot be deleted; only what the user
                // added to this district can.
                onDelete: category.isCustom
                    ? () => _delete(context, ref, category)
                    : null,
              );
            },
          );
        },
      );
    },
  );

  /// Reorders only this district's categories, keeping the slots they already
  /// hold so other districts and the Add/Edit Case form keep their order.
  Future<void> _reorder(
    BuildContext context,
    WidgetRef ref,
    List<CourtCategory> items,
    List<CourtCategory> canonical,
    int oldIndex,
    int newIndex,
  ) async {
    if (oldIndex == newIndex) return;
    final reordered = List<CourtCategory>.from(items);
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex.clamp(0, reordered.length), moved);

    final targets = reorderedCategoryOrderIndexes(
      canonical: canonical,
      reordered: reordered,
    );
    for (final category in reordered) {
      final target = targets[category.id];
      if (target == null || target == category.orderIndex) continue;
      await categoriesRepo.update(
        CourtCategoriesCompanion(
          id: Value(category.id),
          orderIndex: Value(target),
        ),
        base: category,
      );
    }
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    CourtCategory category,
  ) async {
    final current = _categoryLabel(context, category);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _CategoryEditDialog(initialName: current),
    );
    if (name == null || !context.mounted || name == current) return;
    await categoriesRepo.update(
      CourtCategoriesCompanion(id: Value(category.id), nameKey: Value(name)),
      base: category,
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    CourtCategory category,
  ) async {
    if (!category.isCustom) return;
    final confirmed = await confirmDeleteDialog(context);
    if (!confirmed) return;
    await categoriesRepo.delete(category);
  }
}

/// Localized label for a category row.
///
/// Built-in categories store their localization key in `name_key`; categories
/// the user added store the typed name, which is shown as-is.
String _categoryLabel(BuildContext context, CourtCategory category) {
  final grouped = context.l10n.grouped;
  return grouped[AppStrings.lowerCourtCategoryGroup]?[category.nameKey] ??
      grouped[AppStrings.courtCategoryGroup]?[category.nameKey] ??
      category.nameKey;
}

/// A single reorderable court category row with edit (and custom-only) delete.
class _CategoryTile extends StatelessWidget {
  final CourtCategory category;
  final String label;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  const _CategoryTile({
    super.key,
    required this.category,
    required this.label,
    required this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.surfaceContainer),
      ),
      child: ListTile(
        leading: const Icon(Icons.drag_indicator, color: AppColors.tertiary),
        title: Text(label, style: AppTypography.bodyLg),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: onEdit,
              tooltip: l.sharedActions_edit,
            ),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.error),
                onPressed: onDelete,
                tooltip: l.sharedActions_delete,
              ),
          ],
        ),
      ),
    );
  }
}

/// Add/rename dialog for a court category.
class _CategoryEditDialog extends StatefulWidget {
  final String? initialName;
  final bool isNew;

  const _CategoryEditDialog({this.initialName, this.isNew = false});

  @override
  State<_CategoryEditDialog> createState() => _CategoryEditDialogState();
}

class _CategoryEditDialogState extends State<_CategoryEditDialog> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(
        widget.isNew
            ? l.settingsLowerCourtCategories_addTitle
            : l.settingsLowerCourtCategories_editTitle,
      ),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l.settingsLowerCourtCategories_nameLabel,
          ),
          validator: (value) => value == null || value.trim().isEmpty
              ? l.sharedDialogs_requiredField
              : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.sharedActions_cancel),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop(_controller.text.trim());
          },
          child: Text(l.sharedActions_save),
        ),
      ],
    );
  }
}
