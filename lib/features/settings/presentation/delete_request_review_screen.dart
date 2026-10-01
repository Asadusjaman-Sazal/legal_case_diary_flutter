/// Delete request review screen: one decision, made against a locked target.
///
/// Task 20 Phase 4's reviewer surface. It shows the `entity_snapshot` the
/// requester took, who asked and when, and the two actions — **Approve** and
/// **Reject** — plus an optional review note. A request the server parked as
/// `stale_review_required` renders the same way with a warning: what follows is
/// the record as it exists *now*, and the button reads **Reconfirm**.
///
/// The screen never deletes anything itself and never decides anything itself.
/// It writes the request row through [DeleteRequestsViewModel] and the server
/// decides: an approval against an unchanged target tombstones it atomically, and
/// one against a changed target is refused and parked for a reconfirm. That is
/// why the screen reads the request back out of the live stream rather than
/// holding the row it was opened with — after a refusal the row *is* the
/// refreshed, stale one, and the screen has to show it.
///
/// It is a review surface for a firm member with delete permission only. The
/// requester's own view lives on the list screen beside it.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/utils/date_utils.dart';
import '../../../database/app_database.dart';
import '../../auth/presentation/auth_widgets.dart';
import 'delete_requests_viewmodel.dart';
import 'settings_controls.dart';
import 'settings_menu_card.dart';
import 'settings_sub_page_modal.dart';

/// Human label of the entity a request names.
String deleteRequestEntityLabel(AppLocalizations l, String entityType) =>
    switch (entityType) {
      'case' => l.deleteRequests_entityCase,
      'case_history' => l.deleteRequests_entityCaseHistory,
      'note' => l.deleteRequests_entityNote,
      'reference' => l.deleteRequests_entityReference,
      _ => l.deleteRequests_entityUnknown,
    };

/// The snapshot a request carries, decoded; empty when it cannot be read.
///
/// A snapshot is a JSON object written by this same app, so a decode failure can
/// only mean a corrupted local row — the screen shows what it can rather than
/// throwing over it.
Map<String, dynamic> deleteRequestSnapshotMap(DeleteRequest request) {
  try {
    final decoded = jsonDecode(request.entitySnapshot);
    if (decoded is Map<String, dynamic>) return decoded;
  } on FormatException {
    // Fall through to the empty map.
  }
  return const <String, dynamic>{};
}

/// The one-line summary of what is being deleted.
///
/// The field the entity is known by — a case's number, a note's title, a
/// reference's page — so a queue row is readable without opening it.
String deleteRequestSummary(DeleteRequest request, AppLocalizations l) {
  final snapshot = deleteRequestSnapshotMap(request);
  final candidate = switch (request.entityType) {
    'case' => snapshot['case_number'],
    'case_history' => snapshot['last_step'] ?? snapshot['note_result'],
    'note' => snapshot['title'],
    'reference' =>
      snapshot['reference_and_page_no'] ?? snapshot['title_and_description'],
    _ => null,
  };
  final text = candidate?.toString().trim() ?? '';
  return text.isEmpty ? l.deleteRequests_unnamed : text;
}

/// The snapshot's own fields, as labelled rows, for the entity kinds the app
/// raises requests for. An unknown kind simply has no rows to show.
List<(String, String)> deleteRequestDetailRows(
  DeleteRequest request,
  AppLocalizations l,
) {
  final snapshot = deleteRequestSnapshotMap(request);
  String value(String key) => (snapshot[key] ?? '').toString().trim();

  final rows = <(String, String)>[];
  void add(String label, String text) {
    if (text.isNotEmpty) rows.add((label, text));
  }

  switch (request.entityType) {
    case 'case':
      add(l.deleteRequests_fieldCaseNumber, value('case_number'));
      add(l.deleteRequests_fieldCaseType, value('case_type'));
      add(l.deleteRequests_fieldPetitioner, value('petitioner'));
      add(l.deleteRequests_fieldRespondent, value('respondent'));
    case 'case_history':
      add(l.deleteRequests_fieldStep, value('last_step'));
      add(l.deleteRequests_fieldResult, value('note_result'));
    case 'note':
      add(l.deleteRequests_fieldTitle, value('title'));
      add(l.deleteRequests_fieldBody, value('body'));
    case 'reference':
      add(l.deleteRequests_fieldReference, value('reference_and_page_no'));
      add(l.deleteRequests_fieldDescription, value('title_and_description'));
  }
  return rows;
}

/// The reviewer's view of one delete request.
class DeleteRequestReviewScreen extends ConsumerStatefulWidget {
  /// Creates the screen for the request with [requestId].
  const DeleteRequestReviewScreen({required this.requestId, super.key});

  /// The request being reviewed.
  final String requestId;

  @override
  ConsumerState<DeleteRequestReviewScreen> createState() =>
      _DeleteRequestReviewScreenState();
}

