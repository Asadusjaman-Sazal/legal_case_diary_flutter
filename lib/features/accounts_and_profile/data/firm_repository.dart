/// Firm repository: the owner-side invite primitives and the associate-side
/// redemption.
///
/// Firm administration is **online-only** by rule: an invite cannot be created,
/// revoked or redeemed while off the network, because every one of those
/// operations is a server-side decision (a hash match in `firm_invites`, a
/// rate-limit counter in `invite_attempts`, a `firm_members` row under RLS).
/// Nothing here is ever queued locally.
///
/// Two secrets shape the design:
///
/// * the **plaintext invite code** exists only in the owner's hands and in the
///   associate's form. Only its SHA-256 hash is ever written to the server, and
///   nothing here logs the plaintext;
/// * an **associate cannot read `firm_invites`** before membership, so
///   redemption can only go through the `SECURITY DEFINER` `join_firm(code)`
///   RPC, which also rate-limits and consumes the code in one transaction.
///
/// The pieces that decide whether the server would accept a code are **pure
/// functions** — [generateInviteCode], [normalizeInviteCode], [inviteCodeHash],
/// [inviteInsertRow] and [parseInviteRedemption] — so the entropy rule, the hash
/// rule and the used/revoked rule are each tested without a server, and the
/// network methods below are one call each over them.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/error_log.dart';
import '../../../core/errors/error_log_provider.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../sync/connectivity_monitor.dart';
import 'profile_repository.dart' show AccountRole;

/// Crockford Base32: 32 symbols, and deliberately without `I`, `L`, `O` and `U`
/// — the four characters a hand-written or phone-read code confuses with `1`,
/// `0` and `V`.
const String inviteCodeAlphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

/// Ten symbols at five bits each: exactly the **50 bits** of entropy Task 17
/// Phase 5 requires, and no longer than a code someone can read out loud.
const int inviteCodeLength = 10;

/// A fresh invite code from a cryptographic source.
///
/// Every symbol is drawn independently and uniformly from
/// [inviteCodeAlphabet], so the code space is `32^10 = 2^50` — the entropy
/// requirement is a property of the length and the alphabet, not of the
/// randomness being "good enough". [random] exists for tests only; production
/// callers take the default `Random.secure()`.
String generateInviteCode({Random? random}) {
  final source = random ?? Random.secure();
  final buffer = StringBuffer();
  for (var index = 0; index < inviteCodeLength; index++) {
    buffer.write(inviteCodeAlphabet[source.nextInt(inviteCodeAlphabet.length)]);
  }
  return buffer.toString();
}

/// The normalization the server applies, applied here first.
///
/// `join_firm` hashes `upper(btrim(code))`, so a code typed in lower case or
/// with a stray space redeems to the same row. Nothing else is folded — no
/// `O`→`0` guessing — because the client's hash has to equal the server's
/// exactly; a correction the server does not make would produce a code that
/// never matches.
String normalizeInviteCode(String code) => code.trim().toUpperCase();

/// The SHA-256 hex of [code], in the same shape as `public.sha256_hex`.
String inviteCodeHash(String code) =>
    sha256.convert(utf8.encode(normalizeInviteCode(code))).toString();

/// The one row a new invite writes to the server.
///
/// The plaintext code is **not** in this map, and this map is the only object
/// that reaches `firm_invites` — which is what "insert only its SHA-256 hash"
/// means in practice. `id`, `used_by`, `used_at` and `revoked` are left to the
/// table's own defaults.
Map<String, dynamic> inviteInsertRow({
  required String firmId,
  required String code,
  required String createdBy,
  required int createdAt,
}) => <String, dynamic>{
  'firm_id': firmId,
  'code_hash': inviteCodeHash(code),
  'created_by': createdBy,
  'created_at': createdAt,
};

/// A `returns jsonb` value, whichever shape PostgREST handed back.
///
/// Current builds return a map and older ones a JSON string; both are accepted
/// rather than assumed.
Map<String, dynamic> decodeRpcMap(Object? response) {
  if (response is Map) return response.cast<String, dynamic>();
  if (response is String) {
    final decoded = jsonDecode(response);
    if (decoded is Map) return decoded.cast<String, dynamic>();
  }
  return const <String, dynamic>{};
}

