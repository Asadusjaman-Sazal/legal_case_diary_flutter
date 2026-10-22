/// Devices: where the lawyer sees and frees the slots their plan allows.
///
/// The list comes from the server (`device_state`), never from a local cache:
/// the cap is the server's rule, so the screen that explains it must read the
/// same answer. Removing a device revokes its slot immediately; that device
/// hands over its unsent work and erases itself at its next contact, which is
/// the only order that never loses a lawyer's notes.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/providers/device_providers.dart';
import '../../auth/data/device_registration.dart';

/// The account's devices, newest contact first, with one Remove per row.
class DevicesScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const DevicesScreen({super.key});

  @override
  ConsumerState<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends ConsumerState<DevicesScreen> {
  @override
  void initState() {
    super.initState();
    // The gate's registration answer carries the list now, but it may have been
    // built before this screen opened (or before a server change). Read the
    // authoritative `device_state` when the screen appears, without claiming a
    // slot.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(deviceGateProvider.notifier).refresh(claim: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final gate = ref.watch(deviceGateProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.devices_title)),
      body: SafeArea(
        child: gate.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => _Message(
            icon: Icons.cloud_off_outlined,
            text: l.devices_unavailable,
            action: TextButton(
              onPressed: () =>
                  ref.read(deviceGateProvider.notifier).refresh(claim: false),
              child: Text(l.devices_tryAgain),
            ),
          ),
          data: (state) {
            final devices = state.devices;
            if (devices.isEmpty) {
              return _Message(
                icon: Icons.smartphone_outlined,
                text: l.devices_empty,
              );
            }
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.edgeMargin),
              children: [
                Text(
                  l.devices_limitLabel('${devices.length}', '${state.cap}'),
                  style: AppTypography.titleMd,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l.devices_subtitle,
                  style: AppTypography.bodyMd.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                for (final device in devices) ...[
                  _DeviceRow(
                    device: device,
                    onRemove: device.isCurrent
                        ? null
                        : () => _confirmRemove(context, device),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  /// Confirms, then frees the row's slot.
  Future<void> _confirmRemove(
    BuildContext context,
    RegisteredDevice device,
  ) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.devices_removeTitle),
        content: Text(l.devices_removeBody(device.label)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l.devices_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l.devices_remove),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final removed = await ref
        .read(deviceGateProvider.notifier)
        .remove(device.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(removed ? l.devices_removed : l.devices_unavailable),
      ),
    );
  }
}

/// One device: its label, when it was last used, and Remove.
class _DeviceRow extends StatelessWidget {
  const _DeviceRow({required this.device, required this.onRemove});

  final RegisteredDevice device;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final seen = device.lastSeenAt;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(
            device.platform == 'windows'
                ? Icons.desktop_windows_outlined
                : Icons.smartphone_outlined,
            color: AppColors.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.gutter),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.isCurrent
                      ? '${device.label} · ${l.devices_thisDevice}'
                      : device.label,
                  style: AppTypography.labelLg.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (seen != null)
                  Text(
                    l.devices_lastUsed(
                      MaterialLocalizations.of(context).formatShortDate(seen),
                    ),
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          if (onRemove != null)
            TextButton(onPressed: onRemove, child: Text(l.devices_remove)),
        ],
      ),
    );
  }
}

/// A centred icon and sentence, with an optional action.
class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 44, color: AppColors.onSurfaceVariant),
          const SizedBox(height: AppSpacing.sm),
          Text(
            text,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMd.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: AppSpacing.sm),
            action!,
          ],
        ],
      ),
    ),
  );
}
