/// Reusable app shell for every Settings sub-page.
///
/// Task 12 supplies each page body; this widget keeps the app header and
/// navigation behavior consistent across the Settings surface.
library;

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';

/// A mobile-first Settings sub-page with a standard app header and back action.
class SettingsSubPageModal extends StatelessWidget {
  /// Header title shown for the current Settings sub-page.
  final String title;

  /// Content supplied by the concrete Settings sub-page.
  final Widget child;

  /// Optional trailing header actions supplied by a concrete sub-page.
  final List<Widget>? actions;

  /// Optional custom back handler; defaults to popping the current route.
  final VoidCallback? onBack;

  /// Creates a reusable Settings sub-page shell.
  const SettingsSubPageModal({
    required this.title,
    required this.child,
    this.actions,
    this.onBack,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: BackButton(onPressed: onBack ?? () => _pop(context)),
        title: Text(
          title,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.titleLg,
        ),
        actions: actions,
        titleSpacing: AppSpacing.sm,
      ),
      body: SafeArea(child: child),
    );
  }

  void _pop(BuildContext context) {
    Navigator.of(context).maybePop();
  }
}
