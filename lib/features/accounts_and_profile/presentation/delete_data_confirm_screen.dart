/// Delete Data — the typed confirmation a data deletion has to pass through.
///
/// Mirrors [DeleteAccountScreen]: the tick list says *what* goes, this screen
/// is the point of no return — the user must type **delete my data** before
/// anything is destroyed. The phrase stays English in both languages, by the
/// user's instruction, and is read from
/// `settingsManageAccount_deleteDataConfirmPhrase` so the words the user reads
/// and the words the code compares are written once. Compared trimmed and
/// case-insensitively; the button stays disabled until it matches.
///
/// A dumb gate: it pops `true` on confirm and nothing (null) on back, and the
/// caller in `manage_account_screen.dart` does the deleting.
library;

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../settings/presentation/settings_controls.dart';
import '../../settings/presentation/settings_menu_card.dart';
import '../../settings/presentation/settings_sub_page_modal.dart';

/// The typed-confirmation screen between the tick list and the deletion.
class DeleteDataConfirmScreen extends StatefulWidget {
  /// Creates the screen.
  const DeleteDataConfirmScreen({super.key});

  @override
  State<DeleteDataConfirmScreen> createState() =>
      _DeleteDataConfirmScreenState();
}

class _DeleteDataConfirmScreenState extends State<DeleteDataConfirmScreen> {
  /// What the user has typed so far.
  final TextEditingController _typed = TextEditingController();

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  /// Whether [typed] is the confirmation phrase.
  bool _matches(String phrase, String typed) =>
      typed.trim().toLowerCase() == phrase.toLowerCase();

  /// The instruction, with only the phrase in the error ink — red and bold.
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
    final phrase = l.settingsManageAccount_deleteDataConfirmPhrase;

    return SettingsSubPageModal(
      title: l.settingsManageAccount_deleteDataTitle,
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
              _confirmSentence(l, phrase),
              SizedBox(height: AppSpacing.sm),
              TextField(
                key: const ValueKey('delete-data-phrase'),
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
              // Only the button listens to the field, so typing does not
              // rebuild the page.
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _typed,
                builder: (context, value, _) => FilledButton.icon(
                  key: const ValueKey('delete-data-confirm'),
                  onPressed: _matches(phrase, value.text)
                      ? () => Navigator.of(context).pop(true)
                      : null,
                  icon: const Icon(Icons.delete_outline, size: 20),
                  label: Text(l.settingsManageAccount_deleteDataConfirm),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: AppColors.onError,
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
}
