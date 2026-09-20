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
  String get allCasesScreen_title => 'সব মামলা';

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
  String get activeCasesScreen_title => 'সক্রিয় মামলা';

  @override
  String get upcomingCasesScreen_title => 'আসন্ন মামলা';

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
      'এখনো কোনো ইতিহাস এন্ট্রি নেই।';

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
  String addEditCaseSheet_offsetDaysBefore(Object count) {
    return '$count দিন আগে';
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
  String get casesContact_whatsappNote => 'চ্যাট খুলবে — সেখান থেকে কল করুন।';

  @override
  String casesContact_noNumber(String party) {
    return '$party পক্ষের কোনো নম্বর সংরক্ষিত নেই।';
  }

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
  String get notesScreen_empty => 'এখনও কোনো নোট নেই। যোগ করতে + ট্যাপ করুন।';

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
  String get paywall_title => 'প্রিমিয়াম';

  @override
  String get paywall_limitTitle => 'ফ্রি প্ল্যানের সীমা পূর্ণ হয়েছে';

  @override
  String paywall_limitBody(String limit) {
    return 'ফ্রি প্ল্যানে সর্বোচ্চ $limitটি মামলা রাখা যায়। একটি মামলা মুছে ফেললে জায়গা খালি হয়; ক্লায়েন্ট ম্যানেজমেন্ট, দৈনিক মামলার তালিকা, সম্পাদনা ও প্রিন্ট — সবই ফ্রি থাকে।';
  }

  @override
  String get paywall_benefitsTitle => 'প্রিমিয়ামে যা থাকে';

  @override
  String get paywall_benefitUnlimitedCases => 'আনলিমিটেড মামলা';

  @override
  String get paywall_benefitCloudBackup => 'নিরাপদ এনক্রিপ্টেড ক্লাউড ব্যাকআপ';

  @override
  String get paywall_benefitMultiDevice =>
      'যে ডিভাইসেই সাইন ইন করুন, ডায়েরি সেখানেই';

  @override
  String get paywall_benefitFirmMode => 'সহকারীদের জন্য ফার্ম মোড';

  @override
  String get paywall_plansTitle => 'প্ল্যান';

  @override
  String get paywall_planMonthly => 'মাসিক';

  @override
  String paywall_planMonthlyPrice(String price) {
    return '৳$price / মাস';
  }

  @override
  String get paywall_planAnnual => 'বার্ষিক';

  @override
  String paywall_planAnnualPrice(String price) {
    return '৳$price / বছর';
  }

  @override
  String get paywall_comingSoon => 'শীঘ্রই আসছে';

  @override
  String get paywall_note =>
      'সাবস্ক্রিপশন এখনো চালু হয়নি। এই স্ক্রিনে দেখা যাচ্ছে প্রিমিয়ামে কী থাকবে এবং কোন প্ল্যানের দাম কত।';

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
  String get sharedMessages_signInRequired =>
      'সাইন ইন করার পর উপলব্ধ (Task 17)';

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
  String get settingsScreen_manageAccount => 'অ্যাকান্ট ব্যবস্থাপনা';

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
  String get settingsAccountProfile_profileSubtitle =>
      'আপনার নাম, বার অ্যাসোসিয়েশন ও সদস্যপদ সংক্রান্ত তথ্য';

  @override
  String get settingsAccountProfile_manageAccountSubtitle =>
      'পাসওয়ার্ড, সাবস্ক্রিপশন ও অ্যাকাউন্ট সেটিংস';

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
  String get settingsManageAccount_title => '্যাকাউন্ট ব্যবস্থাপনা';

  @override
  String get settingsManageAccount_changePassword => 'পাসওয়ার্ড পরিবর্তন';

  @override
  String get settingsManageAccount_subscriptionDetails => 'সাবস্ক্রিপশন বিবরণ';

  @override
  String get settingsManageAccount_purchaseNewSubscription =>
      'নতুন সাবস্ক্রিপশন ক্রয়';

  @override
  String get settingsManageAccount_logout => 'লগআউট';

  @override
  String get settingsManageAccount_accountSettings => 'অ্যাকাউন্ট সেটিংস';

  @override
  String get settingsManageAccount_deleteAccount => 'অ্যাকাউন্ট মুছুন';

  @override
  String get settingsManageAccount_deleteCannotBeUndone =>
      'এই কাজটি ফিরিয়ে আনা যাবে না';

  @override
  String get settingsOnlineSync_title => 'অনলাইন সিঙ্ক';

  @override
  String get settingsOnlineSync_subtitle =>
      'আপনার সব ডিভাইসে রিয়েল-টাইম ডেটা সিঙ্ক পরিচালনা করুন।';

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
  String get settingsOnlineSync_itemsUnknown => '— আইটেম';

  @override
  String settingsOnlineSync_itemsCount(int count) {
    return '$count আইটেম';
  }

  @override
  String get settingsBackupRestore_title => 'ব্যাকআপ ও পুনরুদ্ধার';

  @override
  String get settingsBackupRestore_sectionBackup => 'ব্যাকআপ ও পুনরুদ্ধার';

  @override
  String get settingsBackupRestore_sectionAutomaticBackup =>
      'স্বয়ংক্রিয় ব্যাকআপ';

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
      'ব্যাকআপ এনক্রিপ্ট করা হয় এবং আপনার লোকাল স্টোরেজ বা ক্লাউড প্রোভাইডারে সংরক্ষিত হয়। পুনরুদ্ধার বর্তমান ডেটা প্রতিস্থাপন করবে।';

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
  String get settingsBackupRestore_encryptAndSave =>
      'এনক্রিপ্ট করে সংরক্ষণ করুন';

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
  String get settingsBackupRestore_errorOpenFile => 'ফাইলটি খোলা যায়নি।';

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
      'এখনো কোনো আইটেম নেই। নিচে একটি যোগ করুন।';

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
      'এখনো কোনো আদালত নেই। নিচে একটি যোগ করুন।';

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
      'এই জেলায় এখনো কোনো আদালতের ক্যাটেগরি নেই।';

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
  String get settingsNotifications_offsetSameDay => 'একই দিনে';

  @override
  String get settingsNotifications_offsetDayBefore => 'একদিন আগে';

  @override
  String settingsNotifications_offsetBeforeDays(int days) {
    return '$days দিন আগে';
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
  String get settingsGuidelines_dailyCauseListTitle => 'দৈনিক কজ লিস্ট';

  @override
  String get settingsGuidelines_dailyCauseListBody1 =>
      'দৈনিক কজ লিস্ট আপনার রেকর্ড করা একদিনের শুনানিগুলো আপনার আদালত-ক্রম অনুযায়ী আদালতভিত্তিক গ্রুপে এবং দিনের মোট সংখ্যাসহ দেখায়। ক্যালেন্ডার থেকে অন্য তারিখ বাছাই করুন; ডিফল্টভাবে আজকের তারিখ নির্বাচিত থাকে।';

  @override
  String get settingsGuidelines_dailyCauseListBody2 =>
      'তালিকাটি আপনার নিজের মামলার তথ্য থেকে তৈরি, তাই তথ্য যত নির্ভুল তালিকাও তত নির্ভুল। প্রতিটি মামলার পরবর্তী তারিখ ও সর্বশেষ ধাপ হালনাগাদ রাখুন এবং আদালত থেকে ফেরার সঙ্গে সঙ্গে তালিকা থেকেই শুনানির ফলাফল লিখুন। হালনাগাদ ছাড়া শুনানির তারিখ পেরিয়ে গেলে ফলাফল লেখা পর্যন্ত মামলাটি \'মেয়াদোত্তীর্ণ তারিখ\' অংশে থাকবে।';

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
      'অফলাইন সংস্করণে আপনি নিজে না পাঠালে আপনার ফোন থেকে কোনো তথ্য বাইরে যায় না। পাসফ্রেজ নিরাপদে রেখে দিন — ব্যাকআপ থাকলেও পাসফ্রেজ হারালে সেটি আমরা বা অন্য কেউ খুলতে পারবে না।';

  @override
  String get settingsGuidelines_sectionFaqs => 'সাধারণ জিজ্ঞাসা';

  @override
  String get settingsGuidelines_faqCatGettingStarted => 'শুরু করা';

  @override
  String get settingsGuidelines_faqCatGettingStartedQ1 =>
      'অ্যাপটি কি ইন্টারনেট সংযোগ ছাড়া চলে?';

  @override
  String get settingsGuidelines_faqCatGettingStartedA1 =>
      'হ্যাঁ। অ্যাপটি সম্পূর্ণ অফলাইনে কাজ করার জন্য তৈরি — মামলা যোগ ও সম্পাদনা, দৈনিক কজ লিস্ট, প্রিন্ট এবং ব্যাকআপ সবই সংযোগ ছাড়া চলে। অফলাইন সংস্করণে অনলাইন সিঙ্ক নেই।';

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
      'সেটিংস > ব্যাকআপ ও পুনরুদ্ধার-এ গিয়ে \'লোকাল স্টোরেজে ব্যাকআপ\'-এ ট্যাপ করুন। ফাইলটি কোথায় সংরক্ষিত হবে তা আপনি বেছে নেন এবং একটি পাসফ্রেজ দেন যা ফাইলটি এনক্রিপ্ট করে। কোনো অ্যাকাউন্ট বা ইন্টারনেট সংযোগ লাগে না।';

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
      'হ্যাঁ। অফলাইন অ্যাপটি ব্যবহারে কোনো খরচ নেই এবং এতে ৫০টি পর্যন্ত মামলা রাখা যায়। প্রিমিয়াম এই সীমা বাড়াবে এবং চালু হলে অনলাইন সিঙ্ক যোগ করবে।';

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
      'অফলাইন সংস্করণে আপনার লেখা সব তথ্য ডিভাইসেই এনক্রিপ্ট করা অবস্থায় থাকে। আমাদের বা অন্য কারো কাছে কিছু পাঠানো হয় না এবং কোনো অ্যাকাউন্ট লাগে না। ব্যাকআপ ফাইল এনক্রিপ্ট করা এবং কেবল আপনার দেওয়া পাসফ্রেজ দিয়েই খোলা যায়। অনলাইন সংস্করণ চালু হলে কী তথ্য কোথায় রাখা হবে তা ব্যবহারের আগে আলাদা নির্দেশনায় জানানো হবে।';

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
      'adv.asadusjaman@gmail.com-এ লিখুন, অথবা সেটিংস > সম্পর্কিত-এ গিয়ে আমাদের ইমেইল ও হোয়াটসঅ্যাপ যোগাযোগ দেখুন। সমস্যার সময় আপনি কী করছিলেন, আপনার ফোনের মডেল এবং সেটিংস > সম্পর্কিত-এ দেখা যাওয়া অ্যাপ সংস্করণ লিখুন।';

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
  String get settingsAbout_emailLabel => 'ইমেইল';

  @override
  String get settingsAbout_whatsappLabel => 'হোয়াটসঅ্যাপ';

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
  String get settingsLegal_loadFailed =>
      'এই নথিটি খোলা যায়নি। আবার চেষ্টা করুন।';

  @override
  String get settingsMoreAbout_title => 'অ্যাপ সম্পর্কে আরও';

  @override
  String get settingsMoreAbout_checkUpdates => 'আপডেট পরীক্ষা করুন';

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
}
