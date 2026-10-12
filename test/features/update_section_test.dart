/// Guards the About screen's Update sub-page (all three cards).
///
/// Pins what the section promises: the App Update card defaults unfolded with
/// the current version, a check moves through Checking → Update Now (green
/// tick on the latest), and the Auto Check for Update card defaults folded
/// frequency radio list. The network is faked — an injected [UpdateRepository]
/// without any HTTP — so the section can be driven end to end on the test
/// clock.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/providers/repository_providers.dart';
import 'package:legal_case_diary/core/constants/app_version.dart';
import 'package:legal_case_diary/features/settings/data/update_metadata_store.dart';
import 'package:legal_case_diary/features/settings/data/update_release.dart';
import 'package:legal_case_diary/features/settings/data/update_repository.dart';
import 'package:legal_case_diary/features/settings/presentation/update_screen.dart';
import 'package:legal_case_diary/shared/providers/shared_preferences_provider.dart';
import 'package:legal_case_diary/sync/connectivity_monitor.dart';

import '../test_utils.dart';

/// A repository that answers from memory with no HTTP.
class _FakeUpdateRepository extends UpdateRepository {
  _FakeUpdateRepository({this.outcome});

  UpdateCheckOutcome? outcome;

  @override
  Future<UpdateCheckOutcome> checkForLatestRelease() async =>
      outcome ?? const UpdateCheckOutcome(ReleaseCheckResult.upToDate);
}

/// A monitor that is online, and answers the cellular question as told.
class _FakeMonitor implements ConnectivityMonitor {
  _FakeMonitor({this.onMobileData = false});

  bool onMobileData;

  @override
  Future<bool> isOnline() async => true;

  @override
  Future<bool> isOnMobileData() async => onMobileData;

  @override
  Stream<bool> get onlineChanges => const Stream<bool>.empty();
}

/// A repository that records what it was asked to download.
///
/// The download is a real file write that a widget test's fake clock cannot
/// drive, so what these tests assert is that it was **asked for** (or not) —
/// the bytes and the size check have their own coverage.
class _RecordingUpdateRepository extends _FakeUpdateRepository {
  final List<String> downloads = <String>[];

  _RecordingUpdateRepository({super.outcome});

  @override
  Future<DownloadProgress> downloadRelease(
    AppRelease release,
    List<int> target, {
    void Function(int received, int total)? onProgress,
  }) async {
    downloads.add(release.version);
    return (received: 0, total: 0);
  }
}

