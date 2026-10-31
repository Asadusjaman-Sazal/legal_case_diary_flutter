/// The Case Reference library's shared body: one row model, the law grouping,
/// and the list and card widgets both the user's screen and the Admin Panel's
/// Server-wide page draw.
///
/// The two screens read different data sources — the user's own `case_references`
/// plus the pulled official cache, and the admin's live server rows — but a
/// lawyer should see one library, not two shapes. Keeping the widgets here is
/// what makes the admin page a replica rather than a second design that drifts.
library;

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/constants/pre_seeded_data.dart';
import '../../../core/l10n/app_translations.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../database/app_database.dart';
import '../../../shared/widgets/read_only_lock.dart';
import '../../settings/presentation/settings_menu_card.dart';
import '../data/local/shared_case_references_dao.dart';

/// One card's worth of data, from any of the library's sources.
///
/// The user's own references, the pulled official cache and an admin's live
/// server rows are three table classes with three write rules — one is queued
/// and editable, one is read-only here, and one is the admins' to change — but a
/// lawyer reads them as one library, so the screen renders all three through
/// this row and keeps the original behind [own], [official] or neither.
class ReferenceRow {
  /// A row the signed-in user owns: editable and deletable under the allowance.
  ReferenceRow.own(CaseReference reference)
    : id = reference.id,
      referenceAndPageNo = reference.referenceAndPageNo,
      parties = reference.parties,
      statute = reference.statute,
      sectionOrArticle = reference.sectionOrArticle,
      titleAndDescription = reference.titleAndDescription,
      commentsNotes = reference.commentsNotes,
      caseNote = reference.caseNote,
      tags = reference.tags,
      isPinned = reference.isPinned,
      own = reference,
      official = null,
      editable = false;

  /// A row from the pulled official library: read-only on this device.
  ReferenceRow.official(OfficialReference entry)
    : id = entry.row.id,
      referenceAndPageNo = entry.row.referenceAndPageNo,
      parties = entry.row.parties,
      statute = entry.row.statute,
      sectionOrArticle = entry.row.sectionOrArticle,
      titleAndDescription = entry.row.titleAndDescription,
      commentsNotes = entry.row.commentsNotes,
      caseNote = entry.row.caseNote,
      tags = entry.row.tags,
      isPinned = entry.isPinned,
      own = null,
      official = entry,
      editable = false;

  /// A live server row the Admin Panel is editing: server-owned but writable
  /// **through the admin repository**, because the admin's own account carries
  /// the policy the phone cannot use.
  ReferenceRow.admin({
    required this.id,
    required this.referenceAndPageNo,
    this.parties,
    this.statute,
    this.sectionOrArticle,
    this.titleAndDescription,
    this.commentsNotes,
    this.caseNote,
    this.tags,
    this.isPinned = false,
  }) : own = null,
       official = null,
       editable = true;

  final String id;
  final String referenceAndPageNo;
  final String? parties;
  final String? statute;
  final String? sectionOrArticle;
  final String? titleAndDescription;
  final String? commentsNotes;
  final String? caseNote;
  final String? tags;
  final bool isPinned;

  /// The user's own row, or null when this is not theirs.
  final CaseReference? own;

  /// The official cache entry, or null when this did not come from the cache.
  final OfficialReference? official;

  /// Whether this row may be edited and deleted through the admin repository.
  final bool editable;

  /// True for a row that belongs to the server-wide library rather than to this
  /// account — the one that wears the **Official** chip.
  bool get isOfficial => own == null;

  /// Whether the row's menu offers Delete.
  bool get canDelete => own != null || editable;
}

/// One law row on the library's first level: the statute text and its count.
class LawSectionRow {
  /// Creates a row.
  const LawSectionRow({
    required this.key,
    required this.label,
    required this.count,
  });

  /// The statute text references carry; empty for a reference with no statute.
  final String key;

  /// The name to show; empty is rendered as **No statute**.
  final String label;

  /// How many references this law holds.
  final int count;
}

/// One category heading and the laws under it that hold references.
class LawSectionData {
  /// Creates a section; [categoryId] is empty for the trailing **Other** group.
  const LawSectionData({required this.categoryId, required this.rows});

  /// A seeded category id, or empty for the trailing **Other** section.
  final String categoryId;

  final List<LawSectionRow> rows;
}

/// The statute text a reference is filed under; blank reads as "no statute".
String referenceStatuteKey(String? statute) => (statute ?? '').trim();

