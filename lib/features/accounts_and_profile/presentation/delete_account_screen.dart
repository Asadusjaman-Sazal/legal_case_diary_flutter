/// Delete Account — the typed confirmation a deletion has to pass through.
///
/// **0.0.412 (user request).** Manage Account's warning says what the action
/// takes with it; this screen is the second gate, and the one that makes an
/// accidental deletion impossible: the user must type the phrase
/// **delete my account** before the destructive button will do anything.
///
/// **The phrase stays English in both languages**, by the user's instruction,
/// and it is stored exactly once (`settingsManageAccount_deleteConfirmPhrase`,
/// identical in `app_en.arb` and `app_bn.arb` — the same choice `drawer_version`
/// makes for a version string). The sentence above the field carries it as a
/// `{phrase}` placeholder rather than repeating the words, so the instruction the
/// user reads and the string the code compares can never disagree.
///
/// The phrase is also the only part of the sentence drawn in the app's error
/// ink, red and bold, so the words to type stand out from the instruction around
/// them without the sentence shouting as a whole.
///
/// Nothing is destroyed before the phrase matches: the field is compared
/// **trimmed and case-insensitively**, because typing `Delete My Account` is the
/// same intent and rejecting it would only teach the user to fight the keyboard.
/// The button is disabled until it does, and the rest of the flow is the one
/// Manage Account used to run itself — offline it refuses rather than
/// half-deleting, a refusal or failure is reported and changes nothing, and a
/// success ends with the device back at what an install starts from and the user
/// on Login.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../sync/connectivity_monitor.dart';
import '../../auth/data/logout_flow.dart';
import '../../settings/presentation/settings_controls.dart';
import '../../settings/presentation/settings_menu_card.dart';
import '../../settings/presentation/settings_sub_page_modal.dart';
import '../data/account_deletion_repository.dart';
import '../data/account_mode.dart';

