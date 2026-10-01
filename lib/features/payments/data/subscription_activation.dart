/// Activation detection: notice a free → premium upgrade and push the backlog.
///
/// Task 21 Phase 4 item 3 / plan §2. A payment is approved by the admin RPC on
/// the server; the app learns about it through the ordinary profile refresh on
/// launch/resume (a `profiles`/`payment_submissions` Broadcast ping does not
/// exist — neither table has the row trigger). When the derived entitlement
/// rises from **false to true**, this runs [SyncService.runBacklogPush] once,
/// which compacts and pushes everything the account accumulated while it was
/// free and then does a full pull.
///
/// "Once per upgrade" needs durable memory, because the transition may happen
/// while the app is closed: the last observed entitlement is stored per account
/// (`subscription_was_premium_<userId>`). A missing value is *no prior state* —
/// a first-ever launch stores the current value and does **not** push, so a
/// brand-new install never fires a backlog pass. A stored `false` that becomes
/// `true` is the upgrade, however long the app was closed in between.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/providers/shared_preferences_provider.dart';
import '../../../sync/sync_service.dart';
import '../../accounts_and_profile/data/account_mode.dart';

/// Preference key holding the last observed entitlement for one account.
String subscriptionWasPremiumKey(String userId) =>
    'subscription_was_premium_$userId';

/// Records entitlement transitions and runs the backlog pass on an upgrade.
class SubscriptionActivation {
  /// Creates the detector for [userId].
  SubscriptionActivation({
    required this.prefs,
    required this.userId,
    required this.runBacklogPush,
  });

  /// The device's preferences store.
  final SharedPreferences prefs;

  /// The account whose entitlement is observed.
  final String userId;

  /// The free → premium backlog pass to run on an upgrade.
  final Future<void> Function() runBacklogPush;

  /// Observes [premium] and returns true when it triggered the backlog push.
  ///
  /// Safe to call on every entitlement change; it is a no-op unless the value
  /// actually changed to `true` from a stored `false`.
  Future<bool> observe(bool premium) async {
    final key = subscriptionWasPremiumKey(userId);
    final previous = prefs.getBool(key);
    if (previous == premium) return false;
    await prefs.setBool(key, premium);
    if (previous == false && premium) {
      await runBacklogPush();
      return true;
    }
    return false;
  }
}

/// The activation detector for the signed-in account.
final subscriptionActivationProvider = Provider<SubscriptionActivation>((ref) {
  return SubscriptionActivation(
    prefs: ref.watch(sharedPreferencesProvider),
    userId: ref.watch(accountCacheUserIdProvider),
    runBacklogPush: () async {
      await ref.read(syncServiceProvider).runBacklogPush();
    },
  );
});
