/// Guards the shared chamber capacity against drift between the plan cards and
/// the server: the tier's slot count, the reserved owner device, the owner's
/// dynamic device cap, and the trim order.
///
/// The numbers live in the SQL, not in a table, so a card promising one figure
/// against a server enforcing another would only surface when a lawyer is
/// refused. Like the device-cap guard, this reads the **last** migration that
/// defines each function.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:legal_case_diary/features/payments/data/payment_plans.dart';

import '../../tool/apply_supabase_migrations.dart';

void main() {
  group('Chamber capacity', () {
    test('the tier slot counts match the cards and the associate count', () {
      final arms = _arms(_latestDefining(
        'create or replace function public.tier_seat_cap(',
      ));

      expect(arms['firm'], 5);
      expect(arms['firm_plus'], 10);
      expect(arms['enterprise'], 20);

      for (final tier in <SubscriptionTier>[
        SubscriptionTier.firm,
        SubscriptionTier.firmPlus,
        SubscriptionTier.enterprise,
      ]) {
        expect(
          tier.seatCap,
          arms[tier.key],
          reason: '${tier.key} sells ${tier.seatCap} slots on its card',
        );
        // The card's collaboration sentence invites one fewer associate than
        // the slot count: the owner's first device uses one.
        expect(tier.seatCap! - 1, arms[tier.key]! - 1);
      }
    });

    test('a join reserves the owner\'s first device', () {
      final sql = _latestDefining(
        'create or replace function public.join_firm(',
      );
      expect(
        sql,
        contains(
          'v_associates + greatest(v_owner_devices, 1) + 1 > v_seat_cap',
        ),
        reason:
            'counting only associates would let a chamber reach its slot count '
            'and then exceed it when the owner signs in',
      );
    });

    test('the owner device cap is the slots left after associates', () {
      final sql = _latestDefining(
        'create or replace function public.device_cap(',
      );
      expect(
        sql,
        contains(
          'public.firm_seat_cap(p.firm_id) - public.firm_associate_count(p.firm_id)',
        ),
      );
    });

    test('a capacity trim removes owner devices first, then newest associates',
        () {
      final sql = _latestDefining(
        'create or replace function public.rebalance_firm_capacity(',
      );
      expect(
        sql,
        contains('least(v_associates, greatest(v_slots - 1, 0))'),
      );
      expect(sql, contains('order by m.joined_at desc, m.id desc'));
      // The owner's devices are the first query; associates are flagged only
      // after that trim, which is the order the ruling chose.
      expect(
        sql.indexOf('order by d.last_seen_at asc'),
        lessThan(sql.indexOf('order by m.joined_at desc')),
      );
    });
  });
}

String _latestDefining(String marker) {
  final hits = [
    for (final migration in listMigrations())
      if (File('$migrationsDir/${migration.fileName}')
          .readAsStringSync()
          .replaceAll('\r\n', '\n')
          .contains(marker))
        File('$migrationsDir/${migration.fileName}')
            .readAsStringSync()
            .replaceAll('\r\n', '\n'),
  ];
  expect(
    hits,
    isNotEmpty,
    reason: 'no migration contains `$marker`; the guard can no longer see it',
  );
  return hits.last;
}

Map<String, int> _arms(String sql) {
  final from = sql.indexOf(r'as $$');
  final to = sql.indexOf(r'$$;', from);
  expect(from, isNonNegative);
  expect(to, isNonNegative);
  return {
    for (final hit in RegExp(r"when '([a-z_]+)' then (\d+)")
        .allMatches(sql.substring(from, to)))
      hit.group(1)!: int.parse(hit.group(2)!),
  };
}
