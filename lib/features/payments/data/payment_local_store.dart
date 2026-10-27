/// Per-user local payments state: the checkout draft, the submission log and
/// the plan this device last saw running.
///
/// Task 21 Phase 2 / Addendum. Three things must survive closing the app and
/// must never leak between accounts, so all are keyed by the account id:
///
///   * the **checkout draft** — the form input, saved on every keystroke and
///     pre-filled on reopen, cleared only after a confirmed successful
///     submission. A failed submit keeps it, because retyping a TrxID is exactly
///     the kind of loss this is here to prevent;
///   * the **local submission log** — the timestamps of this account's accepted
///     submissions, used purely as a **UX** best-effort check of the 5-per-24h
///     rule. The authoritative gate is the server's `BEFORE INSERT` trigger, and
///     the client check exists only so the user sees the limit before typing
///     rather than after a round trip;
///   * the **running plan** — the plan key this device last saw the account
///     holding, with the tier it was chosen for, so the side menu's plan row and
///     Manage Plan can still name it with no link (user report, 0.0.683).
///
/// None is firm-shared: a checkout is personal (Addendum), and the running plan
/// is this account's own even when the chamber pays for it.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/providers/repository_providers.dart';
import '../../../shared/providers/shared_preferences_provider.dart';
import '../../accounts_and_profile/data/account_mode.dart'
    show accountCacheUserIdProvider, currentTierProvider, firmMemberProvider;
import '../../auth/presentation/auth_viewmodel.dart' show authIdentityProvider;
import 'payment_plans.dart';
import 'payment_repository.dart';

/// The window the local submission check counts over.
const Duration paymentSubmissionWindow = Duration(hours: 24);

/// How many submissions the local check allows in [paymentSubmissionWindow].
///
/// The server's trigger holds the same number; this copy is UX only.
const int paymentLocalSubmissionLimit = 5;

/// Preference key for the checkout draft, scoped to one account.
String paymentDraftKey(String userId) => 'payment_draft_$userId';

/// Preference key for the local submission log, scoped to one account.
String paymentSubmissionLogKey(String userId) =>
    'payment_submission_log_$userId';

/// The checkout form's saved state.
class PaymentDraft {
  /// Creates a draft.
  const PaymentDraft({
    this.planKey,
    this.method,
    this.phone = '',
    this.trx = '',
  });

  /// The plan the draft was entered for (`monthly`/`annual`), or null.
  final String? planKey;

  /// The selected MFS provider, or null.
  final String? method;

  /// The sender phone as typed.
  final String phone;

  /// The transaction id as typed.
  final String trx;

  /// True when there is nothing worth restoring.
  bool get isEmpty =>
      (planKey ?? '').isEmpty &&
      (method ?? '').isEmpty &&
      phone.isEmpty &&
      trx.isEmpty;

  /// A JSON map for [SharedPreferences].
  Map<String, dynamic> toJson() => <String, dynamic>{
    'planKey': planKey,
    'method': method,
    'phone': phone,
    'trx': trx,
  };

  /// Reads a draft from a stored JSON map, tolerating a missing/old shape.
  static PaymentDraft fromJson(Map<String, dynamic> json) => PaymentDraft(
    planKey: json['planKey'] as String?,
    method: json['method'] as String?,
    phone: (json['phone'] as String?) ?? '',
    trx: (json['trx'] as String?) ?? '',
  );
}

/// The current account's checkout draft, backed by [SharedPreferences].
class PaymentDraftNotifier extends Notifier<PaymentDraft> {
  late final SharedPreferences _prefs;

  @override
  PaymentDraft build() {
    _prefs = ref.watch(sharedPreferencesProvider);
    ref.watch(authIdentityProvider); // rebuild when the account changes
    final raw = _prefs.getString(paymentDraftKey(_userId));
    if (raw == null) return const PaymentDraft();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return PaymentDraft.fromJson(decoded);
      }
    } on FormatException {
      // A corrupt draft is simply no draft.
    }
    return const PaymentDraft();
  }

  String get _userId => ref.read(accountCacheUserIdProvider);

  /// Persists [draft]. Called on every keystroke, so it stays cheap.
  Future<void> save(PaymentDraft draft) async {
    await _prefs.setString(
      paymentDraftKey(_userId),
      jsonEncode(draft.toJson()),
    );
    state = draft;
  }

  /// Removes the draft. Only a confirmed successful submission does this.
  Future<void> clear() async {
    await _prefs.remove(paymentDraftKey(_userId));
    state = const PaymentDraft();
  }
}

/// The current account's checkout draft.
final paymentDraftProvider =
    NotifierProvider<PaymentDraftNotifier, PaymentDraft>(
      PaymentDraftNotifier.new,
    );

/// This account's accepted-submission timestamps (epoch ms), newest first.
class PaymentSubmissionLogNotifier extends Notifier<List<int>> {
  late final SharedPreferences _prefs;

