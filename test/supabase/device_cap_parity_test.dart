/// Guards the device cap against drift between the three places that state it:
/// the paywall's cards (which read `SubscriptionTier.deviceCap`), the server's
/// `tier_device_cap` (which answers the number the cap is enforced with), and
/// `device_cap`'s chamber rule (one device per person, the owner included).
///
/// There is no table holding these numbers, so nothing in the database can catch
/// a tier whose card promises two devices while the server allows one. The
/// failure it would cause is a device refused a slot its own receipt sold it,
/// which is why the guard reads the **last** migration defining each function: a
/// later migration is followed rather than contradicted, and a place it can no
/// longer find is a failure, never a silent pass.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:legal_case_diary/features/payments/data/payment_plans.dart';

import '../../tool/apply_supabase_migrations.dart';

void main() {
  group('Device cap', () {
    test('each tier allows the devices its card sells', () {
      final caps = _capsByTier();

      // The named branches are every tier but Free, which falls to the floor.
      expect(
        caps.keys,
        {
          for (final tier in SubscriptionTier.values)
            if (tier.key != SubscriptionTier.free.key) tier.key,
        },
        reason:
            'a tier with no branch falls through to the floor, so its card '
            'would promise a number the server never reads',
      );

      for (final tier in SubscriptionTier.values) {
        // A null `deviceCap` is the chamber rule, not "unlimited": one device
        // per member, the owner included — so the server still answers 1.
        final expected = tier.deviceCap ?? 1;
        expect(
          tier == SubscriptionTier.free ? _floor() : caps[tier.key],
          expected,
          reason:
              '${tier.key} sells $expected concurrent device(s) and the '
              'server answers ${caps[tier.key] ?? _floor()}',
        );
      }
    });

    test('a chamber member is allowed one device, the owner included', () {
      final sql = _latestDefining(
        'create or replace function public.device_cap(',
      );
      expect(
        sql,
        contains('when p.firm_id is not null then 1'),
        reason:
            'the chamber cards say "one concurrent device each", so a member '
            'and the chamber owner both read 1 whatever the chamber tier says',
      );
    });

    test('the floor is one device, so no account is left without a slot', () {
      expect(_floor(), 1);
    });
  });
}

// --- The server ---------------------------------------------------------------

/// The text of the last migration defining [marker] — the one that wins.
String _latestDefining(String marker) {
  final hits = [
    for (final migration in listMigrations())
      if (File(
        '$migrationsDir/${migration.fileName}',
      ).readAsStringSync().replaceAll('\r\n', '\n').contains(marker))
        File(
          '$migrationsDir/${migration.fileName}',
        ).readAsStringSync().replaceAll('\r\n', '\n'),
  ];
  expect(
    hits,
    isNotEmpty,
    reason:
        'no migration contains `$marker`, so this guard can no longer see '
        'that place — the function was renamed or removed',
  );
  return hits.last;
}

/// The cap `tier_device_cap` names for each tier that has its own branch.
Map<String, int> _capsByTier() {
  final sql = _latestDefining(
    'create or replace function public.tier_device_cap(',
  );
  final from = sql.indexOf(r'as $$');
  final to = sql.indexOf(r'$$;', from);
  expect(from, isNonNegative, reason: 'tier_device_cap has no body');
  expect(to, isNonNegative, reason: 'tier_device_cap has no end');
  return {
    for (final hit in RegExp(
      r"when '([a-z_]+)' then (\d+)",
    ).allMatches(sql.substring(from, to)))
      hit.group(1)!: int.parse(hit.group(2)!),
  };
}

/// The number every unnamed tier, Free included, falls through to.
int _floor() {
  final sql = _latestDefining(
    'create or replace function public.tier_device_cap(',
  );
  final hit = RegExp(r'else (\d+)\s*\n\s*end').firstMatch(sql);
  expect(hit, isNotNull, reason: 'tier_device_cap has no `else` floor');
  return int.parse(hit!.group(1)!);
}
