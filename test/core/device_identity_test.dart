/// The install key must be this install's own, not the Android build ID.
///
/// Two Redmi Note 10 Pro handsets reported one build ID, collided on the
/// server's active-device index and broke registration. These pin the fix: the
/// key comes from storage, is reused across service instances, and the label is
/// never the generic fallback that made the server column read "This device".
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:legal_case_diary/core/devices/device_identity.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the install key is stable across resolves and instances', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final first = await DeviceIdentityService().resolve();
    final second = await DeviceIdentityService().resolve();

    expect(second.key, first.key);
    expect(first.key, isNot(DeviceIdentity.fallback.key));
    expect(first.key.length, greaterThan(8));
    expect(first.label, isNot('This device'));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(DeviceIdentityService.keyPreference), first.key);
  });

  test('a stored install key is reused', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      DeviceIdentityService.keyPreference: 'stored-install-key',
    });

    final identity = await DeviceIdentityService().resolve();

    expect(identity.key, 'stored-install-key');
  });
}
