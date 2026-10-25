/// The shared-capacity resolver: the owner-device cap, the reserved first
/// device, the capacity-signed-out count, and the pending shrink.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/firm_capacity.dart';

void main() {
  final now = DateTime.utc(2026, 10, 26, 12);

  FirmCapacityView view({
    required int slots,
    int? pendingSlots,
    DateTime? pendingFrom,
    required int associates,
    required int seated,
    required int ownerDevices,
    DateTime? expiry,
  }) => resolveFirmCapacity(
    slots: slots,
    pendingSlots: pendingSlots,
    pendingFrom: pendingFrom,
    associates: associates,
    seated: seated,
    ownerDevices: ownerDevices,
    expiry: expiry,
    now: now,
  );

  group('Owner devices and associates share the slots', () {
    test('an owner alone may use every slot', () {
      final v = view(
        slots: 5,
        associates: 0,
        seated: 0,
        ownerDevices: 5,
        expiry: now.add(const Duration(days: 30)),
      );

      expect(v.ownerDeviceCap, 5);
      expect(v.used, 5);
      expect(v.over, isFalse);
      expect(v.canAddAssociate, isFalse);
    });

    test('four associates leave one slot for the owner', () {
      final v = view(
        slots: 5,
        associates: 4,
        seated: 4,
        ownerDevices: 1,
        expiry: now.add(const Duration(days: 30)),
      );

      expect(v.ownerDeviceCap, 1);
      expect(v.used, 5);
      expect(v.over, isFalse);
      expect(v.canAddAssociate, isFalse);
    });

    test('the owner\'s first device is reserved even before it signs in', () {
      final v = view(
        slots: 5,
        associates: 4,
        seated: 4,
        ownerDevices: 0,
        expiry: now.add(const Duration(days: 30)),
      );

      expect(v.used, 4);
      expect(v.over, isFalse);
      // 4 + max(0, 1) + 1 = 6 > 5: a fifth associate cannot join.
      expect(v.canAddAssociate, isFalse);
    });

    test('a third associate can join beside one owner device', () {
      final v = view(
        slots: 5,
        associates: 2,
        seated: 2,
        ownerDevices: 1,
        expiry: now.add(const Duration(days: 30)),
      );

      expect(v.canAddAssociate, isTrue);
    });

    test('a full roster is over even when the device total equals the slots',
        () {
      final v = view(
        slots: 5,
        associates: 5,
        seated: 5,
        ownerDevices: 0,
        expiry: now.add(const Duration(days: 30)),
      );

      expect(v.overRoster, isTrue);
      expect(v.over, isTrue);
    });

    test('signed-out associates still hold their seats', () {
      final v = view(
        slots: 5,
        associates: 7,
        seated: 4,
        ownerDevices: 1,
        expiry: now.add(const Duration(days: 30)),
      );

      expect(v.signedOut, 3);
      expect(v.active, 5);
      expect(v.used, 8);
      expect(v.overRoster, isTrue);
    });
  });

  group('A pending lower tier', () {
    test('names the associates and devices it will sign out', () {
      final v = view(
        slots: 10,
        pendingSlots: 5,
        pendingFrom: now.add(const Duration(days: 1)),
        associates: 7,
        seated: 7,
        ownerDevices: 1,
        expiry: now.add(const Duration(days: 30)),
      );

      expect(v.shrinkAt, now.add(const Duration(days: 1)));
      expect(v.pendingAssociatesExcess, 3);
      expect(v.pendingDevicesExcess, 0);
      expect(v.shrinkPending, isTrue);
    });

    test('trims the owner\'s extra devices before any associate', () {
      final v = view(
        slots: 10,
        pendingSlots: 5,
        pendingFrom: now.add(const Duration(days: 1)),
        associates: 2,
        seated: 2,
        ownerDevices: 4,
        expiry: now.add(const Duration(days: 30)),
      );

      expect(v.pendingAssociatesExcess, 0);
      expect(v.pendingDevicesExcess, 1);
      expect(v.shrinkPending, isTrue);
    });

    test('a pending upgrade is not a shrink', () {
      final v = view(
        slots: 5,
        pendingSlots: 10,
        pendingFrom: now.add(const Duration(days: 1)),
        associates: 4,
        seated: 4,
        ownerDevices: 1,
        expiry: now.add(const Duration(days: 30)),
      );

      expect(v.shrinkAt, isNull);
      expect(v.shrinkPending, isFalse);
    });
  });

  group('The 48-hour grace', () {
    test('is still live one hour before its end', () {
      final v = view(
        slots: 5,
        associates: 0,
        seated: 0,
        ownerDevices: 1,
        expiry: now.subtract(const Duration(hours: 47)),
      );

      expect(v.frozen, isFalse);
    });

    test('is over at the boundary and after it', () {
      final atBoundary = view(
        slots: 5,
        associates: 0,
        seated: 0,
        ownerDevices: 1,
        expiry: now.subtract(const Duration(hours: 48)),
      );
      final after = view(
        slots: 5,
        associates: 0,
        seated: 0,
        ownerDevices: 1,
        expiry: now.subtract(const Duration(hours: 49)),
      );

      expect(atBoundary.frozen, isTrue);
      expect(after.frozen, isTrue);
    });

    test('a chamber that never had a plan is frozen', () {
      final v = view(
        slots: 5,
        associates: 0,
        seated: 0,
        ownerDevices: 1,
      );

      expect(v.frozen, isTrue);
    });
  });
}
