/// App Lock: a device-level 4-digit PIN that guards opening the app.
///
/// The PIN is **not** a credential and never meets a server: it lives only on
/// this device, in the same secure storage the database key and the session
/// use (Android Keystore / iOS Keychain), and what is written there is a
/// salted SHA-256 digest — never the four digits themselves. A 4-digit PIN has
/// only 10,000 values, so the hash's job is not to survive a determined
/// offline brute force; it is to keep the digits out of any file or backup
/// that leaves the Keystore's protection, which is exactly where a plaintext
/// PIN would be read back.
///
/// Two preferences ride along beside it in plain `SharedPreferences`, because
/// neither is a secret: whether the device's fingerprint may unlock the app,
/// and when the PIN must be asked (on app open, or also on returning from the
/// background). The whole feature is device-level and per-install: it is not
/// part of any account's synced settings, it is never written to
/// `user_preferences`, and it survives sign-out on purpose — a lock that a
/// logout could switch off would not guard the next account either.
library;

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../database/encryption_key_manager.dart';
import '../../../shared/providers/shared_preferences_provider.dart';

/// How often the App Lock PIN has to be entered.
///
/// The user chooses this on the App Lock screen; the default is [appOpen].
enum AppLockTiming {
  /// Ask when the app is opened — the shipped default.
  appOpen,

  /// Ask on open *and* whenever the app returns to the foreground.
  appOpenAndReturn,
}

/// Parses a stored timing name, falling back to [AppLockTiming.appOpen] — a
/// value written by a future build must not lock anyone out of their diary.
AppLockTiming appLockTimingFromName(String? name) =>
    AppLockTiming.values.asNameMap()[name] ?? AppLockTiming.appOpen;

/// The PIN's length: four digits, per the user's choice.
const int appLockPinLength = 4;

/// Secure-storage key holding the salted digest, in `v1$salt$digest` form.
const String _pinStorageKey = 'app_lock_pin';

/// Preference key for whether the fingerprint may unlock the app.
const String _fingerprintKey = 'app_lock_fingerprint_enabled';

/// Preference key for when the PIN is asked.
const String _timingKey = 'app_lock_timing';

/// Preference key recording that a PIN exists.
///
/// **Not the secret** — only its existence, so the app can decide *before its
/// first frame* whether to cover itself without waiting on the Keystore. The
/// flag is written only after the digest lands, so it can never claim "set up"
/// over a store that has nothing to verify against; the digest remains the
/// only thing a PIN can ever match.
const String _setupKey = 'app_lock_enabled';

/// The stored PIN digest and the preferences beside it.
///
/// Constructible over any [KeyStorage], so tests run on
/// [InMemoryKeyStorage] and never touch the platform Keystore.
class AppLockStore {
  /// Creates a store; defaults to the app's secure storage.
  AppLockStore({KeyStorage? storage, required this.prefs})
    : _storage = storage ?? const FlutterSecureKeyStorage();

  final KeyStorage _storage;

  /// The plain preferences: the setup flag and the two switches.
  final SharedPreferences prefs;

  /// Whether a PIN has been set up.
  ///
  /// Reads the plain flag rather than the digest: this is the one question the
  /// app asks before its first frame, and a Keystore read that has not
  /// answered yet would leave the app neither covered nor open. The flag is
  /// only ever set once the digest exists, so "not set up" is always safe.
  Future<bool> get isSetup async => prefs.getBool(_setupKey) ?? false;

  /// Whether the fingerprint may unlock the app.
  bool get fingerprintEnabled => prefs.getBool(_fingerprintKey) ?? false;

  /// When the PIN must be asked; defaults to [AppLockTiming.appOpen].
  AppLockTiming get timing =>
      appLockTimingFromName(prefs.getString(_timingKey));

  /// Sets the PIN. Throws unless [pin] is exactly [appLockPinLength] digits.
  Future<void> setupPin(String pin) async {
    validatePin(pin);
    final salt = _randomSalt();
    await _storage.write(
      key: _pinStorageKey,
      value: _encode(pin, salt),
    );
    // Flag last: it may only claim what the digest above already guarantees.
    await prefs.setBool(_setupKey, true);
  }

  /// Whether [pin] is the stored one.
  ///
  /// False for anything unparseable — a corrupt or absent record must never
  /// grant entry by accident.
  Future<bool> verifyPin(String pin) async {
    final stored = await _storage.read(key: _pinStorageKey);
    if (stored == null || stored.isEmpty) return false;
    return _matches(stored, pin);
  }

