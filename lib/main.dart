import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'shared/providers/shared_preferences_provider.dart';

/// Entry point of the Legal Case Diary application.
///
/// SharedPreferences are loaded before the first frame so that preferences
/// such as the active locale are available synchronously to providers and
/// widgets throughout the app.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load intl locale data for date formatting in English and Bengali before
  // the first frame. Date formatting helpers in [AppDateUtils] rely on this.
  await initializeDateFormatting();

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const App(),
    ),
  );
}
