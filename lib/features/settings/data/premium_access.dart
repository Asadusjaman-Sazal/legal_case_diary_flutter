/// Premium entitlement, derived in exactly one place (plan §6).
///
/// Entitlement is **always computed**, never read from a stored status flag:
/// nothing fires at the expiry instant to flip `subscription_status`, so a flag
/// inevitably goes stale. The rule is `subscription_expiry + 48h grace > now()`
/// — the same rule the server applies in RLS and the `push_changes` RPC.
///
/// This moved here from `add_edit_case_sheet.dart` when Task 15 Phase 6 needed
/// the same answer outside the Add Case form (the monthly nudge is for free
/// users only). Task 21 swaps the body and no call site changes — which is only
/// true if there really is one function, in a file a non-UI caller can import.
library;

import '../../accounts_and_profile/data/local/firms_dao.dart';
import '../../accounts_and_profile/data/local/profiles_dao.dart';
import '../../../database/app_database.dart';
import '../../../sync/sync_metadata_dao.dart';

/// Resolves premium entitlement from the cached subscription expiry.
///
/// Individual users use their profile expiry. Firm users use the firm's
/// mirrored expiry, which is the source of truth for all associates. The
/// 48-hour grace period is intentionally applied here rather than trusting the
/// display-only subscription status flag.
///
/// **Clock skew (Task 21 Phase 3 item 4):** the local check uses device time and
/// is UX only — the server's `now()` and the RLS/`push_changes` checks remain the
/// security boundary. To reduce false banners, the recorded offset (Task 18
/// Phase 3, stored as `server - device`) is applied, so a device clock that is
/// ahead cannot wrongly expire a subscription still inside its grace window. An
/// offset of 0 (no successful sync yet) is a no-op, and an explicit [now] is
/// still treated as device time and corrected the same way.
Future<bool> resolvePremiumAccess(
  AppDatabase db,
  String userId, {
  DateTime? now,
}) async {
  final profile = await ProfilesDao(db).getById(userId);
  final expiry = profile?.firmId == null
      ? profile?.subscriptionExpiry
      : (await FirmsDao(db).getById(profile!.firmId!))?.subscriptionExpiry;
  if (expiry == null) return false;
  final offsetMs =
      await SyncMetadataDao(db).getIntValue(clockOffsetMsKey) ?? 0;
  final serverNow = (now ?? DateTime.now())
      .toUtc()
      .add(Duration(milliseconds: offsetMs));
  final graceExpiry = DateTime.fromMillisecondsSinceEpoch(
    expiry,
    isUtc: true,
  ).add(const Duration(hours: 48));
  return graceExpiry.isAfter(serverNow);
}
