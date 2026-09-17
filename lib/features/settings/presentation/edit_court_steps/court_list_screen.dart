/// Court list screen: manage courts for a category (higher courts) or a
/// division+district (lower courts). Supports drag reorder, edit, soft-delete
/// (custom only), and FAB add. Mirrors
/// `courtCategory_lowerCourts-Districts_listOfCourts`.
library;

import 'package:drift/drift.dart' hide isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/constants/pre_seeded_data.dart';
import '../../../../core/l10n/generated/app_localizations.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../data/courts_repository.dart';
import '../../../../database/app_database.dart';
import '../../../../shared/providers/locale_provider.dart';
import '../settings_sub_page_modal.dart';

/// Add/edit dialog for a single court name.
class _CourtEditDialog extends StatefulWidget {
  final Court? court;
  final String higherLowerCourts;
  final String? division;
  final String? district;
  final String courtCategoryId;

  const _CourtEditDialog({
    this.court,
    required this.higherLowerCourts,
    this.division,
    this.district,
    required this.courtCategoryId,
  });

  @override
  State<_CourtEditDialog> createState() => _CourtEditDialogState();
}

class _CourtEditDialogState extends State<_CourtEditDialog> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.court?.courtName ?? '');
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
        widget.court == null
            ? l.settingsCourtList_addTitle
            : l.settingsCourtList_editTitle,
      ),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          decoration: InputDecoration(labelText: l.settingsCourtList_nameLabel),
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

/// Court list screen for a category or division+district.
class CourtListScreen extends ConsumerStatefulWidget {
  /// Court category id (higher courts) — used when [division] is null.
  final String? category;

  /// `higher_courts` or `lower_courts`.
  final String? higherLower;

  /// Division id (lower courts).
  final String? division;

  /// District id (lower courts).
  final String? district;

  const CourtListScreen({
    super.key,
    this.category,
    this.higherLower,
    this.division,
    this.district,
  });

  @override
  ConsumerState<CourtListScreen> createState() => _CourtListScreenState();
}

class _CourtListScreenState extends ConsumerState<CourtListScreen> {
  bool get _isLower => widget.division != null && widget.district != null;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final repoAsync = ref.watch(courtsRepositoryProvider);

    final title = _isLower
        ? l.settingsCourtList_titleLower(_districtLabel(widget.district!))
        : l.settingsCourtList_titleHigher;

    return SettingsSubPageModal(
      title: title,
      subtitle: _isLower ? l.settingsCourtFlow_districts : null,
      floatingActionButton: repoAsync.whenOrNull(
        data: (repo) => FloatingActionButton(
          onPressed: () => _addCourt(context, repo),
          child: const Icon(Icons.add),
        ),
      ),
      child: repoAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l.sharedMessages_error('$e'))),
        data: (repo) => _CourtListView(repo: repo, widget: widget),
      ),
    );
  }

  Future<void> _addCourt(BuildContext context, CourtsRepository repo) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _CourtEditDialog(
        higherLowerCourts: _isLower ? 'lower_courts' : 'higher_courts',
        division: widget.division,
        district: widget.district,
        courtCategoryId: _isLower
            ? 'chief_judicial_magistrate'
            : widget.category!,
      ),
    );
    if (name == null || !mounted) return;
    await repo.insert(
      CourtsCompanion(
        courtName: Value(name),
        higherLowerCourts: Value(_isLower ? 'lower_courts' : 'higher_courts'),
        division: widget.division == null
            ? const Value.absent()
            : Value(widget.division),
        district: widget.district == null
            ? const Value.absent()
            : Value(widget.district),
        courtCategoryId: Value(
          _isLower ? 'chief_judicial_magistrate' : widget.category!,
        ),
        orderIndex: const Value(0),
      ),
    );
  }

  String _districtLabel(String id) {
    final locale = ref.read(localeProvider);
    final isBn = locale.languageCode == 'bn';
    return isBn ? districtLabelBn[id] ?? id : districtLabelEn[id] ?? id;
  }
}

/// Stream-driven list body with reorder/edit/delete for a resolved category.
class _CourtListView extends ConsumerStatefulWidget {
  final CourtsRepository repo;
  final CourtListScreen widget;

  const _CourtListView({required this.repo, required this.widget});

  @override
  ConsumerState<_CourtListView> createState() => _CourtListViewState();
}

class _CourtListViewState extends ConsumerState<_CourtListView> {
  @override
  Widget build(BuildContext context) {
    final state = widget.widget;
    final isLower = state.division != null && state.district != null;

    return StreamBuilder<List<Court>>(
      stream: isLower
          ? widget.repo.watchAll()
          : widget.repo.watchByCategory(state.category!),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              AppLocalizations.of(
                context,
              ).sharedMessages_error('${snapshot.error}'),
            ),
          );
        }
        final courts = snapshot.data ?? const [];
        final items = courts.where((c) {
          if (isLower) {
            return c.division == state.division && c.district == state.district;
          }
          return true;
        }).toList();
        if (items.isEmpty) {
          return Center(
            child: Text(AppLocalizations.of(context).settingsCourtList_empty),
          );
        }
        return ReorderableListView.builder(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: items.length,
          onReorderItem: (oldIndex, newIndex) =>
              _reorder(items, oldIndex, newIndex),
          itemBuilder: (context, index) {
            final court = items[index];
            return _CourtTile(
              key: ValueKey(court.id),
              court: court,
              onEdit: () => _editCourt(context, court),
              onDelete: () => _deleteCourt(context, court),
            );
          },
        );
      },
    );
  }

  Future<void> _reorder(List<Court> items, int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;
    final reordered = List<Court>.from(items);
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);
    for (var i = 0; i < reordered.length; i++) {
      final c = reordered[i];
      await widget.repo.update(
        CourtsCompanion(id: Value(c.id), orderIndex: Value(i)),
        base: c,
      );
    }
  }

  Future<void> _editCourt(BuildContext context, Court court) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _CourtEditDialog(
        court: court,
        higherLowerCourts: court.higherLowerCourts,
        division: court.division,
        district: court.district,
        courtCategoryId: court.courtCategoryId,
      ),
    );
    if (name == null || !mounted) return;
    await widget.repo.update(
      CourtsCompanion(id: Value(court.id), courtName: Value(name)),
      base: court,
    );
  }

  Future<void> _deleteCourt(BuildContext context, Court court) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.settingsCourtList_deleteTitle),
        content: Text(l.settingsCourtList_deleteMessage(court.courtName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.sharedActions_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.sharedActions_delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await widget.repo.delete(court);
  }
}

/// A single reorderable court tile with edit/delete actions.
class _CourtTile extends StatelessWidget {
  final Court court;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CourtTile({
    super.key,
    required this.court,
    required this.onEdit,
    required this.onDelete,
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
        title: Text(court.courtName, style: AppTypography.bodyLg),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: onEdit,
              tooltip: l.sharedActions_edit,
            ),
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
