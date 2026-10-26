/// Bundled application version shown on the About screens.
///
/// The value is bundled at build time instead of being read from disk, and it
/// must stay equal to `version:` in `pubspec.yaml` and to the `## Current
/// Version` line in `docs/version_history.md`.
/// `test/core/app_version_test.dart` fails when the three drift, and
/// `python tool/record_version.py` writes all three together, so a version
/// bump cannot silently leave this constant behind.
library;

/// User-facing version string, e.g. `0.0.226`.
const String appVersion = '0.0.662';
