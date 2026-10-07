/// Support screen tests (Settings > About > Support).
///
/// The screen has no mockup, so these tests are its contract: what support can
/// and cannot do sits beside the channels, the link really opens Guidelines &
/// FAQs, and the two channels open the **same** message — the app version, the
/// phone and the language, with the user's own description left to fill in.
/// The device facts and the launcher are seams, so no test needs a real phone,
/// WhatsApp or a mail app.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:legal_case_diary/core/errors/error_log.dart';
import 'package:legal_case_diary/core/errors/error_log_provider.dart';
import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/providers/contact_providers.dart';
import 'package:legal_case_diary/core/router/app_router.dart';
import 'package:legal_case_diary/core/services/contact_launcher.dart';
import 'package:legal_case_diary/features/settings/data/support_diagnostics.dart';
import 'package:legal_case_diary/features/settings/presentation/settings_about/guidelines_screen.dart';
import 'package:legal_case_diary/features/settings/presentation/settings_about/support_screen.dart';
import 'package:legal_case_diary/features/auth/data/auth_repository.dart';

/// Records every URI the channels try to open.
class _RecordingLauncher implements ContactLauncher {
  _RecordingLauncher({this.result = true});

  /// What `open` answers: `false` stands for "no app accepted this".
  final bool result;

  /// The URIs the channels asked to open, in order.
  final List<Uri> opened = <Uri>[];

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return result;
  }
}

/// Reports the device the test chooses, instead of a platform channel.
class _FakeFactsReader implements SupportDeviceFactsReader {
  _FakeFactsReader(this.facts);

  /// The facts the message should carry.
  final SupportDeviceFacts facts;

  @override
  Future<SupportDeviceFacts> read() async => facts;
}

/// The device every test but the "unreadable phone" one uses.
const SupportDeviceFacts _redmi = SupportDeviceFacts(
  model: 'Redmi Note 10',
  osVersion: 'Android 13',
);

