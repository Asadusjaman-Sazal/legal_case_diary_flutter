/// Sync Status screen (Task 19 Phase 4).
///
/// Every unfinished queue entry in one list, so nothing the sync engine is
/// holding can go unseen: what it is, what it was trying to do, why it stopped,
/// and how many times it has tried. The filter chips are a view over that single
/// list rather than four separate queries, which is why the "All" chip can never
/// disagree with the count on the header badge that opened this screen.
///
/// The actions are the plan's three: **Retry** returns a blocked entry to the
/// queue, **Discard** drops the mutation and puts the record back to a state the
/// server agrees with (behind a confirmation, because it throws work away), and
/// **Review Conflict** hands a frozen entry to the Phase 3 screen. The fourth —
/// exporting a diagnostic bundle — is whole-queue and lives in the app bar, so
/// the bundle is one file describing the device rather than one file per row.
///
/// No mockup HTML exists for this screen; it follows the established Settings
/// sub-page shell and the Justice Ledger tokens, as the task file permits.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/backup/diagnostic_bundle.dart';
import '../../../core/errors/error_log_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/app_translations.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/router/app_router.dart';
import '../../../database/app_database.dart';
import '../../../shared/providers/database_provider.dart';
import '../../../sync/sync_metadata_dao.dart';
import '../../../sync/sync_service.dart';
import '../../../sync/sync_status_providers.dart';
import '../../../sync/sync_providers.dart';
import '../../settings/data/backup_file_gateway.dart';
import '../../settings/data/backup_metadata_store.dart';
import '../../settings/presentation/backup_dialogs.dart';
import '../../settings/presentation/edit_court_steps/court_category_label.dart';
import '../../settings/presentation/settings_sub_page_modal.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_dialog_actions.dart';

/// The Sync Status / Diagnostics screen.
class SyncStatusScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const SyncStatusScreen({super.key});

  @override
  ConsumerState<SyncStatusScreen> createState() => _SyncStatusScreenState();
}

class _SyncStatusScreenState extends ConsumerState<SyncStatusScreen> {
  /// The selected chip. Defaults to All, which hides nothing.
  SyncStatusFilter _filter = SyncStatusFilter.all;

  /// True while a bundle is being written, so Export cannot be tapped twice.
  bool _exporting = false;

  /// True while a *Sync Now* press is draining, so its button spins and cannot
  /// be pressed twice before the run reports back.
  bool _syncing = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final entries =
        ref.watch(syncQueueEntriesProvider).value ?? const <SyncQueueRow>[];
    final counts = syncStatusCounts(entries);
    final visible = entries
        .where((row) => syncStatusMatches(row, _filter))
        .toList(growable: false);
    // What each entry is about, resolved from the local rows: the queue carries
    // only an entity type and id, which names nothing a user can recognise.
    final subjects =
        ref.watch(syncEntrySubjectsProvider).value ??
        const <String, SyncEntrySubject>{};

