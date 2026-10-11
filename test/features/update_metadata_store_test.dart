/// Guards the updater's stored preferences (update_metadata_store.dart).
///
/// The offline streak is the part worth pinning: it counts consecutive skipped
/// days, resets on a successful online check, and arms the day-8 toast only
/// once per streak. A bug here would either nag forever or never notify.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:legal_case_diary/features/settings/data/update_metadata_store.dart';
import 'package:legal_case_diary/shared/providers/shared_preferences_provider.dart';

void main() {
  late ProviderContainer container;

  Future<ProviderContainer> makeContainer([Map<String, Object> initial = const {}])
      async {
    SharedPreferences.setMockInitialValues(initial);
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('defaults: every day, no streak, nothing known', () async {
    container = await makeContainer();
    final m = container.read(updateMetadataProvider);
    expect(m.frequencyDays, defaultUpdateFrequencyDays);
    expect(m.lastCheckedAt, isNull);
    expect(m.offlineCheckDays, 0);
    expect(m.offlineNoticeShown, isFalse);
    expect(m.latestKnownVersion, isNull);
  });

  test('the frequency is stored and re-read', () async {
    container = await makeContainer();
    await container.read(updateMetadataProvider.notifier).setFrequencyDays(7);
    expect(container.read(updateMetadataProvider).frequencyDays, 7);
  });

  test('an offline check counts a day; an online check resets the streak',
      () async {
    container = await makeContainer();
    final notifier = container.read(updateMetadataProvider.notifier);

    await notifier.recordCheck(atEpochMs: 1, offline: true);
    await notifier.recordCheck(atEpochMs: 2, offline: true);
    expect(container.read(updateMetadataProvider).offlineCheckDays, 2);

    // Success resets the count and clears the toast arming.
    await notifier.recordCheck(atEpochMs: 3, offline: false);
    final after = container.read(updateMetadataProvider);
    expect(after.offlineCheckDays, 0);
    expect(after.offlineNoticeShown, isFalse);
  });

  test('a release version is remembered, and survives an offline check',
      () async {
    container = await makeContainer();
    final notifier = container.read(updateMetadataProvider.notifier);

    await notifier.recordCheck(
      atEpochMs: 1,
      releaseVersion: '0.0.480',
      offline: false,
    );
    expect(container.read(updateMetadataProvider).latestKnownVersion, '0.0.480');

    // An offline check names no release, so the last known one stands.
    await notifier.recordCheck(atEpochMs: 2, offline: true);
    expect(container.read(updateMetadataProvider).latestKnownVersion, '0.0.480');
  });

  test('the toast is armed once and stays suppressed within the streak',
      () async {
    container = await makeContainer();
    final notifier = container.read(updateMetadataProvider.notifier);

    await notifier.markOfflineNoticeShown();
    expect(container.read(updateMetadataProvider).offlineNoticeShown, isTrue);

    // A further offline day does not clear it — the streak is still running.
    await notifier.recordCheck(atEpochMs: 1, offline: true);
    expect(container.read(updateMetadataProvider).offlineNoticeShown, isTrue);
  });

  test('stored values are read back on a fresh container', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      updateFrequencyDaysKey: 30,
      updateOfflineCheckDaysKey: 5,
      updateOfflineNoticeShownKey: true,
      updateLatestKnownVersionKey: '0.0.481',
      updateLastCheckedAtKey: 1234,
    });
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(c.dispose);

    final m = c.read(updateMetadataProvider);
    expect(m.frequencyDays, 30);
    expect(m.offlineCheckDays, 5);
    expect(m.offlineNoticeShown, isTrue);
    expect(m.latestKnownVersion, '0.0.481');
    expect(m.lastCheckedAt, 1234);
  });
}