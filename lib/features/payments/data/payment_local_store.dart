/// Per-user local payments state: the checkout draft and the submission log.
///
/// Task 21 Phase 2 / Addendum. Two things must survive closing the app and must
/// never leak between accounts, so both are keyed by the account id:
///
///   * the **checkout draft** — the form input, saved on every keystroke and
///     pre-filled on reopen, cleared only after a confirmed successful
///     submission. A failed submit keeps it, because retyping a TrxID is exactly
///     the kind of loss this is here to prevent;
///   * the **local submission log** — the timestamps of this account's accepted
///     submissions, used purely as a **UX** best-effort check of the 5-per-24h
///     rule. The authoritative gate is the server's `BEFORE INSERT` trigger, and
///     the client check exists only so the user sees the limit before typing
///     rather than after a round trip.
///
/// Neither is firm-shared: a checkout is personal (Addendum).
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/providers/shared_preferences_provider.dart';
import '../../accounts_and_profile/data/account_mode.dart'
    show accountCacheUserIdProvider;
import '../../auth/presentation/auth_viewmodel.dart' show authIdentityProvider;

/// The window the local submission check counts over.
const Duration paymentSubmissionWindow = Duration(hours: 24);

/// How many submissions the local check allows in [paymentSubmissionWindow].
///
/// The server's trigger holds the same number; this copy is UX only.
const int paymentLocalSubmissionLimit = 5;

/// Preference key for the checkout draft, scoped to one account.
String paymentDraftKey(String userId) => 'payment_draft_$userId';

/// Preference key for the local submission log, scoped to one account.
String paymentSubmissionLogKey(String userId) => 'payment_submission_log_$userId';

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
      if (decoded is Map<String, dynamic>) return PaymentDraft.fromJson(decoded);
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
    return raw
            ?.map(int.tryParse)
            .whereType<int>()
            .toList(growable: false) ??
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
