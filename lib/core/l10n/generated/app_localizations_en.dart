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
  String get caseCard_disposed => 'Disposed:';

  @override
  String get caseTable_serial => 'Serial';

  @override
  String get caseTable_disposed => 'Disposed';

  @override
  String get activeCasesScreen_title => 'Active Cases';

  @override
  String get upcomingCasesScreen_title => 'Upcoming Cases';

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
  String get disposedCasesScreen_title => 'Disposed Cases';

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
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString Entries Total';
  }

  @override
  String get caseDetailsScreen_noHistoryEntries => 'No history entries yet.';

  @override
  String get caseDetailsScreen_showHistory => 'Show';

  @override
  String get caseDetailsScreen_hideHistory => 'Hide';

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
  String caseDetailsScreen_deleteCaseError(String message) {
    return 'Unable to delete the case: $message';
  }

  @override
  String caseDetailsScreen_deleteHistoryError(String message) {
    return 'Unable to delete the history entry: $message';
  }

  @override
  String caseDetailsScreen_loadError(String message) {
    return 'Unable to load the case: $message';
  }

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

  @override
  String get casesContact_openWith => 'Open with';

  @override
  String get casesContact_whatsapp => 'WhatsApp';

  @override
  String get casesContact_message => 'Message';

  @override
  String get casesContact_phone => 'Phone';

  @override
  String get casesContact_whatsappNote =>
      'Opens the chat — start the call from there.';

  @override
  String casesContact_noNumber(String party) {
    return 'No number saved for the $party.';
  }

  @override
  String get casesContact_unableToOpenApp => 'Unable to open the app.';

  @override
  String get casesContact_unableToOpenWhatsApp => 'Unable to open WhatsApp.';

  @override
  String get casesContact_unableToCall => 'Unable to place a call.';

  @override
  String get casesContact_unableToMessage => 'Unable to open messages.';

  @override
  String casesScreen_loadError(String message) {
    return 'Unable to load cases: $message';
  }

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
  String get paywall_title => 'Premium';

  @override
  String get paywall_limitTitle => 'Free plan limit reached';

  @override
  String paywall_limitBody(String limit) {
    return 'The free plan holds up to $limit cases. Deleting a case frees a slot, and everything else — Client Management, the Daily Cause List, editing and printing — stays free.';
  }

  @override
  String get paywall_benefitsTitle => 'Premium includes';

  @override
  String get paywall_benefitUnlimitedCases => 'Unlimited cases';

  @override
  String get paywall_benefitCloudBackup => 'Secure encrypted cloud backup';

  @override
  String get paywall_benefitMultiDevice =>
      'Your diary on every device you sign in on';

  @override
  String get paywall_benefitFirmMode => 'Firm mode for your associates';

  @override
  String get paywall_plansTitle => 'Plans';

  @override
  String get paywall_planMonthly => 'Monthly';

  @override
  String paywall_planMonthlyPrice(String price) {
    return '৳$price per month';
  }

  @override
  String get paywall_planAnnual => 'Annual';

  @override
  String paywall_planAnnualPrice(String price) {
    return '৳$price per year';
  }

  @override
  String get paywall_comingSoon => 'Coming soon';

  @override
  String get paywall_note =>
      'Subscriptions are not available yet. This screen shows what premium will include and what each plan will cost.';

  @override
  String get general_tomorrow => 'Tomorrow';

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
  String sharedMessages_error(String message) {
    return 'Error: $message';
  }

  @override
  String get sharedMessages_signInRequired =>
      'Available after sign-in (Task 17)';

  @override
  String get appShell_exitTitle => 'Exit App?';

  @override
  String get appShell_exitMessage => 'Do you want to exit Legal Case Diary?';

  @override
  String get appShell_exit => 'Exit';

  @override
  String get databaseRecovery_title => 'Database Locked';

  @override
  String get databaseRecovery_body =>
      'The encryption key for your local case diary is missing. This can happen after an operating system update or if app data was cleared.\n\nTo continue using the app offline, you must reset the local database. All unsynced local data will be lost.';

  @override
  String get databaseRecovery_reset => 'Reset Local Database';

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
    String court,
    String lawyerName,
  ) {
    return 'Dear $clientName, your case $caseNumber is scheduled for hearing on $nextDate at $court. - $lawyerName';
  }

  @override
  String messageTemplate_clientWhatsApp(
    String clientName,
    String caseNumber,
    String nextDate,
    String court,
    String lawyerName,
  ) {
    return 'Dear $clientName, your case $caseNumber is scheduled for hearing on $nextDate at $court. - $lawyerName';
  }

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
  String get settingsScreen_viewSettings => 'View Settings';

  @override
  String get settingsScreen_guidelines => 'Guidelines & FAQs';

  @override
  String get settingsScreen_about => 'About';

  @override
  String get settingsScreen_sectionGeneral => 'General';

  @override
  String get settingsScreen_sectionPreferences => 'Preferences';

  @override
  String get settingsScreen_sectionAppInfo => 'App Info';

  @override
  String get settingsScreen_searchTooltip => 'Search settings';

  @override
  String get settingsScreen_searchHint => 'Search';

  @override
  String get settingsScreen_closeSearchTooltip => 'Close search';

  @override
  String get settingsScreen_noResults => 'No settings found';

  @override
  String get settingsScreen_languageEnglish => 'English';

  @override
  String get settingsScreen_languageBengali => 'বাংলা';

  @override
  String get settingsLanguage_selectHeading => 'Select App Language';

  @override
  String get settingsLanguage_intro =>
      'Every label, date and message in the app will use the language you pick here.';

  @override
  String get settingsLanguage_previewTitle => 'Today\'s Date in This Language';

  @override
  String get settingsLanguage_selected => 'Selected';

  @override
  String get settingsLanguage_note =>
      'This changes only the app\'s interface. Your saved cases and notes stay exactly as they are.';

  @override
  String get settingsAccountProfile_profileSubtitle =>
      'Your name, bar association, and membership details';

  @override
  String get settingsAccountProfile_manageAccountSubtitle =>
      'Password, subscription, and account settings';

  @override
  String get settingsProfile_title => 'Profile';

  @override
  String get settingsProfile_editTooltip => 'Edit profile';

  @override
  String get settingsProfile_fullName => 'Full Name';

  @override
  String get settingsProfile_barAssociation => 'Bar Association';

  @override
  String get settingsProfile_membershipNo => 'Membership No.';

  @override
  String get settingsProfile_officeAddress => 'Office Address';

  @override
  String get settingsProfile_mobileNo => 'Mobile No.';

  @override
  String get settingsProfile_yourName => 'Your Name';

  @override
  String settingsProfile_displayName(String name) {
    return 'Adv. $name';
  }

  @override
  String get settingsProfile_editTitle => 'Edit Profile';

  @override
  String get settingsProfile_fullNameHint => 'Enter your full name';

  @override
  String get settingsProfile_barAssociationHint => 'Enter bar association name';

  @override
  String get settingsProfile_membershipNoHint => 'Enter registration number';

  @override
  String get settingsProfile_officeAddressHint => 'Enter your office address';

  @override
  String get settingsProfile_save => 'Save Profile';

  @override
  String get settingsProfile_saved => 'Profile saved (offline)';

  @override
  String get settingsManageAccount_title => 'Manage Account';

  @override
  String get settingsManageAccount_changePassword => 'Change Password';

  @override
  String get settingsManageAccount_subscriptionDetails =>
      'Subscription Details';

  @override
  String get settingsManageAccount_purchaseNewSubscription =>
      'Purchase New Subscription';

  @override
  String get settingsManageAccount_logout => 'Logout';

  @override
  String get settingsManageAccount_accountSettings => 'Account Settings';

  @override
  String get settingsManageAccount_deleteAccount => 'Delete Account';

  @override
  String get settingsManageAccount_deleteCannotBeUndone =>
      'This action cannot be undone';

  @override
  String get settingsOnlineSync_title => 'Online Sync';

  @override
  String get settingsOnlineSync_subtitle =>
      'Manage your real-time data sync across all your devices.';

  @override
  String get settingsOnlineSync_cases => 'Cases';

  @override
  String get settingsOnlineSync_notes => 'Notes';

  @override
  String get settingsOnlineSync_references => 'References';

  @override
  String get settingsOnlineSync_notSignedIn => 'Not signed in';

  @override
  String get settingsOnlineSync_signInPrompt =>
      'Sign in to sync your data across all your devices';

  @override
  String get settingsOnlineSync_actionRequired => 'Action Required';

  @override
  String get settingsOnlineSync_lastSyncNever => 'Last Sync: Never';

  @override
  String get settingsOnlineSync_dataStaysOnDevice =>
      'Your data stays on this device until you sign in.';

  @override
  String get settingsOnlineSync_syncNow => 'Sync Now';

  @override
  String get settingsOnlineSync_notSynced => 'Not synced';

  @override
  String get settingsOnlineSync_itemsUnknown => '— Items';

  @override
  String settingsOnlineSync_itemsCount(int count) {
    return '$count Items';
  }

  @override
  String get settingsBackupRestore_title => 'Backup & Restore';

  @override
  String get settingsBackupRestore_sectionBackup => 'Backup & Restore';

  @override
  String get settingsBackupRestore_sectionAutomaticBackup => 'Automatic Backup';

  @override
  String get settingsBackupRestore_sectionStatus => 'Backup Status';

  @override
  String get settingsBackupRestore_backupLocal => 'Backup to Local Storage';

  @override
  String get settingsBackupRestore_backupDrive => 'Backup to Google Drive';

  @override
  String get settingsBackupRestore_restore => 'Restore from backup';

  @override
  String get settingsBackupRestore_encryptionNote =>
      'Backups are encrypted and stored in your local storage or cloud provider. Restoration will overwrite current data.';

  @override
  String get settingsBackupRestore_offlineNote =>
      'Note: Restoration is available for offline accounts only.';

  @override
  String get settingsBackupRestore_lastSuccessfulBackup =>
      'Last successful backup';

  @override
  String get settingsBackupRestore_lastBackupPlaceholder =>
      'No backup has been made yet.';

  @override
  String get backupNudge_message =>
      'You have not backed up this month. Your cases live only on this phone — save a backup to keep them safe.';

  @override
  String get backupNudge_action => 'Back up to local storage';

  @override
  String get backupNudge_dismiss => 'Dismiss for this month';

  @override
  String get settingsBackupRestore_driveShareTitle => 'Send to Google Drive?';

  @override
  String get settingsBackupRestore_driveShareBody =>
      'Your backup is saved. Send it to Google Drive from the share sheet.';

  @override
  String get settingsBackupRestore_driveShareSend => 'Send';

  @override
  String get settingsBackupRestore_driveShareNotNow => 'Not now';

  @override
  String get settingsBackupRestore_shareFailed =>
      'Could not open the share sheet.';

  @override
  String get settingsBackupRestore_shareSubject => 'Legal Case Diary backup';

  @override
  String get settingsBackupRestore_scheduleOff => 'Off';

  @override
  String get settingsBackupRestore_scheduleEveryday => 'Everyday';

  @override
  String get settingsBackupRestore_scheduleEvery3Days => 'Every 3 days';

  @override
  String get settingsBackupRestore_scheduleEvery7Days => 'Every 7 days';

  @override
  String get settingsBackupRestore_scheduleEveryMonth => 'Every month';

  @override
  String get settingsBackupRestore_passphraseTitle => 'Protect this backup';

  @override
  String get settingsBackupRestore_passphraseBody =>
      'The backup is encrypted with this passphrase. It is not stored anywhere, so without it the file can never be restored.';

  @override
  String get settingsBackupRestore_passphraseLabel => 'Passphrase';

  @override
  String get settingsBackupRestore_passphraseConfirmLabel =>
      'Confirm passphrase';

  @override
  String get settingsBackupRestore_passphraseRequired => 'Enter a passphrase.';

  @override
  String get settingsBackupRestore_passphraseMismatch =>
      'The two passphrases do not match.';

  @override
  String get settingsBackupRestore_encryptAndSave => 'Encrypt and save';

  @override
  String get settingsBackupRestore_recoveryPassphraseTitle =>
      'Open this backup';

  @override
  String get settingsBackupRestore_recoveryPassphraseBody =>
      'Enter the passphrase this backup was created with.';

  @override
  String get settingsBackupRestore_recoveryPassphraseHint =>
      'A backup made before encryption was added opens without a passphrase.';

  @override
  String get settingsBackupRestore_openBackup => 'Open backup';

  @override
  String get settingsBackupRestore_backupProgress => 'Creating your backup…';

  @override
  String get settingsBackupRestore_restoreProgress => 'Restoring your data…';

  @override
  String settingsBackupRestore_backupSaved(String path) {
    return 'Backup saved to $path';
  }

  @override
  String get settingsBackupRestore_backupFailed =>
      'Could not create the backup.';

  @override
  String get settingsBackupRestore_restoreDetailsTitle =>
      'Replace all current data?';

  @override
  String get settingsBackupRestore_restoreDetailsBackedUp => 'Backed up';

  @override
  String get settingsBackupRestore_restoreDetailsAppVersion => 'App version';

  @override
  String get settingsBackupRestore_restoreDetailsRecords => 'Records';

  @override
  String get settingsBackupRestore_restoreDetailsWarning =>
      'Everything currently on this device will be replaced. This cannot be undone.';

  @override
  String get settingsBackupRestore_restoreReplace => 'Replace';

  @override
  String get settingsBackupRestore_restoreCompleteTitle => 'Restore complete';

  @override
  String settingsBackupRestore_restoreCompleteBody(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString records restored.';
  }

  @override
  String get settingsBackupRestore_restoreCompleteNote =>
      'The app will now reload your data.';

  @override
  String get settingsBackupRestore_errorInvalidFile =>
      'That file is not a backup made by this app.';

  @override
  String get settingsBackupRestore_errorUnsupportedVersion =>
      'This backup was made by a newer version of the app.';

  @override
  String get settingsBackupRestore_errorWrongSecret =>
      'Wrong passphrase, or the backup file has been changed.';

  @override
  String get settingsBackupRestore_errorDamaged =>
      'The backup file is damaged and cannot be restored.';

  @override
  String get settingsBackupRestore_errorConflict =>
      'The app gained new data while restoring, so nothing was changed.';

  @override
  String get settingsBackupRestore_errorImportFailed =>
      'The restore failed. Your existing data was left unchanged.';

  @override
  String get settingsBackupRestore_errorOpenFile => 'Could not open that file.';

  @override
  String get settingsEditCourtSteps_editItemTypes =>
      'Edit Case Types, Step etc';

  @override
  String get settingsEditCourtSteps_editItemTypesSubtitle =>
      'Manage case types, procedural steps, and on-behalf roles';

  @override
  String get settingsEditCourtSteps_courtNamesCategories => 'Edit Court Names';

  @override
  String get settingsEditCourtSteps_courtNamesCategoriesSubtitle =>
      'Supreme Court divisions and district lower courts';

  @override
  String get settingsEditCourtSteps_lowerCourtCategories =>
      'Edit Lower Court Categories';

  @override
  String get settingsEditCourtSteps_lowerCourtCategoriesSubtitle =>
      'Divisions, districts and their court categories';

  @override
  String get settingsEditCourtNames_courtCategory => 'Edit Court Names';

  @override
  String get settingsEditCourtNames_lowerCourts => 'Lower Courts';

  @override
  String get settingsEditCourtNames_lowerCourtsSubtitle =>
      'District, Session & Specialized Courts';

  @override
  String get settingsEditCourtNames_quickTip => 'Quick Tip';

  @override
  String get settingsEditCourtNames_quickTipBody =>
      'Need specialized tribunals? Add them under the relevant division and district, then assign a court category.';

  @override
  String get settingsEditItems_caseTypes => 'Case Types';

  @override
  String get settingsEditItems_steps => 'Steps';

  @override
  String get settingsEditItems_onBehalf => 'On Behalf';

  @override
  String get settingsCourtNamesSteps_title => 'Court Names, Steps etc';

  @override
  String get settingsCourtNamesSteps_catAppellateDivision =>
      'Appellate Division';

  @override
  String get settingsCourtNamesSteps_catHighCourtDivision =>
      'High Court Division';

  @override
  String get settingsCourtNamesSteps_catDistrictSessions =>
      'District & Sessions (Criminal)';

  @override
  String get settingsCourtNamesSteps_catDistrictCivil =>
      'District Courts (Civil)';

  @override
  String get settingsCourtNamesSteps_catCjm => 'Chief Judicial Magistrate';

  @override
  String get settingsCourtNamesSteps_catCmm => 'Chief Metropolitan Magistrate';

  @override
  String get settingsCourtNamesSteps_catExecutive => 'Executive Magistrate';

  @override
  String get settingsCourtNamesSteps_catMetropolitanSessions =>
      'Metropolitan Sessions (Criminal)';

  @override
  String get settingsItemList_addTitle => 'Add Item';

  @override
  String get settingsItemList_editTitle => 'Edit Item';

  @override
  String get settingsItemList_nameLabel => 'Name';

  @override
  String get settingsItemList_empty => 'No items yet. Add one below.';

  @override
  String get settingsItemList_deleteTitle => 'Delete Item';

  @override
  String get settingsItemList_deleteMessage =>
      'Delete this item? This cannot be undone.';

  @override
  String get settingsItemList_catAppellate => 'Appellate';

  @override
  String get settingsItemList_catHighCourt => 'High Court';

  @override
  String get settingsItemList_catSessions => 'Sessions (Crim)';

  @override
  String get settingsItemList_catDistrictCivil => 'District (Civil)';

  @override
  String get settingsItemList_catMetropolitanSessions =>
      'Metro Sessions (Crim)';

  @override
  String get settingsItemList_catCjm => 'CJM';

  @override
  String get settingsItemList_catCmm => 'CMM';

  @override
  String get settingsItemList_catExecutive => 'Executive';

  @override
  String get settingsItemList_catTribunals => 'Tribunals';

  @override
  String get settingsCourtList_addTitle => 'Add Court';

  @override
  String get settingsCourtList_editTitle => 'Edit Court';

  @override
  String get settingsCourtList_nameLabel => 'Court name';

  @override
  String get settingsCourtList_titleHigher => 'Court Names';

  @override
  String get settingsCourtList_empty => 'No courts yet. Add one below.';

  @override
  String get settingsCourtList_deleteTitle => 'Delete Court';

  @override
  String settingsCourtList_deleteMessage(String name) {
    return 'Delete \"$name\"? This cannot be undone.';
  }

  @override
  String settingsCourtList_titleLower(String district) {
    return '$district Court Names';
  }

  @override
  String get settingsCourtFlow_divisions => 'Divisions';

  @override
  String get settingsCourtFlow_districts => 'Districts';

  @override
  String get settingsLowerCourtCategories_addTooltip => 'Add Court Category';

  @override
  String get settingsLowerCourtCategories_addTitle => 'Add Court Category';

  @override
  String get settingsLowerCourtCategories_editTitle => 'Edit Court Category';

  @override
  String get settingsLowerCourtCategories_nameLabel => 'Category name';

  @override
  String get settingsLowerCourtCategories_empty =>
      'No court categories in this district yet.';

  @override
  String settingsCourtFlow_divisionTitle(String division) {
    return '$division Division';
  }

  @override
  String settingsLowerCourtCategories_title(String district) {
    return '$district Court Categories';
  }

  @override
  String get settingsNotifications_title => 'Notifications';

  @override
  String get settingsNotifications_statusLabel => 'Default Notification Status';

  @override
  String get settingsNotifications_on => 'On';

  @override
  String get settingsNotifications_off => 'Off';

  @override
  String get settingsNotifications_dayOffsetLabel => 'Notification Day Offset';

  @override
  String get settingsNotifications_selectDayOffsetTitle => 'Select Day Offset';

  @override
  String get settingsNotifications_offsetSameDay => 'The Same Day';

  @override
  String get settingsNotifications_offsetDayBefore => 'The Day Before';

  @override
  String settingsNotifications_offsetBeforeDays(int days) {
    return 'Before $days Days';
  }

  @override
  String get settingsNotifications_timeLabel => 'Notification Time';

  @override
  String get settingsNotifications_reminderBanner =>
      'Notifications May Not Work Reliably on Your Device. Tap to Complete Setup.';

  @override
  String get settingsNotifications_setupGuide =>
      'Battery & Auto-Start Setup Guide';

  @override
  String get settingsNotifications_setupGuideSubtitle =>
      'Required on Xiaomi, Oppo, Vivo and Realme Phones';

  @override
  String get settingsNotifications_sendTest => 'Send Test Notification';

  @override
  String get settingsNotifications_sendTestSubtitle =>
      'See how a hearing alert looks on this phone';

  @override
  String get settingsNotifications_testSent => 'Test Notification Sent';

  @override
  String get settingsNotifications_testFailed =>
      'Could Not Show a Notification. Check the App\'s Notification Permission.';

  @override
  String get notificationJob_channelName => 'Hearing Alerts';

  @override
  String get notificationJob_channelDescription =>
      'Daily reminders for your upcoming hearings';

  @override
  String get notificationJob_titleSameDay => 'Hearing Today';

  @override
  String get notificationJob_titleDayBefore => 'Hearing Tomorrow';

  @override
  String notificationJob_titleBeforeDays(String days) {
    return 'Hearing in $days Days';
  }

  @override
  String notificationJob_parties(String petitioner, String respondent) {
    return '$petitioner vs $respondent';
  }

  @override
  String get notificationJob_testTitle => 'Test Notification';

  @override
  String get notificationJob_testBody =>
      'Hearing alerts are working. This is how a hearing reminder will look.';

  @override
  String get settingsBatteryGuide_intro =>
      'Xiaomi, Oppo, Vivo, Realme and similar phones stop background alarms to save battery, so hearing reminders can fail silently. These two or three steps keep them working.';

  @override
  String get settingsBatteryGuide_autoStartTitle => 'Allow Auto-Start';

  @override
  String get settingsBatteryGuide_autoStartBody =>
      'In your phone\'s settings, open Auto-start (or Startup manager) and allow Legal Case Diary to start by itself.';

  @override
  String get settingsBatteryGuide_batteryTitle =>
      'Set Battery Usage to Unrestricted';

  @override
  String get settingsBatteryGuide_batteryBody =>
      'Open Battery then App battery usage (or Battery optimization), choose Legal Case Diary and select Unrestricted / No restrictions.';

  @override
  String get settingsBatteryGuide_exactTitle => 'Allow Exact Alarms';

  @override
  String get settingsBatteryGuide_exactBody =>
      'On Android 12 and newer, allow Alarms & reminders for Legal Case Diary; otherwise the daily reminder can arrive late.';

  @override
  String get settingsBatteryGuide_takeMeThere => 'Take Me There';

  @override
  String get settingsBatteryGuide_exactAllowed =>
      'Exact Alarms Are Already Allowed';

  @override
  String get settingsBatteryGuide_openFailed =>
      'Could Not Open That Settings Page. Please Set It Manually.';

  @override
  String get settingsBatteryGuide_done => 'Done, I\'ve Completed the Steps';

  @override
  String get settingsBatteryGuide_skip => 'Skip for Now';

  @override
  String get settingsBatteryGuide_skipNote =>
      'You can finish this later from Settings → Notifications.';

  @override
  String get settingsViewSettings_title => 'View Settings';

  @override
  String get settingsViewSettings_sectionDisplay => 'Display';

  @override
  String get settingsViewSettings_sectionNavigation => 'Navigation';

  @override
  String get settingsViewSettings_upcomingPeriod => 'Upcoming Cases Period';

  @override
  String settingsViewSettings_days(int days) {
    return '$days Days';
  }

  @override
  String get settingsViewSettings_caseListMode => 'Case List Display';

  @override
  String get settingsViewSettings_caseListCompact => 'Compact';

  @override
  String get settingsViewSettings_caseListExpanded => 'Expanded';

  @override
  String get settingsViewSettings_bottomTabs => 'Bottom Navigation';

  @override
  String settingsViewSettings_bottomTabsCount(int count) {
    return '$count Screens Selected';
  }

  @override
  String get settingsViewSettings_keepOneTab =>
      'Keep at Least One Screen in the Bottom Bar.';

  @override
  String get settingsViewSettings_sideNav => 'Side Navigation Options';

  @override
  String settingsViewSettings_sideNavCount(int shown, int total) {
    return '$shown of $total Sections Shown';
  }

  @override
  String get settingsViewSettings_landingPage => 'Default Landing Page';

  @override
  String get settingsGuidelines_title => 'Guidelines & FAQs';

  @override
  String get settingsGuidelines_intro =>
      'How the app works, and answers to the questions we are asked most often. Tap a card to expand it.';

  @override
  String get settingsGuidelines_sectionGuidelines => 'Guidelines';

  @override
  String get settingsGuidelines_dailyCauseListTitle => 'Daily Cause List';

  @override
  String get settingsGuidelines_dailyCauseListBody1 =>
      'The Daily Cause List shows the hearings you have recorded for a single date, grouped by court in your court hierarchy, with a total for the day. Use the calendar to choose another date; today is selected by default.';

  @override
  String get settingsGuidelines_dailyCauseListBody2 =>
      'The list is built from your own case records, so it is only as accurate as they are. Keep each case\'s next date and latest step current, and record a hearing from the list itself as soon as you leave the courtroom. Cases whose hearing date has passed without an update appear under Overdue Dates until you record the outcome.';

  @override
  String get settingsGuidelines_referencesTitle => 'Case References & Notes';

  @override
  String get settingsGuidelines_referencesBody1 =>
      'Case Reference is your own library of citations, kept separately from any case. For each entry you can record the reference (for example, 25 DLR (AD) 142), the statute and section, a title and description, and private comments. Pin the entries you cite most often to keep them at the top of the list.';

  @override
  String get settingsGuidelines_referencesBody2 =>
      'General notes belong in Notes, which also stands on its own. Both allow you to undo a deletion immediately after making it.';

  @override
  String get settingsGuidelines_backupTitle => 'Offline Backup & Restore';

  @override
  String get settingsGuidelines_backupBody1 =>
      'Your diary lives on this device. In Settings > Backup & Restore, choose Backup to Local Storage to write an encrypted copy to a location you choose — a memory card, a folder on the phone, or anywhere the system file picker can reach. You set a passphrase for the file, and the app never stores or sends it.';

  @override
  String get settingsGuidelines_backupBody2 =>
      'Restore from backup reads a backup file and replaces the contents of the app with the file\'s contents. This cannot be undone, so make a fresh backup before restoring. If no backup has been made in the current month, the app displays a reminder you can dismiss.';

  @override
  String get settingsGuidelines_securityTitle => 'Security & Encryption';

  @override
  String get settingsGuidelines_securityBody1 =>
      'Your case diary is stored on this device in encrypted form. Backup files are encrypted with AES-256-GCM, using a key derived from your passphrase on the device itself with PBKDF2-HMAC-SHA256. Neither the passphrase nor the key is stored or transmitted anywhere.';

  @override
  String get settingsGuidelines_securityBody2 =>
      'In the offline version, nothing leaves your phone unless you send it. Keep your passphrase somewhere safe — where a backup exists but its passphrase is lost, the file cannot be opened by us or by anyone else.';

  @override
  String get settingsGuidelines_sectionFaqs => 'FAQs';

  @override
  String get settingsGuidelines_faqCatGettingStarted => 'Getting started';

  @override
  String get settingsGuidelines_faqCatGettingStartedQ1 =>
      'Does the app work without an internet connection?';

  @override
  String get settingsGuidelines_faqCatGettingStartedA1 =>
      'Yes. The app is built to work fully offline — adding and editing cases, the Daily Cause List, printing and backups all work with no connection. Online sync is not part of the offline version.';

  @override
  String get settingsGuidelines_faqCatGettingStartedQ2 =>
      'How do I add a case?';

  @override
  String get settingsGuidelines_faqCatGettingStartedA2 =>
      'Tap the + button on any cases page. The case is then filed onto the relevant pages automatically, based on the information you enter.';

  @override
  String get settingsGuidelines_faqCatGettingStartedQ3 =>
      'Where does a case appear after I add it?';

  @override
  String get settingsGuidelines_faqCatGettingStartedA3 =>
      'A case appears on more than one page, each answering a different question: Active Cases lists everything still running; Upcoming Cases lists hearings within your chosen period; Daily Cause List shows the hearings for one date; All Cases is the full list with sorting and court filtering; Overdue Dates shows cases whose hearing date has passed without an update; and Disposed Cases holds cases you have marked as disposed.';

  @override
  String get settingsGuidelines_faqCatGettingStartedQ4 =>
      'What is the difference between updating a case and editing a case?';

  @override
  String get settingsGuidelines_faqCatGettingStartedA4 =>
      'Update records a new step or result and adds it to the case\'s history — use it after each hearing. Edit Case changes the case\'s own details, such as the parties, court or case number — use it to correct recorded information.';

  @override
  String get settingsGuidelines_faqCatGettingStartedQ5 =>
      'How do I mark a case as disposed?';

  @override
  String get settingsGuidelines_faqCatGettingStartedA5 =>
      'Open the case in the Update screen or the Edit Case form and select নিষ্পত্তি (Disposed). For Appellate Division and High Court Division cases you can also type \"Disposed\" or \"নিষ্পত্তি\". The case then moves from Active Cases to Disposed Cases.';

  @override
  String get settingsGuidelines_faqCatGettingStartedQ6 =>
      'How do I move a case back to Active Cases?';

  @override
  String get settingsGuidelines_faqCatGettingStartedA6 =>
      'Open the case and choose any step or result other than নিষ্পত্তি (Disposed). The case returns to Active Cases.';

  @override
  String get settingsGuidelines_faqCatGettingStartedQ7 =>
      'What happens when I delete a case?';

  @override
  String get settingsGuidelines_faqCatGettingStartedA7 =>
      'The case is removed from your diary and frees a slot on the free plan. Deletion cannot be undone, so delete only cases you no longer need a record of. Notes and case references, by contrast, can be undone immediately after deleting.';

  @override
  String get settingsGuidelines_faqCatGettingStartedQ8 =>
      'What is the Overdue Dates page?';

  @override
  String get settingsGuidelines_faqCatGettingStartedA8 =>
      'It lists cases whose hearing date has passed without a recorded outcome, with the date they were last updated. It is the fastest way to find matters you have not yet caught up on. Recording a new step or result removes the case from the list.';

  @override
  String get settingsGuidelines_faqCatFindingCases =>
      'Finding and viewing cases';

  @override
  String get settingsGuidelines_faqCatFindingCasesQ1 =>
      'I added a case but can\'t find it with search.';

  @override
  String get settingsGuidelines_faqCatFindingCasesA1 =>
      'Search matches the script you entered. A case recorded in English is found with an English query, and a case recorded in Bengali with a Bengali query. A Bengali case number will not match an English search, and vice versa.';

  @override
  String get settingsGuidelines_faqCatFindingCasesQ2 =>
      'How far ahead does the Upcoming Cases list show hearings?';

  @override
  String get settingsGuidelines_faqCatFindingCasesA2 =>
      'By default, the next 7 days. To change this, go to Settings > View Settings > Upcoming Cases Period.';

  @override
  String get settingsGuidelines_faqCatFindingCasesQ3 =>
      'Can I change how cases are displayed?';

  @override
  String get settingsGuidelines_faqCatFindingCasesA3 =>
      'The default compact view uses cards to fit as much information as possible into as little space as possible. Switch to extended view using the toggle beside the search field on the Cases screen, or in Settings > View Settings > Case List View.';

  @override
  String get settingsGuidelines_faqCatFindingCasesQ4 =>
      'What does the Daily Cause List show?';

  @override
  String get settingsGuidelines_faqCatFindingCasesA4 =>
      'The hearings recorded in your diary for one date, grouped by court in your court hierarchy, with a total for the day. Choose the date from the calendar; today is selected by default.';

  @override
  String get settingsGuidelines_faqCatNotesAndPrinting =>
      'Notes, references and printing';

  @override
  String get settingsGuidelines_faqCatNotesAndPrintingQ1 =>
      'What is the difference between Notes and Case References?';

  @override
  String get settingsGuidelines_faqCatNotesAndPrintingA1 =>
      'Notes holds free-form notes with a title and body. Case Reference is a structured library of citations — reference, statute, section, description and private comments — which you can pin. Both are separate from your cases and neither is linked to one automatically.';

  @override
  String get settingsGuidelines_faqCatNotesAndPrintingQ2 => 'What can I print?';

  @override
  String get settingsGuidelines_faqCatNotesAndPrintingA2 =>
      'A case\'s details, and case lists. Print produces a formatted PDF and uses the device\'s printing options. Print is not available on the Notes and Case Reference screens.';

  @override
  String get settingsGuidelines_faqCatNotesAndPrintingQ3 =>
      'How do I contact a client about a case?';

  @override
  String get settingsGuidelines_faqCatNotesAndPrintingA3 =>
      'A case that carries the client\'s phone number offers Call, Message and WhatsApp actions, and a prepared message containing the client\'s name, the case number, the next hearing date and the court. Review the message before sending — the app cannot check that the number or the hearing date is current.';

  @override
  String get settingsGuidelines_faqCatBackupAndRestore => 'Backup and restore';

  @override
  String get settingsGuidelines_faqCatBackupAndRestoreQ1 =>
      'How do I back up my diary?';

  @override
  String get settingsGuidelines_faqCatBackupAndRestoreA1 =>
      'Go to Settings > Backup & Restore and tap Backup to Local Storage. You choose where the file is saved and set a passphrase that encrypts it. No account and no internet connection are required.';

  @override
  String get settingsGuidelines_faqCatBackupAndRestoreQ2 =>
      'Does the app back up automatically?';

  @override
  String get settingsGuidelines_faqCatBackupAndRestoreA2 =>
      'Not in the offline version — each backup is started by you. If no backup has been made in the current month, the app displays a reminder, which you can dismiss.';

  @override
  String get settingsGuidelines_faqCatBackupAndRestoreQ3 =>
      'I forgot my passphrase. Can you recover it?';

  @override
  String get settingsGuidelines_faqCatBackupAndRestoreA3 =>
      'No. The passphrase is never stored, on your device or anywhere else, so a backup cannot be opened without it. If it is lost, make a fresh backup with a passphrase you can keep safely.';

  @override
  String get settingsGuidelines_faqCatBackupAndRestoreQ4 =>
      'What does restoring a backup do to my current data?';

  @override
  String get settingsGuidelines_faqCatBackupAndRestoreA4 =>
      'Restoring replaces everything currently in the app with the contents of the backup file. It does not merge, and it cannot be undone. Back up your current diary first if there is anything in it you may still need. If the app already holds data, it asks you to confirm before anything is replaced.';

  @override
  String get settingsGuidelines_faqCatBackupAndRestoreQ5 =>
      'How do I move my diary to a new phone?';

  @override
  String get settingsGuidelines_faqCatBackupAndRestoreA5 =>
      'Make a backup on your current phone and save the file somewhere the new phone can reach — a memory card, Google Drive, or an email to yourself. Install the app on the new phone, open Settings > Backup & Restore, and use Restore from backup with the same passphrase.';

  @override
  String get settingsGuidelines_faqCatBackupAndRestoreQ6 =>
      'Can I use a backup made by a different version of the app?';

  @override
  String get settingsGuidelines_faqCatBackupAndRestoreA6 =>
      'Backups made by older versions are upgraded automatically when restored. A backup made by a newer version than the one you are running is refused, so update the app first and then restore.';

  @override
  String get settingsGuidelines_faqCatBackupAndRestoreQ7 =>
      'What happens to my data if I delete the app or lose my phone?';

  @override
  String get settingsGuidelines_faqCatBackupAndRestoreA7 =>
      'In the offline version your diary is stored only on the device, so uninstalling the app or losing the phone also loses the data unless you hold a backup file. Keep a recent backup, and store a copy somewhere outside the phone.';

  @override
  String get settingsGuidelines_faqCatNotifications => 'Notifications';

  @override
  String get settingsGuidelines_faqCatNotificationsQ1 =>
      'Why didn\'t my hearing notification arrive?';

  @override
  String get settingsGuidelines_faqCatNotificationsA1 =>
      'Most Android phones stop background apps to save battery, which prevents hearing alerts. In Settings > Notifications, tap Battery & Auto-Start Setup Guide and follow the steps for your phone, then use Send Test Notification to confirm that alerts arrive.';

  @override
  String get settingsGuidelines_faqCatNotificationsQ2 =>
      'Can I change when hearing notifications are sent?';

  @override
  String get settingsGuidelines_faqCatNotificationsA2 =>
      'Yes. In Settings > Notifications you can choose the day offset — the same day, the day before, or a number of days before the hearing — and the time of day. Notifications can be turned off entirely from the same screen.';

  @override
  String get settingsGuidelines_faqCatLanguageAndDisplay =>
      'Language and display';

  @override
  String get settingsGuidelines_faqCatLanguageAndDisplayQ1 =>
      'How do I change the app language?';

  @override
  String get settingsGuidelines_faqCatLanguageAndDisplayA1 =>
      'Go to Settings > Language and choose English or বাংলা. The change applies throughout the app, and numbers are displayed in the numerals of the selected language. The app language does not change the language your case data was entered in, which is what search matches against.';

  @override
  String get settingsGuidelines_faqCatFreePlanAndPremium =>
      'Free plan and premium';

  @override
  String get settingsGuidelines_faqCatFreePlanAndPremiumQ1 =>
      'Is the app free?';

  @override
  String get settingsGuidelines_faqCatFreePlanAndPremiumA1 =>
      'Yes. The offline app costs nothing to use and holds up to 50 cases. Premium raises that limit and will add online sync when it launches.';

  @override
  String get settingsGuidelines_faqCatFreePlanAndPremiumQ2 =>
      'Why can\'t I add a case?';

  @override
  String get settingsGuidelines_faqCatFreePlanAndPremiumA2 =>
      'The free plan holds up to 50 cases. At the limit, the Add Case form opens the premium screen instead. Nothing is hidden or deleted — you can still view, edit, print and delete every case you have, and deleting a case frees a slot.';

  @override
  String get settingsGuidelines_faqCatFreePlanAndPremiumQ3 =>
      'What stays free?';

  @override
  String get settingsGuidelines_faqCatFreePlanAndPremiumA3 =>
      'Everything except adding cases beyond the limit: viewing, editing, updating, deleting and printing cases, the Daily Cause List, client details and contact actions, Notes, Case References, and Backup & Restore.';

  @override
  String get settingsGuidelines_faqCatFreePlanAndPremiumQ4 =>
      'Why isn\'t cloud backup offered for free?';

  @override
  String get settingsGuidelines_faqCatFreePlanAndPremiumA4 =>
      'Cloud backup and online mode depend on a backend service, which we pay for. Your subscription will cover the cost of storing your data securely online, which is why that service cannot be offered at no charge.';

  @override
  String get settingsGuidelines_faqCatFreePlanAndPremiumQ5 =>
      'Can I subscribe now?';

  @override
  String get settingsGuidelines_faqCatFreePlanAndPremiumA5 =>
      'Not yet. The premium screen shows the available plans, but purchases open with the online version. Until then the offline app is fully usable, and your data stays on your device.';

  @override
  String get settingsGuidelines_faqCatCourtsAndCustomisation =>
      'Courts and customisation';

  @override
  String get settingsGuidelines_faqCatCourtsAndCustomisationQ1 =>
      'Why are some district court names not what I expect?';

  @override
  String get settingsGuidelines_faqCatCourtsAndCustomisationA1 =>
      'We sourced court names for all 64 districts from the Government\'s Cause List website (causelist.judiciary.gov.bd) and used them unchanged. You can rename any court to your preference in Settings > Edit Court/Steps.';

  @override
  String get settingsGuidelines_faqCatCourtsAndCustomisationQ2 =>
      'Can I add my own courts, case types, steps or on-behalf items?';

  @override
  String get settingsGuidelines_faqCatCourtsAndCustomisationA2 =>
      'Yes. Settings > Edit Court/Steps lets you add, rename and delete the courts, case types, steps and on-behalf entries used in the Add and Edit Case forms. Deleting an item cannot be undone.';

  @override
  String get settingsGuidelines_faqCatCourtsAndCustomisationQ3 =>
      'Where do Tribunals and Special Tribunals appear?';

  @override
  String get settingsGuidelines_faqCatCourtsAndCustomisationA3 =>
      'So that tribunals display the correct case types, steps and on-behalf options, we grouped them by subject:\n\nCivil tribunals → District Judge Court (Civil)\nCriminal tribunals → Sessions Judge Court (Criminal)\nCriminal tribunals in metropolitan areas → Metropolitan Sessions Judge Court (Criminal)';

  @override
  String get settingsGuidelines_faqCatCourtsAndCustomisationQ4 =>
      'I can\'t find the court I\'m looking for.';

  @override
  String get settingsGuidelines_faqCatCourtsAndCustomisationA4 =>
      'Courts are listed under the following categories:\n\nDistrict Judge Court (Civil)\n1. District and Additional District Judge Courts\n2. Joint District Judge Courts\n3. Civil & Senior Civil Judge Courts\n4. Family Courts & Family Appeal Court\n5. Land Survey Tribunal & Land Survey Appeal Tribunal\n6. Commercial Court\n7. Labour Court\n\nSessions Judge Court (Criminal) and Metropolitan Sessions Judge Court (Criminal)\n1. Sessions and Additional Sessions Judge Courts\n2. Joint Sessions Judge Courts\n3. Women and Child Abuse Suppression Tribunal\n4. Child Violence Prevention Tribunal\n5. Special Tribunals\n\nChief Judicial Magistrate Court and Chief Metropolitan Magistrate Court\n1. Chief and Additional Chief Judicial Magistrate\n2. Special Magistrate Courts\n3. Speedy Trial Court\n4. Environment Court\n5. Forest Court\n6. Senior Judicial Magistrate Courts\n7. Judicial Magistrate Courts\n8. Cognizance Courts';

  @override
  String get settingsGuidelines_faqCatDataAndSupport =>
      'Data, privacy and support';

  @override
  String get settingsGuidelines_faqCatDataAndSupportQ1 =>
      'Where is my data stored, and who can see it?';

  @override
  String get settingsGuidelines_faqCatDataAndSupportA1 =>
      'In the offline version, everything you enter is stored on your device in encrypted form. Nothing is sent to us or to anyone else, and no account is required. Backup files are encrypted and can only be opened with the passphrase you set. When the online version launches, what it stores and where will be described in its own topic before you use it.';

  @override
  String get settingsGuidelines_faqCatDataAndSupportQ2 =>
      'Is the app a substitute for court records?';

  @override
  String get settingsGuidelines_faqCatDataAndSupportA2 =>
      'No. The app is a personal record-keeping tool for your own practice. The information in it is entered by you, and the official cause list and court records remain authoritative. Always verify a hearing date against the court before relying on it.';

  @override
  String get settingsGuidelines_faqCatDataAndSupportQ3 =>
      'My question isn\'t answered here.';

  @override
  String get settingsGuidelines_faqCatDataAndSupportA3 =>
      'Please write to us at adv.asadusjaman@gmail.com, or open Settings > About for our email and WhatsApp contact. Describe what you were doing when the problem occurred, together with your phone model and the app version shown in Settings > About.';

  @override
  String get settingsAbout_title => 'About';

  @override
  String settingsAbout_version(String version) {
    return 'Version $version';
  }

  @override
  String get settingsAbout_designedBy => 'Designed & Developed By';

  @override
  String get settingsAbout_role => 'Advocate';

  @override
  String get settingsAbout_emailLabel => 'Email';

  @override
  String get settingsAbout_whatsappLabel => 'WhatsApp';

  @override
  String get settingsAbout_moreAboutApp => 'More About the App';

  @override
  String get settingsAbout_faq => 'FAQ';

  @override
  String get settingsAbout_privacyPolicy => 'Privacy Policy';

  @override
  String get settingsAbout_termsOfService => 'Terms of Service';

  @override
  String get settingsAbout_support => 'Support';

  @override
  String get settingsAbout_dataSafetyTitle => 'Data Safety';

  @override
  String get settingsAbout_dataSafetyBody =>
      'Your data is stored locally on your device and encrypted in the cloud.';

  @override
  String get settingsAbout_actionPending => 'Arrives in a later task';

  @override
  String get settingsMoreAbout_title => 'More About the App';

  @override
  String get settingsMoreAbout_checkUpdates => 'Check for updates';

  @override
  String get settingsMoreAbout_description =>
      'Justice Ledger is a comprehensive digital diary exclusively crafted for Bangladeshi lawyers. It is designed to streamline the management of daily cause lists, rigorously track upcoming and missed dates, and store vital case references securely. Built with precision and the demanding pace of legal professionals in mind, it ensures that your most critical data is always organized and instantly accessible.';

  @override
  String get settingsMoreAbout_keyFeatures => 'Key Features';

  @override
  String get settingsMoreAbout_featureDailyCauseList => 'Daily Cause List';

  @override
  String get settingsMoreAbout_featureOfflineBackup => 'Offline Backup';

  @override
  String get settingsMoreAbout_featureCaseReferences => 'Case References';

  @override
  String get settingsMoreAbout_featureSecureSync => 'Secure Sync';

  @override
  String get settingsMoreAbout_rateApp => 'Rate App';

  @override
  String get settingsMoreAbout_shareApp => 'Share App';

  @override
  String get settingsMoreAbout_footer => 'Designed & Developed by';

  @override
  String get print_notAvailable => 'Print is not available on this screen.';

  @override
  String appShare_invite(String link) {
    return 'Legal Case Diary - a complete offline case diary for Bangladeshi lawyers.\nGet it here: $link';
  }

  @override
  String get appShare_subject => 'Legal Case Diary';

  @override
  String get appShare_copied =>
      'No app to share with, so the invite was copied to your clipboard.';

  @override
  String get appShare_failed => 'Could Not Share the App';

  @override
  String get print_preparing => 'Preparing Your Print';

  @override
  String get print_failed => 'Could Not Print';

  @override
  String get print_nothingToPrint => 'Nothing to Print';

  @override
  String print_printedOn(String date) {
    return 'Printed on $date';
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

    return 'Page $pageString of $totalString';
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
}
