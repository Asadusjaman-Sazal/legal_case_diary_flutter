/// Device-stored fingerprint (or Face ID) for App Lock.
///
/// One seam, two implementations: the app talks to [Biometrics], the real one
/// wraps `local_auth`, and tests override [biometricsProvider] with a fake —
/// the platform prompt cannot be driven from a widget test, and a feature whose
/// only coverage is "the button exists" would not know whether verification
/// actually gates anything.
///
/// Every failure answers `false` rather than throwing: a phone with no sensor,
/// no enrolled fingerprint or a cancelled prompt is not an error the user
/// should be shown as one — it is "not verified", which the caller words.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

/// What App Lock asks the device for.
abstract class Biometrics {
  /// Whether this device can be asked at all: sensor present *and* something
  /// enrolled on it.
  Future<bool> get isUsable;

  /// Asks the user to prove themselves; true only if they did.
  ///
  /// [reason] is shown by the system in the prompt itself, so it must be a
  /// sentence the OS may print.
  Future<bool> verify(String reason);
}

/// The real device, through `local_auth`.
class LocalBiometrics implements Biometrics {
  /// Creates the service.
  LocalBiometrics();

  final LocalAuthentication _auth = LocalAuthentication();

  @override
  Future<bool> get isUsable async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      if (!await _auth.canCheckBiometrics) return false;
      return (await _auth.getAvailableBiometrics()).isNotEmpty;
    } on Object {
      // A platform that refuses the query (no feature, OEM differences) simply
      // has no usable fingerprint, as far as App Lock is concerned.
      return false;
    }
  }

  @override
  Future<bool> verify(String reason) async {
    try {
      // biometricOnly: the PIN is App Lock's own; a device screen lock must
      // never satisfy this prompt, or anyone holding the unlocked phone could
      // switch fingerprint unlock on.
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
      );
    } on Object {
      return false;
    }
  }
}

/// The device's biometrics, as this app uses them.
final biometricsProvider = Provider<Biometrics>((ref) => LocalBiometrics());
