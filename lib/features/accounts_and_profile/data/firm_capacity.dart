/// The chamber's shared-capacity picture, for the owner's screens.
///
/// One pure resolver and one provider. The server is the boundary; this is the
/// number the owner is shown and the warning they see before a shrink. The
/// formula is the server's: `associates + owner devices <= slots`, the owner's
/// first device always reserved, and a lower tier's slots only after its
/// 48-hour grace.
library;

import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/device_providers.dart';
import '../../auth/data/device_registration.dart';
import '../../payments/data/payment_plans.dart';
import '../../payments/presentation/subscription_banner.dart';
import 'account_mode.dart';
import 'firm_repository.dart';

/// What the owner's capacity card and the Plan Usage meter read.
class FirmCapacityView {
  /// Creates one capacity picture.
  const FirmCapacityView({
    required this.slots,
    required this.associates,
    required this.seated,
    required this.ownerDevices,
    required this.ownerDeviceCap,
    required this.used,
    required this.active,
    required this.overRoster,
    required this.overDevices,
    required this.frozen,
    required this.pendingSlots,
    required this.shrinkAt,
    required this.pendingAssociatesExcess,
    required this.pendingDevicesExcess,
    required this.shrinkPending,
  });

  /// Slots the current effective tier sells.
  final int slots;

  /// Non-owner members, seated and signed out. They all hold a seat.
  final int associates;

  /// Associates currently allowed a device.
  final int seated;

  /// Associates signed out for capacity; they still hold a seat.
  int get signedOut => associates - seated;

  /// The owner's active devices.
  final int ownerDevices;

  /// The owner's allowed devices: the slots left after associates, at least 1.
  final int ownerDeviceCap;

  /// Committed usage: associates plus the owner's devices.
  final int used;

  /// Devices actually active: seated associates plus the owner's devices.
  final int active;

  /// More associates than `slots - 1` (the owner's first device is reserved).
  final bool overRoster;

  /// More owner devices than the remaining slots allow.
  final bool overDevices;

  /// Whether any part of the chamber is over its plan.
  bool get over => overRoster || overDevices;

  /// True once the chamber's 48-hour grace has ended.
  final bool frozen;

  /// The pending tier's slots, when a queued change exists.
  final int? pendingSlots;

  /// The instant a lower pending tier starts; null when it is not a shrink.
  final DateTime? shrinkAt;

  /// Associates the pending shrink would sign out.
  final int pendingAssociatesExcess;

  /// The owner's devices the pending shrink would sign out.
  final int pendingDevicesExcess;

  /// A lower pending tier would leave the chamber over capacity.
  final bool shrinkPending;

  /// Whether another associate can join now. The owner's first device is always
  /// reserved, so this is not `used < slots`.
  bool get canAddAssociate =>
      associates + math.max(ownerDevices, 1) + 1 <= slots;
}

/// Resolves the capacity picture. Pure, so the boundary cases are testable.
FirmCapacityView resolveFirmCapacity({
  required int slots,
  required int? pendingSlots,
  required DateTime? pendingFrom,
  required int associates,
  required int seated,
  required int ownerDevices,
  required DateTime? expiry,
  required DateTime now,
}) {
  final ownerDeviceCap = math.max(1, slots - associates);
  final used = associates + ownerDevices;
  final active = seated + ownerDevices;
  final seatLimit = math.max(slots - 1, 0);
  final overRoster = associates > seatLimit;
  final overDevices = ownerDevices > ownerDeviceCap;
  final frozen =
      expiry == null || !expiry.add(const Duration(hours: 48)).isAfter(now);

  final isLowerPending = pendingSlots != null && pendingSlots < slots;
  final shrinkAt = isLowerPending && pendingFrom != null &&
          pendingFrom.isAfter(now)
      ? pendingFrom
      : null;
  final pendingSeatLimit =
      pendingSlots == null ? null : math.max(pendingSlots - 1, 0);
  final pendingOwnerCap =
      pendingSlots == null ? null : math.max(1, pendingSlots - associates);
  final pendingAssociatesExcess = pendingSeatLimit == null
      ? 0
      : math.max(0, associates - pendingSeatLimit);
  final pendingDevicesExcess =
      pendingOwnerCap == null ? 0 : math.max(0, ownerDevices - pendingOwnerCap);
  final shrinkPending = shrinkAt != null &&
      (pendingAssociatesExcess > 0 || pendingDevicesExcess > 0);

  return FirmCapacityView(
    slots: slots,
    associates: associates,
    seated: seated,
    ownerDevices: ownerDevices,
    ownerDeviceCap: ownerDeviceCap,
    used: used,
    active: active,
    overRoster: overRoster,
    overDevices: overDevices,
    frozen: frozen,
    pendingSlots: pendingSlots,
    shrinkAt: shrinkAt,
    pendingAssociatesExcess: pendingAssociatesExcess,
    pendingDevicesExcess: pendingDevicesExcess,
    shrinkPending: shrinkPending,
  );
}

/// The owner's capacity view, or null while a piece is unknown.
///
/// Owner-only: an associate has no roster-wide device count and no action to
/// take. Null also covers a loading roster, an offline read, or an unregistered
/// device — the card then shows a dash instead of inventing zero.
final firmCapacityViewProvider = Provider<FirmCapacityView?>((ref) {
  if (!ref.watch(firmModeProvider) || ref.watch(firmMemberProvider)) return null;

  final firm = ref.watch(accountFirmProvider).value;
  final profile = ref.watch(accountProfileProvider).value;
  final members = ref.watch(firmMembersListProvider).value;
  final gate = ref.watch(deviceGateProvider).value;
  if (firm == null || profile == null || members == null || gate == null) {
    return null;
  }
  if (gate.status != DeviceGateStatus.active &&
      gate.status != DeviceGateStatus.limitReached) {
    return null;
  }

  final people =
      members.where((member) => member.userId != profile.id).toList();
  final associates = people.length;
  final seated =
      people.where((member) => member.capacitySignedOutAt == null).length;

  final tier = ref.watch(allowanceTierProvider);
  final slots = tier.seatCap ?? 0;
  final pendingKey = firm.tierPending;
  final pendingSlots =
      pendingKey == null ? null : SubscriptionTier.fromKey(pendingKey).seatCap;
  final pendingFrom = firm.tierPendingFrom == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(
          firm.tierPendingFrom!,
          isUtc: true,
        );
  final expiry = firm.subscriptionExpiry == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(
          firm.subscriptionExpiry!,
          isUtc: true,
        );

  final offset = ref.watch(clockOffsetMsProvider).value ?? 0;
  final now = DateTime.now().toUtc().add(Duration(milliseconds: offset));

  return resolveFirmCapacity(
    slots: slots,
    pendingSlots: pendingSlots,
    pendingFrom: pendingFrom,
    associates: associates,
    seated: seated,
    ownerDevices: gate.devices.length,
    expiry: expiry,
    now: now,
  );
});
