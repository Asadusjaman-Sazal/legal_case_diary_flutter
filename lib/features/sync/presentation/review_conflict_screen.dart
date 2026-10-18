/// Review Conflict screen (Task 19 Phase 3).
///
/// The one place a person answers a conflict the three-way comparison could not.
/// It shows the authoritative server values, the values this device tried to
/// write, and any later edits the freeze is preserving — and it offers exactly
/// the answers the plan allows: keep one value per colliding field, keep the
/// local work as a **new** record when the server row is a tombstone, or discard
/// it after an explicit confirmation.
///
/// Nothing here is decorative: closing the screen changes nothing, and the
/// conflict stays frozen until one of those answers is written.
library;

// `drift` defines a `Column` too; the screen's own layout needs Flutter's.
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../database/app_database.dart';
import '../../../shared/providers/database_provider.dart';
import '../../../shared/widgets/attribution_line.dart';
import '../../../sync/conflict_rebase.dart';
import '../../../sync/conflict_resolution.dart';
import '../../../sync/entity_tables.dart';
import '../../../sync/sync_conflict_log.dart';
import '../../../sync/sync_providers.dart';
import '../../accounts_and_profile/data/account_mode.dart';
import '../../settings/presentation/settings_menu_card.dart';
import '../../settings/presentation/settings_sub_page_modal.dart';

/// Every queue row still held for one entity, oldest first.
///
/// The conflict's own rejected mutation is filtered out by the screen; what is
/// left is the later work the freeze preserved, which the user has a right to
/// see before choosing what happens to it.
final _entityQueueProvider =
    StreamProvider.family<List<SyncQueueRow>, (String, String)>((ref, key) async* {
  final db = await ref.watch(databaseProvider.future);
  yield* (db.select(db.syncQueue)
        ..where((row) =>
            row.entityType.equals(key.$1) & row.entityId.equals(key.$2))
        ..orderBy([(row) => OrderingTerm(expression: row.createdAt)]))
      .watch();
});

/// One changed field, as both sides see it.
class _FieldDiff {
  _FieldDiff(this.field, this.serverValue, this.localValue);

  /// snake_case column name.
  final String field;

  /// The authoritative value.
  final Object? serverValue;

  /// The value this device tried to write.
  final Object? localValue;

  /// Whether the two sides disagree.
  bool get differs => serverValue != localValue;

  /// A readable label for the column name.
  ///
  /// `ponytail:` the labels are data-derived (column names), not UI copy, so they
  /// are title-cased at render time instead of adding one ARB key per column;
  /// upgrade by mapping the handful of columns the Review screen shows onto ARB
  /// labels if localized field names are ever needed.
  String get label => field
      .split('_')
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1).toLowerCase())
      .join(' ');
}

/// Renders a raw payload value; a missing value is a dash, never a blank.
String _formatValue(Object? value) {
  if (value == null) return '—';
  return value.toString();
}

/// The Review Conflict screen for one conflict id.
class ReviewConflictScreen extends ConsumerStatefulWidget {
  /// Creates the screen for [conflictId].
  const ReviewConflictScreen({required this.conflictId, super.key});

  /// The `conflict_log.id` being answered.
  final String conflictId;

  @override
  ConsumerState<ReviewConflictScreen> createState() =>
      _ReviewConflictScreenState();
}

class _ReviewConflictScreenState extends ConsumerState<ReviewConflictScreen> {
  /// field name -> true when the local value is kept.
  final Map<String, bool> _keepMine = <String, bool>{};

  /// True while a resolution is being written, so the buttons cannot double-fire.
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final conflict = ref.watch(conflictByIdProvider(widget.conflictId)).value;
    // A chamber's other side may be a **colleague**, not a second device of this
    // account, so the subtitle names a member there (firm-mode §9.9). Outside a
    // chamber the two-device wording is exactly right and is kept.
    final subtitle = ref.watch(firmModeProvider)
        ? l.syncConflict_subtitleMember
        : l.syncConflict_subtitle;

