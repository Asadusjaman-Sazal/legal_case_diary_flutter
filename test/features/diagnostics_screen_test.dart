/// The Diagnostics viewer: the one screen whose whole job is being readable.
///
/// What it has to prove is small and worth pinning: an empty log says so instead
/// of drawing a blank page, a recorded failure is shown with the area it
/// happened in, and clearing really empties the log it was handed.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/core/errors/error_log.dart';
import 'package:legal_case_diary/core/errors/error_log_provider.dart';
import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/theme/app_theme.dart';
import 'package:legal_case_diary/features/auth/data/auth_repository.dart';
import 'package:legal_case_diary/core/providers/contact_providers.dart';
import 'package:legal_case_diary/core/services/contact_launcher.dart';
import 'package:legal_case_diary/features/settings/data/support_diagnostics.dart';
import 'package:legal_case_diary/features/settings/presentation/settings_about/diagnostics_screen.dart';

/// Installs a clipboard channel handler and hands back a reader for the last
/// text the screen copied.
///
/// The screen's real `Clipboard.setData` call is what gets observed here, not a
/// stubbed helper, so the test fails if the report ever stops being what is put
/// on the clipboard.
String? Function() watchClipboard(WidgetTester tester) {
  final messenger = tester.binding.defaultBinaryMessenger;
  final copied = <String>[];
  messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'Clipboard.setData') {
      final arguments = call.arguments as Map<Object?, Object?>;
      copied
        ..clear()
        ..add(arguments['text']! as String);
    }
    return null;
  });
  addTearDown(
    () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
  );
  return () => copied.isEmpty ? null : copied.last;
}

/// A device-facts reader that answers with fixed facts.
class _FixedFacts implements SupportDeviceFactsReader {
  const _FixedFacts(this.facts);
  final SupportDeviceFacts facts;
  @override
  Future<SupportDeviceFacts> read() async => facts;
}

/// A launcher that records the URIs it was asked to open.
class _RecordingLauncher implements ContactLauncher {
  _RecordingLauncher({this.result = true});
  final bool result;
  final List<Uri> opened = <Uri>[];
  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return result;
  }

  @override
  Future<bool> openMailApp() async => result;
}

/// The message a launched URI carries, decoded.
String sentMessage(Uri uri) => uri.host == 'wa.me'
    ? uri.queryParameters['text']!
    : uri.queryParameters['body']!;