/// The tags a citation carries, split on the ASCII comma.
///
/// Each tag is trimmed and blank ones disappear; duplicates that differ only in
/// case keep the first spelling, so a card never shows the same tag twice. A
/// Bengali comma stays inside its tag: only `,` separates.
List<String> referenceTags(String? raw) {
  if (raw == null) return const <String>[];
  final seen = <String>{};
  final tags = <String>[];
  for (final part in raw.split(',')) {
    final tag = part.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (tag.isEmpty || !seen.add(tag.toLowerCase())) continue;
    tags.add(tag);
  }
  return List<String>.unmodifiable(tags);
}

/// The stored form of [raw]: `tag1, tag2`, or null when it holds no tag.
String? canonicalReferenceTags(String? raw) {
  final tags = referenceTags(raw);
  return tags.isEmpty ? null : tags.join(', ');
}

/// Every tag already used in the library, alphabetical, each spelled once.
///
/// Feeds the form's Tags dropdown, so a tag is reused instead of retyped.
List<String> tagVocabulary(Iterable<String?> tagTexts) {
  final seen = <String>{};
  final tags = <String>[];
  for (final text in tagTexts) {
    for (final tag in referenceTags(text)) {
      if (seen.add(tag.toLowerCase())) tags.add(tag);
    }
  }
  tags.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return List<String>.unmodifiable(tags);
}

/// The library's first level: every law that holds references, under its
/// category, in the law list's order.
///
/// A law appears only when a reference names it, which is the user's rule — the
/// headings are the law categories, not a browse-every-law catalogue. A statute
/// text no law row owns is still listed, under **Other**, and a reference with
/// no statute at all sits there as **No statute**, so nothing in the library is
/// unreachable.
List<LawSectionData> lawSectionsFor(List<Law> laws, List<ReferenceRow> rows) {
  final counts = <String, int>{};
  for (final row in rows) {
    final key = referenceStatuteKey(row.statute);
    counts.update(key, (count) => count + 1, ifAbsent: () => 1);
  }
  if (counts.isEmpty) return const <LawSectionData>[];

  final sections = <LawSectionData>[];
  final claimed = <String>{};
  for (final category in seedLawCategories) {
    final lawsHere = <LawSectionRow>[];
    // `laws` arrives in display order (order_index, then name), so walking it
    // gives each heading its own order without sorting again.
    for (final law in laws) {
      if (law.category != category.id || claimed.contains(law.name)) continue;
      final count = counts[law.name];
      if (count == null) continue;
      claimed.add(law.name);
      lawsHere.add(LawSectionRow(key: law.name, label: law.name, count: count));
    }
    if (lawsHere.isNotEmpty) {
      sections.add(LawSectionData(categoryId: category.id, rows: lawsHere));
    }
  }

  // Everything the list could not place: an old free-text statute, a name a
  // newer release wrote, and the blank key.
  final others =
      counts.keys
          .where((key) => key.isNotEmpty && !claimed.contains(key))
          .toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  final otherRows = <LawSectionRow>[
    for (final key in others)
      LawSectionRow(key: key, label: key, count: counts[key]!),
    if (counts.containsKey(''))
      LawSectionRow(key: '', label: '', count: counts['']!),
  ];
  if (otherRows.isNotEmpty) {
    sections.add(LawSectionData(categoryId: '', rows: otherRows));
  }
  return sections;
}

/// The law list body: category headings and law rows, pullable to sync.
class ReferenceLawList extends StatelessWidget {
  /// Creates the list.
  const ReferenceLawList({
    required this.sections,
    required this.onOpen,
    required this.onRefresh,
    this.emptyMessage,
    super.key,
  });

  final List<LawSectionData> sections;
  final ValueChanged<String> onOpen;
  final Future<void> Function() onRefresh;

  /// What an empty library says; null uses the user's own wording.
  final String? emptyMessage;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    if (sections.isEmpty) {
      // The same centred, semibold message the reference list shows, in a
      // scrollable that always overscrolls so an empty library can be pulled
      // to sync.
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.6,
              child: Center(
                child: Text(
                  emptyMessage ?? l.caseReferenceScreen_empty,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final children = <Widget>[];
    for (var i = 0; i < sections.length; i++) {
      final section = sections[i];
      if (i > 0) children.add(const SizedBox(height: AppSpacing.md));
      children.add(
        Padding(
          key: ValueKey('law-section-${section.categoryId}'),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.xs,
          ),
          child: Text(
            context.l10n.lawCategoryName(section.categoryId),
            style: AppTypography.labelLg.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
      );
      for (final row in section.rows) {
        // The same sub-menu card Account & Profile uses, without its leading
        // icon (user request): the law name, its count and the chevron.
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: SettingsMenuCard(
              key: ValueKey('law-row-${row.key}'),
              title: row.label.isEmpty
                  ? l.caseReferenceScreen_noStatute
                  : row.label,
              onTap: () => onOpen(row.key),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${row.count}',
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.tertiary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  const Icon(Icons.chevron_right, color: AppColors.tertiary),
                ],
              ),
            ),
          ),
        );
      }
    }
    children.add(const SizedBox(height: AppSpacing.lg));

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.only(top: AppSpacing.sm),
        children: children,
      ),
    );
  }
}

