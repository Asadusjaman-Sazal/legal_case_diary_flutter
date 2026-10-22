/// Generic managed-item list for Case Types / Steps / On Behalf under a court
/// category. Reached from [CourtNamesStepsScreen] with `?kind=` and
/// `?category=` query params. Supports reorder, edit, soft-delete (custom only),
/// and FAB add. Reuses the shared edit dialog pattern.
library;

import 'package:drift/drift.dart' hide isNotNull;
import 'package:flutter/material.dart' hide Step;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/l10n/app_translations.dart';
import '../../../../core/l10n/generated/app_localizations.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../database/app_database.dart';
import '../../data/case_types_repository.dart';
import '../../data/on_behalfs_repository.dart';
import '../../data/reference_in_use_checker.dart';
import '../../data/steps_repository.dart';
import '../settings_sub_page_modal.dart';
import 'edit_name_dialog.dart';
import 'next_order_index.dart';

/// Which kind of item this list manages.
enum ItemKind { caseTypes, steps, onBehalf }

/// Parse a `?kind=` query value into [ItemKind].
ItemKind itemKindFromParam(String? value) => switch (value) {
  'case_types' => ItemKind.caseTypes,
  'steps' => ItemKind.steps,
  _ => ItemKind.onBehalf,
};

/// Localized title for a kind.
String itemKindTitle(AppLocalizations l, ItemKind kind) => switch (kind) {
  ItemKind.caseTypes => l.settingsEditItems_caseTypes,
  ItemKind.steps => l.settingsEditItems_steps,
  ItemKind.onBehalf => l.settingsEditItems_onBehalf,
};

/// Generic item list screen (Case Types / Steps / On Behalf).
class ItemListScreen extends ConsumerWidget {
  final ItemKind kind;
  final String categoryId;

  const ItemListScreen({
    super.key,
    required this.kind,
    required this.categoryId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final title =
        '${itemKindTitle(l, kind)} — ${_categoryShortLabel(l, categoryId)}';

    switch (kind) {
      case ItemKind.caseTypes:
        final repoAsync = ref.watch(caseTypesRepositoryProvider);
        return SettingsSubPageModal(
          title: title,
          floatingActionButton: repoAsync.whenOrNull(
            data: (repo) => FloatingActionButton(
              onPressed: () => _add(context, ref, repo),
              child: const Icon(Icons.add),
            ),
          ),
          child: repoAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(l.sharedMessages_error('$e'))),
            data: (repo) =>
                _CaseTypeListView(repo: repo, categoryId: categoryId),
          ),
        );
      case ItemKind.steps:
        final repoAsync = ref.watch(stepsRepositoryProvider);
        return SettingsSubPageModal(
          title: title,
          floatingActionButton: repoAsync.whenOrNull(
            data: (repo) => FloatingActionButton(
              onPressed: () => _add(context, ref, repo),
              child: const Icon(Icons.add),
            ),
          ),
          child: repoAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(l.sharedMessages_error('$e'))),
            data: (repo) => _StepListView(repo: repo, categoryId: categoryId),
          ),
        );
      case ItemKind.onBehalf:
        final repoAsync = ref.watch(onBehalfsRepositoryProvider);
        return SettingsSubPageModal(
          title: title,
          floatingActionButton: repoAsync.whenOrNull(
            data: (repo) => FloatingActionButton(
              onPressed: () => _add(context, ref, repo),
              child: const Icon(Icons.add),
            ),
          ),
          child: repoAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(l.sharedMessages_error('$e'))),
            data: (repo) =>
                _OnBehalfListView(repo: repo, categoryId: categoryId),
          ),
        );
    }
  }

  String _categoryShortLabel(AppLocalizations l, String id) =>
      {
        'appellate_division': l.settingsItemList_catAppellate,
        'high_court_division': l.settingsItemList_catHighCourt,
        'district_sessions_criminal': l.settingsItemList_catSessions,
        'district_courts_civil': l.settingsItemList_catDistrictCivil,
        'metropolitan_sessions_judge_criminal':
            l.settingsItemList_catMetropolitanSessions,
        'chief_judicial_magistrate': l.settingsItemList_catCjm,
        'chief_metropolitan_magistrate': l.settingsItemList_catCmm,
        'executive_magistrate': l.settingsItemList_catExecutive,
        'tribunals': l.settingsItemList_catTribunals,
      }[id] ??
      id;

  // Separate typed add/edit callbacks keep the repository generics concrete.
  Future<void> _add(BuildContext context, WidgetRef ref, dynamic repo) async {
    final l = AppLocalizations.of(context);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => EditNameDialog(
        title: l.settingsItemList_addTitle,
        fieldLabel: l.settingsItemList_nameLabel,
      ),
    );
    if (name == null || !context.mounted) return;
    // The new row takes the slot after the rows already in this list, so it
    // lands at the end instead of tying with the first one.
    if (repo is CaseTypesRepository) {
      final existing = await repo.listByCategory(categoryId);
      await repo.insert(
        CaseTypesCompanion(
          courtCategoryId: Value(categoryId),
          name: Value(name),
          orderIndex: Value(
            nextOrderIndex(existing.map((item) => item.orderIndex)),
          ),
        ),
      );
    } else if (repo is StepsRepository) {
      final existing = await repo.listByCategory(categoryId);
      await repo.insert(
        StepsCompanion(
          courtCategoryId: Value(categoryId),
          stepName: Value(name),
          orderIndex: Value(
            nextOrderIndex(existing.map((item) => item.orderIndex)),
          ),
        ),
      );
    } else if (repo is OnBehalfsRepository) {
      final existing = await repo.listByCategory(categoryId);
      await repo.insert(
        OnBehalfsCompanion(
          courtCategoryId: Value(categoryId),
          name: Value(name),
          orderIndex: Value(
            nextOrderIndex(existing.map((item) => item.orderIndex)),
          ),
        ),
      );
    }
  }
}

