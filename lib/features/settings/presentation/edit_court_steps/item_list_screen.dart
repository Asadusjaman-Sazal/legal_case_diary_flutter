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
import '../../../../core/providers/repository_providers.dart';
import '../../../../database/app_database.dart';
import '../../data/case_types_repository.dart';
import '../../data/on_behalfs_repository.dart';
import '../../data/steps_repository.dart';
import '../settings_sub_page_modal.dart';

/// Which kind of item this list manages.
enum ItemKind { caseTypes, steps, onBehalf }

/// Parse a `?kind=` query value into [ItemKind].
ItemKind itemKindFromParam(String? value) => switch (value) {
      'case_types' => ItemKind.caseTypes,
      'steps' => ItemKind.steps,
      _ => ItemKind.onBehalf,
    };

/// English title for a kind.
String itemKindTitle(ItemKind kind) => switch (kind) {
      ItemKind.caseTypes => 'Case Types',
      ItemKind.steps => 'Steps',
      ItemKind.onBehalf => 'On Behalf',
    };

/// Add/edit dialog for a single named item.
class _ItemEditDialog extends StatefulWidget {
  final String? initialName;

  const _ItemEditDialog({this.initialName});

  @override
  State<_ItemEditDialog> createState() => _ItemEditDialogState();
}