void main() {
  late AppLocalizations l;

  Future<void> pump(
    WidgetTester tester,
    ErrorLog log, {
    ContactLauncher? launcher,
    SupportDeviceFacts facts = const SupportDeviceFacts(
      model: 'Redmi Note 10',
      osVersion: 'Android 13',
    ),
  }) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          errorLogProvider.overrideWithValue(log),
          // The Report button reaches the same two seams the Support screen
          // does, so no test needs WhatsApp installed or a real phone.
          supportDeviceFactsProvider.overrideWithValue(
            _FixedFacts(facts),
          ),
          if (launcher != null)
            contactLauncherProvider.overrideWithValue(launcher),
        ],
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
    // Nothing to copy and nothing to clear, so neither is offered.
    expect(find.text(l.settingsDiagnostics_copy), findsNothing);
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

  testWidgets('the actions sit in the body, above the log, not in the header', (
    tester,
  ) async {
    final log = ErrorLog();
    await log.record('sync.push', StateError('boom'));

    await pump(tester, log);
    // Re-pumped at 360dp, the narrowest target (the test phone is 1080px at
    // 3x): a layout that overflows or clips there fails here rather than on a
    // device.
    await tester.binding.setSurfaceSize(const Size(360, 900));
    await tester.pumpAndSettle();

    final copy = find.text(l.settingsDiagnostics_copy);
    final clear = find.text(l.settingsDiagnostics_clear);
    expect(copy, findsOneWidget);
    expect(clear, findsOneWidget);

    // The header keeps the title and the back button alone.
    expect(
      find.descendant(of: find.byType(AppBar), matching: copy),
      findsNothing,
    );
    expect(
      find.descendant(of: find.byType(AppBar), matching: clear),
      findsNothing,
    );

    // Both sit above the entries they act on: the button's bottom edge is
    // above the first entry's top edge.
    final entryTop = tester.getRect(find.text('StateError')).top;
    expect(tester.getRect(copy).bottom, lessThan(entryTop));
    expect(tester.getRect(clear).bottom, lessThan(entryTop));
  });

  testWidgets('a recorded failure shows its own message, not just its type', (
    tester,
  ) async {
    // The label names the type; the line under it is what a reader fixes from —
    // a `FlutterError` row with no message was the complaint that set this
    // policy (0.0.406).
    final log = ErrorLog();
    await log.record(
      'auth.recover',
      StateError('the reset mail could not be sent'),
    );

    await pump(tester, log);

    expect(find.text('StateError'), findsOneWidget);
    expect(
      find.text('Bad state: the reset mail could not be sent'),
      findsOneWidget,
    );
  });

  testWidgets('copying puts the whole report on the clipboard and says so', (
    tester,
  ) async {
    final clipboard = watchClipboard(tester);
    final log = ErrorLog();
    await log.record('auth.recover', StateError('boom'));
    await log.record('sync.push', const AuthFailure(AuthFailureKind.network));

    await pump(tester, log);
    await tester.tap(find.text(l.settingsDiagnostics_copy));
    await tester.pumpAndSettle();

    final copied = clipboard();
    expect(find.text(l.settingsDiagnostics_copied), findsOneWidget);
    // The report, not a one-line summary: both entries, each in its own
    // column, with the newest first.
    expect(copied, contains('| sync.push | AuthFailure(network)'));
    expect(copied, contains('| auth.recover | StateError'));
    expect(
      copied!.indexOf('sync.push'),
      lessThan(copied.indexOf('auth.recover')),
    );
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

  testWidgets('Report Error Or Bug offers WhatsApp and Email', (tester) async {
    await pump(tester, ErrorLog());

    // Offered even with an empty log: a fault that left no entry still needs
    // reporting, and "Errors Recorded: 0" is often the answer the developer
    // needs. (Copy and Clear stay hidden — there is nothing to act on.)
    expect(find.text(l.settingsDiagnostics_reportBug), findsOneWidget);
    expect(find.text(l.settingsDiagnostics_copy), findsNothing);

    await tester.tap(find.byKey(const ValueKey('diagnostics-report-bug')));
    await tester.pumpAndSettle();

    expect(find.text(l.settingsSupport_channelWhatsApp), findsOneWidget);
    expect(find.text(l.settingsSupport_channelEmail), findsOneWidget);
  });

  testWidgets('the prompt opens WhatsApp with the whole message written', (
    tester,
  ) async {
    final launcher = _RecordingLauncher();
    final log = ErrorLog();
    await log.record('sync.push', StateError('boom'));

    await pump(tester, log, launcher: launcher);
    await tester.tap(find.byKey(const ValueKey('diagnostics-report-bug')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('diagnostics-report-whatsapp')),
    );
    await tester.pumpAndSettle();

    expect(launcher.opened, hasLength(1));
    final uri = launcher.opened.single;
    expect(uri.host, 'wa.me');
    final message = sentMessage(uri);
    // The one format, in the order the user asked for: intro, then the facts,
    // then the prompt for their own description.
    expect(message, contains(l.settingsSupport_messageIntro));
    expect(message, contains('Legal Case Diary — Diagnostics'));
    expect(message, contains('App Version: '));
    expect(message, contains('Phone: Redmi Note 10 · Android 13'));
    expect(message, contains('App Language: English'));
    expect(message, contains('Generated: '));
    expect(message, contains('Errors Recorded: 1'));
    expect(message, contains('| sync.push | StateError'));
    expect(
      message.indexOf('Errors Recorded:'),
      lessThan(message.indexOf(l.settingsSupport_messagePrompt)),
    );
  });

  testWidgets('the prompt opens Email with the same message and a subject', (
    tester,
  ) async {
    final launcher = _RecordingLauncher();
    await pump(tester, ErrorLog(), launcher: launcher);

    await tester.tap(find.byKey(const ValueKey('diagnostics-report-bug')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('diagnostics-report-email')));
    await tester.pumpAndSettle();

    final uri = launcher.opened.single;
    expect(uri.scheme, 'mailto');
    expect(uri.queryParameters['subject'], l.settingsSupport_messageSubject);
    expect(sentMessage(uri), contains(l.settingsSupport_messageIntro));
    expect(sentMessage(uri), contains('Errors Recorded: 0'));
  });

  testWidgets('dismissing the prompt writes nothing', (tester) async {
    final launcher = _RecordingLauncher();
    await pump(tester, ErrorLog(), launcher: launcher);

    await tester.tap(find.byKey(const ValueKey('diagnostics-report-bug')));
    await tester.pumpAndSettle();
    // Tap the barrier: a dismissed window is a cancellation.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(launcher.opened, isEmpty);
  });

  testWidgets('a channel that opens nothing says so', (tester) async {
    final launcher = _RecordingLauncher(result: false);
    await pump(tester, ErrorLog(), launcher: launcher);

    await tester.tap(find.byKey(const ValueKey('diagnostics-report-bug')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('diagnostics-report-email')));
    await tester.pumpAndSettle();

    expect(find.text(l.settingsSupport_unableToOpenEmail), findsOneWidget);
  });
}
