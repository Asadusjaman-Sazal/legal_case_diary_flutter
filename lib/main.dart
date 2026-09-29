import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/constants/supabase_config.dart';
import 'features/auth/data/session_store.dart';
import 'features/auth/data/supabase_auth_repository.dart';
import 'shared/providers/shared_preferences_provider.dart';

/// Entry point of the Legal Case Diary application.
///
/// SharedPreferences are loaded before the first frame so that preferences
/// such as the active locale are available synchronously to providers and
/// widgets throughout the app.
///
/// Supabase is initialized only when the build carries a project URL and
/// publishable key (`--dart-define-from-file=env.json`). Either way, the diary
/// itself is local and is never gated on the backend: with no configuration, or
/// with a backend that cannot be reached, the app starts exactly as it did in
/// Part A.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load intl locale data for date formatting in English and Bengali before
  // the first frame. Date formatting helpers in [AppDateUtils] rely on this.
  await initializeDateFormatting();

  final prefs = await SharedPreferences.getInstance();

  await _initializeSupabase();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const App(),
    ),
  );
}

/// Initializes Supabase when this build is configured for it.
///
/// `Supabase.initialize` restores any persisted session from secure storage
/// with a local read only, and kicks off a token refresh in the background — so
/// this call never waits on the network, and a failure here leaves the app fully
/// usable offline rather than stopping it.
Future<void> _initializeSupabase() async {
  if (!SupabaseConfig.isConfigured) {
    // No backend in this build: `activeSupabaseClient` stays null and the auth
    // providers fall back to the unavailable repository.
    return;
  }

  try {
    final client = await Supabase.initialize(
      url: SupabaseConfig.url,
      // The publishable (anon) key: public by design, and every table is
      // protected by RLS. The secret key must never ship in the app.
      publishableKey: SupabaseConfig.publishableKey,
      authOptions: FlutterAuthClientOptions(
        // The session is a credential, so it goes to secure storage instead of
        // plain preferences.
        localStorage: SecureSessionStorage(),
      ),
    );
    activeSupabaseClient = client.client;
  } catch (error) {
    // Never fatal: a session that cannot be restored is a sign-in problem, not
    // a diary problem.
    debugPrint('Supabase initialization failed: ${error.runtimeType}');
  }
}
