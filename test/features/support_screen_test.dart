/// Support screen tests (Settings > About > Support).
///
/// The screen has no mockup, so these tests are its contract: the app's own
/// Diagnostics leads it, the three notes read as one card under **Before You
/// Write To Us**, the FAQs are a link *inside* that card, and **both channels
/// open with nothing written for the user** — Support is where a user says it
/// in their own words, and the pre-filled report lives on the Diagnostics
/// screen instead. The launcher is a seam, so no test needs WhatsApp or a mail
/// app.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:legal_case_diary/core/constants/app_colors.dart';
import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/providers/contact_providers.dart';
import 'package:legal_case_diary/core/router/app_router.dart';
import 'package:legal_case_diary/core/services/contact_launcher.dart';
import 'package:legal_case_diary/features/settings/presentation/settings_about/guidelines_screen.dart';
import 'package:legal_case_diary/features/settings/presentation/settings_about/support_screen.dart';
import 'package:legal_case_diary/features/settings/presentation/settings_controls.dart';

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

  @override
  Future<bool> openMailApp() async => result;
}

/// Pumps the Support screen with the Guidelines & FAQs route behind it, so the
/// link can be followed for real.
Future<void> _pumpSupport(
  WidgetTester tester, {
  required _RecordingLauncher launcher,
  Locale locale = const Locale('en'),
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
      overrides: [contactLauncherProvider.overrideWithValue(launcher)],
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

void main() {
  testWidgets('leads with Diagnostics, and the FAQs are a link, not a row', (
    tester,
  ) async {
    await _pumpSupport(tester, launcher: _RecordingLauncher());
    final l = await AppLocalizations.delegate.load(const Locale('en'));

    // The log answers "what went wrong" before anybody has to write in.
    expect(find.text(l.settingsSupport_faqLead), findsOneWidget);
    expect(find.text(l.settingsDiagnostics_title), findsOneWidget);

    // The FAQs are no longer a row of their own (user request): they are the
    // link inside the card, so the screen's only link row is Diagnostics.
    expect(
      find.byKey(const ValueKey('support-guidelines-link')),
      findsOneWidget,
    );
    final guidelinesRows = find.ancestor(
      of: find.text(l.settingsGuidelines_title),
      matching: find.byType(SettingsLinkRow),
    );
    expect(guidelinesRows, findsNothing);
  });

  testWidgets('the FAQs link inside the card opens the FAQs screen', (
    tester,
  ) async {
    await _pumpSupport(tester, launcher: _RecordingLauncher());
    final l = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.byKey(const ValueKey('support-guidelines-link')));
    await tester.pumpAndSettle();

    expect(find.byType(GuidelinesScreen), findsOneWidget);
    expect(find.text(l.settingsGuidelines_sectionGuidelines), findsOneWidget);
  });

  testWidgets('the three notes read as one card, under their heading', (
    tester,
  ) async {
    await _pumpSupport(tester, launcher: _RecordingLauncher());
    final l = await AppLocalizations.delegate.load(const Locale('en'));

    // The heading above the card is the group's name.
    expect(find.text(l.settingsSupport_scopeTitle), findsOneWidget);

    // All three sit inside the one card, and the FAQs sentence leads it.
    final card = find.byKey(const ValueKey('support-help-card'));
    expect(card, findsOneWidget);
    for (final title in <String>[
      l.settingsSupport_helpTitle,
      l.settingsSupport_warningTitle,
      l.settingsSupport_replyTitle,
    ]) {
      expect(
        find.descendant(of: card, matching: find.text(title)),
        findsOneWidget,
        reason: '$title belongs to the merged card',
      );
    }
    expect(
      find.descendant(
        of: card,
        matching: find.byKey(const ValueKey('support-guidelines-link')),
      ),
      findsOneWidget,
      reason: 'the FAQs sentence is the first thing on the card',
    );

    // In order: what we can help with, what never to send, when a reply comes.
    final helpTop = tester.getRect(find.text(l.settingsSupport_helpTitle)).top;
    final warningTop = tester
        .getRect(find.text(l.settingsSupport_warningTitle))
        .top;
    final replyTop = tester
        .getRect(find.text(l.settingsSupport_replyTitle))
        .top;
    expect(helpTop, lessThan(warningTop));
    expect(warningTop, lessThan(replyTop));
  });

  testWidgets('the never-send note is ordinary ink, not red', (tester) async {
    // It used to sit on an error-tinted card; the user asked for the text to be
    // black, so it no longer reads as an alarm for advice nobody has earned.
    await _pumpSupport(tester, launcher: _RecordingLauncher());
    final l = await AppLocalizations.delegate.load(const Locale('en'));

    final title = tester.widget<Text>(
      find.text(l.settingsSupport_warningTitle),
    );
    final body = tester.widget<Text>(find.text(l.settingsSupport_warningBody));
    expect(title.style?.color, isNot(AppColors.error));
    expect(body.style?.color, isNot(AppColors.error));
    expect(body.style?.color, isNot(AppColors.onErrorContainer));
  });

  testWidgets('lists both channels, each naming the address it writes to', (
    tester,
  ) async {
    await _pumpSupport(tester, launcher: _RecordingLauncher());
    final l = await AppLocalizations.delegate.load(const Locale('en'));

    expect(find.text(l.settingsSupport_channelsLabel), findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.text(supportWhatsAppNumber), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text(supportEmailAddress), findsOneWidget);
  });

  testWidgets('WhatsApp opens an empty composer', (tester) async {
    final launcher = _RecordingLauncher();
    await _pumpSupport(tester, launcher: launcher);

    await tester.tap(find.byKey(const ValueKey('support-whatsapp')));
    await tester.pumpAndSettle();

    expect(launcher.opened, hasLength(1));
    final uri = launcher.opened.single;
    expect(uri.scheme, 'https');
    expect(uri.host, 'wa.me');
    // Digits only on the path, as wa.me requires.
    expect(uri.path, '/8801835252721');
    // Nothing is written for the user: Support is where they use their own
    // words, and the pre-filled report is what Diagnostics sends instead.
    expect(uri.queryParameters['text'], isNull);
  });

  testWidgets('Email opens a draft with the subject and no body', (
    tester,
  ) async {
    final launcher = _RecordingLauncher();
    await _pumpSupport(tester, launcher: launcher);
    final l = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.byKey(const ValueKey('support-email')));
    await tester.pumpAndSettle();

    final uri = launcher.opened.single;
    expect(uri.scheme, 'mailto');
    expect(uri.path, supportEmailAddress);
    // The subject is kept, so a reply is still recognisable as support; the
    // body is left for the user to write.
    expect(uri.queryParameters['subject'], l.settingsSupport_messageSubject);
    expect(uri.queryParameters['body'], isEmpty);
  });

  testWidgets('a channel that opens nothing says so', (tester) async {
    await _pumpSupport(tester, launcher: _RecordingLauncher(result: false));
    final l = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.byKey(const ValueKey('support-email')));
    await tester.pumpAndSettle();

    expect(find.text(l.settingsSupport_unableToOpenEmail), findsOneWidget);
  });

  testWidgets('renders the Bengali copy', (tester) async {
    await _pumpSupport(
      tester,
      launcher: _RecordingLauncher(),
      locale: const Locale('bn'),
    );
    final l = await AppLocalizations.delegate.load(const Locale('bn'));

    expect(find.text(l.settingsSupport_title), findsOneWidget);
    expect(find.text(l.settingsSupport_scopeTitle), findsOneWidget);
    expect(find.text(l.settingsSupport_helpTitle), findsOneWidget);
    expect(find.text(l.settingsSupport_warningTitle), findsOneWidget);
    expect(find.text(l.settingsSupport_replyTitle), findsOneWidget);
    expect(find.text(l.settingsSupport_channelWhatsApp), findsOneWidget);
    // The link reads as the screen's own Bengali name.
    expect(find.text(l.settingsGuidelines_title), findsOneWidget);
    expect(find.text(l.settingsSupport_replyBody), findsOneWidget);
  });
}
