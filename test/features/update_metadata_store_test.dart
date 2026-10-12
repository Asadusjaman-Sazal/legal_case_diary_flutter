/// Guards the updater's stored preferences (update_metadata_store.dart).
///
/// The rules worth pinning: the offline streak counts consecutive skipped days
/// and resets on a successful online check; an online check either stores the
/// release it found or clears the offer (which is what stops the dot outliving
/// the update); a skipped version stops being offered; and the network
/// preference defaults to Wi-Fi.
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:legal_case_diary/features/settings/data/update_metadata_store.dart';
import 'package:legal_case_diary/features/settings/data/update_release.dart';
import 'package:legal_case_diary/shared/providers/shared_preferences_provider.dart';

/// A release far ahead of whatever is bundled, so it always counts as newer.
const AppRelease _newerRelease = AppRelease(
  version: '99.99.999',
  downloadUrl: 'https://example.test/app.apk',
  size: 100,
);

void main() {
  late ProviderContainer container;

  Future<ProviderContainer> makeContainer([
    Map<String, Object> initial = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(initial);
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('defaults: every day, Wi-Fi only, no streak, nothing offered', () async {
    container = await makeContainer();
    final m = container.read(updateMetadataProvider);
    expect(m.frequencyDays, defaultUpdateFrequencyDays);
    expect(m.network, UpdateNetwork.wifi);
    expect(m.lastCheckedAt, isNull);
    expect(m.offlineCheckDays, 0);
    expect(m.offlineNoticeShown, isFalse);
    expect(m.availableRelease, isNull);
    expect(m.skippedVersion, isNull);
  });

  test('the frequency and the network are stored and re-read', () async {
    container = await makeContainer();
    await container.read(updateMetadataProvider.notifier).setFrequencyDays(7);
    await container
        .read(updateMetadataProvider.notifier)
        .setNetwork(UpdateNetwork.mobileData);
    expect(container.read(updateMetadataProvider).frequencyDays, 7);
    expect(container.read(updateMetadataProvider).network, UpdateNetwork.mobileData);
  });

  test('an offline check counts a day; an online check resets the streak',
      () async {
    container = await makeContainer();
    final notifier = container.read(updateMetadataProvider.notifier);

    await notifier.recordCheck(atEpochMs: 1, offline: true);
    await notifier.recordCheck(atEpochMs: 2, offline: true);
    expect(container.read(updateMetadataProvider).offlineCheckDays, 2);

    await notifier.recordCheck(atEpochMs: 3, offline: false);
    final after = container.read(updateMetadataProvider);
    expect(after.offlineCheckDays, 0);
    expect(after.offlineNoticeShown, isFalse);
  });

  test('a found release is stored, and survives an offline check', () async {
    container = await makeContainer();
    final notifier = container.read(updateMetadataProvider.notifier);

    await notifier.recordCheck(
      atEpochMs: 1,
      offline: false,
      release: _newerRelease,
    );
    expect(
      container.read(updateMetadataProvider).availableRelease?.version,
      '99.99.999',
    );

    // An offline check learned nothing, so the offer stands.
    await notifier.recordCheck(atEpochMs: 2, offline: true);
    expect(
      container.read(updateMetadataProvider).availableRelease?.version,
      '99.99.999',
    );
  });

  test('an online check that finds nothing clears the offer', () async {
    // This is what keeps the dot from outliving the update it pointed at.
    container = await makeContainer();
    final notifier = container.read(updateMetadataProvider.notifier);

    await notifier.recordCheck(atEpochMs: 1, offline: false, release: _newerRelease);
    expect(container.read(updateMetadataProvider).availableRelease, isNotNull);

    await notifier.recordCheck(atEpochMs: 2, offline: false);
    expect(container.read(updateMetadataProvider).availableRelease, isNull);
  });

  test('clearAvailableRelease drops a stored offer', () async {
    container = await makeContainer();
    final notifier = container.read(updateMetadataProvider.notifier);
    await notifier.recordCheck(atEpochMs: 1, offline: false, release: _newerRelease);

    await notifier.clearAvailableRelease();
    expect(container.read(updateMetadataProvider).availableRelease, isNull);
  });

  test('a skipped version stops being offered, until a newer one appears',
      () async {
    container = await makeContainer();
    final notifier = container.read(updateMetadataProvider.notifier);
    await notifier.recordCheck(atEpochMs: 1, offline: false, release: _newerRelease);

    // Offered to begin with.
    expect(container.read(updateAvailableProvider), isNotNull);

    await notifier.skipVersion('99.99.999');
    expect(container.read(updateAvailableProvider), isNull);

    // A newer release than the skipped one is offered again.
    await notifier.recordCheck(
      atEpochMs: 2,
      offline: false,
      release: const AppRelease(
        version: '99.99.1000',
        downloadUrl: 'https://example.test/app.apk',
      ),
    );
    expect(
      container.read(updateAvailableProvider)?.version,
      '99.99.1000',
    );
  });

  test('Later hides the offer for this session only', () async {
    container = await makeContainer();
    final notifier = container.read(updateMetadataProvider.notifier);
    await notifier.recordCheck(atEpochMs: 1, offline: false, release: _newerRelease);
    expect(container.read(updateAvailableProvider), isNotNull);

    container.read(updateDeferredProvider.notifier).defer();
    expect(container.read(updateAvailableProvider), isNull);
    // The deferred release is still stored: only the dot is silenced, and a
    // fresh launch (a fresh container) shows it again.
    expect(container.read(updateMetadataProvider).availableRelease, isNotNull);

    final restarted = await makeContainer();
    expect(restarted.read(updateDeferredProvider), isFalse);
  });

  test('a release this build already has is never offered', () async {
    // The stored offer outlives the check that found it, so it is guarded on
    // read as well as on write.
    container = await makeContainer(<String, Object>{
      updateAvailableReleaseKey: jsonEncode(<String, Object?>{
        'version': '0.0.1',
        'url': 'https://example.test/app.apk',
      }),
    });
    expect(container.read(updateAvailableProvider), isNull);
  });

  test('the toast is armed once and stays suppressed within the streak',
      () async {
    container = await makeContainer();
    final notifier = container.read(updateMetadataProvider.notifier);

    await notifier.markOfflineNoticeShown();
    expect(container.read(updateMetadataProvider).offlineNoticeShown, isTrue);

    await notifier.recordCheck(atEpochMs: 1, offline: true);
    expect(container.read(updateMetadataProvider).offlineNoticeShown, isTrue);
  });

  test('stored values are read back on a fresh container', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      updateFrequencyDaysKey: 30,
      updateNetworkKey: 'mobileData',
      updateOfflineCheckDaysKey: 5,
      updateOfflineNoticeShownKey: true,
      updateSkippedVersionKey: '1.2.3',
      updateLastCheckedAtKey: 1234,
      updateAvailableReleaseKey: jsonEncode(<String, Object?>{
        'version': '99.99.999',
        'url': 'https://example.test/app.apk',
        'size': 42,
      }),
    });
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(c.dispose);

    final m = c.read(updateMetadataProvider);
    expect(m.frequencyDays, 30);
    expect(m.network, UpdateNetwork.mobileData);
    expect(m.offlineCheckDays, 5);
    expect(m.offlineNoticeShown, isTrue);
    expect(m.skippedVersion, '1.2.3');
    expect(m.lastCheckedAt, 1234);
    expect(m.availableRelease?.version, '99.99.999');
    expect(m.availableRelease?.size, 42);
  });

  test('a corrupt stored release reads as no offer, not a crash', () async {
    container = await makeContainer(<String, Object>{
      updateAvailableReleaseKey: '{not json',
    });
    expect(container.read(updateMetadataProvider).availableRelease, isNull);
  });
}