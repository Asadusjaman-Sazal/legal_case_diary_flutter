/// Guards the About screen's Update section (App Update + Auto Update).
///
/// Pins what the section promises: the App Update card defaults unfolded with
/// the current version, a check moves through Checking → Update Now (green
/// tick on the latest), and the Auto Update card defaults folded with the
/// frequency radio list. The network is faked — an injected [UpdateRepository]
/// without any HTTP — so the section can be driven end to end on the test
/// clock.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/providers/repository_providers.dart';
import 'package:legal_case_diary/core/constants/app_version.dart';
import 'package:legal_case_diary/features/settings/data/update_release.dart';
import 'package:legal_case_diary/features/settings/data/update_repository.dart';
import 'package:legal_case_diary/features/settings/presentation/update_section_container.dart';
import 'package:legal_case_diary/shared/providers/shared_preferences_provider.dart';

/// A repository that answers from memory with no HTTP.
class _FakeUpdateRepository extends UpdateRepository {
  _FakeUpdateRepository({this.outcome});

  UpdateCheckOutcome? outcome;

  @override
  Future<UpdateCheckOutcome> checkForLatestRelease() async =>
      outcome ?? const UpdateCheckOutcome(ReleaseCheckResult.upToDate);
}

void main() {
  Future<void> pump(
    WidgetTester tester,
    _FakeUpdateRepository repo, {
    Locale locale = const Locale('en'),
  }) async {
    // The Auto Update card reads the shared store behind its frequency radios.
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    await tester.binding.setSurfaceSize(const Size(420, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          updateRepositoryProvider.overrideWithValue(repo),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: locale,
          home: const Scaffold(body: SingleChildScrollView(child: UpdateSectionContainer())),
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
    expect(find.text('Check For Update'), findsOneWidget);
    // Auto Update is folded by default, so its radio list is off-screen.
    expect(find.text('Off'), findsNothing);
  });

  testWidgets('Auto Update defaults folded and opens its frequency list', (
    tester,
  ) async {
    await pump(tester, _FakeUpdateRepository());

    // Folded: the radio list is not on screen.
    expect(find.text('Off'), findsNothing);
    expect(find.text('Every Day'), findsNothing);

    await tester.tap(find.text('Auto Update'));
    await tester.pumpAndSettle();

    expect(find.text('Off'), findsOneWidget);
    expect(find.text('Every Day'), findsOneWidget);
    expect(find.text('Every 3 Days'), findsOneWidget);
    expect(find.text('Every 7 Days'), findsOneWidget);
    expect(find.text('Every Month'), findsOneWidget);
  });

  testWidgets('a newer release turns the check into Update Now with a notice', (
    tester,
  ) async {
    final repo = _FakeUpdateRepository(
      outcome: const UpdateCheckOutcome(
        ReleaseCheckResult.updateAvailable,
        release: AppRelease(
          version: '0.0.480',
          downloadUrl: 'https://example.com/app.apk',
          size: 100,
        ),
      ),
    );
    await pump(tester, repo);

    await tester.tap(find.text('Check For Update'));
    await tester.pumpAndSettle();

    expect(find.text('Update Now'), findsOneWidget);
    expect(find.text('There Is A Newer Version Available (V0.0.480).'), findsOneWidget);
  });

  testWidgets('no newer release shows the green latest line', (tester) async {
    await pump(tester, _FakeUpdateRepository());

    await tester.tap(find.text('Check For Update'));
    await tester.pumpAndSettle();

    expect(find.text('You\'re On The Latest Version.'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });
}