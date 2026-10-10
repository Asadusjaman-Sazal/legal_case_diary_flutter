/// Pieces shared by the Admin Panel's two sub-pages.
///
/// Both pages load their whole list from the server and filter it in memory, so
/// neither needs the case screens' `ScopedSearch` runner (which re-runs a
/// database query per keystroke) — what they share is the rule for "does this
/// card match", the search field, the load-failed panel and the date wording.
library;

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/utils/date_utils.dart';

/// Whether [query] appears anywhere in [fields], case-insensitively.
///
/// A blank query matches everything, so the caller can filter unconditionally.
/// [fields] is every string the card shows — the admin searches what they can
/// see, not a hidden column.
bool adminTextMatches(String query, Iterable<String?> fields) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return true;
  for (final field in fields) {
    if ((field ?? '').toLowerCase().contains(needle)) return true;
  }
  return false;
}

/// The search box the two sub-pages show while the header's search button is on.
class AdminSearchField extends StatelessWidget {
  /// The controller the screen owns.
  final TextEditingController controller;

  /// Called with the new text on every keystroke.
  final ValueChanged<String> onChanged;

  /// Placeholder, localized.
  final String hint;

  /// Clears the query and closes the search.
  final VoidCallback onClose;

  const AdminSearchField({
    required this.controller,
    required this.onChanged,
    required this.hint,
    required this.onClose,
    super.key,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.edgeMargin,
      AppSpacing.md,
      AppSpacing.edgeMargin,
      0,
    ),
    child: TextField(
      controller: controller,
      onChanged: onChanged,
      autofocus: true,
      style: AppTypography.bodyMd,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: IconButton(
          icon: const Icon(Icons.close, size: 20),
          onPressed: onClose,
        ),
        isDense: true,
        filled: true,
        fillColor: AppColors.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
          borderSide: const BorderSide(color: AppColors.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
          borderSide: const BorderSide(color: AppColors.outlineVariant),
        ),
      ),
    ),
  );
}

/// The note shown when a query hides everything on the page.
class AdminNoResults extends StatelessWidget {
  /// Localized "no results" message.
  final String message;

  const AdminNoResults({required this.message, super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.edgeMargin),
    child: Text(
      message,
      style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
    ),
  );
}

/// "Could not load · Try Again", shared by both admin sub-pages.
class AdminLoadFailed extends StatelessWidget {
  /// Localized failure message.
  final String message;

  /// Localized retry label.
  final String retryLabel;

  /// Runs the retry.
  final VoidCallback onRetry;

  const AdminLoadFailed({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
    super.key,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.edgeMargin),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMd,
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              textStyle: AppTypography.labelLg,
            ),
            child: Text(retryLabel),
          ),
        ],
      ),
    ),
  );
}

/// `dd/MM/yyyy`, or the dash the panel uses for an absent value.
String adminPanelDate(AppLocalizations l, DateTime? value) => value == null
    ? l.adminPanel_noValue
    : AppDateUtils.formatDateDDMMYYYY(
        value.millisecondsSinceEpoch,
        locale: l.localeName,
      );

/// A card's timestamp as `dd/MM/yyyy, hh:mm AM/PM` — an account shows the time
/// of day too, since that is what tells two sign-ups apart.
String adminPanelDateTime(AppLocalizations l, DateTime? value) => value == null
    ? l.adminPanel_noValue
    : AppDateUtils.formatNoteCardDate(
        value.millisecondsSinceEpoch,
        locale: l.localeName,
      );
