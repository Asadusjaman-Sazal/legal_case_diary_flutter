/// The once-per-launch update check, mounted above the router.
///
/// Renders [child] untouched and, **once per process after the first frame**,
/// runs the automatic update check the User chose in Auto Check For Update.
/// This is the whole battery story: it never runs again this launch, never
/// schedules itself, never loops — the same one-shot discipline the launch
/// refresh scope uses. A
/// check that cannot happen (offline) leaves the diary untouched and counts the
/// day toward the offline streak.
///
/// The check's only user-visible output is the *day-8* toast: after seven
/// consecutive offline days the user is quietly told to connect and check (once
/// per streak). The green "You're On The Latest Version" state is the About
/// screen's business, not here.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/providers/repository_providers.dart';
import '../data/update_check_schedule.dart';
import '../data/update_metadata_store.dart';
import '../data/update_repository.dart';

/// Runs the launch-period auto check on a per-process one-shot basis.
class UpdateCheckScope extends ConsumerStatefulWidget {
  /// Creates the scope around [child].
  const UpdateCheckScope({required this.child, super.key});

  /// The app subtree; returned unchanged.
  final Widget child;

  @override
  ConsumerState<UpdateCheckScope> createState() => _UpdateCheckScopeState();
}

class _UpdateCheckScopeState extends ConsumerState<UpdateCheckScope> {
  /// True once the launch check has been attempted.
  ///
  /// The check runs after the first frame; a rebuild must not re-run it.
  bool _checkedThisLaunch = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_checkOnce()));
  }

  @override
  Widget build(BuildContext context) => widget.child;

  Future<void> _checkOnce() async {
    if (_checkedThisLaunch) return; // One check per launch, never more.
    _checkedThisLaunch = true;

    final metadata = ref.read(updateMetadataProvider);
    final now = DateTime.now().millisecondsSinceEpoch;

    // The frequency decides whether a check is even due. Off means never.
    if (!isUpdateCheckDue(
      frequencyDays: metadata.frequencyDays,
      lastCheckAt: metadata.lastCheckedAt,
      nowEpochMs: now,
    )) {
      return;
    }

    // The network leg itself. Nothing here is gated on connectivity: the call
    // fails fast when offline, and `unavailable` is exactly the "no internet"
    // signal the offline streak counts.
    final outcome = await ref.read(updateRepositoryProvider).checkForLatestRelease();
    final offline = outcome.result == ReleaseCheckResult.unavailable;

    // The check only ever **reports**: it stores what it found so the About and
    // Update rows can show their dot, and never installs anything. Installing
    // is the user's tap on Update Now.
    final notifier = ref.read(updateMetadataProvider.notifier);
    await notifier.recordCheck(
      atEpochMs: now,
      offline: offline,
      release: outcome.release,
    );

    // Day 8 of a streak: one quiet nudge, once per streak, then not again
    // until a successful check resets the count.
    final updated = ref.read(updateMetadataProvider);
    if (shouldShowOfflineToast(
      offlineCheckDays: updated.offlineCheckDays,
      offlineNoticeShown: updated.offlineNoticeShown,
    )) {
      await notifier.markOfflineNoticeShown();
      if (!mounted) return;
      final l = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.settingsUpdate_offlineToast)),
      );
    }
  }
}