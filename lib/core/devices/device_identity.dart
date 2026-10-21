/// The install identity the device limit is counted against.
///
/// The limit itself is enforced by the server on the **session** a sign-in
/// creates, which a client cannot forge. This key exists for the one thing a
/// session cannot do: recognise the same phone signing in again, so it reuses
/// its own slot instead of spending a second one. Android's SSAID (the value
/// `device_info_plus` calls `id`) survives a reinstall; elsewhere a UUID minted
/// once and kept in SharedPreferences is used, so a Windows reinstall counts as
/// a new device — which the device list can then free.
library;

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
    label: 'This device',
  );
}

/// Resolves the identity once per install and caches it in memory.
class DeviceIdentityService {
  /// The SharedPreferences key holding the minted fallback key.
  static const keyPreference = 'device_install_key';

  /// Cached after the first resolve, so every caller sees the same key.
  DeviceIdentity? _cached;

  /// The install key, once [resolve] has finished; null before that.
  ///
  /// Read by paths that must not wait on the platform — the push registration
  /// attaches it as metadata and has nothing to gain by delaying its row — while
  /// the device gate's own launch calls [resolve] and fills it in.
  String? get cachedKey => _cached?.key;

  /// How long the platform may take to answer before a key is minted for this
  /// process instead.
  ///
  /// A platform channel that never answers is a real case — an emulator, a test
  /// host, a device whose service is wedged — and it must not hold up
  /// registration: the session, not this key, is what the limit counts, so a
  /// usable stand-in keeps sync working and only costs a second slot on the one
  /// device whose storage is already broken.
  static const resolveTimeout = Duration(seconds: 2);

  /// Reads the device's own identifiers, falling back to a stored UUID.
  ///
  /// Never throws and never waits longer than [resolveTimeout]: a platform the
  /// plugin cannot answer for still needs a usable device key, because the
  /// alternative is an app that cannot register and therefore cannot sync.
  Future<DeviceIdentity> resolve() async {
    final cached = _cached;
    if (cached != null) return cached;

    final identity = await _resolve().timeout(
      resolveTimeout,
      onTimeout: () => DeviceIdentity(
        key: const Uuid().v4(),
        platform: 'unknown',
        label: 'This device',
      ),
    );
    _cached = identity;
    return identity;
  }

  /// The plugin and storage reads behind [resolve].
  Future<DeviceIdentity> _resolve() async {
    DeviceIdentity identity = DeviceIdentity.fallback;
    try {
      final plugin = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final info = await plugin.androidInfo;
        identity = DeviceIdentity(
          key: info.id.trim().isEmpty ? await _storedKey() : info.id.trim(),
          platform: 'android',
          label: _join([info.manufacturer, info.model]),
        );
      } else if (Platform.isIOS) {
        final info = await plugin.iosInfo;
        identity = DeviceIdentity(
          key: info.identifierForVendor ?? await _storedKey(),
          platform: 'ios',
          label: info.name.trim().isEmpty ? info.model : info.name,
        );
      } else if (Platform.isWindows) {
        final info = await plugin.windowsInfo;
        identity = DeviceIdentity(
          key: await _storedKey(),
          platform: 'windows',
          label: info.computerName.trim().isEmpty
              ? 'Windows PC'
              : info.computerName,
        );
      }
    } on Object {
      // A plugin that cannot answer is not a reason to fail: fall through to the
      // stored key below.
    }

    if (identity.key == DeviceIdentity.fallback.key) {
      identity = DeviceIdentity(
        key: await _storedKey(),
        platform: identity.platform,
        label: identity.label,
      );
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

  /// Joins the non-empty parts of a label.
  String _join(List<String> parts) {
    final text = parts
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .join(' ');
    return text.isEmpty ? 'This device' : text;
  }
}