    return SettingsSubPageModal(
      // The screen is the queue of work still waiting, so it is named for that
      // (user request); the header badge elsewhere keeps the older tooltip.
      title: l.settingsOnlineSync_pendingSyncTitle,
      subtitle: l.syncStatus_subtitle,
      actions: [
        IconButton(
          key: const ValueKey('sync-status-export'),
          icon: const Icon(Icons.file_download_outlined),
          tooltip: l.syncStatus_export,
          onPressed: entries.isEmpty || _exporting ? null : _export,
        ),
      ],
      child: Column(
        children: [
          _LastSyncedLine(l: l),
          _FilterBar(
            counts: counts,
            selected: _filter,
            onSelected: (filter) => setState(() => _filter = filter),
            l: l,
          ),
          Expanded(
            child: visible.isEmpty
                ? _EmptyState(l: l)
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.edgeMargin,
                      AppSpacing.sm,
                      AppSpacing.edgeMargin,
                      AppSpacing.xl,
                    ),
                    itemCount: visible.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.gutter),
                    itemBuilder: (context, index) {
                      final row = visible[index];
                      return _QueueEntryCard(
                        row: row,
                        subject:
                            subjects[syncSubjectKey(
                              row.entityType,
                              row.entityId,
                            )],
                        l: l,
                        onRetry: () => _retry(row),
                        onSyncNow: _syncNow,
                        syncing: _syncing,
                        onDiscard: () => _discard(row),
                        onReview: () => _review(row),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// Sync Now: run one forced drain and report what the engine says afterwards.
  ///
  /// The same two sentences the Online Sync screen's own button uses, read from
  /// the engine rather than assumed: `syncNow` returns silently when a guard
  /// refuses it, and a failure surfaces as a failure count, not an exception.
  Future<void> _syncNow() async {
    if (_syncing) return;
    final l = AppLocalizations.of(context);
    setState(() => _syncing = true);
    try {
      await ref.read(syncServiceProvider).syncNow(force: true, pull: true);
      if (!mounted) return;
      final failed = ref.read(syncHealthProvider).value?.consecutiveFailures;
      _say(
        failed != null && failed > 0
            ? l.settingsOnlineSync_syncFailed
            : l.settingsOnlineSync_syncFinished,
      );
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  /// Retry: make a blocked entry eligible again and say so.
  Future<void> _retry(SyncQueueRow row) async {
    final l = AppLocalizations.of(context);
    final actions = await ref.read(syncStatusActionsProvider.future);
    await actions.retry(row);
    if (!mounted) return;
    _say(l.syncStatus_retried);
  }

  /// Review Conflict: hand the entry to the Phase 3 screen.
  ///
  /// It needs the conflict's own id, not the queue row's, so the newest
  /// unresolved conflict for this entity is what opens. With none — a state that
  /// should not be reachable, because a frozen row always has a conflict behind
  /// it — the screen says so rather than opening a blank page.
  Future<void> _review(SyncQueueRow row) async {
    final l = AppLocalizations.of(context);
    final conflicts = ref.read(unresolvedConflictsProvider).value ?? const [];
    final match = conflicts
        .where(
          (conflict) =>
              conflict.entityType == row.entityType &&
              conflict.entityId == row.entityId,
        )
        .firstOrNull;
    if (match == null) {
      _say(l.syncConflict_missingNotice);
      return;
    }
    await context.push(AppRoutes.reviewConflictPath(match.id));
  }

  /// Discard: confirm, then drop the mutation and roll the record back.
  Future<void> _discard(SyncQueueRow row) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showAppConfirmDialog(
      context,
      title: l.syncStatus_discardTitle,
      message: l.syncStatus_discardBody,
      cancelLabel: l.sharedActions_cancel,
      confirmLabel: l.syncStatus_discardConfirm,
      confirmKind: AppDialogActionKind.text,
    );
    if (!confirmed) return;

    final actions = await ref.read(syncStatusActionsProvider.future);
    final outcome = await actions.discard(row);
    if (!mounted) return;
    _say(switch (outcome) {
      SyncDiscardOutcome.rolledBackLocally =>
        l.syncStatus_discardRestoredLocally,
      SyncDiscardOutcome.dropped => l.syncStatus_discarded,
      _ => l.syncStatus_discarded,
    });
  }

  /// Export: choose a scope, take consent if payloads are included, then seal
  /// and write the bundle through the platform's save dialog.
  Future<void> _export() async {
    final l = AppLocalizations.of(context);
    final includePayloads = await _chooseExportScope();
    if (includePayloads == null || !mounted) return;
    if (includePayloads) {
      final consent = await _confirmPayloadConsent();
      if (!consent || !mounted) return;
    }
    // A passphrase is asked for only when encryption is on (off by default):
    // with it off the bundle is written as readable JSON.
    final String? secret;
    if (ref.read(backupMetadataProvider).encryptBackups) {
      secret = await showBackupPassphraseDialog(context);
      if (secret == null || secret.isEmpty || !mounted) return;
    } else {
      secret = null;
    }

    setState(() => _exporting = true);
    try {
      final entries =
          ref.read(syncQueueEntriesProvider).value ?? const <SyncQueueRow>[];
      final db = await ref.read(databaseProvider.future);
      final generatedAt = DateTime.now().toUtc().millisecondsSinceEpoch;
      final bundle = buildDiagnosticBundle(
        entries: [
          for (final row in entries)
            diagnosticEntryFor(
              entityType: row.entityType,
              entityId: row.entityId,
              operation: row.operation,
              state: row.state,
              retryCount: row.retryCount,
              createdAt: row.createdAt,
              lastAttemptAt: row.lastAttemptAt,
              lastError: row.lastError,
              baseVersion: row.baseVersion,
              changedFields: row.changedFields,
              basePayload: row.basePayload,
              payload: row.payload,
              preMutationPayload: row.preMutationPayload,
              includePayloads: includePayloads,
            ),
        ],
        metadata: await _diagnosticMetadata(db),
        // The failures the queue cannot show — sign-in, payments, profile,
        // anything the app recorded. Already redacted, and never payloads.
        errors: <Map<String, dynamic>>[
          for (final entry in ref.read(errorLogProvider).entries)
            entry.toJson(),
        ],
        includePayloads: includePayloads,
        generatedAt: generatedAt,
      );
      final result = await exportDiagnosticBundle(
        bundle: bundle,
        recoverySecret: secret,
        generatedAt: generatedAt,
        write: ref.read(backupFileGatewayProvider).write,
      );
      if (!mounted) return;
      _say(l.syncStatus_exportSaved(result.path));
    } on BackupSaveCancelledException {
      // The save dialog was dismissed: nothing was written and nothing is owed.
    } on Exception {
      if (mounted) _say(l.syncStatus_exportFailed);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  /// Reads the two sync metadata values a support reader asks about first.
  Future<Map<String, String?>> _diagnosticMetadata(AppDatabase db) async {
    final metadata = SyncMetadataDao(db);
    return {
      lastSuccessfulSyncAtKey: await metadata.getValue(lastSuccessfulSyncAtKey),
      clockOffsetMsKey: await metadata.getValue(clockOffsetMsKey),
    };
  }

  /// The scope sheet: metadata only (the default) or payloads included.
  Future<bool?> _chooseExportScope() => showModalBottomSheet<bool>(
    context: context,
    builder: (context) => _ExportScopeSheet(l: AppLocalizations.of(context)),
  );

  /// The explicit consent for including case content.
  Future<bool> _confirmPayloadConsent() {
    final l = AppLocalizations.of(context);
    return showAppConfirmDialog(
      context,
      title: l.syncStatus_exportConsentTitle,
      message: l.syncStatus_exportConsentBody,
      cancelLabel: l.sharedActions_cancel,
      confirmLabel: l.syncStatus_exportConsentConfirm,
      confirmKind: AppDialogActionKind.text,
    );
  }

  void _say(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
}

/// The live "Last Synced …" line, read from the durable sync metadata.
class _LastSyncedLine extends ConsumerWidget {
  const _LastSyncedLine({required this.l});

  final AppLocalizations l;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lastSuccess = ref.watch(syncLastSuccessProvider).value;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.edgeMargin,
        AppSpacing.md,
        AppSpacing.edgeMargin,
        0,
      ),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          lastSuccess == null
              ? l.syncStatus_lastSyncedNever
              : l.syncStatus_lastSynced(syncStatusRelativeTime(l, lastSuccess)),
          style: AppTypography.bodySm,
        ),
      ),
    );
  }
}

/// The filter chips, each labelled with how many entries it would show.
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.counts,
    required this.selected,
    required this.onSelected,
    required this.l,
  });