    return SettingsSubPageModal(
      title: l.syncConflict_title,
      subtitle: subtitle,
      child: switch (conflict) {
        null => Center(child: Text(l.syncConflict_missingNotice)),
        final c when c.resolutionState != conflictUnresolved =>
          Center(child: Text(l.syncConflict_resolvedNotice)),
        final c => _body(context, l, c),
      },
    );
  }

  Widget _body(
    BuildContext context,
    AppLocalizations l,
    ConflictLogRow conflict,
  ) {
    final server = decodeJsonObject(conflict.serverPayload);
    final submitted = decodeJsonObject(conflict.submittedPayload);
    final fields = _changedFields(conflict, submitted);
    final isTombstone = server['is_deleted'] == true;
    final editorId = server['last_modified_by'];

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.edgeMargin,
        AppSpacing.md,
        AppSpacing.edgeMargin,
        AppSpacing.xl,
      ),
      children: [
        if (editorId is String && editorId.isNotEmpty)
          _EditorLine(editorId: editorId),
        const SizedBox(height: AppSpacing.sm),
        if (isTombstone)
          _Card(child: _tombstoneBody(context, l, conflict))
        else ...[
          Text(
            l.syncConflict_intro,
            style: AppTypography.bodyMd.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final diff in fields) ...[
            _FieldCard(
              diff: diff,
              keepMine: _keepMine[diff.field] ?? true,
              onChanged: (mine) => setState(() => _keepMine[diff.field] = mine),
            ),
            const SizedBox(height: AppSpacing.gutter),
          ],
          _saveButton(l, conflict, fields),
        ],
        const SizedBox(height: AppSpacing.lg),
        _LaterEdits(conflict: conflict),
      ],
    );
  }

  /// The tombstone's two legal answers, and nothing else.
  Widget _tombstoneBody(
    BuildContext context,
    AppLocalizations l,
    ConflictLogRow conflict,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Icon(Icons.delete_outline, color: AppColors.error, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              l.syncConflict_tombstoneTitle,
              style: AppTypography.titleMd.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.sm),
      Text(l.syncConflict_tombstoneBody, style: AppTypography.bodyMd),
      const SizedBox(height: AppSpacing.lg),
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: _busy
              ? null
              : () => _run((resolver) => resolver.rebaseOntoNewRecord(conflict)),
          style: _primaryStyle,
          child: Text(l.syncConflict_rebaseOntoNewRecord),
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: _busy ? null : () => _confirmDiscard(context, l, conflict),
          child: Text(l.syncConflict_discard),
        ),
      ),
    ],
  );

  /// Writes the chosen value for every disagreeing field in one mutation.
  Widget _saveButton(
    AppLocalizations l,
    ConflictLogRow conflict,
    List<_FieldDiff> fields,
  ) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      onPressed: _busy ? null : () => _resolve(conflict, fields),
      style: _primaryStyle,
      child: Text(l.sharedActions_save),
    ),
  );

  Future<void> _resolve(
    ConflictLogRow conflict,
    List<_FieldDiff> fields,
  ) async {
    final server = decodeJsonObject(conflict.serverPayload);
    final chosen = <String, dynamic>{};
    for (final diff in fields) {
      // Keeping the server value is still a deliberate choice, and it is sent
      // explicitly so the merged row is unambiguous.
      chosen[diff.field] = (_keepMine[diff.field] ?? true)
          ? diff.localValue
          : server[diff.field];
    }
    await _run((resolver) => resolver.resolveWithFields(conflict, chosen: chosen));
  }

  Future<void> _confirmDiscard(
    BuildContext context,
    AppLocalizations l,
    ConflictLogRow conflict,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.syncConflict_discardConfirmTitle),
        content: Text(l.syncConflict_discardConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.sharedActions_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.syncConflict_discard),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run((resolver) => resolver.discard(conflict));
  }

  /// Runs one resolution and leaves the screen once it is written.
  Future<void> _run(
    Future<void> Function(ConflictResolver resolver) action,
  ) async {
    setState(() => _busy = true);
    try {
      final resolver = await ref.read(conflictResolverProvider.future);
      await action(resolver);
      if (!mounted) return;
      context.pop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The fields worth showing: the mutation's own list, minus what every write
  /// touches. An older row without a list falls back to every key it submitted.
  List<_FieldDiff> _changedFields(
    ConflictLogRow conflict,
    Map<String, dynamic> submitted,
  ) {
    final named = decodeJsonStringList(conflict.changedFields);
    final candidates = named.isEmpty ? submitted.keys.toList() : named;
    final server = decodeJsonObject(conflict.serverPayload);
    return [
      for (final field in candidates)
        if (!syncBookkeepingFields.contains(field) &&
            (server.containsKey(field) || submitted.containsKey(field)))
          _FieldDiff(field, server[field], submitted[field]),
    ];
  }

  static final ButtonStyle _primaryStyle = FilledButton.styleFrom(
    backgroundColor: AppColors.primary,
    foregroundColor: AppColors.onPrimary,
    textStyle: AppTypography.titleMd,
    minimumSize: const Size.fromHeight(settingsPrimaryButtonHeight),
  );
}

/// Plain white bordered card, matching the Settings sub-page cards.
class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
      border: Border.all(color: AppColors.outlineVariant),
    ),
    padding: const EdgeInsets.all(AppSpacing.lg),
    child: child,
  );
}

