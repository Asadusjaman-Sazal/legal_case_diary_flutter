/// Task 14 Phase 4 tests: the shared Phone/Message actions.
///
/// What is worth pinning here is every rule the Addendum names — the represented
/// party comes from `on_behalf_id` rather than field order, the message sheet's
/// pre-filled text is the Client Notification template chosen in Settings with
/// the case's own facts, and the only routes launched are the documented `tel:`,
/// `sms:` and `https://wa.me/…` ones
/// (WhatsApp publishes no call scheme, so the chat is the fallback). The window
/// itself names no party and prints no number, and the call sheet's WhatsApp
/// route opens the bare chat. The launcher is a seam, so the tests assert the
/// exact URI a tap produces without a device.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:legal_case_diary/core/constants/app_spacing.dart';
import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/providers/repository_providers.dart';
import 'package:legal_case_diary/core/services/contact_launcher.dart';
import 'package:legal_case_diary/core/utils/date_utils.dart';
import 'package:legal_case_diary/core/utils/on_behalf_side.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/cases/presentation/case_contact_actions.dart';
import 'package:legal_case_diary/features/settings/data/settings_repository.dart';
import 'package:legal_case_diary/shared/providers/shared_preferences_provider.dart';

import 'settings_test_support.dart';

/// Records every URI the actions try to open.
class _RecordingLauncher implements ContactLauncher {
  _RecordingLauncher({this.result = true});

  /// What `open` answers: `false` stands for "no app accepted this".
  final bool result;

  /// The URIs the actions asked to open, in order.
  final List<Uri> opened = <Uri>[];

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return result;
  }

  @override
  Future<bool> openMailApp() async {
    // The case contact actions never ask for the mail app: every channel here is
    // an addressed URI handed to [open].
    return result;
  }
}