/// How a redemption ended.
enum InviteRedemptionStatus {
  /// The account is now a member of the firm.
  joined,

  /// The account was already a member; the code was retired as revoked rather
  /// than consumed, so the owner's list does not read *used* for a member who
  /// was already in the chamber.
  alreadyMember,
}

/// A redeemed invite.
class InviteRedemption {
  /// Creates a redemption result.
  const InviteRedemption({required this.status, this.firmId});

  /// What the server reported.
  final InviteRedemptionStatus status;

  /// The firm the account now belongs to, when the server reported one.
  final String? firmId;

  /// Whether the account is a member of the firm after this call.
  bool get isMember => true;
}

/// A redemption the server refused, with the number the refusal has to word.
///
/// Both of §2's seat refusals quote a count — "its own diary (N cases)" and how
/// many seats the tier sells — so the count travels with the failure rather than
/// being a second round trip the client cannot make anyway (an associate cannot
/// read `firms` or another account's diary).
class InviteRefusal implements Exception, DiagnosableFailure {
  /// Creates a refusal of [kind].
  const InviteRefusal(this.kind, {this.count});

  /// Which refusal this is.
  final InviteRefusalKind kind;

  /// The number the sentence quotes: cases in the account's own diary, or the
  /// chamber's seat cap. Null when the refusal does not quote one.
  final int? count;

  /// The log's label: the kind, so entries stay scannable and comparable.
  @override
  String get diagnosticLabel => 'InviteRefusal(${kind.name})';

  /// Nothing beyond the kind is logged: the number is user-facing copy, and the
  /// refusal is never a diagnostic event.
  @override
  String? get diagnosticDetail => null;

  @override
  String toString() => diagnosticLabel;
}

/// The seat refusals `join_firm` returns as statuses.
enum InviteRefusalKind {
  /// The redeemer already keeps their own diary, so the seat is not empty. The
  /// refusal is never silent and never merges: the count is shown and the account
  /// is left exactly as it was.
  ownDiary,

  /// The chamber's effective tier sells fewer seats than it has live members.
  seatsFull,
}

/// An invite that was just created on the server.
///
/// [code] is the **plaintext**, returned exactly once and never written
/// anywhere: there is no cache, no preference and no log line holding it, and
/// [toString] deliberately omits it so an accidental interpolation cannot leak
/// it either.
class GeneratedInvite {
  /// Creates a generated invite.
  const GeneratedInvite({
    required this.code,
    required this.inviteId,
    required this.firmId,
  });

  /// The plaintext code, for the owner to read out once.
  final String code;

  /// The `firm_invites.id` the code was stored under, used to revoke it.
  final String inviteId;

  /// The firm the code invites into.
  final String firmId;

  /// Never prints the code.
  @override
  String toString() => 'GeneratedInvite($inviteId)';
}

/// Reads a `join_firm`/`ensure_firm` response into its typed outcome.
///
/// Public and pure so the mapping the tests pin is the mapping the app runs: a
/// used code and a revoked one both arrive as `invalid_code` — `join_firm` only
/// matches an unused, unrevoked row, so the client cannot and must not try to
/// tell them apart.
///
/// The two seat refusals arrive as statusses rather than errors, with the count
/// the sentence needs. They are **not** `FirmFailure`s: nothing went wrong, and
/// the account is untouched, so a screen that shows them as an error banner
/// would read as a system fault where the message is really advice.
InviteRedemption parseInviteRedemption(Object? response) {
  final result = decodeRpcMap(response);
  return switch (result['status']) {
    'joined' => InviteRedemption(
      status: InviteRedemptionStatus.joined,
      firmId: result['firm_id'] as String?,
    ),
    'already_member' => InviteRedemption(
      status: InviteRedemptionStatus.alreadyMember,
      firmId: result['firm_id'] as String?,
    ),
    'has_own_diary' => throw InviteRefusal(
      InviteRefusalKind.ownDiary,
      count: (result['cases'] as num?)?.toInt(),
    ),
    'seats_full' => throw InviteRefusal(
      InviteRefusalKind.seatsFull,
      count: (result['seats'] as num?)?.toInt(),
    ),
    'invalid_code' => throw const FirmFailure(FirmFailureKind.invalidInviteCode),
    // The RPC falls back to a status rather than raising when it cannot see a
    // caller; a redemption always happens signed in, so this is a bug state, not
    // something to explain to the user.
    _ => throw FirmFailure(FirmFailureKind.unknown, cause: result['status'] as String?),
  };
}