  final Map<SyncStatusFilter, int> counts;
  final SyncStatusFilter selected;
  final ValueChanged<SyncStatusFilter> onSelected;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 64,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.edgeMargin,
        vertical: AppSpacing.md,
      ),
      children: [
        for (final filter in SyncStatusFilter.values) ...[
          _FilterChip(
            label: '${_filterLabel(l, filter)} ${counts[filter] ?? 0}',
            selected: filter == selected,
            onTap: () => onSelected(filter),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ],
    ),
  );

  String _filterLabel(AppLocalizations l, SyncStatusFilter filter) =>
      switch (filter) {
        SyncStatusFilter.all => l.syncStatus_filterAll,
        SyncStatusFilter.pending => l.syncStatus_filterPending,
        SyncStatusFilter.conflicted => l.syncStatus_filterConflicted,
        SyncStatusFilter.blocked => l.syncStatus_filterBlocked,
      };
}

/// One chip: the unified active black when selected, a muted fill otherwise.
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected
        ? AppColors.secondaryContainer
        : AppColors.surfaceContainerLow,
    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.gutter,
          vertical: AppSpacing.sm,
        ),
        child: Text(
          label,
          style: AppTypography.labelMd.copyWith(
            color: selected
                ? AppColors.onSecondaryContainer
                : AppColors.onSurfaceVariant,
          ),
        ),
      ),
    ),
  );
}

