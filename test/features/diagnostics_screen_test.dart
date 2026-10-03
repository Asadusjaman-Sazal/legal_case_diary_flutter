/// The Diagnostics viewer: the one screen whose whole job is being readable.
///
/// What it has to prove is small and worth pinning: an empty log says so instead
/// of drawing a blank page, a recorded failure is shown with the area it
/// happened in, and clearing really empties the log it was handed.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/core/errors/error_log.dart';
import 'package:legal_case_diary/core/errors/error_log_provider.dart';
import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/theme/app_theme.dart';
import 'package:legal_case_diary/features/settings/presentation/settings_about/diagnostics_screen.dart';

void main() {
  late AppLocalizations l;

  Future<void> pump(WidgetTester tester, ErrorLog log) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [errorLogProvider.overrideWithValue(log)],
        child: MaterialApp(
          theme: AppTheme.lightTheme(const Locale('en')),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const DiagnosticsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    l = await AppLocalizations.delegate.load(const Locale('en'));
  }

  testWidgets('an empty log says so rather than showing a blank page', (
    tester,
  ) async {
    await pump(tester, ErrorLog());

    expect(find.text(l.settingsDiagnostics_empty), findsOneWidget);
    // Nothing to clear, so nothing offers to.
    expect(find.text(l.settingsDiagnostics_clear), findsNothing);
  });

  testWidgets('a recorded failure is listed with its area and label', (
    tester,
  ) async {
    final log = ErrorLog();
    await log.record('auth.recover', StateError('boom'));

    await pump(tester, log);

    expect(find.text('StateError'), findsOneWidget);
    expect(find.textContaining('auth.recover'), findsOneWidget);
    expect(find.text(l.settingsDiagnostics_empty), findsNothing);
    expect(find.text(l.settingsDiagnostics_clear), findsOneWidget);
  });

  testWidgets('clearing the log empties it and says so', (tester) async {
    final log = ErrorLog();
    await log.record('sync.push', StateError('boom'));

    await pump(tester, log);
    await tester.tap(find.text(l.settingsDiagnostics_clear));
    await tester.pumpAndSettle();

    expect(log.entries, isEmpty);
    expect(find.text(l.settingsDiagnostics_cleared), findsOneWidget);
    expect(find.text(l.settingsDiagnostics_empty), findsOneWidget);
    expect(find.text(l.settingsDiagnostics_clear), findsNothing);
  });
}
