// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Bengali Bangla (`bn`).
class AppLocalizationsBn extends AppLocalizations {
  AppLocalizationsBn([String locale = 'bn']) : super(locale);

  @override
  String get appName => 'লিগ্যাল কেস ডায়েরি';

  @override
  String get appTitle => 'লিগ্যাল কেস ডায়েরি';

  @override
  String get nav_upcomingCases => 'আসন্ন মামলা';

  @override
  String get nav_dailyCauseList => 'দৈনিক মামলার তালিকা';

  @override
  String get nav_allCases => 'সকল মামলা';

  @override
  String get nav_disposedCases => 'নিষ্পত্তিকৃত মামলা';

  @override
  String get nav_caseReference => 'কেস রেফারেন্স';

  @override
  String get nav_notes => 'নোট';

  @override
  String get nav_settings => 'সেটিংস';

  @override
  String get nav_print => 'প্রিন্ট';

  @override
  String get nav_share => 'শেয়ার';

  @override
  String get nav_activeCases => 'চলতি মামলা';

  @override
  String get nav_overdueDates => 'বিলম্বিত তারিখ';

  @override
  String get nav_adminPanel => 'অ্যাডমিন প্যানেল';

  @override
  String get drawerOf => 'এর';

  @override
  String drawer_version(String version) {
    return 'V$version';
  }

  @override
  String get allCasesScreen_title => 'সব মামলা';

  @override
  String get allCasesScreen_empty =>
      'এখনো কোনও মামলা যোগ করা হয়নি। যোগ করতে + চাপুন।';

  @override
  String get allCasesScreen_activeCases => 'সক্রিয় মামলা';

  @override
  String get allCasesScreen_disposedCases => 'নিষ্পত্তিকৃত মামলা';

  @override
  String get allCasesScreen_filterByCourt => 'আদালত অনুযায়ী ফিল্টার';

  @override
  String get allCasesScreen_newestFirst => 'নতুন প্রথমে';

  @override
  String get allCasesScreen_oldestFirst => 'পুরাতন প্রথমে';

  @override
  String get allCasesScreen_caseType => 'মামলার ধরন';

  @override
  String get allCasesScreen_caseNumber => 'মামলা নং';

  @override
  String get allCasesScreen_onBehalf => 'পক্ষে';

  @override
  String get allCasesScreen_petitionerVsRespondent => 'বাদী বনাম বিবাদী';

  @override
  String get caseCard_nextDate => 'পরবর্তী তারিখ';

  @override
  String get caseCard_previousDate => 'পূর্ববর্তী তারিখ';

  @override
  String get caseCard_lastStep => 'পদক্ষেপ';

  @override
  String get allCasesScreen_phone => 'ফোন';

  @override
  String get allCasesScreen_message => 'বার্তা';

  @override
  String get allCasesScreen_unableToCall => 'কল করা যায়নি।';

  @override
  String get allCasesScreen_unableToMessage => 'বার্তা খোলা যায়নি।';

  @override
  String get allCasesScreen_update => 'আপডেট';

  @override
  String get caseCard_disposed => 'নিষ্পত্তিকৃত:';

  @override
  String get caseTable_serial => 'ক্রমিক';

  @override
  String get caseTable_disposed => 'নিষ্পত্তিকৃত';

  @override
  String get activeCasesScreen_title => 'চলতি মামলা';

  @override
  String get activeCasesScreen_empty =>
      'দেখানোর মতো কোনও চলতি মামলা নেই। যোগ করতে + চাপুন।';

  @override
  String get upcomingCasesScreen_title => 'আসন্ন মামলা';

  @override
  String get upcomingCasesScreen_empty => 'কোনও আসন্ন মামলা নেই';

  @override
  String get dailyCauseListScreen_title => 'দৈনিক কজ লিস্ট';

  @override
  String get dailyCauseListScreen_today => 'আজ';

  @override
  String get dailyCauseListScreen_tomorrow => 'আগামীকাল';

  @override
  String get dailyCauseListScreen_calendarLabel => 'ক্যালেন্ডার';

  @override
  String get dailyCauseListScreen_noHearings =>
      'এই তারিখের জন্য কোনো শুনানি নির্ধারিত নেই।';

  @override
  String get dailyCauseListScreen_totalHearings => 'মোট শুনানি:';

  @override
  String get dailyCauseListScreen_selectYear => 'বছর নির্বাচন';

  @override
  String get dailyCauseListScreen_selectMonth => 'মাস নির্বাচন';

  @override
  String get dailyCauseListScreen_noPhone => 'এই মামলার কোনো ফোন নম্বর নেই।';

  @override
  String get dailyCauseListScreen_whatsappError => 'WhatsApp খোলা যাচ্ছে না।';

  @override
  String get dailyCauseListScreen_callError => 'কল করা যাচ্ছে না।';

  @override
  String get dailyCauseListScreen_messageError => 'মেসেজ খোলা যাচ্ছে না।';

  @override
  String get disposedCasesScreen_title => 'নিষ্পত্তিকৃত মামলা';

  @override
  String get disposedCasesScreen_empty => 'কোনও নিষ্পত্তিকৃত মামলা নেই';

  @override
  String get disposedCasesScreen_helpTitle =>
      'কোনো মামলাকে নিষ্পত্তিকৃত হিসেবে চিহ্নিত করবেন কীভাবে?';

  @override
  String get disposedCasesScreen_helpBody =>
      'তারিখ আপডেট করার সময় নিচের যেকোনো উপযুক্ত ধাপ বেছে নিন, যাতে নিষ্পত্তিকৃত বা নিষ্ক্রিয় নিম্ন আদালতের মামলাটি সক্রিয় মামলার তালিকা থেকে এই তালিকায় চলে আসে। আপিল ও হাইকোর্ট ডিভিশনের মামলার ক্ষেত্রে রেজাল্ট ফিল্ডে নিষ্পত্তির কীওয়ার্ড লিখুন। নোট: মামলাটি সব মামলার তালিকায় এখনও থাকবে।';

  @override
  String get disposedCasesScreen_disposedSteps =>
      'আদালত বিভাগ অনুযায়ী নিষ্পত্তির ধাপ';

  @override
  String get disposedCasesScreen_appellateHighCourtDivision =>
      'আপিল ডিভিশন ও হাইকোর্ট ডিভিশন';

  @override
  String get disposedCasesScreen_gotIt => 'বুঝেছি';

  @override
  String get overdueDatesScreen_title => 'বিলম্বিত তারিখ';

  @override
  String get overdueDatesScreen_empty => 'কোনও বিলম্বিত মামলা নেই';

  @override
  String get overdueDatesScreen_lastUpdated => 'সর্বশেষ আপডেট';

  @override
  String get caseDetailsScreen_title => 'মামলার বিবরণ';

  @override
  String get caseDetailsScreen_delete => 'মুছুন';

  @override
  String get caseDetailsScreen_editCase => 'মামলা সম্পাদনা';

  @override
  String get caseDetailsScreen_close => 'বন্ধ';

  @override
  String get caseDetailsScreen_onBehalfOf => 'পক্ষে';

  @override
  String get caseDetailsScreen_petitioner => 'বাদী';

  @override
  String get caseDetailsScreen_respondent => 'বিবাদী';

  @override
  String get caseDetailsScreen_leadCounsel => 'প্রধান আইনজীবী';

  @override
  String get caseDetailsScreen_caseTitleAndRemark => 'মামলার শিরোনাম ও মন্তব্য';

  @override
  String get caseDetailsScreen_sectionsOrCaseTitle => 'ধারা বা মামলার শিরোনাম';

  @override
  String get caseDetailsScreen_remarksOrCaseSummary =>
      'মন্তব্য বা মামলার সারাংশ';

  @override
  String get caseDetailsScreen_caseHistory => 'মামলার ইতিহাস';

  @override
  String get caseDetailsScreen_phone => 'ফোন';

  @override
  String get caseDetailsScreen_message => 'বার্তা';

  @override
  String caseDetailsScreen_entriesTotal(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'মোট $countString টি এন্ট্রি';
  }

  @override
  String get caseDetailsScreen_noHistoryEntries =>
      'এখনো কোনো কেস হিস্টোরি যুক্ত করা হয়নি।';

  @override
  String get caseDetailsScreen_showHistory => 'দেখুন';

  @override
  String get caseDetailsScreen_hideHistory => 'লুকান';

