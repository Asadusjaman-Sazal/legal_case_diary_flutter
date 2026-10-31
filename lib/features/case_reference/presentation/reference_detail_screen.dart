/// The read-only Case Reference detail, shared by the user's library and the
/// Admin Panel's Server-wide library.
///
/// Tapping a citation card opens this screen. The top-right **Edit** opens the
/// shared Add/Edit form through the host's callback — the host owns the write
/// rules, so the detail has no providers of its own. An Official cached row on
/// the user's screen carries no callback and therefore no Edit, because the
/// phone cannot write the server-wide library.
///
/// The layout follows the Case Detail screen: the app background, 16 px side
/// margins, white section cards with an 8 px corner and the card border, 24 px
/// padding, icon-and-title headings and labelled value boxes.
library;

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import 'reference_library.dart';

/// A citation's read-only detail, with an optional Edit action.
class ReferenceDetailScreen extends StatefulWidget {
  /// Creates the detail for [row].
  ///
  /// [onEdit] opens the host's edit form with the detail's current row and
  /// returns the fresh row on a save; a null return (a cancel or a refusal)
  /// leaves the screen as it is. A null callback hides the Edit button.
  const ReferenceDetailScreen({required this.row, this.onEdit, super.key});

  /// The row to show.
  final ReferenceRow row;

  /// The host's edit path, or null for a read-only citation.
  final Future<ReferenceRow?> Function(ReferenceRow currentRow)? onEdit;

  @override
  State<ReferenceDetailScreen> createState() => _ReferenceDetailScreenState();
}

class _ReferenceDetailScreenState extends State<ReferenceDetailScreen> {
  late ReferenceRow _row = widget.row;
  bool _editing = false;

  Future<void> _edit() async {
    final edit = widget.onEdit;
    if (edit == null || _editing) return;
    setState(() => _editing = true);
    try {
      final updated = await edit(_row);
      if (updated != null && mounted) setState(() => _row = updated);
    } finally {
      if (mounted) setState(() => _editing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tags = referenceTags(_row.tags);
    final statute = _row.statute?.trim() ?? '';
    final parties = _row.parties?.trim() ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: ListView(
            padding: const EdgeInsets.only(
              top: AppSpacing.lg,
              bottom: AppSpacing.xxxl,
            ),
            children: [
              _topRow(l),
              const SizedBox(height: AppSpacing.lg),
              Text(
                _row.referenceAndPageNo,
                key: const ValueKey('reference-detail-citation'),
                style: AppTypography.headlineMd,
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  const Icon(
                    Icons.gavel,
                    size: 18,
                    color: AppColors.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      statute.isEmpty ? '—' : statute,
                      key: const ValueKey('reference-detail-law'),
                      style: AppTypography.bodyLg.copyWith(
                        color: statute.isEmpty
                            ? AppColors.outline
                            : AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              if (_row.isOfficial) ...[
                const SizedBox(height: AppSpacing.md),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OfficialChip(label: l.caseReferenceScreen_official),
                ),
              ],
              if (parties.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                _sectionCard(
                  key: const ValueKey('reference-detail-parties'),
                  icon: Icons.person_outline,
                  title: l.caseReferenceScreen_parties,
                  child: _valueBox(
                    child: Text(
                      parties,
                      style: AppTypography.bodyLg.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              _sectionCard(
                key: const ValueKey('reference-detail-details'),
                icon: Icons.info_outline,
                title: l.caseReferenceDetail_details,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _field(
                      l.caseReferenceScreen_sectionOrArticle,
                      _row.sectionOrArticle,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _field(l.caseReferenceScreen_caseNote, _row.caseNote),
                    const SizedBox(height: AppSpacing.md),
                    _field(
                      l.caseReferenceScreen_titleAndDescription,
                      _row.titleAndDescription,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _field(
                      l.caseReferenceScreen_commentsNotes,
                      _row.commentsNotes,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _tagsField(l, tags),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The top action row: back at the left, Edit at the right.
  Widget _topRow(AppLocalizations l) => Row(
    children: [
      _topAction(
        key: const ValueKey('reference-detail-back'),
        icon: Icons.arrow_back,
        label: MaterialLocalizations.of(context).backButtonTooltip,
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      const Spacer(),
      if (widget.onEdit != null)
        _topAction(
          key: const ValueKey('reference-detail-edit'),
          icon: Icons.edit_outlined,
          label: l.sharedActions_edit,
          onPressed: _editing ? null : _edit,
        ),
    ],
  );

  /// One 40 px black icon button, the Case Detail's header-action style.
  Widget _topAction({
    required Key key,
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) => Tooltip(
    message: label,
    child: SizedBox(
      width: 40,
      height: 40,
      child: FilledButton(
        key: key,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.secondary,
          foregroundColor: AppColors.onPrimary,
          disabledBackgroundColor: AppColors.secondary.withValues(alpha: 0.5),
          minimumSize: const Size(40, 40),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
          ),
        ),
        onPressed: onPressed,
        child: Icon(icon, size: 18),
      ),
    ),
  );

  /// One Case-Detail-style section card.
  Widget _sectionCard({
    required Key key,
    required IconData icon,
    required String title,
    required Widget child,
  }) => Container(
    key: key,
    width: double.infinity,
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerLowest,
      border: Border.all(color: AppColors.cardBorder),
      borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(title, style: AppTypography.titleMd)),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        child,
      ],
    ),
  );

  /// The Case Detail's labelled value box, one step in from the section card.
  Widget _valueBox({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
    ),
    child: child,
  );

  /// Label above a value box; an empty value reads as an em dash.
  Widget _field(String label, String? value) {
    final text = value?.trim() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.labelLg.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        _valueBox(
          child: Text(
            text.isEmpty ? '—' : text,
            style: AppTypography.bodyMd.copyWith(
              color: text.isEmpty ? AppColors.outline : AppColors.onBackground,
            ),
          ),
        ),
      ],
    );
  }

  /// The Tags field: its chips, or the em dash when there are none.
  Widget _tagsField(AppLocalizations l, List<String> tags) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        l.caseReferenceScreen_tags,
        style: AppTypography.labelLg.copyWith(
          color: AppColors.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: AppSpacing.xs),
      _valueBox(
        child: tags.isEmpty
            ? Text(
                '—',
                style: AppTypography.bodyMd.copyWith(color: AppColors.outline),
              )
            : Wrap(
                key: const ValueKey('reference-detail-tags'),
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [for (final tag in tags) TagChip(label: tag)],
              ),
      ),
    ],
  );
}