/// One member of the caller's firm, as the owner's roster shows them.
///
/// Read live and never cached: `firm_members` and `profiles` are pull-only
/// caches that hold this account's own row (AGENTS.md rule 4), and Manage
/// Associates is an online-only screen, so its roster is a read rather than a
/// second copy of the membership state.
class FirmMemberSummary {
  /// Creates a roster row.
  const FirmMemberSummary({
    required this.userId,
    required this.role,
    required this.fullName,
    required this.canAdd,
    required this.canEdit,
    required this.canDelete,
  });

  /// The member's `auth.users.id`.
  final String userId;

  /// `owner`, `associate` or `viewer`.
  final String role;

  /// The member's display name, blank when the account has none yet.
  final String fullName;

  /// Whether the member may add cases.
  final bool canAdd;

  /// Whether the member may edit cases.
  final bool canEdit;

  /// Whether the member may delete cases directly instead of raising a request.
  final bool canDelete;
}

/// An invite that is still outstanding: unused and unrevoked.
///
/// The plaintext code is deliberately **not** here and cannot be: only its
/// SHA-256 hash is stored server-side, so an outstanding invite identifies
/// itself by when it was created and by nothing else (Task 20 Phase 2 item 1).
class FirmInviteSummary {
  /// Creates an outstanding-invite row.
  const FirmInviteSummary({required this.id, required this.createdAt});

  /// The `firm_invites.id`, used to revoke it.
  final String id;

  /// When the code was created, in epoch milliseconds.
  final int createdAt;
}

/// Firm membership operations the app performs.
abstract class FirmRepository {
  /// Redeems [code] for the signed-in account.
  ///
  /// Throws [FirmFailure] with [FirmFailureKind.invalidInviteCode] when the code
  /// matches no unused, unrevoked invite — a revoked code and an already-used
  /// code both surface that way, because the server will not say which — and
  /// with [FirmFailureKind.tooManyAttempts] once the rate limit is hit. Both
  /// leave onboarding retryable.
  Future<InviteRedemption> redeemInvite(String code);

  /// Creates a single-use invite for the caller's own firm.
  ///
  /// Owner-side only: the RLS insert policy requires `created_by = auth.uid()`
  /// and a firm the caller owns. The returned [GeneratedInvite.code] is the one
  /// and only sight of the plaintext. Throws [FirmFailure] with
  /// [FirmFailureKind.firmAdminOffline] when the device has no connection.
  Future<GeneratedInvite> createInvite();

  /// Revokes the unused invite [inviteId].
  ///
  /// RLS restricts this to the firm's owner, and `firm_invites` has no DELETE
  /// policy: an unused code is revoked, never removed.
  Future<void> revokeInvite(String inviteId);

  /// Establishes the caller's firm through the `ensure_firm` RPC and returns its
  /// id.
  ///
  /// The one path from individual to owner: `profiles.firm_id`/`role` are
  /// server-owned, so an owner who needs a firm to invite into cannot create one
  /// from the client. Idempotent — calling it again returns the same firm.
  Future<String> ensureFirm(String name);

  /// The caller's firm roster, read live from the server.
  ///
  /// Owner-side: RLS (`firm_members_select_firm`) scopes the read to the
  /// caller's own firm, so an associate cannot ask for another firm's roster and
  /// an individual gets an empty list. Names come from `profiles`, whose select
  /// policy is self-or-same-firm. Throws [FirmFailure] with
  /// [FirmFailureKind.firmAdminOffline] when the device has no connection.
  Future<List<FirmMemberSummary>> listMembers();

