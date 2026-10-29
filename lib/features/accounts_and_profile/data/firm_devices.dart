/// The chamber's devices, as its owner's Devices screen reads them.
///
/// The registry is server-managed and grants no read to any client role, so
/// this one RPC (`firm_device_list`) is how the owner names who holds the
/// chamber's shared slots. An associate keeps the ordinary per-account answer
/// (`device_state`), and an individual gets `not_owner`, which reads here as
/// null — the screen then keeps its own list alone.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_providers.dart';

/// One active device in the chamber.
class FirmDevice {
  /// Creates one device row.
  const FirmDevice({
    required this.id,
    required this.label,
    required this.platform,
    required this.memberName,
    required this.isOwner,
    this.lastSeenAt,
    this.isCurrent = false,
  });

  /// The row id.
  final String id;

  /// The phone's own label, e.g. *Samsung SM-A525F*.
  final String label;

  /// `android`, `ios`, `windows` or `unknown`.
  final String platform;

  /// The account holder's name, as the server holds it.
  final String memberName;

  /// Whether the chamber's owner holds this device.
  final bool isOwner;

  /// When the server last heard from it.
  final DateTime? lastSeenAt;

  /// Whether this is the device showing the list.
  final bool isCurrent;
}

/// The chamber's active devices, with the numbers its screen states.
class FirmDeviceList {
  /// Creates one answer.
  const FirmDeviceList({
    required this.slots,
    required this.associates,
    required this.devices,
  });

  /// Slots the chamber's plan sells.
  final int slots;

  /// Associates on the roster (signed out or not).
  final int associates;

  /// Every active device in the chamber, owner's first.
  final List<FirmDevice> devices;

  /// The associates' devices, in the order the server returned them.
  List<FirmDevice> get associateDevices =>
      devices.where((device) => !device.isOwner).toList(growable: false);
}

/// The chamber's device list for its owner, or null when it does not apply.
///
/// Null covers four cases the screen treats the same way: no backend, an
/// answered `not_owner`, a member or individual, and a read the server could
/// not answer. Invalidating it is what a pull and the screen's open both do.
final firmDeviceListProvider = FutureProvider<FirmDeviceList?>((ref) async {
  final client = ref.watch(activeSupabaseClientProvider);
  if (client == null) return null;

  final data = await client.rpc<Map<String, dynamic>>('firm_device_list');
  if (data['status'] != 'ok') return null;

  final raw = data['devices'];
  return FirmDeviceList(
    slots: (data['slots'] as num?)?.toInt() ?? 0,
    associates: (data['associates'] as num?)?.toInt() ?? 0,
    devices: raw is! List
        ? const <FirmDevice>[]
        : raw
              .whereType<Map<String, dynamic>>()
              .map(
                (row) => FirmDevice(
                  id: row['id'] as String? ?? '',
                  label: (row['label'] as String?)?.trim().isNotEmpty == true
                      ? row['label'] as String
                      : 'Unknown device',
                  platform: row['platform'] as String? ?? 'unknown',
                  memberName: (row['member_name'] as String?)?.trim() ?? '',
                  isOwner: row['is_owner'] == true,
                  lastSeenAt: DateTime.tryParse(
                    row['last_seen_at'] as String? ?? '',
                  )?.toLocal(),
                  isCurrent: row['is_current'] == true,
                ),
              )
              .toList(growable: false),
  );
});
