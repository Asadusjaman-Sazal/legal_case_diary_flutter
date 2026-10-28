/// The one place the app decides *how* a deletion happens (Task 20 Phase 3).
///
/// Sync Plan §1's Associate Deletion Policy in one function: a member who may
/// delete does so, exactly as before; a member who may not raises a
/// `delete_requests` row for somebody who can. Every delete in the app therefore
/// goes through here — case, case history, note and reference — so the rule
/// cannot be applied on one screen and forgotten on the next, and so the copy for
/// each outcome is written once.
///
/// Three things this function owns, and nothing else does:
///
/// * the **permission refresh** before the decision (plan §1: the cached flags
///   are advisory, so they are re-read before an action is taken on their word);
/// * the **confirmation**, whose wording differs by branch — "confirm delete" is
///   wrong for an action that only asks someone else;
/// * the **request itself**, queued locally and pushed later, which is what makes
///   the whole workflow offline-capable (the task's item 2). A direct delete is
///   the caller's own call, passed in, so this file never learns how a case or a
///   note is deleted — only whether the caller may.
///
/// A **failure is not caught in the direct branch**: the screens already word
/// their own failures (`caseDetailsScreen_deleteCaseError` and friends) and
/// swallowing the error here would replace a specific message with a generic one.
/// The request branch has no caller-side handling, so it reports its own.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/repositories/base_local_repository.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_dialog_actions.dart';
import '../../../shared/widgets/confirm_dialogs.dart';
import '../../accounts_and_profile/data/account_mode.dart';

/// What the one delete interaction ended as.
enum DeleteOutcome {
  /// The record was deleted locally and queued, as every delete was before.
  deleted,

  /// No permission to delete, so a request was queued instead.
  requested,

  /// The user declined, or nothing could be decided. Nothing changed.
  cancelled,

  /// The request could not be written. Nothing changed.
  failed,
}

/// The snapshot a request carries: the entity's own server-shaped row.
///
/// The reviewer reads this (Phase 4) and the approval compares against
/// `target_base_version`, so it is the whole record rather than a summary — an
/// old snapshot must never be a reason to delete materially changed data.
Map<String, dynamic> deleteRequestSnapshot(Map<String, dynamic> row) =>
    BaseLocalRepository.toSyncPayload(row);

/// The version a request records for a target that reports [version].
///
/// A row created on this device and not yet pushed has no version, and the server
/// inserts one with `version = 1`; recording 1 is therefore the observed value in
/// the only sense that exists, rather than a guess.
int deletionBaseVersion(int? version) => version ?? 1;

/// Deletes [entityId] through the firm's rules, or queues a request to.
///
/// [deleteDirectly] is the caller's own deletion — its repository, its
/// post-delete navigation and its error copy — and runs only when this account
/// may delete. [entitySnapshot] and [targetBaseVersion] are ignored on that path
/// and are what the request carries on the other.
Future<DeleteOutcome> deleteThroughFirmRules(
  BuildContext context,
  WidgetRef ref, {
  required String entityType,
  required String entityId,
  required Map<String, dynamic> entitySnapshot,
  required int targetBaseVersion,
  required Future<void> Function() deleteDirectly,
}) async {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);

  // The one moment the decision depends on a cached fact, so it is refreshed
  // first — a no-op offline, where the provisional path stands and the server
  // stays authoritative.
  await ref.read(permissionFreshnessProvider)();
  if (!context.mounted) return DeleteOutcome.cancelled;

  final direct = ref.read(canDeleteDirectlyProvider);

  final confirmed = direct
      ? await confirmDeleteDialog(context)
      : await _confirmRequest(context, l);
  if (!confirmed || !context.mounted) return DeleteOutcome.cancelled;

  if (direct) {
    await deleteDirectly();
    return DeleteOutcome.deleted;
  }

  // Only a firm member without `can_delete` reaches here, and a firm member
  // always has a firm — but a request with no firm is one the server refuses
  // (both the RLS insert policy and `sync_can_write` compare it against
  // `current_firm_id()`), so it is checked rather than assumed: if it were ever
  // null, nothing happens, which is the safe direction.
  final profile = ref.read(accountProfileProvider).value;
  final firmId = profile?.firmId;
  if (firmId == null) return DeleteOutcome.failed;

  try {
    final repository = await ref.read(deleteRequestsRepositoryProvider.future);
    // One open request per record (the server enforces it with a unique index).
    // Checked here first so the common case is a sentence rather than a refused
    // push, and so two colleagues are never asked about one record.
    final alreadyOpen = (await repository.listAll()).any(
      (request) =>
          request.entityType == entityType &&
          request.entityId == entityId &&
          (request.status == 'pending' ||
              request.status == 'stale_review_required'),
    );
    if (alreadyOpen) {
      messenger.showSnackBar(
        SnackBar(content: Text(l.deleteRequest_alreadyOpen)),
      );
      return DeleteOutcome.cancelled;
    }
    await repository.createRequest(
      entityType: entityType,
      entityId: entityId,
      entitySnapshot: entitySnapshot,
      targetBaseVersion: targetBaseVersion,
      firmId: firmId,
      // The requester's own name is the one profile row every device holds, so
      // the request can say who asked before it has ever reached the server.
      // The server derives the stored value from `profiles` regardless.
      requesterName: profile?.fullName ?? '',
    );
    messenger.showSnackBar(SnackBar(content: Text(l.deleteRequest_sent)));
    return DeleteOutcome.requested;
  } on Object {
    messenger.showSnackBar(SnackBar(content: Text(l.deleteRequest_failed)));
    return DeleteOutcome.failed;
  }
}

