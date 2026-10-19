/// Guards the payment ladder against drift between the two sides that hold it:
/// the client's ladder in `payment_plans.dart` with one label per plan in each
/// locale, and the server's four places in SQL — `approve_payment`'s allow-list,
/// its amount `CASE`, its duration `CASE` and the generated `plan_name` `CASE`
/// (`tier` is read from the key by a fifth `CASE`, checked here too).
///
/// The server additionally accepts the **four legacy keys** the old ten-plan
/// ladder sold (`monthly`, `quarterly`, `half_yearly`, `annual`), so a submission
/// already waiting when the ladder changed can still be resolved. They are not
/// sellable on the client and are checked separately: a legacy key's tier and
/// label are Starter, because that is the rung the old `pro` became.
///
/// There is **no `payment_plans` table**, so nothing in the database can catch a
/// key that was added in one place only. The failure it would cause is a paying
/// user's submission refused with `invalid_plan`, or their amount refused with
/// `invalid_amount` — a rejected payment rather than a wrong price, which is
/// exactly why this guard is two-directional: a key on either side with no
/// counterpart fails, in either direction.
///
/// It reads the **last** migration that defines each place, so a later migration
/// that changes the ladder is followed rather than contradicted, and a place it
/// can no longer find is a failure, never a silent pass.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:legal_case_diary/features/payments/data/payment_plans.dart';

import '../../tool/apply_supabase_migrations.dart';

/// Where the plan labels live, one file per locale.
const String _enArb = 'lib/core/l10n/app_en.arb';

/// The Bengali labels, which must cover the same keys as [_enArb].
const String _bnArb = 'lib/core/l10n/app_bn.arb';

/// The ladder's length, pinned so a plan cannot be dropped or added silently.
const int _ladderLength = 17;

/// The four keys the old ladder sold, which the server still resolves.
const Set<String> _legacyKeys = <String>{
  'monthly',
  'quarterly',
  'half_yearly',
  'annual',
};

/// The Starter label each legacy key answers now.
const Map<String, String> _legacyLabelKey = <String, String>{
  'monthly': 'paywall_planStarterMonthly',
  'quarterly': 'paywall_planStarterQuarterly',
  'half_yearly': 'paywall_planStarterHalfYearly',
  'annual': 'paywall_planStarterAnnual',
};

