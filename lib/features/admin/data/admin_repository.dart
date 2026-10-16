/// The admin panel's data boundary: who the caller is, the submissions they
/// may see, and the two actions they may take.
///
/// Task 22. Every read and write here goes through a **server-side RPC** rather
/// than a table query, and that is the whole design. `app_admins`,
/// `payment_submissions` and `profiles` all have RLS that keeps a client inside
/// its own account, and none of them is widened for the panel: the panel asks
/// `is_app_admin()` whether it is allowed, then asks
/// `admin_list_payment_submissions()` for the work, and the server decides
/// whether to answer. A client that skipped those calls could read nothing,
/// because the policies already refuse it.
///
/// Approval reuses the existing `approve_payment` RPC unchanged — it was already
/// admin-gated and already writes its own immutable audit event. Rejection is
/// `admin_reject_payment`, added alongside it.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

/// Why an admin action could not be completed.
///
/// These are the server's own answers, not guesses: `approve_payment` and
/// `admin_reject_payment` each return a `status` string and this maps it to one
/// thing the screen can word.
enum AdminActionFailure {
  /// The caller is not an admin, so the server refused the call outright.
  notAnAdmin,

  /// The submission no longer exists.
  notFound,

  /// It was already approved or already rejected; nothing was changed.
  alreadyResolved,

  /// The account signed up too recently to be treated as abandoned — the
  /// Non-verified Accounts page hides and refuses anything younger than its
  /// 72-hour window, so this only reaches the screen from a stale list.
  tooRecent,

  /// The network or the server failed in a way the caller cannot classify.
  unexpected,
}

/// One payment submission, with the payer it belongs to.
class AdminPaymentRequest {
  /// Creates a request.
  const AdminPaymentRequest({
    required this.id,
    required this.userId,
    required this.planKey,
    required this.amount,
    required this.mfsProvider,
    required this.senderNumber,
    required this.transactionId,
    required this.status,
    required this.submittedAt,
    this.adminNotes,
    this.approvedAt,
    this.approvedBy,
    this.rejectedAt,
    this.rejectedBy,
    this.approvedNewExpiry,
    this.fullName = '',
    this.email = '',
    this.barAssociation = '',
    this.membershipNo = '',
    this.mobileNo = '',
  });

  /// The submission's own id, which both actions take.
  final String id;

  /// The paying account.
  final String userId;

  /// The plan key of the ladder's ten (`monthly` … `firm_plus_annual`).
  ///
  /// Stored as submitted, so a row from before the ten-plan ladder keeps the key
  /// it was submitted under rather than being read as a plan it never bought.
  final String planKey;

  /// The amount submitted, which the server validates exactly.
  final int amount;

  /// `bkash`, `nagad` or `rocket`.
  final String mfsProvider;

  /// The number the sender paid from.
  final String senderNumber;

  /// The TrxID the payer quoted.
  final String transactionId;

  /// `pending`, `approved` or `rejected`.
  final String status;

  /// Server submission time.
  final DateTime? submittedAt;

  /// The admin's note, set by a rejection.
  final String? adminNotes;

  /// When it was approved, if it was.
  final DateTime? approvedAt;

  /// Which admin approved it.
  final String? approvedBy;

  /// When it was rejected, if it was.
  final DateTime? rejectedAt;

  /// Which admin rejected it.
  final String? rejectedBy;

  /// The entitlement that THIS approval set, from the immutable event — not the
  /// account's current expiry, which may have moved on since.
  final DateTime? approvedNewExpiry;

  /// The payer's own name from their profile.
  final String fullName;

  /// The payer's email from their profile.
  final String email;

  /// The payer's bar association from their profile.
  final String barAssociation;

  /// The payer's bar membership number from their profile.
  final String membershipNo;

  /// The payer's mobile number from their profile.
  final String mobileNo;

  /// True while the submission still awaits a decision.
  bool get isPending => status == 'pending';

  /// True once it has been approved or rejected.
  bool get isResolved => !isPending;