class _ItemEditDialogState extends State<_ItemEditDialog> {
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
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.initialName == null ? 'Add Item' : 'Edit Item'),
        content: Form(
          key: _formKey,
          child: TextFormField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Name'),
            validator: (value) =>
                value == null || value.trim().isEmpty ? 'Required' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!_formKey.currentState!.validate()) return;
              Navigator.of(context).pop(_controller.text.trim());
            },
            child: const Text('Save'),
          ),
        ],
      );
}

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
    final title = '${itemKindTitle(kind)} — ${_categoryShortLabel(categoryId)}';

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
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (repo) => _CaseTypeListView(repo: repo, categoryId: categoryId),
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
            error: (e, _) => Center(child: Text('Error: $e')),
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
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (repo) => _OnBehalfListView(repo: repo, categoryId: categoryId),
          ),
        );
    }
  }

  String _categoryShortLabel(String id) => const {
        'appellate_division': 'Appellate',
        'high_court_division': 'High Court',
        'district_sessions_criminal': 'Sessions (Crim)',
        'district_courts_civil': 'District (Civil)',
        'chief_judicial_magistrate': 'CJM',
        'chief_metropolitan_magistrate': 'CMM',
        'executive_magistrate': 'Executive',
        'tribunals': 'Tribunals',
      }[id] ?? id;

  // Separate typed add/edit callbacks keep the repository generics concrete.
  Future<void> _add(BuildContext context, WidgetRef ref, dynamic repo) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _ItemEditDialog(),
    );
    if (name == null || !context.mounted) return;
    if (repo is CaseTypesRepository) {
      await repo.insert(
        CaseTypesCompanion(
          courtCategoryId: Value(categoryId),
          name: Value(name),
          orderIndex: const Value(0),
        ),
      );
    } else if (repo is StepsRepository) {
      await repo.insert(
        StepsCompanion(
          courtCategoryId: Value(categoryId),
          stepName: Value(name),
          orderIndex: const Value(0),
        ),
      );
    } else if (repo is OnBehalfsRepository) {
      await repo.insert(
        OnBehalfsCompanion(
          courtCategoryId: Value(categoryId),
          name: Value(name),
          orderIndex: const Value(0),
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
  Widget build(BuildContext context, WidgetRef ref) => StreamBuilder<List<CaseType>>(
        stream: repo.watchByCategory(categoryId),
        builder: (context, snap) => _ListBody<CaseType>(
          items: snap.data ?? const <CaseType>[],
          getName: (c) => c.name,
          getId: (c) => c.id,
          onEdit: (c) => _edit(context, c.name, (name) => repo.update(
                CaseTypesCompanion(id: Value(c.id), name: Value(name)),
                base: c,
              )),
          onDelete: (c) => _delete(context, c, repo.delete),
          onReorder: (items, oldIndex, newIndex) =>
              _reorder(items, oldIndex, newIndex, (c, i) => repo.update(
                CaseTypesCompanion(id: Value(c.id), orderIndex: Value(i)),
                base: c,
              )),
        ),
      );
}

class _StepListView extends ConsumerWidget {
  final StepsRepository repo;
  final String categoryId;
  const _StepListView({required this.repo, required this.categoryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) => StreamBuilder<List<Step>>(
        stream: repo.watchByCategory(categoryId),
        builder: (context, snap) => _ListBody<Step>(
          items: snap.data ?? const <Step>[],
          getName: (c) => c.stepName,
          getId: (c) => c.id,
          onEdit: (c) => _edit(context, c.stepName, (name) => repo.update(
                StepsCompanion(id: Value(c.id), stepName: Value(name)),
                base: c,
              )),
          onDelete: (c) => _delete(context, c, repo.delete),
          onReorder: (items, oldIndex, newIndex) =>
              _reorder(items, oldIndex, newIndex, (c, i) => repo.update(
                StepsCompanion(id: Value(c.id), orderIndex: Value(i)),
                base: c,
              )),
        ),
      );
}

class _OnBehalfListView extends ConsumerWidget {
  final OnBehalfsRepository repo;
  final String categoryId;
  const _OnBehalfListView({required this.repo, required this.categoryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) => StreamBuilder<List<OnBehalf>>(
        stream: repo.watchByCategory(categoryId),
        builder: (context, snap) => _ListBody<OnBehalf>(
          items: snap.data ?? const <OnBehalf>[],
          getName: (c) => c.name,
          getId: (c) => c.id,
          onEdit: (c) => _edit(context, c.name, (name) => repo.update(
                OnBehalfsCompanion(id: Value(c.id), name: Value(name)),
                base: c,
              )),
          onDelete: (c) => _delete(context, c, repo.delete),
          onReorder: (items, oldIndex, newIndex) =>
              _reorder(items, oldIndex, newIndex, (c, i) => repo.update(
                OnBehalfsCompanion(id: Value(c.id), orderIndex: Value(i)),
                base: c,
              )),
        ),
      );
}

/// Shared list body with reorder/edit/delete rendering.
class _ListBody<T> extends StatelessWidget {
  final List<T> items;
  final String Function(T) getName;
  final String Function(T) getId;
  final void Function(T) onEdit;
  final void Function(T) onDelete;
  final void Function(List<T>, int, int) onReorder;

  const _ListBody({
    required this.items,
    required this.getName,
    required this.getId,
    required this.onEdit,
    required this.onDelete,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('No items yet. Add one below.'));
    }
    return ReorderableListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: items.length,
      onReorderItem: (oldIndex, newIndex) => onReorder(items, oldIndex, newIndex),
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          key: ValueKey(getId(item)),
          elevation: 0,
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppColors.surfaceContainer),
          ),
          child: ListTile(
            leading: const Icon(Icons.drag_indicator, color: AppColors.tertiary),
            title: Text(getName(item), style: AppTypography.bodyLg),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => onEdit(item),
                  tooltip: 'Edit',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.error),
                  onPressed: () => onDelete(item),
                  tooltip: 'Delete',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

Future<void> _edit(BuildContext context, String initial, Future<void> Function(String) save) async {
  final name = await showDialog<String>(
    context: context,
    builder: (_) => _ItemEditDialog(initialName: initial),
  );
  if (name == null || !context.mounted) return;
  await save(name);
}

Future<void> _delete<T>(BuildContext context, T item, Future<void> Function(T) delete) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete Item'),
      content: const Text('Delete this item? This cannot be undone.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Delete'),
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