  @override
  List<int> build() {
    _prefs = ref.watch(sharedPreferencesProvider);
    ref.watch(authIdentityProvider);
    final raw = _prefs.getStringList(paymentSubmissionLogKey(_userId));
    return raw?.map(int.tryParse).whereType<int>().toList(growable: false) ??
        const <int>[];
  }

  String get _userId => ref.read(accountCacheUserIdProvider);

  /// Records one accepted submission at [at].
  Future<void> record(DateTime at) async {
    final next = <int>[at.millisecondsSinceEpoch, ...state];
    await _prefs.setStringList(
      paymentSubmissionLogKey(_userId),
      next.map((e) => e.toString()).toList(growable: false),
    );
    state = next;
  }
}

/// The current account's accepted-submission timestamps.
final paymentSubmissionLogProvider =
    NotifierProvider<PaymentSubmissionLogNotifier, List<int>>(
      PaymentSubmissionLogNotifier.new,
    );

/// The number of [timestamps] inside the [paymentSubmissionWindow] before [now].
///
/// Pure, so the UX rule can be unit-tested without a store.
int localSubmissionsInWindow(List<int> timestamps, DateTime now) {
  final cutoff = now.subtract(paymentSubmissionWindow).millisecondsSinceEpoch;
  return timestamps.where((t) => t > cutoff).length;
}

/// Whether the local best-effort check should warn the user off submitting.
bool isLocallyRateLimited(List<int> timestamps, DateTime now) =>
    localSubmissionsInWindow(timestamps, now) >= paymentLocalSubmissionLimit;

/// The plan this device last saw running, and the tier it was chosen for.
///
/// A record, so two copies compare by value: the cache below skips a write it
/// already holds.
typedef RunningPlan = ({String planKey, SubscriptionTier tier});

/// Preference key for the running plan's own key, scoped to one account.
String runningPlanKeyCacheKey(String userId) => 'running_plan_$userId';

/// Preference key for the tier the cached running plan was chosen for.
String runningPlanTierCacheKey(String userId) => 'running_plan_tier_$userId';

/// The plan this device last saw running for the current account, or null.
///
/// `payment_submissions` is server-managed and read live, so with no link the
/// ledger cannot name a plan and the label fell back to the generic *Premium* —
/// a premium user offline was never told which plan they hold (user report).
/// This keeps one copy, written by every successful ledger read.
///
/// The **tier** is stored beside the key because it is what makes the copy safe
/// to show: [currentPlanProvider] prints it only while the cached profile or
/// firm row still holds that same tier, so a downgrade that has already started
/// can never leave the old plan's name on screen.
final runningPlanCacheProvider =
    NotifierProvider<RunningPlanCacheNotifier, RunningPlan?>(
      RunningPlanCacheNotifier.new,
    );

/// Mirrors the running plan into preferences and reads it back.
///
/// The write happens in [build], which re-runs whenever the ledger, the stored
/// tier or the account changes — so every successful read refreshes the copy, a
/// read that names no plan clears it, and an offline build leaves it untouched.
class RunningPlanCacheNotifier extends Notifier<RunningPlan?> {
  @override
  RunningPlan? build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final userId = ref.watch(accountCacheUserIdProvider);
    final ledger = ref.watch(myPaymentSubmissionsProvider);
    // A chamber member's plan is the chamber's, and the ledger does not name
    // it. Their own rows are deliberately not remembered (current_plan.dart).
    if (ref.watch(firmMemberProvider)) return null;
    // No answer yet (offline, or the first read still in flight): keep the copy.
    if (!ledger.hasValue) return _readRunningPlan(prefs, userId);

    final plan = _resolveRunningPlan(
      ledger.value!,
      ref.watch(currentTierProvider),
    );
    if (_readRunningPlan(prefs, userId) != plan) {
      unawaited(_writeRunningPlan(prefs, userId, plan));
    }
    return plan;
  }

  RunningPlan? _resolveRunningPlan(
    Iterable<PaymentSubmission> submissions,
    SubscriptionTier tier,
  ) {
    final key = runningPlanKey(
      submissions
          .where((row) => row.status == 'approved')
          .map((row) => row.planType),
      tier,
    );
    return key == null ? null : (planKey: key, tier: tier);
  }

  RunningPlan? _readRunningPlan(SharedPreferences prefs, String userId) {
    final planKey = prefs.getString(runningPlanKeyCacheKey(userId));
    final tierKey = prefs.getString(runningPlanTierCacheKey(userId));
    if (planKey == null || tierKey == null) return null;
    return (planKey: planKey, tier: SubscriptionTier.fromKey(tierKey));
  }

  Future<void> _writeRunningPlan(
    SharedPreferences prefs,
    String userId,
    RunningPlan? plan,
  ) async {
    if (plan == null) {
      await prefs.remove(runningPlanKeyCacheKey(userId));
      await prefs.remove(runningPlanTierCacheKey(userId));
      return;
    }
    await prefs.setString(runningPlanKeyCacheKey(userId), plan.planKey);
    await prefs.setString(runningPlanTierCacheKey(userId), plan.tier.key);
  }
}