  @override
  String caseDetailsScreen_daysRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'আর $count দিন বাকি',
      one: 'আর ১ দিন বাকি',
      zero: 'আর ০ দিন বাকি',
    );
    return '$_temp0';
  }

  @override
  String get caseDetailsScreen_setReminder => 'রিমাইন্ডার সেট করুন';

  @override
  String get caseDetailsScreen_editHistoryEntry => 'ইতিহাস এন্ট্রি সম্পাদনা';

  @override
  String get caseDetailsScreen_caseNotFound => 'মামলা পাওয়া যায়নি।';

  @override
  String get caseDetailsScreen_otherInformation => 'অন্যান্য তথ্য';

  @override
  String get caseDetailsScreen_tenderNumber => 'টেন্ডার নম্বর';

  @override
  String get caseDetailsScreen_previousCourtCase => 'পূর্ববর্তী আদালতের মামলা';

  @override
  String get caseDetailsScreen_districtOfOrigin => 'উৎপত্তির জেলা';

  @override
  String caseDetailsScreen_deleteCaseError(String message) {
    return 'মামলা মুছে ফেলা যায়নি: $message';
  }

  @override
  String caseDetailsScreen_deleteHistoryError(String message) {
    return 'ইতিহাস এন্ট্রি মুছে ফেলা যায়নি: $message';
  }

  @override
  String caseDetailsScreen_loadError(String message) {
    return 'মামলা লোড করা যায়নি: $message';
  }

  @override
  String get addEditCaseSheet_title => 'মামলা যোগ করুন';

  @override
  String get addEditCaseSheet_editTitle => 'মামলা সম্পাদনা';

  @override
  String get addEditCaseSheet_higherOrLowerCourt => 'উচ্চতর বা নিম্ন আদালত';

  @override
  String get addEditCaseSheet_division => 'বিভাগ';

  @override
  String get addEditCaseSheet_district => 'জেলা';

  @override
  String get addEditCaseSheet_courtCategory => 'আদালতের ক্যাটেগরি';

  @override
  String get addEditCaseSheet_nameOfCourt => 'আদালতের নাম';

  @override
  String get addEditCaseSheet_honorableJudges => 'মাননীয় বিচারকদের নাম';

  @override
  String get addEditCaseSheet_caseCategory => 'মামলার ক্যাটেগরি';

  @override
  String get addEditCaseSheet_caseNumber => 'মামলা নং';

  @override
  String get addEditCaseSheet_tenderNumber => 'টেন্ডার নম্বর';

  @override
  String get addEditCaseSheet_previousCourtCase => 'পূর্ববর্তী আদালতের মামলা';

  @override
  String get addEditCaseSheet_districtOfOrigin => 'উৎপত্তির জেলা';

  @override
  String get addEditCaseSheet_petitioner => 'বাদী';

  @override
  String get addEditCaseSheet_respondent => 'বিবাদী';

  @override
  String get addEditCaseSheet_petitionerLeadCounsel => 'বাদীর প্রধান আইনজীবী';

  @override
  String get addEditCaseSheet_respondentLeadCounsel => 'বিবাদীর প্রধান আইনজীবী';

  @override
  String get addEditCaseSheet_onBehalf => 'পক্ষে';

  @override
  String get addEditCaseSheet_partyPhone => 'পক্ষের ফোন নং';

  @override
  String get addEditCaseSheet_year => 'বছর';

  @override
  String get addEditCaseSheet_caseTitleAndSection => 'মামলার শিরোনাম বা ধারা';

  @override
  String get addEditCaseSheet_caseRemarks => 'মামলার মন্তব্য';

  @override
  String get addEditCaseSheet_nextDate => 'পরবর্তী তারিখ';

  @override
  String get quickUpdateCase_currentNextDate => 'বর্তমান পরবর্তী তারিখ';

  @override
  String get addEditCaseSheet_pickDate => 'তারিখ নির্বাচন করুন';

  @override
  String get addEditCaseSheet_notification => 'নোটিফিকেশন';

  @override
  String get addEditCaseSheet_dayOffset => 'দিনের অফসেট';

  @override
  String get addEditCaseSheet_offsetSameDay => 'একই দিন';

  @override
  String get addEditCaseSheet_offsetDayBefore => 'আগের দিন';

  @override
  String addEditCaseSheet_offsetDaysBefore(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString দিন আগে';
  }

  @override
  String get addEditCaseSheet_step => 'ধাপ';

  @override
  String get addEditCaseSheet_result => 'ফলাফল';

  @override
  String get addEditCaseSheet_note => 'নোট';

  @override
  String get addEditCaseSheet_save => 'সংরক্ষণ';

  @override
  String get addEditCaseSheet_sectionCourt => 'আদালত ও মোকদ্দমা';

  @override
  String get addEditCaseSheet_sectionParties => 'পক্ষ সমূহ';

  @override
  String get addEditCaseSheet_sectionDetails => 'মামলার শিরোনাম ও মন্তব্য';

  @override
  String get addEditCaseSheet_sectionSchedule => 'পরবর্তী তারিখ ও পদক্ষেপ';

  @override
  String addEditCaseSheet_dependencyRequired(String field) {
    return 'অনুগ্রহ করে প্রথমে $field থেকে একটি বিকল্প নির্বাচন করুন।';
  }

  @override
  String get customDropdown_clear => 'পরিষ্কার';

  @override
  String get customDropdown_selected => 'নির্বাচিত';

  @override
  String get casesModal_addCase => 'মামলা যোগ করুন';

  @override
  String get casesModal_search => 'অনুসন্ধান';

  @override
  String get casesModal_viewCompact => 'সংক্ষিপ্ত ভিউ';

  @override
  String get casesModal_viewExpanded => 'বিস্তারিত ভিউ';

  @override
  String get casesModal_help => 'সাহায্য';

  @override
  String get customDropdown_selectOption => 'অপশন নির্বাচন করুন';

  @override
  String get customDropdown_search => 'অনুসন্ধান';

  @override
  String get customDropdown_noResults => 'কোনো ফলাফল পাওয়া যায়নি';

  @override
  String get customDropdown_done => 'সম্পন্ন';

  @override
  String get casesContact_openWith => 'খুলুন';

  @override
  String get casesContact_whatsapp => 'হোয়াটসঅ্যাপ';

  @override
  String get casesContact_message => 'বার্তা';

  @override
  String get casesContact_phone => 'ফোন';

  @override
  String get casesContact_unableToOpenApp => 'অ্যাপটি খোলা যায়নি।';

  @override
  String get casesContact_unableToOpenWhatsApp => 'হোয়াটসঅ্যাপ খোলা যায়নি।';

  @override
  String get casesContact_unableToCall => 'কল করা যায়নি।';

  @override
  String get casesContact_unableToMessage => 'বার্তা খোলা যায়নি।';

  @override
  String casesScreen_loadError(String message) {
    return 'মামলা লোড করা যায়নি: $message';
  }

  @override
  String get notesScreen_title => 'নোট';

  @override
  String get notesScreen_delete => 'মুছুন';

  @override
  String get notesScreen_pin => 'পিন';

  @override
  String get notesScreen_modified => 'পরিবর্তিত';

  @override
  String get notesScreen_empty =>
      'এখনও কোনো নোট যুক্ত করা হয়নি। যোগ করতে + ট্যাপ করুন।';

  @override
  String get notesScreen_noteTitle => 'শিরোনাম';

  @override
  String get notesScreen_noteBody => 'নোট';

  @override
  String get notesScreen_noteBodyPlaceholder => 'আপনার নোট এখানে লিখুন...';

  @override
  String get notesScreen_drafting => 'খসড়া লেখা হচ্ছে...';

  @override
  String get notesScreen_noteDeleted => 'নোট মোছা হয়েছে';

  @override
  String get notesScreen_undo => 'পূর্বাবস্থায় ফেরত';

  @override
  String get notesScreen_newTextNote => 'টেক্সট নোট';

  @override
  String get notesScreen_newTodo => 'করণীয় তালিকা';

  @override
  String get notesScreen_listItemHint => 'তালিকার আইটেম';

  @override
  String get notesScreen_addItem => 'আইটেম যোগ করুন';

  @override
  String get notesScreen_removeItem => 'আইটেম মুছুন';

  @override
  String notesScreen_itemsMore(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '+$countString আরও';
  }

  @override
  String get caseReferenceScreen_title => 'মামলার রেফারেন্স';

  @override
  String get caseReferenceScreen_referenceAndPageNo => 'রেফারেন্স ও পৃষ্ঠা নং';

  @override
  String get caseReferenceScreen_statute => 'আইন';

  @override
  String get caseReferenceScreen_sectionOrArticle => 'ধারা/অনুচ্ছেদ';

  @override
  String get caseReferenceScreen_titleAndDescription => 'শিরোনাম ও বর্ণনা';

  @override
  String get caseReferenceScreen_commentsNotes => 'মন্তব্য/নোট';

  @override
  String get caseReferenceScreen_empty =>
      'এখনও কোনো রেফারেন্স নেই। যোগ করতে + ট্যাপ করুন।';

  @override
  String get caseReferenceScreen_addTitle => 'মামলার রেফারেন্স যোগ করুন';

  @override
  String get caseReferenceScreen_editTitle => 'মামলার রেফারেন্স সম্পাদনা করুন';

  @override
  String get caseReferenceScreen_pin => 'পিন করুন';

  @override
  String get caseReferenceScreen_unpin => 'আনপিন করুন';

  @override
  String get caseReferenceScreen_saved => 'রেফারেন্স সংরক্ষিত হয়েছে';

  @override
  String get caseReferenceScreen_saveTitle => 'রেফারেন্স সংরক্ষণ করুন';

  @override
  String get caseReferenceScreen_deleted => 'রেফারেন্স মোছা হয়েছে';

  @override
  String get caseReferenceScreen_referenceDeleted => 'রেফারেন্স মোছা হয়েছে';

  @override
  String get caseReferenceScreen_undo => 'পূর্বাবস্থায় ফেরত';

  @override
  String get caseReferenceScreen_refPlaceholder => 'যেমন: ২৫ DLR (AD) ১৪২';

  @override
  String get caseReferenceScreen_statutePlaceholder => 'যেমন: CRPC';

  @override
  String get caseReferenceScreen_sectionPlaceholder => 'যেমন: ধারা ৫৪';

  @override
  String get caseReferenceScreen_titlePlaceholder => 'শিরোনাম ও বর্ণনা';

  @override
  String get caseReferenceScreen_commentsPlaceholder =>
      'এখানে মন্তব্য বা ব্যক্তিগত নোট যোগ করুন...';

  @override
  String get sync_idle => 'সিঙ্ক';

  @override
  String get sync_syncing => 'সিঙ্ক হচ্ছে…';

  @override
  String get sync_success => 'সিঙ্ক হয়েছে';

  @override
  String get sync_paused => 'সিঙ্ক বিরতি';

  @override
  String get sync_error => 'সিঙ্ক ত্রুটি';

  @override
  String get sync_unavailable =>
      'সিঙ্কের জন্য প্রিমিয়াম সাবস্ক্রিপশন প্রয়োজন';

  @override
  String sync_pendingBadge(int count) {
    return 'সিঙ্কের অপেক্ষায় $count';
  }

  @override
  String get sync_offline => 'কোনো সংযোগ নেই';

  @override
  String get sync_permissionsChanged =>
      'আপনার ফার্মের অনুমতি পরিবর্তিত হয়েছে; এই অপেক্ষমাণ কাজটি প্রয়োগ করা হয়নি।';

  @override
  String get sync_clockSkewWarning =>
      'আপনার ডিভাইসের ঘড়ি ভুল বলে মনে হচ্ছে। নির্ভরযোগ্য সিঙ্কের জন্য এটি ঠিক করুন।';

  @override
  String syncConflict_bannerMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countটি দ্বন্দ্ব পর্যালোচনা প্রয়োজন',
      one: 'একটি দ্বন্দ্ব পর্যালোচনা প্রয়োজন',
    );
    return '$_temp0';
  }

  @override
  String get syncConflict_bannerAction => 'পর্যালোচনা করুন';

  @override
  String get syncConflict_title => 'দ্বন্দ্ব পর্যালোচনা';

  @override
  String get syncConflict_subtitle =>
      'অন্য একটি ডিভাইস এই রেকর্ডটি পরিবর্তন করেছে';

  @override
  String syncConflict_editedBy(String name) {
    return '$name সম্পাদনা করেছেন';
  }

  @override
  String get syncConflict_unknownEditor => 'অন্য ডিভাইস';

  @override
  String get syncConflict_intro =>
      'আপনি এবং অন্য একটি ডিভাইস একই ঘর পরিবর্তন করেছেন। প্রতিটির জন্য যে মান রাখতে চান সেটি বাছুন।';

  @override
  String get syncConflict_keepServer => 'সার্ভার';

  @override
  String get syncConflict_keepMine => 'আমার';

  @override
  String get syncConflict_tombstoneTitle => 'সার্ভারে মুছে ফেলা হয়েছে';

  @override
  String get syncConflict_tombstoneBody =>
      'অন্য একটি ডিভাইসে এই রেকর্ডটি মুছে ফেলা হয়েছে। আপনার সংরক্ষিত পরিবর্তন এখনও আছে — সেগুলোর কী হবে তা বেছে নিন।';

  @override
  String get syncConflict_rebaseOntoNewRecord => 'নতুন রেকর্ড হিসেবে রাখুন';

  @override
  String get syncConflict_discard => 'আমার পরিবর্তন বাদ দিন';

  @override
  String get syncConflict_discardConfirmTitle => 'আপনার পরিবর্তন বাদ দেবেন?';

  @override
  String get syncConflict_discardConfirmBody =>
      'সার্ভারের সংস্করণ আপনার অসিঙ্ক করা পরিবর্তন প্রতিস্থাপন করবে। এটি ফেরানো যাবে না।';

  @override
  String get syncConflict_laterEditsTitle => 'পরে সংরক্ষিত পরিবর্তন';

  @override
  String get syncConflict_laterEditsBody =>
      'এই দ্বন্দ্বের সমাধান না হওয়া পর্যন্ত এই পরিবর্তনগুলো সংরক্ষিত থাকবে।';

  @override
  String get syncConflict_resolvedNotice =>
      'এই দ্বন্দ্বটি ইতিমধ্যে সমাধান হয়েছে।';

  @override
  String get syncConflict_missingNotice => 'এই দ্বন্দ্বটি আর পাওয়া যাচ্ছে না।';

  @override
  String get syncStatus_title => 'সিঙ্ক স্ট্যাটাস';

  @override
  String get syncStatus_subtitle => 'যে সব পরিবর্তন পাঠানোর অপেক্ষায় আছে';

  @override
  String get syncStatus_lastSyncedNever => 'কখনও সিঙ্ক হয়নি';

  @override
  String syncStatus_lastSynced(String time) {
    return 'শেষ সিঙ্ক $time';
  }

  @override
  String get syncStatus_filterAll => 'সব';

  @override
  String get syncStatus_filterPending => 'অপেক্ষমাণ';

  @override
  String get syncStatus_filterConflicted => 'দ্বন্দ্বপূর্ণ';

  @override
  String get syncStatus_filterBlocked => 'আটকে আছে';

  @override
  String get syncStatus_statePending => 'অপেক্ষমাণ';

  @override
  String get syncStatus_statePushing => 'পাঠানো হচ্ছে';

  @override
  String get syncStatus_stateConflicted => 'দ্বন্দ্বপূর্ণ';

  @override
  String get syncStatus_stateBlocked => 'আটকে আছে';

  @override
  String get syncStatus_stateUnknown => 'অজানা';

  @override
  String get syncStatus_retry => 'আবার চেষ্টা করুন';

  @override
  String get syncStatus_discard => 'বাতিল করুন';

  @override
  String get syncStatus_reviewConflict => 'দ্বন্দ্ব দেখুন';

  @override
  String get syncStatus_moreActions => 'আরও কাজ';

  @override
  String syncStatus_queued(String time) {
    return 'সারিতে যোগ হয়েছে $time';
  }

  @override
  String syncStatus_attempted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count বার চেষ্টা হয়েছে',
      one: 'একবার চেষ্টা হয়েছে',
    );
    return '$_temp0';
  }

  @override
  String syncStatus_lastAttempt(String time) {
    return 'শেষ চেষ্টা $time';
  }

  @override
  String syncStatus_lastError(String message) {
    return 'শেষ ত্রুটি: $message';
  }

  @override
  String get syncStatus_blockedWhy => 'কেন আটকে আছে';

  @override
  String get syncStatus_blockedCauseRefused =>
      'সার্ভার এই পরিবর্তনটি গ্রহণ করেনি।';

  @override
  String get syncStatus_blockedCauseAttempts =>
      'অনেকবার চেষ্টার পরও সফল না হওয়ায় সিঙ্ক আর চেষ্টা করছে না।';

  @override
  String get syncStatus_timeJustNow => 'এইমাত্র';

  @override
  String syncStatus_timeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count মিনিট আগে',
      one: '১ মিনিট আগে',
    );
    return '$_temp0';
  }

  @override
  String syncStatus_timeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ঘণ্টা আগে',
      one: '১ ঘণ্টা আগে',
    );
    return '$_temp0';
  }

  @override
  String syncStatus_timeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count দিন আগে',
      one: '১ দিন আগে',
    );
    return '$_temp0';
  }

  @override
  String get syncStatus_emptyTitle => 'সিঙ্ক করার মতো কিছু নেই';

  @override
  String get syncStatus_emptyBody =>
      'এই ডিভাইসের প্রতিটি পরিবর্তন পাঠানো হয়েছে।';

  @override
  String get syncStatus_retried => 'পরিবর্তনটি আবার পাঠানো হবে।';

  @override
  String get syncStatus_discardTitle => 'এই পরিবর্তনটি বাতিল করবেন?';

  @override
  String get syncStatus_discardBody =>
      'সারিতে থাকা পরিবর্তনটি মুছে যাবে এবং রেকর্ডটি সার্ভারে সংরক্ষিত সংস্করণে ফিরে যাবে। এটি ফিরিয়ে আনা যাবে না।';

  @override
  String get syncStatus_discardConfirm => 'বাতিল করুন';

  @override
  String get syncStatus_discarded => 'সারিতে থাকা পরিবর্তনটি বাতিল করা হয়েছে।';

  @override
  String get syncStatus_discardRestoredLocally =>
      'পরিবর্তনটি বাতিল করা হয়েছে। রেকর্ডটি এই ডিভাইসে সর্বশেষ সংরক্ষিত কপি থেকে ফিরিয়ে আনা হয়েছে।';

  @override
  String get syncStatus_pendingDeletion => 'মুছে ফেলা অপেক্ষমাণ';

  @override
  String get syncStatus_export => 'ডায়াগনস্টিক বান্ডেল এক্সপোর্ট করুন';

  @override
  String get syncStatus_exportShort => 'এক্সপোর্ট';

  @override
  String get syncStatus_exportTitle => 'ডায়াগনস্টিক বান্ডেল এক্সপোর্ট করুন';

  @override
  String get syncStatus_exportMetadataOnly => 'শুধু মেটাডেটা';

  @override
  String get syncStatus_exportMetadataOnlyBody =>
      'ধরন, অবস্থা, পুনঃচেষ্টার সংখ্যা ও ত্রুটির বার্তা। কোনো মামলার তথ্য থাকবে না।';

  @override
  String get syncStatus_exportIncludePayloads => 'পেলোডসহ';

  @override
  String get syncStatus_exportIncludePayloadsBody =>
      'সারিতে থাকা পরিবর্তনগুলোও যোগ হবে, যেখানে মামলার বিবরণ থাকতে পারে।';

  @override
  String get syncStatus_exportConsentTitle => 'মামলার তথ্য যোগ করবেন?';

  @override
  String get syncStatus_exportConsentBody =>
      'বান্ডেলে সারিতে থাকা পরিবর্তনগুলো থাকবে, যেখানে মামলার নম্বর, নাম ও নোট থাকতে পারে। শুধু বিশ্বস্ত কারও সঙ্গে শেয়ার করুন।';

  @override
  String get syncStatus_exportConsentConfirm => 'যোগ করুন';

  @override
  String get syncStatus_exportReminder =>
      'সাত দিন পর, বা সাপোর্টের আর প্রয়োজন না হলে সঙ্গে সঙ্গে এই ফাইলটি মুছে ফেলুন।';

  @override
  String syncStatus_exportSaved(String path) {
    return 'ডায়াগনস্টিক বান্ডেল $path-এ সংরক্ষিত হয়েছে';
  }

  @override
  String get syncStatus_exportFailed =>
      'ডায়াগনস্টিক বান্ডেল সংরক্ষণ করা যায়নি।';

  @override
  String get logout_connectToSync =>
      'আগে আপনার পরিবর্তনগুলো সিঙ্ক করতে ইন্টারনেটে যুক্ত হন।';

  @override
  String get logout_logOutAnyway => 'তবুও লগ আউট করুন';

  @override
  String get logout_unsyncedWarningTitle => 'কিছু পরিবর্তন এখনও সিঙ্ক হয়নি';

  @override
  String get logout_unsyncedWarningBody =>
      'কিছু তথ্য এখনও ক্লাউডে সিঙ্ক হয়নি। এখন লগ আউট করলে সেই সিঙ্ক না হওয়া তথ্য মুছে যাবে।';

  @override
  String get logout_proceed => 'লগ আউট করুন';

  @override
  String get logout_backupPromptTitle => 'লোকাল স্টোরেজে ডেটা ব্যাকআপ করুন';

  @override
  String logout_backedUpTo(String path) {
    return 'আপনার তথ্য $path-এ ব্যাকআপ করা হয়েছে। লগ ইন করার পর আপনি এটি পুনরুদ্ধার করতে পারবেন।';
  }

  @override
  String get logout_exportCancelled =>
      'লগ আউট বাতিল হয়েছে; কিছুই মুছে ফেলা হয়নি।';

  @override
  String get logout_exportFailed =>
      'নিরাপত্তা কপি সংরক্ষণ করা যায়নি, তাই কিছুই মুছে ফেলা হয়নি।';

  @override
  String get logout_syncFailed => 'আপনার পরিবর্তনগুলো সিঙ্ক করা যায়নি।';

  @override
  String get recoveryLock_title => 'অনেক দিন অফলাইনে আছেন';

  @override
  String recoveryLock_message(int days, String path) {
    return 'আপনি $days দিন অফলাইনে আছেন। আপনার স্থানীয় পরিবর্তনগুলো $path-এ সংরক্ষণ করা হয়েছে। সম্পাদনা চালু করার আগে সার্ভার থেকে নতুন ডেটা আনতে হবে।';
  }

  @override
  String recoveryLock_messageNoCopy(int days) {
    return 'আপনি $days দিন অফলাইনে আছেন। সার্ভার থেকে নতুন ডেটা আনার আগে একটি নিরাপত্তা কপি সংরক্ষণ করতে হবে।';
  }

  @override
  String get recoveryLock_saveTitle => 'নিরাপত্তা কপি সংরক্ষণ করুন';

  @override
  String get recoveryLock_saveBody =>
      'এই ডিভাইসের সব কিছু — আপনার মামলা, নোট ও এখনও সিঙ্ক না হওয়া পরিবর্তন — একটি এনক্রিপ্টেড ফাইলে সিল করা হবে। নিজে মনে রাখতে পারবেন এমন একটি পাসফ্রেজ দিন; এটি কোথাও সংরক্ষিত হয় না।';

  @override
  String get recoveryLock_saveBodyUnencrypted =>
      'এই ডিভাইসের সব কিছু — আপনার মামলা, নোট ও এখনও সিঙ্ক না হওয়া পরিবর্তন — প্রথমে একটি এনক্রিপ্ট-না-করা ফাইলে সংরক্ষণ করা হবে।';

  @override
  String get recoveryLock_saveAction => 'নিরাপত্তা কপি সংরক্ষণ করুন';

  @override
  String recoveryLock_savedTo(String path) {
    return 'নিরাপত্তা কপি $path-এ সংরক্ষিত হয়েছে';
  }

  @override
  String get recoveryLock_saveFailed =>
      'নিরাপত্তা কপি সংরক্ষণ করা যায়নি। আপনার ডেটা এখনও এই ডিভাইসেই আছে — আবার চেষ্টা করুন।';

  @override
  String get recoveryLock_proceed => 'নতুন ডেটা আনুন';

  @override
  String get recoveryLock_proceedConfirmTitle =>
      'এই ডিভাইসটি সার্ভারের কপি দিয়ে বদলে ফেলবেন?';

  @override
  String get recoveryLock_proceedConfirmBody =>
      'আপনার স্থানীয় পরিবর্তনগুলো সার্ভারের ডেটা দিয়ে প্রতিস্থাপিত হবে। আপনি যে নিরাপত্তা কপিটি সংরক্ষণ করেছেন, সেটিই তাদের ফিরে পাওয়ার একমাত্র উপায়।';

  @override
  String get recoveryLock_close => 'বন্ধ করুন';

  @override
  String get recoveryLock_closeBody =>
      'পুনরুদ্ধার সফল না হওয়া পর্যন্ত অ্যাপটি লক থাকে এবং ক্লাউডে কিছু লেখা হয় না।';

  @override
  String get recoveryLock_working => 'নতুন ডেটা আনা হচ্ছে…';

  @override
  String get recoveryLock_failed =>
      'পুনরুদ্ধার সম্পন্ন করা যায়নি। আপনার ডেটা এখনও এই ডিভাইসে আছে এবং অ্যাপটি লক থাকবে; আবার চেষ্টা করুন।';

  @override
  String syncStatus_entryTitle(String entity, String operation) {
    return '$entity $operation';
  }

  @override
  String get paywall_title => 'সাবস্ক্রিপশন প্ল্যান';

  @override
  String get paywall_limitTitle => 'ফ্রি প্ল্যানের সীমা পূর্ণ হয়েছে';

  @override
  String paywall_limitBody(String limit) {
    return 'ফ্রি প্ল্যানে সর্বোচ্চ $limitটি মামলা রাখা যায়। একটি মামলা মুছে ফেললে জায়গা খালি হয়; কেস ম্যানেজমেন্ট, নোটস এবং কেস রেফারেন্স এর ব্যবহার, সম্পাদনা ও প্রিন্ট — সবই ফ্রি থাকবে।';
  }

  @override
  String get paywall_benefitsTitle => 'সাবস্ক্রিপশন প্ল্যানে যা থাকে';

  @override
  String get paywall_featureUnlimitedCasesTitle => 'আনলিমিটেড মামলা';

  @override
  String get paywall_featureUnlimitedCasesBody =>
      'যত খুশি মামলা সংরক্ষণ করুন, কোনো সীমা ছাড়াই।';

  @override
  String get paywall_featureDisasterRecoveryTitle => 'দুর্যোগে ডেটা পুনরুদ্ধার';

  @override
  String get paywall_featureDisasterRecoveryBody =>
      'আপনার ফোন হারিয়ে গেলে বা নষ্ট হয়ে গেলে আপনার ডেটা সবসময় ক্লাউডে নিরাপদ থাকে। আপনার অ্যাকাউন্ট দিয়ে নতুন ডিভাইসে লগ ইন করলেই আপনি পুরোনো ডেটা পেয়ে যাবেন।';

  @override
  String get paywall_featureRealTimeBackupTitle => 'রিয়েল-টাইম ব্যাকআপ';

  @override
  String get paywall_featureRealTimeBackupBody =>
      'প্রতিটি পরিবর্তন সঙ্গে সঙ্গে ক্লাউডে সংরক্ষিত হয়।';

  @override
  String get paywall_featureMultiDeviceTitle => 'একাধিক ডিভাইসে ব্যবহার';

  @override
  String get paywall_featureMultiDeviceBody =>
      'একই সময়ে একাধিক ডিভাইস থেকে আপনার ডায়েরি ব্যবহার করুন।';

  @override
  String get paywall_featureCollaborationTitle => 'সহযোগিতা';

  @override
  String get paywall_featureCollaborationBody =>
      'একই ডায়েরিতে আপনার সহযোগীদের সঙ্গে একসঙ্গে কাজ করুন।';

  @override
  String get paywall_plansTitle => 'প্ল্যান';

  @override
  String get paywall_planMonthly => '১ মাস';

  @override
  String get paywall_planQuarterly => '৩ মাস';

  @override
  String get paywall_planHalfYearly => '৬ মাস';

  @override
  String get paywall_planAnnual => '১ বছর';

  @override
  String paywall_planWasPrice(String price) {
    return '৳$price';
  }

  @override
  String paywall_planDiscount(String percent) {
    return '$percent% ছাড়';
  }

  @override
  String get paywall_subscribe => 'সাবস্ক্রাইব';

  @override
  String get adminPanel_title => 'অ্যাডমিন প্যানেল';

  @override
  String get adminPanel_paymentRequests => 'পেমেন্ট অনুরোধ';

  @override
  String get adminPanel_paymentRequestsSubtitle =>
      'জমা দেওয়া পেমেন্ট অনুমোদন বা প্রত্যাখ্যান করুন';

  @override
  String get adminPanel_unverifiedAccounts => 'অযাচিত অ্যাকাউন্ট';

  @override
  String get adminPanel_unverifiedAccountsSubtitle =>
      'যে সাইন-আপগুলো কখনও নিশ্চিত হয়নি';

  @override
  String get adminPanel_unverifiedTitle => 'অযাচিত অ্যাকাউন্ট';

  @override
  String get adminPanel_unverifiedEmpty =>
      'সব অ্যাকাউন্টই তাদের ঠিকানা নিশ্চিত করেছে।';

  @override
  String get adminPanel_unverifiedLoadFailed =>
      'অ্যাকাউন্টগুলো লোড করা যায়নি।';

  @override
  String get adminPanel_created => 'তৈরি';

  @override
  String get adminPanel_lastSignIn => 'সর্বশেষ সাইন-ইন';

  @override
  String get adminPanel_delete => 'মুছুন';

  @override
  String get adminPanel_deleteTitle => 'এই অ্যাকাউন্টটি মুছবেন?';

  @override
  String get adminPanel_deleteBody =>
      'অ্যাকাউন্টটি কখনও ঠিকানা নিশ্চিত করেনি এবং কিছুই করেনি, তাই এটি স্থায়ীভাবে মুছে যাবে। এটি ফেরানো যাবে না।';

  @override
  String get adminPanel_deleteConfirm => 'অ্যাকাউন্ট মুছুন';

  @override
  String get adminPanel_deleteBlocked =>
      'এই অ্যাকাউন্টে ডেটা আছে বা এটি নিশ্চিত হয়েছে, তাই এখান থেকে মোছা যাবে না।';

  @override
  String get adminPanel_deleted => 'অ্যাকাউন্ট মুছে ফেলা হয়েছে।';

  @override
  String get adminPanel_search => 'খুঁজুন';

  @override
  String get adminPanel_searchHint => 'খুঁজুন';

  @override
  String get adminPanel_noResults => 'কোনো ফলাফল পাওয়া যায়নি।';

  @override
  String get adminPanel_pending => 'অপেক্ষমাণ';

  @override
  String get adminPanel_resolved => 'সমাধানকৃত';

  @override
  String adminPanel_sectionCount(String count) {
    return '$count';
  }

  @override
  String get adminPanel_emptyPending =>
      'সিদ্ধান্তের অপেক্ষায় কোনো পেমেন্ট নেই।';

  @override
  String get adminPanel_emptyResolved =>
      'এখনও কোনো পেমেন্ট অনুমোদন বা বাতিল করা হয়নি।';

  @override
  String get adminPanel_approve => 'অনুমোদন';

  @override
  String get adminPanel_reject => 'বাতিল';

  @override
  String get adminPanel_rejectTitle => 'এই পেমেন্ট বাতিল করুন';

  @override
  String get adminPanel_rejectNoteLabel => 'গ্রাহকের জন্য নোট (ঐচ্ছিক)';

  @override
  String get adminPanel_rejectNoteHint => 'এই পেমেন্ট কেন গ্রহণ করা হয়নি';

  @override
  String get adminPanel_rejectConfirm => 'পেমেন্ট বাতিল করুন';

  @override
  String adminPanel_detailLabel(String label, String value) {
    return '$label: $value';
  }

  @override
  String get adminPanel_detailLabelTrx => 'ট্রানজেকশন আইডি';

  @override
  String get adminPanel_detailLabelMfs => 'মাধ্যম';

  @override
  String get adminPanel_detailLabelName => 'নাম';

  @override
  String get adminPanel_detailLabelEmail => 'ইমেইল';

  @override
  String get adminPanel_detailLabelBar => 'বার অ্যাসোসিয়েশন';

  @override
  String get adminPanel_detailLabelMembership => 'সদস্য নম্বর';

  @override
  String get adminPanel_detailLabelMobile => 'মোবাইল';

  @override
  String get adminPanel_detailLabelSubmitted => 'জমা';

  @override
  String get adminPanel_detailLabelNote => 'নোট';

  @override
  String get adminPanel_noValue => '—';

  @override
  String get adminPanel_statusApproved => 'অনুমোদিত';

  @override
  String get adminPanel_statusRejected => 'বাতিল';

  @override
  String get adminPanel_statusPending => 'অপেক্ষমাণ';

  @override
  String get adminPanel_approvedExpiry => 'প্রিমিয়ামের মেয়াদ';

  @override
  String get adminPanel_approvedBy => 'অনুমোদনকারী';

  @override
  String get adminPanel_rejectedBy => 'বাতিলকারী';

  @override
  String get adminPanel_loading => 'পেমেন্ট অনুরোধ লোড হচ্ছে…';

  @override
  String get adminPanel_loadFailed => 'পেমেন্ট অনুরোধ লোড করা যায়নি।';

  @override
  String get adminPanel_retry => 'আবার চেষ্টা করুন';

  @override
  String get adminPanel_approved =>
      'পেমেন্ট অনুমোদিত হয়েছে। গ্রাহক এখন প্রিমিয়াম।';

  @override
  String get adminPanel_rejected => 'পেমেন্ট বাতিল করা হয়েছে।';

  @override
  String get adminPanel_failedNotAdmin =>
      'শুধুমাত্র একজন প্রশাসক এটি করতে পারবেন।';

  @override
  String get adminPanel_failedNotFound => 'এই পেমেন্টটি আর নেই।';

  @override
  String get adminPanel_failedAlreadyResolved =>
      'এই পেমেন্টের সিদ্ধান্ত আগেই হয়ে গেছে।';

  @override
  String get adminPanel_failedUnexpected => 'এটি কাজ করেনি। আবার চেষ্টা করুন।';

  @override
  String get general_tomorrow => 'আগামীকাল';

  @override
  String get sharedActions_save => 'সংরক্ষণ';

  @override
  String get sharedActions_cancel => 'বাতিল';

  @override
  String get sharedActions_delete => 'মুছুন';

  @override
  String get sharedActions_edit => 'সম্পাদনা';

  @override
  String get sharedActions_search => 'অনুসন্ধান';

  @override
  String get sharedActions_add => 'যোগ করুন';

  @override
  String get sharedActions_update => 'আপডেট';

  @override
  String get sharedActions_close => 'বন্ধ';

  @override
  String get sharedActions_yes => 'হ্যাঁ';

  @override
  String get sharedActions_no => 'না';

  @override
  String get sharedDialogs_confirmDeleteTitle => 'মুছে ফেলা নি্চিত করুন';

  @override
  String get sharedDialogs_confirmDeleteMessage =>
      'আপনি কি এই আইটেমটি মুছে ফেলতে চান?';

  @override
  String get sharedDialogs_noResults => 'কোনো ফলাফল পাওয়া যায়নি।';

  @override
  String get sharedDialogs_requiredField => 'এই ক্ষেত্রটি আবশ্যক।';

  @override
  String get sharedDialogs_ok => 'ঠিক আছে';

  @override
  String get sharedDialogs_cancel => 'বাতিল';

  @override
  String sharedMessages_error(String message) {
    return 'ত্রুটি: $message';
  }

  @override
  String get sharedMessages_signInRequired => 'চালিয়ে যেতে সাইন ইন করুন';

  @override
  String get appShell_exitTitle => 'অ্যাপ থেকে প্রস্থান?';

  @override
  String get appShell_exitMessage =>
      'আপনি কি লিগ্যাল কেস ডায়েরি থেকে প্রস্থান করতে চান?';

  @override
  String get appShell_exit => 'প্রস্থান';

  @override
  String get databaseRecovery_title => 'ডেটাবেস লক করা হয়েছে';

  @override
  String get databaseRecovery_body =>
      'আপনার লোকাল কেস ডায়েরির এনক্রিপশন কী পাওয়া যাচ্ছে না। অপারেটিং সিস্টেম আপডেটের পর বা অ্যাপ ডেটা মুছে ফেললে এমন হতে পারে।\n\nঅফলাইনে অ্যাপটি ব্যবহার চালিয়ে যেতে হলে লোকাল ডেটাবেস রিসেট করতে হবে। সিঙ্ক না করা সব লোকাল ডেটা হারিয়ে যাবে।';

  @override
  String get databaseRecovery_reset => 'লোকাল ডেটাবেস রিসেট করুন';

  @override
  String get courtCategory_appellateDivision => 'আপিল বিভাগ';

  @override
  String get courtCategory_highCourtDivision => 'হাই কোর্ট বিভাগ';

  @override
  String get courtCategory_lowerDivisionalCourts => 'বিভাগীয় নিম্ন আদালত সমূহ';

  @override
  String get lowerCourtCategory_districtSessionsCriminal =>
      'দায়রা জজ আদালত (ফৌজদারি)';

  @override
  String get lowerCourtCategory_districtCourtsCivil =>
      'জেলা জজ আদালত (দেওয়ানি)';

  @override
  String get lowerCourtCategory_metropolitanSessionsJudgeCriminal =>
      'মহানগর দায়রা জজ আদালত (ফৌজদারি)';

  @override
  String get lowerCourtCategory_chiefJudicialMagistrate =>
      'চীফ জুডিসিয়াল ম্যাজিস্ট্রেট আদালত';

  @override
  String get lowerCourtCategory_chiefMetropolitanMagistrate =>
      'চীফ মেট্রোপলিটন ম্যাজিস্ট্রেট আদালত';

  @override
  String get lowerCourtCategory_executiveMagistrate =>
      'নির্বাহী ম্যাজিস্ট্রেট ও অন্যান্য আদালত';

  @override
  String get lowerCourtCategory_tribunals => 'ট্রাইব্যুনাল সমূহ';

  @override
  String get onBehalf_plaintiff => 'বাদী';

  @override
  String get onBehalf_defendant => 'বিবাদী';

  @override
  String get onBehalf_accused => 'অভিযুক্ত';

  @override
  String get onBehalf_appellant => 'আপিলকারী';

  @override
  String get onBehalf_petitioner => 'বাদী';

  @override
  String get onBehalf_respondent => 'বিবাদী';

  @override
  String get onBehalf_writPetitioner => 'রিট আবেদনকারী';

  @override
  String get onBehalf_state => 'রাষ্ট্র';

  @override
  String get onBehalf_victim => 'ভিকটিম';

  @override
  String get onBehalf_complainant => 'বাদী';

  @override
  String get onBehalf_informant => 'তথ্যদাতা';

  @override
  String get onBehalf_applicant => 'আবেদনকারী';

  @override
  String get onBehalf_claimant => 'দাবিদার';

  @override
  String get onBehalf_objector => 'আপত্তিকারী';

  @override
  String get caseType_civil => 'দেওয়ানি';

  @override
  String get caseType_criminal => 'ফৌজদারি';

  @override
  String get caseType_writ => 'রিট';

  @override
  String get caseType_appeal => 'আপিল';

  @override
  String get caseType_revision => 'রিভিশন';

  @override
  String get step_filed => 'দায়েরকৃত';

  @override
  String get step_hearing => 'শ্রবণ';

  @override
  String get step_disposed => 'নিষ্পত্তিকৃত';

  @override
  String get step_pending => 'বিবেচনাধীন';

  @override
  String get division_dhaka => 'ঢাকা';

  @override
  String get division_chattagram => 'চট্টগ্রাম';

  @override
  String get division_rajshahi => 'রাজশাহী';

  @override
  String get division_khulna => 'খুলনা';

  @override
  String get division_barishal => 'বরিশাল';

  @override
  String get division_sylhet => 'সিলেট';

  @override
  String get division_rangpur => 'রংপুর';

  @override
  String get division_mymensingh => 'ময়মনসিংহ';

  @override
  String messageTemplate_clientSms(
    String clientName,
    String caseNumber,
    String nextDate,
    String court,
    String lawyerName,
  ) {
    return 'প্রিয় $clientName, আপনার মামলা $caseNumber এর পরবর্তী তারিখ $nextDate, $court। - $lawyerName';
  }

  @override
  String messageTemplate_clientWhatsApp(
    String clientName,
    String caseNumber,
    String nextDate,
    String court,
    String lawyerName,
  ) {
    return 'প্রিয় $clientName, আপনার মামলা $caseNumber এর পরবর্তী তারিখ $nextDate, $court। - $lawyerName';
  }

  @override
  String get settingsScreen_title => 'সেটিংস';

  @override
  String get settingsScreen_accountAndProfile => 'অ্যাকাউন্ট ও প্রোফাইল';

  @override
  String get settingsScreen_profile => 'প্রোফাইল';

  @override
  String get settingsScreen_manageAccount => 'অ্যাকাউন্ট ব্যবস্থাপনা';

  @override
  String get settingsScreen_onlineSync => 'অনলাইন সিঙ্ক';

  @override
  String get settingsScreen_backupAndRestore => 'ব্যাকআপ ও পুনরুদ্ধার';

  @override
  String get settingsScreen_editCourtSteps => 'আদালত/ধাপ সম্পাদনা';

  @override
  String get settingsScreen_notifications => 'নোটিফিকেশন';

  @override
  String get settingsScreen_language => 'ভাষা';

  @override
  String get settingsScreen_viewSettings => 'ভিউ সেটিংস';

  @override
  String get settingsScreen_guidelines => 'নির্দেশনা ও প্রশ্নোত্তর';

  @override
  String get settingsScreen_about => 'সম্পর্কিত';

  @override
  String get settingsScreen_sectionGeneral => 'সাধারণ';

  @override
  String get settingsScreen_sectionPreferences => 'পছন্দসমূহ';

  @override
  String get settingsScreen_sectionAppInfo => 'অ্যাপ সম্পর্কিত তথ্য';

  @override
  String get settingsScreen_searchTooltip => 'সেটিংস অনুসন্ধান';

  @override
  String get settingsScreen_searchHint => 'অনুসন্ধান';

  @override
  String get settingsScreen_closeSearchTooltip => 'অনুসন্ধান বন্ধ করুন';

  @override
  String get settingsScreen_noResults => 'কোনো সেটিংস পাওয়া যায়নি';

  @override
  String get settingsScreen_languageEnglish => 'English';

  @override
  String get settingsScreen_languageBengali => 'বাংলা';

  @override
  String get settingsLanguage_selectHeading => 'অ্যাপের ভাষা নির্বাচন করুন';

  @override
  String get settingsLanguage_intro =>
      'অ্যাপের সব লেখা, তারিখ ও বার্তা এখানে বেছে নেওয়া ভাষায় দেখানো হবে।';

  @override
  String get settingsLanguage_previewTitle => 'এই ভাষায় আজকের তারিখ';

  @override
  String get settingsLanguage_selected => 'নির্বাচিত';

  @override
  String get settingsLanguage_note =>
      'এটি শুধু অ্যাপের ইন্টারফেস বদলায়। আপনার সংরক্ষিত মামলা ও নোট আগের মতোই থাকবে।';

  @override
  String get settingsAccountProfile_sectionProfile => 'প্রোফাইল';

  @override
  String get settingsAccountProfile_sectionAccount => 'অ্যাকাউন্ট';

  @override
  String get settingsAccountProfile_sectionFirm => 'ফার্ম';

  @override
  String get settingsAccountProfile_profileSubtitle =>
      'আপনার নাম, বার অ্যাসোসিয়েশন ও সদস্যপদ সংক্রান্ত তথ্য';

  @override
  String get settingsAccountProfile_manageAccountSubtitle =>
      'আপনার অ্যাকাউন্টের তথ্য, পাসওয়ার্ড ও সাইন-আউট';

  @override
  String get settingsAccountProfile_subscriptionSubtitle =>
      'আপনার প্ল্যান, মেয়াদ ও ক্রয়ের ইতিহাস';

  @override
  String get settingsAccountProfile_manageAssociatesSubtitle =>
      'সহকারী, আমন্ত্রণ ও ফার্মের অনুমতি পরিচালনা করুন';

  @override
  String get settingsProfile_title => 'প্রোফাইল';

  @override
  String get settingsProfile_editTooltip => 'প্রোফাইল সম্পাদনা';

  @override
  String get settingsProfile_fullName => 'পূর্ণ নাম';

  @override
  String get settingsProfile_barAssociation => 'বার অ্যাসোসিয়েশন';

  @override
  String get settingsProfile_membershipNo => 'সদস্য নম্বর';

  @override
  String get settingsProfile_officeAddress => 'অফিসের ঠিকানা';

  @override
  String get settingsProfile_mobileNo => 'মোবাইল নম্বর';

  @override
  String get settingsProfile_yourName => 'আপনার নাম';

  @override
  String settingsProfile_displayName(String name) {
    return 'অ্যাড. $name';
  }

  @override
  String get settingsProfile_editTitle => 'প্রোফাইল সম্পাদনা';

  @override
  String get settingsProfile_fullNameHint => 'আপনার পূর্ণ নাম লিখুন';

  @override
  String get settingsProfile_barAssociationHint =>
      'বার অ্যাসোসিয়েশনের নাম লিখুন';

  @override
  String get settingsProfile_membershipNoHint => 'নিবন্ধন নম্বর লিখুন';

  @override
  String get settingsProfile_officeAddressHint => 'আপনার অফিসের ঠিকানা লিখুন';

  @override
  String get settingsProfile_save => 'প্রোফাইল সংরক্ষণ করুন';

  @override
  String get settingsProfile_saved => 'প্রোফাইল সংরক্ষিত হয়েছে (অফলাইন)';

  @override
  String get settingsProfile_savedOnline => 'প্রোফাইল সংরক্ষিত হয়েছে';

  @override
  String get settingsManageAccount_title => 'অ্যাকাউন্ট ব্যবস্থাপনা';

  @override
  String get settingsManageAccount_changePassword => 'পাসওয়ার্ড পরিবর্তন';

  @override
  String get settingsSubscription_freePlanLimitations =>
      'ফ্রি প্ল্যানের সীমাবদ্ধতা';

  @override
  String settingsSubscription_freeLimitCases(String limit) {
    return 'একসাথে সর্বোচ্চ $limitটি মামলা। একটি মামলা মুছে ফেললে জায়গা খালি হয়।';
  }

  @override
  String get settingsSubscription_freeLimitCloud =>
      'ক্লাউড সুবিধাগুলো — রিয়েল-টাইম ব্যাকআপ, অন্য ডিভাইস থেকে কাজ করা, এবং সহযোগীদের সঙ্গে ডায়েরি ভাগ করা — পেইড প্ল্যানে পাওয়া যায়।';

  @override
  String get settingsSubscription_freeLimitRecovery =>
      'ফোন হারিয়ে গেলে বা নষ্ট হলে, ফ্রি অ্যাকাউন্টের ডায়েরির কোনো ক্লাউড কপি থাকে না যেখান থেকে পুনরুদ্ধার করা যাবে।';

  @override
  String get settingsSubscription_currentPlan => 'বর্তমান প্ল্যান';

  @override
  String get settingsSubscription_paid => 'পরিশোধিত';

  @override
  String get settingsSubscription_dateTime => 'তারিখ ও সময়';

  @override
  String get settingsSubscription_title => 'সাবস্ক্রিপশন';

  @override
  String get settingsManageAccount_subscriptionDetails => 'সাবস্ক্রিপশন বিবরণ';

  @override
  String get settingsManageAccount_purchaseNewSubscription =>
      'নতুন সাবস্ক্রিপশন ক্রয়';

  @override
  String get settingsManageAccount_logout => 'লগআউট';

  @override
  String get settingsManageAccount_deleteAccount => 'অ্যাকাউন্ট মুছুন';

  @override
  String get settingsManageAccount_deleteCannotBeUndone =>
      'এই কাজটি ফিরিয়ে আনা যাবে না';

  @override
  String get settingsManageAccount_deleteLocalAndCloudData =>
      'লোকাল ও ক্লাউড ডেটা মুছুন';

  @override
  String get settingsManageAccount_deleteLocalData => 'লোকাল ডেটা মুছুন';

  @override
  String get settingsManageAccount_deleteDataTitle => 'ডেটা মুছে ফেলবেন?';

  @override
  String get settingsManageAccount_deleteDataBodyCloud =>
      'এই ডিভাইস ও আপনার অ্যাকাউন্ট থেকে কী মুছবেন তা টিক দিন। আপনার প্রোফাইল, সাবস্ক্রিপশন ও সেটিং অপরিবর্তিত থাকবে।';

  @override
  String get settingsManageAccount_deleteDataBodyLocal =>
      'এই ডিভাইস থেকে কী মুছবেন তা টিক দিন। আপনার প্রোফাইল, সাবস্ক্রিপশন ও সেটিং অপরিবর্তিত থাকবে।';

  @override
  String get settingsManageAccount_deleteDataCases => 'মামলা';

  @override
  String get settingsManageAccount_deleteDataNotes => 'নোট';

  @override
  String get settingsManageAccount_deleteDataCaseReferences => 'কেস রেফারেন্স';

  @override
  String get settingsManageAccount_deleteDataCustomSeedData => 'কাস্টম ডেটা';

  @override
  String get settingsManageAccount_deleteDataCustomSeedDataHint =>
      'আপনার যোগ করা আদালতের ক্যাটেগরি, আদালতের নাম, ধাপ, মামলার ধরন ও পক্ষগুলো';

  @override
  String get settingsManageAccount_deleteDataConfirm => 'নির্বাচিত মুছুন';

  @override
  String get settingsManageAccount_deleteDataConfirmPhrase => 'delete my data';

  @override
  String get settingsManageAccount_deleteDataDone =>
      'আপনার নির্বাচিত ডেটা মুছে ফেলা হয়েছে।';

  @override
  String get settingsManageAccount_deleteDataCloudPending =>
      'এই ডিভাইস থেকে আপনার ডেটা মুছে ফেলা হয়েছে। অ্যাকাউন্টের কপিগুলো পরের সিঙ্কে মুছে যাবে।';

  @override
  String get settingsManageAccount_deleteDataNeedsConnection =>
      'আপনার ক্লাউড ডেটা মুছতে ইন্টারনেটে সংযুক্ত হন। কিছুই মুছে ফেলা হয়নি।';

  @override
  String get settingsManageAccount_deleteDataFirmRefused =>
      'আপনি একটি ফার্মের সদস্য, তাই আপনার ডায়েরি ফার্মের সঙ্গে যুক্ত। ডেটা মুছতে আগে ফার্মের মালিককে আপনাকে সরিয়ে দিতে বলুন।';

  @override
  String get settingsManageAccount_deleteDataFailed =>
      'আপনার ডেটা মোছা যায়নি। আবার চেষ্টা করুন।';

  @override
  String get settingsManageAccount_dangerZone => 'সতর্কতা';

  @override
  String get settingsManageAccount_deleted =>
      'আপনার অ্যাকাউন্ট মুছে ফেলা হয়েছে।';

  @override
  String get settingsManageAccount_deleteDialogTitle =>
      'অ্যাকাউন্ট মুছে ফেলবেন?';

  @override
  String get settingsManageAccount_deleteWarningFree =>
      'এতে আপনার অ্যাকাউন্ট এবং এই ডিভাইসে থাকা সব মামলা, নোট, কেস রেফারেন্স ও সেটিং স্থায়ীভাবে মুছে যাবে। এরপর কিছুই ফিরিয়ে আনা যাবে না।';

  @override
  String get settingsManageAccount_deleteWarningPremium =>
      'এতে আপনার অ্যাকাউন্ট এবং এই ডিভাইস ও ক্লাউডে থাকা সব মামলা, নোট, কেস রেফারেন্স ও সেটিং স্থায়ীভাবে মুছে যাবে। এরপর কিছুই ফিরিয়ে আনা যাবে না।';

  @override
  String get settingsManageAccount_deleteConfirmPhrase => 'delete my account';

  @override
  String settingsManageAccount_deleteConfirmBody(String phrase) {
    return 'নিশ্চিত করতে নিচে $phrase লিখুন।';
  }

  @override
  String get settingsManageAccount_deleteNeedsConnection =>
      'অ্যাকাউন্ট মুছতে ইন্টারনেটে সংযুক্ত হন। কিছুই মুছে ফেলা হয়নি।';

  @override
  String get settingsManageAccount_deleteFirmRefused =>
      'আপনি একটি ফার্মের সদস্য, তাই আপনার কিছু তথ্য ফার্মের সঙ্গে যুক্ত। অ্যাকাউন্ট মুছতে আগে ফার্মের মালিককে আপনাকে সরিয়ে দিতে বলুন।';

  @override
  String get settingsManageAccount_deleteAdminRefused =>
      'অ্যাডমিনিস্ট্রেটর অ্যাকাউন্ট অ্যাপ থেকে মোছা যায় না।';

  @override
  String get settingsManageAccount_deleteFailed =>
      'আপনার অ্যাকাউন্ট মোছা যায়নি। আবার চেষ্টা করুন।';

  @override
  String get settingsManageAccount_loggedOut => 'আপনি লগ আউট হয়েছেন।';

  @override
  String get settingsManageAccount_role => 'ভূমিকা';

  @override
  String get settingsManageAccount_roleIndividual => 'ব্যক্তিগত';

  @override
  String get settingsManageAccount_roleOwner => 'মালিক';

  @override
  String get settingsManageAccount_roleAssociate => 'সহযোগী';

  @override
  String get settingsManageAccount_roleViewer => 'পর্যবেক্ষক';

  @override
  String get settingsManageAccount_firm => 'ফার্ম';

  @override
  String get settingsManageAccount_subscription => 'সাবস্ক্রিপশন';

  @override
  String get settingsManageAccount_planFree => 'ফ্রি';

  @override
  String get settingsManageAccount_planPremium => 'প্রিমিয়াম';

  @override
  String settingsManageAccount_premiumUntil(String date) {
    return '$date পর্যন্ত প্রিমিয়াম';
  }

  @override
  String get settingsOnlineSync_title => 'অনলাইন সিঙ্ক';

  @override
  String get settingsOnlineSync_cases => 'মামলা';

  @override
  String get settingsOnlineSync_notes => 'নোট';

  @override
  String get settingsOnlineSync_references => 'রেফারেন্স';

  @override
  String get settingsOnlineSync_notSignedIn => 'সাইন ইন করা হয়নি';

  @override
  String get settingsOnlineSync_signInPrompt =>
      'সব ডিভাইসে ডেটা সিঙ্ক করতে সাইন ইন করুন';

  @override
  String get settingsOnlineSync_actionRequired => 'ব্যবস্থা প্রয়োজন';

  @override
  String get settingsOnlineSync_lastSyncNever => 'সর্বশেষ সিঙ্ক: কখনো নয়';

  @override
  String get settingsOnlineSync_dataStaysOnDevice =>
      'সাইন ইন না করা পর্যন্ত আপনার ডেটা এই ডিভাইসেই থাকবে।';

  @override
  String get settingsOnlineSync_syncNow => 'এখনই সিঙ্ক করুন';

  @override
  String get settingsOnlineSync_notSynced => 'সিঙ্ক হয়নি';

  @override
  String get settingsOnlineSync_synced => 'সিঙ্ক হয়েছে';

  @override
  String get settingsOnlineSync_notSyncedSignedOut => 'সিঙ্ক করতে সাইন ইন করুন';

  @override
  String get settingsOnlineSync_pendingSyncTitle => 'অপেক্ষমাণ সিঙ্ক';

  @override
  String get settingsOnlineSync_pendingSyncSubtitle =>
      'পাঠানোর অপেক্ষায় থাকা প্রতিটি পরিবর্তন';

  @override
  String get settingsOnlineSync_signedIn => 'সাইন ইন করা আছে';

  @override
  String settingsOnlineSync_signedInAs(String name) {
    return '$name হিসেবে সাইন ইন করা';
  }

  @override
  String get settingsOnlineSync_premiumActive =>
      'আপনার সব ডিভাইসে প্রিমিয়াম সিঙ্ক চালু আছে';

  @override
  String get settingsOnlineSync_freePlan =>
      'ফ্রি প্ল্যান — আপনার ডায়েরি এই ডিভাইসেই থাকবে';

  @override
  String get settingsOnlineSync_freePlanPill => 'ফ্রি প্ল্যান';

  @override
  String get settingsOnlineSync_freePlanHint =>
      'ডিভাইসের মধ্যে সিঙ্ক করতে সাবস্ক্রিপশন প্ল্যান প্রয়োজন।';

  @override
  String get settingsOnlineSync_freePlanHintLink => 'এখান থেকে';

  @override
  String get settingsOnlineSync_freePlanHintSuffix => ' প্ল্যান কিনুন।';

  @override
  String get settingsOnlineSync_upToDate => 'হালনাগাদ';

  @override
  String get settingsOnlineSync_syncing => 'সিঙ্ক হচ্ছে…';

  @override
  String get settingsOnlineSync_paused => 'সিঙ্ক বিরতি';

  @override
  String get settingsOnlineSync_offline => 'কোনো সংযোগ নেই';

  @override
  String get settingsOnlineSync_actionRequiredBody =>
      'কিছু পরিবর্তন পাঠানো যায়নি। দেখতে সিঙ্ক স্ট্যাটাস খুলুন।';

  @override
  String settingsOnlineSync_lastSyncAt(String when) {
    return 'সর্বশেষ সিঙ্ক: $when';
  }

  @override
  String settingsOnlineSync_pendingUploads(int count) {
    return '$count পাঠানোর অপেক্ষায়';
  }

  @override
  String get settingsOnlineSync_pendingNone =>
      'সবকিছু আপনার অ্যাকাউন্টে সংরক্ষিত আছে।';

  @override
  String settingsOnlineSync_pendingCount(int count) {
    return '$count অপেক্ষমাণ';
  }

  @override
  String get settingsOnlineSync_syncFailed =>
      'সিঙ্ক সম্পন্ন হয়নি। আপনার পরিবর্তন এই ডিভাইসেই নিরাপদে আছে।';

  @override
  String get settingsOnlineSync_syncFinished => 'সিঙ্ক সম্পন্ন হয়েছে।';

  @override
  String get settingsOnlineSync_needSignInToSync =>
      'ডিভাইসের মধ্যে সিঙ্ক করতে সাইন ইন করুন।';

  @override
  String get settingsOnlineSync_needConnectionToSync =>
      'কোনো সংযোগ নেই। আপনার পরিবর্তন এই ডিভাইসেই সংরক্ষিত আছে।';

  @override
  String get settingsOnlineSync_checkingPlan =>
      'আপনার সাবস্ক্রিপশন যাচাই করা হচ্ছে…';

  @override
  String get settingsOnlineSync_checkingPlanBody =>
      'কিছু পাঠানোর আগে আপনার প্ল্যান নিশ্চিত করা হচ্ছে।';

  @override
  String get settingsOnlineSync_checkingPlanMessage =>
      'আপনার প্ল্যান নিশ্চিত হলেই সিঙ্ক শুরু হবে।';

  @override
  String get settingsOnlineSync_itemsUnknown => '— আইটেম';

  @override
  String settingsOnlineSync_itemsCount(int count) {
    return '$count আইটেম';
  }

  @override
  String get settingsOnlineSync_syncOff => 'সিঙ্ক বন্ধ';

  @override
  String get settingsOnlineSync_syncOffBody =>
      'সিঙ্ক বন্ধ আছে। আপনার পরিবর্তন পাঠাতে ও গ্রহণ করতে এটি আবার চালু করুন।';

  @override
  String get settingsOnlineSync_syncOffMessage =>
      'সিঙ্ক বন্ধ আছে। সিঙ্ক করতে এটি আবার চালু করুন।';

  @override
  String get settingsOnlineSync_syncOnTitle => 'সিঙ্ক চালু আছে';

  @override
  String get settingsOnlineSync_syncOnBody =>
      'আপাতত আপনার পরিবর্তন এই ডিভাইসেই রাখতে সিঙ্ক বন্ধ করুন। যেকোনো সময় এখান থেকেই আবার চালু করতে পারবেন।';

  @override
  String get settingsOnlineSync_syncOffTitle => 'সিঙ্ক বন্ধ আছে';

  @override
  String get settingsOnlineSync_syncOffCardBody =>
      'সিঙ্ক বন্ধ থাকলে কিছু পাঠানো বা গ্রহণ করা হয় না। আপনার পরিবর্তন এই ডিভাইসেই থাকে, আর অ্যাপ আবার চালু করলে সিঙ্ক নিজে থেকেই চালু হয়ে যায়।';

  @override
  String get settingsOnlineSync_disableSync => 'সিঙ্ক বন্ধ করুন';

  @override
  String get settingsOnlineSync_enableSync => 'সিঙ্ক চালু করুন';

  @override
  String get settingsOnlineSync_syncOffToast =>
      'সিঙ্ক বন্ধ। আপনার পরিবর্তন এই ডিভাইসেই থাকছে।';

  @override
  String get settingsOnlineSync_syncOnToast => 'সিঙ্ক আবার চালু হয়েছে।';

  @override
  String get settingsBackupRestore_title => 'ব্যাকআপ ও পুনরুদ্ধার';

  @override
  String get settingsBackupRestore_chooseBackupTitle =>
      'পুনরুদ্ধারের জন্য ব্যাকআপ নির্বাচন করুন';

  @override
  String get backupScheduled_skipNoticeTitle =>
      'স্বয়ংক্রিয় ব্যাকআপ এড়িয়ে গেছে';

  @override
  String get backupScheduled_skipNoticeBody =>
      'ব্যাকআপ এমন একটি পাসফ্রেজ দিয়ে এনক্রিপ্ট করা থাকে যা কেবল আপনি জানেন, তাই স্বয়ংক্রিয় ব্যাকআপ চালানো যায় না। লিগ্যাল কেস ডায়েরি খুলে ম্যানুয়ালি ব্যাকআপ নিন।';

  @override
  String get backupScheduled_noticeChannelName => 'ব্যাকআপ রিমাইন্ডার';

  @override
  String get backupScheduled_noticeChannelDescription =>
      'আপনার স্বয়ংক্রিয় ব্যাকআপের রিমাইন্ডার।';

  @override
  String get settingsBackupRestore_sectionBackup => 'ব্যাকআপ ও পুনরুদ্ধার';

  @override
  String get settingsBackupRestore_sectionBackupSubtitle =>
      'আপনার ডায়েরি ব্যাকআপ করুন বা পুনরুদ্ধার করুন';

  @override
  String get settingsBackupRestore_sectionEncryption => 'ব্যাকআপে এনক্রিপশন';

  @override
  String get settingsBackupRestore_sectionEncryptionSubtitle =>
      'পাসফ্রেজ দিয়ে ব্যাকআপ সুরক্ষিত করুন';

  @override
  String get settingsBackupRestore_encryptionWhy =>
      'ব্যাকআপ এনক্রিপ্ট করলে ফাইলটি আপনার বেছে নেওয়া পাসফ্রেজ দিয়ে লক হয়ে যায়, তাই ফাইলটি যার হাতেই পড়ুক আপনার মামলার তথ্য পড়তে পারবে না।';

  @override
  String get settingsBackupRestore_encryptionCost =>
      'পাসফ্রেজ কোথাও সংরক্ষিত হয় না। এটি ভুলে গেলে ওই ব্যাকআপ আর কখনও পুনরুদ্ধার করা যাবে না, তাই এটি নিরাপদে রাখুন।';

  @override
  String get settingsBackupRestore_encryptionStateOn => 'এনক্রিপশন এখন চালু';

  @override
  String get settingsBackupRestore_encryptionStateOff => 'এনক্রিপশন এখন বন্ধ';

  @override
  String get settingsBackupRestore_encryptionEnable => 'চালু করুন';

  @override
  String get settingsBackupRestore_encryptionDisable => 'বন্ধ করুন';

  @override
  String get settingsBackupRestore_sectionAutomaticBackup =>
      'স্বয়ংক্রিয় ব্যাকআপ';

  @override
  String get settingsBackupRestore_sectionAutomaticBackupSubtitle =>
      'আপনার ডায়েরি কত ঘন ঘন ব্যাকআপ হবে তা বেছে নিন';

  @override
  String get settingsBackupRestore_sectionStatus => 'ব্যাকআপ অবস্থা';

  @override
  String get settingsBackupRestore_backupLocal => 'লোকাল স্টোরেজে ব্যাকআপ';

  @override
  String get settingsBackupRestore_backupDrive => 'গুগল ড্রাইভে ব্যাকআপ';

  @override
  String get settingsBackupRestore_restore => 'ব্যাকআপ থেকে পুনরুদ্ধার';

  @override
  String get settingsBackupRestore_encryptionNote =>
      'ব্যাকআপ আপনার লোকাল স্টোরেজ বা ক্লাউড প্রোভাইডারে সংরক্ষিত হয়। পাসফ্রেজ দিয়ে লক করতে ব্যাকআপে এনক্রিপশন চালু করুন। পুনরুদ্ধার বর্তমান ডেটা প্রতিস্থাপন করবে।';

  @override
  String get settingsBackupRestore_offlineNote =>
      'নোট: শুধুমাত্র অফলাইন অ্যাকাউন্টের জন্য পুনরুদ্ধার উপলব্ধ।';

  @override
  String get settingsBackupRestore_lastSuccessfulBackup =>
      'সর্বশেষ সফল ব্যাকআপ';

  @override
  String get settingsBackupRestore_lastBackupPlaceholder =>
      'এখনো কোনো ব্যাকআপ করা হয়নি।';

  @override
  String get backupNudge_message =>
      'এই মাসে কোনো ব্যাকআপ নেওয়া হয়নি। আপনার মামলাগুলো শুধু এই ফোনেই আছে — নিরাপদ রাখতে একটি ব্যাকআপ সংরক্ষণ করুন।';

  @override
  String get backupNudge_action => 'লোকাল স্টোরেজে ব্যাকআপ';

  @override
  String get backupNudge_dismiss => 'এই মাসের জন্য বন্ধ করুন';

  @override
  String get settingsBackupRestore_driveShareTitle => 'গুগল ড্রাইভে পাঠাবেন?';

  @override
  String get settingsBackupRestore_driveShareBody =>
      'আপনার ব্যাকআপ সংরক্ষিত হয়েছে। শেয়ার শিট থেকে এটি গুগল ড্রাইভে পাঠান।';

  @override
  String get settingsBackupRestore_driveShareSend => 'পাঠান';

  @override
  String get settingsBackupRestore_driveShareNotNow => 'এখন নয়';

  @override
  String get settingsBackupRestore_shareFailed => 'শেয়ার শিট খোলা যায়নি।';

  @override
  String get settingsBackupRestore_shareSubject =>
      'লিগ্যাল কেস ডায়েরি ব্যাকআপ';

  @override
  String get settingsBackupRestore_scheduleOff => 'বন্ধ';

  @override
  String get settingsBackupRestore_scheduleEveryday => 'প্রতিদিন';

  @override
  String get settingsBackupRestore_scheduleEvery3Days => 'প্রতি ৩ দিনে';

  @override
  String get settingsBackupRestore_scheduleEvery7Days => 'প্রতি ৭ দিনে';

  @override
  String get settingsBackupRestore_scheduleEveryMonth => 'প্রতি মাসে';

  @override
  String get settingsBackupRestore_passphraseTitle =>
      'এই ব্যাকআপ সুরক্ষিত করুন';

  @override
  String get settingsBackupRestore_passphraseBody =>
      'এই পাসফ্রেজ দিয়ে ব্যাকআপটি এনক্রিপ্ট করা হয়। এটি কোথাও সংরক্ষণ করা হয় না, তাই এটি ছাড়া ফাইলটি কখনো পুনরুদ্ধার করা যাবে না।';

  @override
  String get settingsBackupRestore_passphraseLabel => 'পাসফ্রেজ';

  @override
  String get settingsBackupRestore_passphraseConfirmLabel =>
      'পাসফ্রেজ নিশ্চিত করুন';

  @override
  String get settingsBackupRestore_passphraseRequired => 'একটি পাসফ্রেজ লিখুন।';

  @override
  String get settingsBackupRestore_passphraseMismatch =>
      'দুটি পাসফ্রেজ মিলছে না।';

  @override
  String get settingsBackupRestore_encryptAndSave => 'এনক্রিপ্ট ও সংরক্ষণ';

  @override
  String get settingsBackupRestore_recoveryPassphraseTitle =>
      'এই ব্যাকআপ খুলুন';

  @override
  String get settingsBackupRestore_recoveryPassphraseBody =>
      'যে পাসফ্রেজ দিয়ে ব্যাকআপটি তৈরি হয়েছিল, সেটি লিখুন।';

  @override
  String get settingsBackupRestore_recoveryPassphraseHint =>
      'এনক্রিপশন চালু হওয়ার আগে তৈরি পুরনো ব্যাকআপ পাসফ্রেজ ছাড়াই খোলে।';

  @override
  String get settingsBackupRestore_openBackup => 'ব্যাকআপ খুলুন';

  @override
  String get settingsBackupRestore_backupProgress =>
      'আপনার ব্যাকআপ তৈরি হচ্ছে…';

  @override
  String get settingsBackupRestore_restoreProgress =>
      'আপনার ডেটা পুনরুদ্ধার হচ্ছে…';

  @override
  String get settingsBackupRestore_restoreBlockedBody =>
      'ডেটা দূষণ ও সম্ভাব্য সমস্যা এড়াতে সাবস্ক্রিপশন ব্যবহারকারীদের অফলাইন ডেটা পুনরুদ্ধার করা সীমাবদ্ধ। লোকাল সেভ পুনরুদ্ধারের আগে বর্তমান লোকাল ও ক্লাউড ডেটা মুছে ফেলুন।';

  @override
  String settingsBackupRestore_backupSaved(String path) {
    return 'ব্যাকআপ সংরক্ষিত হয়েছে: $path';
  }

  @override
  String get settingsBackupRestore_backupFailed => 'ব্যাকআপ তৈরি করা যায়নি।';

  @override
  String get settingsBackupRestore_restoreDetailsTitle =>
      'বর্তমান সব ডেটা প্রতিস্থাপন করবেন?';

  @override
  String get settingsBackupRestore_restoreDetailsBackedUp => 'ব্যাকআপের সময়';

  @override
  String get settingsBackupRestore_restoreDetailsAppVersion => 'অ্যাপ সংস্করণ';

  @override
  String get settingsBackupRestore_restoreDetailsRecords => 'রেকর্ড';

  @override
  String get settingsBackupRestore_restoreDetailsWarning =>
      'এই ডিভাইসে থাকা সব ডেটা প্রতিস্থাপিত হবে। এটি ফিরিয়ে আনা যাবে না।';

  @override
  String get settingsBackupRestore_restoreReplace => 'প্রতিস্থাপন করুন';

  @override
  String get settingsBackupRestore_restoreCompleteTitle => 'পুনরুদ্ধার সম্পন্ন';

  @override
  String settingsBackupRestore_restoreCompleteBody(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString রেকর্ড পুনরুদ্ধার হয়েছে।';
  }

  @override
  String get settingsBackupRestore_restoreCompleteNote =>
      'অ্যাপটি এখন আপনার ডেটা আবার লোড করবে।';

  @override
  String get settingsBackupRestore_errorInvalidFile =>
      'ফাইলটি এই অ্যাপের তৈরি ব্যাকআপ নয়।';

  @override
  String get settingsBackupRestore_errorUnsupportedVersion =>
      'ব্যাকআপটি অ্যাপের নতুন কোনো সংস্করণে তৈরি করা হয়েছে।';

  @override
  String get settingsBackupRestore_errorWrongSecret =>
      'পাসফ্রেজ ভুল, অথবা ব্যাকআপ ফাইলটি পরিবর্তিত হয়েছে।';

  @override
  String get settingsBackupRestore_errorDamaged =>
      'ব্যাকআপ ফাইলটি ক্ষতিগ্রস্ত, পুনরুদ্ধার করা যাবে না।';

  @override
  String get settingsBackupRestore_errorConflict =>
      'পুনরুদ্ধারের সময় নতুন ডেটা এসেছে, তাই কিছুই বদলানো হয়নি।';

  @override
  String get settingsBackupRestore_errorImportFailed =>
      'পুনরুদ্ধার ব্যর্থ হয়েছে। আপনার আগের ডেটা অপরিবর্তিত রয়েছে।';

  @override
  String get settingsBackupRestore_errorAnotherAccount =>
      'এই ব্যাকআপটি অন্য একটি অ্যাকাউন্টের। এটি পুনরুদ্ধার করতে ওই অ্যাকাউন্টে সাইন ইন করুন।';

  @override
  String get settingsBackupRestore_errorOpenFile => 'ফাইলটি খোলা যায়নি।';

  @override
  String get settingsBackupRestore_backupExcel => 'এক্সেল ফাইল হিসেবে ব্যাকআপ';

  @override
  String get settingsBackupRestore_excelNote =>
      'এক্সেল ফাইলটি একটি স্প্রেডশিট এবং এনক্রিপ্ট করা নয়। যে কেউ এটি খুললে আপনার মামলার তথ্য পড়তে পারবে।';

  @override
  String get settingsBackupRestore_sectionExcelFormat =>
      'এক্সেল ব্যাকআপ ফরম্যাট';

  @override
  String get settingsBackupRestore_sectionExcelFormatSubtitle =>
      'ফরম্যাট দেখুন ও একটি নমুনা ডাউনলোড করুন';

  @override
  String get settingsBackupRestore_excelTemplateNote =>
      'নমুনা ওয়ার্কবুকে Courts, Case Types, Steps, On Behalfs ও Case Categories শিট এবং একটি Guide শিটও থাকে। এই বাড়তি শিটগুলো শুধু দেখানোর জন্য — পুনরুদ্ধারের সময় অ্যাপ এগুলো ছুঁয়ে দেখে না।';

  @override
  String get settingsBackupRestore_excelIntro =>
      'এক্সেল ফাইলে চারটি শিট থাকে — Cases, Case History, Notes ও Case References — এবং একটি Info শিট। শিটের নাম এবং প্রতিটি শিটের প্রথম সারি হুবহু অপরিবর্তিত রাখুন: পুনরুদ্ধারের সময় অ্যাপ এগুলো মিলিয়ে দেখে।';

  @override
  String get settingsBackupRestore_excelPartialNote =>
      'এটি সম্পূর্ণ ব্যাকআপ নয়। আদালত, ধাপ ও আপনার সেটিংস এতে নেই, তাই এমন ডায়েরিতে পুনরুদ্ধার করুন যেখানে এগুলো আগে থেকেই আছে।';

  @override
  String get settingsBackupRestore_excelIdNote =>
      'কোনো সারির id খালি রাখলে অ্যাপ নতুন একটি দেবে। বাকি প্রতিটি আবশ্যক ঘর অবশ্যই পূরণ করতে হবে।';

  @override
  String get settingsBackupRestore_excelTemplate =>
      'টেমপ্লেট ফাইল ডাউনলোড করুন';

  @override
  String get settingsBackupRestore_excelProgress =>
      'আপনার এক্সেল ফাইল তৈরি হচ্ছে…';

  @override
  String settingsBackupRestore_excelSaved(String path) {
    return 'এক্সেল ফাইল $path-এ সংরক্ষিত হয়েছে';
  }

  @override
  String settingsBackupRestore_excelTemplateSaved(String path) {
    return 'টেমপ্লেট $path-এ সংরক্ষিত হয়েছে';
  }

  @override
  String get settingsBackupRestore_excelNotSpreadsheet =>
      'ফাইলটি একটি স্প্রেডশিট নয়।';

  @override
  String get settingsBackupRestore_excelNotBackup =>
      'ওয়ার্কবুকটি Legal Case Diary-এর একটি এক্সেল ব্যাকআপ নয়।';

  @override
  String get settingsBackupRestore_excelNewerVersion =>
      'এই ওয়ার্কবুকটি অ্যাপের একটি নতুন সংস্করণে তৈরি হয়েছে।';

  @override
  String settingsBackupRestore_excelUnknownSheet(String sheet) {
    return 'ওয়ার্কবুকে এই ফরম্যাটে নেই এমন একটি শিট আছে: $sheet';
  }

  @override
  String settingsBackupRestore_excelMissingSheet(String sheet) {
    return 'ওয়ার্কবুকে $sheet শিট নেই।';
  }

  @override
  String settingsBackupRestore_excelUnknownColumn(String sheet, String column) {
    return '$sheet শিটে এই ফরম্যাটে নেই এমন একটি কলাম আছে: $column';
  }

  @override
  String settingsBackupRestore_excelMissingColumn(String sheet, String column) {
    return '$sheet শিটে $column কলামটি নেই।';
  }

  @override
  String settingsBackupRestore_excelEmptySheet(String sheet) {
    return '$sheet শিটে কোনো সারি নেই।';
  }

  @override
  String settingsBackupRestore_excelMissingValue(
    String sheet,
    int row,
    String column,
  ) {
    final intl.NumberFormat rowNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String rowString = rowNumberFormat.format(row);

    return '$sheet, সারি $rowString: $column অবশ্যই পূরণ করতে হবে।';
  }

  @override
  String get settingsBackupRestore_restoreDetailsSheets => 'শিট';

  @override
  String get settingsBackupRestore_restoreExcelTitle =>
      'এই শিটগুলোর ডেটা প্রতিস্থাপন করবেন?';

  @override
  String get settingsBackupRestore_restoreExcelWarning =>
      'এই ফাইলের শিটগুলো এই ডিভাইসের সেই রেকর্ডগুলো প্রতিস্থাপন করবে। বাকি সব অপরিবর্তিত থাকবে।';

  @override
  String get settingsEditCourtSteps_editItemTypes =>
      'মামলার ধরন, ধাপ ইত্যাদি সম্পাদনা';

  @override
  String get settingsEditCourtSteps_editItemTypesSubtitle =>
      'মামলার ধরন, কার্যপদ্ধতির ধাপ ও পক্ষের ভূমিকা পরিচালনা করুন';

  @override
  String get settingsEditCourtSteps_courtNamesCategories =>
      'আদালতের নাম ও ক্যাটেগরি সম্পাদনা';

  @override
  String get settingsEditCourtSteps_courtNamesCategoriesSubtitle =>
      'সুপ্রিম কোর্টের বিভাগ ও জেলার নিম্ন আদালত';

  @override
  String get settingsEditCourtSteps_lowerCourtCategories =>
      'নিম্ন আদালতের ক্যাটেগরি';

  @override
  String get settingsEditCourtSteps_lowerCourtCategoriesSubtitle =>
      'বিভাগ, জেলা ও তাদের আদালতের ক্যাটেগরি';

  @override
  String get settingsEditCourtNames_courtCategory => 'আদালতের নাম সম্পাদনা';

  @override
  String get settingsEditCourtNames_lowerCourts => 'নিম্ন আদালত';

  @override
  String get settingsEditCourtNames_lowerCourtsSubtitle =>
      'জেলা, দায়রা ও বিশেষায়িত আদালত';

  @override
  String get settingsEditCourtNames_quickTip => 'দ্রুত পরামর্শ';

  @override
  String get settingsEditCourtNames_quickTipBody =>
      'বিশেষায়িত ট্রাইব্যুনাল প্রয়োজন? সংশ্লিষ্ট বিভাগ ও জেলার অধীনে সেগুলো যোগ করুন, তারপর একটি আদালতের ক্যাটেগরি নির্ধারণ করুন।';

  @override
  String get settingsEditItems_caseTypes => 'মামলার ধরন';

  @override
  String get settingsEditItems_steps => 'ধাপ';

  @override
  String get settingsEditItems_onBehalf => 'পক্ষে';

  @override
  String get settingsCourtNamesSteps_title => 'আদালতের নাম, ধাপ ইত্যাদি';

  @override
  String get settingsCourtNamesSteps_catAppellateDivision => 'আপিল বিভাগ';

  @override
  String get settingsCourtNamesSteps_catHighCourtDivision => 'হাইকোর্ট বিভাগ';

  @override
  String get settingsCourtNamesSteps_catDistrictSessions =>
      'জেলা ও দায়রা (ফৌজদারি)';

  @override
  String get settingsCourtNamesSteps_catDistrictCivil =>
      'জেলা আদালত (দেওয়ানি)';

  @override
  String get settingsCourtNamesSteps_catCjm => 'চীফ জুডিসিয়াল ম্যাজিস্ট্রেট';

  @override
  String get settingsCourtNamesSteps_catCmm => 'চীফ মেট্রোপলিটন ম্যাজিস্ট্রেট';

  @override
  String get settingsCourtNamesSteps_catExecutive => 'নির্বাহী ম্যাজিস্ট্রেট';

  @override
  String get settingsCourtNamesSteps_catMetropolitanSessions =>
      'মেট্রোপলিটন সেশন (ফৌজদারি)';

  @override
  String get settingsItemList_addTitle => 'আইটেম যোগ করুন';

  @override
  String get settingsItemList_editTitle => 'আইটেম সম্পাদনা';

  @override
  String get settingsItemList_nameLabel => 'নাম';

  @override
  String get settingsItemList_empty =>
      'এখনো কোনো আইটেম যুক্ত করা হয়নি। নিচে একটি যোগ করুন।';

  @override
  String get settingsItemList_deleteTitle => 'আইটেম মুছুন';

  @override
  String get settingsItemList_deleteMessage =>
      'এই আইটেমটি মুছে ফেলবেন? এই কাজটি ফিরিয়ে আনা যাবে না।';

  @override
  String get settingsItemList_catAppellate => 'আপিল';

  @override
  String get settingsItemList_catHighCourt => 'হাইকোর্ট';

  @override
  String get settingsItemList_catSessions => 'দায়রা (ফৌজ.)';

  @override
  String get settingsItemList_catDistrictCivil => 'জেলা (দেওয়ানি)';

  @override
  String get settingsItemList_catMetropolitanSessions => 'মেট্রো দায়রা (ফৌজ.)';

  @override
  String get settingsItemList_catCjm => 'সিজেএম';

  @override
  String get settingsItemList_catCmm => 'সিএমএম';

  @override
  String get settingsItemList_catExecutive => 'নির্বাহী';

  @override
  String get settingsItemList_catTribunals => 'ট্রাইব্যুনাল';

  @override
  String get settingsCourtList_addTitle => 'আদালত যোগ করুন';

  @override
  String get settingsCourtList_editTitle => 'আদালত সম্পাদনা';

  @override
  String get settingsCourtList_nameLabel => 'আদালতের নাম';

  @override
  String get settingsCourtList_titleHigher => 'আদালতের নাম';

  @override
  String get settingsCourtList_empty =>
      'এখনো কোনো আদালত যুক্ত করা হয়নি। নিচে একটি যোগ করুন।';

  @override
  String get settingsCourtList_deleteTitle => 'আদালত মুছুন';

  @override
  String settingsCourtList_deleteMessage(String name) {
    return '\"$name\" মুছে ফেলবেন? এই কাজটি ফিরিয়ে আনা যাবে না।';
  }

  @override
  String settingsCourtList_titleLower(String district) {
    return '$district আদালতের নাম';
  }

  @override
  String get settingsCourtFlow_divisions => 'বিভাগ';

  @override
  String get settingsCourtFlow_districts => 'জেলা';

  @override
  String get settingsLowerCourtCategories_addTooltip =>
      'আদালতের ক্যাটেগরি যোগ করুন';

  @override
  String get settingsLowerCourtCategories_addTitle =>
      'আদালতের ক্যাটেগরি যোগ করুন';

  @override
  String get settingsLowerCourtCategories_editTitle =>
      'আদালতের ক্যাটেগরি সম্পাদনা';

  @override
  String get settingsLowerCourtCategories_nameLabel => 'ক্যাটেগরির নাম';

  @override
  String get settingsLowerCourtCategories_empty =>
      'এই জেলায় এখনো কোনো আদালতের ক্যাটেগরি যুক্ত করা হয়নি।';

  @override
  String settingsCourtFlow_divisionTitle(String division) {
    return '$division বিভাগ';
  }

  @override
  String settingsLowerCourtCategories_title(String district) {
    return '$district আদালতের ক্যাটেগরি';
  }

  @override
  String get settingsNotifications_title => 'নোটিফিকেশন';

  @override
  String get settingsNotifications_statusLabel => 'ডিফল্ট নোটিফিকেশন স্ট্যাটাস';

  @override
  String get settingsNotifications_on => 'চালু';

  @override
  String get settingsNotifications_off => 'বন্ধ';

  @override
  String get settingsNotifications_dayOffsetLabel =>
      'নোটিফিকেশনের দিনের ব্যবধান';

  @override
  String get settingsNotifications_selectDayOffsetTitle =>
      'দিনের ব্যবধান নির্বাচন করুন';

  @override
  String get settingsNotifications_keepOneOffset =>
      'অন্তত একটি দিনের ব্যবধান রাখুন।';

  @override
  String get settingsNotifications_offsetSameDay => 'একই দিনে';

  @override
  String get settingsNotifications_offsetDayBefore => 'একদিন আগে';

  @override
  String settingsNotifications_offsetBeforeDays(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String daysString = daysNumberFormat.format(days);

    return '$daysString দিন আগে';
  }

  @override
  String get settingsNotifications_timeLabel => 'নোটিফিকেশনের সময়';

  @override
  String get settingsNotifications_reminderBanner =>
      'আপনার ডিভাইসে নোটিফিকেশন যথাযথভাবে কাজ নাও করতে পারে। সেটআপ সম্পন্ন করতে ট্যাপ করুন।';

  @override
  String get settingsNotifications_setupGuide =>
      'ব্যাটারি ও অটো-স্টার্ট সেটআপ গাইড';

  @override
  String get settingsNotifications_setupGuideSubtitle =>
      'শাওমি, অপো, ভিভো ও রিয়েলমি ফোনে প্রয়োজন';

  @override
  String get settingsNotifications_sendTest => 'পরীক্ষামূলক নোটিফিকেশন পাঠান';

  @override
  String get settingsNotifications_sendTestSubtitle =>
      'এই ফোনে শুনানির অ্যালার্ট কেমন দেখায় তা দেখুন';

  @override
  String get settingsNotifications_testSent =>
      'পরীক্ষামূলক নোটিফিকেশন পাঠানো হয়েছে';

  @override
  String get settingsNotifications_testFailed =>
      'নোটিফিকেশন দেখানো যায়নি। অ্যাপের নোটিফিকেশন অনুমতি যাচাই করুন।';

  @override
  String get notificationJob_channelName => 'শুনানির অ্যালার্ট';

  @override
  String get notificationJob_channelDescription =>
      'আসন্ন শুনানির দৈনিক রিমাইন্ডার';

  @override
  String get notificationJob_titleSameDay => 'আজ শুনানি';

  @override
  String get notificationJob_titleDayBefore => 'আগামীকাল শুনানি';

  @override
  String notificationJob_titleBeforeDays(String days) {
    return '$days দিন পর শুনানি';
  }

  @override
  String notificationJob_parties(String petitioner, String respondent) {
    return '$petitioner বনাম $respondent';
  }

  @override
  String get notificationJob_testTitle => 'পরীক্ষামূলক নোটিফিকেশন';

  @override
  String get notificationJob_testBody =>
      'শুনানির অ্যালার্ট কাজ করছে। আসল রিমাইন্ডার এমনই দেখাবে।';

  @override
  String get settingsBatteryGuide_intro =>
      'শাওমি, অপো, ভিভো, রিয়েলমি ও অনুরূপ ফোন ব্যাটারি বাঁচাতে ব্যাকগ্রাউন্ড অ্যালার্ম বন্ধ করে দেয়, তাই শুনানির রিমাইন্ডার নীরবে ব্যর্থ হতে পারে। এই দুই-তিনটি ধাপ সেগুলো চালু রাখবে।';

  @override
  String get settingsBatteryGuide_autoStartTitle => 'অটো-স্টার্ট অনুমতি দিন';

  @override
  String get settingsBatteryGuide_autoStartBody =>
      'ফোনের সেটিংসে অটো-স্টার্ট (বা স্টার্টআপ ম্যানেজার) খুলে Legal Case Diary-কে নিজে চালু হতে অনুমতি দিন।';

  @override
  String get settingsBatteryGuide_batteryTitle =>
      'ব্যাটারি ব্যবহার সীমাহীন করুন';

  @override
  String get settingsBatteryGuide_batteryBody =>
      'ব্যাটারি, তারপর অ্যাপ ব্যাটারি ব্যবহার (বা ব্যাটারি অপটিমাইজেশন) খুলে Legal Case Diary বেছে নিন এবং সীমাহীন / কোনো সীমাবদ্ধতা নেই নির্বাচন করুন।';

  @override
  String get settingsBatteryGuide_exactTitle =>
      'নির্দিষ্ট অ্যালার্ম অনুমতি দিন';

  @override
  String get settingsBatteryGuide_exactBody =>
      'অ্যান্ড্রয়েড ১২ ও নতুন সংস্করণে Legal Case Diary-র জন্য অ্যালার্ম ও রিমাইন্ডার অনুমতি দিন; নাহলে দৈনিক রিমাইন্ডার দেরিতে আসতে পারে।';

  @override
  String get settingsBatteryGuide_takeMeThere => 'সেখানে নিয়ে যান';

  @override
  String get settingsBatteryGuide_exactAllowed =>
      'নির্দিষ্ট অ্যালার্ম ইতিমধ্যেই অনুমোদিত';

  @override
  String get settingsBatteryGuide_batteryAllowed =>
      'ব্যাটারি ব্যবহার ইতিমধ্যেই সীমাহীন';

  @override
  String get settingsBatteryGuide_autoStartDone =>
      'আপনি অটো-স্টার্ট সম্পন্ন হিসেবে চিহ্নিত করেছেন';

  @override
  String get settingsBatteryGuide_markDone => 'সম্পন্ন হিসেবে চিহ্নিত করুন';

  @override
  String get settingsBatteryGuide_markNotDone =>
      'সম্পন্ন নয় হিসেবে চিহ্নিত করুন';

  @override
  String get settingsBatteryGuide_openFailed =>
      'সেটিংস পেজটি খোলা যায়নি। অনুগ্রহ করে নিজে সেট করুন।';

  @override
  String get settingsBatteryGuide_done => 'সম্পন্ন, আমি ধাপগুলো করেছি';

  @override
  String get settingsBatteryGuide_skip => 'এখনই নয়';

  @override
  String get settingsBatteryGuide_skipNote =>
      'পরে Settings → Notifications থেকে সম্পূর্ণ করতে পারবেন।';

  @override
  String get settingsViewSettings_title => 'ভিউ সেটিংস';

  @override
  String get settingsViewSettings_sectionDisplay => 'প্রদর্শন';

  @override
  String get settingsViewSettings_sectionFontSize => 'ফন্ট সাইজ';

  @override
  String get settingsViewSettings_sectionNavigation => 'নেভিগেশন';

  @override
  String get settingsViewSettings_upcomingPeriod => 'আসন্ন মামলার সময়সীমা';

  @override
  String settingsViewSettings_days(int days) {
    return '$days দিন';
  }

  @override
  String get settingsViewSettings_caseListMode => 'মামলার তালিকার ধরন';

  @override
  String get settingsViewSettings_caseListCompact => 'সংক্ষিপ্ত';

  @override
  String get settingsViewSettings_caseListExpanded => 'বিস্তারিত';

  @override
  String get settingsViewSettings_fontSizeDefault => 'ডিফল্ট';

  @override
  String settingsViewSettings_fontSizeMore(String step) {
    return '+$step';
  }

  @override
  String settingsViewSettings_fontSizeLess(String step) {
    return '-$step';
  }

  @override
  String get settingsViewSettings_fontSizeIncrease => 'ফন্ট সাইজ বাড়ান';

  @override
  String get settingsViewSettings_fontSizeDecrease => 'ফন্ট সাইজ কমান';

  @override
  String get settingsViewSettings_fontSizeReset => 'ডিফল্টে ফিরিয়ে দিন';

  @override
  String get settingsViewSettings_bottomTabs => 'নিচের নেভিগেশন';

  @override
  String settingsViewSettings_bottomTabsCount(int count) {
    return '$countটি স্ক্রিন নির্বাচিত';
  }

  @override
  String get settingsViewSettings_keepOneTab =>
      'নিচের বারে অন্তত একটি স্ক্রিন রাখুন।';

  @override
  String get settingsViewSettings_sideNav => 'সাইড নেভিগেশন অপশন';

  @override
  String settingsViewSettings_sideNavCount(int shown, int total) {
    return '$totalটির মধ্যে $shownটি সেকশন দেখানো হচ্ছে';
  }

  @override
  String get settingsViewSettings_landingPage => 'ডিফল্ট শুরুর পেজ';

  @override
  String get settingsGuidelines_title => 'নির্দেশনা ও প্রশ্নোত্তর';

  @override
  String get settingsGuidelines_intro =>
      'অ্যাপটি কীভাবে কাজ করে, এবং সবচেয়ে বেশি জিজ্ঞাসিত প্রশ্নের উত্তর। বিস্তারিত দেখতে যেকোনো কার্ডে ট্যাপ করুন।';

  @override
  String get settingsGuidelines_sectionGuidelines => 'নির্দেশনা';

  @override
  String get settingsGuidelines_accountTitle => 'আপনার অ্যাকাউন্ট';

  @override
  String get settingsGuidelines_accountBody1 =>
      'অ্যাপটি প্রথমবার খোলার সময়ই আপনি আপনার অ্যাকাউন্ট তৈরি করে নেবেন — এতে এক মুহূর্ত লাগে এবং ফ্রি প্ল্যানসহ সবার জন্যই এটি বাধ্যতামূলক। এরপর আপনি যা কিছু লিখবেন, সবই ওই অ্যাকাউন্টেরই থাকবে।';

  @override
  String get settingsGuidelines_accountBody2 =>
      'প্রতিটি অ্যাকাউন্ট এই ডিভাইসে সীমাবদ্ধ ফ্রি প্ল্যান দিয়েই শুরু হয় এবং আপনি আপগ্রেড না করা পর্যন্ত সেখানেই থাকে। প্রথম মামলা থেকেই ডায়েরিটি আপনার অ্যাকাউন্টের সঙ্গে যুক্ত থাকায় আপগ্রেড করতে কোনো তথ্য নতুন করে লিখতে বা স্থানান্তর করতে হয় না — ক্লাউড ব্যাকআপ কেবল চালু হয়ে যায়।';

  @override
  String get settingsGuidelines_dailyCauseListTitle => 'দৈনিক কজ লিস্ট';

  @override
  String get settingsGuidelines_dailyCauseListBody1 =>
      'দৈনিক কজ লিস্ট আপনার রেকর্ড করা একদিনের শুনানিগুলো আপনার আদালত-ক্রম অনুযায়ী আদালতভিত্তিক গ্রুপে এবং দিনের মোট সংখ্যাসহ দেখায়। ক্যালেন্ডার থেকে অন্য তারিখ বাছাই করুন; ডিফল্টভাবে আজকের তারিখ নির্বাচিত থাকে।';

  @override
  String get settingsGuidelines_dailyCauseListBody2 =>
      'তালিকাটি আপনার নিজের মামলার তথ্য থেকে তৈরি, তাই তথ্য যত নির্ভুল তালিকাও তত নির্ভুল। প্রতিটি মামলার পরবর্তী তারিখ ও সর্বশেষ ধাপ হালনাগাদ রাখুন এবং আদালত থেকে ফেরার সঙ্গে সঙ্গে তালিকা থেকেই শুনানির ফলাফল লিখুন। হালনাগাদ ছাড়া শুনানির তারিখ পেরিয়ে গেলে ফলাফল লেখা পর্যন্ত মামলাটি \'মেয়াদোত্তীর্ণ তারিখ\' অংশে থাকবে।';

  @override
  String get settingsGuidelines_allCasesTitle => 'সব মামলা';

  @override
  String get settingsGuidelines_allCasesBody1 =>
      'আপনার সব মামলা এক তালিকায়, উপরে সক্রিয় ও নিষ্পত্তিকৃত মামলার সংখ্যাসহ — সংখ্যায় ট্যাপ করলে সেই তালিকা খোলে। পক্ষ, কৌঁসুলি, মামলা নম্বর বা ফোন দিয়ে খুঁজুন, \'আদালত অনুযায়ী ফিল্টার\' ও \'নতুন প্রথমে/পুরাতন প্রথমে\' দিয়ে তালিকা ছোট করুন, আর কার্ড ও টেবিল ভিউয়ের মধ্যে বদল করুন।';

  @override
  String get settingsGuidelines_activeCasesTitle => 'সক্রিয় মামলা';

  @override
  String get settingsGuidelines_activeCasesBody1 =>
      'কেবল চলমান মামলাগুলো; নিষ্পত্তিকৃত কোনো মামলা এখানে থাকে না। এখান থেকে মামলা খুলে হালনাগাদ করুন বা শুনানির ফলাফল লিখুন।';

  @override
  String get settingsGuidelines_overdueDatesTitle => 'মেয়াদোত্তীর্ণ তারিখ';

  @override
  String get settingsGuidelines_overdueDatesBody1 =>
      'যেসব মামলার শুনানির তারিখ পেরিয়ে গেছে কিন্তু ফলাফল লেখা হয়নি, সেগুলো আদালত অনুযায়ী সাজানো থাকে এবং কোনটি কবে সর্বশেষ হালনাগাদ হয়েছে তা দেখা যায়। নতুন ধাপ বা ফলাফল লিখলে মামলাটি এই তালিকা থেকে সরে যায়।';

  @override
  String get settingsGuidelines_upcomingCasesTitle => 'আসন্ন মামলা';

  @override
  String get settingsGuidelines_upcomingCasesBody1 =>
      'আগামীকাল থেকে শুরু করে সেটিংস > ভিউ সেটিংস > আসন্ন মামলার সময়কাল-এ নির্ধারিত সময়ের শেষ দিন পর্যন্ত শুনানিগুলো তারিখ অনুযায়ী সাজানো থাকে — ডিফল্টভাবে ৭ দিন। আদালতে বেরোনোর আগে এই তালিকাটি দেখে নিন।';

  @override
  String get settingsGuidelines_disposedCasesTitle => 'নিষ্পত্তিকৃত মামলা';

  @override
  String get settingsGuidelines_disposedCasesBody1 =>
      'আপনার নিষ্পত্তি করা মামলাগুলো — প্রতিটিতে নিষ্পত্তির তারিখ, পক্ষ, সর্বশেষ নোট ও সাম্প্রতিক ইতিহাস দেখা যায়। এখানে \'মামলা যোগ\' বোতাম নেই; মামলা কীভাবে নিষ্পত্তি হিসেবে চিহ্নিত হয় তা \'সহায়তা\' বোতামে লেখা আছে।';

  @override
  String get settingsGuidelines_referencesTitle => 'মামলার রেফারেন্স ও নোট';

  @override
  String get settingsGuidelines_referencesBody1 =>
      'মামলার রেফারেন্স হলো আপনার নিজস্ব নজির-সংগ্রহ, যা কোনো নির্দিষ্ট মামলার সঙ্গে যুক্ত নয়। প্রতিটি এন্ট্রিতে রেফারেন্স (যেমন, ২৫ ডিএলআর (এডি) ১৪২), আইন ও ধারা, শিরোনাম ও বিবরণ এবং ব্যক্তিগত মন্তব্য লিখতে পারেন। বেশি ব্যবহৃত এন্ট্রি পিন করে তালিকার উপরে রাখুন।';

  @override
  String get settingsGuidelines_referencesBody2 =>
      'সাধারণ নোটের জন্য রয়েছে \'নোট\' অংশ, যা স্বতন্ত্রভাবে ব্যবহৃত হয়। দুটোতেই মুছে ফেলার পরপরই \'পূর্বাবস্থায় ফেরান\' সুবিধা পাওয়া যায়।';

  @override
  String get settingsGuidelines_backupTitle => 'অফলাইন ব্যাকআপ ও পুনরুদ্ধার';

  @override
  String get settingsGuidelines_backupBody1 =>
      'আপনার ডায়েরি এই ডিভাইসেই থাকে। সেটিংস > ব্যাকআপ ও পুনরুদ্ধার-এ গিয়ে \'লোকাল স্টোরেজে ব্যাকআপ\' বেছে নিলে আপনার পছন্দের স্থানে এনক্রিপ্ট করা একটি কপি সংরক্ষিত হয় — মেমোরি কার্ড, ফোনের কোনো ফোল্ডার বা সিস্টেমের ফাইল পিকার যেখানে পৌঁছায়। ফাইলটির জন্য আপনি একটি পাসফ্রেজ দেন, যা অ্যাপ কোথাও সংরক্ষণ বা পাঠায় না।';

  @override
  String get settingsGuidelines_backupBody2 =>
      '\'ব্যাকআপ থেকে পুনরুদ্ধার\' ব্যাকআপ ফাইল পড়ে অ্যাপের বর্তমান তথ্য সেই ফাইলের বিষয়বস্তু দিয়ে প্রতিস্থাপন করে। এটি ফেরানো যায় না, তাই পুনরুদ্ধারের আগে নতুন ব্যাকআপ নিন। চলতি মাসে কোনো ব্যাকআপ না থাকলে অ্যাপ একটি মনে করিয়ে দেওয়ার বার্তা দেখায়, যা আপনি বন্ধ করতে পারেন।';

  @override
  String get settingsGuidelines_securityTitle => 'নিরাপত্তা ও এনক্রিপশন';

  @override
  String get settingsGuidelines_securityBody1 =>
      'আপনার মামলার ডায়েরি এই ডিভাইসে এনক্রিপ্ট করা অবস্থায় সংরক্ষিত থাকে। ব্যাকআপ ফাইল AES-256-GCM দিয়ে এনক্রিপ্ট করা হয়, যার চাবি আপনার পাসফ্রেজ থেকে ডিভাইসেই PBKDF2-HMAC-SHA256 দিয়ে তৈরি হয়। পাসফ্রেজ বা চাবি কোথাও সংরক্ষণ বা প্রেরণ করা হয় না।';

  @override
  String get settingsGuidelines_securityBody2 =>
      'অফলাইন সংস্করণে আপনার সাইন-আপের অ্যাকাউন্টের তথ্য ছাড়া আর কিছুই আপনার ফোন থেকে বাইরে যায় না — মামলার কোনো তথ্য নয়। পাসফ্রেজ নিরাপদে রেখে দিন — ব্যাকআপ থাকলেও পাসফ্রেজ হারালে সেটি আমরা বা অন্য কেউ খুলতে পারবে না।';

  @override
  String get settingsGuidelines_sectionFaqs => 'সাধারণ জিজ্ঞাসা';

  @override
  String get settingsGuidelines_faqCatGettingStarted => 'শুরু করা';

  @override
  String get settingsGuidelines_faqCatGettingStartedQ1 =>
      'অ্যাপটি কি ইন্টারনেট সংযোগ ছাড়া চলে?';

  @override
  String get settingsGuidelines_faqCatGettingStartedA1 =>
      'হ্যাঁ — আপনার অ্যাকাউন্ট থাকলে। অ্যাপটি সম্পূর্ণ অফলাইনে কাজ করার জন্য তৈরি: মামলা যোগ ও সম্পাদনা, দৈনিক কজ লিস্ট, প্রিন্ট এবং ব্যাকআপ সবই সংযোগ ছাড়া চলে। অ্যাকাউন্ট কেবল অ্যাপটি প্রথমবার খোলার সময় একবার তৈরি করতে হয়; ডায়েরি ব্যবহারের জন্য আবার সাইন-ইন করতে হয় না। অফলাইন সংস্করণে অনলাইন সিঙ্ক নেই।';

  @override
  String get settingsGuidelines_faqCatGettingStartedQ2 =>
      'কীভাবে নতুন মামলা যোগ করব?';

  @override
  String get settingsGuidelines_faqCatGettingStartedA2 =>
      'যেকোনো মামলার পাতায় + বোতামে ট্যাপ করুন। আপনি যে তথ্য দেবেন, তার ভিত্তিতে মামলাটি সংশ্লিষ্ট পাতাগুলোতে স্বয়ংক্রিয়ভাবে যুক্ত হবে।';

  @override
  String get settingsGuidelines_faqCatGettingStartedQ3 =>
      'মামলা যোগ করার পর কোথায় দেখা যাবে?';

  @override
  String get settingsGuidelines_faqCatGettingStartedA3 =>
      'একটি মামলা একাধিক পাতায় দেখা যায়, প্রতিটি ভিন্ন প্রশ্নের উত্তর দেয়: \'সক্রিয় মামলা\' চলমান সব মামলা দেখায়; \'আসন্ন মামলা\' আপনার নির্বাচিত সময়ের শুনানি দেখায়; \'দৈনিক কজ লিস্ট\' একদিনের শুনানি দেখায়; \'সব মামলা\' সাজানো ও আদালতভিত্তিক ফিল্টারসহ পূর্ণ তালিকা; \'মেয়াদোত্তীর্ণ তারিখ\' হালনাগাদ ছাড়া শুনানির তারিখ পেরিয়ে যাওয়া মামলা দেখায়; আর \'নিষ্পত্তিকৃত মামলা\' আপনি নিষ্পত্তি হিসেবে চিহ্নিত মামলাগুলো ধরে রাখে।';

  @override
  String get settingsGuidelines_faqCatGettingStartedQ4 =>
      'মামলা \'আপডেট\' ও \'সম্পাদনা\' করার মধ্যে পার্থক্য কী?';

  @override
  String get settingsGuidelines_faqCatGettingStartedA4 =>
      '\'আপডেট\' নতুন ধাপ বা ফলাফল লিখে মামলার ইতিহাসে যোগ করে — প্রতিটি শুনানির পর এটি ব্যবহার করুন। \'মামলা সম্পাদনা\' মামলার নিজস্ব তথ্য, যেমন পক্ষ, আদালত বা মামলা নম্বর পরিবর্তন করে — ভুল তথ্য সংশোধনে এটি ব্যবহার করুন।';

  @override
  String get settingsGuidelines_faqCatGettingStartedQ5 =>
      'কীভাবে মামলা নিষ্পত্তি হিসেবে চিহ্নিত করব?';

  @override
  String get settingsGuidelines_faqCatGettingStartedA5 =>
      '\'আপডেট\' স্ক্রিনে বা \'মামলা সম্পাদনা\' ফর্মে মামলাটি খুলে নিষ্পত্তি (Disposed) নির্বাচন করুন। আপিল বিভাগ ও হাইকোর্ট বিভাগের মামলার ক্ষেত্রে \'Disposed\' বা \'নিষ্পত্তি\' টাইপও করতে পারেন। এরপর মামলাটি \'সক্রিয় মামলা\' থেকে \'নিষ্পত্তিকৃত মামলা\'-য় চলে যাবে।';

  @override
  String get settingsGuidelines_faqCatGettingStartedQ6 =>
      'নিষ্পত্তিকৃত মামলা আবার সক্রিয় মামলায় কীভাবে ফিরিয়ে আনব?';

  @override
  String get settingsGuidelines_faqCatGettingStartedA6 =>
      'মামলাটি খুলে নিষ্পত্তি (Disposed) ছাড়া অন্য যেকোনো ধাপ বা ফলাফল বেছে নিন। মামলাটি আবার \'সক্রিয় মামলা\'-য় ফিরে আসবে।';

  @override
  String get settingsGuidelines_faqCatGettingStartedQ7 =>
      'মামলা মুছে ফেললে কী হয়?';

  @override
  String get settingsGuidelines_faqCatGettingStartedA7 =>
      'মামলাটি আপনার ডায়েরি থেকে সরে যায় এবং ফ্রি প্ল্যানে একটি স্লট খালি হয়। মুছে ফেলা ফেরানো যায় না, তাই যার রেকর্ড আর দরকার নেই কেবল সেটিই মুছুন। তবে নোট ও মামলার রেফারেন্স মুছে ফেলার পরপরই ফিরিয়ে আনা যায়।';

  @override
  String get settingsGuidelines_faqCatGettingStartedQ8 =>
      '\'মেয়াদোত্তীর্ণ তারিখ\' পাতাটি কী?';

  @override
  String get settingsGuidelines_faqCatGettingStartedA8 =>
      'যেসব মামলার শুনানির তারিখ পেরিয়ে গেছে কিন্তু ফলাফল লেখা হয়নি, সেগুলো সর্বশেষ হালনাগাদের তারিখসহ এখানে দেখা যায়। এখনো যেসব মামলায় হাত দেওয়া হয়নি তা খুঁজে বের করার সবচেয়ে সহজ উপায় এটি। নতুন ধাপ বা ফলাফল লিখলে মামলাটি তালিকা থেকে সরে যায়।';

  @override
  String get settingsGuidelines_faqCatGettingStartedQ9 =>
      'আমার কি অ্যাকাউন্ট দরকার?';

  @override
  String get settingsGuidelines_faqCatGettingStartedA9 =>
      'হ্যাঁ। ফ্রি প্ল্যানসহ সবার জন্যই অ্যাকাউন্ট বাধ্যতামূলক, এবং অ্যাপটি প্রথমবার খোলার সময়ই সেটি তৈরি করতে হয়। আপনার ডায়েরি ওই অ্যাকাউন্টেরই থাকে, তাই প্রিমিয়ামে উন্নীত হলে আপনার আগের মামলাগুলো আগেই আপনার — নতুন করে কিছু লিখতে, রপ্তানি করতে বা স্থানান্তর করতে হয় না; ক্লাউড ব্যাকআপ কেবল চালু হয়ে যায়।';

  @override
  String get settingsGuidelines_faqCatFindingCases => 'মামলা খোঁজা ও দেখা';

  @override
  String get settingsGuidelines_faqCatFindingCasesQ1 =>
      'মামলা যোগ করেছি কিন্তু সার্চে পাচ্ছি না।';

  @override
  String get settingsGuidelines_faqCatFindingCasesA1 =>
      'সার্চ আপনার লেখা লিপির সঙ্গে মিলিয়ে খোঁজে। ইংরেজিতে লেখা মামলা ইংরেজি অনুসন্ধানে এবং বাংলায় লেখা মামলা বাংলা অনুসন্ধানে পাওয়া যাবে। বাংলায় লেখা মামলা নম্বর ইংরেজি অনুসন্ধানে মিলবে না, এবং উল্টোটাও নয়।';

  @override
  String get settingsGuidelines_faqCatFindingCasesQ2 =>
      '\'আসন্ন মামলা\' তালিকায় কত দিন আগ পর্যন্ত শুনানি দেখা যায়?';

  @override
  String get settingsGuidelines_faqCatFindingCasesA2 =>
      'ডিফল্টভাবে পরবর্তী ৭ দিন। এটি বদলাতে সেটিংস > ভিউ সেটিংস > আসন্ন মামলার সময়কাল-এ যান।';

  @override
  String get settingsGuidelines_faqCatFindingCasesQ3 =>
      'মামলা কীভাবে দেখানো হয় তা বদলাতে পারি?';

  @override
  String get settingsGuidelines_faqCatFindingCasesA3 =>
      'ডিফল্ট \'সংক্ষিপ্ত ভিউ\' কার্ড ব্যবহার করে যতটুকু জায়গায় সম্ভব ততটুকু তথ্য দেখায়। মামলার স্ক্রিনে সার্চ ফিল্ডের পাশের টগল অথবা সেটিংস > ভিউ সেটিংস > মামলার তালিকা ভিউ থেকে \'বিস্তৃত ভিউ\'-তে যেতে পারেন।';

  @override
  String get settingsGuidelines_faqCatFindingCasesQ4 =>
      '\'দৈনিক কজ লিস্ট\' কী দেখায়?';

  @override
  String get settingsGuidelines_faqCatFindingCasesA4 =>
      'আপনার ডায়েরিতে রেকর্ড করা একদিনের শুনানিগুলো আপনার আদালত-ক্রম অনুযায়ী আদালতভিত্তিক গ্রুপে এবং দিনের মোট সংখ্যাসহ দেখায়। ক্যালেন্ডার থেকে তারিখ বাছাই করুন; ডিফল্টভাবে আজকের তারিখ থাকে।';

  @override
  String get settingsGuidelines_faqCatNotesAndPrinting =>
      'নোট, রেফারেন্স ও প্রিন্ট';

  @override
  String get settingsGuidelines_faqCatNotesAndPrintingQ1 =>
      '\'নোট\' ও \'মামলার রেফারেন্স\'-এর পার্থক্য কী?';

  @override
  String get settingsGuidelines_faqCatNotesAndPrintingA1 =>
      '\'নোট\' শিরোনাম ও বিবরণসহ সাধারণ নোট রাখে। \'মামলার রেফারেন্স\' কাঠামোবদ্ধ নজির-সংগ্রহ — রেফারেন্স, আইন, ধারা, বিবরণ ও ব্যক্তিগত মন্তব্য — যা পিন করা যায়। দুটোই মামলা থেকে আলাদা এবং কোনোটি স্বয়ংক্রিয়ভাবে মামলার সঙ্গে যুক্ত হয় না।';

  @override
  String get settingsGuidelines_faqCatNotesAndPrintingQ2 =>
      'কী কী প্রিন্ট করা যায়?';

  @override
  String get settingsGuidelines_faqCatNotesAndPrintingA2 =>
      'মামলার বিবরণ এবং মামলার তালিকা। প্রিন্ট একটি সাজানো পিডিএফ তৈরি করে এবং ডিভাইসের প্রিন্ট সুবিধা ব্যবহার করে। \'নোট\' ও \'মামলার রেফারেন্স\' স্ক্রিনে প্রিন্ট পাওয়া যায় না।';

  @override
  String get settingsGuidelines_faqCatNotesAndPrintingQ3 =>
      'মামলা সম্পর্কে ক্লায়েন্টকে কীভাবে জানাব?';

  @override
  String get settingsGuidelines_faqCatNotesAndPrintingA3 =>
      'ক্লায়েন্টের ফোন নম্বর থাকা মামলায় \'কল\', \'মেসেজ\' ও \'হোয়াটসঅ্যাপ\' সুবিধা আছে, সঙ্গে ক্লায়েন্টের নাম, মামলা নম্বর, পরবর্তী শুনানির তারিখ ও আদালতসহ প্রস্তুত বার্তা। পাঠানোর আগে বার্তাটি দেখে নিন — নম্বর বা তারিখ হালনাগাদ আছে কিনা অ্যাপ যাচাই করতে পারে না।';

  @override
  String get settingsGuidelines_faqCatBackupAndRestore =>
      'ব্যাকআপ ও পুনরুদ্ধার';

  @override
  String get settingsGuidelines_faqCatBackupAndRestoreQ1 =>
      'কীভাবে ডায়েরির ব্যাকআপ নেব?';

  @override
  String get settingsGuidelines_faqCatBackupAndRestoreA1 =>
      'সেটিংস > ব্যাকআপ ও পুনরুদ্ধার-এ গিয়ে \'লোকাল স্টোরেজে ব্যাকআপ\'-এ ট্যাপ করুন। ফাইলটি কোথায় সংরক্ষিত হবে তা আপনি বেছে নেন এবং একটি পাসফ্রেজ দেন যা ফাইলটি এনক্রিপ্ট করে। আপনার অ্যাকাউন্ট আগেই তৈরি করা থাকে, তাই ইন্টারনেট সংযোগের দরকার নেই।';

  @override
  String get settingsGuidelines_faqCatBackupAndRestoreQ2 =>
      'অ্যাপ কি নিজে থেকেই ব্যাকআপ নেয়?';

  @override
  String get settingsGuidelines_faqCatBackupAndRestoreA2 =>
      'অফলাইন সংস্করণে না — প্রতিটি ব্যাকআপ আপনি নিজে শুরু করেন। চলতি মাসে কোনো ব্যাকআপ না থাকলে অ্যাপ একটি মনে করিয়ে দেওয়ার বার্তা দেখায়, যা আপনি বন্ধ করতে পারেন।';

  @override
  String get settingsGuidelines_faqCatBackupAndRestoreQ3 =>
      'পাসফ্রেজ ভুলে গেছি। আপনি কি তা উদ্ধার করতে পারবেন?';

  @override
  String get settingsGuidelines_faqCatBackupAndRestoreA3 =>
      'না। পাসফ্রেজ আপনার ডিভাইসে বা অন্য কোথাও সংরক্ষণ করা হয় না, তাই তা ছাড়া ব্যাকআপ খোলা যায় না। হারিয়ে গেলে আপনার মনে রাখা যায় এমন একটি পাসফ্রেজ দিয়ে নতুন ব্যাকআপ নিন।';

  @override
  String get settingsGuidelines_faqCatBackupAndRestoreQ4 =>
      'ব্যাকআপ পুনরুদ্ধার করলে আমার বর্তমান তথ্যের কী হবে?';

  @override
  String get settingsGuidelines_faqCatBackupAndRestoreA4 =>
      'পুনরুদ্ধার অ্যাপের বর্তমান সব তথ্য ব্যাকআপ ফাইলের বিষয়বস্তু দিয়ে প্রতিস্থাপন করে। এটি একসঙ্গে মেলায় না এবং ফেরানোও যায় না। বর্তমান ডায়েরিতে দরকারি কিছু থাকলে আগে তার ব্যাকআপ নিন। অ্যাপে আগে থেকেই তথ্য থাকলে প্রতিস্থাপনের আগে অ্যাপ আপনার সম্মতি চায়।';

  @override
  String get settingsGuidelines_faqCatBackupAndRestoreQ5 =>
      'নতুন ফোনে ডায়েরি কীভাবে নেব?';

  @override
  String get settingsGuidelines_faqCatBackupAndRestoreA5 =>
      'বর্তমান ফোনে একটি ব্যাকআপ নিয়ে ফাইলটি নতুন ফোন থেকে পাওয়া যায় এমন জায়গায় রাখুন — মেমোরি কার্ড, গুগল ড্রাইভ বা নিজেকে পাঠানো ইমেইল। নতুন ফোনে অ্যাপ ইনস্টল করে সেটিংস > ব্যাকআপ ও পুনরুদ্ধার থেকে একই পাসফ্রেজ দিয়ে \'ব্যাকআপ থেকে পুনরুদ্ধার\' করুন।';

  @override
  String get settingsGuidelines_faqCatBackupAndRestoreQ6 =>
      'অ্যাপের ভিন্ন সংস্করণে নেওয়া ব্যাকআপ ব্যবহার করা যাবে?';

  @override
  String get settingsGuidelines_faqCatBackupAndRestoreA6 =>
      'পুরোনো সংস্করণের ব্যাকআপ পুনরুদ্ধারের সময় স্বয়ংক্রিয়ভাবে হালনাগাদ হয়। আপনার চলমান সংস্করণের চেয়ে নতুন সংস্করণে নেওয়া ব্যাকআপ গ্রহণ করা হয় না, তাই আগে অ্যাপ হালনাগাদ করে তারপর পুনরুদ্ধার করুন।';

  @override
  String get settingsGuidelines_faqCatBackupAndRestoreQ7 =>
      'অ্যাপ মুছে ফেললে বা ফোন হারালে আমার তথ্যের কী হবে?';

  @override
  String get settingsGuidelines_faqCatBackupAndRestoreA7 =>
      'অফলাইন সংস্করণে আপনার ডায়েরি কেবল ডিভাইসেই থাকে, তাই ব্যাকআপ ফাইল না থাকলে অ্যাপ আনইনস্টল করলে বা ফোন হারালে তথ্যও হারিয়ে যায়। সাম্প্রতিক ব্যাকআপ রাখুন এবং একটি কপি ফোনের বাইরে সংরক্ষণ করুন।';

  @override
  String get settingsGuidelines_faqCatNotifications => 'নোটিফিকেশন';

  @override
  String get settingsGuidelines_faqCatNotificationsQ1 =>
      'শুনানির নোটিফিকেশন এলো না কেন?';

  @override
  String get settingsGuidelines_faqCatNotificationsA1 =>
      'বেশিরভাগ অ্যান্ড্রয়েড ফোন ব্যাটারি বাঁচাতে ব্যাকগ্রাউন্ড অ্যাপ বন্ধ করে দেয়, ফলে শুনানির সতর্কতা আসে না। সেটিংস > নোটিফিকেশন-এ গিয়ে \'ব্যাটারি ও অটো-স্টার্ট সেটআপ গাইড\'-এ ট্যাপ করে আপনার ফোনের ধাপগুলো অনুসরণ করুন, তারপর \'পরীক্ষামূলক নোটিফিকেশন পাঠান\' দিয়ে নিশ্চিত হোন।';

  @override
  String get settingsGuidelines_faqCatNotificationsQ2 =>
      'শুনানির নোটিফিকেশন কখন পাঠানো হবে তা বদলাতে পারি?';

  @override
  String get settingsGuidelines_faqCatNotificationsA2 =>
      'হ্যাঁ। সেটিংস > নোটিফিকেশন-এ দিনের ব্যবধান — একই দিন, আগের দিন বা শুনানির কয়েক দিন আগে — এবং সময় বেছে নিতে পারেন। একই স্ক্রিন থেকে নোটিফিকেশন সম্পূর্ণ বন্ধও করা যায়।';

  @override
  String get settingsGuidelines_faqCatLanguageAndDisplay => 'ভাষা ও প্রদর্শন';

  @override
  String get settingsGuidelines_faqCatLanguageAndDisplayQ1 =>
      'অ্যাপের ভাষা কীভাবে বদলাব?';

  @override
  String get settingsGuidelines_faqCatLanguageAndDisplayA1 =>
      'সেটিংস > ভাষা-য় গিয়ে ইংরেজি বা বাংলা বেছে নিন। পরিবর্তন পুরো অ্যাপে প্রযোজ্য হবে এবং সংখ্যাগুলো নির্বাচিত ভাষার অঙ্কে দেখানো হবে। অ্যাপের ভাষা আপনার মামলার তথ্য যে ভাষায় লেখা হয়েছে তা বদলায় না, আর সার্চ সেই তথ্যের সঙ্গেই মেলে।';

  @override
  String get settingsGuidelines_faqCatFreePlanAndPremium =>
      'ফ্রি প্ল্যান ও প্রিমিয়াম';

  @override
  String get settingsGuidelines_faqCatFreePlanAndPremiumQ1 =>
      'অ্যাপটি কি ফ্রি?';

  @override
  String get settingsGuidelines_faqCatFreePlanAndPremiumA1 =>
      'হ্যাঁ। প্রতিটি অ্যাকাউন্ট ফ্রি প্ল্যান দিয়েই শুরু হয় — এতে কোনো খরচ নেই, ৫০টি পর্যন্ত মামলা রাখা যায় এবং সব মামলা এই ডিভাইসেই থাকে। প্রিমিয়াম এই সীমা বাড়াবে এবং চালু হলে ক্লাউড ব্যাকআপ ও সিঙ্ক যোগ করবে।';

  @override
  String get settingsGuidelines_faqCatFreePlanAndPremiumQ2 =>
      'মামলা যোগ করতে পারছি না কেন?';

  @override
  String get settingsGuidelines_faqCatFreePlanAndPremiumA2 =>
      'ফ্রি প্ল্যানে ৫০টি পর্যন্ত মামলা রাখা যায়। সীমায় পৌঁছালে \'মামলা যোগ\' ফর্মের বদলে প্রিমিয়াম স্ক্রিন খোলে। কিছুই লুকানো বা মুছে ফেলা হয় না — আপনার সব মামলা দেখা, সম্পাদনা, প্রিন্ট ও মুছে ফেলার সুবিধা আগের মতোই থাকে এবং মামলা মুছলে একটি স্লট খালি হয়।';

  @override
  String get settingsGuidelines_faqCatFreePlanAndPremiumQ3 =>
      'কী কী ফ্রি থাকে?';

  @override
  String get settingsGuidelines_faqCatFreePlanAndPremiumA3 =>
      'সীমার বাইরে নতুন মামলা যোগ করা ছাড়া বাকি সব: মামলা দেখা, সম্পাদনা, আপডেট, মুছে ফেলা ও প্রিন্ট, দৈনিক কজ লিস্ট, ক্লায়েন্টের তথ্য ও যোগাযোগের সুবিধা, নোট, মামলার রেফারেন্স এবং ব্যাকআপ ও পুনরুদ্ধার।';

  @override
  String get settingsGuidelines_faqCatFreePlanAndPremiumQ4 =>
      'ক্লাউড ব্যাকআপ ফ্রি দেওয়া হয় না কেন?';

  @override
  String get settingsGuidelines_faqCatFreePlanAndPremiumA4 =>
      'ক্লাউড ব্যাকআপ ও অনলাইন মোড একটি ব্যাকএন্ড সেবার উপর নির্ভর করে, যার খরচ আমরা বহন করি। আপনার সাবস্ক্রিপশন আপনার তথ্য নিরাপদে অনলাইনে রাখার এই খরচটিই বহন করবে, তাই সেবাটি বিনামূল্যে দেওয়া সম্ভব নয়।';

  @override
  String get settingsGuidelines_faqCatFreePlanAndPremiumQ5 =>
      'এখনই সাবস্ক্রাইব করা যাবে?';

  @override
  String get settingsGuidelines_faqCatFreePlanAndPremiumA5 =>
      'এখনো নয়। প্রিমিয়াম স্ক্রিনে পরিকল্পনাগুলো দেখা যায়, তবে কেনাকাটা অনলাইন সংস্করণের সঙ্গে চালু হবে। ততদিন অফলাইন অ্যাপটি সম্পূর্ণ ব্যবহারযোগ্য এবং আপনার তথ্য আপনার ডিভাইসেই থাকে।';

  @override
  String get settingsGuidelines_faqCatCourtsAndCustomisation =>
      'আদালত ও কাস্টমাইজেশন';

  @override
  String get settingsGuidelines_faqCatCourtsAndCustomisationQ1 =>
      'কিছু জেলার আদালতের নাম প্রত্যাশার সঙ্গে মিলছে না কেন?';

  @override
  String get settingsGuidelines_faqCatCourtsAndCustomisationA1 =>
      '৬৪টি জেলার আদালতের নাম আমরা সরকারের কজ লিস্ট ওয়েবসাইট (causelist.judiciary.gov.bd) থেকে সংগ্রহ করে কোনো পরিবর্তন ছাড়াই ব্যবহার করেছি। সেটিংস > আদালত/ধাপ সম্পাদনা থেকে যেকোনো আদালতের নাম আপনার পছন্দমতো বদলাতে পারেন।';

  @override
  String get settingsGuidelines_faqCatCourtsAndCustomisationQ2 =>
      'নিজের আদালত, মামলার ধরন, ধাপ বা পক্ষ যোগ করতে পারি?';

  @override
  String get settingsGuidelines_faqCatCourtsAndCustomisationA2 =>
      'হ্যাঁ। সেটিংস > আদালত/ধাপ সম্পাদনা থেকে \'মামলা যোগ\' ও \'মামলা সম্পাদনা\' ফর্মে ব্যবহৃত আদালত, মামলার ধরন, ধাপ ও পক্ষের এন্ট্রি যোগ, নাম পরিবর্তন ও মুছে ফেলা যায়। কোনো এন্ট্রি মুছে ফেলা আর ফেরানো যায় না।';

  @override
  String get settingsGuidelines_faqCatCourtsAndCustomisationQ3 =>
      'ট্রাইব্যুনাল ও বিশেষ ট্রাইব্যুনাল কোথায় আছে?';

  @override
  String get settingsGuidelines_faqCatCourtsAndCustomisationA3 =>
      'ট্রাইব্যুনালের জন্য সঠিক মামলার ধরন, ধাপ ও পক্ষের অপশন দেখাতে আমরা সেগুলো বিষয় অনুযায়ী সাজিয়েছি:\n\nদেওয়ানি ট্রাইব্যুনাল → জেলা জজ আদালত (দেওয়ানি)\nফৌজদারি ট্রাইব্যুনাল → দায়রা জজ আদালত (ফৌজদারি)\nমহানগর এলাকার ফৌজদারি ট্রাইব্যুনাল → মহানগর দায়রা জজ আদালত (ফৌজদারি)';

  @override
  String get settingsGuidelines_faqCatCourtsAndCustomisationQ4 =>
      'আমার খোঁজা আদালতটি পাচ্ছি না।';

  @override
  String get settingsGuidelines_faqCatCourtsAndCustomisationA4 =>
      'আদালতগুলো অ্যাপে নিচের শ্রেণিভুক্ত:\n\nজেলা জজ আদালত (দেওয়ানি)\n১. জেলা ও অতিরিক্ত জেলা জজ আদালত\n২. যুগ্ম জেলা জজ আদালত\n৩. দেওয়ানি ও সিনিয়র দেওয়ানি জজ আদালত\n৪. পারিবারিক আদালত ও পারিবারিক আপিল আদালত\n৫. ভূমি জরিপ ট্রাইব্যুনাল ও ভূমি জরিপ আপিল ট্রাইব্যুনাল\n৬. বাণিজ্যিক আদালত\n৭. শ্রম আদালত\n\nদায়রা জজ আদালত (ফৌজদারি) ও মহানগর দায়রা জজ আদালত (ফৌজদারি)\n১. দায়রা ও অতিরিক্ত দায়রা জজ আদালত\n২. যুগ্ম দায়রা জজ আদালত\n৩. নারী ও শিশু নির্যাতন দমন ট্রাইব্যুনাল\n৪. শিশু নির্যাতন প্রতিরোধ ট্রাইব্যুনাল\n৫. বিশেষ ট্রাইব্যুনাল\n\nচীফ জুডিসিয়াল ম্যাজিস্ট্রেট আদালত ও চীফ মেট্রোপলিটন ম্যাজিস্ট্রেট আদালত\n১. চীফ ও অতিরিক্ত চীফ জুডিসিয়াল ম্যাজিস্ট্রেট\n২. বিশেষ ম্যাজিস্ট্রেট আদালত\n৩. দ্রুত বিচার আদালত\n৪. পরিবেশ আদালত\n৫. বন আদালত\n৬. সিনিয়র জুডিসিয়াল ম্যাজিস্ট্রেট আদালত\n৭. জুডিসিয়াল ম্যাজিস্ট্রেট আদালত\n৮. আমলযোগ্য অপরাধ আদালত';

  @override
  String get settingsGuidelines_faqCatDataAndSupport =>
      'তথ্য, গোপনীয়তা ও সহায়তা';

  @override
  String get settingsGuidelines_faqCatDataAndSupportQ1 =>
      'আমার তথ্য কোথায় থাকে এবং কে দেখতে পারে?';

  @override
  String get settingsGuidelines_faqCatDataAndSupportA1 =>
      'অফলাইন সংস্করণে আপনার লেখা সব তথ্য ডিভাইসেই এনক্রিপ্ট করা অবস্থায় থাকে। আমাদের বা অন্য কারো কাছে কিছু পাঠানো হয় না। প্রথম মামলা থেকেই ডায়েরিটি আপনার অ্যাকাউন্টের সঙ্গে যুক্ত থাকে — ফ্রি প্ল্যানে এটি কোনো মামলার তথ্য কোথাও পাঠায় না। ব্যাকআপ ফাইল এনক্রিপ্ট করা এবং কেবল আপনার দেওয়া পাসফ্রেজ দিয়েই খোলা যায়। অনলাইন সংস্করণ চালু হলে কী তথ্য কোথায় রাখা হবে তা ব্যবহারের আগে আলাদা নির্দেশনায় জানানো হবে।';

  @override
  String get settingsGuidelines_faqCatDataAndSupportQ2 =>
      'অ্যাপটি কি আদালতের রেকর্ডের বিকল্প?';

  @override
  String get settingsGuidelines_faqCatDataAndSupportA2 =>
      'না। অ্যাপটি আপনার নিজের কাজের জন্য একটি ব্যক্তিগত রেকর্ড রাখার মাধ্যম। এর তথ্য আপনি নিজে লেখেন এবং অফিসিয়াল কজ লিস্ট ও আদালতের রেকর্ডই চূড়ান্ত। শুনানির তারিখের উপর নির্ভর করার আগে সর্বদা আদালত থেকে যাচাই করুন।';

  @override
  String get settingsGuidelines_faqCatDataAndSupportQ3 =>
      'এখানে উত্তর নেই, কীভাবে যোগাযোগ করব?';

  @override
  String get settingsGuidelines_faqCatDataAndSupportA3 =>
      'সেটিংস > সম্পর্কিত > সহায়তা থেকে আমাদের লিখুন — বার্তাটি আপনার অ্যাপ সংস্করণ ও ফোনের মডেল লেখা অবস্থায় খুলবে। সমস্যার সময় আপনি কী করছিলেন তা লিখুন। চাইলে adv.asadusjaman@gmail.com ঠিকানায়ও লিখতে পারেন।';

  @override
  String get settingsAbout_title => 'সম্পর্কিত';

  @override
  String settingsAbout_version(String version) {
    return 'সংস্করণ $version';
  }

  @override
  String get settingsAbout_designedBy => 'ডিজাইন ও ডেভেলপমেন্ট';

  @override
  String get settingsAbout_role => 'অ্যাডভোকেট';

  @override
  String get settingsAbout_moreAboutApp => 'অ্যাপ সম্পর্কে আরও';

  @override
  String get settingsAbout_privacyPolicy => 'গোপনীয়তা নীতি';

  @override
  String get settingsAbout_termsOfService => 'সেবার শর্তাবলী';

  @override
  String get settingsAbout_support => 'সহায়তা';

  @override
  String get settingsAbout_dataSafetyTitle => 'ডেটা নিরাপত্তা';

  @override
  String get settingsAbout_dataSafetyBody =>
      'আপনার ডায়েরি ও ব্যাকআপ ফাইল আপনার ডিভাইসে এনক্রিপ্ট করা অবস্থায় সংরক্ষিত থাকে। আপনি নিজে না পাঠালে কোনো কিছু আপলোড হয় না।';

  @override
  String get settingsAbout_actionPending => 'পরবর্তী কোনো টাস্কে আসবে';

  @override
  String get settingsUpdate_entry => 'আপডেট';

  @override
  String get settingsUpdate_appUpdate => 'অ্যাপ আপডেট';

  @override
  String get settingsUpdate_appUpdateSubtitle =>
      'আপডেট আছে কি না দেখুন এবং অ্যাপ আপডেট করুন';

  @override
  String get settingsUpdate_autoUpdate => 'স্বয়ংক্রিয়ভাবে আপডেট দেখা';

  @override
  String get settingsUpdate_autoUpdateSubtitle =>
      'কত ঘন ঘন আপডেট দেখতে হবে তা বেছে নিন';

  @override
  String get settingsUpdate_networkTitle => 'কোন নেটওয়ার্কে আপডেট';

  @override
  String get settingsUpdate_networkSubtitle =>
      'কোন নেটওয়ার্কে আপডেট ডাউনলোড হবে তা বেছে নিন';

  @override
  String get settingsUpdate_networkWifi => 'শুধু ওয়াই-ফাই';

  @override
  String get settingsUpdate_networkMobileData => 'ওয়াই-ফাই ও মোবাইল ডেটা';

  @override
  String get settingsUpdate_currentVersion => 'বর্তমান ভার্সন:';

  @override
  String get settingsUpdate_checkForUpdate => 'আপডেট দেখুন';

  @override
  String get settingsUpdate_checking => 'আপডেট দেখা হচ্ছে';

  @override
  String get settingsUpdate_updateNow => 'এখনই আপডেট করুন';

  @override
  String get settingsUpdate_later => 'পরে';

  @override
  String get settingsUpdate_skipVersion => 'এই ভার্সন এড়িয়ে যান';

  @override
  String settingsUpdate_newerVersion(String version) {
    return 'নতুন ভার্সন পাওয়া যাচ্ছে ($version)।';
  }

  @override
  String get settingsUpdate_latest => 'আপনি সর্বশেষ ভার্সনে আছেন।';

  @override
  String get settingsUpdate_mobileDataTitle => 'মোবাইল ডেটায় ডাউনলোড করবেন?';

  @override
  String get settingsUpdate_mobileDataBody =>
      'আপনি মোবাইল ডেটায় আছেন এবং আপডেটটি বড় ডাউনলোড। চালিয়ে যান, অথবা ওয়াই-ফাইতে গিয়ে ডাউনলোড করুন।';

  @override
  String get settingsUpdate_mobileDataContinue => 'চালিয়ে যান';

  @override
  String get settingsUpdate_checkFailed =>
      'এই মুহূর্তে আপডেট দেখা যায়নি। পরে আবার চেষ্টা করুন।';

  @override
  String get settingsUpdate_downloadFailed =>
      'আপডেটটি ডাউনলোড করা যায়নি। পরে আবার চেষ্টা করুন।';

  @override
  String get settingsUpdate_installUnavailable =>
      'এই ডিভাইসে আপডেট ইনস্টল করা যায় না।';

  @override
  String get settingsUpdate_offlineToast =>
      'ইন্টারনেটে যুক্ত হয়ে আপডেট দেখুন।';

  @override
  String get settingsUpdate_frequencyOff => 'বন্ধ';

  @override
  String get settingsUpdate_frequencyEveryday => 'প্রতিদিন';

  @override
  String get settingsUpdate_frequencyEvery3Days => 'প্রতি ৩ দিনে';

  @override
  String get settingsUpdate_frequencyEvery7Days => 'প্রতি ৭ দিনে';

  @override
  String get settingsUpdate_frequencyEveryMonth => 'প্রতি মাসে';

  @override
  String get settingsLegal_loadFailed =>
      'এই নথিটি খোলা যায়নি। আবার চেষ্টা করুন।';

  @override
  String get settingsSupport_title => 'সহায়তা';

  @override
  String get settingsSupport_scopeTitle => 'আমাদের লেখার আগে';

  @override
  String get settingsSupport_scope =>
      'আমরা অ্যাপটি নিয়েই সহায়তা করতে পারি: কোনো সুবিধা কীভাবে কাজ করে, কিছু ঠিকভাবে কাজ করছে না, বা কোনো ব্যাকআপ পুনরুদ্ধার হচ্ছে না। আপনার ডায়েরি আমরা দেখতে পাই না — তা আপনার ফোনেই থাকে — এবং আপনার হয়ে কোনো শুনানির তারিখ যাচাই, নিশ্চিত বা খুঁজে দিতে পারি না।';

  @override
  String get settingsSupport_faqLead =>
      'অধিকাংশ প্রশ্নের উত্তর এখানেই দেওয়া আছে।';

  @override
  String get settingsSupport_faqLink => 'নির্দেশনা ও প্রশ্নোত্তর খুলুন';

  @override
  String get settingsSupport_channelsLabel => 'আমাদের লিখুন';

  @override
  String get settingsSupport_channelWhatsApp => 'হোয়াটসঅ্যাপ';

  @override
  String get settingsSupport_channelEmail => 'ইমেইল';

  @override
  String get settingsSupport_messageSubject => 'লিগ্যাল কেস ডায়েরি — সহায়তা';

  @override
  String get settingsSupport_messageIntro =>
      'আসসালামু আলাইকুম, লিগ্যাল কেস ডায়েরি নিয়ে আমার সহায়তা দরকার।';

  @override
  String get settingsSupport_messageVersion => 'অ্যাপ সংস্করণ';

  @override
  String get settingsSupport_messagePhone => 'ফোন';

  @override
  String get settingsSupport_messageLanguage => 'অ্যাপের ভাষা';

  @override
  String get settingsSupport_messagePrompt =>
      'কী হয়েছে, এবং তার ঠিক আগে আমি কী করছিলাম:';

  @override
  String get settingsSupport_warningTitle => 'এগুলো কখনো পাঠাবেন না';

  @override
  String get settingsSupport_warningBody =>
      'আপনার পাসফ্রেজ, ডায়েরির ডেটাবেস ফাইল বা ব্যাকআপ ফাইল। আমরা কখনো এগুলো চাইব না, আর যে বার্তায় এগুলো চাওয়া হয় তা আমাদের কাছ থেকে আসেনি।';

  @override
  String get settingsSupport_replyTitle => 'কখন উত্তর পাবেন';

  @override
  String get settingsSupport_replyBody =>
      'সহায়তা অ্যাপের ডেভেলপার নিজেই দেখেন, আদালতের কাজের পাশাপাশি; তাই উত্তর পেতে সাধারণত এক থেকে দুই কর্মদিবস (রবিবার থেকে বৃহস্পতিবার) লাগে। কোনো ফোন লাইন বা লাইভ চ্যাট নেই — আপনি যে হোয়াটসঅ্যাপ বা ইমেইল থেকে লিখবেন, সেখানেই উত্তর পাবেন।';

  @override
  String get settingsSupport_unableToOpenWhatsApp =>
      'হোয়াটসঅ্যাপ খোলা যায়নি।';

  @override
  String get settingsSupport_unableToOpenEmail =>
      'কোনো ইমেইল অ্যাপ খোলা যায়নি।';

  @override
  String get settingsMoreAbout_title => 'অ্যাপ সম্পর্কে আরও';

  @override
  String get settingsMoreAbout_description =>
      'লিগ্যাল কেস ডায়েরি বাংলাদেশের আইনজীবীদের জন্য তৈরি একটি সম্পূর্ণ অফলাইন মামলার ডায়েরি। এটি আপনার মামলা ও শুনানিগুলো দৈনিক কজ লিস্টে সাজায়, আসন্ন ও মেয়াদোত্তীর্ণ তারিখের হিসাব রাখে যাতে কোনোটি বাদ না পড়ে, এবং সঙ্গে আপনার নোট ও মামলার রেফারেন্স সংরক্ষণ করে। সব তথ্য আপনি নিজে লিখেন এবং তা আপনার ডিভাইসে এনক্রিপ্ট করা অবস্থায় থাকে — কোনো অ্যাকাউন্ট লাগে না, আর আপনি নিজে না পাঠালে কোনো তথ্য ফোন থেকে বাইরে যায় না।';

  @override
  String get settingsMoreAbout_keyFeatures => 'প্রধান বৈশিষ্ট্য';

  @override
  String get settingsMoreAbout_featureDailyCauseList => 'দৈনিক কজ লিস্ট';

  @override
  String get settingsMoreAbout_featureOfflineBackup => 'অফলাইন ব্যাকআপ';

  @override
  String get settingsMoreAbout_featureCaseReferences => 'মামলার রেফারেন্স';

  @override
  String get settingsMoreAbout_featureHearingNotifications =>
      'শুনানির নোটিফিকেশন';

  @override
  String get settingsMoreAbout_rateApp => 'অ্যাপ রেট করুন';

  @override
  String get settingsMoreAbout_shareApp => 'অ্যাপ শেয়ার করুন';

  @override
  String get settingsMoreAbout_footer => 'ডিজাইন ও ডেভেলপমেন্ট';

  @override
  String get print_notAvailable => 'এই স্ক্রিনে প্রিন্ট করা যায় না।';

  @override
  String appShare_invite(String link) {
    return 'লিগ্যাল কেস ডায়েরি - বাংলাদেশি আইনজীবীদের জন্য পূর্ণাঙ্গ অফলাইন কেস ডায়েরি।\nএখান থেকে নিন: $link';
  }

  @override
  String get appShare_subject => 'লিগ্যাল কেস ডায়েরি';

  @override
  String get appShare_copied =>
      'শেয়ার করার অ্যাপ পাওয়া যায়নি, তাই আমন্ত্রণটি ক্লিপবোর্ডে কপি হয়েছে।';

  @override
  String get appShare_failed => 'অ্যাপ শেয়ার করা যায়নি';

  @override
  String get print_preparing => 'প্রিন্ট তৈরি হচ্ছে';

  @override
  String get print_serialShort => 'ক্রম';

  @override
  String get print_dateLabel => 'তারিখ';

  @override
  String get print_dayLabel => 'বার';

  @override
  String get print_monthLabel => 'মাস';

  @override
  String get print_yearLabel => 'সাল';

  @override
  String print_dateLine(
    String dateLabel,
    String date,
    String dayLabel,
    String day,
    String monthLabel,
    String month,
    String yearLabel,
    String year,
  ) {
    return '$dateLabel: $date       $dayLabel: $day       $monthLabel: $month       $yearLabel: $year';
  }

  @override
  String get print_failed => 'প্রিন্ট করা যায়নি';

  @override
  String get print_nothingToPrint => 'প্রিন্ট করার কিছু নেই';

  @override
  String print_printedOn(String date) {
    return 'প্রিন্টের তারিখ $date';
  }

  @override
  String print_pageOf(int page, int total) {
    final intl.NumberFormat pageNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String pageString = pageNumberFormat.format(page);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'পৃষ্ঠা $pageString / $totalString';
  }

  @override
  String get localeScratch_title => 'স্থানীয়করণ স্ক্র্যাচ';

  @override
  String get localeScratch_greeting => 'হ্যালো';

  @override
  String get localeScratch_englishSample => 'This text is in English.';

  @override
  String get localeScratch_bengaliSample => 'এই টেক্সটি বাংলায়।';

  @override
  String localeScratch_currentLanguage(String language) {
    return 'বর্তমান ভাষা: $language';
  }

  @override
  String get auth_loginSubtitle => 'অ্যাপে লগ ইন করুন';

  @override
  String get auth_emailLabel => 'ইমেইল';

  @override
  String get auth_emailHint => 'example@gmail.com';

  @override
  String get auth_passwordLabel => 'পাসওয়ার্ড';

  @override
  String get auth_passwordHint => '••••••••';

  @override
  String get auth_forgotPassword => 'পাসওয়ার্ড ভুলে গেছেন?';

  @override
  String get auth_loginButton => 'লগইন';

  @override
  String get auth_orContinueWith => 'অথবা চালিয়ে যান';

  @override
  String get auth_googleLogin => 'গুগল দিয়ে লগইন';

  @override
  String get auth_googleSignup => 'গুগল দিয়ে সাইন আপ';

  @override
  String get auth_noAccount => 'অ্যাকাউন্ট নেই?';

  @override
  String get auth_signUpLink => 'সাইন আপ';

  @override
  String get auth_haveAccount => 'আগে থেকেই অ্যাকাউন্ট আছে?';

  @override
  String get auth_loginLink => 'লগইন';

  @override
  String get auth_signupTitle => 'অ্যাকাউন্ট তৈরি করুন';

  @override
  String get auth_signupSubtitle =>
      'ঝামেলামুক্ত কেস ম্যানেজমেন্টের যাত্রা শুরু করুন।';

  @override
  String get auth_fullNameLabel => 'পূর্ণ নাম';

  @override
  String get auth_fullNameHint => 'আপনার নাম লিখুন।';

  @override
  String get auth_barAssociationLabel => 'বার অ্যাসোসিয়েশন';

  @override
  String get auth_barAssociationHint => 'আপনার জেলা বার অ্যাসোসিয়েশনের নাম।';

  @override
  String get auth_emailAddressLabel => 'ইমেইল ঠিকানা';

  @override
  String get auth_emailAddressHint => 'example@gmail.com';

  @override
  String get auth_passwordHelper => 'কমপক্ষে ৮ অক্ষরের হতে হবে।';

  @override
  String get auth_confirmPasswordLabel => 'পাসওয়ার্ড নিশ্চিত করুন';

  @override
  String get auth_accountTypeLabel => 'অ্যাকাউন্টের ধরন';

  @override
  String get auth_accountTypeIndividual => 'ব্যক্তিগত';

  @override
  String get auth_accountTypeJoinFirm => 'বিদ্যমান ফার্মে যোগ দিন';

  @override
  String get auth_inviteCodeLabel => 'ইনভাইট কোড';

  @override
  String get auth_inviteCodeHint => 'ABCDE12345';

  @override
  String get auth_inviteCodeHelper =>
      'আপনার ফার্ম মালিকের কাছ থেকে একবার ব্যবহারযোগ্য কোড নিন।';

  @override
  String get auth_termsAgreePrefix => 'আমি সম্মত আছি';

  @override
  String get auth_termsOfService => 'সেবার শর্তাবলি';

  @override
  String get auth_termsAgreeJoin => 'এবং';

  @override
  String get auth_privacyPolicy => 'গোপনীয়তা নীতি';

  @override
  String get auth_signUpButton => 'সাইন আপ';

  @override
  String get auth_showPassword => 'পাসওয়ার্ড দেখান';

  @override
  String get auth_hidePassword => 'পাসওয়ার্ড লুকান';

  @override
  String get auth_continueWithoutAccount => 'অ্যাকাউন্ট ছাড়া চালিয়ে যান';

  @override
  String get auth_continueWithoutAccountNote =>
      'আপনার মামলাগুলো এই ডিভাইসেই থাকবে।';

  @override
  String get auth_checkEmailTitle => 'আপনার ইমেইল দেখুন';

  @override
  String auth_checkEmailMessage(String email) {
    return '$email ঠিকানায় একটি নিশ্চিতকরণ লিংক পাঠানো হয়েছে। লিংকটি খুলে তারপর লগইন করুন।';
  }

  @override
  String get auth_backToLogin => 'লগইনে ফিরে যান';

  @override
  String get auth_useTheApp => 'অ্যাপটি ব্যবহার করুন';

  @override
  String get auth_openMail => 'মেইল খুলুন';

  @override
  String get auth_unableToOpenMail => 'কোনো মেইল অ্যাপ খোলা যায়নি।';

  @override
  String get auth_resendEmail => 'ইমেইল আবার পাঠান';

  @override
  String get auth_resendSent => 'নতুন নিশ্চিতকরণ ইমেইল পাঠানো হয়েছে।';

  @override
  String get auth_changeEmail => 'ইমেইল ঠিকানা পরিবর্তন করুন';

  @override
  String get auth_changeEmailPasswordTitle => 'পাসওয়ার্ড নিশ্চিত করুন';

  @override
  String get auth_changeEmailPasswordPrompt =>
      'চালিয়ে যেতে এই অ্যাকাউন্টের পাসওয়ার্ডটি লিখুন।';

  @override
  String get auth_changeEmailAlreadyConfirmed =>
      'এই ঠিকানাটি আগেই নিশ্চিত হয়েছে। বরং লগইন করুন।';

  @override
  String get auth_changeEmailRefused =>
      'এই অ্যাকাউন্টে ইতিমধ্যে তথ্য আছে। লগইন করে সেটিংস থেকে অ্যাকাউন্টটি মুছে ফেলুন।';

  @override
  String get auth_emailConfirmedTitle => 'ইমেইল নিশ্চিত হয়েছে!';

  @override
  String auth_emailConfirmedMessage(String email) {
    return '$email ঠিকানাটি নিশ্চিত হয়েছে। এখন আপনি অ্যাপটি ব্যবহার করতে পারেন।';
  }

  @override
  String get auth_forgotTitle => 'পাসওয়ার্ড রিসেট';

  @override
  String get auth_forgotSubtitle =>
      'আপনার ইমেইল দিন, আমরা একটি রিকভারি কোড পাঠাব।';

  @override
  String get auth_recoveryLinkSubtitle =>
      'আপনার অ্যাকাউন্টের জন্য একটি নতুন পাসওয়ার্ড দিন।';

  @override
  String get auth_sendCodeButton => 'কোড পাঠান';

  @override
  String get auth_recoveryCodeLabel => 'রিকভারি কোড';

  @override
  String get auth_recoveryCodeHelper =>
      'আমাদের পাঠানো কোডটি খুলে নতুন পাসওয়ার্ড দিন।';

  @override
  String get auth_recoverySent => 'কোড পাঠানো হয়েছে';

  @override
  String get auth_newPasswordLabel => 'নতুন পাসওয়ার্ড';

  @override
  String get auth_setPasswordButton => 'নতুন পাসওয়ার্ড সেট করুন';

  @override
  String get auth_passwordUpdated => 'আপনার পাসওয়ার্ড হালনাগাদ হয়েছে।';

  @override
  String get auth_errorInvalidCredentials =>
      'ইমেইল বা পাসওয়ার্ড ভুল। আবার চেষ্টা করুন।';

  @override
  String get auth_errorEmailNotConfirmed =>
      'আগে আপনার ইমেইল নিশ্চিত করুন — পাঠানো লিঙ্কটি খুলুন।';

  @override
  String get auth_errorEmailInUse =>
      'এই ইমেইলে আগেই একটি অ্যাকাউন্ট আছে। লগইন করুন।';

  @override
  String get auth_errorWeakPassword => 'কমপক্ষে ৮ অক্ষরের পাসওয়ার্ড দিন।';

  @override
  String get auth_errorRateLimited =>
      'অনেকবার চেষ্টা করা হয়েছে। কয়েক মিনিট পরে আবার চেষ্টা করুন।';

  @override
  String get auth_errorInvalidCode =>
      'ইনভাইট কোডটি সঠিক নয়। ফার্ম মালিকের সাথে যাচাই করুন।';

  @override
  String get auth_errorTooManyAttempts =>
      'অনেকবার চেষ্টা হয়েছে। পরে আবার চেষ্টা করুন।';

  @override
  String get auth_errorFirmAdminOffline =>
      'ফার্ম পরিচালনা করতে ইন্টারনেটে সংযুক্ত হোন।';

  @override
  String get auth_errorPremiumRequired =>
      'ফার্ম মোডের জন্য সক্রিয় প্রিমিয়াম সাবস্ক্রিপশন প্রয়োজন।';

  @override
  String get firm_errorServer =>
      'সার্ভার অনুরোধটি সম্পন্ন করতে পারেনি। আবার চেষ্টা করুন।';

  @override
  String get firm_errorUnauthorized =>
      'আপনার অ্যাকাউন্টের এই কাজটি করার অনুমতি নেই।';

  @override
  String get firm_errorUnavailable =>
      'এই বিল্ডে ফার্ম ম্যানেজমেন্ট উপলব্ধ নয়।';

  @override
  String get auth_errorAlreadyMember => 'আপনি ইতিমধ্যেই এই ফার্মের সদস্য।';

  @override
  String get auth_joinedFirm => 'আপনি ফার্মে যোগ দিয়েছেন।';

  @override
  String get auth_errorNetwork => 'সংযোগ নেই। ইন্টারনেট দেখে আবার চেষ্টা করুন।';

  @override
  String get auth_errorUnavailable => 'এই বিল্ডে সাইন-ইন সুবিধা নেই।';

  @override
  String get auth_errorGoogleFailed =>
      'Google সাইন-ইন সম্পন্ন হয়নি। আবার চেষ্টা করুন।';

  @override
  String get auth_errorAccountMismatch =>
      'এই ডিভাইসটি অন্য একটি অ্যাকাউন্টের। সেই অ্যাকাউন্টে লগইন করুন, অথবা ব্যাকআপ থেকে পুনরুদ্ধার করুন।';

  @override
  String get auth_errorUnknown => 'কিছু একটা ভুল হয়েছে। আবার চেষ্টা করুন।';

  @override
  String get auth_validationEmailRequired => 'আপনার ইমেইল লিখুন।';

  @override
  String get auth_validationEmailInvalid => 'সঠিক ইমেইল ঠিকানা লিখুন।';

  @override
  String get auth_validationPasswordRequired => 'আপনার পাসওয়ার্ড লিখুন।';

  @override
  String get auth_validationPasswordTooShort => 'কমপক্ষে ৮ অক্ষর ব্যবহার করুন।';

  @override
  String get auth_validationPasswordConfirmRequired =>
      'আপনার পাসওয়ার্ড নিশ্চিত করুন।';

  @override
  String get auth_validationPasswordMismatch => 'দুটি পাসওয়ার্ড মিলতে হবে।';

  @override
  String get auth_validationMandatory => 'এই ঘরটি বাধ্যতামূলক।';

  @override
  String get auth_validationInviteCodeRequired => 'আপনার ইনভাইট কোড লিখুন।';

  @override
  String get auth_validationTermsRequired =>
      'চালিয়ে যেতে সেবার শর্তাবলি ও গোপনীয়তা নীতিতে সম্মতি দিন।';

  @override
  String get auth_sessionExpired => 'আপনার সেশন শেষ হয়েছে। আবার সাইন ইন করুন।';

  @override
  String get auth_sessionExpiredAction => 'সাইন ইন';

  @override
  String get manageAssociates_title => 'সহকারী ব্যবস্থাপনা';

  @override
  String get manageAssociates_ownerOnly =>
      'শুধু ফার্মের মালিক সহকারী ব্যবস্থাপনা করতে পারেন।';

  @override
  String get manageAssociates_sectionMembers => 'সহকারীরা';

  @override
  String get manageAssociates_addAssociate => 'সহকারী যোগ করুন';

  @override
  String get manageAssociates_noMembers => 'এখনো কোনো সহকারী নেই।';

  @override
  String get manageAssociates_unnamedMember => 'নামহীন সদস্য';

  @override
  String get manageAssociates_createFirmIntro =>
      'ফার্ম তৈরি করে একসাথে কাজ করতে আপনার প্রথম সহকারীকে যোগ করুন।';

  @override
  String get manageAssociates_firmNameLabel => 'ফার্মের নাম';

  @override
  String get manageAssociates_firmNameHint =>
      'আপনার চেম্বার বা ফার্মের নাম লিখুন';

  @override
  String get manageAssociates_createFirm => 'ফার্ম তৈরি করুন';

  @override
  String get manageAssociates_goPremium => 'প্রিমিয়াম নিন';

  @override
  String get manageAssociates_inviteTitle => 'আমন্ত্রণ কোড';

  @override
  String get manageAssociates_inviteIntro =>
      'এই কোডটি আপনার সহকারীকে দিন। এটি একবারই কাজ করে এবং শুধু এই একবারই দেখানো হবে।';

  @override
  String get manageAssociates_copyCode => 'কোড কপি করুন';

  @override
  String get manageAssociates_codeCopied => 'কোড কপি হয়েছে।';

  @override
  String get manageAssociates_shareCode => 'শেয়ার করুন';

  @override
  String get manageAssociates_shareFailed => 'কোড শেয়ার করা যায়নি';

  @override
  String manageAssociates_inviteMessage(String code) {
    return 'লিগ্যাল কেস ডায়েরিতে আমার ফার্মে যোগ দিন। আমন্ত্রণ কোড: $code';
  }

  @override
  String get manageAssociates_sectionInvites => 'অব্যবহৃত আমন্ত্রণ';

  @override
  String get manageAssociates_noInvites => 'কোনো অব্যবহৃত আমন্ত্রণ নেই।';

  @override
  String manageAssociates_inviteCreated(String date) {
    return 'তৈরি $date';
  }

  @override
  String get manageAssociates_revokeInvite => 'বাতিল করুন';

  @override
  String get manageAssociates_revokeInviteTitle => 'এই আমন্ত্রণটি বাতিল করবেন?';

  @override
  String get manageAssociates_revokeInviteBody =>
      'কোডটি সঙ্গে সঙ্গে কাজ করা বন্ধ করে দেবে।';

  @override
  String get manageAssociates_inviteRevoked => 'আমন্ত্রণ বাতিল করা হয়েছে।';

  @override
  String get manageAssociates_permissionsTitle => 'অনুমতি';

  @override
  String get manageAssociates_roleLabel => 'ভূমিকা';

  @override
  String get manageAssociates_permissionAdd => 'মামলা যোগ';

  @override
  String get manageAssociates_permissionEdit => 'মামলা সম্পাদনা';

  @override
  String get manageAssociates_permissionDelete => 'মামলা মুছে ফেলা';

  @override
  String get manageAssociates_savePermissions => 'অনুমতি সংরক্ষণ করুন';

  @override
  String get manageAssociates_permissionsUpdated =>
      'অনুমতি হালনাগাদ করা হয়েছে।';

  @override
  String get manageAssociates_removeAssociate => 'ফার্ম থেকে সরান';

  @override
  String get manageAssociates_removeAssociateTitle =>
      'এই সহকারীকে সরিয়ে দেবেন?';

  @override
  String get manageAssociates_removeAssociateBody =>
      'তিনি সঙ্গে সঙ্গে ফার্মের মামলাগুলোতে প্রবেশাধিকার হারাবেন। তিনি তৈরি করা রেকর্ড ফার্মেই থাকবে।';

  @override
  String get manageAssociates_associateRemoved => 'সহকারীকে সরানো হয়েছে।';

  @override
  String get syncNotice_permissionsChanged =>
      'আপনার ফার্মের অনুমতি পরিবর্তিত হয়েছে; এই অপেক্ষমাণ কাজটি প্রয়োগ করা হয়নি।';

  @override
  String get syncNotice_clockSkew =>
      'আপনার ডিভাইসের ঘড়ি সার্ভার থেকে দুই মিনিটের বেশি পিছিয়ে বা এগিয়ে আছে। সিঙ্ক করা সময় ভুল হতে পারে।';

  @override
  String get membershipRevoked_title =>
      'আপনাকে ফার্ম থেকে সরিয়ে দেওয়া হয়েছে';

  @override
  String get membershipRevoked_body =>
      'আপনার ফার্মের মালিক এই অ্যাকাউন্টটি সরিয়ে দিয়েছেন। আপনি আর ফার্মের মামলা দেখতে বা সম্পাদনা করতে পারবেন না, এবং সিঙ্ক করার অপেক্ষায় থাকা সবকিছু বাতিল করা হয়েছে। ব্যক্তিগত ডায়েরি দিয়ে চালিয়ে যেতে লগ আউট করুন।';

  @override
  String get membershipRevoked_action => 'লগ আউট';

  @override
  String get membershipRevoked_logoutFailed =>
      'লগ আউট করা যায়নি। আবার চেষ্টা করুন।';

  @override
  String get deleteRequest_confirmTitle => 'মুছে ফেলার অনুরোধ পাঠাবেন?';

  @override
  String get deleteRequest_confirmBody =>
      'রেকর্ডটি মুছে ফেলার আগে ডিলিট অনুমতি আছে এমন একজন ফার্ম সদস্যকে এটি অনুমোদন করতে হবে।';

  @override
  String get deleteRequest_confirmSend => 'অনুরোধ পাঠান';

  @override
  String get deleteRequest_sent =>
      'ডিলিট অনুরোধ অ্যাডমিন/মালিকের কাছে পাঠানো হয়েছে।';

  @override
  String get deleteRequest_failed => 'ডিলিট অনুরোধ পাঠানো যায়নি।';

  @override
  String get deleteRequests_title => 'ডিলিট অনুরোধ';

  @override
  String get deleteRequests_firmOnly =>
      'ডিলিট অনুরোধ শুধু ফার্ম সদস্যদের জন্য উপলব্ধ।';

  @override
  String get deleteRequests_toReview => 'আপনার পর্যালোচনার অপেক্ষায়';

  @override
  String get deleteRequests_noneToReview =>
      'পর্যালোচনার অপেক্ষায় কোনো ডিলিট অনুরোধ নেই।';

  @override
  String get deleteRequests_mine => 'আমার অনুরোধ';

  @override
  String get deleteRequests_noneMine => 'আপনি কোনো ডিলিট অনুরোধ পাঠাননি।';

  @override
  String get deleteRequests_statusPending => 'অপেক্ষমাণ';

  @override
  String get deleteRequests_statusApproved => 'অনুমোদিত';

  @override
  String get deleteRequests_statusRejected => 'প্রত্যাখ্যাত';

  @override
  String get deleteRequests_statusStale => 'পুনরায় নিশ্চিতকরণ প্রয়োজন';

  @override
  String deleteRequests_requestedBy(String name) {
    return 'অনুরোধ করেছেন $name';
  }

  @override
  String deleteRequests_requestedOn(String date) {
    return 'অনুরোধের তারিখ $date';
  }

  @override
  String get deleteRequests_unnamed => 'একটি রেকর্ড';

  @override
  String get deleteRequests_entityCase => 'মামলা';

  @override
  String get deleteRequests_entityCaseHistory => 'মামলার ইতিহাস';

  @override
  String get deleteRequests_entityNote => 'নোট';

  @override
  String get deleteRequests_entityReference => 'রেফারেন্স';

  @override
  String get deleteRequests_entityUnknown => 'রেকর্ড';

  @override
  String get deleteRequests_reviewTitle => 'ডিলিট অনুরোধ পর্যালোচনা';

  @override
  String get deleteRequests_snapshot => 'অনুরোধকৃত রেকর্ড';

  @override
  String get deleteRequests_noteLabel => 'পর্যালোচনা নোট (ঐচ্ছিক)';

  @override
  String get deleteRequests_noteHint => 'একটি কারণ যোগ করুন';

  @override
  String get deleteRequests_approve => 'অনুমোদন';

  @override
  String get deleteRequests_reconfirm => 'পুনরায় নিশ্চিত করুন';

  @override
  String get deleteRequests_reject => 'প্রত্যাখ্যান';

  @override
  String get deleteRequests_approveTitle => 'মুছে ফেলা অনুমোদন করবেন?';

  @override
  String get deleteRequests_approveBody =>
      'রেকর্ডটি ফার্মের সবার জন্য মুছে ফেলা হবে।';

  @override
  String get deleteRequests_rejectTitle => 'ডিলিট অনুরোধ প্রত্যাখ্যান করবেন?';

  @override
  String get deleteRequests_rejectBody =>
      'রেকর্ডটি থাকবে। অনুরোধকারীকে আপনার সিদ্ধান্ত জানানো হবে।';

  @override
  String get deleteRequests_approved => 'মুছে ফেলা অনুমোদিত হয়েছে।';

  @override
  String get deleteRequests_rejected => 'ডিলিট অনুরোধ প্রত্যাখ্যান করা হয়েছে।';

  @override
  String get deleteRequests_failed =>
      'পর্যালোচনা সম্পন্ন করা যায়নি। আবার চেষ্টা করুন।';

  @override
  String get deleteRequests_staleTitle => 'এই রেকর্ডটি পরিবর্তিত হয়েছে';

  @override
  String get deleteRequests_staleBody =>
      'অনুরোধ করার পরে এটি পরিবর্তিত হয়েছে। নিচের বিবরণ এখন যা আছে তা দেখায়; এই বর্তমান সংস্করণটি মুছতে পুনরায় নিশ্চিত করুন।';

  @override
  String get deleteRequests_fieldCaseNumber => 'মামলা নম্বর';

  @override
  String get deleteRequests_fieldCaseType => 'মামলার ধরন';

  @override
  String get deleteRequests_fieldPetitioner => 'বাদী';

  @override
  String get deleteRequests_fieldRespondent => 'বিবাদী';

  @override
  String get deleteRequests_fieldStep => 'ধাপ';

  @override
  String get deleteRequests_fieldResult => 'ফলাফল';

  @override
  String get deleteRequests_fieldTitle => 'শিরোনাম';

  @override
  String get deleteRequests_fieldBody => 'নোট';

  @override
  String get deleteRequests_fieldReference => 'রেফারেন্স ও পৃষ্ঠা নম্বর';

  @override
  String get deleteRequests_fieldDescription => 'শিরোনাম ও বিবরণ';

  @override
  String get deleteRequests_unknownRequester => 'একজন ফার্ম সদস্য';

  @override
  String get deleteRequests_edit => 'অনুরোধ সম্পাদনা করুন';

  @override
  String get deleteRequests_withdraw => 'অনুরোধ প্রত্যাহার করুন';

  @override
  String get deleteRequests_withdrawTitle =>
      'এই ডিলিট অনুরোধ প্রত্যাহার করবেন?';

  @override
  String get deleteRequests_withdrawBody =>
      'রেকর্ডটি মুছে ফেলা হবে না, এবং অনুরোধটি পর্যালোচকদের তালিকা থেকে সরে যাবে।';

  @override
  String get deleteRequests_withdrawn => 'ডিলিট অনুরোধ প্রত্যাহার করা হয়েছে।';

  @override
  String get deleteRequests_updated => 'অনুরোধ হালনাগাদ করা হয়েছে।';

  @override
  String get deleteRequests_updateFailed => 'অনুরোধ হালনাগাদ করা যায়নি।';

  @override
  String get deleteRequests_withdrawFailed => 'অনুরোধ প্রত্যাহার করা যায়নি।';

  @override
  String get payments_goPremium => 'প্রিমিয়াম নিন';

  @override
  String get payments_checkoutTitle => 'চেকআউট';

  @override
  String get payments_planSummaryTitle => 'প্ল্যান';

  @override
  String payments_amountValue(String amount) {
    return '৳$amount';
  }

  @override
  String get payments_transferTitle => 'ট্রান্সফার নির্দেশনা';

  @override
  String payments_transferBody(String amount) {
    return 'নিচের যেকোনো একটি নম্বরে ৳$amount পাঠান, তারপর আপনার পেমেন্টের তথ্য দিন।';
  }

  @override
  String get payments_copy => 'কপি';

  @override
  String get payments_copied => 'নম্বর কপি হয়েছে।';

  @override
  String get payments_formTitle => 'পেমেন্টের তথ্য';

  @override
  String get payments_methodLabel => 'পেমেন্ট পদ্ধতি';

  @override
  String get payments_methodBkash => 'বিকাশ';

  @override
  String get payments_methodNagad => 'নগদ';

  @override
  String get payments_methodRocket => 'রকেট';

  @override
  String get payments_phoneLabel => 'প্রেরকের ফোন নম্বর';

  @override
  String get payments_phoneHint => '01XXXXXXXXX';

  @override
  String get payments_trxLabel => 'ট্রানজেকশন আইডি (TrxID)';

  @override
  String get payments_trxHint => 'TrxID লিখুন';

  @override
  String get payments_submit => 'পেমেন্ট জমা দিন';

  @override
  String get payments_numberUnavailable =>
      'এই মুহূর্তে পেমেন্ট নম্বর পাওয়া যাচ্ছে না। পরে আবার চেষ্টা করুন।';

  @override
  String get payments_errorPhone => 'একটি সঠিক মোবাইল নম্বর লিখুন।';

  @override
  String get payments_errorTrx => 'ট্রানজেকশন আইডি লিখুন।';

  @override
  String get payments_submitFailed => 'জমা দেওয়া যায়নি। আবার চেষ্টা করুন।';

  @override
  String get payments_limitReached =>
      'আজকের জমা দেওয়ার সীমায় পৌঁছে গেছেন। আগামীকাল আবার চেষ্টা করুন।';

  @override
  String get payments_duplicateTrx =>
      'এই ট্রানজেকশন আইডি ইতিমধ্যে জমা দেওয়া হয়েছে।';

  @override
  String get payments_submitSuccess => 'জমা পাওয়া গেছে। আমরা শীঘ্রই যাচাই করব।';

  @override
  String get payments_historyTitle => 'পেমেন্টের ইতিহাস';

  @override
  String get payments_noSubmissions => 'এখনো কোনো পেমেন্ট জমা দেওয়া হয়নি।';

  @override
  String get payments_statusPending => 'অপেক্ষমাণ';

  @override
  String get payments_statusApproved => 'অনুমোদিত';

  @override
  String get payments_statusRejected => 'প্রত্যাখ্যাত';

  @override
  String get payments_notesLabel => 'মন্তব্য';

  @override
  String get subscription_bannerGrace =>
      'আপনার সাবস্ক্রিপশন শেষ হয়ে গেছে। সিঙ্ক চালু রাখতে নবায়ন করুন।';

  @override
  String get subscription_bannerExpiredOwner =>
      'আপনার প্রিমিয়াম সাবস্ক্রিপশন শেষ হয়ে গেছে। সিঙ্ক ফিরে পেতে সাবস্ক্রিপশন নবায়ন করুন।';

  @override
  String get subscription_bannerExpiredAssociate =>
      'আপনার ফার্মের প্রিমিয়াম সাবস্ক্রিপশন শেষ হয়ে গেছে। নবায়নের জন্য ফার্মের মালিকের সাথে যোগাযোগ করুন।';

  @override
  String get settingsManageAccount_plan => 'প্ল্যান';

  @override
  String get settingsManageAccount_expiry => 'মেয়াদ শেষ';

  @override
  String get settingsDiagnostics_title => 'ডায়াগনস্টিকস';

  @override
  String get settingsDiagnostics_hint =>
      'এই অ্যাপে রেকর্ড করা ত্রুটিগুলো। মামলার তথ্য, পাসওয়ার্ড বা টোকেন কখনো এখানে লেখা হয় না।';

  @override
  String get settingsDiagnostics_empty => 'কোনো ত্রুটি রেকর্ড হয়নি।';

  @override
  String get settingsDiagnostics_clear => 'লগ মুছুন';

  @override
  String get settingsDiagnostics_cleared => 'ত্রুটি লগ মুছে ফেলা হয়েছে।';

  @override
  String get settingsDiagnostics_copy => 'ডায়াগনস্টিকস কপি করুন';

  @override
  String get settingsDiagnostics_copied =>
      'ডায়াগনস্টিকস কপি করা হয়েছে। আমাদের একটি বার্তায় পেস্ট করুন।';

  @override
  String get settingsAppLock_title => 'অ্যাপ লক';

  @override
  String get settingsAppLock_setup => 'অ্যাপ লক সেটআপ করুন';

  @override
  String get settingsAppLock_changePin => 'অ্যাপ লক পিন পরিবর্তন করুন';

  @override
  String get settingsAppLock_enableFingerprint => 'ফিঙ্গারপ্রিন্ট চালু করুন';

  @override
  String get settingsAppLock_disableFingerprint => 'ফিঙ্গারপ্রিন্ট বন্ধ করুন';

  @override
  String get settingsAppLock_whenToAsk => 'কখন পিন চাইতে হবে';

  @override
  String get settingsAppLock_whenAppStarts => 'অ্যাপ চালু হলে';

  @override
  String get settingsAppLock_whenAppOpensAndReturns =>
      'প্রতিবার অ্যাপ খোলার সময়';

  @override
  String settingsAppLock_choosePin(String digits) {
    return '$digits সংখ্যার একটি পিন চয়ন করুন';
  }

  @override
  String get settingsAppLock_confirmPin => 'আপনার পিন নিশ্চিত করুন';

  @override
  String get settingsAppLock_pinMismatch =>
      'পিন দুটি মিলছে না। আবার শুরু করুন।';

  @override
  String get settingsAppLock_setupDone => 'অ্যাপ লক চালু হয়েছে।';

  @override
  String get settingsAppLock_setupFailed =>
      'পিন সংরক্ষণ করা যায়নি। আবার চেষ্টা করুন।';

  @override
  String get settingsAppLock_enterCurrentPin => 'আপনার বর্তমান পিন দিন';

  @override
  String get settingsAppLock_newPin => 'নতুন একটি পিন দিন';

  @override
  String get settingsAppLock_pinChanged => 'অ্যাপ লক পিন পরিবর্তন হয়েছে।';

  @override
  String get settingsAppLock_currentPinWrong => 'পিনটি সঠিক নয়।';

  @override
  String get settingsAppLock_unlockTitle => 'আনলক করতে আপনার পিন দিন';

  @override
  String get settingsAppLock_wrongPin => 'পিন ভুল হয়েছে। আবার চেষ্টা করুন।';

  @override
  String settingsAppLock_tooManyAttempts(String seconds) {
    return 'অনেকবার চেষ্টা হয়েছে। $seconds সেকেন্ড পরে আবার চেষ্টা করুন।';
  }

  @override
  String get settingsAppLock_verifyForFingerprint =>
      'অ্যাপ লকের জন্য নিজের পরিচয় নিশ্চিত করুন';

  @override
  String get settingsAppLock_fingerprintEnabled =>
      'ফিঙ্গারপ্রিন্ট আনলক চালু হয়েছে।';

  @override
  String get settingsAppLock_fingerprintDisabled =>
      'ফিঙ্গারপ্রিন্ট আনলক বন্ধ হয়েছে।';

  @override
  String get settingsAppLock_fingerprintUnavailable =>
      'এই ডিভাইসে কোনো ফিঙ্গারপ্রিন্ট নেই।';

  @override
  String get settingsAppLock_useFingerprint => 'ফিঙ্গারপ্রিন্ট দিয়ে আনলক করুন';

  @override
  String get settingsAppLock_turnOff => 'অ্যাপ লক বন্ধ করুন';

  @override
  String get settingsAppLock_turnOffTitle => 'অ্যাপ লক বন্ধ করবেন?';

  @override
  String get settingsAppLock_turnOffBody =>
      'আবার অ্যাপ লক সেটআপ না করা পর্যন্ত অ্যাপটি কোনো পিন বা ফিঙ্গারপ্রিন্ট ছাড়াই খুলবে।';

  @override
  String get settingsAppLock_turnOffConfirm => 'বন্ধ করুন';

  @override
  String get settingsAppLock_turnedOff => 'অ্যাপ লক বন্ধ হয়েছে।';
}
