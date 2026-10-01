/// Entitlement derivation tests — Task 21 Phase 3.
///
/// Pins the single rule (`subscription_expiry + 48h grace > server now`): active,
/// in-grace, lapsed, firm-inherited, and the clock-skew correction that stops a
/// device clock running ahead from falsely expiring a subscription inside grace.
library;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/settings/data/premium_access.dart';
import 'package:legal_case_diary/sync/sync_metadata_dao.dart';

const _userId = 'premium-user';

void main() {
  late AppDatabase db;
  late DateTime now;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    now = DateTime.utc(2026, 10, 1, 12);
    await db
        .into(db.profiles)
        .insert(
          ProfilesCompanion(
            id: const Value(_userId),
            fullName: const Value('Premium User'),
            role: const Value('individual'),
            subscriptionStatus: const Value('free'),
            createdAt: const Value(1),
          ),
        );
  });

  tearDown(() async => db.close());

  Future<void> setExpiry(DateTime expiry) => db
      .update(db.profiles)
      .write(
        ProfilesCompanion(
          id: const Value(_userId),
          subscriptionExpiry: Value(expiry.millisecondsSinceEpoch),
        ),
      );

  test('an unexpired subscription is premium', () async {
    await setExpiry(now.add(const Duration(days: 30)));
    expect(await resolvePremiumAccess(db, _userId, now: now), isTrue);
  });

  test('an expiry inside the 48h grace is still premium', () async {
    await setExpiry(now.subtract(const Duration(hours: 1)));
    expect(await resolvePremiumAccess(db, _userId, now: now), isTrue);
  });

  test('an expiry past the grace window is not premium', () async {
    await setExpiry(now.subtract(const Duration(hours: 49)));
    expect(await resolvePremiumAccess(db, _userId, now: now), isFalse);
  });

  test('a display-only premium status cannot grant access', () async {
    await db
        .update(db.profiles)
        .write(
          ProfilesCompanion(
            id: const Value(_userId),
            subscriptionStatus: const Value('premium'),
            subscriptionExpiry: Value(
              now.subtract(const Duration(days: 30)).millisecondsSinceEpoch,
            ),
          ),
        );
    expect(await resolvePremiumAccess(db, _userId, now: now), isFalse);
  });

  test('no expiry at all is not premium', () async {
    expect(await resolvePremiumAccess(db, _userId, now: now), isFalse);
  });

  test('a firm member inherits the firm expiry, not their own', () async {
    await db
        .into(db.firms)
        .insert(
          FirmsCompanion(
            id: const Value('firm-1'),
            name: const Value('Premium Firm'),
            ownerId: const Value('owner-1'),
            subscriptionStatus: const Value('premium'),
            subscriptionExpiry: Value(
              now.add(const Duration(days: 10)).millisecondsSinceEpoch,
            ),
            createdAt: const Value(1),
          ),
        );
    await db
        .update(db.profiles)
        .write(
          ProfilesCompanion(
            id: const Value(_userId),
            firmId: const Value('firm-1'),
            subscriptionExpiry: Value(
              now.subtract(const Duration(days: 30)).millisecondsSinceEpoch,
            ),
          ),
        );
    expect(await resolvePremiumAccess(db, _userId, now: now), isTrue);
  });

  test('a device clock ahead does not falsely expire a subscription in grace',
      () async {
    // The device believes it is 2h ahead of the server, so the true server now
    // is 2h earlier. A subscription 49h past its expiry by the device clock is
    // only 47h past it by server time — inside the 48h grace.
    await setExpiry(now.subtract(const Duration(hours: 49)));
    expect(await resolvePremiumAccess(db, _userId, now: now), isFalse);

    // offset = server - device = -2h.
    await SyncMetadataDao(
      db,
    ).setIntValue(clockOffsetMsKey, -2 * 60 * 60 * 1000);
    expect(await resolvePremiumAccess(db, _userId, now: now), isTrue);
  });
}