/// The empty state: nothing is waiting, which is the good outcome.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.l});

  final AppLocalizations l;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
            ),
            child: const Icon(
              Icons.cloud_done_outlined,
              size: 32,
              color: AppColors.tertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(l.syncStatus_emptyTitle, style: AppTypography.titleMd),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l.syncStatus_emptyBody,
            style: AppTypography.bodySm,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

/// One queue entry: what it is, why it is held, and what can be done about it.
class _QueueEntryCard extends StatelessWidget {
  const _QueueEntryCard({
    required this.row,
    required this.subject,
    required this.l,
    required this.onRetry,
    required this.onSyncNow,
    required this.syncing,
    required this.onDiscard,
    required this.onReview,
  });

  final SyncQueueRow row;

  /// What the entry is about, when the local rows still name it.
  final SyncEntrySubject? subject;

  final AppLocalizations l;
  final VoidCallback onRetry;
  final VoidCallback onSyncNow;

  /// True while the screen's forced run is in flight.
  final bool syncing;

  final VoidCallback onDiscard;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final error = row.lastError;
    final lastAttemptAt = row.lastAttemptAt;
    final isBlocked = row.state == 'blocked';
    // The identifying line, so the card names which record the issue is about
    // rather than only what kind of record it is.
    final identity = syncSubjectLine(context, row, subject);
    final courtLine = syncSubjectCourtLine(context, subject);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l.syncStatus_entryTitle(
                    _titleCase(row.entityType.replaceAll('_', ' ')),
                    _titleCase(row.operation),
                  ),
                  style: AppTypography.titleMd,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // A destructive provisional action is named as one: the state pill
              // says `pending`, which is true of every queued edit, so without
              // this a queued deletion is not visibly different from a queued
              // rename (Task 20 Phase 2 item 4, plan §1).
              if (isDestructiveQueueOperation(row.operation)) ...[
                _PendingDeletionPill(label: l.syncStatus_pendingDeletion),
                const SizedBox(width: AppSpacing.xs),
              ],
              _StatePill(state: row.state, l: l),
            ],
          ),
          if (identity != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(identity, style: AppTypography.caseNumber),
          ],
          if (courtLine != null) Text(courtLine, style: AppTypography.bodySm),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${l.syncStatus_queued(syncStatusRelativeTime(l, row.createdAt))}'
            ' · ${l.syncStatus_attempted(row.retryCount)}',
            style: AppTypography.bodySm,
          ),
          if (lastAttemptAt != null)
            Text(
              l.syncStatus_lastAttempt(
                syncStatusRelativeTime(l, lastAttemptAt),
              ),
              style: AppTypography.bodySm,
            ),
          // A blocked card carries its reason in a labelled block of its own:
          // the pill says *that* it stopped, and these are the facts that say
          // why. Every other state keeps the plain error line, which is all it
          // needs — a pending row is still going to be tried.
          if (isBlocked)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: _BlockedWhyBlock(
                cause: syncBlockCause(row),
                message: error,
                l: l,
              ),
            )
          else if (error != null && error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                l.syncStatus_lastError(error),
                style: AppTypography.bodySm.copyWith(color: AppColors.error),
              ),
            ),
          const Divider(height: AppSpacing.lg),
          Row(
            children: [
              ..._inlineActions(),
              const Spacer(),
              // A button rather than a menu row (user request): it now sits
              // beside the state's own action and wears the app's black button
              // style — the same size, background and ink as *Sync Now*.
              TextButton(
                key: const ValueKey('sync-status-entry-discard'),
                onPressed: onDiscard,
                child: Text(l.syncStatus_discard),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// The action that matches the row's state. Discard sits beside it in the
  /// card's own row, so it is a button whatever the state is.
  List<Widget> _inlineActions() => switch (row.state) {
    'blocked' => [
      TextButton(onPressed: onRetry, child: Text(l.syncStatus_retry)),
    ],
    'conflict_pending' => [
      TextButton(onPressed: onReview, child: Text(l.syncStatus_reviewConflict)),
    ],
    'pending' || 'pushing' => [
      // The loading icon the Online Sync button shows: the button greys out and
      // spins until the run reports back, then the toast says how it ended.
      TextButton(
        onPressed: syncing ? null : onSyncNow,
        child: syncing
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(l.settingsOnlineSync_syncing),
                ],
              )
            : Text(l.settingsOnlineSync_syncNow),
      ),
    ],
    _ => const <Widget>[],
  };
}

