/// Tests for the device's copy of the running plan (0.0.683).
///
/// The rule being pinned is the one the user reported broken: `payment_submissions`
/// is a live server read, so with no link the plan label stopped naming the plan
/// and printed the generic *Premium*. The copy is written by every successful
/// ledger read, stands in only while the ledger has no answer, and is refused
/// once the tier it was recorded for is no longer the tier the cached rows hold.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:legal_case_diary/core/providers/repository_providers.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/account_mode.dart'
    show
        accountCacheUserIdProvider,
        currentTierProvider,
        entitlementKnownProvider,
        firmMemberProvider,
        premiumAccessProvider;
import 'package:legal_case_diary/features/payments/data/payment_local_store.dart';
import 'package:legal_case_diary/features/payments/data/payment_plans.dart';
import 'package:legal_case_diary/features/payments/data/payment_repository.dart';
import 'package:legal_case_diary/features/payments/presentation/current_plan.dart';
import 'package:legal_case_diary/shared/providers/shared_preferences_provider.dart';

import '../test_utils.dart';

const _userId = 'user-1';

PaymentSubmission _row(
  String id,
  String planType, {
  String status = 'approved',
}) => PaymentSubmission(
  id: id,
  planType: planType,
  amount: 1,
  mfsProvider: 'bkash',
  senderNumber: '01700000000',
  transactionId: id,
  status: status,
);

/// A container whose plan label reads [ledger] and remembers the answer.
ProviderContainer _container({
  required SharedPreferences prefs,
  required Future<List<PaymentSubmission>> Function() ledger,
  SubscriptionTier tier = SubscriptionTier.firmPlus,
  bool member = false,
}) {
  final container = ProviderContainer(
    overrides: withErrorLog(<Override>[
      sharedPreferencesProvider.overrideWithValue(prefs),
      accountCacheUserIdProvider.overrideWithValue(_userId),
      premiumAccessProvider.overrideWith((ref) async => true),
      entitlementKnownProvider.overrideWithValue(true),
      firmMemberProvider.overrideWithValue(member),
      currentTierProvider.overrideWithValue(tier),
      myPaymentSubmissionsProvider.overrideWith((ref) => ledger()),
    ]),
  );
  addTearDown(container.dispose);
  return container;
}

/// Seeds the copy the way an earlier online session left it.
Future<void> _seedCopy(
  SharedPreferences prefs,
  String planKey,
  SubscriptionTier tier,
) async {
  await prefs.setString(runningPlanKeyCacheKey(_userId), planKey);
  await prefs.setString(runningPlanTierCacheKey(_userId), tier.key);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('a live ledger names the plan and the device remembers it', () async {
    final prefs = await SharedPreferences.getInstance();
    final container = _container(
      prefs: prefs,
      ledger: () async => [
        _row('1', paymentPlanFirmPlusHalfYearly),
        _row('2', paymentPlanFirmPlusQuarterly),
      ],
    );

    await container.read(myPaymentSubmissionsProvider.future);

    expect(
      container.read(currentPlanProvider).planKey,
      paymentPlanFirmPlusHalfYearly,
    );
    // The copy is written off the build, so let it land before reading it back.
    await pumpEventQueue();
    expect(
      prefs.getString(runningPlanKeyCacheKey(_userId)),
      paymentPlanFirmPlusHalfYearly,
    );
    expect(
      prefs.getString(runningPlanTierCacheKey(_userId)),
      SubscriptionTier.firmPlus.key,
    );
  });

  test('with no link the remembered plan names the row', () async {
    final prefs = await SharedPreferences.getInstance();
    await _seedCopy(
      prefs,
      paymentPlanFirmPlusHalfYearly,
      SubscriptionTier.firmPlus,
    );

    final container = _container(
      prefs: prefs,
      ledger: () async => throw Exception('offline'),
    );

    // No await: the ledger has not answered, which is exactly the offline case.
    expect(
      container.read(currentPlanProvider).planKey,
      paymentPlanFirmPlusHalfYearly,
    );
  });

  test('the copy is refused when the tier no longer matches', () async {
    final prefs = await SharedPreferences.getInstance();
    await _seedCopy(
      prefs,
      paymentPlanFirmPlusHalfYearly,
      SubscriptionTier.firmPlus,
    );

    final container = _container(
      prefs: prefs,
      ledger: () async => throw Exception('offline'),
      tier: SubscriptionTier.firm,
    );

    expect(container.read(currentPlanProvider).planKey, isNull);
  });

  test('a live read that names no plan clears the copy', () async {
    final prefs = await SharedPreferences.getInstance();
    await _seedCopy(
      prefs,
      paymentPlanFirmPlusHalfYearly,
      SubscriptionTier.firmPlus,
    );

    final container = _container(
      prefs: prefs,
      ledger: () async => [
        _row('1', paymentPlanFirmPlusHalfYearly, status: 'pending'),
      ],
    );

    await container.read(myPaymentSubmissionsProvider.future);

    expect(container.read(currentPlanProvider).planKey, isNull);
    await pumpEventQueue();
    expect(prefs.getString(runningPlanKeyCacheKey(_userId)), isNull);
    expect(prefs.getString(runningPlanTierCacheKey(_userId)), isNull);
  });

  test('a chamber member never reads the copy', () async {
    final prefs = await SharedPreferences.getInstance();
    await _seedCopy(
      prefs,
      paymentPlanFirmPlusHalfYearly,
      SubscriptionTier.firmPlus,
    );

    final container = _container(
      prefs: prefs,
      ledger: () async => throw Exception('offline'),
      member: true,
    );

    // A member's plan is the chamber's, which this ledger never names.
    expect(container.read(currentPlanProvider).planKey, isNull);
  });

  test('the running key is the newest approval of the tier in force', () {
    expect(
      runningPlanKey([
        paymentPlanFirmPlusQuarterly, // queued: a different tier
        paymentPlanStarterAnnual,
        paymentPlanLegacyAnnual,
      ], SubscriptionTier.starter),
      paymentPlanStarterAnnual,
    );
    expect(
      runningPlanKey([paymentPlanFirmPlusQuarterly], SubscriptionTier.firmPlus),
      paymentPlanFirmPlusQuarterly,
    );
    expect(runningPlanKey(const <String>[], SubscriptionTier.firmPlus), isNull);
  });
}