  /// The firm's outstanding invites: unused and unrevoked, newest first.
  ///
  /// Owner-side, and a live read like [listMembers]: `firm_invites` is a
  /// server-managed table the client never caches. Throws [FirmFailure] with
  /// [FirmFailureKind.firmAdminOffline] when the device has no connection.
  Future<List<FirmInviteSummary>> listInvites();

  /// Writes one member's role and their three permission flags.
  ///
  /// Owner-side and online-only: the `firm_members_update_owner` policy requires
  /// the caller to own the firm, and the write is what the member's own device
  /// will pull next. The owner's own row is refused by the screen rather than
  /// here — the owner's permissions are structural (`firms.owner_id`), so their
  /// flags are never what grants them access.
  Future<void> updateMemberPermissions({
    required String userId,
    required String role,
    required bool canAdd,
    required bool canEdit,
    required bool canDelete,
  });

  /// Removes [userId] from the caller's firm.
  ///
  /// The `remove_firm_member` RPC is the only path: it deletes the membership
  /// row, relinks the member's profile to individual mode (which is what revokes
  /// their RLS access, Realtime topic and queued writes) and announces the
  /// removal. Authored records are preserved and never reassigned. Throws
  /// [FirmFailure] when the server refused — a non-owner, the owner themselves,
  /// or a member who is already gone.
  Future<void> removeMember(String userId);

  /// Removes the caller's own **provisional** account after an abandoned
  /// onboarding — the plan's rule that an unfinished sign-up is treated as never
  /// created.
  ///
  /// Returns true when the server removed it and false when it refused because
  /// the account is not provably provisional. A refusal is the normal, safe
  /// answer for every account that has actually been used, so it is a value and
  /// not a failure; only a transport problem or an unconfigured build throws.
  Future<bool> abandonOnboarding();
}

/// Why a firm operation failed, in the terms the firm screens word for.
///
/// A firm failure is not an auth failure, and borrowing `AuthFailureKind` for
/// it made the diagnostics log lie: a refused invite was recorded as
/// `AuthFailure(invalidCode)`, so a report named signing-in when the truth was
/// the firm flow. This enum keeps the four kinds that mean something in their
/// own right (the invite, the membership, the premium gate, the owner being
/// offline) and adds the three transport outcomes a firm RPC can actually hit.
///
/// The app already gives each domain its own failure vocabulary —
/// `AuthFailureKind`, `SyncFailureKind`, `AdminActionFailure` — and a firm flow
/// is no different; what was wrong was the borrowing, not the idea of a shared
/// taxonomy.
enum FirmFailureKind {
  /// The request never reached the server: offline, DNS, a timeout.
  network,

  /// The server answered with a 5xx, or refused in a way that is its fault.
  server,

  /// A 401/403 the server issued: the session is no longer valid, or this
  /// account may not do this.
  unauthorized,

  /// The RPC's rate limiter answered — too many invite attempts.
  tooManyAttempts,

  /// No backend is configured in this build.
  unavailable,

  /// The invite code does not match an unused, unrevoked invite.
  invalidInviteCode,

  /// The caller already belongs to the firm the code would have joined.
  alreadyMember,

  /// An owner-side operation was attempted off the network.
  firmAdminOffline,

  /// Firm Mode needs an active premium subscription.
  premiumRequired,

  /// Anything else.
  unknown,
}

/// A firm operation failed.
class FirmFailure implements Exception, DiagnosableFailure {
  /// Creates a failure of [kind].
  const FirmFailure(this.kind, {this.cause});

  /// What went wrong, in firm-level terms.
  final FirmFailureKind kind;

  /// Underlying error or server status, kept for debugging; screens never show
  /// it, and the log keeps it only as [diagnosticDetail].
  final Object? cause;

  /// The log's label: the kind, so entries stay scannable and comparable.
  @override
  String get diagnosticLabel => 'FirmFailure(${kind.name})';

  /// The log's detail: the underlying error, which is what a reader fixes from.
  @override
  String? get diagnosticDetail => cause?.toString();

  @override
  String toString() => 'FirmFailure(${kind.name})';
}

