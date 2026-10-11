/// Guards the release-version comparison (update_release.dart).
///
/// Pure Dart, no Flutter: the About screen's update check decides "is there a
/// newer release?" from these two functions, so the semantics of a dotted
/// numeric version string are pinned here exactly where they are decided.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/features/settings/data/update_release.dart';

void main() {
  group('compareReleaseVersions', () {
    test('a higher patch is newer', () {
      expect(compareReleaseVersions('0.0.480', '0.0.479') > 0, isTrue);
    });

    test('a higher minor beats a higher patch', () {
      expect(compareReleaseVersions('0.1.0', '0.0.480') > 0, isTrue);
    });

    test('a higher major beats everything else', () {
      expect(compareReleaseVersions('1.0.0', '0.99.999') > 0, isTrue);
    });

    test('equal versions compare equal, with or without the leading v', () {
      expect(compareReleaseVersions('0.0.479', 'v0.0.479'), 0);
      expect(compareReleaseVersions('V0.0.479', '0.0.479'), 0);
    });

    test('0.0.9 is older than 0.0.479 (no digit-length illusion)', () {
      expect(compareReleaseVersions('0.0.9', '0.0.479') < 0, isTrue);
    });

    test('a malformed string never claims to be newer', () {
      expect(compareReleaseVersions('garbage', '0.0.479') < 0, isTrue);
      expect(compareReleaseVersions('0.0.479', 'not-a-version') > 0, isTrue);
      expect(compareReleaseVersions('0.0', '0.0.479') < 0, isTrue);
    });
  });

  test('isReleaseNewerThanApp is true only for a release the app does not have',
      () {
    // Depends on the live bundled version: whatever the app is, a far-future
    // number is newer and the matching tag is not.
    expect(isReleaseNewerThanApp('99.99.999'), isTrue);
    expect(isReleaseNewerThanApp('0.0.1'), isFalse);
  });

  test('a release displays its version with the leading V', () {
    const release = AppRelease(version: '0.0.480', downloadUrl: 'https://x');
    expect(release.displayName, 'V0.0.480');
  });
}