/// The Join a Firm flow: who is offered it, the warning a paying individual
/// reads first, the code window, and what is said when it succeeds.
///
/// It lived inside `manage_associates_screen.dart` until 0.0.664, when the user
/// asked for the entry point to move to the **Firm** menu (Settings → Firm).
/// Both pages need exactly this flow and neither should hold a copy of it, so
/// the pieces live here once.
///
/// Two rules travel with it, both user rulings:
///
///  * **Only an empty diary may join.** `join_firm` refuses an account that
///    already holds its own rows, so [ownCaseCountProvider] decides whether the
///    entry is offered at all, and a count that has not arrived offers nothing.
///  * **A paying individual is warned first** that joining neither pauses nor
///    cancels their own plan. That warning's *Continue* wears the primary colour,
///    because it is a step forward rather than a deletion.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/errors/error_log.dart';
import '../../../core/errors/error_log_provider.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../shared/providers/database_provider.dart';
import '../../../sync/sync_service.dart';
import '../../auth/presentation/auth_widgets.dart';
import '../../cases/data/local/cases_dao.dart';
import '../data/account_mode.dart';
import '../data/firm_repository.dart';

/// The account's own live case count — the "empty diary" qualification for
/// joining a firm (0.0.654).
///
/// Scoped exactly as `join_firm` scopes its refusal: the rows an individual
/// holds, with no firm. A count that has not arrived yet is null, and the join
/// entry is not offered on a guess.
final ownCaseCountProvider = StreamProvider<int>((ref) async* {
  final db = await ref.watch(databaseProvider.future);
  yield* CasesDao(db).watchNonDeletedCaseCount();
});

/// Runs the join flow from whichever page offers it.
///
/// A free account goes straight to the code window; a paying one reads the plan
/// warning first, because joining does not pause or cancel what they bought.
Future<void> startJoinFirm(BuildContext context, WidgetRef ref) async {
  final l = AppLocalizations.of(context);

  if (ref.read(premiumAccessProvider).value == true) {
    final proceed = await _confirmPlanWarning(context);
    if (!proceed || !context.mounted) return;
  }

  final redemption = await showDialog<InviteRedemption>(
    context: context,
    builder: (_) => const JoinFirmDialog(),
  );
  if (!context.mounted || redemption == null) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        redemption.status == InviteRedemptionStatus.alreadyMember
            ? l.auth_errorAlreadyMember
            : l.auth_joinedFirm,
      ),
    ),
  );
}

/// The warning a paying individual reads before the code is asked for.
///
/// It is not ceremony: the plan is **ignored** while the account holds a firm —
/// only the firm's expiry counts there — and the paid time stays on the account
/// and applies again if it leaves (plan, *A Member May Not Buy A Personal Plan*).
Future<bool> _confirmPlanWarning(BuildContext context) async {
  final l = AppLocalizations.of(context);
  const actionSize = Size(112, 48);
  const actionText = TextStyle(fontSize: 16);

  final answer = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        l.manageAssociates_joinFirmPlanTitle,
        textAlign: TextAlign.center,
      ),
      // The Invite Code window's own corner, which this screen's windows use.
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius * 2),
      ),
      content: SingleChildScrollView(
        child: Text(l.manageAssociates_joinFirmPlanBody),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          style: TextButton.styleFrom(
            minimumSize: actionSize,
            textStyle: actionText,
          ),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l.sharedActions_cancel),
        ),
        FilledButton(
          // Primary, not red: this continues the join rather than destroying
          // anything.
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            minimumSize: actionSize,
            textStyle: actionText,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l.manageAssociates_joinFirmContinue),
        ),
      ],
    ),
  );
  return answer ?? false;
}

/// The Join a Firm window: the owner's invitation code, and the two actions.
///
/// Built like the Invite Code window — the same panel, corner and action size —
/// so the app's firm windows read as one family. A refusal is shown **in** the
/// window rather than behind it, so a mistyped code can be corrected without
/// reopening anything.
class JoinFirmDialog extends ConsumerStatefulWidget {
  const JoinFirmDialog({super.key});

  @override
  ConsumerState<JoinFirmDialog> createState() => _JoinFirmDialogState();
}

class _JoinFirmDialogState extends ConsumerState<JoinFirmDialog> {
  final TextEditingController _code = TextEditingController();

  bool _busy = false;
  Object? _failure;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final canSend = !_busy && _code.text.trim().isNotEmpty;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.lg,
      ),
      backgroundColor: AppColors.surfaceContainerLowest,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius * 2),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.manageAssociates_joinFirmTitle,
              textAlign: TextAlign.center,
              style: AppTypography.titleLg,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l.manageAssociates_joinFirmIntro,
              textAlign: TextAlign.center,
              style: AppTypography.bodySm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const ValueKey('join-firm-code'),
              controller: _code,
              enabled: !_busy,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              style: AppTypography.bodyLg,
              // The Send button reads the field, so a keystroke must rebuild it.
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: l.manageAssociates_joinFirmCodeLabel,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
              ),
            ),
            if (_failure != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                failureText(l, _failure) ?? l.auth_errorUnknown,
                key: const ValueKey('join-firm-error'),
                textAlign: TextAlign.center,
                style: AppTypography.bodySm.copyWith(color: AppColors.error),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: AppSpacing.lg,
              children: [
                TextButton(
                  key: const ValueKey('join-firm-cancel'),
                  onPressed: _busy
                      ? null
                      : () => Navigator.of(context).maybePop(),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(112, 48),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                  child: Text(l.sharedActions_cancel),
                ),
                FilledButton(
                  key: const ValueKey('join-firm-send'),
                  onPressed: canSend ? _send : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    minimumSize: const Size(112, 48),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                  child: Text(l.manageAssociates_joinFirmSend),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Redeems the code and closes with the server's answer.
  ///
  /// The membership is the server's to grant, so nothing local is written here:
  /// the profile refresh caches the new firm and role, and the delta pull that
  /// follows (detached, because the join has already succeeded) brings the
  /// chamber's rows. A joining account has no rows of its own, which is why the
  /// pull cannot overwrite anything.
  Future<void> _send() async {
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      final redemption = await ref
          .read(firmRepositoryProvider)
          .redeemInvite(_code.text.trim());
      await ref.read(accountRefreshProvider)();
      unawaited(ref.read(syncServiceProvider).syncNow(force: true, pull: true));
      if (!mounted) return;
      Navigator.of(context).maybePop(redemption);
    } on Object catch (error) {
      if (!mounted) return;
      // Recorded here for the same reason the screen records its own: a refused
      // code is exactly what the diagnostics log has to be able to answer.
      recordFailure(ref.read(errorLogProvider), 'firm.join', error);
      setState(() {
        _busy = false;
        _failure = error;
      });
    }
  }
}