/// Classifies a transport error raised by a firm RPC into [FirmFailureKind].
///
/// Deliberately narrower than `mapAuthFailure`: that mapper answers for a
/// sign-in and can return kinds that make no sense here (an unconfirmed e-mail
/// is not something an invite can be), so reusing it meant a firm failure
/// could arrive wearing a credential's name.
FirmFailure mapFirmFailure(Object error) {
  if (error is FirmFailure) return error;

  if (error is AuthRetryableFetchException) {
    // The SDK raises this for two situations and only the status tells them
    // apart: a request that never reached the server carries none, while every
    // HTTP >= 500 arrives with it set.
    final status = int.tryParse(error.statusCode ?? '');
    if (status != null && status >= 500) {
      return FirmFailure(FirmFailureKind.server, cause: error);
    }
    return FirmFailure(FirmFailureKind.network, cause: error);
  }

  if (error is PostgrestException) {
    // `code` carries the HTTP status as text, or nothing at all when the
    // request never completed.
    final status = int.tryParse(error.code ?? '');
    if (status == null || status >= 500) {
      return FirmFailure(FirmFailureKind.server, cause: error);
    }
    if (status == 401 || status == 403 || status == 425) {
      return FirmFailure(FirmFailureKind.unauthorized, cause: error);
    }
    return FirmFailure(FirmFailureKind.unknown, cause: error);
  }

  if (error is AuthException) {
    final code = error.code ?? '';
    final message = error.message.toLowerCase();
    if (error.statusCode == '429' ||
        code.contains('rate_limit') ||
        message.contains('rate limit')) {
      return FirmFailure(FirmFailureKind.tooManyAttempts, cause: error);
    }
    return FirmFailure(FirmFailureKind.unknown, cause: error);
  }

  // A bare socket or timeout failure: the request never reached the server.
  if (error is SocketException || error is TimeoutException) {
    return FirmFailure(FirmFailureKind.network, cause: error);
  }
  return FirmFailure(FirmFailureKind.unknown, cause: error);
}

/// The repository used when this build has no backend configured.
class UnavailableFirmRepository implements FirmRepository {
  /// Creates the unavailable repository.
  const UnavailableFirmRepository();

  @override
  Future<InviteRedemption> redeemInvite(String code) async =>
      throw const FirmFailure(FirmFailureKind.unavailable);

  @override
  Future<GeneratedInvite> createInvite() async =>
      throw const FirmFailure(FirmFailureKind.unavailable);

  @override
  Future<void> revokeInvite(String inviteId) async =>
      throw const FirmFailure(FirmFailureKind.unavailable);

  @override
  Future<String> ensureFirm(String name) async =>
      throw const FirmFailure(FirmFailureKind.unavailable);

  @override
  Future<List<FirmMemberSummary>> listMembers() async =>
      throw const FirmFailure(FirmFailureKind.unavailable);

  @override
  Future<List<FirmInviteSummary>> listInvites() async =>
      throw const FirmFailure(FirmFailureKind.unavailable);

  @override
  Future<void> updateMemberPermissions({
    required String userId,
    required String role,
    required bool canAdd,
    required bool canEdit,
    required bool canDelete,
  }) async => throw const FirmFailure(FirmFailureKind.unavailable);

  @override
  Future<void> removeMember(String userId) async =>
      throw const FirmFailure(FirmFailureKind.unavailable);

  @override
  Future<bool> abandonOnboarding() async =>
      throw const FirmFailure(FirmFailureKind.unavailable);
}

/// [FirmRepository] implemented on the `join_firm` and `ensure_firm` RPCs and on
/// owner-scoped `firm_invites` writes.
class SupabaseFirmRepository implements FirmRepository {
  /// Creates a repository over [client].
  ///
  /// [isOnline] is the connectivity answer the online-only rule is enforced
  /// with; it defaults to "reachable", which is the safe direction — a request
  /// that runs and fails still shows its own localized message, while a wrong
  /// "offline" would hide an operation the server would have accepted.
  SupabaseFirmRepository(this._client, {Future<bool> Function()? isOnline})
    : _isOnline = isOnline ?? _alwaysOnline;

  static Future<bool> _alwaysOnline() async => true;

  final SupabaseClient _client;
  final Future<bool> Function() _isOnline;