class _DeleteRequestReviewScreenState
    extends ConsumerState<DeleteRequestReviewScreen> {
  /// The optional review note.
  final TextEditingController _noteController = TextEditingController();

  /// Set while a decision is being written, so no button is tapped twice.
  bool _busy = false;

  /// Set when the last write failed; cleared when a new attempt starts.
  bool _failed = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final request = ref
        .watch(deleteRequestsStreamProvider)
        .value
        ?.where((row) => row.id == widget.requestId)
        .firstOrNull;

    // The row can only vanish locally through a soft-delete the requester made
    // on this same device, so this is a message rather than an error.
    if (request == null) {
      return SettingsSubPageModal(
        title: l.deleteRequests_reviewTitle,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: AuthErrorBanner(text: l.deleteRequests_noneToReview),
          ),
        ),
      );
    }

    final stale = request.status == 'stale_review_required';
    final locale = Localizations.localeOf(context).toString();
    final requester = ref
        .watch(deleteRequestRequesterNameProvider(request.requestedBy))
        .value;

    return SettingsSubPageModal(
      title: l.deleteRequests_reviewTitle,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.edgeMargin,
          AppSpacing.md,
          AppSpacing.edgeMargin,
          AppSpacing.xl,
        ),
        children: [
          _HeaderCard(
            request: request,
            l: l,
            locale: locale,
            requester: requester ?? l.deleteRequests_unknownRequester,
          ),
          // The stale warning sits above the details on purpose: it is the one
          // thing that changes what this screen is asking the reviewer to do.
          if (stale) ...[
            const SizedBox(height: AppSpacing.md),
            AuthErrorBanner(
              text: '${l.deleteRequests_staleTitle}. ${l.deleteRequests_staleBody}',
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          SettingsSectionLabel(l.deleteRequests_snapshot),
          const SizedBox(height: AppSpacing.sm),
          _SnapshotCard(rows: deleteRequestDetailRows(request, l)),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            key: const ValueKey('delete-review-note'),
            controller: _noteController,
            enabled: !_busy,
            maxLines: 3,
            minLines: 2,
            style: AppTypography.bodyMd,
            decoration: InputDecoration(
              labelText: l.deleteRequests_noteLabel,
              hintText: l.deleteRequests_noteHint,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
            ),
          ),
          if (_failed) ...[
            const SizedBox(height: AppSpacing.md),
            AuthErrorBanner(text: l.deleteRequests_failed),
          ],
          const SizedBox(height: AppSpacing.md),
          _PrimaryButton(
            key: const ValueKey('delete-review-approve'),
            icon: Icons.delete_outline,
            label: stale
                ? l.deleteRequests_reconfirm
                : l.deleteRequests_approve,
            // Approving deletes data, so it is the error-coloured action; the
            // armed state is what makes the two buttons tell themselves apart.
            destructive: true,
            onPressed: _busy ? null : () => _decide(approve: true),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const ValueKey('delete-review-reject'),
              onPressed: _busy ? null : () => _decide(approve: false),
              icon: const Icon(Icons.close, size: 18),
              label: Text(l.deleteRequests_reject),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: AppColors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Writes one decision after confirming it, then returns to the list.
  Future<void> _decide({required bool approve}) async {
    final l = AppLocalizations.of(context);
    // Captured before the write: the snackbar is shown after this screen pops,
    // and a context that has been popped can no longer find its messenger.
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await _confirm(
      context: context,
      title: approve
          ? l.deleteRequests_approveTitle
          : l.deleteRequests_rejectTitle,
      body: approve ? l.deleteRequests_approveBody : l.deleteRequests_rejectBody,
      confirmLabel: approve
          ? l.deleteRequests_approve
          : l.deleteRequests_reject,
    );
    if (!confirmed || !mounted) return;

    final note = _noteController.text.trim();
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      final viewModel = ref.read(deleteRequestsViewModelProvider.notifier);
      if (approve) {
        await viewModel.approve(
          widget.requestId,
          reviewNote: note.isEmpty ? null : note,
        );
      } else {
        await viewModel.reject(
          widget.requestId,
          reviewNote: note.isEmpty ? null : note,
        );
      }
      if (!mounted) return;
      Navigator.of(context).maybePop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            approve ? l.deleteRequests_approved : l.deleteRequests_rejected,
          ),
        ),
      );
    } on Object {
      if (!mounted) return;
      setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// The request's identity: what it is, who asked and when.
class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.request,
    required this.l,
    required this.locale,
    required this.requester,
  });

  final DeleteRequest request;
  final AppLocalizations l;
  final String locale;
  final String requester;

  @override
  Widget build(BuildContext context) => Container(
    decoration: settingsCardDecoration(),
    padding: const EdgeInsets.all(AppSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Text(
                deleteRequestEntityLabel(l, request.entityType),
                style: AppTypography.labelMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(deleteRequestSummary(request, l), style: AppTypography.bodyLg),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l.deleteRequests_requestedBy(requester),
          style: AppTypography.bodySm.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        Text(
          l.deleteRequests_requestedOn(
            AppDateUtils.formatDateDDMMYYYY(request.createdAt, locale: locale),
          ),
          style: AppTypography.bodySm.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}

/// The snapshot's fields as labelled rows, or a note when there are none.
class _SnapshotCard extends StatelessWidget {
  const _SnapshotCard({required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    decoration: settingsCardDecoration(),
    padding: const EdgeInsets.all(AppSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const Divider(height: AppSpacing.lg),
          Text(
            rows[i].$1,
            style: AppTypography.labelMd.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(rows[i].$2, style: AppTypography.bodyMd),
        ],
        if (rows.isEmpty)
          Text(
            AppLocalizations.of(context).deleteRequests_unnamed,
            style: AppTypography.bodyMd.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
      ],
    ),
  );
}

/// The screen's full-width action at the shared Settings button height.
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.destructive = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: onPressed,
    icon: Icon(icon, size: 20),
    label: Text(label),
    style: FilledButton.styleFrom(
      backgroundColor: destructive ? AppColors.error : AppColors.primary,
      foregroundColor: destructive ? AppColors.onError : AppColors.onPrimary,
      textStyle: AppTypography.titleMd,
      minimumSize: const Size.fromHeight(settingsPrimaryButtonHeight),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
    ),
  );
}

/// A titled confirmation window, with the destructive action in the error colour.
Future<bool> _confirm({
  required BuildContext context,
  required String title,
  required String body,
  required String confirmLabel,
}) async {
  final l = AppLocalizations.of(context);
  final answer = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l.sharedActions_cancel),
        ),
        FilledButton(
          key: const ValueKey('delete-review-confirm'),
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return answer ?? false;
}
