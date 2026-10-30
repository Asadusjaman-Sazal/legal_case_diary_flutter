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
import '../../../core/l10n/app_translations.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/print/print_document.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/on_behalf_side.dart';
import '../../../database/app_database.dart';
import '../../../shared/widgets/app_dialog.dart';
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
  String value(String key) => (snapshot[key] ?? '').toString().trim();
  final candidate = switch (request.entityType) {
    // A case reads as the app writes one everywhere else — the type's own
    // trailing dash then the number, `Civil Appeal- 345/25` (user request: the
    // type was missing from this list). `caseTypeAndCaseNumber` is the one
    // writer of that reading, so the printouts, the client message and this
    // list can never disagree.
    'case' => caseTypeAndCaseNumber(value('case_type'), value('case_number')),
    'case_history' => snapshot['last_step'] ?? snapshot['note_result'],
    'note' => snapshot['title'],
    'reference' =>
      snapshot['reference_and_page_no'] ?? snapshot['title_and_description'],
    _ => null,
  };
  final text = candidate?.toString().trim() ?? '';
  return text.isEmpty ? l.deleteRequests_unnamed : text;
}

/// The fields of one record, as labelled rows, for the entity kinds the app
/// raises requests for. An unknown kind simply has no rows to show.
///
/// Taken by kind and snapshot rather than by request so the **same** renderer
/// draws the requester's stored copy and the record as it exists now (user
/// request: the reviewer judges what is there, not only what was asked about).
List<(String, String)> deleteRequestDetailRows(
  String entityType,
  Map<String, dynamic> snapshot,
  BuildContext context,
) {
  final l = AppLocalizations.of(context);
  String value(String key) => (snapshot[key] ?? '').toString().trim();

  final rows = <(String, String)>[];
  void add(String label, String text) {
    if (text.isNotEmpty) rows.add((label, text));
  }

  switch (entityType) {
    case 'case':
      // The type and the number are one reading under the number's own label
      // (user request): *Case Number* over `Civil Appeal- 345/25`, rather than
      // two rows the reviewer has to join up by eye.
      add(
        l.deleteRequests_fieldCaseNumber,
        caseTypeAndCaseNumber(value('case_type'), value('case_number')),
      );
      add(l.deleteRequests_fieldPetitioner, value('petitioner'));
      // The client's number sits under the party the case is pleaded for, the
      // same on-behalf rule the party card and pre-filled message use (user
      // request, 0.0.729).
      final side =
          representedSideOfId(value('on_behalf_id')) ?? PartySide.petitioner;
      if (side == PartySide.petitioner) {
        add(l.deleteRequests_fieldPetitionerPhone, value('party_phone'));
      }
      add(l.deleteRequests_fieldRespondent, value('respondent'));
      if (side == PartySide.respondent) {
        add(l.deleteRequests_fieldRespondentPhone, value('party_phone'));
      }
      add(
        l.addEditCaseSheet_caseTitleAndSection,
        value('case_title_and_section'),
      );
      add(l.addEditCaseSheet_caseRemarks, value('case_remarks'));
      final nextDate = snapshot['next_date'];
      if (nextDate is int) {
        final past =
            AppDateUtils.normalizeToBangladeshStartOfDay(nextDate) <
            AppDateUtils.bangladeshTodayStartOfDay();
        add(
          past ? l.caseCard_previousDate : l.addEditCaseSheet_nextDate,
          AppDateUtils.formatDisplayDate(
            nextDate,
            todayLabel: l.dailyCauseListScreen_today,
            tomorrowLabel: l.dailyCauseListScreen_tomorrow,
            locale: l.localeName,
          ),
        );
      }
      add(
        l.addEditCaseSheet_step,
        context.l10n.stepNames(value('last_step')) ?? '',
      );
      add(l.addEditCaseSheet_note, value('notes_results'));
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

  /// Whether the note box is holding the keyboard, which is what shows its
  /// cross (user request).
  bool _noteFocused = false;

  /// The note box's own focus, so the cross can hand the keyboard back.
  final FocusNode _noteFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _noteFocus.addListener(
      () => setState(() => _noteFocused = _noteFocus.hasFocus),
    );
  }

  @override
  void dispose() {
    _noteFocus.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// Empties the note box and hands the keyboard back (user request).
  ///
  /// One action for the cross in the box's own trailing slot, so the wipe and
  /// the focus change cannot get out of step, and so the box's state is settled
  /// before the frame the empty field is painted in.
  void _clearNote() {
    _noteController.clear();
    _noteFocus.unfocus();
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

    final parked = request.status == 'stale_review_required';
    // What exists now, as this device holds it. It is read for a parked request
    // and for a pending one, so a record that moved after the request was made
    // can be shown as changed before any approval is attempted (user request,
    // 0.0.726). Null when this device does not hold the record, which is not
    // the same thing as the record being gone — the card is simply left out.
    final current = request.status == 'pending' || parked
        ? ref.watch(deleteRequestTargetProvider(request.id)).value
        : null;
    final currentVersion = current?['version'];
    final locallyChanged =
        request.status == 'pending' &&
        currentVersion is int &&
        currentVersion > request.targetBaseVersion;
    // The server's own stale state, or the same answer read locally from the
    // record's version.
    final changed = parked || locallyChanged;
    final shownCurrent = changed ? current : null;
    final locale = Localizations.localeOf(context).toString();
    // The request carries who asked inside it, so the line is right offline and
    // from the very first review. The profile lookup stays as the fallback for a
    // request written before the column existed, or by a requester whose profile
    // still held no name when it was written.
    final storedRequester = request.requesterName?.trim() ?? '';
    final requester = storedRequester.isNotEmpty
        ? storedRequester
        : ref
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
          // The request's own card is gone (user request): it repeated the
          // record below and the two facts under it, so the screen now opens
          // on the warning that changes what is being asked, or on the record.
          // That warning sits above the details on purpose.
          if (changed) ...[
            AuthErrorBanner(
              text:
                  '${l.deleteRequests_staleTitle}. ${l.deleteRequests_staleBody}',
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          // Two cards when the record moved: what is there now, then the copy
          // the requester saw — so Reconfirm is a decision about the record that
          // exists rather than about an old snapshot. One card otherwise.
          if (shownCurrent != null) ...[
            SettingsSectionLabel(l.deleteRequests_current),
            const SizedBox(height: AppSpacing.sm),
            _SnapshotCard(
              rows: deleteRequestDetailRows(
                request.entityType,
                shownCurrent,
                context,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          SettingsSectionLabel(
            shownCurrent != null
                ? l.deleteRequests_original
                : l.deleteRequests_snapshot,
          ),
          const SizedBox(height: AppSpacing.sm),
          _SnapshotCard(
            rows: deleteRequestDetailRows(
              request.entityType,
              deleteRequestSnapshotMap(request),
              context,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Who asked and when, directly under the record they are asking to
          // delete (user request).
          Text(
            l.deleteRequests_requestedBy(
              requester ?? l.deleteRequests_unknownRequester,
            ),
            key: const ValueKey('delete-review-requester'),
            style: AppTypography.bodySm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          Text(
            l.deleteRequests_requestedOn(
              AppDateUtils.formatDateTimeDDMMYYYY(
                request.createdAt,
                locale: locale,
              ),
            ),
            key: const ValueKey('delete-review-requested-on'),
            style: AppTypography.bodySm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            key: const ValueKey('delete-review-note'),
            controller: _noteController,
            focusNode: _noteFocus,
            enabled: !_busy,
            maxLines: 3,
            minLines: 2,
            style: AppTypography.bodyMd,
            decoration: InputDecoration(
              labelText: l.deleteRequests_noteLabel,
              hintText: l.deleteRequests_noteHint,
              // The cross rides the keyboard: it appears while the box holds the
              // focus, and on tap it empties the box and closes the keyboard
              // (user request — the clearing was added after the closing, so
              // the one tap both wipes the note and puts the keyboard away).
              suffixIcon: _noteFocused
                  ? IconButton(
                      key: const ValueKey('delete-review-note-close'),
                      icon: const Icon(Icons.close),
                      tooltip: l.deleteRequests_noteClearText,
                      onPressed: _clearNote,
                    )
                  : null,
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
            label: l.deleteRequests_approve,
            // Approving deletes data, so it is the error-coloured action; the
            // armed state is what makes the two buttons tell themselves apart.
            destructive: true,
            // One approval is enough (user request, 0.0.727): a locally
            // changed record refreshes the request's snapshot and base version
            // first, so this tap decides against the version that exists now.
            onPressed: _busy
                ? null
                : () => _decide(approve: true, refreshFirst: locallyChanged),
          ),
          const SizedBox(height: AppSpacing.sm),
          // The same button and the same size as Approve, in the app's black
          // rather than Approve's error red, so the two read as one pair of
          // outcomes and still tell themselves apart (user request: the size
          // matched and the label white).
          _PrimaryButton(
            key: const ValueKey('delete-review-reject'),
            icon: Icons.close,
            label: l.deleteRequests_reject,
            onPressed: _busy ? null : () => _decide(approve: false),
          ),
        ],
      ),
    );
  }

  /// Writes one decision after confirming it, then returns to the list.
  ///
  /// [refreshFirst] is the reconfirm of a record this device already knows has
  /// changed: the request's snapshot and target version are re-taken from the
  /// record as it stands, then the approval is written, so the server sees a
  /// matching version instead of parking the request for a second tap.
  Future<void> _decide({
    required bool approve,
    bool refreshFirst = false,
  }) async {
    final l = AppLocalizations.of(context);
    // Captured before the write: the snackbar is shown after this screen pops,
    // and a context that has been popped can no longer find its messenger.
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await _confirm(
      context: context,
      title: approve
          ? l.deleteRequests_approveTitle
          : l.deleteRequests_rejectTitle,
      body: approve
          ? l.deleteRequests_approveBody
          : l.deleteRequests_rejectBody,
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
        // Best effort: when the record is not on this device the refresh does
        // nothing and the server's own park-then-reconfirm still stands.
        if (refreshFirst) {
          await viewModel.refreshSnapshot(widget.requestId);
        }
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

/// A titled confirmation window, with the red destructive action.
Future<bool> _confirm({
  required BuildContext context,
  required String title,
  required String body,
  required String confirmLabel,
}) {
  return showAppConfirmDialog(
    context,
    title: title,
    message: body,
    cancelLabel: AppLocalizations.of(context).sharedActions_cancel,
    confirmLabel: confirmLabel,
    confirmKey: const ValueKey('delete-review-confirm'),
  );
}
