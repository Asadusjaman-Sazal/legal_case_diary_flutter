// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Legal Case Diary';

  @override
  String get appTitle => 'Legal Case Diary';

  @override
  String get allCasesScreen_title => 'All Cases';

  @override
  String get allCasesScreen_activeCases => 'Active Cases';

  @override
  String get allCasesScreen_disposedCases => 'Disposed Cases';

  @override
  String get allCasesScreen_filterByCourt => 'Filter by Court';

  @override
  String get allCasesScreen_newestFirst => 'Newest first';

  @override
  String get allCasesScreen_oldestFirst => 'Oldest first';

  @override
  String get allCasesScreen_caseType => 'Case Type';

  @override
  String get allCasesScreen_caseNumber => 'Case No';

  @override
  String get allCasesScreen_onBehalf => 'On Behalf';

  @override
  String get allCasesScreen_petitionerVsRespondent =>
      'Petitioner Vs Respondent';

  @override
  String get caseCard_nextDate => 'Next Date';

  @override
  String get caseCard_previousDate => 'Previous Date';

  @override
  String get caseCard_lastStep => 'Step';

  @override
  String get allCasesScreen_phone => 'Phone';

  @override
  String get allCasesScreen_message => 'Message';

  @override
  String get allCasesScreen_unableToCall => 'Unable to place a call.';

  @override
  String get allCasesScreen_unableToMessage => 'Unable to open messages.';

  @override
  String get allCasesScreen_update => 'Update';

  @override
  String get dailyCauseListScreen_title => 'Daily Cause List';

  @override
  String get dailyCauseListScreen_today => 'Today';

  @override
  String get dailyCauseListScreen_tomorrow => 'Tomorrow';

  @override
  String get dailyCauseListScreen_calendarLabel => 'Calendar';

  @override
  String get dailyCauseListScreen_noHearings =>
      'No hearings scheduled for this date.';

  @override
  String get dailyCauseListScreen_totalHearings => 'Total Hearings:';

  @override
  String get dailyCauseListScreen_selectYear => 'Select Year';

  @override
  String get dailyCauseListScreen_selectMonth => 'Select Month';

  @override
  String get dailyCauseListScreen_noPhone => 'No phone number for this case.';

  @override
  String get dailyCauseListScreen_whatsappError => 'Unable to open WhatsApp.';

  @override
  String get dailyCauseListScreen_callError => 'Unable to place a call.';

  @override
  String get dailyCauseListScreen_messageError => 'Unable to open messages.';

  @override
  String get upcomingCasesScreen_title => 'Upcoming Cases';

  @override
  String get general_tomorrow => 'Tomorrow';

  @override
  String get overdueDatesScreen_title => 'Overdue Dates';

  @override
  String get overdueDatesScreen_lastUpdated => 'Last Updated';

  @override
  String get caseDetailsScreen_title => 'Case Details';

  @override
  String get caseDetailsScreen_delete => 'Delete';

  @override
  String get caseDetailsScreen_editCase => 'Edit Case';

  @override
  String get caseDetailsScreen_close => 'Close';

  @override
  String get caseDetailsScreen_onBehalfOf => 'On Behalf Of';

  @override
  String get caseDetailsScreen_petitioner => 'Petitioner';

  @override
  String get caseDetailsScreen_respondent => 'Respondent';

  @override
  String get caseDetailsScreen_leadCounsel => 'Lead Counsel';

  @override
  String get caseDetailsScreen_caseTitleAndRemark => 'Case Title & Remark';

  @override
  String get caseDetailsScreen_sectionsOrCaseTitle => 'Sections or Case Title';

  @override
  String get caseDetailsScreen_remarksOrCaseSummary =>
      'Remarks or Case Summary';

  @override
  String get caseDetailsScreen_caseHistory => 'Case History';

  @override
  String get caseDetailsScreen_phone => 'Phone';

  @override
  String get caseDetailsScreen_message => 'Message';

  @override
  String caseDetailsScreen_entriesTotal(int count) {
    return '$count Entries Total';
  }

  @override
  String get caseDetailsScreen_noHistoryEntries => 'No history entries yet.';

  @override
  String get caseDetailsScreen_showHistory => 'Show';

  @override
  String get caseDetailsScreen_hideHistory => 'Hide';

  @override
  String caseDetailsScreen_viewAllHistory(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'View All $count History Entries',
      one: 'View All $count History Entry',
    );
    return '$_temp0';
  }

  @override
  String caseDetailsScreen_daysRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Days Remaining',
      one: '1 Day Remaining',
      zero: '0 Days Remaining',
    );
    return '$_temp0';
  }

  @override
  String get caseDetailsScreen_setReminder => 'Set Reminder';

  @override
  String get caseDetailsScreen_editHistoryEntry => 'Edit History Entry';

  @override
  String get caseDetailsScreen_caseNotFound => 'Case not found.';

  @override
  String get caseDetailsScreen_otherInformation => 'Other Information';

  @override
  String get caseDetailsScreen_tenderNumber => 'Tender Number';

  @override
  String get caseDetailsScreen_previousCourtCase => 'Previous Court Case';

  @override
  String get caseDetailsScreen_districtOfOrigin => 'District of Origin';

  @override
  String get disposedCasesScreen_title => 'Disposed Cases';

  @override
  String get caseCard_disposed => 'Disposed:';

  @override
  String get disposedCasesScreen_helpTitle => 'How to set a case as disposed?';

  @override
  String get disposedCasesScreen_helpBody =>
      'During updating date, choose an appropriate step from the followings to move a disposed or inactive lower-court case from the Active Cases list to this list. For Appellate & High Court Division cases, enter a disposal keyword in the Result field instead. Note: The case will remain available in the All Cases list.';

  @override
  String get disposedCasesScreen_disposedSteps =>
      'Disposed steps by court category';

  @override
  String get disposedCasesScreen_appellateHighCourtDivision =>
      'Appellate Division & High Court Division';

  @override
  String get disposedCasesScreen_gotIt => 'Got it';

  @override
  String get activeCasesScreen_title => 'Active Cases';

  @override
  String get notesScreen_title => 'Notes';

  @override
  String get notesScreen_delete => 'Delete';

  @override
  String get notesScreen_pin => 'Pin';

  @override
  String get notesScreen_modified => 'Modified';

  @override
  String get notesScreen_empty => 'No notes yet. Tap + to add one.';

  @override
  String get notesScreen_noteTitle => 'Title';

  @override
  String get notesScreen_noteBody => 'Note';

  @override
  String get notesScreen_noteBodyPlaceholder => 'Enter your note here...';

  @override
  String get notesScreen_drafting => 'Drafting...';

  @override
  String get notesScreen_noteDeleted => 'Note deleted';

  @override
  String get notesScreen_undo => 'Undo';

  @override
  String get caseReferenceScreen_title => 'Case Reference';

  @override
  String get caseReferenceScreen_referenceAndPageNo => 'Reference & Page No';

  @override
  String get caseReferenceScreen_statute => 'Statute';

  @override
  String get caseReferenceScreen_sectionOrArticle => 'Section/Article';

  @override
  String get caseReferenceScreen_titleAndDescription => 'Title & Description';

  @override
  String get caseReferenceScreen_commentsNotes => 'Comments/Notes';

  @override
  String get caseReferenceScreen_empty =>
      'No references yet. Tap + to add one.';

  @override
  String get caseReferenceScreen_addTitle => 'Add Case Reference';

  @override
  String get caseReferenceScreen_editTitle => 'Edit Case Reference';

  @override
  String get caseReferenceScreen_pin => 'Pin';

  @override
  String get caseReferenceScreen_unpin => 'Unpin';

  @override
  String get caseReferenceScreen_saved => 'Reference saved';

  @override
  String get caseReferenceScreen_saveTitle => 'Save Reference';

  @override
  String get caseReferenceScreen_deleted => 'Reference deleted';

  @override
  String get caseReferenceScreen_referenceDeleted => 'Reference deleted';

  @override
  String get caseReferenceScreen_undo => 'Undo';

  @override
  String get caseReferenceScreen_refPlaceholder => 'e.g. 25 DLR (AD) 142';

  @override
  String get caseReferenceScreen_statutePlaceholder => 'e.g. CRPC';

  @override
  String get caseReferenceScreen_sectionPlaceholder => 'e.g. Section 54';

  @override
  String get caseReferenceScreen_titlePlaceholder => 'Title & description';

  @override
  String get caseReferenceScreen_commentsPlaceholder =>
      'Add comments or private notes here...';

  @override
  String get addEditCaseSheet_title => 'Add Case';

  @override
  String get addEditCaseSheet_editTitle => 'Edit Case';

  @override
  String get addEditCaseSheet_higherOrLowerCourt => 'Higher or Lower Court';

  @override
  String get addEditCaseSheet_division => 'Division';

  @override
  String get addEditCaseSheet_district => 'District';

  @override
  String get addEditCaseSheet_courtCategory => 'Court Category';

  @override
  String get addEditCaseSheet_nameOfCourt => 'Name of Court';

  @override
  String get addEditCaseSheet_honorableJudges => 'Name of Honorable Judges\'';

  @override
  String get addEditCaseSheet_caseCategory => 'Case Category';

  @override
  String get addEditCaseSheet_caseNumber => 'Case Number';

  @override
  String get addEditCaseSheet_tenderNumber => 'Tender Number';

  @override
  String get addEditCaseSheet_previousCourtCase => 'Previous Court Case';

  @override
  String get addEditCaseSheet_districtOfOrigin => 'District of Origin';

  @override
  String get addEditCaseSheet_petitioner => 'Petitioner';

  @override
  String get addEditCaseSheet_respondent => 'Respondent';

  @override
  String get addEditCaseSheet_petitionerLeadCounsel =>
      'Petitioner Lead Counsel';

  @override
  String get addEditCaseSheet_respondentLeadCounsel =>
      'Respondent Lead Counsel';

  @override
  String get addEditCaseSheet_onBehalf => 'On Behalf';

  @override
  String get addEditCaseSheet_partyPhone => 'Party Phone No.';

  @override
  String get addEditCaseSheet_year => 'Year';

  @override
  String get addEditCaseSheet_caseTitleAndSection => 'Case Title or Section';

  @override
  String get addEditCaseSheet_caseRemarks => 'Case Remarks';

  @override
  String get addEditCaseSheet_nextDate => 'Next Date';

  @override
  String get quickUpdateCase_currentNextDate => 'Current Next Date';

  @override
  String get addEditCaseSheet_pickDate => 'Pick a date';

  @override
  String get addEditCaseSheet_notification => 'Notification';

  @override
  String get addEditCaseSheet_dayOffset => 'Day Offset';

  @override
  String get addEditCaseSheet_offsetSameDay => 'The same day';

  @override
  String get addEditCaseSheet_offsetDayBefore => 'The day before';

  @override
  String addEditCaseSheet_offsetDaysBefore(Object count) {
    return 'Before $count days';
  }

  @override
  String get addEditCaseSheet_step => 'Step';

  @override
  String get addEditCaseSheet_result => 'Result';

  @override
  String get addEditCaseSheet_note => 'Note';

  @override
  String get addEditCaseSheet_save => 'Save';

  @override
  String get addEditCaseSheet_sectionCourt => 'Court & Case';

  @override
  String get addEditCaseSheet_sectionParties => 'Parties';

  @override
  String get addEditCaseSheet_sectionDetails => 'Case Title & Remarks';

  @override
  String get addEditCaseSheet_sectionSchedule => 'Next Date & Steps';

  @override
  String addEditCaseSheet_dependencyRequired(String field) {
    return 'Please select an option from $field first.';
  }

  @override
  String get customDropdown_clear => 'Clear';

  @override
  String get customDropdown_selected => 'Selected';

  @override
  String get settingsScreen_title => 'Settings';

  @override
  String get settingsScreen_accountAndProfile => 'Account & Profile';

  @override
  String get settingsScreen_profile => 'Profile';

  @override
  String get settingsScreen_manageAccount => 'Manage Account';

  @override
  String get settingsScreen_onlineSync => 'Online Sync';

  @override
  String get settingsScreen_backupAndRestore => 'Backup & Restore';

  @override
  String get settingsScreen_editCourtSteps => 'Edit Court/Steps';

  @override
  String get settingsScreen_notifications => 'Notifications';

  @override
  String get settingsScreen_language => 'Language';

  @override
  String get settingsScreen_languageEnglish => 'English';

  @override
  String get settingsScreen_languageBengali => 'Bengali';

  @override
  String get settingsScreen_viewSettings => 'View Settings';

  @override
  String get settingsScreen_guidelines => 'Guidelines';

  @override
  String get settingsScreen_about => 'About';

  @override
  String get settingsProfile_title => 'Profile';

  @override
  String get settingsManageAccount_title => 'Manage Account';

  @override
  String get settingsOnlineSync_title => 'Online Sync';

  @override
  String get settingsBackupRestore_title => 'Backup & Restore';

  @override
  String get settingsNotifications_title => 'Notifications';

  @override
  String get settingsViewSettings_title => 'View Settings';

  @override
  String get settingsGuidelines_title => 'Guidelines';

  @override
  String get settingsAbout_title => 'About';

  @override
  String get sharedActions_save => 'Save';

  @override
  String get sharedActions_cancel => 'Cancel';

  @override
  String get sharedActions_delete => 'Delete';

  @override
  String get sharedActions_edit => 'Edit';

  @override
  String get sharedActions_search => 'Search';

  @override
  String get sharedActions_add => 'Add';

  @override
  String get sharedActions_update => 'Update';

  @override
  String get sharedActions_close => 'Close';

  @override
  String get sharedActions_yes => 'Yes';

  @override
  String get sharedActions_no => 'No';

  @override
  String get sharedDialogs_confirmDeleteTitle => 'Confirm Delete';

  @override
  String get sharedDialogs_confirmDeleteMessage =>
      'Are you sure you want to delete this item?';

  @override
  String get sharedDialogs_noResults => 'No results found.';

  @override
  String get sharedDialogs_requiredField => 'This field is required.';

  @override
  String get sharedDialogs_ok => 'OK';

  @override
  String get sharedDialogs_cancel => 'Cancel';

  @override
  String get courtCategory_appellateDivision => 'Appellate Division';

  @override
  String get courtCategory_highCourtDivision => 'High Court Division';

  @override
  String get courtCategory_lowerDivisionalCourts => 'Lower Divisional Courts';

  @override
  String get lowerCourtCategory_districtSessionsCriminal =>
      'Sessions Judge Court (Criminal)';

  @override
  String get lowerCourtCategory_districtCourtsCivil =>
      'District Judge Court (Civil)';

  @override
  String get lowerCourtCategory_metropolitanSessionsJudgeCriminal =>
      'Metropolitan Sessions Judge Court (Criminal)';

  @override
  String get lowerCourtCategory_chiefJudicialMagistrate =>
      'Chief Judicial Magistrate Court';

  @override
  String get lowerCourtCategory_chiefMetropolitanMagistrate =>
      'Chief Metropolitan Magistrate Court';

  @override
  String get lowerCourtCategory_executiveMagistrate =>
      'Executive Magistrate & Other Courts';

  @override
  String get lowerCourtCategory_tribunals => 'Tribunals';

  @override
  String get onBehalf_plaintiff => 'Plaintiff';

  @override
  String get onBehalf_defendant => 'Defendant';

  @override
  String get onBehalf_accused => 'Accused';

  @override
  String get onBehalf_appellant => 'Appellant';

  @override
  String get onBehalf_petitioner => 'Petitioner';

  @override
  String get onBehalf_respondent => 'Respondent';

  @override
  String get onBehalf_writPetitioner => 'Writ Petitioner';

  @override
  String get onBehalf_state => 'State';

  @override
  String get onBehalf_victim => 'Victim';

  @override
  String get onBehalf_complainant => 'Complainant';

  @override
  String get onBehalf_informant => 'Informant';

  @override
  String get onBehalf_applicant => 'Applicant';

  @override
  String get onBehalf_claimant => 'Claimant';

  @override
  String get onBehalf_objector => 'Objector';

  @override
  String get caseType_civil => 'Civil';

  @override
  String get caseType_criminal => 'Criminal';

  @override
  String get caseType_writ => 'Writ';

  @override
  String get caseType_appeal => 'Appeal';

  @override
  String get caseType_revision => 'Revision';

  @override
  String get step_filed => 'Filed';

  @override
  String get step_hearing => 'Hearing';

  @override
  String get step_disposed => 'Disposed';

  @override
  String get step_pending => 'Pending';

  @override
  String get division_dhaka => 'Dhaka';

  @override
  String get division_chattagram => 'Chittagong';

  @override
  String get division_rajshahi => 'Rajshahi';

  @override
  String get division_khulna => 'Khulna';

  @override
  String get division_barishal => 'Barishal';

  @override
  String get division_sylhet => 'Sylhet';

  @override
  String get division_rangpur => 'Rangpur';

  @override
  String get division_mymensingh => 'Mymensingh';

  @override
  String messageTemplate_clientSms(
    String clientName,
    String caseNumber,
    String nextDate,
  ) {
    return 'Dear $clientName, your case $caseNumber is scheduled for hearing on $nextDate. Please contact us if you have any questions.';
  }

  @override
  String messageTemplate_clientWhatsApp(
    String clientName,
    String caseNumber,
    String nextDate,
  ) {
    return 'Dear $clientName, your case $caseNumber is scheduled for hearing on $nextDate. Please contact us if you have any questions.';
  }

  @override
  String get localeScratch_title => 'Localization Scratch';

  @override
  String get localeScratch_greeting => 'Hello';

  @override
  String get localeScratch_englishSample => 'This text is in English.';

  @override
  String get localeScratch_bengaliSample => 'এই টেক্সটি বাংলায়।';

  @override
  String localeScratch_currentLanguage(String language) {
    return 'Current language: $language';
  }

  @override
  String get nav_upcomingCases => 'Upcoming Cases';

  @override
  String get nav_dailyCauseList => 'Daily Cause List';

  @override
  String get nav_allCases => 'All Cases';

  @override
  String get nav_disposedCases => 'Disposed Cases';

  @override
  String get nav_caseReference => 'Case Reference';

  @override
  String get nav_notes => 'Notes';

  @override
  String get nav_settings => 'Settings';

  @override
  String get nav_print => 'Print';

  @override
  String get nav_share => 'Share';

  @override
  String get nav_activeCases => 'Active Cases';

  @override
  String get nav_overdueDates => 'Overdue Dates';

  @override
  String get sync_idle => 'Sync';

  @override
  String get sync_syncing => 'Syncing…';

  @override
  String get sync_success => 'Synced';

  @override
  String get sync_paused => 'Sync paused';

  @override
  String get sync_error => 'Sync error';

  @override
  String get sync_unavailable => 'Sync requires a premium subscription';

  @override
  String get casesModal_addCase => 'Add Case';

  @override
  String get casesModal_search => 'Search';

  @override
  String get casesModal_viewCompact => 'Compact view';

  @override
  String get casesModal_viewExpanded => 'Expanded view';

  @override
  String get casesModal_help => 'Help';

  @override
  String get customDropdown_selectOption => 'Select an option';

  @override
  String get customDropdown_search => 'Search';

  @override
  String get customDropdown_noResults => 'No results found';

  @override
  String get customDropdown_done => 'Done';
}
