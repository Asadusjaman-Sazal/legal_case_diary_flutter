/// Tests for the OEM battery-guide policy (Task 13 Phase 3).
///
/// Which phones need the guide, which steps they get and in what order is pure
/// policy, so it is pinned here rather than on a device: the widget tests then
/// only have to prove the screen renders and wires that policy up.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/core/notifications/oem_setup_guide.dart';

DeviceIdentity _device(String? manufacturer, [String? brand]) =>
    DeviceIdentity(manufacturer: manufacturer, brand: brand);

void main() {
  group('family detection', () {
    test('recognizes the OEMs the plan names', () {
      expect(oemFamilyFor(_device('Xiaomi')), OemFamily.xiaomi);
      expect(oemFamilyFor(_device('Redmi', 'Redmi')), OemFamily.xiaomi);
      expect(oemFamilyFor(_device('POCO')), OemFamily.xiaomi);
      expect(oemFamilyFor(_device('OPPO')), OemFamily.oppo);
      expect(oemFamilyFor(_device('realme')), OemFamily.oppo);
      expect(oemFamilyFor(_device('OnePlus')), OemFamily.oppo);
      expect(oemFamilyFor(_device('vivo')), OemFamily.vivo);
      expect(oemFamilyFor(_device('iQOO')), OemFamily.vivo);
      expect(oemFamilyFor(_device('HUAWEI')), OemFamily.huawei);
      expect(oemFamilyFor(_device('HONOR')), OemFamily.huawei);
      expect(oemFamilyFor(_device('Infinix')), OemFamily.infinix);
      expect(oemFamilyFor(_device('TECNO')), OemFamily.infinix);
      expect(oemFamilyFor(_device('itel')), OemFamily.infinix);
      expect(oemFamilyFor(_device('samsung')), OemFamily.samsung);
    });

    test('falls back to generic for anything else, including nothing', () {
      // The brand field is checked too: some OEMs report only one of the two.
      expect(oemFamilyFor(_device('Google', 'Pixel 8')), OemFamily.generic);
      expect(oemFamilyFor(_device(null, 'Redmi Note 12')), OemFamily.xiaomi);
      expect(oemFamilyFor(const DeviceIdentity()), OemFamily.generic);
      expect(const DeviceIdentity().isEmpty, isTrue);
    });
  });

  group('first-launch aggressiveness', () {
    test('only the auto-start families are offered the guide', () {
      expect(isAggressiveOem(_device('Xiaomi')), isTrue);
      expect(isAggressiveOem(_device('OPPO')), isTrue);
      expect(isAggressiveOem(_device('vivo')), isTrue);
      expect(isAggressiveOem(_device('HUAWEI')), isTrue);
      expect(isAggressiveOem(_device('Tecno')), isTrue);
    });

    test('phones that need nothing are left alone', () {
      expect(isAggressiveOem(_device('Google', 'Pixel 8')), isFalse);
      expect(isAggressiveOem(_device('samsung')), isFalse);
      expect(isAggressiveOem(const DeviceIdentity()), isFalse);
    });
  });

  group('steps', () {
    test('an aggressive OEM gets auto-start, battery and exact alarms, in order', () {
      final plan = oemGuidePlanFor(_device('Xiaomi', 'Redmi'));
      expect(plan.family, OemFamily.xiaomi);
      expect(plan.steps, const [
        OemGuideStepId.autoStart,
        OemGuideStepId.batteryUnrestricted,
        OemGuideStepId.exactAlarms,
      ]);
      expect(plan.requiresAutoStart, isTrue);
      expect(plan.isEmpty, isFalse);
    });

    test('Samsung and unknown phones get the two standard steps', () {
      for (final plan in [
        oemGuidePlanFor(_device('samsung')),
        oemGuidePlanFor(_device('Google', 'Pixel 8')),
        oemGuidePlanFor(const DeviceIdentity()),
      ]) {
        expect(plan.steps, const [
          OemGuideStepId.batteryUnrestricted,
          OemGuideStepId.exactAlarms,
        ]);
        // No auto-start manager exists there, so the step is not shown.
        expect(plan.requiresAutoStart, isFalse);
      }
    });
  });

  group('settings targets', () {
    test('each step ends at the app details page, which always exists', () {
      for (final step in OemGuideStepId.values) {
        final targets = settingsTargetsFor(step);
        expect(targets, isNotEmpty, reason: '$step');
        expect(targets.last, OemSettingsTarget.appDetails, reason: '$step');
      }
    });

    test('each step tries its own page before the fallback', () {
      expect(settingsTargetsFor(OemGuideStepId.autoStart), const [
        OemSettingsTarget.autoStart,
        OemSettingsTarget.appDetails,
      ]);
      expect(settingsTargetsFor(OemGuideStepId.batteryUnrestricted), const [
        OemSettingsTarget.batteryOptimization,
        OemSettingsTarget.appDetails,
      ]);
      expect(settingsTargetsFor(OemGuideStepId.exactAlarms), const [
        OemSettingsTarget.exactAlarms,
        OemSettingsTarget.appDetails,
      ]);
    });
  });
}
