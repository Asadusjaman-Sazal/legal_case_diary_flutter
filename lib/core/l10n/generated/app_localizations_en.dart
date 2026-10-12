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
  String get nav_adminPanel => 'Admin Panel';

  @override
  String get drawerOf => 'of';

  @override
  String drawer_version(String version) {
    return 'V$version';
  }

  @override
  String get allCasesScreen_title => 'All Cases';

  @override
  String get allCasesScreen_empty => 'No case added yet. Tap + to add one.';

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
  String get activeCasesScreen_empty =>
      'No active case to show. Tap + to add one.';

  @override
  String get upcomingCasesScreen_title => 'Upcoming Cases';

  @override
  String get upcomingCasesScreen_empty => 'No upcoming case';

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
  String get disposedCasesScreen_empty => 'No disposed case';

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
  String get overdueDatesScreen_empty => 'No overdue case';

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
  String addEditCaseSheet_offsetDaysBefore(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Before $countString days';
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
  String get notesScreen_newTextNote => 'Text Note';

  @override
  String get notesScreen_newTodo => 'To-Do';

  @override
  String get notesScreen_listItemHint => 'List Item';

  @override
  String get notesScreen_addItem => 'Add Item';

  @override
  String get notesScreen_removeItem => 'Remove Item';

  @override
  String notesScreen_itemsMore(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '+$countString More';
  }

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
  String sync_pendingBadge(int count) {
    return '$count waiting to sync';
  }

  @override
  String get sync_offline => 'No Connection';

  @override
  String get sync_permissionsChanged =>
      'Your Firm Permissions Changed; This Pending Action Was Not Applied.';

  @override
  String get sync_clockSkewWarning =>
      'Your Device Clock Appears Incorrect. Please Fix It To Ensure Reliable Syncing.';

  @override
  String syncConflict_bannerMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Conflicts Need Review',
      one: 'A Conflict Needs Review',
    );
    return '$_temp0';
  }

  @override
  String get syncConflict_bannerAction => 'Review';

  @override
  String get syncConflict_title => 'Review Conflict';

  @override
  String get syncConflict_subtitle => 'Another Device Changed This Record';

  @override
  String syncConflict_editedBy(String name) {
    return 'Edited By $name';
  }

  @override
  String get syncConflict_unknownEditor => 'Another Device';

  @override
  String get syncConflict_intro =>
      'You and another device changed the same fields. Choose the value to keep for each one.';

  @override
  String get syncConflict_keepServer => 'Server';

  @override
  String get syncConflict_keepMine => 'Mine';

  @override
  String get syncConflict_tombstoneTitle => 'Deleted On The Server';

  @override
  String get syncConflict_tombstoneBody =>
      'This record was deleted on another device. Your saved changes are still here — choose what happens to them.';

  @override
  String get syncConflict_rebaseOntoNewRecord => 'Keep As A New Record';

  @override
  String get syncConflict_discard => 'Discard My Changes';

  @override
  String get syncConflict_discardConfirmTitle => 'Discard Your Changes?';

  @override
  String get syncConflict_discardConfirmBody =>
      'The server version will replace your unsynced changes. This cannot be undone.';

  @override
  String get syncConflict_laterEditsTitle => 'Later Saved Changes';

  @override
  String get syncConflict_laterEditsBody =>
      'These edits are preserved until this conflict is answered.';

  @override
  String get syncConflict_resolvedNotice =>
      'This Conflict Is Already Resolved.';

  @override
  String get syncConflict_missingNotice =>
      'This Conflict Is No Longer Available.';

  @override
  String get syncStatus_title => 'Sync Status';

  @override
  String get syncStatus_subtitle => 'Every Change Waiting To Be Sent';

  @override
  String get syncStatus_lastSyncedNever => 'Never Synced';

  @override
  String syncStatus_lastSynced(String time) {
    return 'Last Synced $time';
  }

  @override
  String get syncStatus_filterAll => 'All';

  @override
  String get syncStatus_filterPending => 'Pending';

  @override
  String get syncStatus_filterConflicted => 'Conflicted';

  @override
  String get syncStatus_filterBlocked => 'Blocked';

  @override
  String get syncStatus_statePending => 'Pending';

  @override
  String get syncStatus_statePushing => 'Sending';

  @override
  String get syncStatus_stateConflicted => 'Conflicted';

  @override
  String get syncStatus_stateBlocked => 'Blocked';

  @override
  String get syncStatus_stateUnknown => 'Unknown';

  @override
  String get syncStatus_retry => 'Retry';

  @override
  String get syncStatus_discard => 'Discard';

  @override
  String get syncStatus_reviewConflict => 'Review Conflict';

  @override
  String get syncStatus_moreActions => 'More Actions';

  @override
  String syncStatus_queued(String time) {
    return 'Queued $time';
  }

  @override
  String syncStatus_attempted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Attempted $count Times',
      one: 'Attempted Once',
    );
    return '$_temp0';
  }

  @override
  String syncStatus_lastAttempt(String time) {
    return 'Last Attempt $time';
  }

  @override
  String syncStatus_lastError(String message) {
    return 'Last Error: $message';
  }

  @override
  String get syncStatus_blockedWhy => 'Why It Is Blocked';

  @override
  String get syncStatus_blockedCauseRefused =>
      'The server refused this change.';

  @override
  String get syncStatus_blockedCauseAttempts =>
      'Sync gave up after too many failed attempts.';

  @override
  String get syncStatus_timeJustNow => 'Just Now';

  @override
  String syncStatus_timeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Minutes Ago',
      one: '1 Minute Ago',
    );
    return '$_temp0';
  }

  @override
  String syncStatus_timeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Hours Ago',
      one: '1 Hour Ago',
    );
    return '$_temp0';
  }

  @override
  String syncStatus_timeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Days Ago',
      one: '1 Day Ago',
    );
    return '$_temp0';
  }

  @override
  String get syncStatus_emptyTitle => 'Nothing Is Waiting To Sync';

  @override
  String get syncStatus_emptyBody =>
      'Every Change On This Device Has Been Sent.';

  @override
  String get syncStatus_retried => 'The Change Will Be Sent Again.';

  @override
  String get syncStatus_discardTitle => 'Discard This Change?';

  @override
  String get syncStatus_discardBody =>
      'The Queued Change Will Be Removed And The Record Will Go Back To The Version Saved On The Server. This Cannot Be Undone.';

  @override
  String get syncStatus_discardConfirm => 'Discard';

  @override
  String get syncStatus_discarded => 'The Queued Change Was Discarded.';

  @override
  String get syncStatus_discardRestoredLocally =>
      'The Change Was Discarded. The Record Was Restored From The Last Saved Copy On This Device.';

  @override
  String get syncStatus_pendingDeletion => 'Deletion Pending';

  @override
  String get syncStatus_export => 'Export Diagnostic Bundle';

  @override
  String get syncStatus_exportShort => 'Export';

  @override
  String get syncStatus_exportTitle => 'Export Diagnostic Bundle';

  @override
  String get syncStatus_exportMetadataOnly => 'Metadata Only';

  @override
  String get syncStatus_exportMetadataOnlyBody =>
      'Types, States, Retry Counts And Error Messages. No Case Content Is Included.';

  @override
  String get syncStatus_exportIncludePayloads => 'Include Payloads';

  @override
  String get syncStatus_exportIncludePayloadsBody =>
      'Adds The Queued Changes Themselves, Which Can Include Case Details.';

  @override
  String get syncStatus_exportConsentTitle => 'Include Case Content?';

  @override
  String get syncStatus_exportConsentBody =>
      'The Bundle Will Contain The Queued Changes, Which Can Include Case Numbers, Names And Notes. Only Share It With Someone You Trust.';

  @override
  String get syncStatus_exportConsentConfirm => 'Include';

  @override
  String get syncStatus_exportReminder =>
      'Delete This File After Seven Days, Or As Soon As Support No Longer Needs It.';

  @override
  String syncStatus_exportSaved(String path) {
    return 'Diagnostic Bundle Saved To $path';
  }

  @override
  String get syncStatus_exportFailed =>
      'The Diagnostic Bundle Could Not Be Saved.';

  @override
  String get logout_connectToSync =>
      'Connect To The Internet To Sync Your Changes First.';

  @override
  String get logout_logOutAnyway => 'Log Out Anyway';

  @override
  String get logout_unsyncedWarningTitle => 'Some Changes Have Not Synced Yet';

  @override
  String get logout_unsyncedWarningBody =>
      'Some data haven\'t finished syncing to cloud yet. Logging out now will result in those unsynced data being discarded.';

  @override
  String get logout_proceed => 'Log Out';

  @override
  String get logout_backupPromptTitle => 'Backup Data to Local Storage';

  @override
  String logout_backedUpTo(String path) {
    return 'Your Data Has Been Backed Up To $path. You Can Restore It After Logging Back In.';
  }

  @override
  String get logout_exportCancelled =>
      'Logging Out Was Cancelled; Nothing Was Deleted.';

  @override
  String get logout_exportFailed =>
      'The Safety Copy Could Not Be Saved, So Nothing Was Deleted.';

  @override
  String get logout_syncFailed => 'Your Changes Could Not Be Synced.';

  @override
  String get recoveryLock_title => 'Offline For Too Long';

  @override
  String recoveryLock_message(int days, String path) {
    return 'You Have Been Offline For $days Days. Your Local Changes Have Been Saved To $path. Fresh Data Must Be Loaded From The Server Before Editing Can Continue.';
  }

  @override
  String recoveryLock_messageNoCopy(int days) {
    return 'You Have Been Offline For $days Days. A Safety Copy Must Be Saved Before Fresh Data Can Be Loaded From The Server.';
  }

  @override
  String get recoveryLock_saveTitle => 'Save A Safety Copy';

  @override
  String get recoveryLock_saveBody =>
      'Everything on this device — your cases, notes and unsynced changes — is sealed into one encrypted file first. Set a passphrase you will remember; it is not stored anywhere.';

  @override
  String get recoveryLock_saveBodyUnencrypted =>
      'Everything on this device — your cases, notes and unsynced changes — is saved into one unencrypted file first.';

  @override
  String get recoveryLock_saveAction => 'Save The Safety Copy';

  @override
  String recoveryLock_savedTo(String path) {
    return 'Safety Copy Saved To $path';
  }

  @override
  String get recoveryLock_saveFailed =>
      'The Safety Copy Could Not Be Saved. Your Data Is Still On This Device — Try Again.';

  @override
  String get recoveryLock_proceed => 'Load Fresh Data';

  @override
  String get recoveryLock_proceedConfirmTitle =>
      'Replace This Device With The Server\'s Copy?';

  @override
  String get recoveryLock_proceedConfirmBody =>
      'Your Local Changes Will Be Replaced By The Server\'s Data. The Safety Copy You Saved Is The Only Way Back To Them.';

  @override
  String get recoveryLock_close => 'Close';

  @override
  String get recoveryLock_closeBody =>
      'The App Stays Locked And Nothing Is Written To The Cloud Until Recovery Succeeds.';

  @override
  String get recoveryLock_working => 'Loading Fresh Data…';

  @override
  String get recoveryLock_failed =>
      'Recovery Could Not Finish. Your Data Is Still On This Device And The App Stays Locked; Try Again.';

  @override
  String syncStatus_entryTitle(String entity, String operation) {
    return '$entity $operation';
  }

  @override
  String get paywall_title => 'Subscription Plans';

  @override
  String get paywall_limitTitle => 'Free Plan Limit Reached';

  @override
  String paywall_limitBody(String limit) {
    return 'The free plan holds up to $limit cases. Deleting a case frees a slot, and everything else — Case Management, taking Notes, using Case Reference, editing and printing — stays free.';
  }

  @override
  String get paywall_benefitsTitle => 'Subscription Plans Offer';

  @override
  String get paywall_featureUnlimitedCasesTitle => 'Unlimited Cases';

  @override
  String get paywall_featureUnlimitedCasesBody =>
      'Store as many cases as you need, with no limit.';

  @override
  String get paywall_featureDisasterRecoveryTitle => 'Disaster Recovery';

  @override
  String get paywall_featureDisasterRecoveryBody =>
      'If your phone is lost or broken, your data is always safe in the cloud. You can login to your new device with your account to get access to your old data.';

  @override
  String get paywall_featureRealTimeBackupTitle => 'Real-time Backup';

  @override
  String get paywall_featureRealTimeBackupBody =>
      'Every change is instantly saved to the cloud.';

  @override
  String get paywall_featureMultiDeviceTitle => 'Multi-device Support';

  @override
  String get paywall_featureMultiDeviceBody =>
      'Access your diary from multiple devices simultaneously.';

  @override
  String get paywall_featureCollaborationTitle => 'Collaboration';

  @override
  String get paywall_featureCollaborationBody =>
      'Work together with your associates on the same diary.';

  @override
  String get paywall_plansTitle => 'Plans';

  @override
  String get paywall_planMonthly => '1 Month';

  @override
  String get paywall_planQuarterly => '3 Months';

  @override
  String get paywall_planHalfYearly => '6 Months';

  @override
  String get paywall_planAnnual => '1 Year';

  @override
  String paywall_planWasPrice(String price) {
    return '৳$price';
  }

  @override
  String paywall_planDiscount(String percent) {
    return '$percent% Off';
  }

  @override
  String get paywall_subscribe => 'Subscribe';

  @override
  String get adminPanel_title => 'Admin Panel';

  @override
  String get adminPanel_paymentRequests => 'Payment Requests';

  @override
  String get adminPanel_paymentRequestsSubtitle =>
      'Approve Or Reject Submitted Payments';

  @override
  String get adminPanel_unverifiedAccounts => 'Non-verified Accounts';

  @override
  String get adminPanel_unverifiedAccountsSubtitle =>
      'Sign-Ups That Never Confirmed';

  @override
  String get adminPanel_unverifiedTitle => 'Non-verified Accounts';

  @override
  String get adminPanel_unverifiedEmpty =>
      'Every account has confirmed its address.';

  @override
  String get adminPanel_unverifiedLoadFailed =>
      'The accounts could not be loaded.';

  @override
  String get adminPanel_created => 'Created';

  @override
  String get adminPanel_lastSignIn => 'Last Sign-in';

  @override
  String get adminPanel_delete => 'Delete';

  @override
  String get adminPanel_deleteTitle => 'Delete This Account?';

  @override
  String get adminPanel_deleteBody =>
      'The account never confirmed its address and has done nothing, so it will be removed for good. This cannot be undone.';

  @override
  String get adminPanel_deleteConfirm => 'Delete Account';

  @override
  String get adminPanel_deleteBlocked =>
      'This account has data or is confirmed, so it cannot be deleted from here.';

  @override
  String get adminPanel_deleted => 'Account deleted.';

  @override
  String get adminPanel_search => 'Search';

  @override
  String get adminPanel_searchHint => 'Search';

  @override
  String get adminPanel_noResults => 'No results found.';

  @override
  String get adminPanel_pending => 'Pending';

  @override
  String get adminPanel_resolved => 'Resolved';

  @override
  String adminPanel_sectionCount(String count) {
    return '$count';
  }

  @override
  String get adminPanel_emptyPending => 'No payment is waiting for a decision.';

  @override
  String get adminPanel_emptyResolved =>
      'Nothing has been approved or rejected yet.';

  @override
  String get adminPanel_approve => 'Approve';

  @override
  String get adminPanel_reject => 'Reject';

  @override
  String get adminPanel_rejectTitle => 'Reject This Payment';

  @override
  String get adminPanel_rejectNoteLabel => 'Note For The Payer (Optional)';

  @override
  String get adminPanel_rejectNoteHint => 'Why this payment was not accepted';

  @override
  String get adminPanel_rejectConfirm => 'Reject Payment';

  @override
  String adminPanel_detailLabel(String label, String value) {
    return '$label: $value';
  }

  @override
  String get adminPanel_detailLabelTrx => 'TrxID';

  @override
  String get adminPanel_detailLabelMfs => 'Method';

  @override
  String get adminPanel_detailLabelName => 'Name';

  @override
  String get adminPanel_detailLabelEmail => 'Email';

  @override
  String get adminPanel_detailLabelBar => 'Bar Association';

  @override
  String get adminPanel_detailLabelMembership => 'Membership No';

  @override
  String get adminPanel_detailLabelMobile => 'Mobile';

  @override
  String get adminPanel_detailLabelSubmitted => 'Submitted';

  @override
  String get adminPanel_detailLabelNote => 'Note';

  @override
  String get adminPanel_noValue => '—';

  @override
  String get adminPanel_statusApproved => 'Approved';

  @override
  String get adminPanel_statusRejected => 'Rejected';

  @override
  String get adminPanel_statusPending => 'Pending';

  @override
  String get adminPanel_approvedExpiry => 'Premium Extended To';

  @override
  String get adminPanel_approvedBy => 'Approved By';

  @override
  String get adminPanel_rejectedBy => 'Rejected By';

  @override
  String get adminPanel_loading => 'Loading payment requests…';

  @override
  String get adminPanel_loadFailed => 'Payment requests could not be loaded.';

  @override
  String get adminPanel_retry => 'Try Again';

  @override
  String get adminPanel_approved =>
      'Payment approved. The payer is now premium.';

  @override
  String get adminPanel_rejected => 'Payment rejected.';

  @override
  String get adminPanel_failedNotAdmin => 'Only an administrator can do that.';

  @override
  String get adminPanel_failedNotFound => 'That payment no longer exists.';

  @override
  String get adminPanel_failedAlreadyResolved =>
      'That payment was already decided.';

  @override
  String get adminPanel_failedUnexpected =>
      'That did not work. Please try again.';

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
  String get sharedMessages_signInRequired => 'Sign In To Continue';

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
  String get settingsAccountProfile_sectionProfile => 'Profile';

  @override
  String get settingsAccountProfile_sectionAccount => 'Account';

  @override
  String get settingsAccountProfile_sectionFirm => 'Firm';

  @override
  String get settingsAccountProfile_profileSubtitle =>
      'Your name, bar association, and membership details';

  @override
  String get settingsAccountProfile_manageAccountSubtitle =>
      'Your account details, password, and sign-out';

  @override
  String get settingsAccountProfile_subscriptionSubtitle =>
      'Your plan, expiry, and purchase history';

  @override
  String get settingsAccountProfile_manageAssociatesSubtitle =>
      'Manage Associates, Invites, And Firm Permissions';

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
  String get settingsProfile_savedOnline => 'Profile saved';

  @override
  String get settingsManageAccount_title => 'Manage Account';

  @override
  String get settingsManageAccount_changePassword => 'Change Password';

  @override
  String get settingsSubscription_freePlanLimitations =>
      'Free Plan Limitations';

  @override
  String settingsSubscription_freeLimitCases(String limit) {
    return 'Up to $limit cases at a time. Deleting a case frees a slot.';
  }

  @override
  String get settingsSubscription_freeLimitCloud =>
      'The cloud features — real-time backup, working from another device, and sharing the diary with associates — need a paid plan.';

  @override
  String get settingsSubscription_freeLimitRecovery =>
      'If the phone is lost or broken, a free account\'s diary has no cloud copy to restore from.';

  @override
  String get settingsSubscription_currentPlan => 'Current Plan';

  @override
  String get settingsSubscription_paid => 'Paid';

  @override
  String get settingsSubscription_dateTime => 'Date & Time';

  @override
  String get settingsSubscription_title => 'Subscription';

  @override
  String get settingsManageAccount_subscriptionDetails =>
      'Subscription Details';

  @override
  String get settingsManageAccount_purchaseNewSubscription =>
      'Purchase New Subscription';

  @override
  String get settingsManageAccount_logout => 'Logout';

  @override
  String get settingsManageAccount_deleteAccount => 'Delete Account';

  @override
  String get settingsManageAccount_deleteCannotBeUndone =>
      'This action cannot be undone';

  @override
  String get settingsManageAccount_deleteLocalAndCloudData =>
      'Delete Local & Cloud Data';

  @override
  String get settingsManageAccount_deleteLocalData => 'Delete Local Data';

  @override
  String get settingsManageAccount_deleteDataTitle => 'Delete Data?';

  @override
  String get settingsManageAccount_deleteDataBodyCloud =>
      'Tick what to delete from this device and your account. Your profile, subscription and settings stay.';

  @override
  String get settingsManageAccount_deleteDataBodyLocal =>
      'Tick what to delete from this device. Your profile, subscription and settings stay.';

  @override
  String get settingsManageAccount_deleteDataCases => 'Cases';

  @override
  String get settingsManageAccount_deleteDataNotes => 'Notes';

  @override
  String get settingsManageAccount_deleteDataCaseReferences =>
      'Case References';

  @override
  String get settingsManageAccount_deleteDataCustomSeedData =>
      'Custom Seed Data';

  @override
  String get settingsManageAccount_deleteDataCustomSeedDataHint =>
      'Court categories, court names, steps, case types and on-behalfs you added';

  @override
  String get settingsManageAccount_deleteDataConfirm => 'Delete Selected';

  @override
  String get settingsManageAccount_deleteDataConfirmPhrase => 'delete my data';

  @override
  String get settingsManageAccount_deleteDataDone =>
      'Your Selected Data Has Been Deleted.';

  @override
  String get settingsManageAccount_deleteDataCloudPending =>
      'Your data was deleted from this device. The account\'s copies will be removed on the next sync.';

  @override
  String get settingsManageAccount_deleteDataNeedsConnection =>
      'Connect to the internet to delete your cloud data. Nothing Has Been Deleted.';

  @override
  String get settingsManageAccount_deleteDataFirmRefused =>
      'You are part of a firm, so your diary is shared with it. Ask the firm owner to remove you before deleting your data.';

  @override
  String get settingsManageAccount_deleteDataFailed =>
      'Your data could not be deleted. Please try again.';

  @override
  String get settingsManageAccount_dangerZone => 'Danger Zone';

  @override
  String get settingsManageAccount_deleted => 'Your Account Has Been Deleted.';

  @override
  String get settingsManageAccount_deleteDialogTitle => 'Delete Account?';

  @override
  String get settingsManageAccount_deleteWarningFree =>
      'This permanently deletes your account and every case, note, case reference and setting on this device. Nothing can be recovered after this.';

  @override
  String get settingsManageAccount_deleteWarningPremium =>
      'This permanently deletes your account and every case, note, case reference and setting on this device and in the cloud. Nothing can be recovered after this.';

  @override
  String get settingsManageAccount_deleteConfirmPhrase => 'delete my account';

  @override
  String settingsManageAccount_deleteConfirmBody(String phrase) {
    return 'Type $phrase below to confirm.';
  }

  @override
  String get settingsManageAccount_deleteNeedsConnection =>
      'Connect to the internet to delete your account. Nothing Has Been Deleted.';

  @override
  String get settingsManageAccount_deleteFirmRefused =>
      'You are part of a firm, so some of your data is shared with it. Ask the firm owner to remove you before deleting your account.';

  @override
  String get settingsManageAccount_deleteAdminRefused =>
      'An administrator account cannot be deleted from the app.';

  @override
  String get settingsManageAccount_deleteFailed =>
      'Your account could not be deleted. Please try again.';

  @override
  String get settingsManageAccount_loggedOut => 'You Have Been Logged Out.';

  @override
  String get settingsManageAccount_role => 'Role';

  @override
  String get settingsManageAccount_roleIndividual => 'Individual';

  @override
  String get settingsManageAccount_roleOwner => 'Owner';

  @override
  String get settingsManageAccount_roleAssociate => 'Associate';

  @override
  String get settingsManageAccount_roleViewer => 'Viewer';

  @override
  String get settingsManageAccount_firm => 'Firm';

  @override
  String get settingsManageAccount_subscription => 'Subscription';

  @override
  String get settingsManageAccount_planFree => 'Free';

  @override
  String get settingsManageAccount_planPremium => 'Premium';

  @override
  String settingsManageAccount_premiumUntil(String date) {
    return 'Premium Until $date';
  }

  @override
  String get settingsOnlineSync_title => 'Online Sync';

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
  String get settingsOnlineSync_synced => 'Synced';

  @override
  String get settingsOnlineSync_notSyncedSignedOut => 'Sign in to sync';

  @override
  String get settingsOnlineSync_pendingSyncTitle => 'Pending Sync';

  @override
  String get settingsOnlineSync_pendingSyncSubtitle =>
      'Every Change Waiting To Be Sent';

  @override
  String get settingsOnlineSync_signedIn => 'Signed In';

  @override
  String settingsOnlineSync_signedInAs(String name) {
    return 'Signed In As $name';
  }

  @override
  String get settingsOnlineSync_premiumActive =>
      'Premium Sync Is Active Across Your Devices';

  @override
  String get settingsOnlineSync_freePlan =>
      'Free Plan — Your Diary Stays On This Device';

  @override
  String get settingsOnlineSync_freePlanPill => 'Free Plan';

  @override
  String get settingsOnlineSync_freePlanHint =>
      'A subscription plan is required to sync across devices. Purchase a plan from';

  @override
  String get settingsOnlineSync_freePlanHintLink => 'here';

  @override
  String get settingsOnlineSync_freePlanHintSuffix => '.';

  @override
  String get settingsOnlineSync_upToDate => 'Up To Date';

  @override
  String get settingsOnlineSync_syncing => 'Syncing…';

  @override
  String get settingsOnlineSync_paused => 'Sync Paused';

  @override
  String get settingsOnlineSync_offline => 'No Connection';

  @override
  String get settingsOnlineSync_actionRequiredBody =>
      'Some changes could not be sent. Open Sync Status to review them.';

  @override
  String settingsOnlineSync_lastSyncAt(String when) {
    return 'Last Sync: $when';
  }

  @override
  String settingsOnlineSync_pendingUploads(int count) {
    return '$count Waiting To Send';
  }

  @override
  String get settingsOnlineSync_pendingNone =>
      'Everything is backed up to your account.';

  @override
  String settingsOnlineSync_pendingCount(int count) {
    return '$count Waiting';
  }

  @override
  String get settingsOnlineSync_syncFailed =>
      'Sync did not complete. Your changes are safe on this device.';

  @override
  String get settingsOnlineSync_syncFinished => 'Sync Finished.';

  @override
  String get settingsOnlineSync_needSignInToSync =>
      'Sign In To Sync Across Devices.';

  @override
  String get settingsOnlineSync_needConnectionToSync =>
      'No Connection. Your Changes Are Saved On This Device.';

  @override
  String get settingsOnlineSync_checkingPlan => 'Checking Your Subscription…';

  @override
  String get settingsOnlineSync_checkingPlanBody =>
      'Confirming your plan before anything is sent.';

  @override
  String get settingsOnlineSync_checkingPlanMessage =>
      'Sync Starts As Soon As Your Plan Is Confirmed.';

  @override
  String get settingsOnlineSync_itemsUnknown => '— Items';

  @override
  String settingsOnlineSync_itemsCount(int count) {
    return '$count Items';
  }

  @override
  String get settingsOnlineSync_syncOff => 'Sync Off';

  @override
  String get settingsOnlineSync_syncOffBody =>
      'Sync is off. Turn it back on to send and receive your changes.';

  @override
  String get settingsOnlineSync_syncOffMessage =>
      'Sync Is Off. Turn It Back On To Sync.';

  @override
  String get settingsOnlineSync_syncOnTitle => 'Sync Is On';

  @override
  String get settingsOnlineSync_syncOnBody =>
      'Turn sync off to keep your changes on this device for now. You can turn it back on here at any time.';

  @override
  String get settingsOnlineSync_syncOffTitle => 'Sync Is Off';

  @override
  String get settingsOnlineSync_syncOffCardBody =>
      'Nothing is sent or received while sync is off. Your changes stay on this device, and sync turns back on when the app is restarted.';

  @override
  String get settingsOnlineSync_disableSync => 'Disable Sync';

  @override
  String get settingsOnlineSync_enableSync => 'Enable Sync';

  @override
  String get settingsOnlineSync_syncOffToast =>
      'Sync Is Off. Your Changes Stay On This Device.';

  @override
  String get settingsOnlineSync_syncOnToast => 'Sync Is On Again.';

  @override
  String get settingsBackupRestore_title => 'Backup & Restore';

  @override
  String get settingsBackupRestore_chooseBackupTitle =>
      'Choose the backup to restore';

  @override
  String get backupScheduled_skipNoticeTitle => 'Automatic backup skipped';

  @override
  String get backupScheduled_skipNoticeBody =>
      'Backups are encrypted with a passphrase only you know, so the automatic backup cannot run. Open Legal Case Diary and back up manually.';

  @override
  String get backupScheduled_noticeChannelName => 'Backup reminders';

  @override
  String get backupScheduled_noticeChannelDescription =>
      'Reminders about your automatic backups.';

  @override
  String get settingsBackupRestore_sectionBackup => 'Backup & Restore';

  @override
  String get settingsBackupRestore_sectionBackupSubtitle =>
      'Back Up Or Restore Your Diary';

  @override
  String get settingsBackupRestore_sectionEncryption => 'Encryption On Backup';

  @override
  String get settingsBackupRestore_sectionEncryptionSubtitle =>
      'Protect Backups With A Passphrase';

  @override
  String get settingsBackupRestore_encryptionWhy =>
      'Encrypting a backup locks the file behind a passphrase you choose, so anyone who gets it cannot read your case data.';

  @override
  String get settingsBackupRestore_encryptionCost =>
      'The passphrase is never stored. If you forget it, that backup can never be restored, so keep it somewhere safe.';

  @override
  String get settingsBackupRestore_encryptionStateOn =>
      'Encryption is currently on';

  @override
  String get settingsBackupRestore_encryptionStateOff =>
      'Encryption is currently off';

  @override
  String get settingsBackupRestore_encryptionEnable => 'Enable';

  @override
  String get settingsBackupRestore_encryptionDisable => 'Disable';

  @override
  String get settingsBackupRestore_sectionAutomaticBackup => 'Automatic Backup';

  @override
  String get settingsBackupRestore_sectionAutomaticBackupSubtitle =>
      'Choose How Often Your Diary Backs Up';

  @override
  String get settingsBackupRestore_sectionStatus => 'Backup Status';

  @override
  String get settingsBackupRestore_backupLocal => 'Backup to Local Storage';

  @override
  String get settingsBackupRestore_backupDrive => 'Backup to Google Drive';

  @override
  String get settingsBackupRestore_restore => 'Restore from Backup';

  @override
  String get settingsBackupRestore_encryptionNote =>
      'Backups are saved to your local storage or cloud provider. Turn on Encryption On Backup to lock them behind a passphrase. Restoration will overwrite current data.';

  @override
  String get settingsBackupRestore_offlineNote =>
      'Note: Restoration is available for offline accounts only.';

  @override
  String get settingsBackupRestore_lastSuccessfulBackup =>
      'Last Successful Backup';

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
  String get settingsBackupRestore_restoreBlockedBody =>
      'Subscribed users are restricted from restoring offline data to prevent data contamination and potential issues. You need to delete current local & cloud data before restoring a local save.';

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
  String get settingsBackupRestore_errorAnotherAccount =>
      'This backup belongs to another account. Sign in as that account to restore it.';

  @override
  String get settingsBackupRestore_errorOpenFile => 'Could not open that file.';

  @override
  String get settingsBackupRestore_backupExcel => 'Backup as Excel File';

  @override
  String get settingsBackupRestore_excelNote =>
      'The Excel file is a spreadsheet and is not encrypted. Anyone who opens it can read your case data.';

  @override
  String get settingsBackupRestore_sectionExcelFormat => 'Excel Backup Format';

  @override
  String get settingsBackupRestore_sectionExcelFormatSubtitle =>
      'See The Format And Download A Sample';

  @override
  String get settingsBackupRestore_excelTemplateNote =>
      'The sample workbook also carries Courts, Case Types, Steps, On Behalfs and Case Categories sheets, plus a Guide sheet. Those extra sheets are there only to show you what to fill in — the app leaves them alone when restoring.';

  @override
  String get settingsBackupRestore_excelIntro =>
      'The Excel file holds four sheets — Cases, Case History, Notes and Case References — plus an Info sheet. Keep the sheet names and the first row of every sheet exactly as they are: the app matches them when restoring.';

  @override
  String get settingsBackupRestore_excelPartialNote =>
      'It is not a complete backup. Courts, steps and your settings are not in it, so restore it into a diary that already has them.';

  @override
  String get settingsBackupRestore_excelIdNote =>
      'Leave a row\'s id blank and the app gives it a new one. Every other required cell must be filled.';

  @override
  String get settingsBackupRestore_excelTemplate => 'Download Template File';

  @override
  String get settingsBackupRestore_excelProgress => 'Creating your Excel file…';

  @override
  String settingsBackupRestore_excelSaved(String path) {
    return 'Excel file saved to $path';
  }

  @override
  String settingsBackupRestore_excelTemplateSaved(String path) {
    return 'Template saved to $path';
  }

  @override
  String get settingsBackupRestore_excelNotSpreadsheet =>
      'That file is not a spreadsheet.';

  @override
  String get settingsBackupRestore_excelNotBackup =>
      'That workbook is not a Legal Case Diary Excel backup.';

  @override
  String get settingsBackupRestore_excelNewerVersion =>
      'This workbook was made by a newer version of the app.';

  @override
  String settingsBackupRestore_excelUnknownSheet(String sheet) {
    return 'The workbook has a sheet this format does not define: $sheet';
  }

  @override
  String settingsBackupRestore_excelMissingSheet(String sheet) {
    return 'The workbook has no $sheet sheet.';
  }

  @override
  String settingsBackupRestore_excelUnknownColumn(String sheet, String column) {
    return 'The $sheet sheet has a column this format does not define: $column';
  }

  @override
  String settingsBackupRestore_excelMissingColumn(String sheet, String column) {
    return 'The $sheet sheet is missing the $column column.';
  }

  @override
  String settingsBackupRestore_excelEmptySheet(String sheet) {
    return 'The $sheet sheet has no rows.';
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

    return '$sheet, row $rowString: $column must be filled.';
  }

  @override
  String get settingsBackupRestore_restoreDetailsSheets => 'Sheets';

  @override
  String get settingsBackupRestore_restoreExcelTitle =>
      'Replace the data in these sheets?';

  @override
  String get settingsBackupRestore_restoreExcelWarning =>
      'The sheets in this file replace those records on this device. Everything else is kept.';

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
      'Sessions Courts (Criminal)';

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
  String get settingsNotifications_keepOneOffset =>
      'Keep at Least One Day Offset.';

  @override
  String get settingsNotifications_offsetSameDay => 'The Same Day';

  @override
  String get settingsNotifications_offsetDayBefore => 'The Day Before';

  @override
  String settingsNotifications_offsetBeforeDays(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String daysString = daysNumberFormat.format(days);

    return 'Before $daysString Days';
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
  String get settingsBatteryGuide_batteryAllowed =>
      'Battery Usage Is Already Unrestricted';

  @override
  String get settingsBatteryGuide_autoStartDone =>
      'Auto-Start Marked As Done By You';

  @override
  String get settingsBatteryGuide_markDone => 'Mark As Done';

  @override
  String get settingsBatteryGuide_markNotDone => 'Mark As Not Done';

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
  String get settingsViewSettings_sectionFontSize => 'Font Size';

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
  String get settingsViewSettings_fontSizeDefault => 'Default';

  @override
  String settingsViewSettings_fontSizeMore(String step) {
    return '+$step';
  }

  @override
  String settingsViewSettings_fontSizeLess(String step) {
    return '-$step';
  }

  @override
  String get settingsViewSettings_fontSizeIncrease => 'Increase Font Size';

  @override
  String get settingsViewSettings_fontSizeDecrease => 'Decrease Font Size';

  @override
  String get settingsViewSettings_fontSizeReset => 'Reset to Default';

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
  String get settingsGuidelines_accountTitle => 'Your Account';

  @override
  String get settingsGuidelines_accountBody1 =>
      'You create your account the first time you open the app — it takes a moment, and it is required for everyone, the free plan included. Everything you record afterwards belongs to that account.';

  @override
  String get settingsGuidelines_accountBody2 =>
      'Every account starts on the free plan, which is local to this device, and stays there until you upgrade. Because your diary was yours from the first case, upgrading needs nothing re-entered or transferred — cloud backup simply switches on.';

  @override
  String get settingsGuidelines_dailyCauseListTitle => 'Daily Cause List';

  @override
  String get settingsGuidelines_dailyCauseListBody1 =>
      'The Daily Cause List shows the hearings you have recorded for a single date, grouped by court in your court hierarchy, with a total for the day. Use the calendar to choose another date; today is selected by default.';

  @override
  String get settingsGuidelines_dailyCauseListBody2 =>
      'The list is built from your own case records, so it is only as accurate as they are. Keep each case\'s next date and latest step current, and record a hearing from the list itself as soon as you leave the courtroom. Cases whose hearing date has passed without an update appear under Overdue Dates until you record the outcome.';

  @override
  String get settingsGuidelines_allCasesTitle => 'All Cases';

  @override
  String get settingsGuidelines_allCasesBody1 =>
      'Every case you have, with the Active and Disposed counts above the list — tap a count to open that list. Search by party, counsel, case number or phone, narrow the list with Filter by Court and Newest/Oldest First, and switch between card and table view.';

  @override
  String get settingsGuidelines_activeCasesTitle => 'Active Cases';

  @override
  String get settingsGuidelines_activeCasesBody1 =>
      'Only the cases still running, with nothing disposed mixed in. Open one here to update it or to record the outcome of a hearing.';

  @override
  String get settingsGuidelines_overdueDatesTitle => 'Overdue Dates';

  @override
  String get settingsGuidelines_overdueDatesBody1 =>
      'Cases whose hearing date has passed without a recorded outcome, grouped by court and showing when each was last updated. Recording a new step or result removes the case from the list.';

  @override
  String get settingsGuidelines_upcomingCasesTitle => 'Upcoming Cases';

  @override
  String get settingsGuidelines_upcomingCasesBody1 =>
      'Hearings grouped by date, from tomorrow to the end of the period you set in Settings > View Settings > Upcoming Cases Period — 7 days by default. This is the list to check before leaving for court.';

  @override
  String get settingsGuidelines_disposedCasesTitle => 'Disposed Cases';

  @override
  String get settingsGuidelines_disposedCasesBody1 =>
      'The cases you have closed, each showing its disposal date, parties, final note and latest history. There is no Add Case button here; the Help button explains how a case is marked as disposed.';

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
      'In the offline version nothing leaves your phone except the account details you signed up with — nothing about your cases. Keep your passphrase somewhere safe — where a backup exists but its passphrase is lost, the file cannot be opened by us or by anyone else.';

  @override
  String get settingsGuidelines_sectionFaqs => 'FAQs';

  @override
  String get settingsGuidelines_faqCatGettingStarted => 'Getting started';

  @override
  String get settingsGuidelines_faqCatGettingStartedQ1 =>
      'Does the app work without an internet connection?';

  @override
  String get settingsGuidelines_faqCatGettingStartedA1 =>
      'Yes — once your account exists. The app is built to work fully offline: adding and editing cases, the Daily Cause List, printing and backups all work with no connection. Your account is created once, when you first open the app, and does not need to be signed in again to use the diary. Online sync is not part of the offline version.';

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
  String get settingsGuidelines_faqCatGettingStartedQ9 =>
      'Do I need an account?';

  @override
  String get settingsGuidelines_faqCatGettingStartedA9 =>
      'Yes. An account is required for everyone, the free plan included, and you create it the first time you open the app. Your diary belongs to that account, so when you upgrade to premium your existing cases are already yours — cloud backup switches on with nothing re-entered, exported or transferred.';

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
      'Go to Settings > Backup & Restore and tap Backup to Local Storage. You choose where the file is saved and set a passphrase that encrypts it. Your account is already in place, so no internet connection is required.';

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
      'Yes. Every account starts on the free plan, which costs nothing, holds up to 50 cases and keeps them on this device. Premium raises that limit and will add cloud backup and sync when it launches.';

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
      'In the offline version, everything you enter is stored on your device in encrypted form. Nothing is sent to us or to anyone else. Your account is what makes the diary yours from the first case — on the free plan it carries no case data anywhere. Backup files are encrypted and can only be opened with the passphrase you set. When the online version launches, what it stores and where will be described in its own topic before you use it.';

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
      'Open Settings > About > Support and write to us there — the message opens already carrying your app version and your phone model. Describe what you were doing when the problem occurred. You can also write to adv.asadusjaman@gmail.com.';

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
  String get settingsAbout_moreAboutApp => 'More About the App';

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
      'Your diary and your backup files are stored on your device in encrypted form. Nothing is uploaded unless you send it.';

  @override
  String get settingsAbout_actionPending => 'Arrives in a later task';

  @override
  String get settingsUpdate_entry => 'Update';

  @override
  String get settingsUpdate_appUpdate => 'App Update';

  @override
  String get settingsUpdate_appUpdateSubtitle =>
      'Check For Updates And Update The App';

  @override
  String get settingsUpdate_autoUpdate => 'Auto Check For Update';

  @override
  String get settingsUpdate_autoUpdateSubtitle =>
      'Choose How Often To Check For Updates';

  @override
  String get settingsUpdate_networkTitle => 'Update Over Network';

  @override
  String get settingsUpdate_networkSubtitle =>
      'Choose Which Network Downloads The Update';

  @override
  String get settingsUpdate_networkWifi => 'Wi-Fi';

  @override
  String get settingsUpdate_networkMobileData => 'Mobile Data';

  @override
  String get settingsUpdate_currentVersion => 'Current Version:';

  @override
  String get settingsUpdate_checkForUpdate => 'Check For Update';

  @override
  String get settingsUpdate_checking => 'Checking For Update';

  @override
  String get settingsUpdate_updateNow => 'Update Now';

  @override
  String get settingsUpdate_later => 'Later';

  @override
  String get settingsUpdate_skipVersion => 'Skip This Version';

  @override
  String settingsUpdate_newerVersion(String version) {
    return 'There Is A Newer Version Available ($version).';
  }

  @override
  String get settingsUpdate_latest => 'You\'re On The Latest Version.';

  @override
  String get settingsUpdate_mobileDataTitle => 'Download Over Mobile Data?';

  @override
  String get settingsUpdate_mobileDataBody =>
      'You are on mobile data and the update is a large download. Continue, or switch to Wi-Fi to download it there.';

  @override
  String get settingsUpdate_mobileDataContinue => 'Continue';

  @override
  String get settingsUpdate_checkFailed =>
      'Could Not Check For An Update Right Now. Please Try Again Later.';

  @override
  String get settingsUpdate_downloadFailed =>
      'The Update Could Not Be Downloaded. Please Try Again Later.';

  @override
  String get settingsUpdate_installUnavailable =>
      'This Device Cannot Install An Update.';

  @override
  String get settingsUpdate_offlineToast =>
      'Please Connect To The Internet And Check For An Update.';

  @override
  String get settingsUpdate_frequencyOff => 'Off';

  @override
  String get settingsUpdate_frequencyEveryday => 'Every Day';

  @override
  String get settingsUpdate_frequencyEvery3Days => 'Every 3 Days';

  @override
  String get settingsUpdate_frequencyEvery7Days => 'Every 7 Days';

  @override
  String get settingsUpdate_frequencyEveryMonth => 'Every Month';

  @override
  String get settingsLegal_loadFailed =>
      'Could not open this document. Please try again.';

  @override
  String get settingsSupport_title => 'Support';

  @override
  String get settingsSupport_scopeTitle => 'Before You Write To Us';

  @override
  String get settingsSupport_scope =>
      'We can help you with the app itself: how a feature works, something that is not behaving as it should, or a backup that will not restore. We cannot see your diary — it stays on your phone — and we cannot check, confirm or look up a hearing date for you.';

  @override
  String get settingsSupport_faqLead =>
      'Most questions are already answered here.';

  @override
  String get settingsSupport_faqLink => 'Open Guidelines & FAQs';

  @override
  String get settingsSupport_channelsLabel => 'Write To Us';

  @override
  String get settingsSupport_channelWhatsApp => 'WhatsApp';

  @override
  String get settingsSupport_channelEmail => 'Email';

  @override
  String get settingsSupport_messageSubject => 'Legal Case Diary support';

  @override
  String get settingsSupport_messageIntro =>
      'Hello, I need help with Legal Case Diary.';

  @override
  String get settingsSupport_messageVersion => 'App version';

  @override
  String get settingsSupport_messagePhone => 'Phone';

  @override
  String get settingsSupport_messageLanguage => 'App language';

  @override
  String get settingsSupport_messagePrompt =>
      'What happened, and what I did just before it:';

  @override
  String get settingsSupport_warningTitle => 'Never Send These';

  @override
  String get settingsSupport_warningBody =>
      'Your passphrase, your diary database file, or a backup file. We will never ask for them, and a message that asks for them is not from us.';

  @override
  String get settingsSupport_replyTitle => 'When You Will Hear Back';

  @override
  String get settingsSupport_replyBody =>
      'Support is handled by the app\'s developer alongside court work, so a reply usually takes one to two working days (Sunday to Thursday). There is no phone line and no live chat — the answer comes back to the WhatsApp or email address you wrote from.';

  @override
  String get settingsSupport_unableToOpenWhatsApp =>
      'WhatsApp could not be opened.';

  @override
  String get settingsSupport_unableToOpenEmail =>
      'No email app could be opened.';

  @override
  String get settingsMoreAbout_title => 'More About the App';

  @override
  String get settingsMoreAbout_description =>
      'Legal Case Diary is a complete offline case diary built for lawyers in Bangladesh. It organises your cases and hearings into a daily cause list, tracks upcoming and overdue dates so nothing is missed, and keeps your notes and case references beside them. Everything is entered by you and stored on your device in encrypted form — no account is required, and no data leaves your phone unless you send it.';

  @override
  String get settingsMoreAbout_keyFeatures => 'Key Features';

  @override
  String get settingsMoreAbout_featureDailyCauseList => 'Daily Cause List';

  @override
  String get settingsMoreAbout_featureOfflineBackup => 'Offline Backup';

  @override
  String get settingsMoreAbout_featureCaseReferences => 'Case References';

  @override
  String get settingsMoreAbout_featureHearingNotifications =>
      'Hearing Notifications';

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
  String get print_serialShort => 'SL';

  @override
  String get print_dateLabel => 'Date';

  @override
  String get print_dayLabel => 'Day';

  @override
  String get print_monthLabel => 'Month';

  @override
  String get print_yearLabel => 'Year';

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

  @override
  String get auth_loginSubtitle => 'Log in to the app';

  @override
  String get auth_emailLabel => 'Email';

  @override
  String get auth_emailHint => 'example@gmail.com';

  @override
  String get auth_passwordLabel => 'Password';

  @override
  String get auth_passwordHint => '••••••••';

  @override
  String get auth_forgotPassword => 'Forgot Password?';

  @override
  String get auth_loginButton => 'Login';

  @override
  String get auth_orContinueWith => 'Or Continue With';

  @override
  String get auth_googleLogin => 'Login With Google';

  @override
  String get auth_googleSignup => 'Sign Up With Google';

  @override
  String get auth_noAccount => 'Don\'t have an account?';

  @override
  String get auth_signUpLink => 'Sign Up';

  @override
  String get auth_haveAccount => 'Already have an account?';

  @override
  String get auth_loginLink => 'Login';

  @override
  String get auth_signupTitle => 'Create Account';

  @override
  String get auth_signupSubtitle =>
      'Start a stress-free journey of case management.';

  @override
  String get auth_fullNameLabel => 'Full Name';

  @override
  String get auth_fullNameHint => 'Type your name.';

  @override
  String get auth_barAssociationLabel => 'Bar Association';

  @override
  String get auth_barAssociationHint =>
      'Name of your district bar association.';

  @override
  String get auth_emailAddressLabel => 'Email Address';

  @override
  String get auth_emailAddressHint => 'example@gmail.com';

  @override
  String get auth_passwordHelper => 'Must be at least 8 characters long.';

  @override
  String get auth_confirmPasswordLabel => 'Confirm Password';

  @override
  String get auth_accountTypeLabel => 'Account Type';

  @override
  String get auth_accountTypeIndividual => 'Individual';

  @override
  String get auth_accountTypeJoinFirm => 'Join Existing Firm';

  @override
  String get auth_inviteCodeLabel => 'Invite Code';

  @override
  String get auth_inviteCodeHint => 'ABCDE12345';

  @override
  String get auth_inviteCodeHelper =>
      'Ask your firm owner for a single-use code.';

  @override
  String get auth_termsAgreePrefix => 'I agree to the';

  @override
  String get auth_termsOfService => 'Terms of Service';

  @override
  String get auth_termsAgreeJoin => 'and';

  @override
  String get auth_privacyPolicy => 'Privacy Policy';

  @override
  String get auth_signUpButton => 'Sign Up';

  @override
  String get auth_showPassword => 'Show Password';

  @override
  String get auth_hidePassword => 'Hide Password';

  @override
  String get auth_continueWithoutAccount => 'Continue Without An Account';

  @override
  String get auth_continueWithoutAccountNote =>
      'Your cases stay on this device.';

  @override
  String get auth_checkEmailTitle => 'Check Your Email';

  @override
  String auth_checkEmailMessage(String email) {
    return 'We sent a confirmation link to $email. Open it, then log in.';
  }

  @override
  String get auth_backToLogin => 'Back To Login';

  @override
  String get auth_useTheApp => 'Use The App';

  @override
  String get auth_openMail => 'Open Mail';

  @override
  String get auth_unableToOpenMail => 'No mail app could be opened.';

  @override
  String get auth_resendEmail => 'Resend Email';

  @override
  String get auth_resendSent => 'A new confirmation email has been sent.';

  @override
  String get auth_changeEmail => 'Change Email Address';

  @override
  String get auth_changeEmailPasswordTitle => 'Confirm Your Password';

  @override
  String get auth_changeEmailPasswordPrompt =>
      'Enter this account\'s password to continue.';

  @override
  String get auth_changeEmailAlreadyConfirmed =>
      'That address is already confirmed. Log in instead.';

  @override
  String get auth_changeEmailRefused =>
      'That account already has data. Log in and delete it from Settings instead.';

  @override
  String get auth_emailConfirmedTitle => 'Email Confirmed!';

  @override
  String auth_emailConfirmedMessage(String email) {
    return 'Your email address $email is confirmed. You can use the app now.';
  }

  @override
  String get auth_forgotTitle => 'Reset Password';

  @override
  String get auth_forgotSubtitle =>
      'Enter your email and we will send a recovery code.';

  @override
  String get auth_recoveryLinkSubtitle =>
      'Choose A New Password For Your Account.';

  @override
  String get auth_sendCodeButton => 'Send Code';

  @override
  String get auth_recoveryCodeLabel => 'Recovery Code';

  @override
  String get auth_recoveryCodeHelper =>
      'Open the code we emailed you, then choose a new password.';

  @override
  String get auth_recoverySent => 'Code Sent';

  @override
  String get auth_newPasswordLabel => 'New Password';

  @override
  String get auth_setPasswordButton => 'Set New Password';

  @override
  String get auth_passwordUpdated => 'Your password has been updated.';

  @override
  String get auth_errorInvalidCredentials =>
      'Wrong email or password. Please try again.';

  @override
  String get auth_errorEmailNotConfirmed =>
      'Confirm your email address first — open the link we sent you.';

  @override
  String get auth_errorEmailInUse =>
      'That email already has an account. Log in instead.';

  @override
  String get auth_errorWeakPassword =>
      'Choose a password with at least 8 characters.';

  @override
  String get auth_errorRateLimited =>
      'Too many attempts. Please wait a few minutes and try again.';

  @override
  String get auth_errorInvalidCode =>
      'That invite code is not valid. Check it with your firm owner.';

  @override
  String get auth_errorTooManyAttempts =>
      'Too many attempts. Please try again later.';

  @override
  String get auth_errorFirmAdminOffline =>
      'Connect to the internet to manage your firm.';

  @override
  String get auth_errorPremiumRequired =>
      'Firm Mode Requires An Active Premium Subscription.';

  @override
  String get firm_errorServer =>
      'The server could not complete that request. Please try again.';

  @override
  String get firm_errorUnauthorized =>
      'Your account is not allowed to do that.';

  @override
  String get firm_errorUnavailable =>
      'Firm management is not available in this build.';

  @override
  String get auth_errorAlreadyMember =>
      'You are already a member of this firm.';

  @override
  String get auth_joinedFirm => 'You Have Joined The Firm.';

  @override
  String get auth_errorNetwork =>
      'No connection. Check your internet and try again.';

  @override
  String get auth_errorUnavailable => 'Sign-in is not available in this build.';

  @override
  String get auth_errorGoogleFailed =>
      'Google Sign-In Could Not Complete. Please Try Again.';

  @override
  String get auth_errorAccountMismatch =>
      'This device belongs to another account. Log in with that account, or restore a backup.';

  @override
  String get auth_errorUnknown => 'Something went wrong. Please try again.';

  @override
  String get auth_validationEmailRequired => 'Enter your email address.';

  @override
  String get auth_validationEmailInvalid => 'Enter a valid email address.';

  @override
  String get auth_validationPasswordRequired => 'Enter your password.';

  @override
  String get auth_validationPasswordTooShort => 'Use at least 8 characters.';

  @override
  String get auth_validationPasswordConfirmRequired => 'Confirm your password.';

  @override
  String get auth_validationPasswordMismatch => 'Both passwords must match.';

  @override
  String get auth_validationMandatory => 'This field is mandatory.';

  @override
  String get auth_validationInviteCodeRequired => 'Enter your invite code.';

  @override
  String get auth_validationTermsRequired =>
      'Accept the Terms of Service and Privacy Policy to continue.';

  @override
  String get auth_sessionExpired => 'Your Session Expired. Sign In Again.';

  @override
  String get auth_sessionExpiredAction => 'Sign In';

  @override
  String get manageAssociates_title => 'Manage Associates';

  @override
  String get manageAssociates_ownerOnly =>
      'Only The Firm Owner Can Manage Associates.';

  @override
  String get manageAssociates_sectionMembers => 'Associates';

  @override
  String get manageAssociates_addAssociate => 'Add Associate';

  @override
  String get manageAssociates_noMembers => 'No Associates Yet.';

  @override
  String get manageAssociates_unnamedMember => 'Unnamed Member';

  @override
  String get manageAssociates_createFirmIntro =>
      'Add Your First Associate To Create Your Firm And Work Together.';

  @override
  String get manageAssociates_firmNameLabel => 'Firm Name';

  @override
  String get manageAssociates_firmNameHint => 'Enter Your Chamber Or Firm Name';

  @override
  String get manageAssociates_createFirm => 'Create Firm';

  @override
  String get manageAssociates_goPremium => 'Go Premium';

  @override
  String get manageAssociates_inviteTitle => 'Invite Code';

  @override
  String get manageAssociates_inviteIntro =>
      'Share This Code With Your Associate. It Works Once, And This Is The Only Time It Is Shown.';

  @override
  String get manageAssociates_copyCode => 'Copy Code';

  @override
  String get manageAssociates_codeCopied => 'Code Copied.';

  @override
  String get manageAssociates_shareCode => 'Share';

  @override
  String get manageAssociates_shareFailed => 'Could Not Share The Code';

  @override
  String manageAssociates_inviteMessage(String code) {
    return 'Join My Firm On Legal Case Diary. Invite Code: $code';
  }

  @override
  String get manageAssociates_sectionInvites => 'Outstanding Invites';

  @override
  String get manageAssociates_noInvites => 'No Unused Invites.';

  @override
  String manageAssociates_inviteCreated(String date) {
    return 'Created $date';
  }

  @override
  String get manageAssociates_revokeInvite => 'Revoke';

  @override
  String get manageAssociates_revokeInviteTitle => 'Revoke This Invite?';

  @override
  String get manageAssociates_revokeInviteBody =>
      'The Code Will Stop Working Immediately.';

  @override
  String get manageAssociates_inviteRevoked => 'Invite Revoked.';

  @override
  String get manageAssociates_permissionsTitle => 'Permissions';

  @override
  String get manageAssociates_roleLabel => 'Role';

  @override
  String get manageAssociates_permissionAdd => 'Add Cases';

  @override
  String get manageAssociates_permissionEdit => 'Edit Cases';

  @override
  String get manageAssociates_permissionDelete => 'Delete Cases';

  @override
  String get manageAssociates_savePermissions => 'Save Permissions';

  @override
  String get manageAssociates_permissionsUpdated => 'Permissions Updated.';

  @override
  String get manageAssociates_removeAssociate => 'Remove From Firm';

  @override
  String get manageAssociates_removeAssociateTitle => 'Remove This Associate?';

  @override
  String get manageAssociates_removeAssociateBody =>
      'They Lose Access To The Firm\'s Cases Immediately. The Records They Authored Stay In The Firm.';

  @override
  String get manageAssociates_associateRemoved => 'Associate Removed.';

  @override
  String get syncNotice_permissionsChanged =>
      'Your Firm Permissions Changed; This Pending Action Was Not Applied.';

  @override
  String get syncNotice_clockSkew =>
      'Your Device Clock Is More Than Two Minutes Off From The Server. Synced Times May Be Wrong.';

  @override
  String get membershipRevoked_title => 'You Have Been Removed From The Firm';

  @override
  String get membershipRevoked_body =>
      'Your Firm Owner Removed This Account. You Can No Longer See Or Edit The Firm\'s Cases, And Anything Still Waiting To Sync Has Been Discarded. Log Out To Continue With An Individual Diary.';

  @override
  String get membershipRevoked_action => 'Log Out';

  @override
  String get membershipRevoked_logoutFailed => 'Could Not Log Out. Try Again.';

  @override
  String get deleteRequest_confirmTitle => 'Send A Deletion Request?';

  @override
  String get deleteRequest_confirmBody =>
      'A Firm Member With Delete Permission Has To Approve It Before The Record Is Removed.';

  @override
  String get deleteRequest_confirmSend => 'Send Request';

  @override
  String get deleteRequest_sent => 'Deletion Request Sent To Admin/Owner.';

  @override
  String get deleteRequest_failed => 'Could Not Send The Deletion Request.';

  @override
  String get deleteRequests_title => 'Delete Requests';

  @override
  String get deleteRequests_firmOnly =>
      'Delete Requests Are Only Available To Firm Members.';

  @override
  String get deleteRequests_toReview => 'Awaiting Your Review';

  @override
  String get deleteRequests_noneToReview =>
      'No Deletion Requests Awaiting Review.';

  @override
  String get deleteRequests_mine => 'My Requests';

  @override
  String get deleteRequests_noneMine =>
      'You Have Not Sent Any Deletion Requests.';

  @override
  String get deleteRequests_statusPending => 'Pending';

  @override
  String get deleteRequests_statusApproved => 'Approved';

  @override
  String get deleteRequests_statusRejected => 'Rejected';

  @override
  String get deleteRequests_statusStale => 'Needs Reconfirmation';

  @override
  String deleteRequests_requestedBy(String name) {
    return 'Requested By $name';
  }

  @override
  String deleteRequests_requestedOn(String date) {
    return 'Requested On $date';
  }

  @override
  String get deleteRequests_unnamed => 'A Record';

  @override
  String get deleteRequests_entityCase => 'Case';

  @override
  String get deleteRequests_entityCaseHistory => 'Case History';

  @override
  String get deleteRequests_entityNote => 'Note';

  @override
  String get deleteRequests_entityReference => 'Reference';

  @override
  String get deleteRequests_entityUnknown => 'Record';

  @override
  String get deleteRequests_reviewTitle => 'Review Deletion Request';

  @override
  String get deleteRequests_snapshot => 'Requested Record';

  @override
  String get deleteRequests_noteLabel => 'Review Note (Optional)';

  @override
  String get deleteRequests_noteHint => 'Add A Reason';

  @override
  String get deleteRequests_approve => 'Approve';

  @override
  String get deleteRequests_reconfirm => 'Reconfirm';

  @override
  String get deleteRequests_reject => 'Reject';

  @override
  String get deleteRequests_approveTitle => 'Approve Deletion?';

  @override
  String get deleteRequests_approveBody =>
      'The Record Will Be Deleted For Everyone In The Firm.';

  @override
  String get deleteRequests_rejectTitle => 'Reject Deletion Request?';

  @override
  String get deleteRequests_rejectBody =>
      'The Record Stays. The Requester Is Told Your Decision.';

  @override
  String get deleteRequests_approved => 'Deletion Approved.';

  @override
  String get deleteRequests_rejected => 'Deletion Request Rejected.';

  @override
  String get deleteRequests_failed =>
      'Could Not Complete The Review. Try Again.';

  @override
  String get deleteRequests_staleTitle => 'This Record Changed';

  @override
  String get deleteRequests_staleBody =>
      'It Changed After The Request Was Made. The Details Below Are What Exists Now; Reconfirm To Delete This Current Version.';

  @override
  String get deleteRequests_fieldCaseNumber => 'Case Number';

  @override
  String get deleteRequests_fieldCaseType => 'Case Type';

  @override
  String get deleteRequests_fieldPetitioner => 'Petitioner';

  @override
  String get deleteRequests_fieldRespondent => 'Respondent';

  @override
  String get deleteRequests_fieldStep => 'Step';

  @override
  String get deleteRequests_fieldResult => 'Result';

  @override
  String get deleteRequests_fieldTitle => 'Title';

  @override
  String get deleteRequests_fieldBody => 'Note';

  @override
  String get deleteRequests_fieldReference => 'Reference And Page No';

  @override
  String get deleteRequests_fieldDescription => 'Title And Description';

  @override
  String get deleteRequests_unknownRequester => 'A Firm Member';

  @override
  String get deleteRequests_edit => 'Edit Request';

  @override
  String get deleteRequests_withdraw => 'Withdraw Request';

  @override
  String get deleteRequests_withdrawTitle => 'Withdraw This Deletion Request?';

  @override
  String get deleteRequests_withdrawBody =>
      'The Record Will Not Be Deleted, And The Request Leaves The Reviewers\' Queue.';

  @override
  String get deleteRequests_withdrawn => 'Request Withdrawn.';

  @override
  String get deleteRequests_updated => 'Request Updated.';

  @override
  String get deleteRequests_updateFailed => 'Could Not Update The Request.';

  @override
  String get deleteRequests_withdrawFailed => 'Could Not Withdraw The Request.';

  @override
  String get payments_goPremium => 'Go Premium';

  @override
  String get payments_checkoutTitle => 'Checkout';

  @override
  String get payments_planSummaryTitle => 'Plan';

  @override
  String payments_amountValue(String amount) {
    return '৳$amount';
  }

  @override
  String get payments_transferTitle => 'Transfer Instructions';

  @override
  String payments_transferBody(String amount) {
    return 'Send ৳$amount to one of the numbers below, then enter your payment details.';
  }

  @override
  String get payments_copy => 'Copy';

  @override
  String get payments_copied => 'Number Copied.';

  @override
  String get payments_formTitle => 'Payment Details';

  @override
  String get payments_methodLabel => 'Payment Method';

  @override
  String get payments_methodBkash => 'bKash';

  @override
  String get payments_methodNagad => 'Nagad';

  @override
  String get payments_methodRocket => 'Rocket';

  @override
  String get payments_phoneLabel => 'Sender Phone Number';

  @override
  String get payments_phoneHint => '01XXXXXXXXX';

  @override
  String get payments_trxLabel => 'Transaction ID (TrxID)';

  @override
  String get payments_trxHint => 'Enter The TrxID';

  @override
  String get payments_submit => 'Submit Payment';

  @override
  String get payments_numberUnavailable =>
      'Payment numbers are unavailable right now. Please try again later.';

  @override
  String get payments_errorPhone => 'Enter A Valid Mobile Number.';

  @override
  String get payments_errorTrx => 'Enter The Transaction ID.';

  @override
  String get payments_submitFailed => 'Submission failed. Tap Retry.';

  @override
  String get payments_limitReached =>
      'You\'ve reached today\'s submission limit. Please try again tomorrow.';

  @override
  String get payments_duplicateTrx =>
      'This Transaction ID Has Already Been Submitted.';

  @override
  String get payments_submitSuccess =>
      'Submission Received. We Will Verify It Shortly.';

  @override
  String get payments_historyTitle => 'Payment History';

  @override
  String get payments_noSubmissions => 'No Payments Submitted Yet.';

  @override
  String get payments_statusPending => 'Pending';

  @override
  String get payments_statusApproved => 'Approved';

  @override
  String get payments_statusRejected => 'Rejected';

  @override
  String get payments_notesLabel => 'Note';

  @override
  String get subscription_bannerGrace =>
      'Your subscription expired. Renew to avoid losing sync access.';

  @override
  String get subscription_bannerExpiredOwner =>
      'Your premium subscription has ended. Renew your subscription to restore sync.';

  @override
  String get subscription_bannerExpiredAssociate =>
      'Your firm\'s premium subscription has ended. Contact your firm owner to renew.';

  @override
  String get settingsManageAccount_plan => 'Plan';

  @override
  String get settingsManageAccount_expiry => 'Expiry';

  @override
  String get settingsDiagnostics_title => 'Diagnostics';

  @override
  String get settingsDiagnostics_hint =>
      'Errors This App Has Recorded. Case Data, Passwords And Tokens Are Never Written Here.';

  @override
  String get settingsDiagnostics_empty => 'No Errors Have Been Recorded.';

  @override
  String get settingsDiagnostics_clear => 'Clear Log';

  @override
  String get settingsDiagnostics_cleared => 'Error Log Cleared.';

  @override
  String get settingsDiagnostics_copy => 'Copy Diagnostics';

  @override
  String get settingsDiagnostics_copied =>
      'Diagnostics Copied. Paste Them Into A Message To Us.';

  @override
  String get settingsAppLock_title => 'App Lock';

  @override
  String get settingsAppLock_setup => 'Setup App Lock';

  @override
  String get settingsAppLock_changePin => 'Change App Lock Pin';

  @override
  String get settingsAppLock_enableFingerprint => 'Enable Fingerprint';

  @override
  String get settingsAppLock_disableFingerprint => 'Disable Fingerprint';

  @override
  String get settingsAppLock_whenToAsk => 'When To Ask For The Pin';

  @override
  String get settingsAppLock_whenAppStarts => 'When The App Starts';

  @override
  String get settingsAppLock_whenAppOpensAndReturns =>
      'Every Time The App Opens';

  @override
  String settingsAppLock_choosePin(String digits) {
    return 'Choose A $digits-Digit PIN';
  }

  @override
  String get settingsAppLock_confirmPin => 'Confirm Your PIN';

  @override
  String get settingsAppLock_pinMismatch =>
      'The PINs Do Not Match. Start Again.';

  @override
  String get settingsAppLock_setupDone => 'App Lock Is On.';

  @override
  String get settingsAppLock_setupFailed =>
      'The PIN Could Not Be Saved. Try Again.';

  @override
  String get settingsAppLock_enterCurrentPin => 'Enter Your Current PIN';

  @override
  String get settingsAppLock_newPin => 'Enter A New PIN';

  @override
  String get settingsAppLock_pinChanged => 'App Lock PIN Changed.';

  @override
  String get settingsAppLock_currentPinWrong => 'That PIN Is Not Correct.';

  @override
  String get settingsAppLock_unlockTitle => 'Enter Your PIN To Unlock';

  @override
  String get settingsAppLock_wrongPin => 'Wrong PIN. Try Again.';

  @override
  String settingsAppLock_tooManyAttempts(String seconds) {
    return 'Too Many Attempts. Try Again In $seconds Seconds.';
  }

  @override
  String get settingsAppLock_verifyForFingerprint =>
      'Verify Your Identity For App Lock';

  @override
  String get settingsAppLock_fingerprintEnabled =>
      'Fingerprint Unlock Enabled.';

  @override
  String get settingsAppLock_fingerprintDisabled =>
      'Fingerprint Unlock Disabled.';

  @override
  String get settingsAppLock_fingerprintUnavailable =>
      'No Fingerprint Is Available On This Device.';

  @override
  String get settingsAppLock_useFingerprint => 'Unlock With Fingerprint';

  @override
  String get settingsAppLock_turnOff => 'Turn Off App Lock';

  @override
  String get settingsAppLock_turnOffTitle => 'Turn Off App Lock?';

  @override
  String get settingsAppLock_turnOffBody =>
      'The app will open without a PIN or fingerprint until you set App Lock up again.';

  @override
  String get settingsAppLock_turnOffConfirm => 'Turn Off';

  @override
  String get settingsAppLock_turnedOff => 'App Lock Is Off.';
}
