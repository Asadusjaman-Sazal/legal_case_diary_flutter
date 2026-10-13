/// The once-per-launch update check, mounted above the router.
///
/// Renders [child] untouched and, **once per process after the first frame**,
/// runs the automatic update check the User chose in Auto Check for Update.
/// This is the whole battery story: it never runs again this launch, never
/// schedules itself, never loops — the same one-shot discipline the launch
/// refresh scope uses. A
/// check that cannot happen (offline) leaves the diary untouched and counts the
/// day toward the offline streak.
///
/// The check's only user-visible output is the *day-8* toast: after seven
/// consecutive offline days the user is quietly told to connect and check (once
/// per streak). The green "You're on the latest version" state is the About
/// screen's business, not here.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/errors/error_log.dart';
import '../../../core/errors/error_log_provider.dart';
import '../data/update_check_schedule.dart';
import '../data/update_metadata_store.dart';
import '../data/update_repository.dart';
import 'update_flow.dart';

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

  /// Removes a leftover downloaded APK once nothing is waiting on it.
  ///
  /// Best-effort and silent: nothing a user can see depends on it, and a file
  /// the OS will not release is left for the next launch.
  Future<void> _deleteStaleDownload() async {
    try {
      final apk = await updateApkFile();
      await deleteUpdateApkIfStale(
        apk,
        // True while the app is still being told about a release: either the
        // install has not happened, or it happened and the stored offer has not
        // been re-checked yet. False once the app *is* that version, or once
        // the offer has gone.
        stillOffered: ref.read(updateAvailableProvider) != null,
      );
    } on Object catch (error) {
      recordFailure(ref.read(errorLogProvider), 'update.cleanup', error);
    }
  }

  Future<void> _checkOnce() async {
    if (_checkedThisLaunch) return; // One check per launch, never more.
    _checkedThisLaunch = true;

    final metadata = ref.read(updateMetadataProvider);
    final now = DateTime.now().millisecondsSinceEpoch;

    // Clear a downloaded update left over from an earlier run, **before** the
    // frequency check: a user who turns Auto Check off should still have their
    // leftover APK tidied away, and the question ("is an update still being
    // offered?") does not depend on whether a check is due.
    //
    // This is where the install is *confirmed*: the APK has to survive its own
    // handoff to Android's installer, so the app only knows it worked once the
    // build it is running is the version that was offered.
    await _deleteStaleDownload();

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