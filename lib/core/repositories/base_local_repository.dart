/// Base repository helper for local Drift repositories.
///
/// Provides shared utilities for applying sync columns and identifying the
/// current local user. Repositories mix this in and call [syncHelper] to
/// enqueue mutations via [SyncWriteHelper].
library;

import '../../sync/sync_write_helper.dart';

/// Mixin for local repositories that write to push-domain tables.
mixin BaseLocalRepository {
  /// The sync helper used to enqueue mutations.
  SyncWriteHelper get syncHelper;

  /// Returns the current local user id used for `last_modified_by`.
  String get currentUserId => syncHelper.currentUserId;

  /// Current epoch timestamp in milliseconds (UTC).
  static int get nowMillis => SyncWriteHelper.nowMillis;

  /// Converts a Drift data class JSON map (camelCase keys) into the snake_case
  /// payload expected by the sync queue and the server.
  static Map<String, dynamic> toSyncPayload(Map<String, dynamic> json) {
    return json.map((key, value) => MapEntry(_camelToSnake(key), value));
  }

  static final _camelCaseRegex = RegExp(r'(?<=[a-z])[A-Z]');

  static String _camelToSnake(String input) {
    return input
        .replaceAllMapped(
          _camelCaseRegex,
          (match) => '_${match.group(0)!.toLowerCase()}',
        )
        .toLowerCase();
  }
}
