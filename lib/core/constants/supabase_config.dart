/// Build-time Supabase configuration.
///
/// The project URL, publishable key and Google Web client ID arrive through
/// `--dart-define-from-file=env.json` — a git-ignored file, the same pattern as
/// the existing git-ignored `supabase/.env.local` used to apply migrations.
/// Nothing here is committed, and no value is ever fetched at runtime.
///
/// When the values are absent the app runs in exactly the Part A shape: fully
/// offline and fully usable, with sign-in reporting that this build has no
/// backend. That is why every `flutter test` run and a plain `flutter run`
/// without the flag both work.
///
/// AGENTS.md rule 12 is enforced here by code rather than by care: only the one
/// writable project is accepted, and the off-limits project is refused by ref.
library;

/// The only Supabase project this app may ever talk to: "Legal Case Diary"
/// (org `xrjmednwyszriubyjzgb`).
const String writableProjectRef = 'lsthasywrdrhuuxnykau';

/// Live project that must never be read or written in any way. Named here only
/// so [SupabaseConfig.isAllowedUrl] can refuse it loudly. `Swanirvor-23`.
const String offLimitsProjectRef = 'ykbwzodadijtiizobehk';

/// Supabase connection settings compiled into the build.
///
/// Deliberately not a class with instances: the values are compile-time
/// constants, so reading them through static getters keeps a single source and
/// makes the whole thing trivially testable.
abstract final class SupabaseConfig {
  /// Project URL for the writable project, or an empty string.
  static const String _url = String.fromEnvironment('SUPABASE_URL');

  /// Publishable (anon) key. Public by design, and every table is protected by
  /// RLS; it is still kept out of the repository so a build cannot ship one
  /// project's key by accident.
  static const String _publishableKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  /// Google OAuth *Web* client ID, which is what the native Google sign-in SDK
  /// needs to mint an ID token the Supabase Auth server accepts.
  static const String _googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
  );

  /// The configured project URL, trimmed.
  static String get url => _url.trim();

  /// The configured publishable key, trimmed.
  static String get publishableKey => _publishableKey.trim();

  /// The configured Google Web client ID, trimmed.
  static String get googleWebClientId => _googleWebClientId.trim();

  /// The custom-scheme URL every auth e-mail sends the user back to.
  ///
  /// Supabase falls back to the project's Site URL when a call passes no
  /// redirect, and that default is `http://localhost:3000` — a dead page in a
  /// mail app on a phone. The sign-up and password-recovery calls pass this
  /// instead, and the matching intent-filter in `AndroidManifest.xml` routes it
  /// back into this app. Being a reverse domain of the application id, it is
  /// fixed by the build rather than by configuration; it must also be listed
  /// under the project's *Redirect URLs*, or Supabase ignores it and falls back
  /// to the Site URL again.
  static const String authRedirectUrl =
      'com.legumsoft.legalcasediary://login-callback';

  /// True when this build can reach the backend.
  ///
  /// A URL naming any other project — including the off-limits one — is treated
  /// as *not configured*, so a wrong value can never reach the wire.
  static bool get isConfigured =>
      isAllowedUrl(url) && publishableKey.isNotEmpty;

  /// True when Google sign-in has the client ID it needs.
  static bool get hasGoogleClientId => googleWebClientId.isNotEmpty;

  /// Whether [candidate] names the one writable project.
  static bool isAllowedUrl(String candidate) =>
      candidate.contains(writableProjectRef) &&
      !candidate.contains(offLimitsProjectRef);
}
