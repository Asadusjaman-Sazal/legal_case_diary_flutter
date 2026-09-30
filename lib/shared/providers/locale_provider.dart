import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/l10n/generated/app_localizations.dart';
import 'shared_preferences_provider.dart';

/// Preference key used to persist the active locale code.
const String _localeKey = 'app_locale';

/// Default locale for the app during current development.
const Locale defaultLocale = Locale('en');

/// Supported application locales.
///
/// Mirrors [AppLocalizations.supportedLocales] so the provider stays in sync
/// with the generated localization delegate.
List<Locale> get supportedLocales => AppLocalizations.supportedLocales;

/// Riverpod state for the active application locale.
///
/// The notifier reads the persisted code from [SharedPreferences] on first
/// build and falls back to [defaultLocale] (English) when no preference has
/// been stored. Changing the locale updates both the in-memory state and the
/// persisted value.
class LocaleNotifier extends Notifier<Locale> {
  late final SharedPreferences _prefs;

  @override
  Locale build() {
    _prefs = ref.read(sharedPreferencesProvider);
    final saved = _prefs.getString(_localeKey);
    if (saved == null) {
      return defaultLocale;
    }
    return _parseLocale(saved);
  }

  /// Updates the active locale and persists it for the next app launch.
  void setLocale(Locale locale) {
    final languageCode = locale.languageCode;
    final normalized = _parseLocale(languageCode);
    if (state == normalized) return;

    _prefs.setString(_localeKey, languageCode);
    state = normalized;
  }

  /// Forgets the stored language and returns to the default (logout/account
  /// switch): language is a per-user preference, so the next account must not
  /// inherit the previous holder's choice.
  void reset() {
    _prefs.remove(_localeKey);
    state = defaultLocale;
  }

  static Locale _parseLocale(String code) {
    return AppLocalizations.supportedLocales.firstWhere(
      (locale) => locale.languageCode == code,
      orElse: () => defaultLocale,
    );
  }
}

/// Public provider to read and update the active locale.
final localeProvider = NotifierProvider<LocaleNotifier, Locale>(
  LocaleNotifier.new,
);
