/// OEM battery-killer policy: which phones need extra setup, and which steps.
///
/// Purely declarative and platform-free (Task 13 Phase 3): the manufacturer
/// strings come in, the family and the ordered step list come out. How a step
/// is opened on a particular phone — a MIUI autostart component, the battery
/// optimizer list, the Alarms & reminders page — is Android knowledge and lives
/// in the gateway, so this file can be unit-tested on the test host.
///
/// Background (plan §10): Xiaomi/MIUI, Oppo/ColorOS, Vivo/Funtouch and Realme
/// ignore standard `AlarmManager` calls and kill background isolates, so the
/// daily alert silently fails unless the user allows auto-start and takes the
/// app off battery optimization.
library;

/// Manufacturer families the guide knows specific advice for.
enum OemFamily {
  /// Xiaomi, Redmi, Poco (MIUI/HyperOS).
  xiaomi,

  /// Oppo, Realme, OnePlus (ColorOS/OxygenOS).
  oppo,

  /// Vivo, iQOO (Funtouch OS/OriginOS).
  vivo,

  /// Huawei, Honor (EMUI/MagicOS).
  huawei,

  /// Infinix, Tecno, itel (XOS/HiOS).
  infinix,

  /// Samsung (One UI) — no auto-start step, but battery limits still apply.
  samsung,

  /// Anything else: the two steps every Android phone understands.
  generic,
}

/// One step of the setup guide.
enum OemGuideStepId {
  /// Allow the app to start by itself (MIUI/ColorOS/Funtouch and friends).
  autoStart,

  /// Set battery usage for the app to Unrestricted / No restrictions.
  batteryUnrestricted,

  /// Permit exact alarms (Android 12+; denied by default on Android 14).
  exactAlarms,
}

/// A settings page the guide can try to open for a step.
///
/// The list for a step is tried in order and the last entry is always the app's
/// own details page, which exists on every phone.
enum OemSettingsTarget {
  /// The OEM's auto-start / startup-manager list.
  autoStart,

  /// The system battery-optimization list.
  batteryOptimization,

  /// The system "Alarms & reminders" permission page.
  exactAlarms,

  /// The app's own settings page — the universal fallback.
  appDetails,
}

/// What the device reports about itself, reduced to what the guide needs.
class DeviceIdentity {
  /// Manufacturer string, e.g. `Xiaomi`.
  final String? manufacturer;

  /// Brand string, e.g. `Redmi`.
  final String? brand;

  /// Creates an identity; both fields are null on a platform without the
  /// device-info plugin (the test host, the future Windows build).
  const DeviceIdentity({this.manufacturer, this.brand});

  /// Whether anything is known at all.
  bool get isEmpty =>
      (manufacturer ?? '').isEmpty && (brand ?? '').isEmpty;
}

/// The guide's decision for one device.
class OemGuidePlan {
  /// Detected family.
  final OemFamily family;

  /// Steps to show, in the order the user should do them.
  final List<OemGuideStepId> steps;

  /// Creates a plan.
  const OemGuidePlan(this.family, this.steps);

  /// Whether the plan has anything to show.
  bool get isEmpty => steps.isEmpty;

  /// Whether this phone family needs the auto-start step.
  bool get requiresAutoStart => steps.contains(OemGuideStepId.autoStart);
}

/// Answers the plan for [device]'s reported manufacturer/brand.
OemGuidePlan oemGuidePlanFor(DeviceIdentity device) {
  final family = oemFamilyFor(device);
  return OemGuidePlan(family, switch (family) {
    // These OEMs kill background work outright: auto-start first, then battery.
    OemFamily.xiaomi ||
    OemFamily.oppo ||
    OemFamily.vivo ||
    OemFamily.huawei ||
    OemFamily.infinix => const [
      OemGuideStepId.autoStart,
      OemGuideStepId.batteryUnrestricted,
      OemGuideStepId.exactAlarms,
    ],
    // No auto-start concept, but battery limits and the exact-alarm gate exist.
    OemFamily.samsung || OemFamily.generic => const [
      OemGuideStepId.batteryUnrestricted,
      OemGuideStepId.exactAlarms,
    ],
  });
}

/// Classifies the reported manufacturer/brand into a family.
///
/// Matching is a case-insensitive contains over both strings, because Android
/// reports the split differently per OEM (`Xiaomi`/`Redmi`, `OPPO`/`realme`).
OemFamily oemFamilyFor(DeviceIdentity device) {
  final haystack = [
    device.manufacturer ?? '',
    device.brand ?? '',
  ].join(' ').toLowerCase();

  bool has(List<String> needles) => needles.any(haystack.contains);

  if (has(const ['xiaomi', 'redmi', 'poco'])) return OemFamily.xiaomi;
  if (has(const ['oppo', 'realme', 'oneplus'])) return OemFamily.oppo;
  if (has(const ['vivo', 'iqoo'])) return OemFamily.vivo;
  if (has(const ['huawei', 'honor'])) return OemFamily.huawei;
  if (has(const ['infinix', 'tecno', 'itel'])) return OemFamily.infinix;
  if (has(const ['samsung'])) return OemFamily.samsung;
  return OemFamily.generic;
}

/// Whether the guide should open by itself once on first launch.
///
/// Only the families with an auto-start manager are intrusive enough to warrant
/// it; everyone else reaches the guide from Settings → Notifications (and the
/// reminder banner), which keeps the app from greeting a Pixel owner with a
/// setup screen they do not need.
bool isAggressiveOem(DeviceIdentity device) => switch (oemFamilyFor(device)) {
  OemFamily.xiaomi ||
  OemFamily.oppo ||
  OemFamily.vivo ||
  OemFamily.huawei ||
  OemFamily.infinix => true,
  OemFamily.samsung || OemFamily.generic => false,
};

/// Settings pages to try, in order, for [step].
///
/// Always ends with [OemSettingsTarget.appDetails] so "Take Me There" has
/// somewhere to land on a phone whose OEM page is missing or renamed.
List<OemSettingsTarget> settingsTargetsFor(OemGuideStepId step) =>
    switch (step) {
      OemGuideStepId.autoStart => const [
        OemSettingsTarget.autoStart,
        OemSettingsTarget.appDetails,
      ],
      OemGuideStepId.batteryUnrestricted => const [
        OemSettingsTarget.batteryOptimization,
        OemSettingsTarget.appDetails,
      ],
      OemGuideStepId.exactAlarms => const [
        OemSettingsTarget.exactAlarms,
        OemSettingsTarget.appDetails,
      ],
    };