/// The identifying line for one entry, or null when there is nothing to name.
///
/// A case reads exactly as it does on every case screen — the localized case
/// type followed by the case number — because that is the pair the user knows
/// the record by. An entry that is not a case shows its own local name; a
/// court and a court category resolve theirs the way their own screens do, and
/// everything else (`case_types`, `steps`, `on_behalfs`, `case_categories`)
/// stores the name it is displayed under.
String? syncSubjectLine(
  BuildContext context,
  SyncQueueRow row,
  SyncEntrySubject? subject,
) {
  if (subject == null || subject.isEmpty) return null;
  if (subject.isCase) {
    final type = context.l10n
        .caseTypeLabel(
          subject.caseType ?? '',
          courtCategoryId: subject.court?.courtCategoryId,
        )
        .trim();
    final number = subject.caseNumber!.trim();
    if (type.isEmpty) return number;
    return number.isEmpty ? type : '$type $number';
  }
  final name = subject.entityName!;
  return switch (row.entityType) {
    // A pre-seeded court stores an English name, and a court category stores a
    // localization key rather than a name at all.
    'court' => context.l10n.seedLabel(row.entityId, fallbackEn: name),
    'court_category' => courtCategoryName(context, name),
    _ => name,
  };
}

/// The court line under a case subject, or null when the case has no court.
///
/// The same resolution the case cards use: a pre-seeded court is labelled from
/// its id so it follows the active language, and a court the user added falls
/// back to the name stored with it.
String? syncSubjectCourtLine(BuildContext context, SyncEntrySubject? subject) {
  final court = subject?.court;
  if (court == null) return null;
  return context.l10n.seedLabel(court.id, fallbackEn: court.name);
}

/// Why a blocked entry stopped, as a labelled block on its own card.
///
/// The request was for the reason to be *labelled*: the state pill says
/// `blocked`, which repeats the pill problem it already has for `pending` — it
/// names the state and not the reason. So the card says why in words, and the
/// server's own message sits under that as the detail.
class _BlockedWhyBlock extends StatelessWidget {
  const _BlockedWhyBlock({
    required this.cause,
    required this.message,
    required this.l,
  });

  /// Why the entry is blocked, from the row's own facts.
  final SyncBlockCause cause;

  /// The server's message, when there is one.
  final String? message;

  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final detail = AppTypography.bodySm.copyWith(
      color: AppColors.onErrorContainer,
    );
    return Container(
      key: const ValueKey('sync-status-blocked-why'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.syncStatus_blockedWhy,
            style: AppTypography.labelMd.copyWith(color: AppColors.error),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            cause == SyncBlockCause.gaveUp
                ? l.syncStatus_blockedCauseAttempts
                : l.syncStatus_blockedCauseRefused,
            style: detail,
          ),
          if (message != null && message!.isNotEmpty)
            Text(l.syncStatus_lastError(message!), style: detail),
        ],
      ),
    );
  }
}

/// The state pill: colour says how bad it is, the label says what it is.
class _StatePill extends StatelessWidget {
  const _StatePill({required this.state, required this.l});

