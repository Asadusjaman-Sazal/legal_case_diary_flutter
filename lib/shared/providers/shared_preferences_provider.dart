import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Synchronous provider for the initialized [SharedPreferences] instance.
///
/// The instance is loaded in `lib/main.dart` before `runApp` and injected via
/// [ProviderScope.overrides]. This avoids async provider gaps anywhere in the
/// widget tree that need access to preferences.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'SharedPreferences must be initialized in main.dart and overridden '
    'via ProviderScope(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]).',
  );
});