/// A law's page header: back to the law list, the law's name, and its count.
class ReferenceLawHeader extends StatelessWidget {
  /// Creates the header.
  const ReferenceLawHeader({
    required this.label,
    required this.count,
    required this.onBack,
    super.key,
  });

  final String label;
  final int count;
  final Future<void> Function() onBack;

  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.surfaceContainerLowest,
    child: Row(
      children: [
        IconButton(
          key: const ValueKey('law-back'),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(Icons.arrow_back),
          onPressed: onBack,
        ),
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.titleMd.copyWith(
              color: AppColors.onBackground,
            ),
          ),
        ),
        Text(
          '$count',
          style: AppTypography.bodySm.copyWith(color: AppColors.tertiary),
        ),
        const SizedBox(width: AppSpacing.md),
      ],
    ),
  );
}

/// Scrollable reference list; the search bar lives in the host above it.
class ReferenceList extends StatelessWidget {
  /// Creates the list.
  const ReferenceList({
    required this.isSearching,
    required this.references,
    required this.totalCount,
    this.emptyMessage,
    this.writableReferenceIds,
    required this.onEdit,
    required this.onDelete,
    this.onTogglePin,
    required this.onRefresh,
    super.key,
  });

  final bool isSearching;
  final List<ReferenceRow> references;
  final int totalCount;

  /// What an empty page says when no query is in force; a law's own page says
  /// *No references for this law yet* rather than the library's own message.
  final String? emptyMessage;

  /// References the allowance keeps editable, or null when every one is.
  final Set<String>? writableReferenceIds;

  final ValueChanged<ReferenceRow> onEdit;
  final ValueChanged<ReferenceRow> onDelete;

  /// Null on a page with no pins (the Admin Panel's).
  final ValueChanged<ReferenceRow>? onTogglePin;

  /// Pull-down-to-sync, so an empty list is still syncable.
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final children = <Widget>[];

    if (references.isEmpty) {
      // Nothing to list: one semibold message centred in the screen, exactly
      // like the case-list empty state on Active Cases. It sits in a scrollable
      // that always overscrolls, so an empty screen can still be pulled to
      // sync — a bare `Center` has nothing to drag.
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.6,
              child: Center(
                child: Text(
                  isSearching && totalCount > 0
                      ? l.sharedDialogs_noResults
                      : (emptyMessage ?? l.caseReferenceScreen_empty),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
          ],
        ),
      );
    }

    for (var i = 0; i < references.length; i++) {
      if (i > 0) children.add(const SizedBox(height: AppSpacing.md));
      final row = references[i];
      children.add(
        ReferenceCard(
          row: row,
          // Only the user's own rows meet the lapse allowance; a server-owned
          // citation has no allowance to fall outside of.
          isReadOnly:
              row.own != null &&
              writableReferenceIds != null &&
              !writableReferenceIds!.contains(row.id),
          onEdit: () => onEdit(row),
          onDelete: () => onDelete(row),
          onTogglePin: onTogglePin == null ? null : () => onTogglePin!(row),
        ),
      );
    }
    children.add(const SizedBox(height: AppSpacing.lg));

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: children,
      ),
    );
  }
}

/// A single reference card matching the mandatory mockup layout.
class ReferenceCard extends StatefulWidget {
  /// Creates a card.
  const ReferenceCard({
    required this.row,
    required this.isReadOnly,
    required this.onEdit,
    required this.onDelete,
    this.onTogglePin,
    super.key,
  });

  /// The citation to draw, from any of the library's sources.
  final ReferenceRow row;

  final bool isReadOnly;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  /// Null where the page has no per-device pin (the Admin Panel's).
  final VoidCallback? onTogglePin;

  @override
  State<ReferenceCard> createState() => _ReferenceCardState();
}