  final String state;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (state) {
      'blocked' => (AppColors.errorContainer, AppColors.onErrorContainer),
      'conflict_pending' => (AppColors.primaryFixed, AppColors.onPrimaryFixed),
      _ => (AppColors.surfaceContainerHigh, AppColors.onSurfaceVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state == 'pushing') ...[
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: foreground,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            _stateLabel(l, state),
            style: AppTypography.labelMd.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}

/// The scope sheet shown before an export.
class _ExportScopeSheet extends StatelessWidget {
  const _ExportScopeSheet({required this.l});

  final AppLocalizations l;

  @override
  Widget build(BuildContext context) => SafeArea(
    // Scrollable, so the sheet fits a short screen rather than overflowing.
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.edgeMargin,
              AppSpacing.lg,
              AppSpacing.edgeMargin,
              AppSpacing.sm,
            ),
            child: Text(l.syncStatus_exportTitle, style: AppTypography.titleLg),
          ),
          ListTile(
            key: const ValueKey('sync-status-export-metadata'),
            leading: const Icon(Icons.description_outlined),
            title: Text(l.syncStatus_exportMetadataOnly),
            subtitle: Text(l.syncStatus_exportMetadataOnlyBody),
            onTap: () => Navigator.of(context).pop(false),
          ),
          ListTile(
            key: const ValueKey('sync-status-export-payloads'),
            leading: const Icon(Icons.folder_shared_outlined),
            title: Text(l.syncStatus_exportIncludePayloads),
            subtitle: Text(l.syncStatus_exportIncludePayloadsBody),
            onTap: () => Navigator.of(context).pop(true),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.edgeMargin,
              AppSpacing.sm,
              AppSpacing.edgeMargin,
              AppSpacing.lg,
            ),
            child: Text(
              l.syncStatus_exportReminder,
              style: AppTypography.bodySm,
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Padding(
              padding: const EdgeInsets.only(
                right: AppSpacing.edgeMargin,
                bottom: AppSpacing.md,
              ),
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l.sharedActions_cancel),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// A relative time for the queue rows and the last-sync line.
///
/// Days are the coarsest unit on purpose: a queue entry older than a week is a
/// problem whatever the exact hour is, and the absolute time is in the bundle for
/// support. A timestamp in the future reads as "Just Now" rather than as a
/// negative age, because a skewed device clock is not this screen's subject.
String syncStatusRelativeTime(AppLocalizations l, int at) {
  final delta = DateTime.now().toUtc().millisecondsSinceEpoch - at;
  const minute = Duration.millisecondsPerMinute;
  const hour = Duration.millisecondsPerHour;
  const day = Duration.millisecondsPerDay;
  if (delta < minute) return l.syncStatus_timeJustNow;
  if (delta < hour) return l.syncStatus_timeMinutesAgo(delta ~/ minute);
  if (delta < day) return l.syncStatus_timeHoursAgo(delta ~/ hour);
  return l.syncStatus_timeDaysAgo(delta ~/ day);
}

/// Whether an operation destroys the record it names.
///
/// The one place the app decides what counts as destructive, so the pending
/// marker cannot drift from the delete paths that produce these entries. A
/// `delete_request` insert is destructive in intent but travels as an `insert`
/// of the request row, which Task 20 Phase 3/4 surface on their own review and
/// "my requests" screens for the reason that matters there: its *status* is the
/// pending fact, not its operation.
bool isDestructiveQueueOperation(String operation) => operation == 'delete';

/// The red "deletion pending" pill.
class _PendingDeletionPill extends StatelessWidget {
  const _PendingDeletionPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('sync-status-pending-deletion'),
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: AppSpacing.xs,
    ),
    decoration: BoxDecoration(
      color: AppColors.errorContainer,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
    ),
    child: Text(
      label,
      style: AppTypography.labelMd.copyWith(color: AppColors.error),
    ),
  );
}

/// A readable label for an entity type or an operation.
///
/// `ponytail:` these labels are data-derived (queue column values), not UI copy,
/// so they are title-cased at render time instead of adding a dozen ARB keys;
/// upgrade by mapping the twelve entity types onto ARB labels if localized
/// entity names are ever needed — the same approach the Review Conflict screen
/// takes for column names.
String _titleCase(String value) => value
    .split(' ')
    .where((part) => part.isNotEmpty)
    .map((part) => part[0].toUpperCase() + part.substring(1).toLowerCase())
    .join(' ');

/// The state pill's label.
String _stateLabel(AppLocalizations l, String state) => switch (state) {
  'pending' => l.syncStatus_statePending,
  'pushing' => l.syncStatus_statePushing,
  'conflict_pending' => l.syncStatus_stateConflicted,
  'blocked' => l.syncStatus_stateBlocked,
  _ => l.syncStatus_stateUnknown,
};
