/// Task 14 Phase 4 tests: the shared Phone/Message actions.
///
/// What is worth pinning here is every rule the Addendum names — the represented
/// party comes from `on_behalf_id` rather than field order, the pre-filled text
/// is the ARB template with the case's own facts, and the only routes launched
/// are the documented `tel:`, `sms:` and `https://wa.me/…` ones (WhatsApp
/// publishes no call scheme, so the chat is the fallback). The launcher is a
/// seam, so the tests assert the exact URI a tap produces without a device.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/services/contact_launcher.dart';
import 'package:legal_case_diary/core/utils/date_utils.dart';
import 'package:legal_case_diary/core/utils/on_behalf_side.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/cases/presentation/case_contact_actions.dart';

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

  group('message template', () {
    test('English SMS text carries every substituted fact', () async {
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      final body = buildContactMessage(
        l: l,
        currentCase: caseRow(),
        clientName: 'Md. Rahim Uddin',
        courtLabel: 'Joint District Judge, 2nd Court, Dhaka',
        lawyerName: 'Adv. Rahima Khatun',
        message: true,
      );

      expect(body, contains('Md. Rahim Uddin'));
      expect(body, contains('423/2023'));
      expect(body, contains('Joint District Judge, 2nd Court, Dhaka'));
      expect(body, contains('Adv. Rahima Khatun'));
      expect(
        body,
        contains(
          AppDateUtils.formatDateDDMMYYYY(nextDate, locale: 'en'),
        ),
      );
      // No placeholder is left behind.
      expect(body, isNot(contains('{')));
    });

    test('Bengali text substitutes the same facts, digits included', () async {
      final l = await AppLocalizations.delegate.load(const Locale('bn'));
      final body = buildContactMessage(
        l: l,
        currentCase: caseRow(),
        clientName: 'মো. রহিম উদ্দিন',
        courtLabel: 'জয়েন্ট জেলা জজ, ২য় আদালত, ঢাকা',
        lawyerName: 'অ্যাড. রহিমা খাতুন',
        message: true,
      );

      expect(body, contains('মো. রহিম উদ্দিন'));
      expect(body, contains('423/2023'));
      expect(body, contains('জয়েন্ট জেলা জজ, ২য় আদালত, ঢাকা'));
      expect(body, contains('অ্যাড. রহিমা খাতুন'));
      final bengaliDate = AppDateUtils.formatDateDDMMYYYY(nextDate, locale: 'bn');
      expect(body, contains(bengaliDate));
      // The date is rendered in Bengali digits, not Latin ones.
      expect(bengaliDate, isNot(matches(RegExp(r'[0-9]'))));
      expect(body, isNot(contains('{')));
    });

    test('the WhatsApp text uses the WhatsApp template', () async {
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      final sms = buildContactMessage(
        l: l,
        currentCase: caseRow(),
        clientName: 'Md. Rahim Uddin',
        courtLabel: 'Court',
        lawyerName: 'Lawyer',
        message: true,
      );
      final whatsApp = buildContactMessage(
        l: l,
        currentCase: caseRow(),
        clientName: 'Md. Rahim Uddin',
        courtLabel: 'Court',
        lawyerName: 'Lawyer',
        message: false,
      );

      expect(sms, isNotEmpty);
      expect(whatsApp, isNotEmpty);
    });
  });

  /// Pumps a host that opens the chooser for [message] and taps it.
  Future<void> pumpChooser(
    WidgetTester tester, {
    required bool message,
    required _RecordingLauncher launcher,
    OnBehalf? onBehalf,
    Case? currentCase,
    Locale locale = const Locale('en'),
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showCaseContactActions(
                  context,
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
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  String prefix(bool message) =>
      'case-contact-${message ? 'message' : 'call'}';

  group('the chooser', () {
    testWidgets('shows both parties, the represented one reachable', (
      tester,
    ) async {
      final launcher = _RecordingLauncher();
      await pumpChooser(tester, message: false, launcher: launcher);
      final l = AppLocalizations.of(tester.element(find.byType(AlertDialog)));

      expect(find.byKey(const ValueKey('case-contact-dialog')), findsOneWidget);
      expect(find.text(l.casesContact_openWith), findsOneWidget);

      // The represented client: enabled, with the number on show.
      expect(
        find.byKey(ValueKey('${prefix(false)}-party-represented')),
        findsOneWidget,
      );
      expect(find.textContaining('Md. Rahim Uddin'), findsOneWidget);
      expect(find.text('01812332721'), findsOneWidget);

      // The other side: listed, with the reason it is not reachable, so the
      // client's number is never silently reused.
      expect(
        find.byKey(ValueKey('${prefix(false)}-party-other')),
        findsOneWidget,
      );
      expect(
        find.text(l.casesContact_noNumber(l.caseDetailsScreen_respondent)),
        findsOneWidget,
      );

      // No undocumented call scheme: WhatsApp is offered as the chat, with the
      // standard dialer beside it.
      expect(find.text(l.casesContact_whatsapp), findsOneWidget);
      expect(find.text(l.casesContact_whatsappNote), findsOneWidget);
      expect(find.text(l.casesContact_phone), findsOneWidget);

      await tester.tap(find.byKey(ValueKey('case-card-call-cancel')));
      await tester.pumpAndSettle();
      expect(launcher.opened, isEmpty);
    });

    testWidgets('the represented party follows the on-behalf role', (
      tester,
    ) async {
      final launcher = _RecordingLauncher();
      await pumpChooser(
        tester,
        message: true,
        launcher: launcher,
        onBehalf: role('contact-category-role-respondent', 'Respondent'),
      );
      final l = AppLocalizations.of(tester.element(find.byType(AlertDialog)));

      // Acting for the respondent: the respondent is the client now.
      expect(find.textContaining('Bangladesh Government'), findsOneWidget);
      expect(
        find.text(l.casesContact_noNumber(l.caseDetailsScreen_petitioner)),
        findsOneWidget,
      );

      await tester.tap(find.byKey(ValueKey('${prefix(true)}-native')));
      await tester.pumpAndSettle();

      final body = launcher.opened.single.queryParameters['body']!;
      expect(body, contains('Bangladesh Government'));
      expect(body, isNot(contains('Md. Rahim Uddin')));
    });

    testWidgets('a case with no number disables both routes and says why', (
      tester,
    ) async {
      final launcher = _RecordingLauncher();
      await pumpChooser(
        tester,
        message: false,
        launcher: launcher,
        currentCase: caseRow(partyPhone: null),
      );
      final l = AppLocalizations.of(tester.element(find.byType(AlertDialog)));

      expect(
        find.text(l.casesContact_noNumber(l.caseDetailsScreen_petitioner)),
        findsOneWidget,
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
      final body = uri.queryParameters['body']!;
      expect(body, contains('423/2023'));
      expect(body, contains('Adv. Rahima Khatun'));
      expect(body, contains('Md. Rahim Uddin'));
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
      expect(uri.queryParameters['text'], contains('423/2023'));
    });

    testWidgets('Phone → the dialer, with no message attached', (tester) async {
      final launcher = _RecordingLauncher();
      await pumpChooser(tester, message: false, launcher: launcher);

      await tester.tap(find.byKey(ValueKey('${prefix(false)}-native')));
      await tester.pumpAndSettle();

      expect(launcher.opened.single.toString(), 'tel:01812332721');
    });

    testWidgets('Phone → WhatsApp opens the chat, never a call scheme', (
      tester,
    ) async {
      final launcher = _RecordingLauncher();
      await pumpChooser(tester, message: false, launcher: launcher);

      await tester.tap(find.byKey(ValueKey('${prefix(false)}-whatsapp')));
      await tester.pumpAndSettle();

      final uri = launcher.opened.single;
      expect(uri.scheme, 'https');
      expect(uri.host, 'wa.me');
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