  /// Refuses an owner-side operation while the device is off the network.
  ///
  /// Checked **before** the request rather than inferred from its failure,
  /// because the task asks for this exact sentence rather than a generic
  /// connection error. Redemption is deliberately not guarded here: the sign-up
  /// screen's own copy for a failed request ("No connection…") already reads
  /// correctly for a joining associate, and its failure is classified from the
  /// transport by [mapFirmFailure].
  Future<void> _requireOnline() async {
    if (await _isOnline()) return;
    throw const FirmFailure(FirmFailureKind.firmAdminOffline);
  }

  @override
  Future<InviteRedemption> redeemInvite(String code) async {
    // Normalization matches the RPC exactly (trim, uppercase), so a code typed
    // in lower case or with stray spaces still redeems, and the hash the server
    // computes is the hash this client would have computed.
    final normalized = normalizeInviteCode(code);
    if (normalized.isEmpty) {
      throw const FirmFailure(FirmFailureKind.invalidInviteCode);
    }

    try {
      return parseInviteRedemption(
        await _client.rpc<dynamic>(
          'join_firm',
          params: <String, dynamic>{'code': normalized},
        ),
      );
    } on InviteRefusal {
      // A seat refusal is already typed and carries its count; mapping it here
      // would turn the app's own advice into a generic server error.
      rethrow;
    } catch (error) {
      // The rate limit is the one outcome the RPC raises instead of returning.
      throw mapFirmFailure(error);
    }
  }

  @override
  Future<GeneratedInvite> createInvite() async {
    await _requireOnline();

    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      // Owner-side calls only ever happen behind a session, so this is a bug
      // state rather than something to explain: it deliberately gets no copy of
      // its own.
      throw const FirmFailure(FirmFailureKind.unknown, cause: 'createInvite: no session');
    }

