/// Offers the OEM battery/auto-start guide once, on first launch.
///
/// Plan §10 asks for the guide on first launch as well as from Settings →
/// Notifications. It is offered **only on the phones that actually kill
/// background alarms** (Xiaomi/MIUI, Oppo/ColorOS, Vivo/Funtouch, Huawei,
/// Infinix/XOS and their brands), so a phone that needs nothing is never
/// greeted with a setup screen; everyone else still reaches the guide from the
/// Notifications screen and its reminder banner.
///
/// The offer happens exactly once per user: the "shown" flag is stored in the
/// per-user `user_preferences` row before navigating, so a rebuild or a restart
/// cannot show it twice, and skipping it leaves the reminder banner in place.
library;

import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/settings/presentation/settings_viewmodel.dart';
import '../providers/notification_providers.dart';
import '../providers/repository_providers.dart';
import '../router/app_router.dart';
import 'oem_setup_guide.dart';

/// Mounts [child] and, when warranted, opens the setup guide over it.
class NotificationSetupGate extends ConsumerStatefulWidget {
  /// Router used to open the guide.
  final GoRouter router;

  /// The app content below this gate.
  final Widget child;

  /// Creates the gate.
  const NotificationSetupGate({
    required this.router,
    required this.child,
    super.key,
  });

  @override
  ConsumerState<NotificationSetupGate> createState() =>
      _NotificationSetupGateState();
}

class _NotificationSetupGateState
    extends ConsumerState<NotificationSetupGate> {
  @override
  void initState() {
    super.initState();
    // After the first frame: the router has settled by then, so a launch from a
    // notification can be respected.
    WidgetsBinding.instance.addPostFrameCallback((_) => _offerGuide());
  }

  Future<void> _offerGuide() async {
    try {
      // A hearing tap opened a specific case; never cover it with the guide.
      if (widget.router.routerDelegate.currentConfiguration.uri.path.startsWith(
        '/case-detail',
      )) {
        return;
      }

      final repo = await ref.read(settingsRepositoryProvider.future);
      final settings = await repo.getSettings();
      if (settings.notificationGuideShown || settings.notificationSetupDone) {
        return;
      }

      final device = await ref
          .read(notificationSchedulerProvider)
          .deviceIdentity();
      if (!isAggressiveOem(device)) return;

      // Written before navigating, so a rebuild cannot open a second guide.
      await ref
          .read(settingsViewModelProvider.notifier)
          .updateSettings(
            (current) => current.copyWith(notificationGuideShown: true),
          );

      if (!mounted) return;
      widget.router.push(AppRoutes.settingsBatterySetupGuide);
    } catch (error, stackTrace) {
      // The guide is an enhancement; a failure here must not affect startup.
      dev.log(
        'OEM setup guide offer failed',
        name: 'notifications',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
