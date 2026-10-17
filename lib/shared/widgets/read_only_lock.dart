/// A small lock marking a row the lapse allowance keeps read-only.
///
/// Shared by the case cards, the note cards and the reference cards so the mark
/// looks the same wherever the allowance applies. It is a mark, not a control:
/// the action it explains is the row's own edit path.
library;

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/l10n/generated/app_localizations.dart';

/// The badge itself.
class ReadOnlyLock extends StatelessWidget {
  /// Creates the badge.
  const ReadOnlyLock({this.size = 14, super.key});

  /// Icon size; the card heading uses the default, larger rows may grow it.
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: AppLocalizations.of(context).lapse_readOnlyBadge,
      child: Icon(
        Icons.lock_outline,
        size: size,
        color: AppColors.onSurfaceVariant,
      ),
    );
  }
}