  /// Replaces the stored PIN. The caller has already verified the old PIN (or
  /// the fingerprint) — verification is the dialog's job, not this one's.
  Future<void> changePin(String newPin) => setupPin(newPin);

  /// Sets whether the fingerprint may unlock the app.
  Future<void> setFingerprintEnabled(bool enabled) =>
      prefs.setBool(_fingerprintKey, enabled);

  /// Sets when the PIN is asked.
  Future<void> setTiming(AppLockTiming value) =>
      prefs.setString(_timingKey, value.name);

  // -------------------------------------------------------------------------

  /// Validates a candidate PIN: exactly [appLockPinLength] digits.
  ///
  /// Called before anything is written, so a malformed PIN can never be
  /// stored and then silently refuse entry forever.
  static void validatePin(String pin) {
    if (pin.length != appLockPinLength || int.tryParse(pin) == null) {
      throw FormatException('App Lock PIN must be $appLockPinLength digits');
    }
  }

  /// `v1$salt$digest`, both hex.
  String _encode(String pin, String salt) =>
      'v1\$$salt\$${_digest(pin, salt)}';

  String _digest(String pin, String salt) => sha256
      .convert(utf8.encode('app-lock-pin:$salt:$pin'))
      .toString();

  /// Compares [stored] against [pin] using the salt inside it.
  bool _matches(String stored, String pin) {
    final parts = stored.split('\$');
    if (parts.length != 3 || parts[0] != 'v1') return false;
    if (pin.length != appLockPinLength) return false;
    return parts[2] == _digest(pin, parts[1]);
  }

  String _randomSalt() {
    final random = Random.secure();
    return List<int>.generate(16, (_) => random.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}

/// The three facts the App Lock screen and the lock gate are built from.
class AppLockState {
  /// Whether a PIN has been set up.
  final bool isSetup;

  /// Whether the fingerprint may unlock the app.
  final bool fingerprintEnabled;

  /// When the PIN must be asked.
  final AppLockTiming timing;

  /// Creates the state.
  const AppLockState({
    required this.isSetup,
    required this.fingerprintEnabled,
    required this.timing,
  });
}

/// The store, over the app's secure storage.
final appLockStoreProvider = Provider<AppLockStore>(
  (ref) => AppLockStore(prefs: ref.watch(sharedPreferencesProvider)),
);

/// The reactive App Lock state.
///
/// Every mutation re-reads the store rather than trusting the write that
/// just happened: what the screen shows has to be what is actually stored, or
/// a failed PIN write would tell the user their app is locked when it is not.
final appLockStateProvider = AsyncNotifierProvider<AppLockNotifier, AppLockState>(
  () => AppLockNotifier(),
);

/// Loads the state once and writes it back after every mutation.
class AppLockNotifier extends AsyncNotifier<AppLockState> {
  @override
  Future<AppLockState> build() async {
    final store = ref.watch(appLockStoreProvider);
    return _read(store);
  }

  /// Stores a new PIN; the store validates it first.
  Future<void> setupPin(String pin) async {
    await ref.read(appLockStoreProvider).setupPin(pin);
    state = AsyncValue.data(await _read(ref.read(appLockStoreProvider)));
  }

  /// Whether [pin] is the stored one.
  Future<bool> verifyPin(String pin) =>
      ref.read(appLockStoreProvider).verifyPin(pin);

  /// Replaces the stored PIN; the caller has already verified the old one.
  Future<void> changePin(String newPin) async {
    await ref.read(appLockStoreProvider).changePin(newPin);
    state = AsyncValue.data(await _read(ref.read(appLockStoreProvider)));
  }

  /// Enables or disables fingerprint unlock.
  Future<void> setFingerprintEnabled(bool enabled) async {
    await ref.read(appLockStoreProvider).setFingerprintEnabled(enabled);
    state = AsyncValue.data(await _read(ref.read(appLockStoreProvider)));
  }

  /// Sets when the PIN is asked.
  Future<void> setTiming(AppLockTiming timing) async {
    await ref.read(appLockStoreProvider).setTiming(timing);
    state = AsyncValue.data(await _read(ref.read(appLockStoreProvider)));
  }

  Future<AppLockState> _read(AppLockStore store) async => AppLockState(
    isSetup: await store.isSetup,
    fingerprintEnabled: store.fingerprintEnabled,
    timing: store.timing,
  );
}
