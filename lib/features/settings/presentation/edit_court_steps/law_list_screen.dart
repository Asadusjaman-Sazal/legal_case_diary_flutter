/// Settings → Edit Court/Steps → Law Names.
///
/// Two levels, exactly like the court list it sits beside: the seven law
/// categories first (`criminal_law`, `family_personal_law`, …), then the names
/// inside the one that was tapped. The category headings translate through
/// [AppTranslations.lawCategoryName], so বাংলা readers see seven বাংলা headings
/// while each law keeps the name it was seeded with.
///
/// A built-in name may be reordered but never renamed or deleted; only a name
/// the user or their firm added carries Edit and Delete, which is the same rule
/// the courts, steps and case types follow. Adding a name here and adding one
/// from the Add Case Reference window write the same row.
library;

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/l10n/app_translations.dart';
import '../../../../core/l10n/generated/app_localizations.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../core/router/app_router.dart';
import '../../../../database/app_database.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../../../shared/widgets/app_dialog_actions.dart';
import '../../../case_reference/presentation/law_name_dialog.dart';
import '../../../case_reference/presentation/law_picker.dart';
import '../../data/laws_repository.dart';
import '../settings_menu_card.dart';
import '../settings_sub_page_modal.dart';
import 'next_order_index.dart';

/// Law Names page: categories when [categoryId] is null, one category's rows
/// otherwise. The route passes `?category=<id>` for the second level.
class LawNamesScreen extends ConsumerWidget {
  const LawNamesScreen({super.key, this.categoryId});

  /// One of the seven stable category IDs, or null for the category list.
  final String? categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final title = categoryId == null
        ? l.settingsEditCourtSteps_lawNames
        : context.l10n.lawCategoryName(categoryId!);
    final repoAsync = ref.watch(lawsRepositoryProvider);

    return repoAsync.when(
      loading: () => SettingsSubPageModal(
        title: title,
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => SettingsSubPageModal(
        title: title,
        child: Center(child: Text(l.sharedMessages_error('$e'))),
      ),
      data: (repo) => SettingsSubPageModal(
        title: title,
        // Only a category page adds a name; the category list has nothing to
        // add to, because a category is a heading rather than a row.
        floatingActionButton: categoryId == null
            ? null
            : FloatingActionButton(
                key: const ValueKey('law-names-add'),
                onPressed: () => _addName(context, ref, repo, categoryId!),
                // The Add Case button, exactly.
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                tooltip: l.lawNamesScreen_addTitle,
                child: const Icon(Icons.add, size: 28),
              ),
        child: StreamBuilder<List<Law>>(
          stream: repo.watchAll(),
          builder: (context, snapshot) {
            final laws = snapshot.data ?? const <Law>[];
            return categoryId == null
                ? _CategoryList(laws: laws)
                : _LawList(repo: repo, laws: laws, categoryId: categoryId!);
          },
        ),
      ),
    );
  }

  /// Adds a name in the category the user is looking at, then leaves it there.
  Future<void> _addName(
    BuildContext context,
    WidgetRef ref,
    LawsRepository repo,
    String categoryId,
  ) async {
    final draft = await showLawNameDialog(
      context,
      initialCategoryId: categoryId,
    );
    if (draft == null || !context.mounted) return;
    final existing = await repo.listAll();
    await repo.insert(
      LawsCompanion(
        name: Value(draft.name),
        category: Value(draft.categoryId),
        orderIndex: Value(
          nextOrderIndex(
            existing
                .where((law) => law.category == draft.categoryId)
                .map((law) => law.orderIndex),
          ),
        ),
      ),
    );
  }
}

/// The seven category cards, in seed order, with how many names each holds.
class _CategoryList extends StatelessWidget {
  const _CategoryList({required this.laws});

  final List<Law> laws;