class _CaseTypeListView extends ConsumerWidget {
  final CaseTypesRepository repo;
  final String categoryId;
  const _CaseTypeListView({required this.repo, required this.categoryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      StreamBuilder<List<CaseType>>(
        stream: repo.watchByCategory(categoryId),
        builder: (context, snap) => _ListBody<CaseType>(
          items: snap.data ?? const <CaseType>[],
          getName: (c) => c.name,
          getId: (c) => c.id,
          onEdit: (c) => _edit(
            context,
            c.name,
            (name) => repo.update(
              CaseTypesCompanion(id: Value(c.id), name: Value(name)),
              base: c,
            ),
          ),
          onDelete: (c) => _delete(context, c, repo.delete),
          // Built-in seed options cannot be deleted; only what the user added.
          isDeletable: (c) => c.isCustom,
          onReorder: (items, oldIndex, newIndex) => _reorder(
            items,
            oldIndex,
            newIndex,
            (c, i) => repo.update(
              CaseTypesCompanion(id: Value(c.id), orderIndex: Value(i)),
              base: c,
            ),
          ),
        ),
      );
}

class _StepListView extends ConsumerWidget {
  final StepsRepository repo;
  final String categoryId;
  const _StepListView({required this.repo, required this.categoryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      StreamBuilder<List<Step>>(
        stream: repo.watchByCategory(categoryId),
        builder: (context, snap) => _ListBody<Step>(
          items: snap.data ?? const <Step>[],
          getName: (c) => c.stepName,
          getId: (c) => c.id,
          onEdit: (c) => _edit(
            context,
            c.stepName,
            (name) => repo.update(
              StepsCompanion(id: Value(c.id), stepName: Value(name)),
              base: c,
            ),
          ),
          onDelete: (c) => _delete(context, c, repo.delete),
          // Built-in seed options cannot be deleted; only what the user added.
          isDeletable: (c) => c.isCustom,
          onReorder: (items, oldIndex, newIndex) => _reorder(
            items,
            oldIndex,
            newIndex,
            (c, i) => repo.update(
              StepsCompanion(id: Value(c.id), orderIndex: Value(i)),
              base: c,
            ),
          ),
        ),
      );
}

class _OnBehalfListView extends ConsumerWidget {
  final OnBehalfsRepository repo;
  final String categoryId;
  const _OnBehalfListView({required this.repo, required this.categoryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // An on-behalf a live case still names keeps its place: that tombstone is
    // what the server refuses, so the action is not offered. A step or a case
    // type is never held back — a case stores both as text, so nothing
    // references either by id.
    final inUse =
        ref.watch(referenceInUseProvider).value ?? ReferenceInUse.none;

    return StreamBuilder<List<OnBehalf>>(
      stream: repo.watchByCategory(categoryId),
      builder: (context, snap) => _ListBody<OnBehalf>(
        items: snap.data ?? const <OnBehalf>[],
        getName: (c) => c.name,
        getId: (c) => c.id,
        onEdit: (c) => _edit(
          context,
          c.name,
          (name) => repo.update(
            OnBehalfsCompanion(id: Value(c.id), name: Value(name)),
            base: c,
          ),
        ),
        isDeletable: (c) => c.isCustom && !inUse.onBehalfIds.contains(c.id),
        onDelete: (c) => _delete(context, c, repo.delete),
        onReorder: (items, oldIndex, newIndex) => _reorder(
          items,
          oldIndex,
          newIndex,
          (c, i) => repo.update(
            OnBehalfsCompanion(id: Value(c.id), orderIndex: Value(i)),
            base: c,
          ),
        ),
      ),
    );
  }
}

/// Shared list body with reorder/edit/delete rendering.
class _ListBody<T> extends StatelessWidget {
  final List<T> items;
  final String Function(T) getName;
  final String Function(T) getId;
  final void Function(T) onEdit;

  /// Null when this list offers no deletion at all, in which case the Delete
  /// action is not rendered.
  final void Function(T)? onDelete;

  /// Whether one row may be deleted. Null means every row the caller offered an
  /// action for: a row [isDeletable] refuses — one a live case still names —
  /// renders no Delete, the same way the built-in courts and categories
  /// withhold it.
  final bool Function(T)? isDeletable;
  final void Function(List<T>, int, int) onReorder;

  const _ListBody({
    required this.items,
    required this.getName,
    required this.getId,
    required this.onEdit,
    this.onDelete,
    this.isDeletable,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (items.isEmpty) {
      return Center(child: Text(l.settingsItemList_empty));
    }
    return ReorderableListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: items.length,
      onReorderItem: (oldIndex, newIndex) =>
          onReorder(items, oldIndex, newIndex),
      itemBuilder: (context, index) {
        final item = items[index];
        final canDelete = onDelete != null && (isDeletable?.call(item) ?? true);
        return Card(
          key: ValueKey(getId(item)),
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
            // Seeded rows are stored in English; resolve them from the seed
            // data so the list follows the active language, like the court
            // list does. User-added rows fall back to their stored name.
            title: Text(
              context.l10n.seedLabel(getId(item), fallbackEn: getName(item)),
              style: AppTypography.bodyLg,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => onEdit(item),
                  tooltip: l.sharedActions_edit,
                ),
                if (canDelete)
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppColors.error,
                    ),
                    onPressed: () => onDelete!(item),
                    tooltip: l.sharedActions_delete,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

Future<void> _edit(
  BuildContext context,
  String initial,
  Future<void> Function(String) save,
) async {
  final l = AppLocalizations.of(context);
  final name = await showDialog<String>(
    context: context,
    builder: (_) => EditNameDialog(
      title: l.settingsItemList_editTitle,
      fieldLabel: l.settingsItemList_nameLabel,
      initialName: initial,
    ),
  );
  if (name == null || !context.mounted) return;
  await save(name);
}

Future<void> _delete<T>(
  BuildContext context,
  T item,
  Future<void> Function(T) delete,
) async {
  final l = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l.settingsItemList_deleteTitle, textAlign: TextAlign.center),
      content: Text(l.settingsItemList_deleteMessage),
      // Centred, with the Exit App window's action size (112x48, 16 pt).
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          style: TextButton.styleFrom(
            minimumSize: const Size(112, 48),
            textStyle: const TextStyle(fontSize: 16),
          ),
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(l.sharedActions_cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
            minimumSize: const Size(112, 48),
            textStyle: const TextStyle(fontSize: 16),
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(l.sharedActions_delete),
        ),
      ],
    ),
  );
  if (confirmed == true && context.mounted) await delete(item);
}

Future<void> _reorder<T>(
  List<T> items,
  int oldIndex,
  int newIndex,
  Future<void> Function(T, int) saveIndex,
) async {
  if (oldIndex == newIndex) return;
  final reordered = List<T>.from(items);
  final moved = reordered.removeAt(oldIndex);
  reordered.insert(newIndex, moved);
  for (var i = 0; i < reordered.length; i++) {
    await saveIndex(reordered[i], i);
  }
}
