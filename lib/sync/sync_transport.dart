/// The network boundary the sync engine talks to.
///
/// Everything above this interface is pure Dart + Drift, so the push worker and
/// the delta pull can be driven end to end in a unit test with a fake transport
/// and no server. The one real implementation wraps the `push_changes` RPC.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/errors/error_log.dart';

/// Thrown by a [SyncTransport] when a call could not complete.
///
/// [retryable] is the only thing the retry policy reads: a network or 5xx
/// failure is retried with backoff, while a permanent rejection stops
/// immediately.
class SyncFailure implements Exception, DiagnosableFailure {
  /// Creates a failure with a user-safe [message].
  const SyncFailure(this.message, {required this.kind, required this.retryable});

  /// A message safe to show and log.
  final String message;

  /// How the failure was classified.
  final SyncFailureKind kind;

  /// Whether the push worker should retry.
  final bool retryable;

  /// The log's label. [message] is already user-safe, but the kind is what a
  /// support reader needs first and it never varies with the payload.
  @override
  String get diagnosticLabel => 'SyncFailure(${kind.name})';

  /// The log's detail: the classified message, which is safe to keep.
  @override
  String? get diagnosticDetail => message;

  @override
  String toString() => message;
}

/// The class a [SyncFailure] falls into.
enum SyncFailureKind {
  /// A connection, DNS, socket or timeout problem.
  network,

  /// A 5xx from PostgREST or the RPC.
  server,

  /// A 401/403 the server issued (the session is no longer valid).
  unauthorized,

  /// No backend is configured in this build.
  unavailable,

  /// Anything else.
  unknown,
}

/// The fixed page size of one delta-pull request.
const int syncPullPageSize = 200;

/// The PostgREST filter for the composite `(server_updated_at, id)` cursor:
/// `server_updated_at > time OR (server_updated_at = time AND id > id)`.
///
/// It is a top-level function so the exact filter — the thing that decides
/// which rows a page can miss — is pinned by a test without a server.
String syncPullFilter(String sinceTime, String sinceId) =>
    'server_updated_at.gt.$sinceTime,and(server_updated_at.eq.$sinceTime,id.gt.$sinceId)';

/// The server calls the engine needs.
abstract class SyncTransport {
  /// Sends one atomic batch of mutations and returns one result per
  /// `mutation_id`, in input order.
  Future<List<Map<String, dynamic>>> pushChanges(
    List<Map<String, dynamic>> rows,
  );

  /// One page of [table]'s rows changed at or after the composite cursor,
  /// ascending by `(server_updated_at, id)`.
  ///
  /// Omitting [sinceTime]/[sinceId] asks for the table from the minimum
  /// sentinel — an initial/full pull. [sinceTime] is the raw server timestamp
  /// string, passed back exactly as the server sent it.
  Future<List<Map<String, dynamic>>> fetchPage(
    String table, {
    String? sinceTime,
    String? sinceId,
    int limit,
  });

  /// One row by id, for the Realtime micro pull.
  ///
  /// Returns null when the row is not visible to this account (deleted by
  /// another device's purge, or outside its scope), which the caller treats as
  /// "nothing to apply" rather than as an error: the delta pull is what decides
  /// a row's absence, never a notification.
  Future<Map<String, dynamic>?> fetchRow(String table, String id);

  /// The server's current instant, or null when it cannot be read.
  Future<DateTime?> serverTime();
}

