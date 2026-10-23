/// Reusable app shell for every Settings sub-page.
///
/// Task 12 supplies each page body; this widget keeps the app header and
/// navigation behavior consistent across the Settings surface.
library;

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../shared/widgets/pull_to_sync.dart';

/// A mobile-first Settings sub-page with a standard app header and back action.
class SettingsSubPageModal extends StatelessWidget {
  /// Header title shown for the current Settings sub-page.
  final String title;

  /// Optional subtitle shown beneath the title in the app bar.
  final String? subtitle;

  /// Content supplied by the concrete Settings sub-page.
  final Widget child;

  /// Optional trailing header actions supplied by a concrete sub-page.
  final List<Widget>? actions;

  /// Optional floating action button (e.g. add item).
  final Widget? floatingActionButton;

  /// Optional custom back handler; defaults to popping the current route.
  final VoidCallback? onBack;

  /// Whether this page gets the premium pull-to-sync gesture.
  ///
  /// The two admin sub-pages and Backup & Restore opt out: the former already
  /// own a pull that syncs and reloads their server lists, and a sync during a
  /// running backup or restore must not be possible by accident.
  final bool pullToSync;

  /// Creates a reusable Settings sub-page shell.
  const SettingsSubPageModal({
    required this.title,
    this.subtitle,
    required this.child,
    this.actions,
    this.floatingActionButton,
    this.onBack,
    this.pullToSync = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: BackButton(onPressed: onBack ?? () => _pop(context)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.titleLg,
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: AppTypography.bodySm.copyWith(color: AppColors.tertiary),
              ),
          ],
        ),
        actions: actions,
        titleSpacing: AppSpacing.sm,
      ),
      body: SafeArea(child: pullToSync ? PullToSync(child: child) : child),
      floatingActionButton: floatingActionButton,
    );
  }

  void _pop(BuildContext context) {
    Navigator.of(context).maybePop();
  }
}
