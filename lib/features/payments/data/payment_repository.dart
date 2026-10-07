/// Payments repository: submits an MFS payment and reads this account's history.
///
/// Task 21 Phase 2. `payment_submissions` is a **server-managed** table
/// (AGENTS.md rule 4): it is never queued, never domain-synced, and the client
/// only ever INSERTs its own row and SELECTs its own rows under RLS. Two rules
/// the server owns and this file must not fight:
///
///   * `submitted_at` is server-assigned — a `BEFORE INSERT` trigger overwrites
///     any client value and the 3-per-24h limit counts it, so it is **never**
///     sent;
///   * approval is **only** the admin `approve_payment` RPC (Task 16) — there is
///     no client update path here, and there never should be.
library;

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/error_log.dart';

/// Why a submission could not be accepted.
enum PaymentSubmitFailure {
  /// The server's 3-per-24h trigger refused it.
  limitReached,

  /// The TrxID was already used (the unique constraint).
  duplicateTransaction,

  /// The request never reached the server.
  network,

  /// Anything else the server refused.
  other,
}

/// A typed submission failure, so the view model can word it honestly.
class PaymentSubmitException implements Exception, DiagnosableFailure {
  /// Creates a failure of [kind].
  const PaymentSubmitException(this.kind, {this.detail});

  /// The category the checkout renders.
  final PaymentSubmitFailure kind;

  /// Optional server detail, for diagnostics only — never shown raw by a
  /// screen, but kept as the log's detail line.
  final String? detail;

  /// The log's label: the kind, never [detail], which is a raw server text.
  @override
  String get diagnosticLabel => 'PaymentSubmitException(${kind.name})';

  /// The log's detail: the server's reply, which is what a reader fixes from.
  @override
  String? get diagnosticDetail => detail;

  @override
  String toString() => 'PaymentSubmitException($kind)';
}

/// One row of this account's payment history, as the app reads it back.
class PaymentSubmission {
  /// Creates a submission.
  const PaymentSubmission({
    required this.id,
    required this.planType,
    required this.amount,
    required this.mfsProvider,
    required this.senderNumber,
    required this.transactionId,
    required this.status,
    this.adminNotes,
    this.submittedAt,
    this.approvedAt,
  });

  /// Server id.
  final String id;

  /// `monthly` or `annual`.
  final String planType;

  /// The amount paid, in BDT.
  final int amount;

  /// `bkash`, `nagad` or `rocket`.
  final String mfsProvider;

  /// The number the money was sent from.
  final String senderNumber;

  /// The TrxID reported by the user.
  final String transactionId;

  /// `pending`, `approved` or `rejected`.
  final String status;

  /// The reviewer's note, present on a rejection usually.
  final String? adminNotes;

  /// The authoritative server submission time.
  final DateTime? submittedAt;

  /// When the admin approved it; null until then.
  final DateTime? approvedAt;

  /// Reads a PostgREST row.
  static PaymentSubmission fromRow(Map<String, dynamic> row) {
    final submitted = row['submitted_at'];
    final approved = row['approved_at'];
    return PaymentSubmission(
      id: row['id'] as String,
      planType: (row['plan_type'] as String?) ?? '',
      amount: (row['amount'] as num?)?.toInt() ?? 0,
      mfsProvider: (row['mfs_provider'] as String?) ?? '',
      senderNumber: (row['sender_number'] as String?) ?? '',
      transactionId: (row['transaction_id'] as String?) ?? '',
      status: (row['status'] as String?) ?? 'pending',
      adminNotes: row['admin_notes'] as String?,
      submittedAt: submitted is String ? DateTime.tryParse(submitted) : null,
      approvedAt: approved is String ? DateTime.tryParse(approved) : null,
    );
  }
}

/// The payments data boundary.
abstract class PaymentRepository {
  /// Submits one payment for [userId].
  ///
  /// Throws [PaymentSubmitException] on any refusal so the caller can word it.
  Future<void> submit({
    required String userId,
    required String planType,
    required int amount,
    required String mfsProvider,
    required String senderNumber,
    required String transactionId,
  });

  /// This account's own submissions, newest first.
  Future<List<PaymentSubmission>> fetchMySubmissions();
}

/// The real repository: PostgREST against `payment_submissions`.
class SupabasePaymentRepository implements PaymentRepository {
  /// Creates the repository over [client].
  SupabasePaymentRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<void> submit({
    required String userId,
    required String planType,
    required int amount,
    required String mfsProvider,
    required String senderNumber,
    required String transactionId,
  }) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    try {
      await _client.from('payment_submissions').insert(<String, dynamic>{
        'user_id': userId,
        'plan_type': planType,
        'amount': amount,
        'mfs_provider': mfsProvider,
        'sender_number': senderNumber,
        'transaction_id': transactionId,
        // Display metadata only; `submitted_at` is deliberately absent because
        // the server assigns it and rejects anything the client sends.
        'created_at': nowMs,
        'updated_at': nowMs,
      });
    } on PostgrestException catch (error) {
      if (error.message.contains('payment_submission_limit_reached')) {
        throw const PaymentSubmitException(PaymentSubmitFailure.limitReached);
      }
      if (error.code == '23505') {
        throw const PaymentSubmitException(
          PaymentSubmitFailure.duplicateTransaction,
          detail: 'transaction_id',
        );
      }
      throw PaymentSubmitException(
        PaymentSubmitFailure.other,
        detail: error.message,
      );
    } on Object catch (error) {
      // A refused connection, a DNS failure, a socket error: nothing reached the
      // server, so the draft must stay and the user may retry.
      throw PaymentSubmitException(
        PaymentSubmitFailure.network,
        detail: error.toString(),
      );
    }
  }

  @override
  Future<List<PaymentSubmission>> fetchMySubmissions() async {
    final rows = await _client
        .from('payment_submissions')
        .select()
        .order('submitted_at', ascending: false);
    return rows
        .map(Map<String, dynamic>.from)
        .map(PaymentSubmission.fromRow)
        .toList(growable: false);
  }
}

/// A repository for a build with no backend: every submit is a network failure.
class UnavailablePaymentRepository implements PaymentRepository {
  /// Creates the inert repository.
  const UnavailablePaymentRepository();

  @override
  Future<void> submit({
    required String userId,
    required String planType,
    required int amount,
    required String mfsProvider,
    required String senderNumber,
    required String transactionId,
  }) async {
    throw const PaymentSubmitException(PaymentSubmitFailure.network);
  }

  @override
  Future<List<PaymentSubmission>> fetchMySubmissions() async =>
      const <PaymentSubmission>[];
}
