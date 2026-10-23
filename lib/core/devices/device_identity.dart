/// The install identity the device limit is counted against.
///
/// The limit itself is enforced by the server on the **session** a sign-in
/// creates, which a client cannot forge. This key exists for the one thing a
/// session cannot do: recognise the same phone signing in again, so it reuses
/// its own slot instead of spending a second one.
///
/// **The key is a UUID minted once and kept in SharedPreferences on Android and
/// Windows.** `device_info_plus`'s Android `id` is the *build ID*, not the
/// SSAID, and two identical phones on the same firmware report the same value —
/// using it made two Redmi Note 10 Pro handsets collide on the server's
/// active-device index. iOS keeps `identifierForVendor` when the plugin answers;
/// the stored UUID is the fallback there too. A reinstall mints a new key and
/// counts as a new device, which the device list can then free.
library;

import 'dart:async';
import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// What one install reports about itself: its key, its platform and a label the
/// lawyer can recognise in the device list.
class DeviceIdentity {
  /// Creates an identity.
  const DeviceIdentity({
    required this.key,
    required this.platform,
    required this.label,
  });

  /// The stable install key. Client-supplied, so it never grants anything.
  final String key;

  /// `android`, `ios`, `windows` or `unknown` — the server's own allow-list.
  final String platform;

  /// A human label: the phone's brand and model, or a plain fallback.
  final String label;

  /// A safe stand-in for a test or a device whose plugin is unavailable.
  static const fallback = DeviceIdentity(
    key: 'unknown-device',
    platform: 'unknown',
    label: 'Unknown device',
  );
}

/// Resolves the identity once per install and caches it in memory.
class DeviceIdentityService {
  /// The SharedPreferences key holding the minted install key.
  static const keyPreference = 'device_install_key';

  /// The SharedPreferences key holding the last model name the plugin reported.
  static const labelPreference = 'device_label';

  /// Cached after the first resolve, so every caller sees the same key.
  DeviceIdentity? _cached;

  /// The install key, once [resolve] has finished; null before that.
  ///
  /// Read by paths that must not wait on the platform — the push registration
  /// attaches it as metadata and has nothing to gain by delaying its row — while
  /// the device gate's own launch calls [resolve] and fills it in.
  String? get cachedKey => _cached?.key;

  /// How long the platform may take to answer before the label falls back to
  /// the last one it reported.
  ///
  /// A platform channel that never answers is a real case — an emulator, a test
  /// host, a device whose service is wedged — and it must not hold up
  /// registration. The key is read from storage before this wait, so a timeout
  /// costs only the label, never the install's identity.
  static const resolveTimeout = Duration(seconds: 2);

  /// Reads the device's own identifiers, falling back to a stored UUID.
  ///
  /// Never throws and never waits longer than [resolveTimeout]: a platform the
  /// plugin cannot answer for still has a stable key and the last model name it
  /// reported, because the alternative is an app that cannot register and
  /// therefore cannot sync. [refresh] re-asks the platform even when a cached
  /// answer exists, which is how a launch whose lookup timed out gets its model
  /// name on the next heartbeat.
  Future<DeviceIdentity> resolve({bool refresh = false}) async {
    final cached = _cached;
    if (cached != null && !refresh) return cached;

    // The key is read first and never depends on the plugin: it must be the
    // same value on every launch, and the Android build ID is not unique.
    final storedKey = await _storedKey();
    final storedLabel = await _storedLabel();

    DeviceIdentity identity;
    try {
      identity = await _resolve(storedKey).timeout(
        resolveTimeout,
        onTimeout: () => DeviceIdentity(
          key: storedKey,
          platform: 'unknown',
          label: storedLabel ?? 'Unknown device',
        ),
      );
    } on Object {
      identity = DeviceIdentity(
        key: storedKey,
        platform: 'unknown',
        label: storedLabel ?? 'Unknown device',
      );
    }

    _cached = identity;
    return identity;
  }

  /// The plugin read behind [resolve]; [storedKey] is the install's own key.
  Future<DeviceIdentity> _resolve(String storedKey) async {
    DeviceIdentity identity = DeviceIdentity.fallback;
    try {
      final plugin = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final info = await plugin.androidInfo;
        identity = DeviceIdentity(
          key: storedKey,
          platform: 'android',
          label: _join([info.manufacturer, info.model]),
        );
      } else if (Platform.isIOS) {
        final info = await plugin.iosInfo;
        identity = DeviceIdentity(
          key: info.identifierForVendor ?? storedKey,
          platform: 'ios',
          label: info.name.trim().isEmpty ? info.model : info.name,
        );
      } else if (Platform.isWindows) {
        final info = await plugin.windowsInfo;
        identity = DeviceIdentity(
          key: storedKey,
          platform: 'windows',
          label: info.computerName.trim().isEmpty
              ? 'Windows PC'
              : info.computerName,
        );
      }
    } on Object {
      // A plugin that cannot answer is not a reason to fail: the stored key and
      // the last known label still register the device.
    }

    if (identity.key == DeviceIdentity.fallback.key) {
      identity = DeviceIdentity(
        key: storedKey,
        platform: identity.platform,
        label: identity.label,
      );
    }

    if (identity.label != DeviceIdentity.fallback.label) {
      unawaited(_rememberLabel(identity.label));
    }

    return identity;
  }

  /// The UUID minted for this install, created on first use.
  Future<String> _storedKey() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(keyPreference);
    if (stored != null && stored.isNotEmpty) return stored;
    final minted = const Uuid().v4();
    await prefs.setString(keyPreference, minted);
    return minted;
  }

  /// The last model name the plugin reported, for a launch where it is slow.
  Future<String?> _storedLabel() async {
    final prefs = await SharedPreferences.getInstance();
    final label = prefs.getString(labelPreference)?.trim();
    return label == null || label.isEmpty ? null : label;
  }

  /// Remembers a resolved model name for the next launch.
  Future<void> _rememberLabel(String label) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(labelPreference, label);
  }

  /// Joins the non-empty parts of a label.
  String _join(List<String> parts) {
    final text = parts
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .join(' ');
    return text.isEmpty ? 'Unknown device' : text;
  }
}