/// Pumps the Support screen with the Guidelines & FAQs route behind it, so the
/// link can be followed for real.
Future<void> _pumpSupport(
  WidgetTester tester, {
  required _RecordingLauncher launcher,
  SupportDeviceFacts facts = _redmi,
  Locale locale = const Locale('en'),
  ErrorLog? log,
}) async {
  // The screen is a scrolling list of cards; a phone-sized viewport would leave
  // the lower cards unbuilt and make their absence mean nothing.
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: AppRoutes.settingsSupport,
    routes: [
      GoRoute(
        path: AppRoutes.settingsSupport,
        builder: (context, state) => const SupportScreen(),
      ),
      GoRoute(
        path: AppRoutes.settingsGuidelines,
        builder: (context, state) => const GuidelinesScreen(),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        supportDeviceFactsProvider.overrideWithValue(_FakeFactsReader(facts)),
        contactLauncherProvider.overrideWithValue(launcher),
        // The message carries the error log, so the screen reads it; main.dart
        // always overrides this provider, and every test must do the same.
        errorLogProvider.overrideWithValue(log ?? ErrorLog()),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The message a channel was opened with, as the URI carries it.
///
/// The screen no longer previews the message, so what it sends is read off the
/// URI the launcher was asked to open — the real thing the phone would hand to
/// WhatsApp or the mail app.
String _sentMessage(Uri uri) =>
    (uri.queryParameters['text'] ?? uri.queryParameters['body'])!;

void main() {
  testWidgets('states its scope, links the FAQs and lists both channels', (
    tester,
  ) async {
    await _pumpSupport(tester, launcher: _RecordingLauncher());
    final l = await AppLocalizations.delegate.load(const Locale('en'));

    // What support can and cannot do, as its own card: the scope says what it
    // cannot do as well as what it can.
    expect(find.text(l.settingsSupport_scopeTitle), findsOneWidget);
    expect(find.text(l.settingsSupport_scope), findsOneWidget);
    expect(find.textContaining('cannot check'), findsOneWidget);

    // The FAQs come before any channel.
    expect(find.text(l.settingsSupport_faqLead), findsOneWidget);
    expect(find.text(l.settingsGuidelines_title), findsOneWidget);

    // WhatsApp, then email, each naming the address it writes to.
    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.text(supportWhatsAppNumber), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text(supportEmailAddress), findsOneWidget);

    // The never-send warning and the honest reply time are both on the screen.
    expect(
      find.text(l.settingsSupport_warningTitle),
      findsOneWidget,
    );
    expect(find.text(l.settingsSupport_warningBody), findsOneWidget);
    expect(
      find.text(l.settingsSupport_replyTitle),
      findsOneWidget,
    );
    expect(find.text(l.settingsSupport_replyBody), findsOneWidget);
    expect(find.textContaining('one to two working days'), findsOneWidget);

    // The three note cards read as one set, in order: what we can do, what
    // never to send, when a reply comes.
    final scopeTop = tester.getRect(find.text(l.settingsSupport_scopeTitle)).top;
    final warningTop =
        tester.getRect(find.text(l.settingsSupport_warningTitle)).top;
    final replyTop = tester.getRect(find.text(l.settingsSupport_replyTitle)).top;
    expect(scopeTop, lessThan(warningTop));
    expect(warningTop, lessThan(replyTop));
  });

  testWidgets('the Guidelines & FAQs row opens the FAQs screen', (
    tester,
  ) async {
    await _pumpSupport(tester, launcher: _RecordingLauncher());
    final l = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.text(l.settingsGuidelines_title));
    await tester.pumpAndSettle();

    expect(find.byType(GuidelinesScreen), findsOneWidget);
    expect(
      find.text(l.settingsGuidelines_sectionGuidelines),
      findsOneWidget,
    );
  });

  testWidgets('WhatsApp opens with the diagnostics message already written', (
    tester,
  ) async {
    final launcher = _RecordingLauncher();
    await _pumpSupport(tester, launcher: launcher);
    final l = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.byKey(const ValueKey('support-whatsapp')));
    await tester.pumpAndSettle();

    expect(launcher.opened, hasLength(1));
    final uri = launcher.opened.single;
    expect(uri.scheme, 'https');
    expect(uri.host, 'wa.me');
    // Digits only on the path, as wa.me requires.
    expect(uri.path, '/8801835252721');
    final message = _sentMessage(uri);
    expect(message, contains('${l.settingsSupport_messageVersion}: '));
    expect(message, contains('Redmi Note 10 · Android 13'));
    expect(message, contains('${l.settingsSupport_messageLanguage}: English'));
    expect(message, contains(l.settingsSupport_messageIntro));
    expect(message, contains(l.settingsSupport_messagePrompt));
  });

  testWidgets('the email channel opens the same message through mailto', (
    tester,
  ) async {
    final launcher = _RecordingLauncher();
    await _pumpSupport(tester, launcher: launcher);
    final l = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.byKey(const ValueKey('support-whatsapp')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('support-email')));
    await tester.pumpAndSettle();

    final whatsApp = launcher.opened.first;
    final email = launcher.opened.last;
    expect(email.scheme, 'mailto');
    expect(email.path, supportEmailAddress);
    expect(email.queryParameters['subject'], l.settingsSupport_messageSubject);
    // One message, two channels: identical bodies.
    expect(_sentMessage(email), _sentMessage(whatsApp));
  });

  testWidgets('leaves the phone line out when the device cannot be read', (
    tester,
  ) async {
    final launcher = _RecordingLauncher();
    await _pumpSupport(
      tester,
      launcher: launcher,
      facts: const SupportDeviceFacts(),
    );
    final l = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.byKey(const ValueKey('support-whatsapp')));
    await tester.pumpAndSettle();

    // The message is still written — just without a fact the app does not have.
    final message = _sentMessage(launcher.opened.single);
    expect(message, contains(l.settingsSupport_messageIntro));
    expect(message, isNot(contains(l.settingsSupport_messagePhone)));
    expect(message, contains(l.settingsSupport_messageVersion));
  });

  testWidgets('a channel that opens nothing says so', (tester) async {
    await _pumpSupport(tester, launcher: _RecordingLauncher(result: false));
    final l = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.byKey(const ValueKey('support-email')));
    await tester.pumpAndSettle();

    expect(find.text(l.settingsSupport_unableToOpenEmail), findsOneWidget);
  });

  testWidgets('a recorded failure rides along in the message it sends', (
    tester,
  ) async {
    final launcher = _RecordingLauncher();
    final log = ErrorLog();
    await log.record(
      'sync.push',
      const AuthFailure(
        AuthFailureKind.network,
        serverMessage: 'connection reset by peer',
      ),
    );
    await _pumpSupport(tester, launcher: launcher, log: log);
    final l = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.byKey(const ValueKey('support-whatsapp')));
    await tester.pumpAndSettle();

    final message = _sentMessage(launcher.opened.single);
    expect(message, contains('| sync.push | AuthFailure(network)'));
    // And the failure's own message with it (0.0.406): a report a support
    // reader cannot act on is a report that has to be asked for twice.
    expect(message, contains('connection reset by peer'));
    // Before the prompt, so the user's own description ends the message.
    expect(
      message.indexOf('| sync.push |'),
      lessThan(message.indexOf(l.settingsSupport_messagePrompt)),
    );
  });

  testWidgets('a clean log sends no diagnostics section at all', (
    tester,
  ) async {
    final launcher = _RecordingLauncher();
    await _pumpSupport(tester, launcher: launcher);
    final l = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.byKey(const ValueKey('support-whatsapp')));
    await tester.pumpAndSettle();

    // An empty report would be noise in a message that is already complete.
    final message = _sentMessage(launcher.opened.single);
    expect(message, isNot(contains('Errors Recorded:')));
    expect(message, contains(l.settingsSupport_messagePrompt));
  });

  testWidgets('a failure recorded while the screen is open reaches the message', (
    tester,
  ) async {
    final launcher = _RecordingLauncher();
    final log = ErrorLog();
    await _pumpSupport(tester, launcher: launcher, log: log);

    // The message is built when a channel is tapped, so a failure recorded
    // after the screen was opened — but before the tap — still rides along.
    await log.record('auth.signIn', StateError('boom'));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('support-whatsapp')));
    await tester.pumpAndSettle();

    expect(
      _sentMessage(launcher.opened.single),
      contains('| auth.signIn | StateError'),
    );
  });

  testWidgets('renders the Bengali copy, message included', (tester) async {
    final launcher = _RecordingLauncher();
    await _pumpSupport(tester, launcher: launcher, locale: const Locale('bn'));
    final l = await AppLocalizations.delegate.load(const Locale('bn'));

    expect(find.text(l.settingsSupport_title), findsOneWidget);
    expect(find.text(l.settingsSupport_scopeTitle), findsOneWidget);
    expect(find.text(l.settingsSupport_scope), findsOneWidget);
    expect(
      find.text(l.settingsSupport_channelWhatsApp),
      findsOneWidget,
    );
    expect(find.text(l.settingsSupport_replyBody), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('support-whatsapp')));
    await tester.pumpAndSettle();

    expect(
      _sentMessage(launcher.opened.single),
      contains('${l.settingsSupport_messageLanguage}: বাংলা'),
    );
  });
}