/// "Edited By {name}" resolved from this device's own profile cache.
///
/// A chamber colleague's name is **not** on this device — `profiles` holds this
/// account's own row (rule 4) — so the fallback is what a member sees for one: a
/// neutral label. "Another Device" is kept outside a chamber, where it is true.
/// The row itself is the app's one attribution style, shared with the case
/// History's *Added By* (`AttributionLine`).
class _EditorLine extends ConsumerWidget {
  const _EditorLine({required this.editorId});

  final String editorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final name = ref.watch(accountDisplayNameProvider(editorId)).value;
    final fallback = ref.watch(firmModeProvider)
        ? l.sharedLabels_chamberMember
        : l.syncConflict_unknownEditor;
    return AttributionLine(label: l.syncConflict_editedBy(name ?? fallback));
  }
}

/// One field, with the two candidate values and a choice between them.
class _FieldCard extends StatelessWidget {
  const _FieldCard({
    required this.diff,
    required this.keepMine,
    required this.onChanged,
  });

  final _FieldDiff diff;

  /// True when the local value is the one being kept.
  final bool keepMine;

  /// Reports the new choice.
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(diff.label, style: AppTypography.labelLg),
          const SizedBox(height: AppSpacing.sm),
          if (!diff.differs)
            Text(
              _formatValue(diff.serverValue),
              style: AppTypography.bodyMd.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: _Choice(
                    label: l.syncConflict_keepServer,
                    value: _formatValue(diff.serverValue),
                    selected: !keepMine,
                    onTap: () => onChanged(false),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _Choice(
                    label: l.syncConflict_keepMine,
                    value: _formatValue(diff.localValue),
                    selected: keepMine,
                    onTap: () => onChanged(true),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// One selectable value inside a field card.
class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
    child: Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.surfaceContainerHigh
            : AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 16,
                color: selected ? AppColors.primary : AppColors.tertiary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                label,
                style: AppTypography.labelMd.copyWith(
                  color: selected ? AppColors.primary : AppColors.tertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(value, style: AppTypography.bodySm, maxLines: 3),
        ],
      ),
    ),
  );
}

/// The later queue entries the freeze preserved for the same entity.
class _LaterEdits extends ConsumerWidget {
  const _LaterEdits({required this.conflict});

  final ConflictLogRow conflict;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final rows = ref
            .watch(_entityQueueProvider((conflict.entityType, conflict.entityId)))
            .value ??
        const <SyncQueueRow>[];
    final later = rows
        .where((row) =>
            row.mutationId != conflict.mutationId && row.state != 'resolved')
        .toList();
    if (later.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.syncConflict_laterEditsTitle, style: AppTypography.titleMd),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l.syncConflict_laterEditsBody,
          style: AppTypography.bodySm.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final row in later)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: _Card(
              child: Text(
                '${row.operation} · ${decodeJsonStringList(row.changedFields).join(', ')}',
                style: AppTypography.bodySm,
              ),
            ),
          ),
      ],
    );
  }
}
