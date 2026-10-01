/// Activation detection tests — Task 21 Phase 4.
///
/// The backlog pass must run once per free → premium upgrade, including one that
/// happened while the app was closed, and never on a first-ever launch or a
/// repeated observation of the same value.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:legal_case_diary/features/payments/data/subscription_activation.dart';

const _userId = 'user-1';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('a first-ever observation stores the value and does not push', () async {
    var pushes = 0;
    final activation = SubscriptionActivation(
      prefs: await SharedPreferences.getInstance(),
      userId: _userId,
      runBacklogPush: () async => pushes++,
    );

    expect(await activation.observe(true), isFalse);
    expect(pushes, 0);
  });

  test('a stored false that becomes true pushes exactly once', () async {
    var pushes = 0;
    final prefs = await SharedPreferences.getInstance();
    final activation = SubscriptionActivation(
      prefs: prefs,
      userId: _userId,
      runBacklogPush: () async => pushes++,
    );

    await activation.observe(false); // free, first time
    expect(await activation.observe(true), isTrue); // upgrade
    expect(pushes, 1);

    // Still premium: no second push.
    expect(await activation.observe(true), isFalse);
    expect(pushes, 1);
  });

  test('an upgrade that survived a restart is detected on the next observe',
      () async {
    final prefs = await SharedPreferences.getInstance();
    // A previous session stored the free state, then the app closed.
    await prefs.setBool(subscriptionWasPremiumKey(_userId), false);

    var pushes = 0;
    final activation = SubscriptionActivation(
      prefs: prefs,
      userId: _userId,
      runBacklogPush: () async => pushes++,
    );

    expect(await activation.observe(true), isTrue);
    expect(pushes, 1);
  });

  test('a lapse and a later re-upgrade push again', () async {
    var pushes = 0;
    final activation = SubscriptionActivation(
      prefs: await SharedPreferences.getInstance(),
      userId: _userId,
      runBacklogPush: () async => pushes++,
    );

    await activation.observe(false);
    await activation.observe(true); // first upgrade
    await activation.observe(false); // lapsed
    expect(await activation.observe(true), isTrue); // re-upgrade
    expect(pushes, 2);
  });

  test('state is per account', () async {
    var pushes = 0;
    final prefs = await SharedPreferences.getInstance();
    final first = SubscriptionActivation(
      prefs: prefs,
      userId: 'a',
      runBacklogPush: () async => pushes++,
    );
    final second = SubscriptionActivation(
      prefs: prefs,
      userId: 'b',
      runBacklogPush: () async => pushes++,
    );

    await first.observe(false);
    await first.observe(true);
    // The second account has no stored state, so nothing is inferred for it.
    expect(await second.observe(true), isFalse);
    expect(pushes, 1);
  });
}
