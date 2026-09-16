/// Local profile full-name store.
///
/// The name entered in Settings > Account & Profile > Profile > Full Name is
/// remembered in [SharedPreferences], so every screen that shows the user — the
/// navigation drawer header, the Profile screen, Manage Account — reads the same
/// value and it survives app restarts.
///
/// Part A: local-only. Task 17 (Part B) binds the synced profile record.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/providers/shared_preferences_provider.dart';

/// Preference key holding the user's saved full name.
const String profileFullNameKey = 'profile_full_name';

/// Name used until the user saves one (matches the mockup placeholder data).
const String defaultProfileFullName = 'Asadusjaman';

/// Riverpod state for the user's full name.
///
/// The initial value is read synchronously from [SharedPreferences], so the
/// drawer header and the Profile screen agree from the first frame. [setName]
/// persists the value and notifies every listener.
class ProfileNameNotifier extends Notifier<String> {
  late final SharedPreferences _prefs;

  @override
  String build() {
    _prefs = ref.read(sharedPreferencesProvider);
    return _prefs.getString(profileFullNameKey) ?? defaultProfileFullName;
  }

  /// Persists [name]; an empty value means "no name saved" (callers show a
  /// placeholder).
  Future<void> setName(String name) async {
    final value = name.trim();
    if (value == state) return;
    await _prefs.setString(profileFullNameKey, value);
    state = value;
  }
}

/// Public provider to read and update the user's full name.
final profileNameProvider = NotifierProvider<ProfileNameNotifier, String>(
  ProfileNameNotifier.new,
);