/// Warns before an edit, when someone else has asked to delete what is about to
/// be edited.
///
/// Returns true when the editor may open — either nothing is open on this record
/// or the person chose to continue — and false when they backed out, in which
/// case the caller closes the editor it was about to show. It warns and never
/// blocks: an edit is a normal thing to do, and the reviewer's reconfirm is what
/// resolves the consequence.
///
/// [parentCaseId] covers a case step: approving a request on the case removes its
/// steps too, so a step under a case someone asked to delete is worth the same
/// warning. The requester's own request is skipped — they already know.
Future<bool> confirmEditOfRequestedRecord(
  BuildContext context,
  WidgetRef ref, {
  required String entityType,
  required String entityId,
  String? parentCaseId,
}) async {
  final l = AppLocalizations.of(context);
  final userId = ref.read(accountCacheUserIdProvider);
  final repository = await ref.read(deleteRequestsRepositoryProvider.future);
  final requests = await repository.listAll();
  if (!context.mounted) return true;

  final open = requests
      .where(
        (request) =>
            request.status == 'pending' ||
            request.status == 'stale_review_required',
      )
      .where((request) => request.requestedBy != userId)
      .where(
        (request) =>
            (request.entityType == entityType &&
                request.entityId == entityId) ||
            (parentCaseId != null &&
                request.entityType == 'case' &&
                request.entityId == parentCaseId),
      )
      .firstOrNull;
  if (open == null) return true;

  final storedName = open.requesterName?.trim() ?? '';
  final answer = await showAppDialog<bool>(
    context,
    title: Text(l.deleteRequests_editWarnTitle, textAlign: TextAlign.center),
    content: Text(
      l.deleteRequests_editWarnBody(
        storedName.isEmpty ? l.deleteRequests_unknownRequester : storedName,
        AppDateUtils.formatDateTimeDDMMYYYY(
          open.createdAt,
          locale: Localizations.localeOf(context).toString(),
        ),
      ),
      textAlign: TextAlign.justify,
    ),
    actions: (dialogContext) => [
      AppDialogAction(
        label: l.sharedActions_cancel,
        onPressed: () => Navigator.of(dialogContext).pop(false),
      ),
      AppDialogAction(
        label: l.deleteRequests_editWarnContinue,
        kind: AppDialogActionKind.primary,
        onPressed: () => Navigator.of(dialogContext).pop(true),
      ),
    ],
  );
  return answer ?? false;
}

/// The request branch's confirmation.
///
/// Deliberately not the delete window: this action removes nothing yet, it asks
/// somebody with the permission to. Saying "Delete" would be a lie about what the
/// user is about to do. It sits on the shared window frame so the app's
/// confirmations read as one family.
Future<bool> _confirmRequest(BuildContext context, AppLocalizations l) async {
  final answer = await showAppDialog<bool>(
    context,
    // Centred like the Exit App window's title.
    title: Text(l.deleteRequest_confirmTitle, textAlign: TextAlign.center),
    // Justified here only (user request): this window's sentence is the one
    // long paragraph, and its two edges read as a block.
    content: Text(l.deleteRequest_confirmBody, textAlign: TextAlign.justify),
    actions: (dialogContext) => [
      AppDialogAction(
        label: l.sharedActions_cancel,
        onPressed: () => Navigator.of(dialogContext).pop(false),
      ),
      AppDialogAction(
        label: l.deleteRequest_confirmSend,
        // Red with white text (user request): the request hands the record to
        // a reviewer to destroy, so the step wears the destructive colour.
        kind: AppDialogActionKind.destructive,
        onPressed: () => Navigator.of(dialogContext).pop(true),
      ),
    ],
  );
  return answer ?? false;
}
