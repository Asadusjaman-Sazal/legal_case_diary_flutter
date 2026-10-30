/// The statute picker: every law name, grouped under its category.
///
/// The app's dropdown pickers are their own window pattern — a black title band,
/// a search field and a list — rather than the shared centred frame, and rule 17
/// names dropdown menus among its deliberate exceptions. This one follows that
/// pattern and adds two things the reference form needs: **category headings**,
/// so the 57 names read as seven short lists instead of one long one, and a
/// final **Add a Law Name…** row that opens the shared add/edit window.
///
/// The screen and the settings page both use [groupLaws], so the picker, the
/// Case Reference screen and Edit Law Names cannot disagree about a category's
/// order or its member rows.
library;

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/constants/pre_seeded_data.dart';
import '../../../core/l10n/app_translations.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../database/app_database.dart';

/// One category's laws, ready to render under its heading.
class LawGroup {
  /// Creates a group; [categoryId] is empty for the trailing "other" group.
  const LawGroup({required this.categoryId, required this.laws});

  /// One of the seven stable IDs, or an empty string for unknown/blank rows.
  final String categoryId;

  /// The group's laws, in display order.
  final List<Law> laws;
}

/// Groups [laws] by category, in the seeded category order.
///
/// Within a group the order is `order_index` then the name, which is exactly what
/// the picker, the grouped screen and the settings list show. A row whose
/// category is blank or unknown — one written before categories existed — keeps
/// its place in a single trailing group, labelled **Other**, instead of
/// disappearing from every list.
List<LawGroup> groupLaws(Iterable<Law> laws) {
  final byCategory = <String, List<Law>>{};
  for (final law in laws) {
    byCategory.putIfAbsent(law.category, () => <Law>[]).add(law);
  }
  for (final rows in byCategory.values) {
    rows.sort((a, b) {
      final byOrder = a.orderIndex.compareTo(b.orderIndex);
      return byOrder != 0 ? byOrder : a.name.compareTo(b.name);
    });
  }

  final groups = <LawGroup>[];
  for (final category in seedLawCategories) {
    final rows = byCategory.remove(category.id);
    if (rows != null && rows.isNotEmpty) {
      groups.add(LawGroup(categoryId: category.id, laws: rows));
    }
  }
  // Anything left over: blank or unknown ids, plus an id a newer release wrote.
  final other = <Law>[];
  for (final rows in byCategory.values) {
    other.addAll(rows);
  }
  if (other.isNotEmpty) {
    other.sort((a, b) {
      final byOrder = a.orderIndex.compareTo(b.orderIndex);
      return byOrder != 0 ? byOrder : a.name.compareTo(b.name);
    });
    groups.add(LawGroup(categoryId: '', laws: other));
  }
  return groups;
}

/// What the picker returned: a chosen law, or the request to add one.
class LawPick {
  const LawPick.law(Law this.law) : addNew = false;
  const LawPick.addNew() : law = null, addNew = true;

  /// The chosen law, when one was tapped.
  final Law? law;

  /// True when the **Add a Law Name…** row was tapped.
  final bool addNew;
}

/// Shows the grouped picker; null means the user closed it.
Future<LawPick?> showLawPicker(
  BuildContext context, {
  required List<Law> laws,
  Law? selected,
}) {
  return showDialog<LawPick>(
    context: context,
    barrierColor: AppColors.overlay54,
    builder: (context) => _LawPickerDialog(laws: laws, selected: selected),
  );
}

class _LawPickerDialog extends StatefulWidget {
  const _LawPickerDialog({required this.laws, this.selected});

  final List<Law> laws;
  final Law? selected;

  @override
  State<_LawPickerDialog> createState() => _LawPickerDialogState();
}

class _LawPickerDialogState extends State<_LawPickerDialog> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<LawGroup> get _groups {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? widget.laws
        : widget.laws
              .where((law) => law.name.toLowerCase().contains(query))
              .toList(growable: false);
    return groupLaws(filtered);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final size = MediaQuery.sizeOf(context);
    final groups = _groups;

    return Dialog(
      insetPadding: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius * 2),
      ),
      child: SizedBox(
        key: const ValueKey('law-picker-dialog'),
        width: size.width * .92,
        height: size.height * .9,
        child: Material(
          color: AppColors.surfaceContainerLowest,
          child: SafeArea(
            child: Column(
              children: [
                _titleBar(context, l.caseReferenceScreen_chooseLaw),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: SizedBox(
                    height: 48,
                    child: TextField(
                      key: const ValueKey('law-picker-search'),
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: l.customDropdown_search,
                        hintStyle: AppTypography.bodySm.copyWith(
                          color: AppColors.tertiary,
                        ),
                        prefixIcon: const Icon(Icons.search),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
                Expanded(child: _list(context, l, groups)),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      key: const ValueKey('law-picker-close'),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.black),
                        minimumSize: const Size.fromHeight(60),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        MaterialLocalizations.of(context).closeButtonLabel,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The app's picker band: black, centred title, close at the right.
  Widget _titleBar(BuildContext context, String title) => Container(
    key: const ValueKey('law-picker-title-bar'),
    width: double.infinity,
    height: 60,
    color: Colors.black,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 56),
          child: Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.titleLg.copyWith(color: Colors.white),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: IconButton(
            key: const ValueKey('law-picker-close-icon'),
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: () => Navigator.of(context).pop(),
            color: Colors.white,
            icon: const Icon(Icons.close),
          ),
        ),
      ],
    ),
  );

  Widget _list(
    BuildContext context,
    AppLocalizations l,
    List<LawGroup> groups,
  ) {
    final rows = <Widget>[];
    for (final group in groups) {
      rows.add(
        Padding(
          key: ValueKey('law-group-${group.categoryId}'),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.xs,
          ),
          child: Text(
            // The heading translates; the law names themselves do not (the
            // seeded list mixes English and বাংলা). An unknown or blank id
            // resolves to Other rather than to a machine key.
            context.l10n.lawCategoryName(group.categoryId),
            style: AppTypography.labelLg.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
      );
      for (final law in group.laws) {
        final selected = law.id == widget.selected?.id;
        rows.add(
          ListTile(
            key: ValueKey('law-option-${law.id}'),
            title: Text(law.name),
            selected: selected,
            selectedColor: AppColors.secondary,
            trailing: selected
                ? const Icon(Icons.check, color: AppColors.secondary)
                : null,
            onTap: () => Navigator.of(context).pop(LawPick.law(law)),
          ),
        );
      }
    }

    if (rows.isEmpty) {
      rows.add(
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Center(child: Text(l.customDropdown_noResults)),
        ),
      );
    }

    rows.add(const Divider(height: 1));
    rows.add(
      ListTile(
        key: const ValueKey('law-picker-add'),
        leading: const Icon(Icons.add),
        title: Text(
          l.caseReferenceScreen_addLawName,
          style: AppTypography.bodyLg.copyWith(
            color: AppColors.secondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        onTap: () => Navigator.of(context).pop(const LawPick.addNew()),
      ),
    );

    return ListView(
      key: const ValueKey('law-picker-list'),
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      children: rows,
    );
  }
}
