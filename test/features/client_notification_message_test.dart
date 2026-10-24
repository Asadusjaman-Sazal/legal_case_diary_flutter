/// The automated client message's wording and the decision that gates it.
///
/// The two template lengths are pinned exactly, in both languages: the letter's
/// line breaks, the call-back line and its omission, the short note, the `/`
/// between several steps, and the clean disappearance of the steps clause for a
/// higher-court case that has none. The decision matrix is pinned beside them
/// (master off, no number, unchanged date, remembered yes/no, Ask on/off).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:legal_case_diary/core/l10n/app_translations.dart';
import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/services/client_notification_message.dart';
import 'package:legal_case_diary/core/utils/date_utils.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/settings/data/client_notification_settings.dart';
import 'package:legal_case_diary/features/settings/data/settings_repository.dart';

void main() {
  final nextDate = AppDateUtils.bangladeshCivilDateEpoch(2026, 11, 17);

  OnBehalf role(String id, String name) => OnBehalf(
    id: id,
    courtCategoryId: 'district_courts_civil',
    name: name,
    orderIndex: 1,
    isCustom: false,
    isUserModified: false,
    updatedAt: 1,
    isDeleted: false,
  );

  Court court({String name = 'Senior Civil Judge Court, Sonargaon, Narayanganj'}) =>
      Court(
        id: 'court-1',
        courtName: name,
        higherLowerCourts: 'lower_courts',
        courtCategoryId: 'district_courts_civil',
        orderIndex: 0,
        isCustom: true,
        isUserModified: false,
        updatedAt: 1,
        isDeleted: false,
      );

  Case caseRow({
    String caseType = 'Custom Suit',
    String? lastStep = 'WS,WO',
  }) => Case(
    id: 'case-1',
    userId: 'user-1',
    courtId: 'court-1',
    caseType: caseType,
    caseCategoryId: null,
    caseNumber: '123/26',
    petitioner: 'Md. Rahim Uddin',
    respondent: 'Bangladesh Government',
    onBehalfId: 'role-petitioner',
    partyPhone: '+8801800000000',
    nextDate: nextDate,
    lastStep: lastStep,
    createdAt: 1,
    updatedAt: 1,
    isDeleted: false,
  );

  Future<AppTranslations> translations(String language) async =>
      AppTranslations(
        await AppLocalizations.delegate.load(Locale(language)),
      );

  Future<String> message({
    required String language,
    required bool long,
    Case? currentCase,
    Court? currentCourt,
    OnBehalf? onBehalf,
    String lawyerName = 'Adv. Shafiullah Sourov',
    String? contact = '01800000000',
  }) async {
    final t = await translations(language);
    final facts = buildClientMessageFacts(
      translations: t,
      currentCase: currentCase ?? caseRow(),
      court: currentCourt ?? court(),
      onBehalf: onBehalf ?? role('role-petitioner', 'Petitioner'),
      nextDateMs: nextDate,
      lawyerName: lawyerName,
      contactNumber: contact,
    );
    return buildClientNotificationMessage(
      translations: t,
      facts: facts,
      long: long,
    );
  }

  setUpAll(() async => initializeDateFormatting());

  group('the long letter', () {
    test('English carries every fact, line breaks included', () async {
      expect(
        await message(
          language: 'en',
          long: true,
          currentCase: caseRow().copyWith(petitioner: 'Ali Hayder'),
        ),
        'Ali Hayder,\n'
        'your case, Custom Suit 123/26, is scheduled for hearing on '
        '17/11/2026 for WS/WO at Senior Civil Judge Court, Sonargaon, '
        'Narayanganj.\n'
        '\n'
        'Best regards,\n'
        'Adv. Shafiullah Sourov\n'
        'Contact: 01800000000',
      );
    });

    test('Bengali uses its own wording, court position and digits', () async {
      expect(
        await message(
          language: 'bn',
          long: true,
          currentCourt: court(name: 'সিনিয়র সিভিল জজ আদালত, সোনারগাঁও'),
          currentCase: caseRow().copyWith(petitioner: 'জনাব আলী হায়দার'),
          lawyerName: 'অ্যাডঃ শফিউল্লাহ সৌরভ',
        ),
        'জনাব আলী হায়দার,\n'
        'আপনার মামলা, Custom Suit 123/26, সিনিয়র সিভিল জজ আদালত, সোনারগাঁও '
        'কোর্টে আগামী ১৭/১১/২০২৬ ইং তারিখ WS/WO এর জন্য দিন ধার্য্য আছে।\n'
        '\n'
        'শুভেচ্ছান্তে,\n'
        'অ্যাডঃ শফিউল্লাহ সৌরভ\n'
        'যোগাযোগ: 01800000000',
      );
    });

    test('a case with no steps drops the clause cleanly', () async {
      final body = await message(
        language: 'en',
        long: true,
        currentCase: caseRow(lastStep: null),
      );
      expect(
        body,
        contains('is scheduled for hearing on 17/11/2026 at Senior Civil'),
      );
      expect(body, isNot(contains('for  at')));
      expect(body, isNot(contains('for at')));
    });

    test('Bengali no-steps drops its clause too', () async {
      final body = await message(
        language: 'bn',
        long: true,
        currentCase: caseRow(lastStep: null)
            .copyWith(petitioner: 'জনাব আলী হায়দার'),
        currentCourt: court(name: 'সিনিয়র সিভিল জজ আদালত'),
      );
      expect(body, contains('ইং তারিখ দিন ধার্য্য আছে।'));
      expect(body, isNot(contains('এর জন্য দিন')));
      expect(body, isNot(contains('  ')));
    });

    test('without a contact number the call-back line is absent', () async {
      final body = await message(language: 'en', long: true, contact: null);
      expect(body, endsWith('Best regards,\nAdv. Shafiullah Sourov'));
      expect(body, isNot(contains('Contact:')));
    });

    test('several steps are joined by a slash', () async {
      final body = await message(
        language: 'en',
        long: true,
        currentCase: caseRow(lastStep: 'Written Statement,Argument'),
      );
      expect(body, contains('for Written Statement/Argument at'));
      expect(body, isNot(contains('Written Statement,Argument')));
    });
  });

  group('the short note', () {
    test('English has no call-back line and no client name', () async {
      expect(
        await message(language: 'en', long: false),
        'Custom Suit 123/26 is scheduled on 17/11/2026 for WS/WO at '
        'Senior Civil Judge Court, Sonargaon, Narayanganj',
      );
    });

    test('Bengali brackets the steps, in Bengali digits', () async {
      final body = await message(
        language: 'bn',
        long: false,
        currentCourt: court(name: 'সিনিয়র সিভিল জজ আদালত'),
      );
      expect(
        body,
        'Custom Suit 123/26 এর পরবর্তী তাং ১৭/১১/২০২৬ ইং (WS/WO)',
      );
    });

    test('a case with no steps leaves no empty brackets', () async {
      final body = await message(
        language: 'bn',
        long: false,
        currentCase: caseRow(lastStep: null),
      );
      expect(body, 'Custom Suit 123/26 এর পরবর্তী তাং ১৭/১১/২০২৬ ইং');
      expect(body, isNot(contains('(')));
    });
  });

  group('the decision', () {
    const base = UserSettings(
      automatedNotificationEnabled: true,
    );

    ClientNotificationDecision decide(
      UserSettings settings, {
      bool dateChanged = true,
      bool hasRecipient = true,
    }) => resolveClientNotificationDecision(
      settings: settings,
      dateChanged: dateChanged,
      hasRecipient: hasRecipient,
    );

    test('off, unchanged date or no number do nothing', () {
      expect(
        decide(const UserSettings()),
        ClientNotificationDecision.none,
      );
      expect(
        decide(base, dateChanged: false),
        ClientNotificationDecision.none,
      );
      expect(
        decide(base, hasRecipient: false),
        ClientNotificationDecision.none,
      );
    });

    test('Ask on asks; Ask off sends', () {
      expect(decide(base), ClientNotificationDecision.ask);
      expect(
        decide(
          base.copyWith(automatedNotificationAskBeforeSending: false),
        ),
        ClientNotificationDecision.send,
      );
    });

    test('the master and Ask switches are the whole rule', () {
      // A remembered Yes is stored as on + Ask off; a remembered No as off.
      expect(
        decide(
          base.copyWith(automatedNotificationAskBeforeSending: false),
        ),
        ClientNotificationDecision.send,
      );
      expect(
        decide(
          const UserSettings(
            automatedNotificationEnabled: false,
            automatedNotificationAskBeforeSending: false,
          ),
        ),
        ClientNotificationDecision.none,
      );
    });
  });
}
