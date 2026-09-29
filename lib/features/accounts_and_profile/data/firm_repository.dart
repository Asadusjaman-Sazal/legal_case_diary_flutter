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

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/repository_providers.dart';
import '../../../sync/connectivity_monitor.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/data/supabase_auth_repository.dart' show mapAuthFailure;

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

  /// The account was already a member; the code was still consumed, exactly as
  /// the single-use rule requires.
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
    'invalid_code' => throw const AuthFailure(AuthFailureKind.invalidCode),
    // The RPC falls back to a status rather than raising when it cannot see a
    // caller; a redemption always happens signed in, so this is a bug state, not
    // something to explain to the user.
    _ => throw AuthFailure(
      AuthFailureKind.unknown,
      serverMessage: result['status'] as String?,
    ),
  };
}

/// Firm membership operations the app performs.
abstract class FirmRepository {
  /// Redeems [code] for the signed-in account.
  ///
  /// Throws [AuthFailure] with [AuthFailureKind.invalidCode] when the code
  /// matches no unused, unrevoked invite — a revoked code and an already-used
  /// code both surface that way, because the server will not say which — and
  /// with [AuthFailureKind.tooManyAttempts] once the rate limit is hit. Both
  /// leave onboarding retryable.
  Future<InviteRedemption> redeemInvite(String code);

  /// Creates a single-use invite for the caller's own firm.
  ///
  /// Owner-side only: the RLS insert policy requires `created_by = auth.uid()`
  /// and a firm the caller owns. The returned [GeneratedInvite.code] is the one
  /// and only sight of the plaintext. Throws [AuthFailure] with
  /// [AuthFailureKind.firmAdminOffline] when the device has no connection.
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
}

/// The repository used when this build has no backend configured.
class UnavailableFirmRepository implements FirmRepository {
  /// Creates the unavailable repository.
  const UnavailableFirmRepository();

  @override
  Future<InviteRedemption> redeemInvite(String code) async =>
      throw const AuthFailure(AuthFailureKind.unavailable);

  @override
  Future<GeneratedInvite> createInvite() async =>
      throw const AuthFailure(AuthFailureKind.unavailable);

  @override
  Future<void> revokeInvite(String inviteId) async =>
      throw const AuthFailure(AuthFailureKind.unavailable);

  @override
  Future<String> ensureFirm(String name) async =>
      throw const AuthFailure(AuthFailureKind.unavailable);
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
  /// transport by [mapAuthFailure].
  Future<void> _requireOnline() async {
    if (await _isOnline()) return;
    throw const AuthFailure(AuthFailureKind.firmAdminOffline);
  }

  @override
  Future<InviteRedemption> redeemInvite(String code) async {
    // Normalization matches the RPC exactly (trim, uppercase), so a code typed
    // in lower case or with stray spaces still redeems, and the hash the server
    // computes is the hash this client would have computed.
    final normalized = normalizeInviteCode(code);
    if (normalized.isEmpty) {
      throw const AuthFailure(AuthFailureKind.invalidCode);
    }

    try {
      return parseInviteRedemption(
        await _client.rpc<dynamic>(
          'join_firm',
          params: <String, dynamic>{'code': normalized},
        ),
      );
    } catch (error) {
      // The rate limit is the one outcome the RPC raises instead of returning.
      throw mapAuthFailure(error);
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
      throw const AuthFailure(
        AuthFailureKind.unknown,
        serverMessage: 'createInvite: no session',
      );
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
        throw const AuthFailure(
          AuthFailureKind.unknown,
          serverMessage: 'createInvite: no firm',
        );
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
      throw mapAuthFailure(error);
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
      throw mapAuthFailure(error);
    }
  }

  @override
  Future<String> ensureFirm(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      // The server refuses an empty name on purpose — it will not invent
      // user-facing copy — so the round trip is not worth making.
      throw const AuthFailure(
        AuthFailureKind.unknown,
        serverMessage: 'ensureFirm: empty name',
      );
    }

    await _requireOnline();

    try {
      final result = decodeRpcMap(
        await _client.rpc<dynamic>(
          'ensure_firm',
          params: <String, dynamic>{'p_name': trimmed},
        ),
      );
      final firmId = result['firm_id'] as String?;
      if (result['status'] == 'ready' && firmId != null) return firmId;
      throw AuthFailure(
        AuthFailureKind.unknown,
        serverMessage: result['status'] as String?,
      );
    } catch (error) {
      throw mapAuthFailure(error);
    }
  }
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