  /// Reads one row of `admin_list_payment_submissions()`'s jsonb array.
  factory AdminPaymentRequest.fromJson(Map<String, dynamic> json) =>
      AdminPaymentRequest(
        id: json['id'] as String? ?? '',
        userId: json['user_id'] as String? ?? '',
        planKey: json['plan_type'] as String? ?? '',
        amount: (json['amount'] as num?)?.toInt() ?? 0,
        mfsProvider: json['mfs_provider'] as String? ?? '',
        senderNumber: json['sender_number'] as String? ?? '',
        transactionId: json['transaction_id'] as String? ?? '',
        status: json['status'] as String? ?? 'pending',
        adminNotes: json['admin_notes'] as String?,
        submittedAt: _instant(json['submitted_at']),
        approvedAt: _instant(json['approved_at']),
        approvedBy: json['approved_by'] as String?,
        rejectedAt: _instant(json['rejected_at']),
        rejectedBy: json['rejected_by'] as String?,
        approvedNewExpiry: _instant(json['approved_new_expiry']),
        fullName: json['full_name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        barAssociation: json['bar_association'] as String? ?? '',
        membershipNo: json['membership_no'] as String? ?? '',
        mobileNo: json['mobile_no'] as String? ?? '',
      );

  static DateTime? _instant(Object? value) => value is String
      ? DateTime.tryParse(value)?.toLocal()
      : null;
}

/// One account that signed up but never confirmed its address.
///
/// Invisible to every client — `email_confirmed_at` lives in `auth.users`, which
/// no client may read — so it arrives only from the admin-gated
/// `admin_list_unconfirmed_accounts()`.
class AdminUnconfirmedAccount {
  /// Creates an account row.
  const AdminUnconfirmedAccount({
    required this.id,
    required this.email,
    required this.fullName,
    this.createdAt,
    this.lastSignInAt,
    this.canDelete = false,
  });

  /// The account's `auth.users` id.
  final String id;

  /// The address it signed up with.
  final String email;

  /// The account holder's name from their profile (empty until they fill it in).
  final String fullName;

  /// When the account was created.
  final DateTime? createdAt;

  /// The last sign-in, if there ever was one — an unconfirmed account cannot
  /// sign in, so this is normally null and is shown only when it is not.
  final DateTime? lastSignInAt;

  /// Whether the server would allow removing it: true only while it is
  /// **provisional** — unconfirmed and having done nothing at all.
  final bool canDelete;

  /// Reads one row of `admin_list_unconfirmed_accounts()`'s jsonb array.
  factory AdminUnconfirmedAccount.fromJson(Map<String, dynamic> json) =>
      AdminUnconfirmedAccount(
        id: json['id'] as String? ?? '',
        email: json['email'] as String? ?? '',
        fullName: json['full_name'] as String? ?? '',
        createdAt: AdminPaymentRequest._instant(json['created_at']),
        lastSignInAt: AdminPaymentRequest._instant(json['last_sign_in_at']),
        canDelete: json['can_delete'] as bool? ?? false,
      );
}

/// The Non-verified Accounts page's age window, in hours. An unconfirmed
/// sign-up younger than this is still expected to confirm, so the server neither
/// lists it nor deletes it; named here only so the UI can word the same number.
const int adminUnconfirmedMinAgeHours = 72;

/// The admin panel's data boundary.
abstract class AdminRepository {
  /// Whether the signed-in account is a registered admin.
  ///
  /// False whenever there is no backend or nobody is signed in, so a caller can
  /// never mistake an unreachable server for an admin session.
  Future<bool> isAdmin();

  /// Every submission, newest first.
  Future<List<AdminPaymentRequest>> listPaymentRequests();

  /// Approves [submissionId]; returns null on success or why it was refused.
  Future<AdminActionFailure?> approve(String submissionId);

  /// Rejects [submissionId] with [note]; returns null on success or why not.
  Future<AdminActionFailure?> reject(String submissionId, {String? note});

  /// Every account that never confirmed its address, at least
  /// [adminUnconfirmedMinAgeHours] hours old, newest first.
  Future<List<AdminUnconfirmedAccount>> listUnconfirmedAccounts();

  /// Removes the unconfirmed account [userId]; null on success, else why not.
  Future<AdminActionFailure?> deleteUnconfirmedAccount(String userId);
}

/// Talks to the three admin RPCs.
class SupabaseAdminRepository implements AdminRepository {
  /// Creates a repository over [client].
  SupabaseAdminRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<bool> isAdmin() async {
    try {
      final response = await _client.rpc('is_app_admin');
      return response == true;
    } on Object {
      // An unreachable server, or an account with no JWT yet. Either way this
      // is not an admin session, and the panel must stay hidden.
      return false;
    }
  }