  @override
  Widget build(BuildContext context) {
    final groups = groupLaws(laws);
    final l = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        if (groups.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xl),
            child: Center(child: Text(l.lawNamesScreen_empty)),
          ),
        for (var i = 0; i < groups.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          SettingsMenuCard(
            key: ValueKey(
              groups[i].categoryId.isEmpty
                  ? 'law-category-other'
                  : 'law-category-${groups[i].categoryId}',
            ),
            icon: _iconFor(groups[i].categoryId),
            title: context.l10n.lawCategoryName(groups[i].categoryId),
            onTap: () => context.push(
              groups[i].categoryId.isEmpty
                  ? '${AppRoutes.settingsLawNames}?category=other'
                  : '${AppRoutes.settingsLawNames}?category=${groups[i].categoryId}',
            ),
            trailing: Text(
              '${groups[i].laws.length}',
              style: AppTypography.bodySm.copyWith(color: AppColors.tertiary),
            ),
          ),
        ],
      ],
    );
  }

  /// One outline icon per heading, so seven identical rows stay scannable.
  IconData _iconFor(String categoryId) => switch (categoryId) {
    'constitution_courts_practice' => Icons.account_balance_outlined,
    'civil_procedure_evidence' => Icons.description_outlined,
    'contract_land_property_business' => Icons.handshake_outlined,
    'family_personal_law' => Icons.family_restroom_outlined,
    'criminal_law' => Icons.gavel_outlined,
    'tax_finance' => Icons.receipt_long_outlined,
    'labour_everyday_regulation' => Icons.work_outline,
    _ => Icons.menu_book_outlined,
  };
}

/// One category's names: drag to reorder; edit and delete only a user-added
/// row.
class _LawList extends StatelessWidget {
  const _LawList({
    required this.repo,
    required this.laws,
    required this.categoryId,
  });

  final LawsRepository repo;
  final List<Law> laws;

  /// The route's category id; `other` stands for the blank/unknown group.
  final String categoryId;

  String get _resolvedCategoryId => categoryId == 'other' ? '' : categoryId;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // The category page's own group. A category with no rows yet — a heading
    // whose names were all removed — simply shows the empty state.
    var rows = const <Law>[];
    for (final group in groupLaws(laws)) {
      if (group.categoryId == _resolvedCategoryId) {
        rows = group.laws;
        break;
      }
    }

    if (rows.isEmpty) {
      return Center(child: Text(l.lawNamesScreen_empty));
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: rows.length,
      onReorderItem: (oldIndex, newIndex) => _reorder(rows, oldIndex, newIndex),
      itemBuilder: (context, index) {
        final law = rows[index];
        return Card(
          key: ValueKey(law.id),
          elevation: 0,
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppColors.surfaceContainer),
          ),
          child: ListTile(
            leading: const Icon(
              Icons.drag_indicator,
              color: AppColors.tertiary,
            ),
            title: Text(law.name, style: AppTypography.bodyLg),
            // A built-in law is part of the app's shared vocabulary: it keeps
            // its name and cannot be removed from here (user request). Only a
            // name the user added can be edited or deleted.
            trailing: law.isCustom
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _edit(context, law),
                        tooltip: l.sharedActions_edit,
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: AppColors.error,
                        ),
                        onPressed: () => _delete(context, law),
                        tooltip: l.sharedActions_delete,
                      ),
                    ],
                  )
                : null,
          ),
        );
      },
    );
  }

  Future<void> _edit(BuildContext context, Law law) async {
    final draft = await showLawNameDialog(
      context,
      editing: true,
      initialName: law.name,
      initialCategoryId: law.category.isEmpty ? categoryId : law.category,
    );
    if (draft == null) return;
    await repo.update(
      LawsCompanion(
        id: Value(law.id),
        name: Value(draft.name),
        category: Value(draft.categoryId),
      ),
      base: law,
    );
  }

  Future<void> _delete(BuildContext context, Law law) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showAppDialog<bool>(
      context,
      title: Text(l.settingsItemList_deleteTitle, textAlign: TextAlign.center),
      content: Text(l.settingsItemList_deleteMessage),
      actions: (dialogContext) => [
        AppDialogAction(
          label: l.sharedActions_cancel,
          onPressed: () => Navigator.of(dialogContext).pop(false),
        ),
        AppDialogAction(
          label: l.sharedActions_delete,
          kind: AppDialogActionKind.destructive,
          onPressed: () => Navigator.of(dialogContext).pop(true),
        ),
      ],
    );
    if (confirmed == true) await repo.delete(law);
  }

  /// Reorders the rows the user sees and writes back their slots.
  ///
  /// The rows keep the `order_index` values this group already held, sorted and
  /// handed out in the new order. Renumbering the whole law table would touch
  /// the six other groups' rows and queue fifty sync writes for one drag, while
  /// reusing the group's own slots keeps every other category untouched and
  /// cannot collide with it.
  Future<void> _reorder(List<Law> rows, int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;
    final reordered = List<Law>.from(rows);
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);
    final slots = rows.map((law) => law.orderIndex).toList()..sort();
    for (var i = 0; i < reordered.length; i++) {
      if (reordered[i].orderIndex == slots[i]) continue;
      await repo.update(
        LawsCompanion(id: Value(reordered[i].id), orderIndex: Value(slots[i])),
        base: reordered[i],
      );
    }
  }
}
