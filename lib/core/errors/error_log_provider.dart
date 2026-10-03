/// The error log the app reads.
///
/// Built in `lib/main.dart` before `runApp` and injected through
/// [ProviderScope.overrides] — the same shape as [sharedPreferencesProvider],
/// and for the same reason: the global capture has to record a failure that
/// happens *during* startup, so the log cannot be created lazily on first read.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'error_log.dart';

/// The app's error log, newest first.
final errorLogProvider = Provider<ErrorLog>((ref) {
  throw UnimplementedError(
    'ErrorLog must be created in main.dart and overridden via '
    'ProviderScope(overrides: [errorLogProvider.overrideWithValue(log)]).',
  );
});