void main() {
  group('Payment plan ladder', () {
    test('the client sells exactly the seventeen keys the server accepts', () {
      final allowed = _allowedKeys();
      final clientKeys = _clientKeys();

      expect(_ladderLength, subscriptionPlans.length, reason: 'the ladder is seventeen plans');
      expect(
        clientKeys,
        allowed.difference(_legacyKeys),
        reason: 'a key the server does not accept is a payment refused with '
            '`invalid_plan`; a key the server accepts and the client does not sell '
            'is a plan nobody can buy. The four legacy keys are the intentional '
            'exception: they resolve old pending rows and are never sold again.',
      );
      expect(allowed.difference(_legacyKeys), clientKeys);
    });

    test('each price is the price the server validates', () {
      final amounts = _amountsByKey();
      for (final plan in subscriptionPlans) {
        expect(
          amounts[plan.key],
          plan.amount,
          reason: '${plan.key} is sold at ৳${plan.amount} and validated against '
              '${amounts[plan.key]} — the amount mismatch is `invalid_amount`',
        );
      }
      expect(amounts.keys, _serverKeys(), reason: 'every accepted key has one amount, and no amount has no key');
    });

    test('each length is the length the server grants', () {
      final months = _monthsByKey();
      for (final plan in subscriptionPlans) {
        expect(
          months[plan.key],
          plan.months,
          reason: '${plan.key} sells ${plan.months} months and the server grants '
              '${months[plan.key]}',
        );
      }
      expect(months.keys, _serverKeys(), reason: 'every accepted key has one duration, and no duration has no key');
    });

    test('the four legacy keys keep their old price and length', () {
      const legacy = <String, (int, int)>{
        'monthly': (100, 1),
        'quarterly': (285, 3),
        'half_yearly': (540, 6),
        'annual': (1000, 12),
      };
      final amounts = _amountsByKey();
      final months = _monthsByKey();
      for (final entry in legacy.entries) {
        expect(amounts[entry.key], entry.value.$1, reason: '${entry.key} was sold at ${entry.value.$1}');
        expect(months[entry.key], entry.value.$2, reason: '${entry.key} granted ${entry.value.$2} months');
      }
    });

    test('each tier is the tier the server reads from the key', () {
      final tiers = _tiersByKey();
      for (final plan in subscriptionPlans) {
        expect(
          tiers[plan.key],
          plan.tier.key,
          reason: '${plan.key} is ${plan.tier.key} on the client and '
              '${tiers[plan.key]} on the server — the gate and the seat cap read '
              'the server`s answer',
        );
      }
      // The old Pro rung is the new Starter rung, so a legacy key buys Starter.
      for (final key in _legacyKeys) {
        expect(tiers[key], SubscriptionTier.starter.key);
      }
      expect(tiers.keys, _serverKeys(), reason: 'every accepted key names one tier, and no tier has no key');
    });

    test('each key has a readable name on the server, and the client says the same', () {
      final names = _serverNames();
      for (final plan in subscriptionPlans) {
        final expected = _labelOf(_enArb, plan.key);
        expect(
          names[plan.key],
          expected,
          reason: '${plan.key} is named "${names[plan.key]}" on the server and '
              '"$expected" on the client',
        );
      }
      // A legacy key's generated name is the Starter name it now maps to.
      for (final key in _legacyKeys) {
        expect(names[key], _arbOf(_enArb)[_legacyLabelKey[key]]);
      }
      expect(names.keys, _serverKeys(), reason: 'every accepted key has one readable name, and no name has no key');
    });

    test('both locales label every key, and no label exists without a key', () {
      final expected = {for (final key in _clientKeys()) _labelKeyFor(key)};
      expect(expected.length, _ladderLength, reason: 'seventeen plans, seventeen labels');
      for (final arb in <String>[_enArb, _bnArb]) {
        final labels = _labelKeysIn(arb);
        expect(
          labels,
          expected,
          reason: '$arb must carry one label per plan and nothing else — an orphan '
              'label is a plan the client can name but not sell',
        );
        for (final label in labels) {
          expect(
            _arbOf(arb)[label],
            isNotEmpty,
            reason: '$label is empty in $arb',
          );
        }
      }
    });

    test('every one of the four places covers every key', () {
      final keys = _serverKeys();
      // The four places the blueprint's hazard names, plus the tier `CASE`: a key
      // added to one of these alone is the drift this guard exists to catch.
      final places = <String, Set<String>>{
        'the allow-list': _allowedKeys(),
        'the amount CASE': _amountsByKey().keys.toSet(),
        'the duration CASE': _monthsByKey().keys.toSet(),
        'the generated plan_name': _serverNames().keys.toSet(),
        'the tier CASE': _tiersByKey().keys.toSet(),
      };
      for (final entry in places.entries) {
        expect(
          entry.value,
          keys,
          reason: '${entry.key} must cover exactly the ladder — a key in one place '
              'only is a plan the server half-accepts',
        );
      }
    });
  });
}

// --- The client ---------------------------------------------------------------

/// The client's seventeen sellable plan keys.
Set<String> _clientKeys() => {for (final plan in subscriptionPlans) plan.key};

/// Every key the server accepts: the sellable ladder plus the legacy four.
Set<String> _serverKeys() => {..._clientKeys(), ..._legacyKeys};

/// `firm_plus_half_yearly` → `paywall_planFirmPlusHalfYearly`.
String _labelKeyFor(String planKey) =>
    'paywall_plan${planKey.split('_').map(_capitalize).join()}';

/// `firm` → `Firm`, the one-word step of [_labelKeyFor].
String _capitalize(String word) =>
    word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}';