    try {
      // The firm id comes from the caller's own profile row (the select policy
      // is self-or-firm), never from a parameter — an owner cannot invite into
      // a firm that is not theirs, and the insert policy checks the same thing
      // again on the server.
      final profile = await _client
          .from('profiles')
          .select('firm_id')
          .eq('id', userId)
          .maybeSingle();
      final firmId = profile?['firm_id'] as String?;
      if (firmId == null) {
        // Individual mode: `ensureFirm` comes first, so there is nothing to
        // invite into yet.
        throw const FirmFailure(FirmFailureKind.unknown, cause: 'createInvite: no firm');
      }

      final code = generateInviteCode();
      final inserted = await _client
          .from('firm_invites')
          .insert(
            inviteInsertRow(
              firmId: firmId,
              code: code,
              createdBy: userId,
              createdAt: DateTime.now().millisecondsSinceEpoch,
            ),
          )
          .select('id')
          .single();

      return GeneratedInvite(
        code: code,
        inviteId: inserted['id'] as String,
        firmId: firmId,
      );
    } catch (error) {
      throw mapFirmFailure(error);
    }
  }

  @override
  Future<void> revokeInvite(String inviteId) async {
    await _requireOnline();

    try {
      await _client
          .from('firm_invites')
          .update(<String, dynamic>{'revoked': true})
          .eq('id', inviteId);
    } catch (error) {
      throw mapFirmFailure(error);
    }
  }

  @override
  Future<bool> abandonOnboarding() async {
    await _requireOnline();

    try {
      final result = decodeRpcMap(
        await _client.rpc<dynamic>('abandon_provisional_account'),
      );
      // `not_provisional` is an answer, not an error: the account has been used
      // for something, so it is not the abandoned shell this call is for.
      return result['status'] == 'removed';
    } catch (error) {
      throw mapFirmFailure(error);
    }
  }

  @override
  Future<String> ensureFirm(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      // The server refuses an empty name on purpose — it will not invent
      // user-facing copy — so the round trip is not worth making.
      throw const FirmFailure(FirmFailureKind.unknown, cause: 'ensureFirm: empty name');
    }

    await _requireOnline();

    try {
      final result = decodeRpcMap(
        await _client.rpc<dynamic>(
          'ensure_firm',
          params: <String, dynamic>{'p_name': trimmed},
        ),
      );
      final status = result['status'] as String?;
      final firmId = result['firm_id'] as String?;
      if (status == 'ready' && firmId != null) return firmId;
      // The free-entitlement refusal is the one the screen must word for itself
      // (Task 20 Phase 1 item 2): it names the Paywall, not a failure. Every
      // other status — including the member-of-another-firm guard — has no copy
      // of its own, because the client gate hides this path first and the server
      // check is the authoritative one behind it.
      throw FirmFailure(
        status == 'premium_required'
            ? FirmFailureKind.premiumRequired
            : FirmFailureKind.unknown,
        cause: status,
      );
    } catch (error) {
      throw mapFirmFailure(error);
    }
  }

  @override
  Future<List<FirmMemberSummary>> listMembers() async {
    await _requireOnline();

    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      // Owner-side calls only ever happen behind a session, so this is a bug
      // state rather than something to explain: it deliberately gets no copy of
      // its own.
      throw const FirmFailure(FirmFailureKind.unknown, cause: 'listMembers: no session');
    }

    try {
      // Filtered by RLS rather than by a parameter, so the query cannot ask for a
      // firm that is not the caller's own.
      final rows = await _client
          .from('firm_members')
          .select('user_id, role, can_add, can_edit, can_delete');
      if (rows.isEmpty) return const <FirmMemberSummary>[];

      final ids = <String>[
        for (final row in rows)
          if (row['user_id'] is String) row['user_id'] as String,
      ];
      final names = <String, String>{};
      if (ids.isNotEmpty) {
        final profiles = await _client
            .from('profiles')
            .select('id, full_name')
            .inFilter('id', ids);
        for (final profile in profiles) {
          final id = profile['id'];
          if (id is String) {
            names[id] = profile['full_name'] as String? ?? '';
          }
        }
      }

      return <FirmMemberSummary>[
        for (final row in rows)
          if (row['user_id'] is String)
            FirmMemberSummary(
              userId: row['user_id'] as String,
              role: row['role'] as String? ?? AccountRole.associate,
              fullName: names[row['user_id'] as String] ?? '',
              canAdd: row['can_add'] as bool? ?? false,
              canEdit: row['can_edit'] as bool? ?? false,
              canDelete: row['can_delete'] as bool? ?? false,
            ),
      ];
    } catch (error) {
      throw mapFirmFailure(error);
    }
  }

  @override
  Future<List<FirmInviteSummary>> listInvites() async {
    await _requireOnline();

    try {
      // `revoked` and `used_by` are the two ways an invite stops being
      // outstanding; the hash is never selected, because nothing on this screen
      // could do anything with it and the code itself is unrecoverable by
      // design. RLS (`firm_invites_select_owner`) scopes the read to the
      // caller's own firm, so no firm id is passed.
      final rows = await _client
          .from('firm_invites')
          .select('id, created_at')
          .eq('revoked', false)
          .isFilter('used_by', null)
          .order('created_at', ascending: false);

      return <FirmInviteSummary>[
        for (final row in rows)
          if (row['id'] is String)
            FirmInviteSummary(
              id: row['id'] as String,
              createdAt: _epochMs(row['created_at']),
            ),
      ];
    } catch (error) {
      throw mapFirmFailure(error);
    }
  }

  @override
  Future<void> updateMemberPermissions({
    required String userId,
    required String role,
    required bool canAdd,
    required bool canEdit,
    required bool canDelete,
  }) async {
    await _requireOnline();

    final firmId = await _ownFirmId();
    if (firmId == null) {
      throw const FirmFailure(FirmFailureKind.unknown, cause: 'updateMemberPermissions: no firm');
    }

    try {
      // Scoped by firm **and** user, so the statement can only ever touch one
      // row of the caller's own firm; the owner-only policy checks the rest.
      // `permissions_synced_at` is deliberately not written here: it is the
      // member's own device's stamp of when *it* last read these flags.
      await _client
          .from('firm_members')
          .update(<String, dynamic>{
            'role': role,
            'can_add': canAdd,
            'can_edit': canEdit,
            'can_delete': canDelete,
          })
          .eq('firm_id', firmId)
          .eq('user_id', userId);
    } catch (error) {
      throw mapFirmFailure(error);
    }
  }

  @override
  Future<void> removeMember(String userId) async {
    await _requireOnline();

    try {
      final result = decodeRpcMap(
        await _client.rpc<dynamic>(
          'remove_firm_member',
          params: <String, dynamic>{'p_user_id': userId},
        ),
      );
      final status = result['status'] as String?;
      if (status == 'removed') return;
      // Every other answer is a refusal with a name the screen words for
      // itself; the server resolved the firm from the caller, so a wrong firm
      // is not one of the possibilities.
      throw FirmFailure(FirmFailureKind.unknown, cause: status);
    } catch (error) {
      throw mapFirmFailure(error);
    }
  }

  /// The caller's own firm id from their profile row, or null.
  ///
  /// Read rather than passed: every owner-side statement is scoped by the
  /// caller's own firm, never by a parameter, so a client cannot aim one at a
  /// firm that is not theirs.
  Future<String?> _ownFirmId() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    final profile = await _client
        .from('profiles')
        .select('firm_id')
        .eq('id', userId)
        .maybeSingle();
    return profile?['firm_id'] as String?;
  }
}