void main() {
  Future<void> pump(
    WidgetTester tester,
    _FakeUpdateRepository repo, {
    Locale locale = const Locale('en'),
    ConnectivityMonitor? monitor,
    Size surface = const Size(420, 1400),
  }) async {
    // The cards read the shared store behind their frequency radios.
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    // The window size matters here: the network buttons measure themselves
    // against the width they are given.
    tester.view.physicalSize = surface;
    tester.view.devicePixelRatio = 1.0;
    await tester.binding.setSurfaceSize(surface);
    addTearDown(tester.view.reset);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: withErrorLog(<Override>[
          updateRepositoryProvider.overrideWithValue(repo),
          sharedPreferencesProvider.overrideWithValue(prefs),
          if (monitor != null)
            connectivityMonitorProvider.overrideWithValue(monitor),
        ]),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: locale,
          home: const UpdateScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the App Update card defaults unfolded with the current version', (
    tester,
  ) async {
    await pump(tester, _FakeUpdateRepository());

    expect(find.byKey(const ValueKey('update-app-update')), findsOneWidget);
    expect(find.text('Current Version: V$appVersion'), findsOneWidget);
    expect(find.text('Check for update'), findsOneWidget);
    // Auto Check is folded by default, so its radio list is off-screen.
    expect(find.text('Off'), findsNothing);
  });

  testWidgets('Auto Check for Update is folded and opens its frequency list', (
    tester,
  ) async {
    await pump(tester, _FakeUpdateRepository());

    // Folded: the radio list is not on screen. The name says "check", because
    // the app cannot auto-install — an APK always needs the OS installer's
    // own confirmation.
    expect(find.text('Auto Check for Update'), findsOneWidget);
    expect(find.text('Off'), findsNothing);
    expect(find.text('Every Day'), findsNothing);

    await tester.tap(find.text('Auto Check for Update'));
    await tester.pumpAndSettle();

    expect(find.text('Off'), findsOneWidget);
    expect(find.text('Every Day'), findsOneWidget);
    expect(find.text('Every 3 Days'), findsOneWidget);
    expect(find.text('Every 7 Days'), findsOneWidget);
    expect(find.text('Every Month'), findsOneWidget);
  });

  testWidgets('Update over Network defaults folded, Wi-Fi Only selected', (
    tester,
  ) async {
    await pump(tester, _FakeUpdateRepository());

    // Folded until asked for, and the two buttons are not on screen yet.
    expect(find.text('Update over Network'), findsOneWidget);
    expect(find.text('Wi-Fi Only'), findsNothing);

    await tester.tap(find.text('Update over Network'));
    await tester.pumpAndSettle();

    expect(find.text('Wi-Fi Only'), findsOneWidget);
    expect(find.text('Wi-Fi & Mobile Data'), findsOneWidget);
    // Wi-Fi only is the default, so its button is the filled one and the
    // wider option the outlined one.
    expect(
      find.widgetWithText(FilledButton, 'Wi-Fi Only'),
      findsOneWidget,
      reason: 'Wi-Fi Only is selected by default',
    );
    expect(
      find.widgetWithText(OutlinedButton, 'Wi-Fi & Mobile Data'),
      findsOneWidget,
    );
  });

  testWidgets('the two network buttons stack when they do not fit', (
    tester,
  ) async {
    // The labels are long: on a narrow phone (and at a larger font step) equal
    // halves would clip them, so they are drawn one after another, full length.
    await pump(tester, _FakeUpdateRepository(), surface: const Size(320, 1400));

    await tester.tap(find.text('Update over Network'));
    await tester.pumpAndSettle();

    final wifi = tester.getRect(find.widgetWithText(FilledButton, 'Wi-Fi Only'));
    final both = tester.getRect(
      find.widgetWithText(OutlinedButton, 'Wi-Fi & Mobile Data'),
    );
    // Stacked: the second starts below the first, rather than beside it.
    expect(both.top, greaterThanOrEqualTo(wifi.bottom));
    // Full length, so the two buttons are the same width and each label has the
    // whole row: at half of this width the longer one would be clipped.
    expect(both.width, closeTo(wifi.width, 0.5));
    final label = tester.getSize(find.text('Wi-Fi & Mobile Data'));
    expect(
      label.width,
      lessThanOrEqualTo(both.width),
      reason: 'the label fits inside its button rather than overflowing',
    );
  });

  testWidgets('choosing Wi-Fi & Mobile Data stores it', (tester) async {
    await pump(tester, _FakeUpdateRepository());

    await tester.tap(find.text('Update over Network'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wi-Fi & Mobile Data'));
    await tester.pumpAndSettle();

    // The same mock store the helper installed, read back directly.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(updateNetworkKey), 'mobileData');
    expect(
      find.widgetWithText(FilledButton, 'Wi-Fi & Mobile Data'),
      findsOneWidget,
    );
    expect(find.widgetWithText(OutlinedButton, 'Wi-Fi Only'), findsOneWidget);
  });

  testWidgets('a newer release turns the check into Update Now with a notice', (
    tester,
  ) async {
    final repo = _FakeUpdateRepository(
      outcome: const UpdateCheckOutcome(
        ReleaseCheckResult.updateAvailable,
        release: AppRelease(
          // Far ahead of any real build, so this fixture cannot go stale as the
          // app's own version moves past a hard-coded one.
          version: '99.99.999',
          downloadUrl: 'https://example.com/app.apk',
          size: 100,
        ),
      ),
    );
    await pump(tester, repo);

    await tester.tap(find.text('Check for update'));
    await tester.pumpAndSettle();

    expect(find.text('Update Now'), findsOneWidget);
    expect(
      find.text('There is a newer version available (V99.99.999).'),
      findsOneWidget,
    );
    // And the two ways out of an offer, so it is never an unclearable badge.
    expect(find.text('Later'), findsOneWidget);
    expect(find.text('Skip This Version'), findsOneWidget);
  });

  testWidgets('Later hides the offer for this session', (tester) async {
    final repo = _FakeUpdateRepository(
      outcome: const UpdateCheckOutcome(
        ReleaseCheckResult.updateAvailable,
        release: AppRelease(
          version: '99.99.999',
          downloadUrl: 'https://example.com/app.apk',
        ),
      ),
    );
    await pump(tester, repo);

    await tester.tap(find.text('Check for update'));
    await tester.pumpAndSettle();
    expect(find.text('Update Now'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('update-later')));
    await tester.pumpAndSettle();

    // Back to at rest, with the offer gone and nothing to nag about.
    expect(find.text('Update Now'), findsNothing);
    expect(find.text('Check for update'), findsOneWidget);
    expect(find.text('Later'), findsNothing);
  });

  testWidgets('Skip This Version retires the release', (tester) async {
    final repo = _FakeUpdateRepository(
      outcome: const UpdateCheckOutcome(
        ReleaseCheckResult.updateAvailable,
        release: AppRelease(
          version: '99.99.999',
          downloadUrl: 'https://example.com/app.apk',
        ),
      ),
    );
    await pump(tester, repo);

    await tester.tap(find.text('Check for update'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('update-skip-version')));
    await tester.pumpAndSettle();

    // Checking again reports the latest version rather than re-offering the
    // release the user retired.
    await tester.tap(find.text('Check for update'));
    await tester.pumpAndSettle();

    expect(find.text('Update Now'), findsNothing);
    expect(
      find.text('You are on the latest V$appVersion version.'),
      findsOneWidget,
    );
  });

  testWidgets('Wi-Fi only asks before downloading on mobile data', (
    tester,
  ) async {
    // The default is Wi-Fi and the device is on cellular, so Update Now stops
    // at a question rather than spending the user's data behind their back.
    // What is asserted is the *decision*: the dialog appears, and cancelling
    // leaves without downloading. (The download itself is real file IO, which a
    // widget test's fake clock cannot drive — the size check and the handoff are
    // covered by their own pure test.)
    final repo = _RecordingUpdateRepository(
      outcome: const UpdateCheckOutcome(
        ReleaseCheckResult.updateAvailable,
        release: AppRelease(
          version: '99.99.999',
          downloadUrl: 'https://x.test/a',
        ),
      ),
    );
    await pump(tester, repo, monitor: _FakeMonitor(onMobileData: true));

    await tester.tap(find.text('Check for update'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Update Now'));
    await tester.pumpAndSettle();

    expect(find.text('Download Over Mobile Data?'), findsOneWidget);
    expect(repo.downloads, isEmpty, reason: 'nothing downloaded before the answer');

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repo.downloads, isEmpty, reason: 'cancelling downloads nothing');
    // And the offer is still there, so the tap can be taken again.
    expect(find.text('Update Now'), findsOneWidget);
  });

  testWidgets('Wi-Fi only does not ask on Wi-Fi', (tester) async {
    // The same tap on a Wi-Fi link goes straight through: no question.
    final repo = _RecordingUpdateRepository(
      outcome: const UpdateCheckOutcome(
        ReleaseCheckResult.updateAvailable,
        release: AppRelease(
          version: '99.99.999',
          downloadUrl: 'https://x.test/a',
        ),
      ),
    );
    await pump(tester, repo, monitor: _FakeMonitor(onMobileData: false));

    await tester.tap(find.text('Check for update'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Update Now'));
    await tester.pump();

    expect(find.text('Download Over Mobile Data?'), findsNothing);
  });

  testWidgets('a failed check shows the sentence, not the raw cause', (
    tester,
  ) async {
    final repo = _FakeUpdateRepository(
      outcome: const UpdateCheckOutcome(
        ReleaseCheckResult.unavailable,
        error: 'GitHub responded 403',
      ),
    );
    await pump(tester, repo);

    await tester.tap(find.text('Check for update'));
    await tester.pumpAndSettle();

    // The technical cause is logged, never shown: a Bengali user must not be
    // handed raw English developer text.
    expect(find.text('GitHub responded 403'), findsNothing);
    expect(
      find.text(
        'Could not check for an update right now. Please try again later.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('no newer release shows the green latest line', (tester) async {
    await pump(tester, _FakeUpdateRepository());

    await tester.tap(find.text('Check for update'));
    await tester.pumpAndSettle();

    expect(
      find.text('You are on the latest V$appVersion version.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });
}