void main() {
  const dayMs = 86400000;
  final nextDate = AppDateUtils.bangladeshTodayStartOfDay() + 3 * dayMs;

  Court court() => const Court(
    id: 'contact-court',
    courtName: 'Joint District Judge, 2nd Court, Dhaka',
    higherLowerCourts: 'lower_courts',
    courtCategoryId: 'contact-category',
    orderIndex: 0,
    isCustom: false,
    isUserModified: false,
    updatedAt: 1,
    isDeleted: false,
  );

  OnBehalf role(String id, String name) => OnBehalf(
    id: id,
    courtCategoryId: 'contact-category',
    name: name,
    orderIndex: 1,
    isCustom: false,
    isUserModified: false,
    updatedAt: 1,
    isDeleted: false,
  );

  Case caseRow({String? partyPhone = '01812332721'}) => Case(
    id: 'contact-case',
    userId: 'user-1',
    courtId: 'contact-court',
    caseType: 'Civil Suit',
    caseNumber: '423/2023',
    petitioner: 'Md. Rahim Uddin',
    respondent: 'Bangladesh Government',
    onBehalfId: 'contact-category-role-petitioner',
    partyPhone: partyPhone,
    caseTitleAndSection: 'Section 138, N.I. Act',
    nextDate: nextDate,
    createdAt: 1,
    updatedAt: 1,
    isDeleted: false,
  );

  setUpAll(() async => initializeDateFormatting());

  group('number normalization', () {
    test('spaces, dashes and brackets are stripped and `+` is kept', () {
      expect(normalizeLaunchNumber('+880 1812-332721'), '+8801812332721');
      expect(normalizeLaunchNumber(' (01812) 332721 '), '01812332721');
    });

    test('a half-typed number is refused rather than dialled', () {
      expect(normalizeLaunchNumber(null), isNull);
      expect(normalizeLaunchNumber(''), isNull);
      expect(normalizeLaunchNumber('12345'), isNull);
      // Six digits is the shortest number the dialer is asked to open.
      expect(normalizeLaunchNumber('123456'), '123456');
    });

    test('WhatsApp gets the digits-only international form', () {
      expect(whatsAppNumber('+880 1812-332721'), '8801812332721');
      expect(whatsAppNumber('01812332721'), '01812332721');
      expect(whatsAppNumber('123'), isNull);
    });
  });

  group('launch URIs', () {
    test('the only schemes used are the documented ones', () {
      expect(telUri('01812332721').toString(), 'tel:01812332721');

      final sms = smsUri('01812332721', 'Dear Client, hello');
      expect(sms.scheme, 'sms');
      expect(sms.path, '01812332721');
      expect(sms.queryParameters['body'], 'Dear Client, hello');

      final whatsApp = whatsAppUri('8801812332721', 'Dear Client, hello');
      expect(whatsApp.scheme, 'https');
      expect(whatsApp.host, 'wa.me');
      expect(whatsApp.path, '/8801812332721');
      expect(whatsApp.queryParameters['text'], 'Dear Client, hello');

      // The bare chat: the same path with nothing written into the composer.
      expect(
        whatsAppChatUri('8801812332721').toString(),
        'https://wa.me/8801812332721',
      );

      // A mail client reads the body literally, so a space must never be
      // written as `+` (it did once, and every space arrived as a plus sign).
      final mail = mailtoUri('dev@example.com', 'Subject here', 'Dear\nDev');
      expect(mail.scheme, 'mailto');
      expect(mail.path, 'dev@example.com');
      expect(mail.query, isNot(contains('+')));
      expect(mail.query, contains('%20'));
      expect(mail.queryParameters['subject'], 'Subject here');
      expect(mail.queryParameters['body'], 'Dear\nDev');
    });
  });

  group('represented client rule', () {
    test('the side comes from the on-behalf role, and unknown roles admit it', () {
      expect(representedSideOf(role('cat-role-petitioner', 'Petitioner')),
          PartySide.petitioner);
      expect(representedSideOf(role('cat-role-respondent', 'Respondent')),
          PartySide.respondent);
      expect(representedSideOf(role('cat-role-defendant', 'Defendant')),
          PartySide.respondent);
      expect(representedSideOf(role('cat-role-appellant', 'Appellant')),
          PartySide.petitioner);
      // A custom role is not guessed at.
      expect(representedSideOf(role('custom-role', 'বাদী')), isNull);
      expect(representedSideOf(null), isNull);
    });

    test('the client name follows the represented side', () {
      expect(
        representedClientName(
          caseRow(),
          role('cat-role-petitioner', 'Petitioner'),
        ),
        'Md. Rahim Uddin',
      );
      // Acting for the respondent names the respondent — naming the petitioner
      // here would send the wrong person's name to the client.
      expect(
        representedClientName(
          caseRow(),
          role('cat-role-respondent', 'Respondent'),
        ),
        'Bangladesh Government',
      );
      // No role at all falls back to the petitioner, the side labelled first.
      expect(representedClientName(caseRow(), null), 'Md. Rahim Uddin');
    });
  });

  /// Pumps a host that opens the chooser for [message] and taps it.
  Future<void> pumpChooser(
    WidgetTester tester, {
    required bool message,
    required _RecordingLauncher launcher,
    OnBehalf? onBehalf,
    Case? currentCase,
    UserSettings settings = const UserSettings(),
    Locale locale = const Locale('en'),
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsRepositoryProvider.overrideWith(
            (ref) async => FakeSettingsRepository(settings),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: locale,
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showCaseContactActions(
                    context,
                    ref: ref,
                    currentCase: currentCase ?? caseRow(),
                    court: court(),
                    onBehalf:
                        onBehalf ??
                        role('contact-category-role-petitioner', 'Petitioner'),
                    lawyerName: 'Adv. Rahima Khatun',
                    message: message,
                    launcher: launcher,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  String prefix(bool message) =>
      'case-contact-${message ? 'message' : 'call'}';

  group('the chooser', () {
    testWidgets('offers the two routes, and no party or number', (tester) async {
      final launcher = _RecordingLauncher();
      await pumpChooser(tester, message: false, launcher: launcher);
      final l = AppLocalizations.of(tester.element(find.byType(AlertDialog)));

      expect(find.byKey(const ValueKey('case-contact-dialog')), findsOneWidget);
      expect(find.text(l.casesContact_openWith), findsOneWidget);
      // The same 8 px corner as the Update window (user request, 0.0.616).
      final dialog = tester.widget<AlertDialog>(
        find.byKey(const ValueKey('case-contact-dialog')),
      );
      expect(
        (dialog.shape! as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(AppSpacing.cardRadius * 2),
      );

      // No undocumented call scheme: WhatsApp is offered as the chat, with the
      // standard dialer beside it — and with no subtitle under it.
      expect(find.text(l.casesContact_whatsapp), findsOneWidget);
      expect(find.text(l.casesContact_phone), findsOneWidget);
      expect(find.byType(ListTile), findsNWidgets(2));

      // Nothing about the parties, either of them: the client's number is the
      // case's own `party_phone`, and the window is not a second place to read
      // it — or the opponent's — from.
      expect(find.text('Md. Rahim Uddin'), findsNothing);
      expect(find.text('Bangladesh Government'), findsNothing);
      expect(find.textContaining('01812332721'), findsNothing);
      expect(find.textContaining('No number saved'), findsNothing);
      expect(find.textContaining('start the call from there'), findsNothing);

      await tester.tap(find.byKey(ValueKey('case-card-call-cancel')));
      await tester.pumpAndSettle();
      expect(launcher.opened, isEmpty);
    });

    testWidgets('the message names the represented client, not the petitioner', (
      tester,
    ) async {
      final launcher = _RecordingLauncher();
      await pumpChooser(
        tester,
        message: true,
        launcher: launcher,
        onBehalf: role('contact-category-role-respondent', 'Respondent'),
      );

      // WhatsApp's default Long template names the client; the short SMS note
      // deliberately carries no name.
      await tester.tap(find.byKey(ValueKey('${prefix(true)}-whatsapp')));
      await tester.pumpAndSettle();

      final body = launcher.opened.single.queryParameters['text']!;
      expect(body, contains('Bangladesh Government'));
      expect(body, isNot(contains('Md. Rahim Uddin')));
    });

    testWidgets('a case with no number disables both routes', (tester) async {
      final launcher = _RecordingLauncher();
      await pumpChooser(
        tester,
        message: false,
        launcher: launcher,
        currentCase: caseRow(partyPhone: null),
      );

      await tester.tap(find.byKey(ValueKey('${prefix(false)}-whatsapp')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('${prefix(false)}-native')));
      await tester.pumpAndSettle();

      expect(launcher.opened, isEmpty);
      // The chooser is still up: a disabled route is not a dismissal.
      expect(find.byKey(const ValueKey('case-contact-dialog')), findsOneWidget);
    });

    testWidgets('Message → the SMS app with the template pre-filled', (
      tester,
    ) async {
      final launcher = _RecordingLauncher();
      await pumpChooser(tester, message: true, launcher: launcher);

      await tester.tap(find.byKey(ValueKey('${prefix(true)}-native')));
      await tester.pumpAndSettle();

      final uri = launcher.opened.single;
      expect(uri.scheme, 'sms');
      expect(uri.path, '01812332721');
      // SMS defaults to the Short template: the case line, date, steps and
      // court — no client name and no sign-off.
      final body = uri.queryParameters['body']!;
      expect(body, contains('Civil Suit 423/2023'));
      expect(body, isNot(contains('Best regards')));
      expect(body, isNot(contains('Md. Rahim Uddin')));
    });

    testWidgets('Message → WhatsApp chat with the same facts', (tester) async {
      final launcher = _RecordingLauncher();
      // A number stored the way the form saves it: with the `+88` country code.
      await pumpChooser(
        tester,
        message: true,
        launcher: launcher,
        currentCase: caseRow(partyPhone: '+880 1812-332721'),
      );

      await tester.tap(find.byKey(ValueKey('${prefix(true)}-whatsapp')));
      await tester.pumpAndSettle();

      final uri = launcher.opened.single;
      expect(uri.scheme, 'https');
      expect(uri.host, 'wa.me');
      // `wa.me` takes the digits without the leading `+`.
      expect(uri.path, '/8801812332721');
      // WhatsApp defaults to the Long template.
      final body = uri.queryParameters['text']!;
      expect(body, contains('Md. Rahim Uddin'));
      expect(body, contains('423/2023'));
      expect(body, contains('Best regards,'));
    });

    testWidgets('Message follows the template chosen in Settings', (
      tester,
    ) async {
      final launcher = _RecordingLauncher();
      await pumpChooser(
        tester,
        message: true,
        launcher: launcher,
        settings: const UserSettings(
          automatedNotificationWhatsAppTemplate: clientNotificationTemplateShort,
          automatedNotificationSmsTemplate: clientNotificationTemplateLong,
          notificationContactNumber: '01700000000',
        ),
      );

      // WhatsApp now uses its Short choice.
      await tester.tap(find.byKey(ValueKey('case-contact-message-whatsapp')));
      await tester.pumpAndSettle();
      final whatsApp = launcher.opened.last.queryParameters['text']!;
      expect(whatsApp, isNot(contains('Best regards')));
      expect(whatsApp, contains('Civil Suit 423/2023'));

      // And the native message uses its Long choice, with the call-back line.
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('case-contact-message-native')));
      await tester.pumpAndSettle();
      final sms = launcher.opened.last.queryParameters['body']!;
      expect(sms, contains('Best regards,'));
      expect(sms, contains('Md. Rahim Uddin'));
      expect(sms, contains('Contact: 01700000000'));
    });

    testWidgets('Phone → the dialer, with no message attached', (tester) async {
      final launcher = _RecordingLauncher();
      await pumpChooser(tester, message: false, launcher: launcher);

      await tester.tap(find.byKey(ValueKey('${prefix(false)}-native')));
      await tester.pumpAndSettle();

      expect(launcher.opened.single.toString(), 'tel:01812332721');
    });

    testWidgets('Phone → WhatsApp opens the bare chat, never a call scheme', (
      tester,
    ) async {
      final launcher = _RecordingLauncher();
      await pumpChooser(
        tester,
        message: false,
        launcher: launcher,
        currentCase: caseRow(partyPhone: '+880 1812-332721'),
      );

      await tester.tap(find.byKey(ValueKey('${prefix(false)}-whatsapp')));
      await tester.pumpAndSettle();

      final uri = launcher.opened.single;
      expect(uri.scheme, 'https');
      expect(uri.host, 'wa.me');
      // The digits-only path, and no text: calling the client is what this
      // route is for, so nothing is written into their composer.
      expect(uri.path, '/8801812332721');
      expect(uri.queryParameters, isEmpty);
    });

    testWidgets('a refused launch is reported instead of failing silently', (
      tester,
    ) async {
      final launcher = _RecordingLauncher(result: false);
      await pumpChooser(tester, message: false, launcher: launcher);
      final l = AppLocalizations.of(tester.element(find.byType(AlertDialog)));

      await tester.tap(find.byKey(ValueKey('${prefix(false)}-native')));
      await tester.pumpAndSettle();

      expect(launcher.opened, hasLength(1));
      expect(find.text(l.casesContact_unableToCall), findsOneWidget);
    });

    testWidgets('a refused WhatsApp launch says so', (tester) async {
      final launcher = _RecordingLauncher(result: false);
      await pumpChooser(tester, message: true, launcher: launcher);
      final l = AppLocalizations.of(tester.element(find.byType(AlertDialog)));

      await tester.tap(find.byKey(ValueKey('${prefix(true)}-whatsapp')));
      await tester.pumpAndSettle();

      expect(find.text(l.casesContact_unableToOpenWhatsApp), findsOneWidget);
    });

    testWidgets('the Bengali chooser sends Bengali text', (tester) async {
      final launcher = _RecordingLauncher();
      await pumpChooser(
        tester,
        message: true,
        launcher: launcher,
        locale: const Locale('bn'),
      );

      await tester.tap(find.byKey(ValueKey('${prefix(true)}-native')));
      await tester.pumpAndSettle();

      final body = launcher.opened.single.queryParameters['body']!;
      expect(body, contains('423/2023'));
      // Bengali digits, not Latin ones.
      expect(body, matches(RegExp('[\u09E6-\u09EF]')));
      expect(body, isNot(contains('{')));
    });
  });
}
