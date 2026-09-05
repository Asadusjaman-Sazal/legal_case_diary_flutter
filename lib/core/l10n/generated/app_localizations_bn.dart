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
  String get upcomingCasesScreen_title => 'সন্ন মামলা';

  @override
  String get general_tomorrow => 'আগামীকাল';

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
    return 'মোট $count টি এন্ট্রি';
  }

  @override
  String get caseDetailsScreen_noHistoryEntries =>
      'এখনো কোনো ইতিহাস এন্ট্রি নেই।';

  @override
  String caseDetailsScreen_viewAllHistory(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'সব $count টি ইতিহাস এন্ট্রি দেখুন',
      one: 'সম্পূর্ণ $count টি ইতিহাস এন্ট্রি দেখুন',
    );
    return '$_temp0';
  }

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
  String get disposedCasesScreen_title => 'নিষ্পত্তিকৃত মামলা';

  @override
  String get caseCard_disposed => 'নিষ্পত্তিকৃত:';

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
  String get activeCasesScreen_title => 'সক্রিয় মামলা';

  @override
  String get notesScreen_title => 'নোট';

  @override
  String get notesScreen_delete => 'মুছুন';

  @override
  String get notesScreen_pin => 'পিন';

  @override
  String get notesScreen_modified => 'পরিবর্তিত';

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
  String get settingsScreen_languageEnglish => 'English';

  @override
  String get settingsScreen_languageBengali => 'বাংলা';

  @override
  String get settingsScreen_viewSettings => 'ভিউ সেটিংস';

  @override
  String get settingsScreen_guidelines => 'নির্দেশনা';

  @override
  String get settingsScreen_about => 'সম্পর্কিত';

  @override
  String get settingsProfile_title => 'প্রোফাইল';

  @override
  String get settingsManageAccount_title => '্যাকাউন্ট ব্যবস্থাপনা';

  @override
  String get settingsOnlineSync_title => 'অনলাইন সিঙ্ক';

  @override
  String get settingsBackupRestore_title => 'ব্যাকআপ ও পুনরুদ্ধার';

  @override
  String get settingsNotifications_title => 'নোটিফিকেশন';

  @override
  String get settingsViewSettings_title => 'ভিউ সেটিংস';

  @override
  String get settingsGuidelines_title => 'নির্দেশনা';

  @override
  String get settingsAbout_title => 'সম্পর্কিত';

  @override
  String get sharedActions_save => 'সংরক্ষণ';

  @override
  String get sharedActions_cancel => 'বাতিল';

  @override
  String get sharedActions_delete => 'মুছুন';

  @override
  String get sharedActions_edit => 'সম্পাদনা';

  @override
  String get sharedActions_search => 'নুসন্ধান';

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
  String get sharedDialogs_ok => 'ঠিক আছে';

  @override
  String get sharedDialogs_cancel => 'বাতিল';

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
  ) {
    return 'প্রিয় $clientName, আপনার মামলা $caseNumber এ্রর পরবর্তী তারিখ $nextDate । কিছু জানার থাকলে আমাদের সাথে যোগাযোগ করুন।';
  }

  @override
  String messageTemplate_clientWhatsApp(
    String clientName,
    String caseNumber,
    String nextDate,
  ) {
    return 'প্রিয় $clientName, আপনার মামলা $caseNumber এ্রর পরবর্তী তারিখ $nextDate । কিছু জানার থাকলে আমাদের সাথে যোগাযোগ করুন।';
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
}