class _ReferenceCardState extends State<ReferenceCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final l = AppLocalizations.of(context);
    final borderColor = _hovered
        ? AppColors.secondary
        : AppColors.outlineVariant;
    final pin = widget.onTogglePin;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Card(
        elevation: _hovered ? 2 : 0,
        color: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: borderColor),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: widget.onEdit,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // L1: reference & page no + statute chips, 3-dot menu on the
                // right.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        children: [
                          _Chip(label: row.referenceAndPageNo),
                          if (row.statute != null && row.statute!.isNotEmpty)
                            _Chip(label: row.statute!),
                          // Which library this row came from. A server-wide
                          // citation reads like any other card — it is a full
                          // member of the library, merely one this device may
                          // not always change.
                          if (row.isOfficial)
                            _OfficialChip(
                              label: l.caseReferenceScreen_official,
                            ),
                        ],
                      ),
                    ),
                    if (widget.isReadOnly) ...[
                      const ReadOnlyLock(),
                      const SizedBox(width: AppSpacing.xs),
                    ],
                    if (pin != null || row.canDelete)
                      PopupMenuButton<String>(
                        key: const ValueKey('reference-menu'),
                        icon: const Icon(Icons.more_vert),
                        color: AppColors.surfaceContainerLowest,
                        onSelected: (value) {
                          if (value == 'pin') {
                            pin?.call();
                          } else if (value == 'delete') {
                            widget.onDelete();
                          }
                        },
                        itemBuilder: (context) => [
                          if (pin != null)
                            PopupMenuItem<String>(
                              key: const ValueKey('reference-pin'),
                              value: 'pin',
                              child: Row(
                                children: [
                                  Icon(
                                    row.isPinned
                                        ? Icons.push_pin
                                        : Icons.push_pin_outlined,
                                    size: 18,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Text(
                                    row.isPinned
                                        ? l.caseReferenceScreen_unpin
                                        : l.caseReferenceScreen_pin,
                                  ),
                                ],
                              ),
                            ),
                          // No Delete on a cached official row: the phone holds
                          // no grant on the server table. An admin's live row
                          // can delete, because the admin's own account does.
                          if (row.canDelete)
                            PopupMenuItem<String>(
                              key: const ValueKey('reference-delete'),
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                    color: AppColors.error,
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Text(
                                    l.sharedActions_delete,
                                    style: TextStyle(color: AppColors.error),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
                // Tags the citation carries, each its own small chip.
                if (referenceTags(row.tags).isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final tag in referenceTags(row.tags))
                        _TagChip(label: tag),
                    ],
                  ),
                ],
                // The parties the case was between, under the citation chips.
                if (row.parties != null && row.parties!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    row.parties!,
                    style: AppTypography.bodyMd.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                // L2: section / article.
                if (row.sectionOrArticle != null &&
                    row.sectionOrArticle!.isNotEmpty)
                  Text(
                    row.sectionOrArticle!,
                    style: AppTypography.titleMd.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                // L3: title & description.
                if (row.titleAndDescription != null &&
                    row.titleAndDescription!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    row.titleAndDescription!,
                    style: AppTypography.bodyMd.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
                // The case note sits beside the summary, before the personal
                // notes, so the two kinds of note read in order.
                if (row.caseNote != null && row.caseNote!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(row.caseNote!, style: AppTypography.bodyMd),
                ],
                // L4: comments / notes.
                if (row.commentsNotes != null &&
                    row.commentsNotes!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                      border: Border(
                        left: BorderSide(color: AppColors.secondary, width: 4),
                      ),
                    ),
                    child: Text(
                      row.commentsNotes!,
                      style: AppTypography.labelMd.copyWith(
                        color: AppColors.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The **Official** mark on a citation from the server-wide library.
///
/// Deliberately the same shape and size as [_Chip] but outlined rather than
/// filled, so it reads as a label on the row rather than a second citation
/// field — and stays legible next to two filled chips.
class _OfficialChip extends StatelessWidget {
  const _OfficialChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: AppSpacing.xs,
    ),
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.outline),
    ),
    child: Text(
      label,
      style: AppTypography.labelMd.copyWith(color: AppColors.onSurfaceVariant),
    ),
  );
}

/// A small chip for one tag on a citation.
///
/// Filled in the neutral container tone rather than the citation chips' accent,
/// so a tag reads as a finding aid rather than another citation field, and it
/// stays distinct from the outlined **Official** mark beside it.
class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: AppSpacing.xs,
    ),
    decoration: BoxDecoration(
      color: AppColors.surfaceContainer,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: AppTypography.labelMd.copyWith(color: AppColors.onSurfaceVariant),
    ),
  );
}

/// Small rounded chip used for the reference & page no and statute labels.
class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: AppSpacing.xs,
    ),
    decoration: BoxDecoration(
      color: AppColors.secondaryFixed,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: AppTypography.labelMd.copyWith(color: AppColors.primary),
    ),
  );
}
