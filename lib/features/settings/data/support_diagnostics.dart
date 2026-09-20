/// Device facts the Support message carries, behind a seam.
///
/// The Support screen pre-fills the message the user is about to send, and the
/// two facts that make a report actionable — the phone and the Android version —
/// are read from `device_info_plus` here, not in the screen: every plugin sits
/// behind a seam in this app (the contact launcher, the file gateway), and the
/// widget tests inject a known phone instead of a platform channel.
///
/// This is local device metadata, never a network lookup, and it never fails
/// loudly: an unreadable device reports empty facts, and the message is then
/// written without the phone line rather than not at all.
library;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the Support message can say about this device; empty when unknown.
class SupportDeviceFacts {
  /// Phone as "brand model" (e.g. "Redmi Note 10"), or null when unavailable.
  final String? model;

  /// Android release (e.g. "Android 13"), or null when unavailable.
  final String? osVersion;

  /// Creates a facts snapshot.
  const SupportDeviceFacts({this.model, this.osVersion});

  /// Whether nothing could be read, so the message omits the phone line.
  bool get isEmpty =>
      (model == null || model!.isEmpty) &&
      (osVersion == null || osVersion!.isEmpty);
}

/// Reads the device facts the Support message carries.
abstract interface class SupportDeviceFactsReader {
  /// Reads the facts; never throws, reporting empty facts when unavailable.
  Future<SupportDeviceFacts> read();
}

/// The Android implementation, backed by `device_info_plus`.
class DeviceInfoSupportFacts implements SupportDeviceFactsReader {
  /// Creates the reader.
  const DeviceInfoSupportFacts();

  @override
  Future<SupportDeviceFacts> read() async {
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      return SupportDeviceFacts(
        model: modelLabel(info.brand, info.model),
        osVersion: 'Android ${info.version.release}',
      );
    } catch (_) {
      // The test host and the desktop builds have no Android info; the Support
      // message simply leaves the phone line out.
      return const SupportDeviceFacts();
    }
  }
}

/// "Redmi Note 10" — the brand is added only when the model lacks it, because
/// Android reports the two inconsistently ("Redmi" + "Redmi Note 10").
String? modelLabel(String brand, String model) {
  final b = brand.trim();
  final m = model.trim();
  if (m.isEmpty) return b.isEmpty ? null : b;
  if (b.isEmpty || m.toLowerCase().contains(b.toLowerCase())) return m;
  return '$b $m';
}

/// The reader behind the Support screen.
final supportDeviceFactsProvider = Provider<SupportDeviceFactsReader>(
  (ref) => const DeviceInfoSupportFacts(),
);