/// Epoch milliseconds from a server value, or 0 when it cannot be read.
///
/// The `firm_invites.created_at` column is a bigint of milliseconds, but the
/// same tolerance every other date reader here has is kept: an unreadable value
/// must not throw a roster read away.
int _epochMs(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

/// Provider for the firm repository.
final firmRepositoryProvider = Provider<FirmRepository>((ref) {
  final client = ref.watch(activeSupabaseClientProvider);
  return client == null
      ? const UnavailableFirmRepository()
      : SupabaseFirmRepository(
          client,
          // Read lazily and per call: a repository built at launch would
          // otherwise freeze the connectivity answer it was created with.
          isOnline: () => ref.read(connectivityMonitorProvider).isOnline(),
        );
});

/// The owner's live firm roster for Manage Associates (Task 20 Phase 1).
///
/// A read, not a cache: Manage Associates is an online-only screen, so this
/// provider is invalidated after a membership change rather than written into
/// `firm_members`, which stays the pull-only cache of this account's own row.
final firmMembersListProvider = FutureProvider<List<FirmMemberSummary>>((ref) {
  return _recordedFirmRead(
    ref,
    'firm.members',
    () => ref.watch(firmRepositoryProvider).listMembers(),
  );
});

/// The owner's outstanding invites for Manage Associates (Task 20 Phase 2).
///
/// The same live-read shape as [firmMembersListProvider], and for the same
/// reason: `firm_invites` is server-managed and the screen is online-only. It is
/// invalidated after a code is created or revoked rather than cached.
final firmInvitesListProvider = FutureProvider<List<FirmInviteSummary>>((ref) {
  return _recordedFirmRead(
    ref,
    'firm.invites',
    () => ref.watch(firmRepositoryProvider).listInvites(),
  );
});

/// Runs a live firm read and remembers it in [area] when it fails.
///
/// Manage Associates draws a failed read as a banner, so the failure is caught
/// and shown and nothing else ever sees it: without this the log is empty for
/// exactly the roster an owner cannot work out for themselves.
///
/// Recorded here rather than through a `ref.listen` in the screen's build,
/// because a build re-registers its listener and one failing read was written
/// once per frame. It is also not written per attempt, because Riverpod retries
/// a failed provider on a backoff and the report is about what went wrong, not
/// about how many times the framework knocked: eleven copies of one fault would
/// bury every other fault the user hit that session. The same fault again after
/// a *different* one is a new line, because then the two really did happen.
Future<T> _recordedFirmRead<T>(
  Ref ref,
  String area,
  Future<T> Function() read,
) async {
  try {
    return await read();
  } catch (error) {
    final log = ref.read(errorLogProvider);
    final newest = log.entries.isEmpty ? null : log.entries.first;
    if (newest == null ||
        newest.area != area ||
        newest.label != describeErrorForLog(error)) {
      recordFailure(log, area, error);
    }
    rethrow;
  }
}
