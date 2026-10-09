/// Arms the automatic-backup scheduler for the app's lifetime.
///
/// Mounted once around the app content, mirroring `NotificationTapListener`: on
/// init it (re-)arms the daily backup alarm from the stored schedule. It does
/// not delay the first frame, so the initialisation runs unawaited.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/backup_providers.dart';

/// Arms the backup scheduler once per app process.
class BackupSchedulerScope extends ConsumerStatefulWidget {
  /// The app content below this scope.
  final Widget child;

  /// Creates the scope.
  const BackupSchedulerScope({required this.child, super.key});

  @override
  ConsumerState<BackupSchedulerScope> createState() =>
      _BackupSchedulerScopeState();
}

class _BackupSchedulerScopeState extends ConsumerState<BackupSchedulerScope> {
  @override
  void initState() {
    super.initState();
    // Re-arm on every launch; must not delay the first frame or fail the app
    // if the platform cannot answer.
    unawaited(ref.read(backupSchedulerProvider).initialize());
  }

  @override
  Widget build(BuildContext context) => widget.child;
}