/// The typed-confirmation screen between the warning and the deletion.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  /// What the user has typed so far.
  final TextEditingController _typed = TextEditingController();

  /// True while the server call and the wipe are running, so a second tap
  /// cannot start a second deletion.
  bool _deleting = false;

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  /// Whether [typed] is the confirmation phrase.
  ///
  /// Trimmed and case-insensitive on purpose — see the library comment.
  bool _matches(String phrase, String typed) =>
      typed.trim().toLowerCase() == phrase.toLowerCase();

  /// The instruction, with only the phrase the user must type in the app's
  /// error ink — red and bold — so the words to copy stand out from the sentence
  /// around them.
  ///
  /// The sentence stays one ARB string (`… {phrase} …`), so the words the user
  /// reads and the words the code compares are written once and cannot drift;
  /// the styled run is simply the phrase's own place in the rendered sentence.
  /// ponytail: split on the placeholder rather than growing before/after ARB
  /// pieces. If a translation ever moved or repeated the phrase the sentence
  /// still renders (plain, with no styled run); splitting the key is the upgrade.
  Widget _confirmSentence(AppLocalizations l, String phrase) {
    final sentence = l.settingsManageAccount_deleteConfirmBody(phrase);
    final start = sentence.indexOf(phrase);
    if (start < 0) {
      return Text(sentence, style: AppTypography.bodyMd);
    }
    return Text.rich(
      TextSpan(
        style: AppTypography.bodyMd,
        children: [
          TextSpan(text: sentence.substring(0, start)),
          TextSpan(
            text: phrase,
            style: AppTypography.bodyMd.copyWith(
              color: AppColors.error,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(text: sentence.substring(start + phrase.length)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final phrase = l.settingsManageAccount_deleteConfirmPhrase;
    // Watched, so the check below is never the "unknown" a lazy first read
    // answers with. Unknown counts as online: the call then reports its own
    // failure, which is the honest direction.
    final online = ref.watch(isOnlineProvider).value != false;
    // A free account's diary has never left the device; a premium account's is in
    // the cloud as well, and this is the screen the deletion is confirmed on, so
    // the same sentence the warning used is repeated here.
    final premium = ref.watch(premiumAccessProvider).value != false;

    return SettingsSubPageModal(
      title: l.settingsManageAccount_deleteAccount,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.edgeMargin,
          AppSpacing.md,
          AppSpacing.edgeMargin,
          AppSpacing.xl,
        ),
        child: Container(
          width: double.infinity,
          decoration: settingsCardDecoration(),
          padding: EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                premium
                    ? l.settingsManageAccount_deleteWarningPremium
                    : l.settingsManageAccount_deleteWarningFree,
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              SizedBox(height: AppSpacing.md),
              _confirmSentence(l, phrase),
              SizedBox(height: AppSpacing.sm),
              TextField(
                key: const ValueKey('delete-account-phrase'),
                controller: _typed,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  hintText: phrase,
                  hintStyle: AppTypography.bodyMd.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceVariant,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 14,
                  ),
                  border: const UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: AppColors.cardBorder,
                      width: 2,
                    ),
                  ),
                ),
              ),
              SizedBox(height: AppSpacing.lg),
              // Only the button listens to the field, so typing does not rebuild
              // the page.
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _typed,
                builder: (context, value, _) => FilledButton.icon(
                  key: const ValueKey('delete-account-confirm'),
                  onPressed: _matches(phrase, value.text) && !_deleting
                      ? () => _delete(online: online)
                      : null,
                  icon: const Icon(Icons.delete_outline, size: 20),
                  label: Text(l.settingsManageAccount_deleteAccount),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: AppColors.onError,
                    // The app's theme paints FilledButton black, so the disabled
                    // pair is spelled out too: a red button that goes grey on
                    // disable would read as "not the destructive one".
                    disabledBackgroundColor: AppColors.error.withValues(
                      alpha: 0.35,
                    ),
                    disabledForegroundColor: AppColors.onError,
                    textStyle: AppTypography.titleMd,
                    minimumSize: const Size.fromHeight(
                      settingsPrimaryButtonHeight,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Deletes the account, having passed the typed gate.
  ///
  /// The same four steps the warning screen used to run, and in the same order:
  /// refuse without a link (nothing local is touched either — the account row
  /// lives on the server, so there is no local-only deletion to fall back on);
  /// ask the server, which answers for itself whether this account may go; then
  /// the logout flow's own complete wipe **with the baseline reference data**, so
  /// the device ends where an install starts; then the sign-out and Login.
  ///
  /// [online] is the live answer watched in `build`, handed in rather than
  /// re-read here, because a lazily-taken first snapshot would answer "unknown".
  Future<void> _delete({required bool online}) async {
    if (_deleting) return;
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    if (!online) {
      messenger.showSnackBar(
        SnackBar(content: Text(l.settingsManageAccount_deleteNeedsConnection)),
      );
      return;
    }

    setState(() => _deleting = true);
    final outcome = await ref
        .read(accountDeletionRepositoryProvider)
        .deleteAccount();
    if (!mounted) return;
    if (outcome != AccountDeletionOutcome.deleted) {
      setState(() => _deleting = false);
      messenger.showSnackBar(
        SnackBar(content: Text(_failureText(l, outcome))),
      );
      return;
    }

    final flow = await ref.read(logoutFlowProvider.future);
    if (!mounted) return;
    await flow.wipeAndComplete();
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text(l.settingsManageAccount_deleted)),
    );
    context.go(AppRoutes.login);
  }

  /// One sentence for anything that did not delete the account.
  String _failureText(AppLocalizations l, AccountDeletionOutcome outcome) =>
      switch (outcome) {
        AccountDeletionOutcome.refusedFirm =>
          l.settingsManageAccount_deleteFirmRefused,
        AccountDeletionOutcome.refusedAdministrator =>
          l.settingsManageAccount_deleteAdminRefused,
        // Deleted never reaches here; the rest are the same retryable sentence.
        AccountDeletionOutcome.deleted ||
        AccountDeletionOutcome.unavailable ||
        AccountDeletionOutcome.failed => l.settingsManageAccount_deleteFailed,
      };
}