/// The real transport over the Supabase client.
class SupabaseSyncTransport implements SyncTransport {
  /// Creates a transport over an initialized [SupabaseClient].
  SupabaseSyncTransport(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Map<String, dynamic>>> pushChanges(
    List<Map<String, dynamic>> rows,
  ) async {
    try {
      final response = await _client.rpc('push_changes', params: {'rows': rows});
      return decodePushResults(response);
    } on Object catch (error) {
      throw mapSyncFailure(error);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPage(
    String table, {
    String? sinceTime,
    String? sinceId,
    int limit = syncPullPageSize,
  }) async {
    try {
      var query = _client.from(table).select();
      if (sinceTime != null && sinceId != null) {
        query = query.or(syncPullFilter(sinceTime, sinceId));
      }
      final rows = await query
          .order('server_updated_at', ascending: true)
          .order('id', ascending: true)
          .limit(limit);
      return rows.map((row) => row).toList(growable: false);
    } on Object catch (error) {
      throw mapSyncFailure(error);
    }
  }

  @override
  Future<Map<String, dynamic>?> fetchRow(String table, String id) async {
    try {
      return await _client.from(table).select().eq('id', id).maybeSingle();
    } on Object catch (error) {
      throw mapSyncFailure(error);
    }
  }

  @override
  Future<DateTime?> serverTime() async {
    try {
      return decodeServerTime(await _client.rpc('sync_server_time'));
    } on Object catch (error) {
      throw mapSyncFailure(error);
    }
  }
}

/// Reads the instant from `sync_server_time()`'s response.
///
/// PostgREST answers a scalar `timestamptz` as a bare ISO-8601 string, but the
/// row form is accepted too; anything unreadable is null rather than a guess,
/// because a wrong offset would raise a false clock warning.
DateTime? decodeServerTime(Object? response) {
  if (response is String) {
    return DateTime.tryParse(response)?.toUtc();
  }
  if (response is Map) {
    final value = response['sync_server_time'];
    if (value is String) return DateTime.tryParse(value)?.toUtc();
  }
  return null;
}

/// Decodes the `{ results: [...] }` object the RPC returns.
///
/// Public so the tests can pin the decoding without a client.
List<Map<String, dynamic>> decodePushResults(Object? response) {
  Object? decoded = response;
  if (decoded is String) {
    if (decoded.isEmpty) return const <Map<String, dynamic>>[];
    try {
      decoded = jsonDecode(decoded);
    } on FormatException {
      return const <Map<String, dynamic>>[];
    }
  }
  if (decoded is! Map) return const <Map<String, dynamic>>[];
  final results = decoded['results'];
  if (results is! List) return const <Map<String, dynamic>>[];
  return results
      .whereType<Map>()
      .map((row) => row.cast<String, dynamic>())
      .toList(growable: false);
}

/// Classifies any thrown object into a [SyncFailure].
SyncFailure mapSyncFailure(Object error) {
  if (error is SyncFailure) return error;

  if (error is AuthRetryableFetchException) {
    return SyncFailure('Could not reach the server.', kind: SyncFailureKind.network, retryable: true);
  }
  if (error is AuthException) {
    // A rejected/expired session is permanent until the user signs in again.
    return SyncFailure(error.message, kind: SyncFailureKind.unauthorized, retryable: false);
  }
  if (error is FunctionException) {
    final status = error.status;
    final retryable = status >= 500 || status == 0;
    return SyncFailure(
      error.reasonPhrase ?? error.details?.toString() ?? 'The server rejected the request.',
      kind: _kindForStatus(status, retryable),
      retryable: retryable,
    );
  }
  if (error is PostgrestException) {
    final code = int.tryParse(error.code ?? '');
    final retryable = code == null || code >= 500;
    return SyncFailure(
      error.message,
      kind: _kindForStatus(code, retryable),
      retryable: retryable,
    );
  }
  if (error is SocketException || error is TimeoutException) {
    return SyncFailure('Could not reach the server.', kind: SyncFailureKind.network, retryable: true);
  }
  final text = error.toString();
  if (text.contains('SocketException') ||
      text.contains('Failed host lookup') ||
      text.contains('ClientException') ||
      text.contains('Connection closed')) {
    return SyncFailure('Could not reach the server.', kind: SyncFailureKind.network, retryable: true);
  }
  if (error is FormatException || error is ArgumentError || error is StateError) {
    // A bug, not a transient problem: retrying it forever would only loop.
    return SyncFailure(text, kind: SyncFailureKind.unknown, retryable: false);
  }
  return SyncFailure(text, kind: SyncFailureKind.unknown, retryable: true);
}

SyncFailureKind _kindForStatus(int? status, bool retryable) {
  if (status == 401 || status == 403) return SyncFailureKind.unauthorized;
  if (status != null && status >= 500) return SyncFailureKind.server;
  return retryable ? SyncFailureKind.server : SyncFailureKind.unknown;
}