  @override
  Future<List<AdminPaymentRequest>> listPaymentRequests() async {
    final response = await _client.rpc('admin_list_payment_submissions');
    if (response is! List) return const <AdminPaymentRequest>[];
    return response
        .whereType<Map<String, dynamic>>()
        .map(AdminPaymentRequest.fromJson)
        .toList(growable: false);
  }

  @override
  Future<AdminActionFailure?> approve(String submissionId) async {
    try {
      final response = await _client.rpc(
        'approve_payment',
        params: <String, dynamic>{'payment_submission_id': submissionId},
      );
      return _failureFrom(response);
    } on Object catch (error) {
      return _failureFromError(error);
    }
  }

  @override
  Future<AdminActionFailure?> reject(String submissionId, {String? note}) async {
    try {
      final response = await _client.rpc(
        'admin_reject_payment',
        params: <String, dynamic>{
          'payment_submission_id': submissionId,
          'rejection_note': note,
        },
      );
      return _failureFrom(response);
    } on Object catch (error) {
      return _failureFromError(error);
    }
  }

  @override
  Future<List<AdminUnconfirmedAccount>> listUnconfirmedAccounts() async {
    final response = await _client.rpc('admin_list_unconfirmed_accounts');
    if (response is! List) return const <AdminUnconfirmedAccount>[];
    return response
        .whereType<Map<String, dynamic>>()
        .map(AdminUnconfirmedAccount.fromJson)
        .toList(growable: false);
  }

  @override
  Future<AdminActionFailure?> deleteUnconfirmedAccount(String userId) async {
    try {
      final response = await _client.rpc(
        'admin_delete_unconfirmed_account',
        params: <String, dynamic>{'p_user_id': userId},
      );
      return _failureFromErrorless(response);
    } on Object catch (error) {
      return _failureFromError(error);
    }
  }

  /// Maps the delete RPC's own `status`/`reason` to a failure, or null on
  /// success. Unlike the payment actions it answers `removed`, and its refusals
  /// are `not_found`, `confirmed` and `has_activity` — the last two are the
  /// account ceasing to be provisional since the list was read.
  static AdminActionFailure? _failureFromErrorless(Object? response) {
    if (response is! Map) return AdminActionFailure.unexpected;
    if (response['status'] == 'removed') return null;
    return switch (response['reason']) {
      'not_found' => AdminActionFailure.notFound,
      'confirmed' || 'has_activity' => AdminActionFailure.alreadyResolved,
      'too_recent' => AdminActionFailure.tooRecent,
      _ => AdminActionFailure.unexpected,
    };
  }

  /// Maps a successful RPC's own `status` to a failure, or null when it worked.
  static AdminActionFailure? _failureFrom(Object? response) {
    if (response is! Map) return AdminActionFailure.unexpected;
    return switch (response['status']) {
      'approved' || 'rejected' => null,
      'not_found' => AdminActionFailure.notFound,
      'already_resolved' || 'already_approved' =>
        AdminActionFailure.alreadyResolved,
      'invalid_plan' || 'invalid_amount' => AdminActionFailure.unexpected,
      _ => AdminActionFailure.unexpected,
    };
  }

  /// The admin gate raises rather than returning, so a refusal arrives here as
  /// an exception carrying the server's message.
  static AdminActionFailure _failureFromError(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('admin_required')) return AdminActionFailure.notAnAdmin;
    if (message.contains('not_found')) return AdminActionFailure.notFound;
    return AdminActionFailure.unexpected;
  }
}

/// The boundary when this build has no backend, or nobody is signed in.
///
/// It reports "not an admin" rather than an error, because that is the truth from
/// the panel's point of view: there is nothing here to administer.
class UnavailableAdminRepository implements AdminRepository {
  /// Creates the inert repository.
  const UnavailableAdminRepository();

  @override
  Future<bool> isAdmin() async => false;

  @override
  Future<List<AdminPaymentRequest>> listPaymentRequests() async =>
      const <AdminPaymentRequest>[];

  @override
  Future<AdminActionFailure?> approve(String submissionId) async =>
      AdminActionFailure.notAnAdmin;

  @override
  Future<AdminActionFailure?> reject(
    String submissionId, {
    String? note,
  }) async => AdminActionFailure.notAnAdmin;

  @override
  Future<List<AdminUnconfirmedAccount>> listUnconfirmedAccounts() async =>
      const <AdminUnconfirmedAccount>[];

  @override
  Future<AdminActionFailure?> deleteUnconfirmedAccount(String userId) async =>
      AdminActionFailure.notAnAdmin;
}
