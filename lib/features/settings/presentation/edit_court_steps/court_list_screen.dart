/// Court list screen: manage the courts of one court category — a Supreme
/// Court division (higher courts) or one category inside a division+district
/// (lower courts). Supports drag reorder, edit, soft-delete (custom only), and
/// a bottom-right add button matching the Add Case button. Mirrors
/// `courtCategory_lowerCourts-Districts_listOfCourts`.
library;

import 'package:drift/drift.dart' hide isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/constants/pre_seeded_data.dart';
import '../../../../core/l10n/app_translations.dart';
import '../../../../core/l10n/generated/app_localizations.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../data/courts_repository.dart';
import '../../data/reference_in_use_checker.dart';
import '../../../../database/app_database.dart';
import '../../../../shared/providers/locale_provider.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../../../shared/widgets/app_dialog_actions.dart';
import '../settings_sub_page_modal.dart';
import 'court_category_label.dart';
import 'edit_name_dialog.dart';
import 'next_order_index.dart';

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

  /// Localization key of [category], passed by the screen that opened this
  /// one so the header can name the category it lists. Null (a restored route)
  /// simply falls back to the district-level subtitle.
  final String? categoryNameKey;

  const CourtListScreen({
    super.key,
    this.category,
    this.higherLower,
    this.division,
    this.district,
    this.categoryNameKey,
  });

  @override
  ConsumerState<CourtListScreen> createState() => _CourtListScreenState();
}

class _CourtListScreenState extends ConsumerState<CourtListScreen> {
  bool get _isLower => widget.division != null && widget.district != null;

  /// Court category the listed courts belong to.
  String? get _categoryId =>
      widget.category ?? (_isLower ? chiefJudicialMagistrateId : null);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final repoAsync = ref.watch(courtsRepositoryProvider);

    final title = _isLower
        ? l.settingsCourtList_titleLower(_districtLabel(widget.district!))
        : l.settingsCourtList_titleHigher;
    final subtitle = widget.categoryNameKey != null
        ? courtCategoryName(context, widget.categoryNameKey!)
        : (_isLower ? l.settingsCourtFlow_districts : null);

    return SettingsSubPageModal(
      title: title,
      subtitle: subtitle,
      // The Add Case button: black, white `+`, bottom-right.
      floatingActionButton: repoAsync.whenOrNull(
        data: (repo) => FloatingActionButton(
          onPressed: () => _addCourt(context, repo),
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          tooltip: l.settingsCourtList_addTitle,
          child: const Icon(Icons.add, size: 28),
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
    final l = AppLocalizations.of(context);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => EditNameDialog(
        title: l.settingsCourtList_addTitle,
        fieldLabel: l.settingsCourtList_nameLabel,
      ),
    );
    if (name == null || !mounted) return;
    // A new court takes the slot after the courts already listed here, so it
    // lands at the end instead of tying with the first court.
    final listed = await _listedCourts(repo);
    await repo.insert(
      CourtsCompanion(
        courtName: Value(name),
        higherLowerCourts: Value(
          _isLower ? lowerCourtsOption : higherCourtsOption,
        ),
        division: widget.division == null
            ? const Value.absent()
            : Value(widget.division),
        district: widget.district == null
            ? const Value.absent()
            : Value(widget.district),
        courtCategoryId: Value(_categoryId!),
        orderIndex: Value(
          nextOrderIndex(listed.map((court) => court.orderIndex)),
        ),
      ),
    );
  }

  /// The courts this screen lists, read so a new court can be appended after
  /// them: one court category for higher courts, one division + district +
  /// category for lower courts.
  Future<List<Court>> _listedCourts(CourtsRepository repo) async {
    final all = await repo.listAll();
    return all
        .where(
          (court) =>
              court.courtCategoryId == _categoryId &&
              (!_isLower ||
                  (court.division == widget.division &&
                      court.district == widget.district)),
        )
        .toList(growable: false);
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
    // A court a live case still names keeps its place: the server refuses that
    // tombstone, so the action is not offered here either (§3.2).
    final inUse =
        ref.watch(referenceInUseProvider).value ?? ReferenceInUse.none;

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
          if (!isLower) return true;
          return c.division == state.division &&
              c.district == state.district &&
              (state.category == null || c.courtCategoryId == state.category);
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
              // Pre-seeded courts cannot be deleted, so only the courts the
              // user added offer the action — and not one a live case still
              // names, which the server would refuse.
              onDelete: court.isCustom && !inUse.courtIds.contains(court.id)
                  ? () => _deleteCourt(context, court)
                  : null,
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
    final l = AppLocalizations.of(context);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => EditNameDialog(
        title: l.settingsCourtList_editTitle,
        fieldLabel: l.settingsCourtList_nameLabel,
        initialName: court.courtName,
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
    final confirmed = await showAppConfirmDialog(
      context,
      title: l.settingsCourtList_deleteTitle,
      message: l.settingsCourtList_deleteMessage(court.courtName),
      cancelLabel: l.sharedActions_cancel,
      confirmLabel: l.sharedActions_delete,
      confirmKind: AppDialogActionKind.primary,
    );
    if (!confirmed || !mounted) return;
    await widget.repo.delete(court);
  }
}

/// A single reorderable court tile with edit/delete actions.
class _CourtTile extends StatelessWidget {
  final Court court;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  const _CourtTile({
    super.key,
    required this.court,
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
        // Seeded courts are labeled from the same pre-seeded data the Add/Edit
        // Case form reads, so both show the court under the active language.
        title: Text(
          context.l10n.seedLabel(court.id, fallbackEn: court.courtName),
          style: AppTypography.bodyLg,
        ),
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
