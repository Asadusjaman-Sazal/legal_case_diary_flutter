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
  String get settingsScreen_guidelines => 'Guidelines';

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
  String get settingsGuidelines_title => 'Guidelines';

  @override
  String get settingsGuidelines_intro =>
      'Tap on any topic below to expand and view detailed administrative procedures.';

  @override
  String get settingsGuidelines_dailyCauseListTitle =>
      'Daily Cause List Management';

  @override
  String get settingsGuidelines_dailyCauseListBody1 =>
      'To ensure your daily schedule is accurate, synchronize your local diary with the court\'s official cause list. Navigate to the \'Cause List\' tab and tap the sync icon in the top right corner.';

  @override
  String get settingsGuidelines_dailyCauseListBody2 =>
      'Note: Disposed cases will automatically move to the archive unless marked for active monitoring.';

  @override
  String get settingsGuidelines_referencesTitle => 'Managing Case References';

  @override
  String get settingsGuidelines_referencesBody1 =>
      'When adding a new case, use the standardized format for case references to enable efficient search later. Enter the Case Type, Number, and Year (e.g., Writ Petition No. 1234 of 2023).';

  @override
  String get settingsGuidelines_referencesBody2 =>
      'You can link relevant legal precedents to specific active cases within the \'Case Details\' view under the \'Notes\' section.';

  @override
  String get settingsGuidelines_backupTitle => 'Offline Backup & Restore';

  @override
  String get settingsGuidelines_backupBody1 =>
      'The Justice Ledger automatically performs a local backup every 24 hours. To configure cloud backups to Google Drive or secure enterprise servers, visit Settings > Backup Options.';

  @override
  String get settingsGuidelines_backupBody2 =>
      'If you need to restore data, ensure you have your encryption key available before initiating the recovery process.';

  @override
  String get settingsGuidelines_securityTitle => 'Security & Encryption';

  @override
  String get settingsGuidelines_securityBody1 =>
      'All sensitive client data and case notes are protected using end-to-end AES-256 encryption. The decryption key remains solely on your device.';

  @override
  String get settingsGuidelines_securityBody2 =>
      'We recommend enabling biometric authentication (Face ID or Fingerprint) in the app settings to add an additional layer of security for daily access.';

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
