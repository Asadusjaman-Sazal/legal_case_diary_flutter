/// The monthly "back up your data" nudge (Task 15 Phase 6).
///
/// A free user's local export is the only safety net they have, so once a
/// calendar month the app asks them to use it. The nudge is deliberately
/// **dismissible and non-modal, never a blocking dialog**: it does not
/// interrupt whatever the user opened the app to do, it can be ignored with one
/// tap, and it goes away on its own for the rest of the month either way. It is
/// drawn as a small centred window, about the footprint of the Exit App
/// confirmation, so it never covers the screen it sits on.
///
/// It is mounted above the app's navigator (see `app.dart`), the same place the
/// OEM setup guide is offered from, so it appears on whatever screen the app
/// opens on — including a launch straight into a case. The route is pushed
/// through the router we are given, because a widget above the navigator has no
/// `context.push` of its own. It floats mid-screen over the app as a small
/// window rather than taking a strip at the top, so the screen behind it never
/// shrinks and stays tappable.
///
/// Four conditions must all hold, and every one of them is a reason *not* to
/// nag: the user is free (premium users are not at risk), the diary actually
/// holds a live case (a fresh install has nothing to lose), no backup has been
/// made this Bangladesh month, and no nudge has been shown in it either. The
/// nudge is then **recorded as shown** — not as dismissed — so an abandoned
/// launch still counts as the month's one ask, exactly like the setup guide.
library;

import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/backup/backup_nudge.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/local_identity_service.dart';
import '../../../shared/providers/database_provider.dart';
import '../data/backup_metadata_store.dart';
import '../data/premium_access.dart';
import '../../cases/data/local/cases_dao.dart';

/// Mounts [child] and, when the month's nudge is due, a small window over it.
class BackupNudgeBanner extends ConsumerStatefulWidget {
  /// Router used to open Backup & Restore from the banner.
  final GoRouter router;

  /// The app content below the banner.
  final Widget child;

  /// Creates the banner gate.
  const BackupNudgeBanner({
    required this.router,
    required this.child,
    super.key,
  });

  @override
  ConsumerState<BackupNudgeBanner> createState() => _BackupNudgeBannerState();
}

/// The window's maximum width: a little wider than Flutter's default
/// [AlertDialog] `minWidth` (280), which the Exit App confirmation settles on,
/// so the underlined action label fits on a single line instead of wrapping by
/// a hair. Still far narrower than the screen — a window, not a dialog.
const double _nudgeWindowWidth = 320.0;

class _BackupNudgeBannerState extends ConsumerState<BackupNudgeBanner> {
  /// Whether this session is showing the nudge.
  ///
  /// Local on purpose: the decision is recorded in the store as soon as the
  /// banner appears, so the store cannot be what keeps it on screen — otherwise
  /// recording it would hide it in the same frame.
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    // After the first frame, so a launch from a notification has already routed
    // and nothing is being built while we decide.
    WidgetsBinding.instance.addPostFrameCallback((_) => _decide());
  }

  Future<void> _decide() async {
    try {
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      final db = await ref.read(databaseProvider.future);
      if (!mounted) return;

      // Premium users sync to the cloud; the nudge is for free users only.
      final hasPremiumAccess = await resolvePremiumAccess(
        db,
        ref.read(localIdentityServiceProvider).getId(),
      );

      // Nothing to lose, nothing to nag about: a fresh install has no cases yet.
      final hasCases = await CasesDao(db).getNonDeletedCaseCount() > 0;

      final metadata = ref.read(backupMetadataProvider);
      final due = isBackupNudgeDue(
        now: now,
        lastBackupAt: metadata.lastSuccessfulAt,
        lastNudgedAt: metadata.lastNudgedAt,
      );
      if (hasPremiumAccess || !hasCases || !due) return;

      // Recorded before showing: one ask per calendar month, whatever the user
      // does with it next.
      await ref.read(backupMetadataProvider.notifier).recordNudge(at: now);
      if (!mounted) return;
      setState(() => _visible = true);
    } catch (error, stackTrace) {
      // A reminder is an enhancement; a failure here must never affect startup.
      dev.log(
        'Monthly backup nudge failed',
        name: 'backup',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Opens Backup & Restore, where the actual backup is one tap away.
  void _openBackupRestore() {
    setState(() => _visible = false);
    widget.router.push(AppRoutes.settingsBackupRestore);
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return widget.child;
    final l = AppLocalizations.of(context);
    // A Stack rather than a Column: the nudge floats in the middle of the
    // screen, so the app below keeps its full height instead of shrinking to
    // make room for a strip. The same `EdgeInsets` side margin keeps the window
    // off the edges on a narrow phone. The centered child is the only hit
    // target, so taps on the app around the window still work — there is no
    // scrim, which is what keeps it a window rather than a full-screen dialog.
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.edgeMargin,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: _nudgeWindowWidth,
                  ),
                  child: _NudgeCard(
                    message: l.backupNudge_message,
                    actionLabel: l.backupNudge_action,
                    dismissTooltip: l.backupNudge_dismiss,
                    onTap: _openBackupRestore,
                    onDismiss: () => setState(() => _visible = false),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The window itself: a tappable card mid-screen, sized to its own content,
/// with a dismiss control.
class _NudgeCard extends StatelessWidget {
  final String message;
  final String actionLabel;
  final String dismissTooltip;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _NudgeCard({
    required this.message,
    required this.actionLabel,
    required this.dismissTooltip,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.error,
    borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
    clipBehavior: Clip.antiAlias,
    elevation: 6,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.backup_outlined,
              size: 20,
              color: AppColors.onError,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                // `min` so the window wraps its two lines of text: the default
                // `max` would stretch it to the screen height and make the
                // "small window" cover everything vertically.
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: AppTypography.bodyMd.copyWith(
                      color: AppColors.onError,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    actionLabel,
                    style: AppTypography.titleMd.copyWith(
                      color: AppColors.onError,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.onError,
                    ),
                  ),
                ],
              ),
            ),
            // No `tooltip` here, and that is not an oversight: this banner is
            // mounted above the app's navigator, so there is no Overlay
            // ancestor for a Tooltip to float in. The label still reaches
            // screen readers through the icon's semantics.
            IconButton(
              key: const ValueKey('backup-nudge-dismiss'),
              icon: Icon(
                Icons.close,
                size: 18,
                semanticLabel: dismissTooltip,
              ),
              color: AppColors.onError,
              onPressed: onDismiss,
            ),
          ],
        ),
      ),
    ),
  );
}
