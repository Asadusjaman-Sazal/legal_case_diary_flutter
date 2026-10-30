/// Devices: where the lawyer sees and frees the slots their plan allows.
///
/// The list comes from the server (`device_state`), never from a local cache:
/// the cap is the server's rule, so the screen that explains it must read the
/// same answer. Removing a device revokes its slot immediately; that device
/// hands over its unsent work and erases itself at its next contact, which is
/// the only order that never loses a lawyer's notes.
///
/// A chamber's owner reads one more server answer (`firm_device_list`, 0.0.713):
/// the chamber's slots are shared between the associates and the owner's own
/// devices, so the owner's screen lists both halves — the owner's devices, then
/// the associates' — and states the whole chamber's use. Only the owner sees
/// those sections; an associate and an individual keep the per-account list.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/providers/device_providers.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_dialog_actions.dart';
import '../../../shared/widgets/pull_to_sync.dart';
import '../../auth/data/device_registration.dart';
import '../data/account_mode.dart';
import '../data/firm_devices.dart';

/// The account's devices, newest contact first, with one Remove per row; for a
/// chamber's owner, the chamber's devices in two sections.
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
    // authoritative answers when the screen appears, without claiming a slot.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_reload());
    });
  }

  /// Whether this account owns a chamber, read from the cached rows.
  bool get _isFirmOwner =>
      ref.read(firmModeProvider) && !ref.read(firmMemberProvider);

  /// Re-reads this device's registry and, for an owner, the chamber's devices.
  ///
  /// Both reads are the server's; a failed chamber read is drawn as its own
  /// section's message, so it is not rethrown here.
  Future<void> _reload() async {
    await ref.read(deviceGateProvider.notifier).refresh(claim: false);
    if (!mounted || !_isFirmOwner) return;
    ref.invalidate(firmDeviceListProvider);
    try {
      await ref.read(firmDeviceListProvider.future);
    } on Object {
      // The associates' section states the failure and offers Try Again.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final gate = ref.watch(deviceGateProvider);
    final isFirmOwner =
        ref.watch(firmModeProvider) && !ref.watch(firmMemberProvider);
    // Only an owner asks for the chamber's list; an associate's own answer is
    // `device_state`, and reading this for them would be a wasted RPC.
    final firm = isFirmOwner ? ref.watch(firmDeviceListProvider) : null;
    return Scaffold(
      appBar: AppBar(title: Text(l.devices_title)),
      body: SafeArea(
        child: gate.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => _Message(
            icon: Icons.cloud_off_outlined,
            text: l.devices_unavailable,
            action: TextButton(
              onPressed: _reload,
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
            return PullToSync(
              // The registry lives on the server, so the pull re-reads it — and
              // the chamber's list when this is the owner — as well as running
              // the sync.
              onReload: _reload,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.edgeMargin),
                children: [
                  ..._summary(l, state, firm),
                  const SizedBox(height: AppSpacing.md),
                  if (firm != null)
                    ..._firmSections(l, devices, firm)
                  else
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
              ),
            );
          },
        ),
      ),
    );
  }

  /// The limit line, its sentence and the shared-slots note.
  ///
  /// An owner's line counts the whole chamber against its slots; while the
  /// chamber's answer has not arrived, the owner's own allowance is stated
  /// instead of a total that would leave the associates out.
  List<Widget> _summary(
    AppLocalizations l,
    DeviceGateState state,
    AsyncValue<FirmDeviceList?>? firm,
  ) {
    final slots = firm?.value?.slots;
    final associates = firm?.value?.associateDevices ?? const <FirmDevice>[];
    return <Widget>[
      Text(
        slots == null
            ? l.devices_limitLabel('${state.devices.length}', '${state.cap}')
            : l.devices_firmLimitLabel(
                '${state.devices.length + associates.length}',
                '$slots',
              ),
        style: AppTypography.titleMd,
      ),
      // The owner reads the chamber's sharing note in place of the per-account
      // sentence, at that sentence's size (user request, 0.0.716).
      if (firm == null) ...[
        const SizedBox(height: AppSpacing.xs),
        Text(
          l.devices_subtitle,
          style: AppTypography.bodyMd.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
      if ((firm?.value?.associates ?? 0) > 0) ...[
        const SizedBox(height: AppSpacing.xs),
        Text(
          l.settingsSubscription_usageSeatsNote,
          style: AppTypography.bodyMd.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    ];
  }

  /// The owner's two lists: the owner's devices, then the associates'.
  List<Widget> _firmSections(
    AppLocalizations l,
    List<RegisteredDevice> devices,
    AsyncValue<FirmDeviceList?> firm,
  ) {
    final associateDevices = firm.value?.associateDevices;
    return <Widget>[
      _SectionHeading(l.devices_ownerSectionCount('${devices.length}')),
      for (final device in devices) ...[
        _DeviceRow(
          device: device,
          onRemove: device.isCurrent
              ? null
              : () => _confirmRemove(context, device),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
      const SizedBox(height: AppSpacing.xs),
      _SectionHeading(
        associateDevices == null
            ? l.devices_associateSection
            : l.devices_associateSectionCount('${associateDevices.length}'),
      ),
      if (firm.isLoading && associateDevices == null)
        const Padding(
          padding: EdgeInsets.all(AppSpacing.sm),
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        )
      else if (firm.hasError && associateDevices == null) ...[
        Text(
          l.devices_firmUnavailable,
          style: AppTypography.bodyMd.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: _reload,
            child: Text(l.devices_tryAgain),
          ),
        ),
      ] else if (associateDevices == null || associateDevices.isEmpty)
        Text(
          l.devices_noAssociateDevices,
          style: AppTypography.bodyMd.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        )
      else
        for (final device in associateDevices) ...[
          _AssociateDeviceRow(device: device),
          const SizedBox(height: AppSpacing.sm),
        ],
    ];
  }

  /// Confirms, then frees the row's slot.
  Future<void> _confirmRemove(
    BuildContext context,
    RegisteredDevice device,
  ) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showAppConfirmDialog(
      context,
      title: l.devices_removeTitle,
      message: l.devices_removeBody(device.label),
      cancelLabel: l.devices_cancel,
      confirmLabel: l.devices_remove,
      confirmKind: AppDialogActionKind.text,
    );
    if (!confirmed) return;
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

/// A section's label, e.g. **Associates' Devices (2)**.
class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.title);

  /// The heading text, already carrying its count where one is known.
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.xs,
      vertical: AppSpacing.sm,
    ),
    child: Text(
      title,
      style: AppTypography.labelLg.copyWith(
        color: AppColors.onSurfaceVariant,
        letterSpacing: 0.7,
      ),
    ),
  );
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
                      AppDateUtils.formatDateTimeDDMMYYYY(
                        seen.millisecondsSinceEpoch,
                        locale: Localizations.localeOf(context).toString(),
                      ),
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

/// One associate's device: whose it is, which phone, and when it was used.
class _AssociateDeviceRow extends StatelessWidget {
  const _AssociateDeviceRow({required this.device});

  final FirmDevice device;

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
                  device.memberName.isEmpty ? '—' : device.memberName,
                  style: AppTypography.labelLg.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  device.label,
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                if (seen != null)
                  Text(
                    l.devices_lastUsed(
                      AppDateUtils.formatDateTimeDDMMYYYY(
                        seen.millisecondsSinceEpoch,
                        locale: Localizations.localeOf(context).toString(),
                      ),
                    ),
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
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
