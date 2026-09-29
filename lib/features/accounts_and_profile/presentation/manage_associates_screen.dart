/// Manage associates screen: add/manage associates & toggle deletion perms.
/// Implemented in Task 20 (Part B).
///
/// Task 17 Phase 5 adds the one rule that belongs to this surface before its UI
/// exists: firm administration is **online-only**, so an offline device is told
/// why nothing here can work instead of being handed controls that must fail.
/// The full associate list, invite display and permission toggles stay in
/// Task 20.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../sync/connectivity_monitor.dart';
import '../../auth/presentation/auth_widgets.dart';

class ManageAssociatesScreen extends ConsumerWidget {
  const ManageAssociatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Unknown connectivity counts as online, the same choice Phase 4 made: a
    // wrong "offline" would hide an operation the server would have accepted.
    final online = ref.watch(isOnlineProvider).value ?? true;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: online
              ? const Text('Manage Associates — Task 20')
              : AuthErrorBanner(
                  text: AppLocalizations.of(context).auth_errorFirmAdminOffline,
                ),
        ),
      ),
    );
  }
}
