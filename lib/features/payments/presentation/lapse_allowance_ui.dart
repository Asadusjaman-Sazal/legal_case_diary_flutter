/// The lapse allowance's two visible pieces: a lock on a read-only row and the
/// banner that explains why some rows are locked.
///
/// Phase 10 keeps everything readable but restricts writing beyond the tier's
/// allowance. A silent refusal would look like a bug, so the app says why once
/// per list (the banner) and marks the affected rows (the lock); tapping a locked
/// row's edit action repeats the reason with a Renew route.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/read_only_lock.dart';
import '../../accounts_and_profile/data/account_mode.dart';

/// Which ledger the banner is speaking about.
enum LapseRowKind {
  /// Cases.
  cases,

  /// Notes.
  notes,

  /// Case references.
  references,
}

/// One-line banner: how many rows stay editable, how many are read-only, and a
/// Renew action.
///
/// Silent while the account is premium, genuinely free, or still inside its
/// allowance — there is nothing to explain then.
class LapseAllowanceBanner extends ConsumerWidget {
  /// Creates the banner for [kind].
  const LapseAllowanceBanner({required this.kind, super.key});

  /// The ledger this banner sits above.
  final LapseRowKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allowance = ref.watch(writeAllowanceProvider).value;
    if (allowance == null || !allowance.isLapsed) {
      return const SizedBox.shrink();
    }
    final (editable, readOnly) = switch (kind) {
      LapseRowKind.cases => (
        allowance.writableCaseIds?.length ?? 0,
        allowance.readOnlyCases,
      ),
      LapseRowKind.notes => (
        allowance.writableNoteIds?.length ?? 0,
        allowance.readOnlyNotes,
      ),
      LapseRowKind.references => (
        allowance.writableReferenceIds?.length ?? 0,
        allowance.readOnlyReferences,
      ),
    };
    if (readOnly <= 0) return const SizedBox.shrink();

    final l = AppLocalizations.of(context);
    final message = switch (kind) {
      LapseRowKind.cases => l.lapse_bannerCases('$editable', '$readOnly'),
      LapseRowKind.notes => l.lapse_bannerNotes('$editable', '$readOnly'),
      LapseRowKind.references => l.lapse_bannerReferences('$editable', '$readOnly'),
    };
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          const ReadOnlyLock(),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(message, style: AppTypography.bodySm),
          ),
          TextButton(
            onPressed: () => context.push(AppRoutes.paywallFromLapse),
            child: Text(l.lapse_renewAction),
          ),
        ],
      ),
    );
  }
}

/// Whether [caseId] is read-only under the current allowance.
///
/// The list screens call this per row; a null allowance (loading, premium or
/// free) reads as writable, the safe direction for a mark that only explains.
bool isCaseReadOnly(WidgetRef ref, String caseId) {
  final allowance = ref.watch(writeAllowanceProvider).value;
  return allowance?.isCaseWritable(caseId) == false;
}

/// Whether [noteId] is read-only under the current allowance.
bool isNoteReadOnly(WidgetRef ref, String noteId) {
  final allowance = ref.watch(writeAllowanceProvider).value;
  return allowance?.isNoteWritable(noteId) == false;
}

/// Whether [referenceId] is read-only under the current allowance.
bool isReferenceReadOnly(WidgetRef ref, String referenceId) {
  final allowance = ref.watch(writeAllowanceProvider).value;
  return allowance?.isReferenceWritable(referenceId) == false;
}

/// Whether [noteId] may be edited now, explaining the refusal when it may not.
bool ensureNoteWritable(BuildContext context, WidgetRef ref, String noteId) {
  final allowance = ref.read(writeAllowanceProvider).value;
  if (allowance == null || allowance.isNoteWritable(noteId)) return true;
  showReadOnlyWriteMessage(
    context,
    AppLocalizations.of(context).lapse_readOnlyNote,
  );
  return false;
}

/// Whether [referenceId] may be edited now, explaining the refusal when it may
/// not.
bool ensureReferenceWritable(
  BuildContext context,
  WidgetRef ref,
  String referenceId,
) {
  final allowance = ref.read(writeAllowanceProvider).value;
  if (allowance == null || allowance.isReferenceWritable(referenceId)) {
    return true;
  }
  showReadOnlyWriteMessage(
    context,
    AppLocalizations.of(context).lapse_readOnlyReference,
  );
  return false;
}

/// Whether [caseId] may be edited now, explaining the refusal when it may not.
///
/// The list screens run this before opening an edit or quick-update form, so a
/// read-only case says why instead of opening a form that would be refused on
/// save. It reads the already-resolved allowance rather than awaiting one, so a
/// tap never waits on a database round-trip; while the answer is still unknown
/// it lets the form open, and the form's own save guard explains instead.
bool ensureCaseWritable(BuildContext context, WidgetRef ref, String caseId) {
  final allowance = ref.read(writeAllowanceProvider).value;
  if (allowance == null || allowance.isCaseWritable(caseId)) return true;
  showReadOnlyWriteMessage(
    context,
    AppLocalizations.of(context).lapse_readOnlyCase,
  );
  return false;
}

/// Explains a refused write on a read-only row, with the Renew route.
void showReadOnlyWriteMessage(BuildContext context, String message) {
  final l = AppLocalizations.of(context);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      action: SnackBarAction(
        label: l.lapse_renewAction,
        onPressed: () => context.push(AppRoutes.paywallFromLapse),
      ),
    ),
  );
}