/// One ARB file as its JSON object.
Map<String, dynamic> _arbOf(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

/// Every plan label in [path] — `paywall_plansTitle` is deliberately excluded:
/// it is the section heading, not a plan, and its `s` after `plan` is lower case.
Set<String> _labelKeysIn(String path) => {
      for (final key in _arbOf(path).keys)
        if (RegExp(r'^paywall_plan[A-Z]').hasMatch(key)) key,
    };

/// The one plan label for [planKey] in [path], failing loudly when it is absent.
String _labelOf(String path, String planKey) {
  final labelKey = _labelKeyFor(planKey);
  final value = _arbOf(path)[labelKey];
  expect(value, isA<String>(), reason: '$path has no $labelKey for $planKey');
  return value! as String;
}

// --- The server ---------------------------------------------------------------

/// Every migration on disk in apply order, with CRLF normalised so the patterns
/// below match one line ending.
List<(String, String)> _migrations() => [
      for (final migration in listMigrations())
        (
          migration.fileName,
          File('$migrationsDir/${migration.fileName}')
              .readAsStringSync()
              .replaceAll('\r\n', '\n'),
        ),
    ];

/// The text of the last migration defining [marker] — the one that wins, because
/// a later migration replaces an earlier one.
String _latestDefining(String marker) {
  final hits =
      _migrations().where((migration) => migration.$2.contains(marker)).toList();
  expect(
    hits,
    isNotEmpty,
    reason: 'no migration contains `$marker`, so this guard can no longer see that '
        'place — the ladder moved or was renamed',
  );
  return hits.last.$2;
}

/// The text of the last migration whose SQL matches [pattern] — the one that
/// wins, because a later migration replaces an earlier one.
String _latestMatching(RegExp pattern, String what) {
  final hits =
      _migrations().where((migration) => pattern.hasMatch(migration.$2)).toList();
  expect(
    hits,
    isNotEmpty,
    reason: 'no migration holds $what, so this guard can no longer see that place',
  );
  return hits.last.$2;
}

/// The text of [sql] from [start] to the next [end], failing when either is gone.
String _block(String sql, String start, String end, String what) {
  final from = sql.indexOf(start);
  expect(from, isNonNegative, reason: '$what no longer contains `$start`');
  final to = sql.indexOf(end, from);
  expect(to, isNonNegative, reason: '$what has no `$end` after `$start`');
  return sql.substring(from, to);
}

/// The tenth key of a chain: the `CASE` writes its last branch as `else`, so the
/// key it covers is the ladder key no `when` branch named. Exactly one may be
/// missing, and the caller decides what that means.
String _elseKey(Set<String> covered, String elseValue, String what) {
  final remaining = _serverKeys().difference(covered);
  expect(
    remaining.length,
    1,
    reason: '$what`s `else` branch covers ${remaining.length} ladder keys, not one — '
        'the ladder and the branches disagree',
  );
  expect(
    elseValue,
    isNotEmpty,
    reason: '$what`s `else` branch names nothing',
  );
  return remaining.single;
}

/// The keys `approve_payment` accepts, from its `not in (...)` refusal.
Set<String> _allowedKeys() {
  final sql = _latestDefining('if v_submission.plan_type not in (');
  final match = RegExp(r'if v_submission\.plan_type not in \(\s*([^)]*)\)')
      .firstMatch(sql);
  expect(match, isNotNull, reason: 'the allow-list is no longer a literal list of keys');
  return RegExp(r"'([a-z_]+)'")
      .allMatches(match!.group(1)!)
      .map((hit) => hit.group(1)!)
      .toSet();
}

/// The amount the server validates for each key, resolved through the named
/// constants the same migration declares.
Map<String, int> _amountsByKey() {
  const marker = 'v_plan_amount := (case v_submission.plan_type';
  final sql = _latestDefining(marker);
  final block = _block(sql, marker, 'end);', 'the amount CASE');

  final constants = <String, int>{
    for (final hit
        in RegExp(r'(c_[a-z_]+_bdt)\s+constant\s+integer\s*:=\s*(\d+)\s*;')
            .allMatches(sql))
      hit.group(1)!: int.parse(hit.group(2)!),
  };
  expect(
    constants,
    isNotEmpty,
    reason: 'the amount constants are no longer declared beside the CASE that uses them',
  );

  final byKey = <String, int>{};
  for (final hit in RegExp(r"when '([a-z_]+)' then (c_[a-z_]+_bdt)").allMatches(block)) {
    final key = hit.group(1)!;
    final constant = hit.group(2)!;
    expect(
      constants[constant],
      isNotNull,
      reason: '$key is priced at `$constant`, which no `constant integer` declares',
    );
    byKey[key] = constants[constant]!;
  }

  final elseMatch = RegExp(r'else\s+(c_[a-z_]+_bdt)').firstMatch(block);
  expect(elseMatch, isNotNull, reason: 'the amount CASE has no `else` constant');
  final elseConstant = elseMatch!.group(1)!;
  expect(
    constants[elseConstant],
    isNotNull,
    reason: 'the `else` amount `$elseConstant` is not declared',
  );
  byKey[_elseKey(byKey.keys.toSet(), elseConstant, 'the amount CASE')] =
      constants[elseConstant]!;

  expect(
    constants.keys.toSet(),
    _constantNamesIn(block),
    reason: 'a declared amount constant is unused, which means a price with no key',
  );
  return byKey;
}

/// The `c_..._bdt` identifiers the amount block actually references.
Set<String> _constantNamesIn(String block) => {
      for (final hit in RegExp(r'(c_[a-z_]+_bdt)').allMatches(block)) hit.group(1)!,
    };

/// The months the server grants for each key, from the duration CASE.
Map<String, int> _monthsByKey() {
  const marker = 'v_plan_months := (case v_submission.plan_type';
  final sql = _latestDefining(marker);
  final block = _block(sql, marker, 'end);', 'the duration CASE');

  final byKey = <String, int>{
    for (final hit in RegExp(r"when '([a-z_]+)' then (\d+)").allMatches(block))
      hit.group(1)!: int.parse(hit.group(2)!),
  };
  final elseMatch = RegExp(r'else\s+(\d+)').firstMatch(block);
  expect(elseMatch, isNotNull, reason: 'the duration CASE has no `else`');
  byKey[_elseKey(byKey.keys.toSet(), elseMatch!.group(1)!, 'the duration CASE')] =
      int.parse(elseMatch.group(1)!);
  return byKey;
}

/// The tier the server reads from each key, from the tier CASE.
Map<String, String> _tiersByKey() {
  final sql = _latestDefining('v_tier := (case');
  final block = _block(sql, 'v_tier := (case', 'end);', 'the tier CASE');

  final byKey = <String, String>{};
  for (final hit
      in RegExp(r"in \(([^)]*)\)\s*then '([a-z_]+)'").allMatches(block)) {
    final tier = hit.group(2)!;
    for (final key in RegExp(r"'([a-z_]+)'").allMatches(hit.group(1)!)) {
      byKey[key.group(1)!] = tier;
    }
  }
  final elseMatch = RegExp(r"else\s+'([a-z_]+)'").firstMatch(block);
  expect(elseMatch, isNotNull, reason: 'the tier CASE has no `else`');
  // Unlike the price and the duration, whose `else` is one plan's own value, a
  // tier covers several keys: `else` here is the whole top of the ladder.
  final remaining = _serverKeys().difference(byKey.keys.toSet());
  expect(
    remaining,
    isNotEmpty,
    reason: 'the tier CASE`s `else` covers no ladder key at all',
  );
  for (final key in remaining) {
    byKey[key] = elseMatch!.group(1)!;
  }
  return byKey;
}

/// The readable name the server generates for each key, from the `plan_name`
/// `CASE` — every generated copy of it must agree, since a plan's name is shown
/// to an approver and stored on the approval event.
Map<String, String> _serverNames() {
  // Matched by its own shape rather than by a marker, because a generated column
  // other than `plan_name` may be the newest use of `generated always as (`.
  final namesPattern =
      RegExp(r'generated always as \(\s*case plan_type([\s\S]*?)end\s*\)');
  final sql = _latestMatching(namesPattern, 'the generated `plan_name` CASE');
  final blocks = namesPattern.allMatches(sql).toList();
  expect(
    blocks,
    isNotEmpty,
    reason: 'no generated `plan_name` CASE is left — the readable names are gone',
  );

  final names = <String, String>{};
  for (final block in blocks) {
    final thisBlock = <String, String>{
      for (final hit in RegExp(r"when '([a-z_]+)' then '([^']*)'").allMatches(block.group(1)!))
        hit.group(1)!: hit.group(2)!,
    };
    if (names.isEmpty) {
      names.addAll(thisBlock);
    } else {
      expect(
        thisBlock,
        names,
        reason: 'the generated `plan_name` CASEs disagree — one table would show a '
            'different name for the same key',
      );
    }
  }
  return names;
}
