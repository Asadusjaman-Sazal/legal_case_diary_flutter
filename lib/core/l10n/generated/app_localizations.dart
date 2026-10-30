import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_bn.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('bn'),
    Locale('en'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Legal Case Diary'**
  String get appName;

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Legal Case Diary'**
  String get appTitle;

  /// No description provided for @app_fatalError.
  ///
  /// In en, this message translates to:
  /// **'Fatal error: {message}'**
  String app_fatalError(String message);

  /// No description provided for @app_openingDiary.
  ///
  /// In en, this message translates to:
  /// **'Opening case diary…'**
  String get app_openingDiary;

  /// No description provided for @app_resettingDatabase.
  ///
  /// In en, this message translates to:
  /// **'Resetting local database…'**
  String get app_resettingDatabase;

  /// No description provided for @nav_upcomingCases.
  ///
  /// In en, this message translates to:
  /// **'Upcoming Cases'**
  String get nav_upcomingCases;

  /// No description provided for @nav_dailyCauseList.
  ///
  /// In en, this message translates to:
  /// **'Daily Cause List'**
  String get nav_dailyCauseList;

  /// No description provided for @nav_allCases.
  ///
  /// In en, this message translates to:
  /// **'All Cases'**
  String get nav_allCases;

  /// No description provided for @nav_disposedCases.
  ///
  /// In en, this message translates to:
  /// **'Disposed Cases'**
  String get nav_disposedCases;

  /// No description provided for @nav_caseReference.
  ///
  /// In en, this message translates to:
  /// **'Case Reference'**
  String get nav_caseReference;

  /// No description provided for @nav_notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get nav_notes;

  /// No description provided for @nav_settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get nav_settings;

  /// No description provided for @nav_print.
  ///
  /// In en, this message translates to:
  /// **'Print'**
  String get nav_print;

  /// No description provided for @nav_share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get nav_share;

  /// No description provided for @nav_activeCases.
  ///
  /// In en, this message translates to:
  /// **'Active Cases'**
  String get nav_activeCases;

  /// No description provided for @nav_overdueDates.
  ///
  /// In en, this message translates to:
  /// **'Overdue Dates'**
  String get nav_overdueDates;

  /// No description provided for @nav_adminPanel.
  ///
  /// In en, this message translates to:
  /// **'Admin Panel'**
  String get nav_adminPanel;

  /// No description provided for @drawerOf.
  ///
  /// In en, this message translates to:
  /// **'of'**
  String get drawerOf;

  /// No description provided for @drawer_rateApp.
  ///
  /// In en, this message translates to:
  /// **'Rate App'**
  String get drawer_rateApp;

  /// No description provided for @drawer_rateAppPending.
  ///
  /// In en, this message translates to:
  /// **'Rating opens with the Play Store release.'**
  String get drawer_rateAppPending;

  /// No description provided for @drawer_caseScreensShowAll.
  ///
  /// In en, this message translates to:
  /// **'Show All Case Screens'**
  String get drawer_caseScreensShowAll;

  /// No description provided for @drawer_caseScreensHide.
  ///
  /// In en, this message translates to:
  /// **'Show Fewer Case Screens'**
  String get drawer_caseScreensHide;

  /// Bundled app version, shown as the last line of the side menu.
  ///
  /// In en, this message translates to:
  /// **'V{version}'**
  String drawer_version(String version);

  /// No description provided for @allCasesScreen_title.
  ///
  /// In en, this message translates to:
  /// **'All Cases'**
  String get allCasesScreen_title;

  /// No description provided for @allCasesScreen_empty.
  ///
  /// In en, this message translates to:
  /// **'No case added yet. Tap + to add one.'**
  String get allCasesScreen_empty;

  /// No description provided for @allCasesScreen_activeCases.
  ///
  /// In en, this message translates to:
  /// **'Active Cases'**
  String get allCasesScreen_activeCases;

  /// No description provided for @allCasesScreen_disposedCases.
  ///
  /// In en, this message translates to:
  /// **'Disposed Cases'**
  String get allCasesScreen_disposedCases;

  /// No description provided for @allCasesScreen_filterByCourt.
  ///
  /// In en, this message translates to:
  /// **'Filter by Court'**
  String get allCasesScreen_filterByCourt;

  /// No description provided for @allCasesScreen_newestFirst.
  ///
  /// In en, this message translates to:
  /// **'Newest first'**
  String get allCasesScreen_newestFirst;

  /// No description provided for @allCasesScreen_oldestFirst.
  ///
  /// In en, this message translates to:
  /// **'Oldest first'**
  String get allCasesScreen_oldestFirst;

  /// No description provided for @allCasesScreen_caseType.
  ///
  /// In en, this message translates to:
  /// **'Case Type'**
  String get allCasesScreen_caseType;

  /// No description provided for @allCasesScreen_caseNumber.
  ///
  /// In en, this message translates to:
  /// **'Case No'**
  String get allCasesScreen_caseNumber;

  /// No description provided for @allCasesScreen_onBehalf.
  ///
  /// In en, this message translates to:
  /// **'On Behalf'**
  String get allCasesScreen_onBehalf;

  /// No description provided for @allCasesScreen_petitionerVsRespondent.
  ///
  /// In en, this message translates to:
  /// **'Petitioner Vs Respondent'**
  String get allCasesScreen_petitionerVsRespondent;

  /// No description provided for @caseCard_nextDate.
  ///
  /// In en, this message translates to:
  /// **'Next Date'**
  String get caseCard_nextDate;

  /// No description provided for @caseCard_previousDate.
  ///
  /// In en, this message translates to:
  /// **'Previous Date'**
  String get caseCard_previousDate;

  /// No description provided for @caseCard_lastStep.
  ///
  /// In en, this message translates to:
  /// **'Step'**
  String get caseCard_lastStep;

  /// No description provided for @allCasesScreen_phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get allCasesScreen_phone;

  /// No description provided for @allCasesScreen_message.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get allCasesScreen_message;

  /// No description provided for @allCasesScreen_unableToCall.
  ///
  /// In en, this message translates to:
  /// **'Unable to place a call.'**
  String get allCasesScreen_unableToCall;

  /// No description provided for @allCasesScreen_unableToMessage.
  ///
  /// In en, this message translates to:
  /// **'Unable to open messages.'**
  String get allCasesScreen_unableToMessage;

  /// No description provided for @allCasesScreen_update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get allCasesScreen_update;

  /// No description provided for @caseCard_disposed.
  ///
  /// In en, this message translates to:
  /// **'Disposed:'**
  String get caseCard_disposed;

  /// No description provided for @caseTable_serial.
  ///
  /// In en, this message translates to:
  /// **'Serial'**
  String get caseTable_serial;

  /// No description provided for @caseTable_disposed.
  ///
  /// In en, this message translates to:
  /// **'Disposed'**
  String get caseTable_disposed;

  /// No description provided for @activeCasesScreen_title.
  ///
  /// In en, this message translates to:
  /// **'Active Cases'**
  String get activeCasesScreen_title;

  /// No description provided for @activeCasesScreen_empty.
  ///
  /// In en, this message translates to:
  /// **'No active case to show. Tap + to add one.'**
  String get activeCasesScreen_empty;

  /// No description provided for @upcomingCasesScreen_title.
  ///
  /// In en, this message translates to:
  /// **'Upcoming Cases'**
  String get upcomingCasesScreen_title;

  /// No description provided for @upcomingCasesScreen_empty.
  ///
  /// In en, this message translates to:
  /// **'No upcoming case'**
  String get upcomingCasesScreen_empty;

  /// No description provided for @dailyCauseListScreen_title.
  ///
  /// In en, this message translates to:
  /// **'Daily Cause List'**
  String get dailyCauseListScreen_title;

  /// No description provided for @dailyCauseListScreen_today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get dailyCauseListScreen_today;

  /// No description provided for @dailyCauseListScreen_tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get dailyCauseListScreen_tomorrow;

  /// No description provided for @dailyCauseListScreen_calendarLabel.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get dailyCauseListScreen_calendarLabel;

  /// No description provided for @dailyCauseListScreen_noHearings.
  ///
  /// In en, this message translates to:
  /// **'No hearings scheduled for this date.'**
  String get dailyCauseListScreen_noHearings;

  /// No description provided for @dailyCauseListScreen_loadError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load cases: {message}'**
  String dailyCauseListScreen_loadError(String message);

  /// No description provided for @dailyCauseListScreen_totalHearings.
  ///
  /// In en, this message translates to:
  /// **'Total Hearings:'**
  String get dailyCauseListScreen_totalHearings;

  /// No description provided for @dailyCauseListScreen_selectYear.
  ///
  /// In en, this message translates to:
  /// **'Select Year'**
  String get dailyCauseListScreen_selectYear;

  /// No description provided for @dailyCauseListScreen_selectMonth.
  ///
  /// In en, this message translates to:
  /// **'Select Month'**
  String get dailyCauseListScreen_selectMonth;

  /// No description provided for @dailyCauseListScreen_noPhone.
  ///
  /// In en, this message translates to:
  /// **'No phone number for this case.'**
  String get dailyCauseListScreen_noPhone;

  /// No description provided for @dailyCauseListScreen_whatsappError.
  ///
  /// In en, this message translates to:
  /// **'Unable to open WhatsApp.'**
  String get dailyCauseListScreen_whatsappError;

  /// No description provided for @dailyCauseListScreen_callError.
  ///
  /// In en, this message translates to:
  /// **'Unable to place a call.'**
  String get dailyCauseListScreen_callError;

  /// No description provided for @dailyCauseListScreen_messageError.
  ///
  /// In en, this message translates to:
  /// **'Unable to open messages.'**
  String get dailyCauseListScreen_messageError;

  /// No description provided for @disposedCasesScreen_title.
  ///
  /// In en, this message translates to:
  /// **'Disposed Cases'**
  String get disposedCasesScreen_title;

  /// No description provided for @disposedCasesScreen_empty.
  ///
  /// In en, this message translates to:
  /// **'No disposed case'**
  String get disposedCasesScreen_empty;

  /// No description provided for @disposedCasesScreen_helpTitle.
  ///
  /// In en, this message translates to:
  /// **'How to set a case as disposed?'**
  String get disposedCasesScreen_helpTitle;

  /// No description provided for @disposedCasesScreen_helpBody.
  ///
  /// In en, this message translates to:
  /// **'During updating date, choose an appropriate step from the followings to move a disposed or inactive lower-court case from the Active Cases list to this list. For Appellate & High Court Division cases, enter a disposal keyword in the Result field instead. Note: The case will remain available in the All Cases list.'**
  String get disposedCasesScreen_helpBody;

  /// No description provided for @disposedCasesScreen_disposedSteps.
  ///
  /// In en, this message translates to:
  /// **'Disposed steps by court category'**
  String get disposedCasesScreen_disposedSteps;

  /// No description provided for @disposedCasesScreen_appellateHighCourtDivision.
  ///
  /// In en, this message translates to:
  /// **'Appellate Division & High Court Division'**
  String get disposedCasesScreen_appellateHighCourtDivision;

  /// No description provided for @disposedCasesScreen_gotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get disposedCasesScreen_gotIt;

  /// No description provided for @overdueDatesScreen_title.
  ///
  /// In en, this message translates to:
  /// **'Overdue Dates'**
  String get overdueDatesScreen_title;

  /// No description provided for @overdueDatesScreen_empty.
  ///
  /// In en, this message translates to:
  /// **'No overdue case'**
  String get overdueDatesScreen_empty;

  /// No description provided for @overdueDatesScreen_lastUpdated.
  ///
  /// In en, this message translates to:
  /// **'Last Updated'**
  String get overdueDatesScreen_lastUpdated;

  /// No description provided for @caseDetailsScreen_title.
  ///
  /// In en, this message translates to:
  /// **'Case Details'**
  String get caseDetailsScreen_title;

  /// No description provided for @caseDetailsScreen_delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get caseDetailsScreen_delete;

  /// No description provided for @caseDetailsScreen_editCase.
  ///
  /// In en, this message translates to:
  /// **'Edit Case'**
  String get caseDetailsScreen_editCase;

  /// No description provided for @caseDetailsScreen_close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get caseDetailsScreen_close;

  /// No description provided for @caseDetailsScreen_onBehalfOf.
  ///
  /// In en, this message translates to:
  /// **'On Behalf Of'**
  String get caseDetailsScreen_onBehalfOf;

  /// No description provided for @caseDetailsScreen_petitioner.
  ///
  /// In en, this message translates to:
  /// **'Petitioner'**
  String get caseDetailsScreen_petitioner;

  /// No description provided for @caseDetailsScreen_respondent.
  ///
  /// In en, this message translates to:
  /// **'Respondent'**
  String get caseDetailsScreen_respondent;

  /// No description provided for @caseDetailsScreen_leadCounsel.
  ///
  /// In en, this message translates to:
  /// **'Lead Counsel'**
  String get caseDetailsScreen_leadCounsel;

  /// No description provided for @caseDetailsScreen_caseTitleAndRemark.
  ///
  /// In en, this message translates to:
  /// **'Case Title & Remark'**
  String get caseDetailsScreen_caseTitleAndRemark;

  /// No description provided for @caseDetailsScreen_sectionsOrCaseTitle.
  ///
  /// In en, this message translates to:
  /// **'Sections or Case Title'**
  String get caseDetailsScreen_sectionsOrCaseTitle;

  /// No description provided for @caseDetailsScreen_remarksOrCaseSummary.
  ///
  /// In en, this message translates to:
  /// **'Remarks or Case Summary'**
  String get caseDetailsScreen_remarksOrCaseSummary;

  /// No description provided for @caseDetailsScreen_caseHistory.
  ///
  /// In en, this message translates to:
  /// **'Case History'**
  String get caseDetailsScreen_caseHistory;

  /// No description provided for @caseDetailsScreen_phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get caseDetailsScreen_phone;

  /// No description provided for @caseDetailsScreen_message.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get caseDetailsScreen_message;

  /// Total number of case history entries.
  ///
  /// In en, this message translates to:
  /// **'{count} Entries Total'**
  String caseDetailsScreen_entriesTotal(int count);

  /// No description provided for @caseDetailsScreen_historySaveError.
  ///
  /// In en, this message translates to:
  /// **'Unable to save the history entry: {message}'**
  String caseDetailsScreen_historySaveError(String message);

  /// No description provided for @caseDetailsScreen_noHistoryEntries.
  ///
  /// In en, this message translates to:
  /// **'No history entries yet.'**
  String get caseDetailsScreen_noHistoryEntries;

  /// No description provided for @caseDetailsScreen_showHistory.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get caseDetailsScreen_showHistory;

  /// No description provided for @caseDetailsScreen_hideHistory.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get caseDetailsScreen_hideHistory;

  /// Countdown shown on the Next Date highlight card.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{0 Days Remaining} =1{1 Day Remaining} other{{count} Days Remaining}}'**
  String caseDetailsScreen_daysRemaining(int count);

  /// Count shown on the Next Date highlight card when the date has passed.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 Day Ago} other{{count} Days Ago}}'**
  String caseDetailsScreen_daysAgo(int count);

  /// No description provided for @caseDetailsScreen_setReminder.
  ///
  /// In en, this message translates to:
  /// **'Set Reminder'**
  String get caseDetailsScreen_setReminder;

  /// No description provided for @caseDetailsScreen_editHistoryEntry.
  ///
  /// In en, this message translates to:
  /// **'Edit History Entry'**
  String get caseDetailsScreen_editHistoryEntry;

  /// No description provided for @caseDetailsScreen_caseNotFound.
  ///
  /// In en, this message translates to:
  /// **'Case not found.'**
  String get caseDetailsScreen_caseNotFound;

  /// No description provided for @caseDetailsScreen_otherInformation.
  ///
  /// In en, this message translates to:
  /// **'Other Information'**
  String get caseDetailsScreen_otherInformation;

  /// No description provided for @caseDetailsScreen_tenderNumber.
  ///
  /// In en, this message translates to:
  /// **'Tender Number'**
  String get caseDetailsScreen_tenderNumber;

  /// No description provided for @caseDetailsScreen_previousCourtCase.
  ///
  /// In en, this message translates to:
  /// **'Previous Court Case'**
  String get caseDetailsScreen_previousCourtCase;

  /// No description provided for @caseDetailsScreen_districtOfOrigin.
  ///
  /// In en, this message translates to:
  /// **'District of Origin'**
  String get caseDetailsScreen_districtOfOrigin;

  /// CASE DETAILS SCREEN
  ///
  /// In en, this message translates to:
  /// **'Unable to delete the case: {message}'**
  String caseDetailsScreen_deleteCaseError(String message);

  /// CASE DETAILS SCREEN
  ///
  /// In en, this message translates to:
  /// **'Unable to delete the history entry: {message}'**
  String caseDetailsScreen_deleteHistoryError(String message);

  /// CASE DETAILS SCREEN
  ///
  /// In en, this message translates to:
  /// **'Unable to load the case: {message}'**
  String caseDetailsScreen_loadError(String message);

  /// No description provided for @addEditCaseSheet_title.
  ///
  /// In en, this message translates to:
  /// **'Add Case'**
  String get addEditCaseSheet_title;

  /// No description provided for @addEditCaseSheet_editTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Case'**
  String get addEditCaseSheet_editTitle;

  /// No description provided for @addEditCaseSheet_higherOrLowerCourt.
  ///
  /// In en, this message translates to:
  /// **'Higher or Lower Court'**
  String get addEditCaseSheet_higherOrLowerCourt;

  /// No description provided for @addEditCaseSheet_division.
  ///
  /// In en, this message translates to:
  /// **'Division'**
  String get addEditCaseSheet_division;

  /// No description provided for @addEditCaseSheet_district.
  ///
  /// In en, this message translates to:
  /// **'District'**
  String get addEditCaseSheet_district;

  /// No description provided for @addEditCaseSheet_courtCategory.
  ///
  /// In en, this message translates to:
  /// **'Court Category'**
  String get addEditCaseSheet_courtCategory;

  /// No description provided for @addEditCaseSheet_nameOfCourt.
  ///
  /// In en, this message translates to:
  /// **'Name of Court'**
  String get addEditCaseSheet_nameOfCourt;

  /// No description provided for @addEditCaseSheet_honorableJudges.
  ///
  /// In en, this message translates to:
  /// **'Name of Honorable Judges\''**
  String get addEditCaseSheet_honorableJudges;

  /// No description provided for @addEditCaseSheet_caseCategory.
  ///
  /// In en, this message translates to:
  /// **'Case Category'**
  String get addEditCaseSheet_caseCategory;

  /// No description provided for @addEditCaseSheet_caseNumber.
  ///
  /// In en, this message translates to:
  /// **'Case Number'**
  String get addEditCaseSheet_caseNumber;

  /// No description provided for @addEditCaseSheet_tenderNumber.
  ///
  /// In en, this message translates to:
  /// **'Tender Number'**
  String get addEditCaseSheet_tenderNumber;

  /// No description provided for @addEditCaseSheet_previousCourtCase.
  ///
  /// In en, this message translates to:
  /// **'Previous Court Case'**
  String get addEditCaseSheet_previousCourtCase;

  /// No description provided for @addEditCaseSheet_districtOfOrigin.
  ///
  /// In en, this message translates to:
  /// **'District of Origin'**
  String get addEditCaseSheet_districtOfOrigin;

  /// No description provided for @addEditCaseSheet_petitioner.
  ///
  /// In en, this message translates to:
  /// **'Petitioner'**
  String get addEditCaseSheet_petitioner;

  /// No description provided for @addEditCaseSheet_respondent.
  ///
  /// In en, this message translates to:
  /// **'Respondent'**
  String get addEditCaseSheet_respondent;

  /// No description provided for @addEditCaseSheet_petitionerLeadCounsel.
  ///
  /// In en, this message translates to:
  /// **'Petitioner Lead Counsel'**
  String get addEditCaseSheet_petitionerLeadCounsel;

  /// No description provided for @addEditCaseSheet_respondentLeadCounsel.
  ///
  /// In en, this message translates to:
  /// **'Respondent Lead Counsel'**
  String get addEditCaseSheet_respondentLeadCounsel;

  /// No description provided for @addEditCaseSheet_onBehalf.
  ///
  /// In en, this message translates to:
  /// **'On Behalf'**
  String get addEditCaseSheet_onBehalf;

  /// No description provided for @addEditCaseSheet_partyPhone.
  ///
  /// In en, this message translates to:
  /// **'Party Phone No.'**
  String get addEditCaseSheet_partyPhone;

  /// No description provided for @addEditCaseSheet_year.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get addEditCaseSheet_year;

  /// No description provided for @addEditCaseSheet_caseTitleAndSection.
  ///
  /// In en, this message translates to:
  /// **'Case Title or Section'**
  String get addEditCaseSheet_caseTitleAndSection;

  /// No description provided for @addEditCaseSheet_caseRemarks.
  ///
  /// In en, this message translates to:
  /// **'Case Remarks'**
  String get addEditCaseSheet_caseRemarks;

  /// No description provided for @addEditCaseSheet_nextDate.
  ///
  /// In en, this message translates to:
  /// **'Next Date'**
  String get addEditCaseSheet_nextDate;

  /// No description provided for @quickUpdateCase_currentNextDate.
  ///
  /// In en, this message translates to:
  /// **'Current Next Date'**
  String get quickUpdateCase_currentNextDate;

  /// No description provided for @addEditCaseSheet_pickDate.
  ///
  /// In en, this message translates to:
  /// **'Pick a date'**
  String get addEditCaseSheet_pickDate;

  /// No description provided for @addEditCaseSheet_loadError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load case form data: {message}'**
  String addEditCaseSheet_loadError(String message);

  /// No description provided for @addEditCaseSheet_saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the case: {message}'**
  String addEditCaseSheet_saveFailed(String message);

  /// No description provided for @addEditCaseSheet_updateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update the case: {message}'**
  String addEditCaseSheet_updateFailed(String message);

  /// No description provided for @addEditCaseSheet_notification.
  ///
  /// In en, this message translates to:
  /// **'Notification'**
  String get addEditCaseSheet_notification;

  /// No description provided for @addEditCaseSheet_dayOffset.
  ///
  /// In en, this message translates to:
  /// **'Day Offset'**
  String get addEditCaseSheet_dayOffset;

  /// No description provided for @notificationTimePicker_title.
  ///
  /// In en, this message translates to:
  /// **'Select Time'**
  String get notificationTimePicker_title;

  /// No description provided for @addEditCaseSheet_offsetSameDay.
  ///
  /// In en, this message translates to:
  /// **'The same day'**
  String get addEditCaseSheet_offsetSameDay;

  /// No description provided for @addEditCaseSheet_offsetDayBefore.
  ///
  /// In en, this message translates to:
  /// **'The day before'**
  String get addEditCaseSheet_offsetDayBefore;

  /// Day-offset option for two or more days before the hearing, in the language's own digits.
  ///
  /// In en, this message translates to:
  /// **'Before {count} days'**
  String addEditCaseSheet_offsetDaysBefore(int count);

  /// No description provided for @addEditCaseSheet_step.
  ///
  /// In en, this message translates to:
  /// **'Step'**
  String get addEditCaseSheet_step;

  /// No description provided for @addEditCaseSheet_result.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get addEditCaseSheet_result;

  /// No description provided for @addEditCaseSheet_note.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get addEditCaseSheet_note;

  /// No description provided for @addEditCaseSheet_save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get addEditCaseSheet_save;

  /// No description provided for @addEditCaseSheet_sectionCourt.
  ///
  /// In en, this message translates to:
  /// **'Court & Case'**
  String get addEditCaseSheet_sectionCourt;

  /// No description provided for @addEditCaseSheet_sectionParties.
  ///
  /// In en, this message translates to:
  /// **'Parties'**
  String get addEditCaseSheet_sectionParties;

  /// No description provided for @addEditCaseSheet_sectionDetails.
  ///
  /// In en, this message translates to:
  /// **'Case Title & Remarks'**
  String get addEditCaseSheet_sectionDetails;

  /// No description provided for @addEditCaseSheet_sectionSchedule.
  ///
  /// In en, this message translates to:
  /// **'Next Date & Steps'**
  String get addEditCaseSheet_sectionSchedule;

  /// No description provided for @addEditCaseSheet_dependencyRequired.
  ///
  /// In en, this message translates to:
  /// **'Please select an option from {field} first.'**
  String addEditCaseSheet_dependencyRequired(String field);

  /// No description provided for @customDropdown_clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get customDropdown_clear;

  /// No description provided for @customDropdown_selected.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get customDropdown_selected;

  /// No description provided for @casesModal_addCase.
  ///
  /// In en, this message translates to:
  /// **'Add Case'**
  String get casesModal_addCase;

  /// No description provided for @casesModal_search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get casesModal_search;

  /// No description provided for @casesModal_viewCompact.
  ///
  /// In en, this message translates to:
  /// **'Compact View'**
  String get casesModal_viewCompact;

  /// No description provided for @casesModal_viewExpanded.
  ///
  /// In en, this message translates to:
  /// **'Expanded View'**
  String get casesModal_viewExpanded;

  /// No description provided for @casesModal_help.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get casesModal_help;

  /// No description provided for @customDropdown_selectOption.
  ///
  /// In en, this message translates to:
  /// **'Select an option'**
  String get customDropdown_selectOption;

  /// No description provided for @customDropdown_search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get customDropdown_search;

  /// No description provided for @customDropdown_noResults.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get customDropdown_noResults;

  /// No description provided for @customDropdown_done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get customDropdown_done;

  /// No description provided for @casesContact_openWith.
  ///
  /// In en, this message translates to:
  /// **'Open with'**
  String get casesContact_openWith;

  /// No description provided for @casesContact_whatsapp.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp'**
  String get casesContact_whatsapp;

  /// No description provided for @casesContact_message.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get casesContact_message;

  /// No description provided for @casesContact_phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get casesContact_phone;

  /// No description provided for @casesContact_unableToOpenApp.
  ///
  /// In en, this message translates to:
  /// **'Unable to open the app.'**
  String get casesContact_unableToOpenApp;

  /// No description provided for @casesContact_unableToOpenWhatsApp.
  ///
  /// In en, this message translates to:
  /// **'Unable to open WhatsApp.'**
  String get casesContact_unableToOpenWhatsApp;

  /// No description provided for @casesContact_unableToCall.
  ///
  /// In en, this message translates to:
  /// **'Unable to place a call.'**
  String get casesContact_unableToCall;

  /// No description provided for @casesContact_unableToMessage.
  ///
  /// In en, this message translates to:
  /// **'Unable to open messages.'**
  String get casesContact_unableToMessage;

  /// CASE CONTACT SHEET + LIST ERRORS
  ///
  /// In en, this message translates to:
  /// **'Unable to load cases: {message}'**
  String casesScreen_loadError(String message);

  /// No description provided for @notesScreen_title.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notesScreen_title;

  /// No description provided for @notesScreen_delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get notesScreen_delete;

  /// No description provided for @notesScreen_pin.
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get notesScreen_pin;

  /// No description provided for @notesScreen_modified.
  ///
  /// In en, this message translates to:
  /// **'Modified'**
  String get notesScreen_modified;

  /// No description provided for @notesScreen_empty.
  ///
  /// In en, this message translates to:
  /// **'No notes yet. Tap + to add one.'**
  String get notesScreen_empty;

  /// No description provided for @notesScreen_noteTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get notesScreen_noteTitle;

  /// No description provided for @notesScreen_noteBody.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get notesScreen_noteBody;

  /// No description provided for @notesScreen_noteBodyPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Enter your note here...'**
  String get notesScreen_noteBodyPlaceholder;

  /// No description provided for @notesScreen_drafting.
  ///
  /// In en, this message translates to:
  /// **'Drafting...'**
  String get notesScreen_drafting;

  /// No description provided for @notesScreen_noteDeleted.
  ///
  /// In en, this message translates to:
  /// **'Note deleted'**
  String get notesScreen_noteDeleted;

  /// No description provided for @notesScreen_undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get notesScreen_undo;

  /// No description provided for @notesScreen_newTextNote.
  ///
  /// In en, this message translates to:
  /// **'Text Note'**
  String get notesScreen_newTextNote;

  /// No description provided for @notesScreen_newTodo.
  ///
  /// In en, this message translates to:
  /// **'To-Do'**
  String get notesScreen_newTodo;

  /// No description provided for @notesScreen_listItemHint.
  ///
  /// In en, this message translates to:
  /// **'List Item'**
  String get notesScreen_listItemHint;

  /// No description provided for @notesScreen_addItem.
  ///
  /// In en, this message translates to:
  /// **'Add Item'**
  String get notesScreen_addItem;

  /// No description provided for @notesScreen_removeItem.
  ///
  /// In en, this message translates to:
  /// **'Remove Item'**
  String get notesScreen_removeItem;

  /// How many checklist items a to-do note's card did not have room to show, in the language's own digits.
  ///
  /// In en, this message translates to:
  /// **'+{count} More'**
  String notesScreen_itemsMore(int count);

  /// No description provided for @caseReferenceScreen_title.
  ///
  /// In en, this message translates to:
  /// **'Case Reference'**
  String get caseReferenceScreen_title;

  /// No description provided for @caseReferenceScreen_referenceAndPageNo.
  ///
  /// In en, this message translates to:
  /// **'Reference & Page No'**
  String get caseReferenceScreen_referenceAndPageNo;

  /// No description provided for @caseReferenceScreen_statute.
  ///
  /// In en, this message translates to:
  /// **'Statute'**
  String get caseReferenceScreen_statute;

  /// No description provided for @caseReferenceScreen_sectionOrArticle.
  ///
  /// In en, this message translates to:
  /// **'Section/Article'**
  String get caseReferenceScreen_sectionOrArticle;

  /// No description provided for @caseReferenceScreen_titleAndDescription.
  ///
  /// In en, this message translates to:
  /// **'Title & Description'**
  String get caseReferenceScreen_titleAndDescription;

  /// No description provided for @caseReferenceScreen_commentsNotes.
  ///
  /// In en, this message translates to:
  /// **'Comments/Notes'**
  String get caseReferenceScreen_commentsNotes;

  /// No description provided for @caseReferenceScreen_empty.
  ///
  /// In en, this message translates to:
  /// **'No references yet. Tap + to add one.'**
  String get caseReferenceScreen_empty;

  /// No description provided for @caseReferenceScreen_addTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Case Reference'**
  String get caseReferenceScreen_addTitle;

  /// No description provided for @caseReferenceScreen_editTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Case Reference'**
  String get caseReferenceScreen_editTitle;

  /// No description provided for @caseReferenceScreen_pin.
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get caseReferenceScreen_pin;

  /// No description provided for @caseReferenceScreen_unpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get caseReferenceScreen_unpin;

  /// No description provided for @caseReferenceScreen_saved.
  ///
  /// In en, this message translates to:
  /// **'Reference saved'**
  String get caseReferenceScreen_saved;

  /// No description provided for @caseReferenceScreen_saveTitle.
  ///
  /// In en, this message translates to:
  /// **'Save Reference'**
  String get caseReferenceScreen_saveTitle;

  /// No description provided for @caseReferenceScreen_deleted.
  ///
  /// In en, this message translates to:
  /// **'Reference deleted'**
  String get caseReferenceScreen_deleted;

  /// No description provided for @caseReferenceScreen_referenceDeleted.
  ///
  /// In en, this message translates to:
  /// **'Reference deleted'**
  String get caseReferenceScreen_referenceDeleted;

  /// No description provided for @caseReferenceScreen_undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get caseReferenceScreen_undo;

  /// No description provided for @caseReferenceScreen_refPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'e.g. 25 DLR (AD) 142'**
  String get caseReferenceScreen_refPlaceholder;

  /// No description provided for @caseReferenceScreen_statutePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'e.g. CRPC'**
  String get caseReferenceScreen_statutePlaceholder;

  /// No description provided for @caseReferenceScreen_sectionPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'e.g. Section 54'**
  String get caseReferenceScreen_sectionPlaceholder;

  /// No description provided for @caseReferenceScreen_titlePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Title & description'**
  String get caseReferenceScreen_titlePlaceholder;

  /// No description provided for @caseReferenceScreen_commentsPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Add comments or private notes here...'**
  String get caseReferenceScreen_commentsPlaceholder;

  /// No description provided for @sync_idle.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get sync_idle;

  /// No description provided for @sync_syncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get sync_syncing;

  /// No description provided for @sync_success.
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get sync_success;

  /// No description provided for @sync_paused.
  ///
  /// In en, this message translates to:
  /// **'Sync paused'**
  String get sync_paused;

  /// No description provided for @sync_error.
  ///
  /// In en, this message translates to:
  /// **'Sync error'**
  String get sync_error;

  /// No description provided for @sync_unavailable.
  ///
  /// In en, this message translates to:
  /// **'Sync requires a premium subscription'**
  String get sync_unavailable;

  /// No description provided for @sync_pendingBadge.
  ///
  /// In en, this message translates to:
  /// **'{count} waiting to sync'**
  String sync_pendingBadge(int count);

  /// No description provided for @sync_offline.
  ///
  /// In en, this message translates to:
  /// **'No Connection'**
  String get sync_offline;

  /// No description provided for @sync_permissionsChanged.
  ///
  /// In en, this message translates to:
  /// **'Your firm permissions changed; this pending action was not applied.'**
  String get sync_permissionsChanged;

  /// No description provided for @sync_clockSkewWarning.
  ///
  /// In en, this message translates to:
  /// **'Your device clock appears incorrect. Please fix it to ensure reliable syncing.'**
  String get sync_clockSkewWarning;

  /// No description provided for @syncConflict_bannerMessage.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{A Conflict Needs Review} other{{count} Conflicts Need Review}}'**
  String syncConflict_bannerMessage(int count);

  /// No description provided for @syncConflict_bannerAction.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get syncConflict_bannerAction;

  /// No description provided for @syncConflict_title.
  ///
  /// In en, this message translates to:
  /// **'Review Conflict'**
  String get syncConflict_title;

  /// No description provided for @syncConflict_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Another Device Changed This Record'**
  String get syncConflict_subtitle;

  /// No description provided for @syncConflict_subtitleMember.
  ///
  /// In en, this message translates to:
  /// **'A Chamber Member Changed This Record'**
  String get syncConflict_subtitleMember;

  /// No description provided for @syncConflict_editedBy.
  ///
  /// In en, this message translates to:
  /// **'Edited By {name}'**
  String syncConflict_editedBy(String name);

  /// No description provided for @syncConflict_unknownEditor.
  ///
  /// In en, this message translates to:
  /// **'Another Device'**
  String get syncConflict_unknownEditor;

  /// No description provided for @syncConflict_intro.
  ///
  /// In en, this message translates to:
  /// **'You and another device changed the same fields. Choose the value to keep for each one.'**
  String get syncConflict_intro;

  /// No description provided for @syncConflict_keepServer.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get syncConflict_keepServer;

  /// No description provided for @syncConflict_keepMine.
  ///
  /// In en, this message translates to:
  /// **'Mine'**
  String get syncConflict_keepMine;

  /// No description provided for @syncConflict_tombstoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Deleted On The Server'**
  String get syncConflict_tombstoneTitle;

  /// No description provided for @syncConflict_tombstoneBody.
  ///
  /// In en, this message translates to:
  /// **'This record was deleted on another device. Your saved changes are still here — choose what happens to them.'**
  String get syncConflict_tombstoneBody;

  /// No description provided for @syncConflict_rebaseOntoNewRecord.
  ///
  /// In en, this message translates to:
  /// **'Keep As A New Record'**
  String get syncConflict_rebaseOntoNewRecord;

  /// No description provided for @syncConflict_discard.
  ///
  /// In en, this message translates to:
  /// **'Discard My Changes'**
  String get syncConflict_discard;

  /// No description provided for @syncConflict_discardConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard Your Changes?'**
  String get syncConflict_discardConfirmTitle;

  /// No description provided for @syncConflict_discardConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'The server version will replace your unsynced changes. This cannot be undone.'**
  String get syncConflict_discardConfirmBody;

  /// No description provided for @syncConflict_laterEditsTitle.
  ///
  /// In en, this message translates to:
  /// **'Later Saved Changes'**
  String get syncConflict_laterEditsTitle;

  /// No description provided for @syncConflict_laterEditsBody.
  ///
  /// In en, this message translates to:
  /// **'These edits are preserved until this conflict is answered.'**
  String get syncConflict_laterEditsBody;

  /// No description provided for @syncConflict_resolvedNotice.
  ///
  /// In en, this message translates to:
  /// **'This conflict is already resolved.'**
  String get syncConflict_resolvedNotice;

  /// No description provided for @syncConflict_missingNotice.
  ///
  /// In en, this message translates to:
  /// **'This conflict is no longer available.'**
  String get syncConflict_missingNotice;

  /// No description provided for @syncStatus_title.
  ///
  /// In en, this message translates to:
  /// **'Sync Status'**
  String get syncStatus_title;

  /// No description provided for @syncStatus_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Every Change Waiting To Be Sent'**
  String get syncStatus_subtitle;

  /// No description provided for @syncStatus_lastSyncedNever.
  ///
  /// In en, this message translates to:
  /// **'Never Synced'**
  String get syncStatus_lastSyncedNever;

  /// No description provided for @syncStatus_lastSynced.
  ///
  /// In en, this message translates to:
  /// **'Last Synced {time}'**
  String syncStatus_lastSynced(String time);

  /// No description provided for @syncStatus_filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get syncStatus_filterAll;

  /// No description provided for @syncStatus_filterPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get syncStatus_filterPending;

  /// No description provided for @syncStatus_filterConflicted.
  ///
  /// In en, this message translates to:
  /// **'Conflicted'**
  String get syncStatus_filterConflicted;

  /// No description provided for @syncStatus_filterBlocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get syncStatus_filterBlocked;

  /// No description provided for @syncStatus_statePending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get syncStatus_statePending;

  /// No description provided for @syncStatus_statePushing.
  ///
  /// In en, this message translates to:
  /// **'Sending'**
  String get syncStatus_statePushing;

  /// No description provided for @syncStatus_stateConflicted.
  ///
  /// In en, this message translates to:
  /// **'Conflicted'**
  String get syncStatus_stateConflicted;

  /// No description provided for @syncStatus_stateBlocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get syncStatus_stateBlocked;

  /// No description provided for @syncStatus_stateUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get syncStatus_stateUnknown;

  /// No description provided for @syncStatus_retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get syncStatus_retry;

  /// No description provided for @syncStatus_discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get syncStatus_discard;

  /// No description provided for @syncStatus_reviewConflict.
  ///
  /// In en, this message translates to:
  /// **'Review Conflict'**
  String get syncStatus_reviewConflict;

  /// No description provided for @syncStatus_moreActions.
  ///
  /// In en, this message translates to:
  /// **'More Actions'**
  String get syncStatus_moreActions;

  /// No description provided for @syncStatus_queued.
  ///
  /// In en, this message translates to:
  /// **'Queued {time}'**
  String syncStatus_queued(String time);

  /// No description provided for @syncStatus_attempted.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Attempted Once} other{Attempted {count} Times}}'**
  String syncStatus_attempted(int count);

  /// No description provided for @syncStatus_lastAttempt.
  ///
  /// In en, this message translates to:
  /// **'Last Attempt {time}'**
  String syncStatus_lastAttempt(String time);

  /// No description provided for @syncStatus_lastError.
  ///
  /// In en, this message translates to:
  /// **'Last Error: {message}'**
  String syncStatus_lastError(String message);

  /// No description provided for @syncStatus_blockedWhy.
  ///
  /// In en, this message translates to:
  /// **'Why It Is Blocked'**
  String get syncStatus_blockedWhy;

  /// No description provided for @syncStatus_blockedCauseRefused.
  ///
  /// In en, this message translates to:
  /// **'The server refused this change.'**
  String get syncStatus_blockedCauseRefused;

  /// No description provided for @syncStatus_blockedCauseAttempts.
  ///
  /// In en, this message translates to:
  /// **'Sync gave up after too many failed attempts.'**
  String get syncStatus_blockedCauseAttempts;

  /// No description provided for @syncStatus_timeJustNow.
  ///
  /// In en, this message translates to:
  /// **'Just Now'**
  String get syncStatus_timeJustNow;

  /// No description provided for @syncStatus_timeMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 Minute Ago} other{{count} Minutes Ago}}'**
  String syncStatus_timeMinutesAgo(int count);

  /// No description provided for @syncStatus_timeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 Hour Ago} other{{count} Hours Ago}}'**
  String syncStatus_timeHoursAgo(int count);

  /// No description provided for @syncStatus_timeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 Day Ago} other{{count} Days Ago}}'**
  String syncStatus_timeDaysAgo(int count);

  /// No description provided for @syncStatus_emptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing Is Waiting To Sync'**
  String get syncStatus_emptyTitle;

  /// No description provided for @syncStatus_emptyBody.
  ///
  /// In en, this message translates to:
  /// **'Every change on this device has been sent.'**
  String get syncStatus_emptyBody;

  /// No description provided for @syncStatus_retried.
  ///
  /// In en, this message translates to:
  /// **'The change will be sent again.'**
  String get syncStatus_retried;

  /// No description provided for @syncStatus_discardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard This Change?'**
  String get syncStatus_discardTitle;

  /// No description provided for @syncStatus_discardBody.
  ///
  /// In en, this message translates to:
  /// **'The queued change will be removed and the record will go back to the version saved on the server. This cannot be undone.'**
  String get syncStatus_discardBody;

  /// No description provided for @syncStatus_discardConfirm.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get syncStatus_discardConfirm;

  /// No description provided for @syncStatus_discarded.
  ///
  /// In en, this message translates to:
  /// **'The queued change was discarded.'**
  String get syncStatus_discarded;

  /// No description provided for @syncStatus_discardRestoredLocally.
  ///
  /// In en, this message translates to:
  /// **'The change was discarded. The record was restored from the last saved copy on this device.'**
  String get syncStatus_discardRestoredLocally;

  /// No description provided for @syncStatus_pendingDeletion.
  ///
  /// In en, this message translates to:
  /// **'Deletion Pending'**
  String get syncStatus_pendingDeletion;

  /// No description provided for @syncStatus_export.
  ///
  /// In en, this message translates to:
  /// **'Export Diagnostic Bundle'**
  String get syncStatus_export;

  /// No description provided for @syncStatus_exportShort.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get syncStatus_exportShort;

  /// No description provided for @syncStatus_exportTitle.
  ///
  /// In en, this message translates to:
  /// **'Export Diagnostic Bundle'**
  String get syncStatus_exportTitle;

  /// No description provided for @syncStatus_exportMetadataOnly.
  ///
  /// In en, this message translates to:
  /// **'Metadata Only'**
  String get syncStatus_exportMetadataOnly;

  /// No description provided for @syncStatus_exportMetadataOnlyBody.
  ///
  /// In en, this message translates to:
  /// **'Types, states, retry counts and error messages. No case content is included.'**
  String get syncStatus_exportMetadataOnlyBody;

  /// No description provided for @syncStatus_exportIncludePayloads.
  ///
  /// In en, this message translates to:
  /// **'Include Payloads'**
  String get syncStatus_exportIncludePayloads;

  /// No description provided for @syncStatus_exportIncludePayloadsBody.
  ///
  /// In en, this message translates to:
  /// **'Adds the queued changes themselves, which can include case details.'**
  String get syncStatus_exportIncludePayloadsBody;

  /// No description provided for @syncStatus_exportConsentTitle.
  ///
  /// In en, this message translates to:
  /// **'Include Case Content?'**
  String get syncStatus_exportConsentTitle;

  /// No description provided for @syncStatus_exportConsentBody.
  ///
  /// In en, this message translates to:
  /// **'The bundle will contain the queued changes, which can include case numbers, names and notes. Only share it with someone you trust.'**
  String get syncStatus_exportConsentBody;

  /// No description provided for @syncStatus_exportConsentConfirm.
  ///
  /// In en, this message translates to:
  /// **'Include'**
  String get syncStatus_exportConsentConfirm;

  /// No description provided for @syncStatus_exportReminder.
  ///
  /// In en, this message translates to:
  /// **'Delete this file after seven days, or as soon as support no longer needs it.'**
  String get syncStatus_exportReminder;

  /// No description provided for @syncStatus_exportSaved.
  ///
  /// In en, this message translates to:
  /// **'Diagnostic Bundle Saved To {path}'**
  String syncStatus_exportSaved(String path);

  /// No description provided for @syncStatus_exportFailed.
  ///
  /// In en, this message translates to:
  /// **'The diagnostic bundle could not be saved.'**
  String get syncStatus_exportFailed;

  /// No description provided for @logout_connectToSync.
  ///
  /// In en, this message translates to:
  /// **'Connect to the internet to sync your changes first.'**
  String get logout_connectToSync;

  /// No description provided for @logout_logOutAnyway.
  ///
  /// In en, this message translates to:
  /// **'Log Out Anyway'**
  String get logout_logOutAnyway;

  /// No description provided for @logout_unsyncedWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'Some Changes Have Not Synced Yet'**
  String get logout_unsyncedWarningTitle;

  /// No description provided for @logout_unsyncedWarningBody.
  ///
  /// In en, this message translates to:
  /// **'Some data haven\'t finished syncing to cloud yet. Logging out now will result in those unsynced data being discarded.'**
  String get logout_unsyncedWarningBody;

  /// No description provided for @logout_memberWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'Log Out and Erase This Device?'**
  String get logout_memberWarningTitle;

  /// No description provided for @logout_memberWarningBody.
  ///
  /// In en, this message translates to:
  /// **'The chamber keeps its records, so no copy is taken from this device. Everything the chamber has here — its cases, notes, references and roster — is erased, and anything still waiting to sync is discarded. Sign in again to get the chamber\'s records back.'**
  String get logout_memberWarningBody;

  /// No description provided for @logout_proceed.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get logout_proceed;

  /// No description provided for @logout_backupPromptTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup Data to Local Storage'**
  String get logout_backupPromptTitle;

  /// No description provided for @logout_backedUpTo.
  ///
  /// In en, this message translates to:
  /// **'Your data has been backed up to {path}. You can restore it after logging back in.'**
  String logout_backedUpTo(String path);

  /// No description provided for @logout_exportCancelled.
  ///
  /// In en, this message translates to:
  /// **'Logging out was cancelled; nothing was deleted.'**
  String get logout_exportCancelled;

  /// No description provided for @logout_exportFailed.
  ///
  /// In en, this message translates to:
  /// **'The safety copy could not be saved, so nothing was deleted.'**
  String get logout_exportFailed;

  /// No description provided for @logout_syncFailed.
  ///
  /// In en, this message translates to:
  /// **'Your changes could not be synced.'**
  String get logout_syncFailed;

  /// No description provided for @recoveryLock_title.
  ///
  /// In en, this message translates to:
  /// **'Offline For Too Long'**
  String get recoveryLock_title;

  /// No description provided for @recoveryLock_message.
  ///
  /// In en, this message translates to:
  /// **'You have been offline for {days} days. Your local changes have been saved to {path}. Fresh data must be loaded from the server before editing can continue.'**
  String recoveryLock_message(int days, String path);

  /// No description provided for @recoveryLock_messageNoCopy.
  ///
  /// In en, this message translates to:
  /// **'You have been offline for {days} days. A safety copy must be saved before fresh data can be loaded from the server.'**
  String recoveryLock_messageNoCopy(int days);

  /// No description provided for @recoveryLock_saveTitle.
  ///
  /// In en, this message translates to:
  /// **'Save A Safety Copy'**
  String get recoveryLock_saveTitle;

  /// No description provided for @recoveryLock_saveBody.
  ///
  /// In en, this message translates to:
  /// **'Everything on this device — your cases, notes and unsynced changes — is sealed into one encrypted file first. Set a passphrase you will remember; it is not stored anywhere.'**
  String get recoveryLock_saveBody;

  /// No description provided for @recoveryLock_saveBodyUnencrypted.
  ///
  /// In en, this message translates to:
  /// **'Everything on this device — your cases, notes and unsynced changes — is saved into one unencrypted file first.'**
  String get recoveryLock_saveBodyUnencrypted;

  /// No description provided for @recoveryLock_saveAction.
  ///
  /// In en, this message translates to:
  /// **'Save The Safety Copy'**
  String get recoveryLock_saveAction;

  /// No description provided for @recoveryLock_savedTo.
  ///
  /// In en, this message translates to:
  /// **'Safety Copy Saved To {path}'**
  String recoveryLock_savedTo(String path);

  /// No description provided for @recoveryLock_saveFailed.
  ///
  /// In en, this message translates to:
  /// **'The safety copy could not be saved. Your data is still on this device — try again.'**
  String get recoveryLock_saveFailed;

  /// No description provided for @recoveryLock_proceed.
  ///
  /// In en, this message translates to:
  /// **'Load Fresh Data'**
  String get recoveryLock_proceed;

  /// No description provided for @recoveryLock_proceedConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Replace This Device With The Server\'s Copy?'**
  String get recoveryLock_proceedConfirmTitle;

  /// No description provided for @recoveryLock_proceedConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Your local changes will be replaced by the server\'s data. The safety copy you saved is the only way back to them.'**
  String get recoveryLock_proceedConfirmBody;

  /// No description provided for @recoveryLock_close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get recoveryLock_close;

  /// No description provided for @recoveryLock_closeBody.
  ///
  /// In en, this message translates to:
  /// **'The app stays locked and nothing is written to the cloud until recovery succeeds.'**
  String get recoveryLock_closeBody;

  /// No description provided for @recoveryLock_working.
  ///
  /// In en, this message translates to:
  /// **'Loading Fresh Data…'**
  String get recoveryLock_working;

  /// No description provided for @recoveryLock_failed.
  ///
  /// In en, this message translates to:
  /// **'Recovery could not finish. Your data is still on this device and the app stays locked; try again.'**
  String get recoveryLock_failed;

  /// No description provided for @syncStatus_entryTitle.
  ///
  /// In en, this message translates to:
  /// **'{entity} {operation}'**
  String syncStatus_entryTitle(String entity, String operation);

  /// No description provided for @paywall_title.
  ///
  /// In en, this message translates to:
  /// **'Subscription Plans'**
  String get paywall_title;

  /// No description provided for @paywall_memberPlanTitle.
  ///
  /// In en, this message translates to:
  /// **'Chamber Plan'**
  String get paywall_memberPlanTitle;

  /// No description provided for @paywall_memberPlanBody.
  ///
  /// In en, this message translates to:
  /// **'This account is covered by the chamber\'s subscription. The chamber owner buys and renews it.'**
  String get paywall_memberPlanBody;

  /// No description provided for @paywall_memberLockedToast.
  ///
  /// In en, this message translates to:
  /// **'Only the firm owner can purchase a subscription for the firm. Please contact your firm owner to manage the subscription.'**
  String get paywall_memberLockedToast;

  /// No description provided for @paywall_chamberPlanLockedToast.
  ///
  /// In en, this message translates to:
  /// **'Dissolve your chamber before choosing an individual plan.'**
  String get paywall_chamberPlanLockedToast;

  /// No description provided for @paywall_limitTitle.
  ///
  /// In en, this message translates to:
  /// **'Free Plan Limit Reached'**
  String get paywall_limitTitle;

  /// No description provided for @paywall_limitBody.
  ///
  /// In en, this message translates to:
  /// **'The free plan holds up to {limit} cases. Deleting a case frees a slot, and everything else — Case Management, taking Notes, using Case Reference, editing and printing — stays free.'**
  String paywall_limitBody(String limit);

  /// No description provided for @paywall_lapsedTitle.
  ///
  /// In en, this message translates to:
  /// **'Limited Access Mode'**
  String get paywall_lapsedTitle;

  /// No description provided for @paywall_lapsedBody.
  ///
  /// In en, this message translates to:
  /// **'Your plan has ended, so your access is limited: you can add up to {limit} cases. Everything you already hold stays readable; renew to add more and edit it all.'**
  String paywall_lapsedBody(String limit);

  /// No description provided for @paywall_intro.
  ///
  /// In en, this message translates to:
  /// **'Choose the plan that fits your practice.'**
  String get paywall_intro;

  /// No description provided for @paywall_audienceIndividual.
  ///
  /// In en, this message translates to:
  /// **'Individual'**
  String get paywall_audienceIndividual;

  /// No description provided for @paywall_audienceFirm.
  ///
  /// In en, this message translates to:
  /// **'Firm'**
  String get paywall_audienceFirm;

  /// No description provided for @paywall_tierFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get paywall_tierFree;

  /// No description provided for @paywall_tierStarter.
  ///
  /// In en, this message translates to:
  /// **'Starter'**
  String get paywall_tierStarter;

  /// No description provided for @paywall_tierPro.
  ///
  /// In en, this message translates to:
  /// **'Pro'**
  String get paywall_tierPro;

  /// No description provided for @paywall_tierFirm.
  ///
  /// In en, this message translates to:
  /// **'Firm'**
  String get paywall_tierFirm;

  /// No description provided for @paywall_tierFirmPlus.
  ///
  /// In en, this message translates to:
  /// **'Firm Plus'**
  String get paywall_tierFirmPlus;

  /// No description provided for @paywall_tierEnterprise.
  ///
  /// In en, this message translates to:
  /// **'Enterprise'**
  String get paywall_tierEnterprise;

  /// No description provided for @paywall_tierFreeNote.
  ///
  /// In en, this message translates to:
  /// **'For new lawyers who want to try the app.'**
  String get paywall_tierFreeNote;

  /// No description provided for @paywall_tierStarterNote.
  ///
  /// In en, this message translates to:
  /// **'For lawyers who need cloud backup.'**
  String get paywall_tierStarterNote;

  /// No description provided for @paywall_tierProNote.
  ///
  /// In en, this message translates to:
  /// **'For lawyers who need flexibility and cloud backup.'**
  String get paywall_tierProNote;

  /// No description provided for @paywall_tierFirmNote.
  ///
  /// In en, this message translates to:
  /// **'For firms and lawyers who need real-time collaboration.'**
  String get paywall_tierFirmNote;

  /// No description provided for @paywall_tierFirmPlusNote.
  ///
  /// In en, this message translates to:
  /// **'For firms and lawyers that need to store large amounts of case data in the cloud.'**
  String get paywall_tierFirmPlusNote;

  /// No description provided for @paywall_tierEnterpriseNote.
  ///
  /// In en, this message translates to:
  /// **'For firms that need the largest case capacity and a team of 20.'**
  String get paywall_tierEnterpriseNote;

  /// No description provided for @paywall_includes.
  ///
  /// In en, this message translates to:
  /// **'Includes'**
  String get paywall_includes;

  /// No description provided for @paywall_everythingIn.
  ///
  /// In en, this message translates to:
  /// **'Everything in {tier}, plus'**
  String paywall_everythingIn(String tier);

  /// No description provided for @paywall_featureCases.
  ///
  /// In en, this message translates to:
  /// **'Up to {count} cases'**
  String paywall_featureCases(String count);

  /// No description provided for @paywall_featureUnlimitedCases.
  ///
  /// In en, this message translates to:
  /// **'Unlimited cases'**
  String get paywall_featureUnlimitedCases;

  /// No description provided for @paywall_featureOfflineUse.
  ///
  /// In en, this message translates to:
  /// **'Offline use only'**
  String get paywall_featureOfflineUse;

  /// No description provided for @paywall_featureOfflineBackup.
  ///
  /// In en, this message translates to:
  /// **'Offline backup and restoration'**
  String get paywall_featureOfflineBackup;

  /// No description provided for @paywall_featureOfflineDataBackup.
  ///
  /// In en, this message translates to:
  /// **'Offline usage & data backup'**
  String get paywall_featureOfflineDataBackup;

  /// No description provided for @paywall_featureCustomization.
  ///
  /// In en, this message translates to:
  /// **'Data customization: court names, steps and case types'**
  String get paywall_featureCustomization;

  /// No description provided for @paywall_featureCloudBackup.
  ///
  /// In en, this message translates to:
  /// **'Real-time cloud backup'**
  String get paywall_featureCloudBackup;

  /// No description provided for @paywall_featureDisasterRecovery.
  ///
  /// In en, this message translates to:
  /// **'Disaster recovery: restore your diary from the cloud on a new device'**
  String get paywall_featureDisasterRecovery;

  /// No description provided for @paywall_featureSingleDevice.
  ///
  /// In en, this message translates to:
  /// **'Single-device use'**
  String get paywall_featureSingleDevice;

  /// No description provided for @paywall_featureMultiDevice.
  ///
  /// In en, this message translates to:
  /// **'Multi-device access: Use your account on up to {count} devices simultaneously.'**
  String paywall_featureMultiDevice(String count);

  /// No description provided for @paywall_featureCollaboration.
  ///
  /// In en, this message translates to:
  /// **'Collaboration: Use your account on up to {devices} devices simultaneously or invite up to {associates} associates to your firm.'**
  String paywall_featureCollaboration(String devices, String associates);

  /// No description provided for @paywall_mostPopular.
  ///
  /// In en, this message translates to:
  /// **'Most Popular'**
  String get paywall_mostPopular;

  /// No description provided for @paywall_currentPlanBadge.
  ///
  /// In en, this message translates to:
  /// **'Current Plan'**
  String get paywall_currentPlanBadge;

  /// No description provided for @paywall_scheduledBadge.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get paywall_scheduledBadge;

  /// No description provided for @paywall_startsOn.
  ///
  /// In en, this message translates to:
  /// **'Starts on {date}'**
  String paywall_startsOn(String date);

  /// No description provided for @paywall_pricePerMonth.
  ///
  /// In en, this message translates to:
  /// **'{amount}/month'**
  String paywall_pricePerMonth(String amount);

  /// No description provided for @paywall_perMonth.
  ///
  /// In en, this message translates to:
  /// **'/month'**
  String get paywall_perMonth;

  /// No description provided for @paywall_termMonthly.
  ///
  /// In en, this message translates to:
  /// **'1 Month'**
  String get paywall_termMonthly;

  /// No description provided for @paywall_termQuarterly.
  ///
  /// In en, this message translates to:
  /// **'3 Months'**
  String get paywall_termQuarterly;

  /// No description provided for @paywall_termHalfYearly.
  ///
  /// In en, this message translates to:
  /// **'6 Months'**
  String get paywall_termHalfYearly;

  /// No description provided for @paywall_termAnnual.
  ///
  /// In en, this message translates to:
  /// **'1 Year'**
  String get paywall_termAnnual;

  /// No description provided for @paywall_planStarterMonthly.
  ///
  /// In en, this message translates to:
  /// **'Starter · 1 Month'**
  String get paywall_planStarterMonthly;

  /// No description provided for @paywall_planStarterQuarterly.
  ///
  /// In en, this message translates to:
  /// **'Starter · 3 Months'**
  String get paywall_planStarterQuarterly;

  /// No description provided for @paywall_planStarterHalfYearly.
  ///
  /// In en, this message translates to:
  /// **'Starter · 6 Months'**
  String get paywall_planStarterHalfYearly;

  /// No description provided for @paywall_planStarterAnnual.
  ///
  /// In en, this message translates to:
  /// **'Starter · 1 Year'**
  String get paywall_planStarterAnnual;

  /// No description provided for @paywall_planProMonthly.
  ///
  /// In en, this message translates to:
  /// **'Pro · 1 Month'**
  String get paywall_planProMonthly;

  /// No description provided for @paywall_planProQuarterly.
  ///
  /// In en, this message translates to:
  /// **'Pro · 3 Months'**
  String get paywall_planProQuarterly;

  /// No description provided for @paywall_planProHalfYearly.
  ///
  /// In en, this message translates to:
  /// **'Pro · 6 Months'**
  String get paywall_planProHalfYearly;

  /// No description provided for @paywall_planProAnnual.
  ///
  /// In en, this message translates to:
  /// **'Pro · 1 Year'**
  String get paywall_planProAnnual;

  /// No description provided for @paywall_planFirmMonthly.
  ///
  /// In en, this message translates to:
  /// **'Firm · 1 Month'**
  String get paywall_planFirmMonthly;

  /// No description provided for @paywall_planFirmQuarterly.
  ///
  /// In en, this message translates to:
  /// **'Firm · 3 Months'**
  String get paywall_planFirmQuarterly;

  /// No description provided for @paywall_planFirmHalfYearly.
  ///
  /// In en, this message translates to:
  /// **'Firm · 6 Months'**
  String get paywall_planFirmHalfYearly;

  /// No description provided for @paywall_planFirmAnnual.
  ///
  /// In en, this message translates to:
  /// **'Firm · 1 Year'**
  String get paywall_planFirmAnnual;

  /// No description provided for @paywall_planFirmPlusQuarterly.
  ///
  /// In en, this message translates to:
  /// **'Firm Plus · 3 Months'**
  String get paywall_planFirmPlusQuarterly;

  /// No description provided for @paywall_planFirmPlusHalfYearly.
  ///
  /// In en, this message translates to:
  /// **'Firm Plus · 6 Months'**
  String get paywall_planFirmPlusHalfYearly;

  /// No description provided for @paywall_planFirmPlusAnnual.
  ///
  /// In en, this message translates to:
  /// **'Firm Plus · 1 Year'**
  String get paywall_planFirmPlusAnnual;

  /// No description provided for @paywall_planEnterpriseQuarterly.
  ///
  /// In en, this message translates to:
  /// **'Enterprise · 3 Months'**
  String get paywall_planEnterpriseQuarterly;

  /// No description provided for @paywall_planEnterpriseHalfYearly.
  ///
  /// In en, this message translates to:
  /// **'Enterprise · 6 Months'**
  String get paywall_planEnterpriseHalfYearly;

  /// No description provided for @paywall_planEnterpriseAnnual.
  ///
  /// In en, this message translates to:
  /// **'Enterprise · 1 Year'**
  String get paywall_planEnterpriseAnnual;

  /// No description provided for @paywall_subscribe.
  ///
  /// In en, this message translates to:
  /// **'Subscribe'**
  String get paywall_subscribe;

  /// No description provided for @paywall_subscribePlan.
  ///
  /// In en, this message translates to:
  /// **'Subscribe — {plan}'**
  String paywall_subscribePlan(String plan);

  /// No description provided for @paywall_renewPlan.
  ///
  /// In en, this message translates to:
  /// **'Renew — {plan}'**
  String paywall_renewPlan(String plan);

  /// No description provided for @paywall_renewScheduledPlan.
  ///
  /// In en, this message translates to:
  /// **'Renew Scheduled Plan — {plan}'**
  String paywall_renewScheduledPlan(String plan);

  /// No description provided for @paywall_included.
  ///
  /// In en, this message translates to:
  /// **'Included'**
  String get paywall_included;

  /// No description provided for @paywall_changeTitle.
  ///
  /// In en, this message translates to:
  /// **'This Plan Starts Later'**
  String get paywall_changeTitle;

  /// No description provided for @paywall_changeBody.
  ///
  /// In en, this message translates to:
  /// **'Your {current} plan runs until {end}. {next} will start on {start} and run for {term}. Your case ceiling will be {limit} from then.'**
  String paywall_changeBody(
    String current,
    String end,
    String next,
    String start,
    String term,
    String limit,
  );

  /// No description provided for @paywall_changeGoBack.
  ///
  /// In en, this message translates to:
  /// **'Go Back'**
  String get paywall_changeGoBack;

  /// No description provided for @paywall_changeContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue to Payment'**
  String get paywall_changeContinue;

  /// No description provided for @paywall_changePendingTitle.
  ///
  /// In en, this message translates to:
  /// **'A Plan Change Is Already Scheduled'**
  String get paywall_changePendingTitle;

  /// No description provided for @paywall_changePendingBody.
  ///
  /// In en, this message translates to:
  /// **'{plan} is scheduled to start on {date}. You can renew your current plan or the scheduled plan.'**
  String paywall_changePendingBody(String plan, String date);

  /// No description provided for @paywall_changePendingClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get paywall_changePendingClose;

  /// No description provided for @paywall_renewShiftTitle.
  ///
  /// In en, this message translates to:
  /// **'Your Scheduled Plan Will Start Later'**
  String get paywall_renewShiftTitle;

  /// No description provided for @paywall_renewShiftBody.
  ///
  /// In en, this message translates to:
  /// **'Renewing {current} extends it to {end}. {next} will now start on that date.'**
  String paywall_renewShiftBody(String current, String end, String next);

  /// No description provided for @paywall_renewShiftConfirm.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get paywall_renewShiftConfirm;

  /// No description provided for @paywall_caseLimitTitle.
  ///
  /// In en, this message translates to:
  /// **'{tier} Case Limit Reached'**
  String paywall_caseLimitTitle(String tier);

  /// No description provided for @paywall_caseLimitBody.
  ///
  /// In en, this message translates to:
  /// **'Your {tier} plan holds up to {limit} cases. Delete a case to free a slot, or choose a larger plan.'**
  String paywall_caseLimitBody(String tier, String limit);

  /// No description provided for @paywall_caseLimitMemberBody.
  ///
  /// In en, this message translates to:
  /// **'This chamber\'s {tier} plan holds up to {limit} cases. The chamber owner manages the plan.'**
  String paywall_caseLimitMemberBody(String tier, String limit);

  /// No description provided for @paywall_caseLimitAction.
  ///
  /// In en, this message translates to:
  /// **'See Plans'**
  String get paywall_caseLimitAction;

  /// No description provided for @paywall_caseLimitClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get paywall_caseLimitClose;

  /// No description provided for @lapse_readOnlyBadge.
  ///
  /// In en, this message translates to:
  /// **'Read-only'**
  String get lapse_readOnlyBadge;

  /// No description provided for @lapse_renewAction.
  ///
  /// In en, this message translates to:
  /// **'Renew'**
  String get lapse_renewAction;

  /// No description provided for @lapse_bannerCases.
  ///
  /// In en, this message translates to:
  /// **'Your access is limited. The {editable} most recently updated cases stay editable; {readOnly} are read-only until you renew.'**
  String lapse_bannerCases(String editable, String readOnly);

  /// No description provided for @lapse_bannerNotes.
  ///
  /// In en, this message translates to:
  /// **'Your access is limited. The {editable} most recently updated notes stay editable; {readOnly} are read-only until you renew.'**
  String lapse_bannerNotes(String editable, String readOnly);

  /// No description provided for @lapse_bannerReferences.
  ///
  /// In en, this message translates to:
  /// **'Your access is limited. The {editable} most recently updated case references stay editable; {readOnly} are read-only until you renew.'**
  String lapse_bannerReferences(String editable, String readOnly);

  /// No description provided for @lapse_readOnlyCase.
  ///
  /// In en, this message translates to:
  /// **'This case is read-only while your access is limited. Renew to edit it.'**
  String get lapse_readOnlyCase;

  /// No description provided for @lapse_readOnlyNote.
  ///
  /// In en, this message translates to:
  /// **'This note is read-only while your access is limited. Renew to edit it.'**
  String get lapse_readOnlyNote;

  /// No description provided for @lapse_readOnlyReference.
  ///
  /// In en, this message translates to:
  /// **'This case reference is read-only while your access is limited. Renew to edit it.'**
  String get lapse_readOnlyReference;

  /// No description provided for @lapse_noteLimit.
  ///
  /// In en, this message translates to:
  /// **'You have reached the notes allowance of your last plan. Renew to add more notes.'**
  String get lapse_noteLimit;

  /// No description provided for @lapse_referenceLimit.
  ///
  /// In en, this message translates to:
  /// **'You have reached the case references allowance of your last plan. Renew to add more references.'**
  String get lapse_referenceLimit;

  /// No description provided for @adminPanel_title.
  ///
  /// In en, this message translates to:
  /// **'Admin Panel'**
  String get adminPanel_title;

  /// No description provided for @adminPanel_paymentRequests.
  ///
  /// In en, this message translates to:
  /// **'Payment Requests'**
  String get adminPanel_paymentRequests;

  /// No description provided for @adminPanel_paymentRequestsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Approve Or Reject Submitted Payments'**
  String get adminPanel_paymentRequestsSubtitle;

  /// No description provided for @adminPanel_unverifiedAccounts.
  ///
  /// In en, this message translates to:
  /// **'Non-verified Accounts'**
  String get adminPanel_unverifiedAccounts;

  /// No description provided for @adminPanel_unverifiedAccountsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign-Ups Unconfirmed For Over 72 Hours'**
  String get adminPanel_unverifiedAccountsSubtitle;

  /// No description provided for @adminPanel_unverifiedTitle.
  ///
  /// In en, this message translates to:
  /// **'Non-verified Accounts'**
  String get adminPanel_unverifiedTitle;

  /// No description provided for @adminPanel_unverifiedEmpty.
  ///
  /// In en, this message translates to:
  /// **'No sign-up has stayed unconfirmed for over 72 hours.'**
  String get adminPanel_unverifiedEmpty;

  /// No description provided for @adminPanel_unverifiedLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'The accounts could not be loaded.'**
  String get adminPanel_unverifiedLoadFailed;

  /// No description provided for @adminPanel_created.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get adminPanel_created;

  /// No description provided for @adminPanel_lastSignIn.
  ///
  /// In en, this message translates to:
  /// **'Last Sign-in'**
  String get adminPanel_lastSignIn;

  /// No description provided for @adminPanel_delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get adminPanel_delete;

  /// No description provided for @adminPanel_deleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete This Account?'**
  String get adminPanel_deleteTitle;

  /// No description provided for @adminPanel_deleteBody.
  ///
  /// In en, this message translates to:
  /// **'The account never confirmed its address and has done nothing, so it will be removed for good. This cannot be undone.'**
  String get adminPanel_deleteBody;

  /// No description provided for @adminPanel_deleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get adminPanel_deleteConfirm;

  /// No description provided for @adminPanel_deleteBlocked.
  ///
  /// In en, this message translates to:
  /// **'This account has data or is confirmed, so it cannot be deleted from here.'**
  String get adminPanel_deleteBlocked;

  /// No description provided for @adminPanel_deleteTooRecent.
  ///
  /// In en, this message translates to:
  /// **'This account signed up less than 72 hours ago, so it cannot be deleted from here yet.'**
  String get adminPanel_deleteTooRecent;

  /// No description provided for @adminPanel_deleted.
  ///
  /// In en, this message translates to:
  /// **'Account deleted.'**
  String get adminPanel_deleted;

  /// No description provided for @adminPanel_search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get adminPanel_search;

  /// No description provided for @adminPanel_searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get adminPanel_searchHint;

  /// No description provided for @adminPanel_noResults.
  ///
  /// In en, this message translates to:
  /// **'No results found.'**
  String get adminPanel_noResults;

  /// No description provided for @adminPanel_pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get adminPanel_pending;

  /// No description provided for @adminPanel_resolved.
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get adminPanel_resolved;

  /// A collapsible section heading with the number of requests in it.
  ///
  /// In en, this message translates to:
  /// **'{count}'**
  String adminPanel_sectionCount(String count);

  /// No description provided for @adminPanel_emptyPending.
  ///
  /// In en, this message translates to:
  /// **'No payment is waiting for a decision.'**
  String get adminPanel_emptyPending;

  /// No description provided for @adminPanel_emptyResolved.
  ///
  /// In en, this message translates to:
  /// **'Nothing has been approved or rejected yet.'**
  String get adminPanel_emptyResolved;

  /// No description provided for @adminPanel_approve.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get adminPanel_approve;

  /// No description provided for @adminPanel_reject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get adminPanel_reject;

  /// No description provided for @adminPanel_rejectTitle.
  ///
  /// In en, this message translates to:
  /// **'Reject the Payment'**
  String get adminPanel_rejectTitle;

  /// No description provided for @adminPanel_rejectNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Note For The Payer (Optional)'**
  String get adminPanel_rejectNoteLabel;

  /// No description provided for @adminPanel_rejectNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Why this payment was not accepted'**
  String get adminPanel_rejectNoteHint;

  /// No description provided for @adminPanel_rejectConfirm.
  ///
  /// In en, this message translates to:
  /// **'Reject Payment'**
  String get adminPanel_rejectConfirm;

  /// No description provided for @adminPanel_rejectPickMessage.
  ///
  /// In en, this message translates to:
  /// **'Pre-Fill Message'**
  String get adminPanel_rejectPickMessage;

  /// No description provided for @adminPanel_rejectTemplateMismatch.
  ///
  /// In en, this message translates to:
  /// **'Mobile number & Transaction ID didn\'t match.'**
  String get adminPanel_rejectTemplateMismatch;

  /// No description provided for @adminPanel_rejectTemplateMobileNumber.
  ///
  /// In en, this message translates to:
  /// **'Mobile number is wrong.'**
  String get adminPanel_rejectTemplateMobileNumber;

  /// No description provided for @adminPanel_rejectTemplateTransactionId.
  ///
  /// In en, this message translates to:
  /// **'Transaction ID is wrong.'**
  String get adminPanel_rejectTemplateTransactionId;

  /// No description provided for @adminPanel_rejectTemplateCorrectInfo.
  ///
  /// In en, this message translates to:
  /// **'Please enter the correct info.'**
  String get adminPanel_rejectTemplateCorrectInfo;

  /// No description provided for @adminPanel_rejectTemplateTwoTries.
  ///
  /// In en, this message translates to:
  /// **'You have 2 tries left today.'**
  String get adminPanel_rejectTemplateTwoTries;

  /// No description provided for @adminPanel_rejectTemplateOneTry.
  ///
  /// In en, this message translates to:
  /// **'You have 1 try left today.'**
  String get adminPanel_rejectTemplateOneTry;

  /// No description provided for @adminPanel_rejectTemplateBeCareful.
  ///
  /// In en, this message translates to:
  /// **'Please be careful typing the info next time.'**
  String get adminPanel_rejectTemplateBeCareful;

  /// No description provided for @adminPanel_rejectAddOwn.
  ///
  /// In en, this message translates to:
  /// **'Add Your Own'**
  String get adminPanel_rejectAddOwn;

  /// No description provided for @adminPanel_rejectOwnMessageTitle.
  ///
  /// In en, this message translates to:
  /// **'Your Own Message'**
  String get adminPanel_rejectOwnMessageTitle;

  /// No description provided for @adminPanel_rejectOwnMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Write the message the payer will read'**
  String get adminPanel_rejectOwnMessageHint;

  /// One payer detail on a payment request, e.g. Bar Association.
  ///
  /// In en, this message translates to:
  /// **'{label}: {value}'**
  String adminPanel_detailLabel(String label, String value);

  /// No description provided for @adminPanel_detailLabelTrx.
  ///
  /// In en, this message translates to:
  /// **'TrxID'**
  String get adminPanel_detailLabelTrx;

  /// No description provided for @adminPanel_detailLabelMfs.
  ///
  /// In en, this message translates to:
  /// **'Method'**
  String get adminPanel_detailLabelMfs;

  /// No description provided for @adminPanel_detailLabelName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get adminPanel_detailLabelName;

  /// No description provided for @adminPanel_detailLabelEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get adminPanel_detailLabelEmail;

  /// No description provided for @adminPanel_detailLabelBar.
  ///
  /// In en, this message translates to:
  /// **'Bar Association'**
  String get adminPanel_detailLabelBar;

  /// No description provided for @adminPanel_detailLabelMembership.
  ///
  /// In en, this message translates to:
  /// **'Membership No'**
  String get adminPanel_detailLabelMembership;

  /// No description provided for @adminPanel_detailLabelMobile.
  ///
  /// In en, this message translates to:
  /// **'Mobile'**
  String get adminPanel_detailLabelMobile;

  /// No description provided for @adminPanel_detailLabelSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Submitted'**
  String get adminPanel_detailLabelSubmitted;

  /// No description provided for @adminPanel_detailLabelNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get adminPanel_detailLabelNote;

  /// No description provided for @adminPanel_noValue.
  ///
  /// In en, this message translates to:
  /// **'—'**
  String get adminPanel_noValue;

  /// No description provided for @adminPanel_statusApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get adminPanel_statusApproved;

  /// No description provided for @adminPanel_statusRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get adminPanel_statusRejected;

  /// No description provided for @adminPanel_statusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get adminPanel_statusPending;

  /// No description provided for @adminPanel_approvedExpiry.
  ///
  /// In en, this message translates to:
  /// **'Premium Extended To'**
  String get adminPanel_approvedExpiry;

  /// No description provided for @adminPanel_approvedBy.
  ///
  /// In en, this message translates to:
  /// **'Approved By'**
  String get adminPanel_approvedBy;

  /// No description provided for @adminPanel_rejectedBy.
  ///
  /// In en, this message translates to:
  /// **'Rejected By'**
  String get adminPanel_rejectedBy;

  /// No description provided for @adminPanel_loading.
  ///
  /// In en, this message translates to:
  /// **'Loading payment requests…'**
  String get adminPanel_loading;

  /// No description provided for @adminPanel_loadFailed.
  ///
  /// In en, this message translates to:
  /// **'Payment requests could not be loaded.'**
  String get adminPanel_loadFailed;

  /// No description provided for @adminPanel_retry.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get adminPanel_retry;

  /// No description provided for @adminPanel_failedNotAdmin.
  ///
  /// In en, this message translates to:
  /// **'Only an administrator can do that.'**
  String get adminPanel_failedNotAdmin;

  /// No description provided for @adminPanel_failedNotFound.
  ///
  /// In en, this message translates to:
  /// **'That payment no longer exists.'**
  String get adminPanel_failedNotFound;

  /// No description provided for @adminPanel_failedAlreadyResolved.
  ///
  /// In en, this message translates to:
  /// **'That payment was already decided.'**
  String get adminPanel_failedAlreadyResolved;

  /// No description provided for @adminPanel_failedUnexpected.
  ///
  /// In en, this message translates to:
  /// **'That did not work. Please try again.'**
  String get adminPanel_failedUnexpected;

  /// No description provided for @general_tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get general_tomorrow;

  /// No description provided for @sharedActions_save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get sharedActions_save;

  /// No description provided for @sharedActions_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get sharedActions_cancel;

  /// No description provided for @imageCrop_title.
  ///
  /// In en, this message translates to:
  /// **'Select Image'**
  String get imageCrop_title;

  /// No description provided for @imageCrop_save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get imageCrop_save;

  /// No description provided for @imageCrop_rotate.
  ///
  /// In en, this message translates to:
  /// **'Rotate'**
  String get imageCrop_rotate;

  /// No description provided for @profilePicture_title.
  ///
  /// In en, this message translates to:
  /// **'Profile Picture'**
  String get profilePicture_title;

  /// No description provided for @firmLogo_title.
  ///
  /// In en, this message translates to:
  /// **'Firm Logo'**
  String get firmLogo_title;

  /// No description provided for @imageSource_gallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get imageSource_gallery;

  /// No description provided for @imageSource_files.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get imageSource_files;

  /// No description provided for @sharedActions_delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get sharedActions_delete;

  /// No description provided for @sharedActions_edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get sharedActions_edit;

  /// No description provided for @sharedActions_search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get sharedActions_search;

  /// No description provided for @sharedActions_add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get sharedActions_add;

  /// No description provided for @sharedActions_update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get sharedActions_update;

  /// No description provided for @sharedActions_close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get sharedActions_close;

  /// No description provided for @sharedActions_yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get sharedActions_yes;

  /// No description provided for @sharedActions_no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get sharedActions_no;

  /// No description provided for @sharedDialogs_confirmDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Delete'**
  String get sharedDialogs_confirmDeleteTitle;

  /// No description provided for @sharedDialogs_confirmDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this item?'**
  String get sharedDialogs_confirmDeleteMessage;

  /// No description provided for @sharedDialogs_noResults.
  ///
  /// In en, this message translates to:
  /// **'No results found.'**
  String get sharedDialogs_noResults;

  /// No description provided for @sharedDialogs_requiredField.
  ///
  /// In en, this message translates to:
  /// **'This field is required.'**
  String get sharedDialogs_requiredField;

  /// No description provided for @sharedDialogs_ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get sharedDialogs_ok;

  /// No description provided for @sharedDialogs_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get sharedDialogs_cancel;

  /// SHARED BUTTONS / DIALOGS
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String sharedMessages_error(String message);

  /// No description provided for @sharedMessages_signInRequired.
  ///
  /// In en, this message translates to:
  /// **'Sign In To Continue'**
  String get sharedMessages_signInRequired;

  /// No description provided for @sharedLabels_chamberMember.
  ///
  /// In en, this message translates to:
  /// **'A Chamber Member'**
  String get sharedLabels_chamberMember;

  /// No description provided for @shared_avatarUnreadable.
  ///
  /// In en, this message translates to:
  /// **'This picture could not be used. Please try a JPG or PNG image.'**
  String get shared_avatarUnreadable;

  /// No description provided for @appShell_exitTitle.
  ///
  /// In en, this message translates to:
  /// **'Exit App?'**
  String get appShell_exitTitle;

  /// No description provided for @appShell_exitMessage.
  ///
  /// In en, this message translates to:
  /// **'Do you want to exit Legal Case Diary?'**
  String get appShell_exitMessage;

  /// No description provided for @appShell_exit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get appShell_exit;

  /// No description provided for @databaseRecovery_title.
  ///
  /// In en, this message translates to:
  /// **'Database Locked'**
  String get databaseRecovery_title;

  /// No description provided for @databaseRecovery_body.
  ///
  /// In en, this message translates to:
  /// **'The encryption key for your local case diary is missing. This can happen after an operating system update or if app data was cleared.\n\nTo continue using the app offline, you must reset the local database. All unsynced local data will be lost.'**
  String get databaseRecovery_body;

  /// No description provided for @databaseRecovery_reset.
  ///
  /// In en, this message translates to:
  /// **'Reset Local Database'**
  String get databaseRecovery_reset;

  /// No description provided for @courtCategory_appellateDivision.
  ///
  /// In en, this message translates to:
  /// **'Appellate Division'**
  String get courtCategory_appellateDivision;

  /// No description provided for @courtCategory_highCourtDivision.
  ///
  /// In en, this message translates to:
  /// **'High Court Division'**
  String get courtCategory_highCourtDivision;

  /// No description provided for @courtCategory_lowerDivisionalCourts.
  ///
  /// In en, this message translates to:
  /// **'Lower Divisional Courts'**
  String get courtCategory_lowerDivisionalCourts;

  /// No description provided for @lowerCourtCategory_districtSessionsCriminal.
  ///
  /// In en, this message translates to:
  /// **'Sessions Judge Court (Criminal)'**
  String get lowerCourtCategory_districtSessionsCriminal;

  /// No description provided for @lowerCourtCategory_districtCourtsCivil.
  ///
  /// In en, this message translates to:
  /// **'District Judge Court (Civil)'**
  String get lowerCourtCategory_districtCourtsCivil;

  /// No description provided for @lowerCourtCategory_metropolitanSessionsJudgeCriminal.
  ///
  /// In en, this message translates to:
  /// **'Metropolitan Sessions Judge Court (Criminal)'**
  String get lowerCourtCategory_metropolitanSessionsJudgeCriminal;

  /// No description provided for @lowerCourtCategory_chiefJudicialMagistrate.
  ///
  /// In en, this message translates to:
  /// **'Chief Judicial Magistrate Court'**
  String get lowerCourtCategory_chiefJudicialMagistrate;

  /// No description provided for @lowerCourtCategory_chiefMetropolitanMagistrate.
  ///
  /// In en, this message translates to:
  /// **'Chief Metropolitan Magistrate Court'**
  String get lowerCourtCategory_chiefMetropolitanMagistrate;

  /// No description provided for @lowerCourtCategory_executiveMagistrate.
  ///
  /// In en, this message translates to:
  /// **'Executive Magistrate & Other Courts'**
  String get lowerCourtCategory_executiveMagistrate;

  /// No description provided for @lowerCourtCategory_tribunals.
  ///
  /// In en, this message translates to:
  /// **'Tribunals'**
  String get lowerCourtCategory_tribunals;

  /// No description provided for @onBehalf_plaintiff.
  ///
  /// In en, this message translates to:
  /// **'Plaintiff'**
  String get onBehalf_plaintiff;

  /// No description provided for @onBehalf_defendant.
  ///
  /// In en, this message translates to:
  /// **'Defendant'**
  String get onBehalf_defendant;

  /// No description provided for @onBehalf_accused.
  ///
  /// In en, this message translates to:
  /// **'Accused'**
  String get onBehalf_accused;

  /// No description provided for @onBehalf_appellant.
  ///
  /// In en, this message translates to:
  /// **'Appellant'**
  String get onBehalf_appellant;

  /// No description provided for @onBehalf_petitioner.
  ///
  /// In en, this message translates to:
  /// **'Petitioner'**
  String get onBehalf_petitioner;

  /// No description provided for @onBehalf_respondent.
  ///
  /// In en, this message translates to:
  /// **'Respondent'**
  String get onBehalf_respondent;

  /// No description provided for @onBehalf_writPetitioner.
  ///
  /// In en, this message translates to:
  /// **'Writ Petitioner'**
  String get onBehalf_writPetitioner;

  /// No description provided for @onBehalf_state.
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get onBehalf_state;

  /// No description provided for @onBehalf_victim.
  ///
  /// In en, this message translates to:
  /// **'Victim'**
  String get onBehalf_victim;

  /// No description provided for @onBehalf_complainant.
  ///
  /// In en, this message translates to:
  /// **'Complainant'**
  String get onBehalf_complainant;

  /// No description provided for @onBehalf_informant.
  ///
  /// In en, this message translates to:
  /// **'Informant'**
  String get onBehalf_informant;

  /// No description provided for @onBehalf_applicant.
  ///
  /// In en, this message translates to:
  /// **'Applicant'**
  String get onBehalf_applicant;

  /// No description provided for @onBehalf_claimant.
  ///
  /// In en, this message translates to:
  /// **'Claimant'**
  String get onBehalf_claimant;

  /// No description provided for @onBehalf_objector.
  ///
  /// In en, this message translates to:
  /// **'Objector'**
  String get onBehalf_objector;

  /// No description provided for @caseType_civil.
  ///
  /// In en, this message translates to:
  /// **'Civil'**
  String get caseType_civil;

  /// No description provided for @caseType_criminal.
  ///
  /// In en, this message translates to:
  /// **'Criminal'**
  String get caseType_criminal;

  /// No description provided for @caseType_writ.
  ///
  /// In en, this message translates to:
  /// **'Writ'**
  String get caseType_writ;

  /// No description provided for @caseType_appeal.
  ///
  /// In en, this message translates to:
  /// **'Appeal'**
  String get caseType_appeal;

  /// No description provided for @caseType_revision.
  ///
  /// In en, this message translates to:
  /// **'Revision'**
  String get caseType_revision;

  /// No description provided for @step_filed.
  ///
  /// In en, this message translates to:
  /// **'Filed'**
  String get step_filed;

  /// No description provided for @step_hearing.
  ///
  /// In en, this message translates to:
  /// **'Hearing'**
  String get step_hearing;

  /// No description provided for @step_disposed.
  ///
  /// In en, this message translates to:
  /// **'Disposed'**
  String get step_disposed;

  /// No description provided for @step_pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get step_pending;

  /// No description provided for @division_dhaka.
  ///
  /// In en, this message translates to:
  /// **'Dhaka'**
  String get division_dhaka;

  /// No description provided for @division_chattagram.
  ///
  /// In en, this message translates to:
  /// **'Chittagong'**
  String get division_chattagram;

  /// No description provided for @division_rajshahi.
  ///
  /// In en, this message translates to:
  /// **'Rajshahi'**
  String get division_rajshahi;

  /// No description provided for @division_khulna.
  ///
  /// In en, this message translates to:
  /// **'Khulna'**
  String get division_khulna;

  /// No description provided for @division_barishal.
  ///
  /// In en, this message translates to:
  /// **'Barishal'**
  String get division_barishal;

  /// No description provided for @division_sylhet.
  ///
  /// In en, this message translates to:
  /// **'Sylhet'**
  String get division_sylhet;

  /// No description provided for @division_rangpur.
  ///
  /// In en, this message translates to:
  /// **'Rangpur'**
  String get division_rangpur;

  /// No description provided for @division_mymensingh.
  ///
  /// In en, this message translates to:
  /// **'Mymensingh'**
  String get division_mymensingh;

  /// The long automated client message, used when the long template is selected.
  ///
  /// In en, this message translates to:
  /// **'{clientName},\nyour case, {caseLine}, is scheduled for hearing on {nextDate}{stepsClause} at {court}.\n\nBest regards,\n{lawyerName}{contactLine}'**
  String clientNotification_long(
    String clientName,
    String caseLine,
    String nextDate,
    String stepsClause,
    String court,
    String lawyerName,
    String contactLine,
  );

  /// The short automated client message, used when the short template is selected.
  ///
  /// In en, this message translates to:
  /// **'{caseLine} is scheduled on {nextDate}{stepsClause} at {court}'**
  String clientNotification_short(
    String caseLine,
    String nextDate,
    String stepsClause,
    String court,
  );

  /// The steps part of the long message; an empty string when the case has no steps.
  ///
  /// In en, this message translates to:
  /// **' for {steps}'**
  String clientNotification_longStepsClause(String steps);

  /// The steps part of the short message; an empty string when the case has no steps.
  ///
  /// In en, this message translates to:
  /// **' for {steps}'**
  String clientNotification_shortStepsClause(String steps);

  /// The call-back line of the long message; absent when no number is available.
  ///
  /// In en, this message translates to:
  /// **'\nContact: {contact}'**
  String clientNotification_contactLine(String contact);

  /// No description provided for @clientNotification_settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Client Notification Settings'**
  String get clientNotification_settingsTitle;

  /// No description provided for @settingsNotifications_deviceSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Device Notification Settings'**
  String get settingsNotifications_deviceSettingsTitle;

  /// No description provided for @clientNotification_automatedLabel.
  ///
  /// In en, this message translates to:
  /// **'Automated Notification'**
  String get clientNotification_automatedLabel;

  /// No description provided for @clientNotification_channelLabel.
  ///
  /// In en, this message translates to:
  /// **'Send Automated Notification Via'**
  String get clientNotification_channelLabel;

  /// No description provided for @clientNotification_templateLabel.
  ///
  /// In en, this message translates to:
  /// **'Default Notification Template'**
  String get clientNotification_templateLabel;

  /// No description provided for @clientNotification_longLabel.
  ///
  /// In en, this message translates to:
  /// **'Long'**
  String get clientNotification_longLabel;

  /// No description provided for @clientNotification_shortLabel.
  ///
  /// In en, this message translates to:
  /// **'Short'**
  String get clientNotification_shortLabel;

  /// No description provided for @clientNotification_sms.
  ///
  /// In en, this message translates to:
  /// **'SMS'**
  String get clientNotification_sms;

  /// No description provided for @clientNotification_askLabel.
  ///
  /// In en, this message translates to:
  /// **'Ask Before Sending Automated Message?'**
  String get clientNotification_askLabel;

  /// No description provided for @clientNotification_contactLabel.
  ///
  /// In en, this message translates to:
  /// **'Contact Number'**
  String get clientNotification_contactLabel;

  /// No description provided for @clientNotification_contactNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get clientNotification_contactNotSet;

  /// No description provided for @clientNotification_contactDialogHelper.
  ///
  /// In en, this message translates to:
  /// **'The number your client will see in the message.'**
  String get clientNotification_contactDialogHelper;

  /// No description provided for @clientNotification_promptTitle.
  ///
  /// In en, this message translates to:
  /// **'Send Message to Client?'**
  String get clientNotification_promptTitle;

  /// No description provided for @clientNotification_promptBody.
  ///
  /// In en, this message translates to:
  /// **'Would you like to send your client a message notifying them of the next court date?'**
  String get clientNotification_promptBody;

  /// No description provided for @clientNotification_rememberChoice.
  ///
  /// In en, this message translates to:
  /// **'Remember My Choice'**
  String get clientNotification_rememberChoice;

  /// No description provided for @clientNotification_exampleLabel.
  ///
  /// In en, this message translates to:
  /// **'Example:'**
  String get clientNotification_exampleLabel;

  /// No description provided for @clientNotification_previewClient.
  ///
  /// In en, this message translates to:
  /// **'Ali Hayder'**
  String get clientNotification_previewClient;

  /// No description provided for @clientNotification_previewCase.
  ///
  /// In en, this message translates to:
  /// **'Civil-123/26'**
  String get clientNotification_previewCase;

  /// No description provided for @clientNotification_previewCourt.
  ///
  /// In en, this message translates to:
  /// **'Senior Civil Judge Court, Sonargaon, Narayanganj'**
  String get clientNotification_previewCourt;

  /// No description provided for @clientNotification_previewSteps.
  ///
  /// In en, this message translates to:
  /// **'WS/WO'**
  String get clientNotification_previewSteps;

  /// No description provided for @clientNotification_previewLawyer.
  ///
  /// In en, this message translates to:
  /// **'Adv. Shafiullah Sourov'**
  String get clientNotification_previewLawyer;

  /// No description provided for @settingsScreen_title.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsScreen_title;

  /// No description provided for @settingsScreen_accountAndProfile.
  ///
  /// In en, this message translates to:
  /// **'Account & Profile'**
  String get settingsScreen_accountAndProfile;

  /// No description provided for @settingsScreen_profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get settingsScreen_profile;

  /// No description provided for @settingsScreen_manageAccount.
  ///
  /// In en, this message translates to:
  /// **'Manage Account'**
  String get settingsScreen_manageAccount;

  /// No description provided for @settingsScreen_onlineSync.
  ///
  /// In en, this message translates to:
  /// **'Online Sync'**
  String get settingsScreen_onlineSync;

  /// No description provided for @settingsScreen_backupAndRestore.
  ///
  /// In en, this message translates to:
  /// **'Backup & Restore'**
  String get settingsScreen_backupAndRestore;

  /// No description provided for @settingsScreen_editCourtSteps.
  ///
  /// In en, this message translates to:
  /// **'Edit Court/Steps'**
  String get settingsScreen_editCourtSteps;

  /// No description provided for @settingsScreen_notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsScreen_notifications;

  /// No description provided for @settingsScreen_language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsScreen_language;

  /// No description provided for @settingsScreen_viewSettings.
  ///
  /// In en, this message translates to:
  /// **'View Settings'**
  String get settingsScreen_viewSettings;

  /// No description provided for @settingsScreen_guidelines.
  ///
  /// In en, this message translates to:
  /// **'Guidelines & FAQs'**
  String get settingsScreen_guidelines;

  /// No description provided for @settingsScreen_about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsScreen_about;

  /// No description provided for @settingsScreen_sectionGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsScreen_sectionGeneral;

  /// No description provided for @settingsScreen_sectionPreferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get settingsScreen_sectionPreferences;

  /// No description provided for @settingsScreen_sectionAppInfo.
  ///
  /// In en, this message translates to:
  /// **'App Info'**
  String get settingsScreen_sectionAppInfo;

  /// No description provided for @settingsScreen_searchTooltip.
  ///
  /// In en, this message translates to:
  /// **'Search Settings'**
  String get settingsScreen_searchTooltip;

  /// No description provided for @settingsScreen_searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get settingsScreen_searchHint;

  /// No description provided for @settingsScreen_closeSearchTooltip.
  ///
  /// In en, this message translates to:
  /// **'Close Search'**
  String get settingsScreen_closeSearchTooltip;

  /// No description provided for @settingsScreen_noResults.
  ///
  /// In en, this message translates to:
  /// **'No settings found'**
  String get settingsScreen_noResults;

  /// No description provided for @settingsScreen_languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsScreen_languageEnglish;

  /// No description provided for @settingsScreen_languageBengali.
  ///
  /// In en, this message translates to:
  /// **'বাংলা'**
  String get settingsScreen_languageBengali;

  /// No description provided for @settingsLanguage_selectHeading.
  ///
  /// In en, this message translates to:
  /// **'Select App Language'**
  String get settingsLanguage_selectHeading;

  /// No description provided for @settingsLanguage_intro.
  ///
  /// In en, this message translates to:
  /// **'Every label, date and message in the app will use the language you pick here.'**
  String get settingsLanguage_intro;

  /// No description provided for @settingsLanguage_previewTitle.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Date in This Language'**
  String get settingsLanguage_previewTitle;

  /// No description provided for @settingsLanguage_selected.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get settingsLanguage_selected;

  /// No description provided for @settingsLanguage_note.
  ///
  /// In en, this message translates to:
  /// **'This changes only the app\'s interface. Your saved cases and notes stay exactly as they are.'**
  String get settingsLanguage_note;

  /// No description provided for @settingsAccountProfile_sectionProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get settingsAccountProfile_sectionProfile;

  /// No description provided for @settingsAccountProfile_sectionAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsAccountProfile_sectionAccount;

  /// No description provided for @settingsAccountProfile_profileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your name, bar association, and membership details'**
  String get settingsAccountProfile_profileSubtitle;

  /// No description provided for @settingsAccountProfile_appLockSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Protect the app with a PIN or fingerprint'**
  String get settingsAccountProfile_appLockSubtitle;

  /// No description provided for @settingsAccountProfile_manageAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your account details, password, and sign-out'**
  String get settingsAccountProfile_manageAccountSubtitle;

  /// No description provided for @settingsAccountProfile_managePlanSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your plan, expiry, and cancellation'**
  String get settingsAccountProfile_managePlanSubtitle;

  /// No description provided for @settingsAccountProfile_firmPlanSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your firm\'s plan, usage, and expiry'**
  String get settingsAccountProfile_firmPlanSubtitle;

  /// No description provided for @settingsAccountProfile_subscriptionPlansSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Compare plans and buy a new one'**
  String get settingsAccountProfile_subscriptionPlansSubtitle;

  /// No description provided for @settingsAccountProfile_subscriptionHistorySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Every purchase, approval, and cancellation'**
  String get settingsAccountProfile_subscriptionHistorySubtitle;

  /// No description provided for @settingsFirm_title.
  ///
  /// In en, this message translates to:
  /// **'Firm'**
  String get settingsFirm_title;

  /// No description provided for @settingsFirm_joinFirmSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Join a firm with an invitation code from its owner'**
  String get settingsFirm_joinFirmSubtitle;

  /// No description provided for @settingsFirm_viewFirmSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View your firm and its associates'**
  String get settingsFirm_viewFirmSubtitle;

  /// No description provided for @settingsAccountProfile_manageAssociatesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage your firm, its associates, and permissions'**
  String get settingsAccountProfile_manageAssociatesSubtitle;

  /// No description provided for @settingsAccountProfile_createFirmSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create a firm and invite your associates'**
  String get settingsAccountProfile_createFirmSubtitle;

  /// No description provided for @settingsAccountProfile_deleteRequestsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Review requests and track their decisions'**
  String get settingsAccountProfile_deleteRequestsSubtitle;

  /// No description provided for @settingsProfile_title.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get settingsProfile_title;

  /// No description provided for @settingsProfile_editTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get settingsProfile_editTooltip;

  /// No description provided for @settingsProfile_fullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get settingsProfile_fullName;

  /// No description provided for @settingsProfile_barAssociation.
  ///
  /// In en, this message translates to:
  /// **'Bar Association'**
  String get settingsProfile_barAssociation;

  /// No description provided for @settingsProfile_membershipNo.
  ///
  /// In en, this message translates to:
  /// **'Membership No.'**
  String get settingsProfile_membershipNo;

  /// No description provided for @settingsProfile_officeAddress.
  ///
  /// In en, this message translates to:
  /// **'Office Address'**
  String get settingsProfile_officeAddress;

  /// No description provided for @settingsProfile_mobileNo.
  ///
  /// In en, this message translates to:
  /// **'Mobile No.'**
  String get settingsProfile_mobileNo;

  /// No description provided for @settingsProfile_yourName.
  ///
  /// In en, this message translates to:
  /// **'Your Name'**
  String get settingsProfile_yourName;

  /// No description provided for @settingsProfile_editTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get settingsProfile_editTitle;

  /// No description provided for @settingsProfile_fullNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your full name'**
  String get settingsProfile_fullNameHint;

  /// No description provided for @settingsProfile_barAssociationHint.
  ///
  /// In en, this message translates to:
  /// **'Enter bar association name'**
  String get settingsProfile_barAssociationHint;

  /// No description provided for @settingsProfile_membershipNoHint.
  ///
  /// In en, this message translates to:
  /// **'Enter registration number'**
  String get settingsProfile_membershipNoHint;

  /// No description provided for @settingsProfile_officeAddressHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your office address'**
  String get settingsProfile_officeAddressHint;

  /// No description provided for @settingsProfile_save.
  ///
  /// In en, this message translates to:
  /// **'Save Profile'**
  String get settingsProfile_save;

  /// No description provided for @settingsProfile_saved.
  ///
  /// In en, this message translates to:
  /// **'Profile saved (offline)'**
  String get settingsProfile_saved;

  /// No description provided for @settingsProfile_savedOnline.
  ///
  /// In en, this message translates to:
  /// **'Profile saved'**
  String get settingsProfile_savedOnline;

  /// No description provided for @settingsManageAccount_title.
  ///
  /// In en, this message translates to:
  /// **'Manage Account'**
  String get settingsManageAccount_title;

  /// No description provided for @settingsManageAccount_changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get settingsManageAccount_changePassword;

  /// No description provided for @devices_title.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get devices_title;

  /// No description provided for @devices_subtitle.
  ///
  /// In en, this message translates to:
  /// **'The devices that can use this account at the same time.'**
  String get devices_subtitle;

  /// No description provided for @devices_limitLabel.
  ///
  /// In en, this message translates to:
  /// **'{used} of {cap} devices in use'**
  String devices_limitLabel(String used, String cap);

  /// No description provided for @devices_firmLimitLabel.
  ///
  /// In en, this message translates to:
  /// **'{used} of {cap} firm devices in use'**
  String devices_firmLimitLabel(String used, String cap);

  /// No description provided for @devices_ownerSectionCount.
  ///
  /// In en, this message translates to:
  /// **'Owner\'s Devices ({count})'**
  String devices_ownerSectionCount(String count);

  /// No description provided for @devices_associateSection.
  ///
  /// In en, this message translates to:
  /// **'Associates\' Devices'**
  String get devices_associateSection;

  /// No description provided for @devices_associateSectionCount.
  ///
  /// In en, this message translates to:
  /// **'Associates\' Devices ({count})'**
  String devices_associateSectionCount(String count);

  /// No description provided for @devices_noAssociateDevices.
  ///
  /// In en, this message translates to:
  /// **'No associate device is signed in.'**
  String get devices_noAssociateDevices;

  /// No description provided for @devices_firmUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Could not load your firm\'s devices. Pull down to try again.'**
  String get devices_firmUnavailable;

  /// No description provided for @devices_thisDevice.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get devices_thisDevice;

  /// No description provided for @devices_lastUsed.
  ///
  /// In en, this message translates to:
  /// **'Last used {date}'**
  String devices_lastUsed(String date);

  /// No description provided for @devices_remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get devices_remove;

  /// No description provided for @devices_removeTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove This Device?'**
  String get devices_removeTitle;

  /// No description provided for @devices_removeBody.
  ///
  /// In en, this message translates to:
  /// **'{name} will be signed out, and its local copy and any unsaved work will be discarded at its next connection.'**
  String devices_removeBody(String name);

  /// No description provided for @devices_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get devices_cancel;

  /// No description provided for @devices_removed.
  ///
  /// In en, this message translates to:
  /// **'Device removed.'**
  String get devices_removed;

  /// No description provided for @devices_empty.
  ///
  /// In en, this message translates to:
  /// **'No devices are registered yet.'**
  String get devices_empty;

  /// No description provided for @devices_unavailable.
  ///
  /// In en, this message translates to:
  /// **'Could not reach your account. Check your connection and try again.'**
  String get devices_unavailable;

  /// No description provided for @devices_tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get devices_tryAgain;

  /// No description provided for @devices_signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get devices_signOut;

  /// No description provided for @devices_planFullTitle.
  ///
  /// In en, this message translates to:
  /// **'Device Limit Reached'**
  String get devices_planFullTitle;

  /// No description provided for @devices_planFullBody.
  ///
  /// In en, this message translates to:
  /// **'You’re already signed in on {count} devices, which is the maximum allowed by your plan. To sign in on this device, please sign out from one of the devices listed below.'**
  String devices_planFullBody(String count);

  /// No description provided for @devices_planFullWarningLabel.
  ///
  /// In en, this message translates to:
  /// **'Warning:'**
  String get devices_planFullWarningLabel;

  /// No description provided for @devices_planFullWarning.
  ///
  /// In en, this message translates to:
  /// **'Any unsaved or unsynced work on the device you sign out from may be lost.'**
  String get devices_planFullWarning;

  /// No description provided for @devices_signOutThisDevice.
  ///
  /// In en, this message translates to:
  /// **'Sign Out This Device'**
  String get devices_signOutThisDevice;

  /// No description provided for @devices_signOutFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not sign out this device. Try again.'**
  String get devices_signOutFailed;

  /// No description provided for @devices_checkingTitle.
  ///
  /// In en, this message translates to:
  /// **'Checking This Device'**
  String get devices_checkingTitle;

  /// No description provided for @devices_checkingBody.
  ///
  /// In en, this message translates to:
  /// **'Confirming that this device has a free slot on your plan.'**
  String get devices_checkingBody;

  /// No description provided for @devices_checkFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Could Not Check This Device'**
  String get devices_checkFailedTitle;

  /// No description provided for @devices_checkFailedBody.
  ///
  /// In en, this message translates to:
  /// **'Connect to the internet and try again, or sign out of this device.'**
  String get devices_checkFailedBody;

  /// No description provided for @devices_signingOut.
  ///
  /// In en, this message translates to:
  /// **'Signing out…'**
  String get devices_signingOut;

  /// No description provided for @devices_signedOutBody.
  ///
  /// In en, this message translates to:
  /// **'This device was signed out from another device. Its local copy is being erased.'**
  String get devices_signedOutBody;

  /// No description provided for @devices_signedOutFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not erase this device. Try again.'**
  String get devices_signedOutFailed;

  /// No description provided for @devices_sessionInUseTitle.
  ///
  /// In en, this message translates to:
  /// **'This Sign-In Was Ended'**
  String get devices_sessionInUseTitle;

  /// No description provided for @devices_sessionInUseBody.
  ///
  /// In en, this message translates to:
  /// **'This sign-in was opened somewhere else, so the app ended it here to protect your diary. This device\'s local copy is being erased.'**
  String get devices_sessionInUseBody;

  /// No description provided for @devices_replacedTitle.
  ///
  /// In en, this message translates to:
  /// **'This Sign-In Has Ended'**
  String get devices_replacedTitle;

  /// No description provided for @devices_replacedBody.
  ///
  /// In en, this message translates to:
  /// **'You signed in again on this device, so this sign-in has ended. Your local data is kept.'**
  String get devices_replacedBody;

  /// No description provided for @devices_revokedTitle.
  ///
  /// In en, this message translates to:
  /// **'This Device Was Signed Out'**
  String get devices_revokedTitle;

  /// No description provided for @devices_revokedBody.
  ///
  /// In en, this message translates to:
  /// **'Your plan allows {cap} device(s) at a time, and another device took this one\'s place. Any unsaved work on this device is discarded.'**
  String devices_revokedBody(String cap);

  /// No description provided for @devices_limitRevokedLeadPro.
  ///
  /// In en, this message translates to:
  /// **'Your Pro plan allows a maximum of'**
  String get devices_limitRevokedLeadPro;

  /// No description provided for @devices_limitRevokedLead.
  ///
  /// In en, this message translates to:
  /// **'Your plan allows a maximum of'**
  String get devices_limitRevokedLead;

  /// No description provided for @devices_limitRevokedLimit.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 device to be signed in at the same time} other{{count} devices to be signed in at the same time}}'**
  String devices_limitRevokedLimit(int count);

  /// No description provided for @devices_limitRevokedTally.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{. You’re already signed in on 1 device, so you’ve been signed out on this device.} other{. You’re already signed in on {count} devices, so you’ve been signed out on this device.}}'**
  String devices_limitRevokedTally(int count);

  /// No description provided for @devices_limitRevokedDiscarded.
  ///
  /// In en, this message translates to:
  /// **'Any unsaved or unsynced work on this device has been discarded.'**
  String get devices_limitRevokedDiscarded;

  /// No description provided for @devices_limitRevokedRelogin.
  ///
  /// In en, this message translates to:
  /// **'To continue using this device, please log in again using the button below.'**
  String get devices_limitRevokedRelogin;

  /// No description provided for @devices_backToLogin.
  ///
  /// In en, this message translates to:
  /// **'Back to Login'**
  String get devices_backToLogin;

  /// No description provided for @devices_revokedRemovedBody.
  ///
  /// In en, this message translates to:
  /// **'You removed this device from your device list. Any unsaved work on this device is discarded.'**
  String get devices_revokedRemovedBody;

  /// No description provided for @devices_capacityRevokedBody.
  ///
  /// In en, this message translates to:
  /// **'Your firm no longer has a slot for this device, so it has been signed out and its local copy is being erased. Your account is still a member of the firm — ask the owner to make room.'**
  String get devices_capacityRevokedBody;

  /// No description provided for @devices_removedRevokedBody.
  ///
  /// In en, this message translates to:
  /// **'The firm owner removed this account, so this device has been signed out and its local copy is being erased.'**
  String get devices_removedRevokedBody;

  /// No description provided for @devices_evicted.
  ///
  /// In en, this message translates to:
  /// **'{name} was signed out to make room for this device.'**
  String devices_evicted(String name);

  /// No description provided for @settingsSubscription_freePlanLimitations.
  ///
  /// In en, this message translates to:
  /// **'Free Plan Limitations'**
  String get settingsSubscription_freePlanLimitations;

  /// No description provided for @settingsSubscription_lapsedTitle.
  ///
  /// In en, this message translates to:
  /// **'Limited Access Mode'**
  String get settingsSubscription_lapsedTitle;

  /// No description provided for @settingsSubscription_lapsedBody.
  ///
  /// In en, this message translates to:
  /// **'Your subscription plan has expired. You can still read everything. Up to {count} most recent cases, notes and case references stay editable until you renew.'**
  String settingsSubscription_lapsedBody(String count);

  /// Limited Access: the reason is a cancellation, not the date running out.
  ///
  /// In en, this message translates to:
  /// **'You recently cancelled your subscription plan. You can still read everything. Up to {count} most recent cases, notes and case references stay editable until you renew.'**
  String settingsSubscription_lapsedBodyCancelled(String count);

  /// No description provided for @settingsSubscription_freeLimitCasesPrefix.
  ///
  /// In en, this message translates to:
  /// **'Manage up to '**
  String get settingsSubscription_freeLimitCasesPrefix;

  /// The bold part of the free-plan case limitation.
  ///
  /// In en, this message translates to:
  /// **'{count} cases'**
  String settingsSubscription_freeLimitCasesBold(String count);

  /// No description provided for @settingsSubscription_freeLimitCasesSuffix.
  ///
  /// In en, this message translates to:
  /// **' at a time.'**
  String get settingsSubscription_freeLimitCasesSuffix;

  /// No description provided for @settingsSubscription_freeLimitCloud.
  ///
  /// In en, this message translates to:
  /// **'Cloud features—including real-time backup, syncing your diary across multiple devices and collaborating in a firm—require a subscription.'**
  String get settingsSubscription_freeLimitCloud;

  /// No description provided for @settingsSubscription_freeLimitRecoveryBold.
  ///
  /// In en, this message translates to:
  /// **'No cloud backup:'**
  String get settingsSubscription_freeLimitRecoveryBold;

  /// No description provided for @settingsSubscription_freeLimitRecoverySuffix.
  ///
  /// In en, this message translates to:
  /// **' If your phone is lost or damaged, you won\'t be able to restore your diary from a cloud backup.'**
  String get settingsSubscription_freeLimitRecoverySuffix;

  /// No description provided for @settingsSubscription_upgradeTitle.
  ///
  /// In en, this message translates to:
  /// **'Want to Upgrade?'**
  String get settingsSubscription_upgradeTitle;

  /// No description provided for @settingsSubscription_upgradeBody.
  ///
  /// In en, this message translates to:
  /// **'Enjoy higher case limits and more cloud features with a subscription starting at:'**
  String get settingsSubscription_upgradeBody;

  /// The bold monthly rate in the upgrade block.
  ///
  /// In en, this message translates to:
  /// **'৳{rate}/month'**
  String settingsSubscription_upgradeRate(String rate);

  /// No description provided for @settingsSubscription_upgradeQuarterly.
  ///
  /// In en, this message translates to:
  /// **' with the 3-month plan'**
  String get settingsSubscription_upgradeQuarterly;

  /// No description provided for @settingsSubscription_upgradeHalfYearly.
  ///
  /// In en, this message translates to:
  /// **' with the 6-month plan'**
  String get settingsSubscription_upgradeHalfYearly;

  /// No description provided for @settingsSubscription_upgradeAnnual.
  ///
  /// In en, this message translates to:
  /// **' with the 1-year plan'**
  String get settingsSubscription_upgradeAnnual;

  /// No description provided for @settingsSubscription_upgradeHint.
  ///
  /// In en, this message translates to:
  /// **'Tap the button below to explore the available subscription plans and learn more.'**
  String get settingsSubscription_upgradeHint;

  /// No description provided for @settingsSubscription_currentPlan.
  ///
  /// In en, this message translates to:
  /// **'Current Plan'**
  String get settingsSubscription_currentPlan;

  /// No description provided for @settingsSubscription_paid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get settingsSubscription_paid;

  /// No description provided for @settingsSubscription_dateTime.
  ///
  /// In en, this message translates to:
  /// **'Date & Time'**
  String get settingsSubscription_dateTime;

  /// No description provided for @settingsSubscription_title.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get settingsSubscription_title;

  /// No description provided for @settingsSubscription_managePlanTitle.
  ///
  /// In en, this message translates to:
  /// **'Manage Plan'**
  String get settingsSubscription_managePlanTitle;

  /// No description provided for @settingsSubscription_firmPlanTitle.
  ///
  /// In en, this message translates to:
  /// **'Firm Plan'**
  String get settingsSubscription_firmPlanTitle;

  /// No description provided for @settingsSubscription_planUsage.
  ///
  /// In en, this message translates to:
  /// **'Plan Usage'**
  String get settingsSubscription_planUsage;

  /// No description provided for @settingsSubscription_usageCases.
  ///
  /// In en, this message translates to:
  /// **'Cases'**
  String get settingsSubscription_usageCases;

  /// No description provided for @settingsSubscription_usageRemaining.
  ///
  /// In en, this message translates to:
  /// **'{count} left'**
  String settingsSubscription_usageRemaining(String count);

  /// No description provided for @settingsSubscription_usageOfLimit.
  ///
  /// In en, this message translates to:
  /// **'{used} of {limit} used'**
  String settingsSubscription_usageOfLimit(String used, String limit);

  /// No description provided for @settingsSubscription_usageFirmNote.
  ///
  /// In en, this message translates to:
  /// **'Cases are counted across the whole chamber.'**
  String get settingsSubscription_usageFirmNote;

  /// No description provided for @settingsSubscription_usageSeats.
  ///
  /// In en, this message translates to:
  /// **'Seats and Devices'**
  String get settingsSubscription_usageSeats;

  /// No description provided for @settingsSubscription_usageSeatsNote.
  ///
  /// In en, this message translates to:
  /// **'Your associates and your own signed-in devices share these slots.'**
  String get settingsSubscription_usageSeatsNote;

  /// No description provided for @settingsSubscription_usageSignedOut.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 associate is not signed in.} other{{count} associates are not signed in.}}'**
  String settingsSubscription_usageSignedOut(int count);

  /// No description provided for @settingsSubscription_capacityShrinkTitle.
  ///
  /// In en, this message translates to:
  /// **'Capacity Changes Soon'**
  String get settingsSubscription_capacityShrinkTitle;

  /// No description provided for @settingsSubscription_capacityShrinkBody.
  ///
  /// In en, this message translates to:
  /// **'From {date}, your firm allows {slots} devices in total. You have {associates} associates and {devices} devices of your own. Sign out a device or remove an associate before then; otherwise the extra ones are signed out automatically.'**
  String settingsSubscription_capacityShrinkBody(
    String date,
    String slots,
    String associates,
    String devices,
  );

  /// No description provided for @settingsSubscription_capacityOverBody.
  ///
  /// In en, this message translates to:
  /// **'Your firm has more associates than its plan allows. Remove associates to free seats; until then no new associate can join.'**
  String get settingsSubscription_capacityOverBody;

  /// No description provided for @settingsSubscription_capacityDevicesOverBody.
  ///
  /// In en, this message translates to:
  /// **'This account has more devices than the plan allows. Sign one out under Devices to free a slot.'**
  String get settingsSubscription_capacityDevicesOverBody;

  /// No description provided for @settingsSubscription_capacityFrozenBody.
  ///
  /// In en, this message translates to:
  /// **'Your firm\'s subscription has ended. No new associates can join until it is renewed. Current members keep working on their devices; nothing syncs.'**
  String get settingsSubscription_capacityFrozenBody;

  /// No description provided for @settingsSubscription_manageSubscription.
  ///
  /// In en, this message translates to:
  /// **'Manage Subscription'**
  String get settingsSubscription_manageSubscription;

  /// No description provided for @settingsSubscription_renewSubscription.
  ///
  /// In en, this message translates to:
  /// **'Renew Subscription'**
  String get settingsSubscription_renewSubscription;

  /// No description provided for @settingsSubscription_cancelSubscription.
  ///
  /// In en, this message translates to:
  /// **'Cancel Subscription'**
  String get settingsSubscription_cancelSubscription;

  /// No description provided for @settingsManageAccount_purchaseNewSubscription.
  ///
  /// In en, this message translates to:
  /// **'Subscription Plans'**
  String get settingsManageAccount_purchaseNewSubscription;

  /// No description provided for @settingsManageAccount_logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get settingsManageAccount_logout;

  /// No description provided for @settingsManageAccount_deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get settingsManageAccount_deleteAccount;

  /// No description provided for @settingsManageAccount_deleteCannotBeUndone.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone'**
  String get settingsManageAccount_deleteCannotBeUndone;

  /// No description provided for @settingsManageAccount_deleteLocalAndCloudData.
  ///
  /// In en, this message translates to:
  /// **'Delete Local & Cloud Data'**
  String get settingsManageAccount_deleteLocalAndCloudData;

  /// No description provided for @settingsManageAccount_deleteLocalData.
  ///
  /// In en, this message translates to:
  /// **'Delete Local Data'**
  String get settingsManageAccount_deleteLocalData;

  /// No description provided for @settingsManageAccount_deleteDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Data?'**
  String get settingsManageAccount_deleteDataTitle;

  /// No description provided for @settingsManageAccount_deleteLocalDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Local Data?'**
  String get settingsManageAccount_deleteLocalDataTitle;

  /// No description provided for @settingsManageAccount_deleteDataBodyCloud.
  ///
  /// In en, this message translates to:
  /// **'Tick what to delete from this device and your account. Your profile, subscription and settings stay.'**
  String get settingsManageAccount_deleteDataBodyCloud;

  /// No description provided for @settingsManageAccount_deleteDataBodyLocal.
  ///
  /// In en, this message translates to:
  /// **'Tick what to delete from this device. Your profile, subscription and settings stay.'**
  String get settingsManageAccount_deleteDataBodyLocal;

  /// No description provided for @settingsManageAccount_deleteDataCases.
  ///
  /// In en, this message translates to:
  /// **'Cases'**
  String get settingsManageAccount_deleteDataCases;

  /// No description provided for @settingsManageAccount_deleteDataNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get settingsManageAccount_deleteDataNotes;

  /// No description provided for @settingsManageAccount_deleteDataCaseReferences.
  ///
  /// In en, this message translates to:
  /// **'Case References'**
  String get settingsManageAccount_deleteDataCaseReferences;

  /// No description provided for @settingsManageAccount_deleteDataCustomSeedData.
  ///
  /// In en, this message translates to:
  /// **'Custom Seed Data'**
  String get settingsManageAccount_deleteDataCustomSeedData;

  /// No description provided for @settingsManageAccount_deleteDataCustomSeedDataHint.
  ///
  /// In en, this message translates to:
  /// **'Court categories, court names, steps, case types and on-behalfs you added'**
  String get settingsManageAccount_deleteDataCustomSeedDataHint;

  /// No description provided for @settingsManageAccount_deleteDataConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete Selected'**
  String get settingsManageAccount_deleteDataConfirm;

  /// No description provided for @settingsManageAccount_deleteDataConfirmPhrase.
  ///
  /// In en, this message translates to:
  /// **'delete my data'**
  String get settingsManageAccount_deleteDataConfirmPhrase;

  /// No description provided for @settingsManageAccount_deleteDataDone.
  ///
  /// In en, this message translates to:
  /// **'Your selected data has been deleted.'**
  String get settingsManageAccount_deleteDataDone;

  /// No description provided for @settingsManageAccount_deleteDataCloudPending.
  ///
  /// In en, this message translates to:
  /// **'Your data was deleted from this device. The account\'s copies will be removed on the next sync.'**
  String get settingsManageAccount_deleteDataCloudPending;

  /// No description provided for @settingsManageAccount_deleteDataNeedsConnection.
  ///
  /// In en, this message translates to:
  /// **'Connect to the internet to delete your cloud data. Nothing has been deleted.'**
  String get settingsManageAccount_deleteDataNeedsConnection;

  /// No description provided for @settingsManageAccount_deleteDataFirmRefused.
  ///
  /// In en, this message translates to:
  /// **'You are part of a firm, so your diary is shared with it. Ask the firm owner to remove you before deleting your data.'**
  String get settingsManageAccount_deleteDataFirmRefused;

  /// No description provided for @settingsManageAccount_deleteDataFailed.
  ///
  /// In en, this message translates to:
  /// **'Your data could not be deleted. Please try again.'**
  String get settingsManageAccount_deleteDataFailed;

  /// No description provided for @settingsManageAccount_dangerZone.
  ///
  /// In en, this message translates to:
  /// **'Danger Zone'**
  String get settingsManageAccount_dangerZone;

  /// No description provided for @settingsManageAccount_deleted.
  ///
  /// In en, this message translates to:
  /// **'Your account has been deleted.'**
  String get settingsManageAccount_deleted;

  /// No description provided for @settingsManageAccount_deleteDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Account?'**
  String get settingsManageAccount_deleteDialogTitle;

  /// No description provided for @settingsManageAccount_deleteWarningFree.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes your account and every case, note, case reference and setting on this device. Nothing can be recovered after this.'**
  String get settingsManageAccount_deleteWarningFree;

  /// No description provided for @settingsManageAccount_deleteWarningPremium.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes your account and every case, note, case reference and setting on this device and in the cloud. Nothing can be recovered after this.'**
  String get settingsManageAccount_deleteWarningPremium;

  /// No description provided for @settingsManageAccount_deleteConfirmPhrase.
  ///
  /// In en, this message translates to:
  /// **'delete my account'**
  String get settingsManageAccount_deleteConfirmPhrase;

  /// No description provided for @settingsManageAccount_deleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Type {phrase} below to confirm.'**
  String settingsManageAccount_deleteConfirmBody(String phrase);

  /// No description provided for @settingsManageAccount_deleteNeedsConnection.
  ///
  /// In en, this message translates to:
  /// **'Connect to the internet to delete your account. Nothing has been deleted.'**
  String get settingsManageAccount_deleteNeedsConnection;

  /// No description provided for @settingsManageAccount_deleteFirmRefused.
  ///
  /// In en, this message translates to:
  /// **'You are part of a firm, so some of your data is shared with it. Ask the firm owner to remove you before deleting your account.'**
  String get settingsManageAccount_deleteFirmRefused;

  /// No description provided for @settingsManageAccount_deleteAdminRefused.
  ///
  /// In en, this message translates to:
  /// **'An administrator account cannot be deleted from the app.'**
  String get settingsManageAccount_deleteAdminRefused;

  /// No description provided for @settingsManageAccount_deleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Your account could not be deleted. Please try again.'**
  String get settingsManageAccount_deleteFailed;

  /// No description provided for @settingsManageAccount_loggedOut.
  ///
  /// In en, this message translates to:
  /// **'You have been logged out.'**
  String get settingsManageAccount_loggedOut;

  /// No description provided for @settingsManageAccount_role.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get settingsManageAccount_role;

  /// No description provided for @settingsManageAccount_roleIndividual.
  ///
  /// In en, this message translates to:
  /// **'Individual'**
  String get settingsManageAccount_roleIndividual;

  /// No description provided for @settingsManageAccount_roleOwner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get settingsManageAccount_roleOwner;

  /// No description provided for @settingsManageAccount_roleAssociate.
  ///
  /// In en, this message translates to:
  /// **'Associate'**
  String get settingsManageAccount_roleAssociate;

  /// No description provided for @settingsManageAccount_roleViewer.
  ///
  /// In en, this message translates to:
  /// **'Viewer'**
  String get settingsManageAccount_roleViewer;

  /// No description provided for @settingsManageAccount_firm.
  ///
  /// In en, this message translates to:
  /// **'Firm'**
  String get settingsManageAccount_firm;

  /// No description provided for @settingsManageAccount_subscription.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get settingsManageAccount_subscription;

  /// No description provided for @settingsManageAccount_planFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get settingsManageAccount_planFree;

  /// No description provided for @settingsManageAccount_planPremium.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get settingsManageAccount_planPremium;

  /// No description provided for @settingsManageAccount_planLimitedAccessTag.
  ///
  /// In en, this message translates to:
  /// **'[Limited Access]'**
  String get settingsManageAccount_planLimitedAccessTag;

  /// No description provided for @settingsManageAccount_premiumUntil.
  ///
  /// In en, this message translates to:
  /// **'Premium Until {date}'**
  String settingsManageAccount_premiumUntil(String date);

  /// No description provided for @settingsOnlineSync_title.
  ///
  /// In en, this message translates to:
  /// **'Online Sync'**
  String get settingsOnlineSync_title;

  /// No description provided for @settingsOnlineSync_cases.
  ///
  /// In en, this message translates to:
  /// **'Cases'**
  String get settingsOnlineSync_cases;

  /// No description provided for @settingsOnlineSync_notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get settingsOnlineSync_notes;

  /// No description provided for @settingsOnlineSync_references.
  ///
  /// In en, this message translates to:
  /// **'References'**
  String get settingsOnlineSync_references;

  /// No description provided for @settingsOnlineSync_notSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Not signed in'**
  String get settingsOnlineSync_notSignedIn;

  /// No description provided for @settingsOnlineSync_signInPrompt.
  ///
  /// In en, this message translates to:
  /// **'Sign in to sync your data across all your devices'**
  String get settingsOnlineSync_signInPrompt;

  /// No description provided for @settingsOnlineSync_actionRequired.
  ///
  /// In en, this message translates to:
  /// **'Action Required'**
  String get settingsOnlineSync_actionRequired;

  /// No description provided for @settingsOnlineSync_lastSyncNever.
  ///
  /// In en, this message translates to:
  /// **'Last Sync: Never'**
  String get settingsOnlineSync_lastSyncNever;

  /// No description provided for @settingsOnlineSync_dataStaysOnDevice.
  ///
  /// In en, this message translates to:
  /// **'Your data stays on this device until you sign in.'**
  String get settingsOnlineSync_dataStaysOnDevice;

  /// No description provided for @settingsOnlineSync_syncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync Now'**
  String get settingsOnlineSync_syncNow;

  /// No description provided for @settingsOnlineSync_notSynced.
  ///
  /// In en, this message translates to:
  /// **'Not synced'**
  String get settingsOnlineSync_notSynced;

  /// No description provided for @settingsOnlineSync_synced.
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get settingsOnlineSync_synced;

  /// No description provided for @settingsOnlineSync_notSyncedSignedOut.
  ///
  /// In en, this message translates to:
  /// **'Sign in to sync'**
  String get settingsOnlineSync_notSyncedSignedOut;

  /// No description provided for @settingsOnlineSync_pendingSyncTitle.
  ///
  /// In en, this message translates to:
  /// **'Pending Sync'**
  String get settingsOnlineSync_pendingSyncTitle;

  /// No description provided for @settingsOnlineSync_pendingSyncSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Every Change Waiting To Be Sent'**
  String get settingsOnlineSync_pendingSyncSubtitle;

  /// No description provided for @settingsOnlineSync_signedIn.
  ///
  /// In en, this message translates to:
  /// **'Signed In'**
  String get settingsOnlineSync_signedIn;

  /// No description provided for @settingsOnlineSync_signedInAs.
  ///
  /// In en, this message translates to:
  /// **'Signed In As {name}'**
  String settingsOnlineSync_signedInAs(String name);

  /// No description provided for @settingsOnlineSync_premiumActive.
  ///
  /// In en, this message translates to:
  /// **'Premium Sync Is Active Across Your Devices'**
  String get settingsOnlineSync_premiumActive;

  /// No description provided for @settingsOnlineSync_freePlan.
  ///
  /// In en, this message translates to:
  /// **'Free Plan — Your Diary Stays On This Device'**
  String get settingsOnlineSync_freePlan;

  /// No description provided for @settingsOnlineSync_freePlanPill.
  ///
  /// In en, this message translates to:
  /// **'Free Plan'**
  String get settingsOnlineSync_freePlanPill;

  /// No description provided for @settingsOnlineSync_freePlanHint.
  ///
  /// In en, this message translates to:
  /// **'A subscription plan is required to sync across devices. Purchase a plan from'**
  String get settingsOnlineSync_freePlanHint;

  /// No description provided for @settingsOnlineSync_freePlanHintLink.
  ///
  /// In en, this message translates to:
  /// **'here'**
  String get settingsOnlineSync_freePlanHintLink;

  /// No description provided for @settingsOnlineSync_freePlanHintSuffix.
  ///
  /// In en, this message translates to:
  /// **'.'**
  String get settingsOnlineSync_freePlanHintSuffix;

  /// No description provided for @settingsOnlineSync_upToDate.
  ///
  /// In en, this message translates to:
  /// **'Up To Date'**
  String get settingsOnlineSync_upToDate;

  /// No description provided for @settingsOnlineSync_syncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get settingsOnlineSync_syncing;

  /// No description provided for @settingsOnlineSync_paused.
  ///
  /// In en, this message translates to:
  /// **'Sync Paused'**
  String get settingsOnlineSync_paused;

  /// No description provided for @settingsOnlineSync_offline.
  ///
  /// In en, this message translates to:
  /// **'No Connection'**
  String get settingsOnlineSync_offline;

  /// No description provided for @settingsOnlineSync_actionRequiredBody.
  ///
  /// In en, this message translates to:
  /// **'Some changes could not be sent. Open Sync Status to review them.'**
  String get settingsOnlineSync_actionRequiredBody;

  /// No description provided for @settingsOnlineSync_lastSyncAt.
  ///
  /// In en, this message translates to:
  /// **'Last Sync: {when}'**
  String settingsOnlineSync_lastSyncAt(String when);

  /// No description provided for @settingsOnlineSync_pendingUploads.
  ///
  /// In en, this message translates to:
  /// **'{count} Waiting To Send'**
  String settingsOnlineSync_pendingUploads(int count);

  /// No description provided for @settingsOnlineSync_pendingNone.
  ///
  /// In en, this message translates to:
  /// **'Everything is backed up to your account.'**
  String get settingsOnlineSync_pendingNone;

  /// No description provided for @settingsOnlineSync_pendingCount.
  ///
  /// In en, this message translates to:
  /// **'{count} Waiting'**
  String settingsOnlineSync_pendingCount(int count);

  /// No description provided for @settingsOnlineSync_syncFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync did not complete. Your changes are safe on this device.'**
  String get settingsOnlineSync_syncFailed;

  /// No description provided for @settingsOnlineSync_syncFinished.
  ///
  /// In en, this message translates to:
  /// **'Sync Finished.'**
  String get settingsOnlineSync_syncFinished;

  /// No description provided for @settingsOnlineSync_needSignInToSync.
  ///
  /// In en, this message translates to:
  /// **'Sign in to sync across devices.'**
  String get settingsOnlineSync_needSignInToSync;

  /// No description provided for @settingsOnlineSync_needConnectionToSync.
  ///
  /// In en, this message translates to:
  /// **'No connection. Your changes are saved on this device.'**
  String get settingsOnlineSync_needConnectionToSync;

  /// No description provided for @settingsOnlineSync_checkingPlan.
  ///
  /// In en, this message translates to:
  /// **'Checking Your Subscription…'**
  String get settingsOnlineSync_checkingPlan;

  /// No description provided for @settingsOnlineSync_checkingPlanBody.
  ///
  /// In en, this message translates to:
  /// **'Confirming your plan before anything is sent.'**
  String get settingsOnlineSync_checkingPlanBody;

  /// No description provided for @settingsOnlineSync_checkingPlanMessage.
  ///
  /// In en, this message translates to:
  /// **'Sync starts as soon as your plan is confirmed.'**
  String get settingsOnlineSync_checkingPlanMessage;

  /// No description provided for @settingsOnlineSync_itemsUnknown.
  ///
  /// In en, this message translates to:
  /// **'— Items'**
  String get settingsOnlineSync_itemsUnknown;

  /// ONLINE SYNC
  ///
  /// In en, this message translates to:
  /// **'{count} Items'**
  String settingsOnlineSync_itemsCount(int count);

  /// No description provided for @settingsOnlineSync_syncOff.
  ///
  /// In en, this message translates to:
  /// **'Sync Off'**
  String get settingsOnlineSync_syncOff;

  /// No description provided for @settingsOnlineSync_syncOffBody.
  ///
  /// In en, this message translates to:
  /// **'Sync is off. Turn it back on to send and receive your changes.'**
  String get settingsOnlineSync_syncOffBody;

  /// No description provided for @settingsOnlineSync_syncOffMessage.
  ///
  /// In en, this message translates to:
  /// **'Sync is off. Turn it back on to sync.'**
  String get settingsOnlineSync_syncOffMessage;

  /// No description provided for @settingsOnlineSync_syncOnTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync Is On'**
  String get settingsOnlineSync_syncOnTitle;

  /// No description provided for @settingsOnlineSync_syncOnBody.
  ///
  /// In en, this message translates to:
  /// **'Turn sync off to keep your changes on this device for now. You can turn it back on here at any time.'**
  String get settingsOnlineSync_syncOnBody;

  /// No description provided for @settingsOnlineSync_syncOffTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync Is Off'**
  String get settingsOnlineSync_syncOffTitle;

  /// No description provided for @settingsOnlineSync_syncOffCardBody.
  ///
  /// In en, this message translates to:
  /// **'Nothing is sent or received while sync is off. Your changes stay on this device, and sync turns back on when the app is restarted.'**
  String get settingsOnlineSync_syncOffCardBody;

  /// No description provided for @settingsOnlineSync_disableSync.
  ///
  /// In en, this message translates to:
  /// **'Disable Sync'**
  String get settingsOnlineSync_disableSync;

  /// No description provided for @settingsOnlineSync_enableSync.
  ///
  /// In en, this message translates to:
  /// **'Enable Sync'**
  String get settingsOnlineSync_enableSync;

  /// No description provided for @settingsOnlineSync_syncOffToast.
  ///
  /// In en, this message translates to:
  /// **'Sync is off. Your changes stay on this device.'**
  String get settingsOnlineSync_syncOffToast;

  /// No description provided for @settingsOnlineSync_syncOnToast.
  ///
  /// In en, this message translates to:
  /// **'Sync is on again.'**
  String get settingsOnlineSync_syncOnToast;

  /// No description provided for @settingsBackupRestore_title.
  ///
  /// In en, this message translates to:
  /// **'Backup & Restore'**
  String get settingsBackupRestore_title;

  /// No description provided for @settingsBackupRestore_chooseBackupTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose the backup to restore'**
  String get settingsBackupRestore_chooseBackupTitle;

  /// No description provided for @backupScheduled_skipNoticeTitle.
  ///
  /// In en, this message translates to:
  /// **'Automatic backup skipped'**
  String get backupScheduled_skipNoticeTitle;

  /// No description provided for @backupScheduled_skipNoticeBody.
  ///
  /// In en, this message translates to:
  /// **'Backups are encrypted with a passphrase only you know, so the automatic backup cannot run. Open Legal Case Diary and back up manually.'**
  String get backupScheduled_skipNoticeBody;

  /// No description provided for @backupScheduled_noticeChannelName.
  ///
  /// In en, this message translates to:
  /// **'Backup reminders'**
  String get backupScheduled_noticeChannelName;

  /// No description provided for @backupScheduled_noticeChannelDescription.
  ///
  /// In en, this message translates to:
  /// **'Reminders about your automatic backups.'**
  String get backupScheduled_noticeChannelDescription;

  /// No description provided for @settingsBackupRestore_sectionBackup.
  ///
  /// In en, this message translates to:
  /// **'Backup & Restore'**
  String get settingsBackupRestore_sectionBackup;

  /// No description provided for @settingsBackupRestore_sectionBackupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Back Up Or Restore Your Diary'**
  String get settingsBackupRestore_sectionBackupSubtitle;

  /// No description provided for @settingsBackupRestore_sectionEncryption.
  ///
  /// In en, this message translates to:
  /// **'Encryption On Backup'**
  String get settingsBackupRestore_sectionEncryption;

  /// No description provided for @settingsBackupRestore_sectionEncryptionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Protect Backups With A Passphrase'**
  String get settingsBackupRestore_sectionEncryptionSubtitle;

  /// No description provided for @settingsBackupRestore_encryptionWhy.
  ///
  /// In en, this message translates to:
  /// **'Encrypting a backup locks the file behind a passphrase you choose, so anyone who gets it cannot read your case data.'**
  String get settingsBackupRestore_encryptionWhy;

  /// No description provided for @settingsBackupRestore_encryptionCost.
  ///
  /// In en, this message translates to:
  /// **'The passphrase is never stored. If you forget it, that backup can never be restored, so keep it somewhere safe.'**
  String get settingsBackupRestore_encryptionCost;

  /// No description provided for @settingsBackupRestore_encryptionStateOn.
  ///
  /// In en, this message translates to:
  /// **'Encryption is currently on'**
  String get settingsBackupRestore_encryptionStateOn;

  /// No description provided for @settingsBackupRestore_encryptionStateOff.
  ///
  /// In en, this message translates to:
  /// **'Encryption is currently off'**
  String get settingsBackupRestore_encryptionStateOff;

  /// No description provided for @settingsBackupRestore_encryptionEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get settingsBackupRestore_encryptionEnable;

  /// No description provided for @settingsBackupRestore_encryptionDisable.
  ///
  /// In en, this message translates to:
  /// **'Disable'**
  String get settingsBackupRestore_encryptionDisable;

  /// No description provided for @settingsBackupRestore_sectionAutomaticBackup.
  ///
  /// In en, this message translates to:
  /// **'Automatic Backup'**
  String get settingsBackupRestore_sectionAutomaticBackup;

  /// No description provided for @settingsBackupRestore_sectionAutomaticBackupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose How Often Your Diary Backs Up'**
  String get settingsBackupRestore_sectionAutomaticBackupSubtitle;

  /// No description provided for @settingsBackupRestore_sectionStatus.
  ///
  /// In en, this message translates to:
  /// **'Backup Status'**
  String get settingsBackupRestore_sectionStatus;

  /// No description provided for @settingsBackupRestore_backupLocal.
  ///
  /// In en, this message translates to:
  /// **'Backup to Local Storage'**
  String get settingsBackupRestore_backupLocal;

  /// No description provided for @settingsBackupRestore_backupDrive.
  ///
  /// In en, this message translates to:
  /// **'Backup to Google Drive'**
  String get settingsBackupRestore_backupDrive;

  /// No description provided for @settingsBackupRestore_restore.
  ///
  /// In en, this message translates to:
  /// **'Restore from Backup'**
  String get settingsBackupRestore_restore;

  /// No description provided for @settingsBackupRestore_encryptionNote.
  ///
  /// In en, this message translates to:
  /// **'Backups are saved to your local storage or cloud provider. Turn on Encryption On Backup to lock them behind a passphrase. Restoration will overwrite current data.'**
  String get settingsBackupRestore_encryptionNote;

  /// No description provided for @settingsBackupRestore_offlineNote.
  ///
  /// In en, this message translates to:
  /// **'Note: Restoration is available for offline accounts only.'**
  String get settingsBackupRestore_offlineNote;

  /// No description provided for @settingsBackupRestore_lastSuccessfulBackup.
  ///
  /// In en, this message translates to:
  /// **'Last Successful Backup'**
  String get settingsBackupRestore_lastSuccessfulBackup;

  /// No description provided for @settingsBackupRestore_lastBackupPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'No backup has been made yet.'**
  String get settingsBackupRestore_lastBackupPlaceholder;

  /// No description provided for @backupNudge_message.
  ///
  /// In en, this message translates to:
  /// **'You have not backed up this month. Your cases live only on this phone — save a backup to keep them safe.'**
  String get backupNudge_message;

  /// No description provided for @backupNudge_action.
  ///
  /// In en, this message translates to:
  /// **'Back up to local storage'**
  String get backupNudge_action;

  /// No description provided for @backupNudge_dismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss for this month'**
  String get backupNudge_dismiss;

  /// No description provided for @settingsBackupRestore_driveShareTitle.
  ///
  /// In en, this message translates to:
  /// **'Send to Google Drive?'**
  String get settingsBackupRestore_driveShareTitle;

  /// No description provided for @settingsBackupRestore_driveShareBody.
  ///
  /// In en, this message translates to:
  /// **'Your backup is saved. Send it to Google Drive from the share sheet.'**
  String get settingsBackupRestore_driveShareBody;

  /// No description provided for @settingsBackupRestore_driveShareSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get settingsBackupRestore_driveShareSend;

  /// No description provided for @settingsBackupRestore_driveShareNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get settingsBackupRestore_driveShareNotNow;

  /// No description provided for @settingsBackupRestore_shareFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the share sheet.'**
  String get settingsBackupRestore_shareFailed;

  /// No description provided for @settingsBackupRestore_shareSubject.
  ///
  /// In en, this message translates to:
  /// **'Legal Case Diary backup'**
  String get settingsBackupRestore_shareSubject;

  /// No description provided for @settingsBackupRestore_scheduleOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get settingsBackupRestore_scheduleOff;

  /// No description provided for @settingsBackupRestore_scheduleEveryday.
  ///
  /// In en, this message translates to:
  /// **'Everyday'**
  String get settingsBackupRestore_scheduleEveryday;

  /// No description provided for @settingsBackupRestore_scheduleEvery3Days.
  ///
  /// In en, this message translates to:
  /// **'Every 3 days'**
  String get settingsBackupRestore_scheduleEvery3Days;

  /// No description provided for @settingsBackupRestore_scheduleEvery7Days.
  ///
  /// In en, this message translates to:
  /// **'Every 7 days'**
  String get settingsBackupRestore_scheduleEvery7Days;

  /// No description provided for @settingsBackupRestore_scheduleEveryMonth.
  ///
  /// In en, this message translates to:
  /// **'Every month'**
  String get settingsBackupRestore_scheduleEveryMonth;

  /// No description provided for @settingsBackupRestore_passphraseTitle.
  ///
  /// In en, this message translates to:
  /// **'Protect this backup'**
  String get settingsBackupRestore_passphraseTitle;

  /// No description provided for @settingsBackupRestore_passphraseBody.
  ///
  /// In en, this message translates to:
  /// **'The backup is encrypted with this passphrase. It is not stored anywhere, so without it the file can never be restored.'**
  String get settingsBackupRestore_passphraseBody;

  /// No description provided for @settingsBackupRestore_passphraseLabel.
  ///
  /// In en, this message translates to:
  /// **'Passphrase'**
  String get settingsBackupRestore_passphraseLabel;

  /// No description provided for @settingsBackupRestore_passphraseConfirmLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm passphrase'**
  String get settingsBackupRestore_passphraseConfirmLabel;

  /// No description provided for @settingsBackupRestore_passphraseRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a passphrase.'**
  String get settingsBackupRestore_passphraseRequired;

  /// No description provided for @settingsBackupRestore_passphraseMismatch.
  ///
  /// In en, this message translates to:
  /// **'The two passphrases do not match.'**
  String get settingsBackupRestore_passphraseMismatch;

  /// No description provided for @settingsBackupRestore_encryptAndSave.
  ///
  /// In en, this message translates to:
  /// **'Encrypt and save'**
  String get settingsBackupRestore_encryptAndSave;

  /// No description provided for @settingsBackupRestore_recoveryPassphraseTitle.
  ///
  /// In en, this message translates to:
  /// **'Open this backup'**
  String get settingsBackupRestore_recoveryPassphraseTitle;

  /// No description provided for @settingsBackupRestore_recoveryPassphraseBody.
  ///
  /// In en, this message translates to:
  /// **'Enter the passphrase this backup was created with.'**
  String get settingsBackupRestore_recoveryPassphraseBody;

  /// No description provided for @settingsBackupRestore_recoveryPassphraseHint.
  ///
  /// In en, this message translates to:
  /// **'A backup made before encryption was added opens without a passphrase.'**
  String get settingsBackupRestore_recoveryPassphraseHint;

  /// No description provided for @settingsBackupRestore_openBackup.
  ///
  /// In en, this message translates to:
  /// **'Open backup'**
  String get settingsBackupRestore_openBackup;

  /// No description provided for @settingsBackupRestore_backupProgress.
  ///
  /// In en, this message translates to:
  /// **'Creating your backup…'**
  String get settingsBackupRestore_backupProgress;

  /// No description provided for @settingsBackupRestore_restoreProgress.
  ///
  /// In en, this message translates to:
  /// **'Restoring your data…'**
  String get settingsBackupRestore_restoreProgress;

  /// No description provided for @settingsBackupRestore_restoreBlockedBody.
  ///
  /// In en, this message translates to:
  /// **'Subscribed users are restricted from restoring offline data to prevent data contamination and potential issues. You need to delete current local & cloud data before restoring a local save.'**
  String get settingsBackupRestore_restoreBlockedBody;

  /// BACKUP STATUS
  ///
  /// In en, this message translates to:
  /// **'Backup saved to {path}'**
  String settingsBackupRestore_backupSaved(String path);

  /// No description provided for @settingsBackupRestore_backupFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create the backup.'**
  String get settingsBackupRestore_backupFailed;

  /// No description provided for @settingsBackupRestore_restoreDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Replace all current data?'**
  String get settingsBackupRestore_restoreDetailsTitle;

  /// No description provided for @settingsBackupRestore_restoreDetailsBackedUp.
  ///
  /// In en, this message translates to:
  /// **'Backed up'**
  String get settingsBackupRestore_restoreDetailsBackedUp;

  /// No description provided for @settingsBackupRestore_restoreDetailsAppVersion.
  ///
  /// In en, this message translates to:
  /// **'App version'**
  String get settingsBackupRestore_restoreDetailsAppVersion;

  /// No description provided for @settingsBackupRestore_restoreDetailsRecords.
  ///
  /// In en, this message translates to:
  /// **'Records'**
  String get settingsBackupRestore_restoreDetailsRecords;

  /// No description provided for @settingsBackupRestore_restoreDetailsWarning.
  ///
  /// In en, this message translates to:
  /// **'Everything currently on this device will be replaced. This cannot be undone.'**
  String get settingsBackupRestore_restoreDetailsWarning;

  /// No description provided for @settingsBackupRestore_restoreReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get settingsBackupRestore_restoreReplace;

  /// No description provided for @settingsBackupRestore_restoreCompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore complete'**
  String get settingsBackupRestore_restoreCompleteTitle;

  /// RESTORE
  ///
  /// In en, this message translates to:
  /// **'{count} records restored.'**
  String settingsBackupRestore_restoreCompleteBody(int count);

  /// No description provided for @settingsBackupRestore_restoreCompleteNote.
  ///
  /// In en, this message translates to:
  /// **'The app will now reload your data.'**
  String get settingsBackupRestore_restoreCompleteNote;

  /// No description provided for @settingsBackupRestore_errorInvalidFile.
  ///
  /// In en, this message translates to:
  /// **'That file is not a backup made by this app.'**
  String get settingsBackupRestore_errorInvalidFile;

  /// No description provided for @settingsBackupRestore_errorUnsupportedVersion.
  ///
  /// In en, this message translates to:
  /// **'This backup was made by a newer version of the app.'**
  String get settingsBackupRestore_errorUnsupportedVersion;

  /// No description provided for @settingsBackupRestore_errorWrongSecret.
  ///
  /// In en, this message translates to:
  /// **'Wrong passphrase, or the backup file has been changed.'**
  String get settingsBackupRestore_errorWrongSecret;

  /// No description provided for @settingsBackupRestore_errorDamaged.
  ///
  /// In en, this message translates to:
  /// **'The backup file is damaged and cannot be restored.'**
  String get settingsBackupRestore_errorDamaged;

  /// No description provided for @settingsBackupRestore_errorConflict.
  ///
  /// In en, this message translates to:
  /// **'The app gained new data while restoring, so nothing was changed.'**
  String get settingsBackupRestore_errorConflict;

  /// No description provided for @settingsBackupRestore_errorImportFailed.
  ///
  /// In en, this message translates to:
  /// **'The restore failed. Your existing data was left unchanged.'**
  String get settingsBackupRestore_errorImportFailed;

  /// No description provided for @settingsBackupRestore_errorAnotherAccount.
  ///
  /// In en, this message translates to:
  /// **'This backup belongs to another account. Sign in as that account to restore it.'**
  String get settingsBackupRestore_errorAnotherAccount;

  /// No description provided for @settingsBackupRestore_errorAnotherFirm.
  ///
  /// In en, this message translates to:
  /// **'This backup was made inside another chamber. Only a backup of this chamber can be restored here.'**
  String get settingsBackupRestore_errorAnotherFirm;

  /// No description provided for @settingsBackupRestore_memberNotice.
  ///
  /// In en, this message translates to:
  /// **'Only the chamber\'s owner can back up or restore. A member keeps no copy of the chamber\'s records outside the app.'**
  String get settingsBackupRestore_memberNotice;

  /// No description provided for @settingsBackupRestore_chamberBarredTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore Is Not Available In A Chamber'**
  String get settingsBackupRestore_chamberBarredTitle;

  /// No description provided for @settingsBackupRestore_chamberBarredBody.
  ///
  /// In en, this message translates to:
  /// **'A backup is a copy of the ledger at one moment, and restoring it here could undo changes other members have made since. Restore is only available on a device that holds nothing yet, such as a fresh install.'**
  String get settingsBackupRestore_chamberBarredBody;

  /// No description provided for @settingsBackupRestore_errorOpenFile.
  ///
  /// In en, this message translates to:
  /// **'Could not open that file.'**
  String get settingsBackupRestore_errorOpenFile;

  /// No description provided for @settingsBackupRestore_backupExcel.
  ///
  /// In en, this message translates to:
  /// **'Backup as Excel File'**
  String get settingsBackupRestore_backupExcel;

  /// No description provided for @settingsBackupRestore_excelNote.
  ///
  /// In en, this message translates to:
  /// **'The Excel file is a spreadsheet and is not encrypted. Anyone who opens it can read your case data.'**
  String get settingsBackupRestore_excelNote;

  /// No description provided for @settingsBackupRestore_sectionExcelFormat.
  ///
  /// In en, this message translates to:
  /// **'Excel Backup Format'**
  String get settingsBackupRestore_sectionExcelFormat;

  /// No description provided for @settingsBackupRestore_sectionExcelFormatSubtitle.
  ///
  /// In en, this message translates to:
  /// **'See The Format And Download A Sample'**
  String get settingsBackupRestore_sectionExcelFormatSubtitle;

  /// No description provided for @settingsBackupRestore_excelTemplateNote.
  ///
  /// In en, this message translates to:
  /// **'The sample workbook also carries Courts, Case Types, Steps, On Behalfs and Case Categories sheets, plus a Guide sheet. Those extra sheets are there only to show you what to fill in — the app leaves them alone when restoring.'**
  String get settingsBackupRestore_excelTemplateNote;

  /// No description provided for @settingsBackupRestore_excelIntro.
  ///
  /// In en, this message translates to:
  /// **'The Excel file holds four sheets — Cases, Case History, Notes and Case References — plus an Info sheet. Keep the sheet names and the first row of every sheet exactly as they are: the app matches them when restoring.'**
  String get settingsBackupRestore_excelIntro;

  /// No description provided for @settingsBackupRestore_excelPartialNote.
  ///
  /// In en, this message translates to:
  /// **'It is not a complete backup. Courts, steps and your settings are not in it, so restore it into a diary that already has them.'**
  String get settingsBackupRestore_excelPartialNote;

  /// No description provided for @settingsBackupRestore_excelIdNote.
  ///
  /// In en, this message translates to:
  /// **'Leave a row\'s id blank and the app gives it a new one. Every other required cell must be filled.'**
  String get settingsBackupRestore_excelIdNote;

  /// No description provided for @settingsBackupRestore_excelTemplate.
  ///
  /// In en, this message translates to:
  /// **'Download Template File'**
  String get settingsBackupRestore_excelTemplate;

  /// No description provided for @settingsBackupRestore_excelProgress.
  ///
  /// In en, this message translates to:
  /// **'Creating your Excel file…'**
  String get settingsBackupRestore_excelProgress;

  /// EXCEL BACKUP
  ///
  /// In en, this message translates to:
  /// **'Excel file saved to {path}'**
  String settingsBackupRestore_excelSaved(String path);

  /// EXCEL TEMPLATE
  ///
  /// In en, this message translates to:
  /// **'Template saved to {path}'**
  String settingsBackupRestore_excelTemplateSaved(String path);

  /// No description provided for @settingsBackupRestore_excelNotSpreadsheet.
  ///
  /// In en, this message translates to:
  /// **'That file is not a spreadsheet.'**
  String get settingsBackupRestore_excelNotSpreadsheet;

  /// No description provided for @settingsBackupRestore_excelNotBackup.
  ///
  /// In en, this message translates to:
  /// **'That workbook is not a Legal Case Diary Excel backup.'**
  String get settingsBackupRestore_excelNotBackup;

  /// No description provided for @settingsBackupRestore_excelNewerVersion.
  ///
  /// In en, this message translates to:
  /// **'This workbook was made by a newer version of the app.'**
  String get settingsBackupRestore_excelNewerVersion;

  /// EXCEL FORMAT REFUSALS
  ///
  /// In en, this message translates to:
  /// **'The workbook has a sheet this format does not define: {sheet}'**
  String settingsBackupRestore_excelUnknownSheet(String sheet);

  /// EXCEL FORMAT REFUSALS
  ///
  /// In en, this message translates to:
  /// **'The workbook has no {sheet} sheet.'**
  String settingsBackupRestore_excelMissingSheet(String sheet);

  /// EXCEL FORMAT REFUSALS
  ///
  /// In en, this message translates to:
  /// **'The {sheet} sheet has a column this format does not define: {column}'**
  String settingsBackupRestore_excelUnknownColumn(String sheet, String column);

  /// EXCEL FORMAT REFUSALS
  ///
  /// In en, this message translates to:
  /// **'The {sheet} sheet is missing the {column} column.'**
  String settingsBackupRestore_excelMissingColumn(String sheet, String column);

  /// EXCEL FORMAT REFUSALS
  ///
  /// In en, this message translates to:
  /// **'The {sheet} sheet has no rows.'**
  String settingsBackupRestore_excelEmptySheet(String sheet);

  /// EXCEL FORMAT REFUSALS
  ///
  /// In en, this message translates to:
  /// **'{sheet}, row {row}: {column} must be filled.'**
  String settingsBackupRestore_excelMissingValue(
    String sheet,
    int row,
    String column,
  );

  /// No description provided for @settingsBackupRestore_restoreDetailsSheets.
  ///
  /// In en, this message translates to:
  /// **'Sheets'**
  String get settingsBackupRestore_restoreDetailsSheets;

  /// No description provided for @settingsBackupRestore_restoreExcelTitle.
  ///
  /// In en, this message translates to:
  /// **'Replace the data in these sheets?'**
  String get settingsBackupRestore_restoreExcelTitle;

  /// No description provided for @settingsBackupRestore_restoreExcelWarning.
  ///
  /// In en, this message translates to:
  /// **'The sheets in this file replace those records on this device. Everything else is kept.'**
  String get settingsBackupRestore_restoreExcelWarning;

  /// No description provided for @settingsEditCourtSteps_editItemTypes.
  ///
  /// In en, this message translates to:
  /// **'Case Types, Step etc'**
  String get settingsEditCourtSteps_editItemTypes;

  /// No description provided for @settingsEditCourtSteps_editItemTypesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage case types, procedural steps, and on-behalf roles'**
  String get settingsEditCourtSteps_editItemTypesSubtitle;

  /// No description provided for @settingsEditCourtSteps_courtNamesCategories.
  ///
  /// In en, this message translates to:
  /// **'Court Names'**
  String get settingsEditCourtSteps_courtNamesCategories;

  /// No description provided for @settingsEditCourtSteps_courtNamesCategoriesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Supreme Court divisions and district lower courts'**
  String get settingsEditCourtSteps_courtNamesCategoriesSubtitle;

  /// No description provided for @settingsEditCourtSteps_lowerCourtCategories.
  ///
  /// In en, this message translates to:
  /// **'Lower Court Categories'**
  String get settingsEditCourtSteps_lowerCourtCategories;

  /// No description provided for @settingsEditCourtSteps_lowerCourtCategoriesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Divisions, districts and their court categories'**
  String get settingsEditCourtSteps_lowerCourtCategoriesSubtitle;

  /// No description provided for @settingsEditCourtNames_courtCategory.
  ///
  /// In en, this message translates to:
  /// **'Edit Court Names'**
  String get settingsEditCourtNames_courtCategory;

  /// No description provided for @settingsEditCourtNames_lowerCourts.
  ///
  /// In en, this message translates to:
  /// **'Lower Courts'**
  String get settingsEditCourtNames_lowerCourts;

  /// No description provided for @settingsEditCourtNames_lowerCourtsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'District, Session & Specialized Courts'**
  String get settingsEditCourtNames_lowerCourtsSubtitle;

  /// No description provided for @settingsEditCourtNames_quickTip.
  ///
  /// In en, this message translates to:
  /// **'Quick Tip'**
  String get settingsEditCourtNames_quickTip;

  /// No description provided for @settingsEditCourtNames_quickTipBody.
  ///
  /// In en, this message translates to:
  /// **'Need specialized tribunals? Add them under the relevant division and district, then assign a court category.'**
  String get settingsEditCourtNames_quickTipBody;

  /// No description provided for @settingsEditItems_caseTypes.
  ///
  /// In en, this message translates to:
  /// **'Case Types'**
  String get settingsEditItems_caseTypes;

  /// No description provided for @settingsEditItems_steps.
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get settingsEditItems_steps;

  /// No description provided for @settingsEditItems_onBehalf.
  ///
  /// In en, this message translates to:
  /// **'On Behalf'**
  String get settingsEditItems_onBehalf;

  /// No description provided for @settingsCourtNamesSteps_title.
  ///
  /// In en, this message translates to:
  /// **'Case Types, Steps etc'**
  String get settingsCourtNamesSteps_title;

  /// No description provided for @settingsCourtNamesSteps_catAppellateDivision.
  ///
  /// In en, this message translates to:
  /// **'Appellate Division'**
  String get settingsCourtNamesSteps_catAppellateDivision;

  /// No description provided for @settingsCourtNamesSteps_catHighCourtDivision.
  ///
  /// In en, this message translates to:
  /// **'High Court Division'**
  String get settingsCourtNamesSteps_catHighCourtDivision;

  /// No description provided for @settingsCourtNamesSteps_catDistrictSessions.
  ///
  /// In en, this message translates to:
  /// **'Sessions Courts (Criminal)'**
  String get settingsCourtNamesSteps_catDistrictSessions;

  /// No description provided for @settingsCourtNamesSteps_catDistrictCivil.
  ///
  /// In en, this message translates to:
  /// **'District Courts (Civil)'**
  String get settingsCourtNamesSteps_catDistrictCivil;

  /// No description provided for @settingsCourtNamesSteps_catCjm.
  ///
  /// In en, this message translates to:
  /// **'Chief Judicial Magistrate'**
  String get settingsCourtNamesSteps_catCjm;

  /// No description provided for @settingsCourtNamesSteps_catCmm.
  ///
  /// In en, this message translates to:
  /// **'Chief Metropolitan Magistrate'**
  String get settingsCourtNamesSteps_catCmm;

  /// No description provided for @settingsCourtNamesSteps_catExecutive.
  ///
  /// In en, this message translates to:
  /// **'Executive Magistrate'**
  String get settingsCourtNamesSteps_catExecutive;

  /// No description provided for @settingsCourtNamesSteps_catMetropolitanSessions.
  ///
  /// In en, this message translates to:
  /// **'Metropolitan Sessions (Criminal)'**
  String get settingsCourtNamesSteps_catMetropolitanSessions;

  /// No description provided for @settingsItemList_addTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Item'**
  String get settingsItemList_addTitle;

  /// No description provided for @settingsItemList_editTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Item'**
  String get settingsItemList_editTitle;

  /// No description provided for @settingsItemList_nameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get settingsItemList_nameLabel;

  /// No description provided for @settingsItemList_empty.
  ///
  /// In en, this message translates to:
  /// **'No items yet. Add one below.'**
  String get settingsItemList_empty;

  /// No description provided for @settingsItemList_deleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Item'**
  String get settingsItemList_deleteTitle;

  /// No description provided for @settingsItemList_deleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete this item? This cannot be undone.'**
  String get settingsItemList_deleteMessage;

  /// No description provided for @settingsItemList_catAppellate.
  ///
  /// In en, this message translates to:
  /// **'Appellate'**
  String get settingsItemList_catAppellate;

  /// No description provided for @settingsItemList_catHighCourt.
  ///
  /// In en, this message translates to:
  /// **'High Court'**
  String get settingsItemList_catHighCourt;

  /// No description provided for @settingsItemList_catSessions.
  ///
  /// In en, this message translates to:
  /// **'Sessions (Crim)'**
  String get settingsItemList_catSessions;

  /// No description provided for @settingsItemList_catDistrictCivil.
  ///
  /// In en, this message translates to:
  /// **'District (Civil)'**
  String get settingsItemList_catDistrictCivil;

  /// No description provided for @settingsItemList_catMetropolitanSessions.
  ///
  /// In en, this message translates to:
  /// **'Metro Sessions (Crim)'**
  String get settingsItemList_catMetropolitanSessions;

  /// No description provided for @settingsItemList_catCjm.
  ///
  /// In en, this message translates to:
  /// **'CJM'**
  String get settingsItemList_catCjm;

  /// No description provided for @settingsItemList_catCmm.
  ///
  /// In en, this message translates to:
  /// **'CMM'**
  String get settingsItemList_catCmm;

  /// No description provided for @settingsItemList_catExecutive.
  ///
  /// In en, this message translates to:
  /// **'Executive'**
  String get settingsItemList_catExecutive;

  /// No description provided for @settingsItemList_catTribunals.
  ///
  /// In en, this message translates to:
  /// **'Tribunals'**
  String get settingsItemList_catTribunals;

  /// No description provided for @settingsCourtList_addTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Court'**
  String get settingsCourtList_addTitle;

  /// No description provided for @settingsCourtList_editTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Court'**
  String get settingsCourtList_editTitle;

  /// No description provided for @settingsCourtList_nameLabel.
  ///
  /// In en, this message translates to:
  /// **'Court name'**
  String get settingsCourtList_nameLabel;

  /// No description provided for @settingsCourtList_titleHigher.
  ///
  /// In en, this message translates to:
  /// **'Court Names'**
  String get settingsCourtList_titleHigher;

  /// No description provided for @settingsCourtList_empty.
  ///
  /// In en, this message translates to:
  /// **'No courts yet. Add one below.'**
  String get settingsCourtList_empty;

  /// No description provided for @settingsCourtList_deleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Court'**
  String get settingsCourtList_deleteTitle;

  /// COURT LIST (add/edit/delete court)
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"? This cannot be undone.'**
  String settingsCourtList_deleteMessage(String name);

  /// COURT LIST (add/edit/delete court)
  ///
  /// In en, this message translates to:
  /// **'{district} Court Names'**
  String settingsCourtList_titleLower(String district);

  /// No description provided for @settingsCourtFlow_divisions.
  ///
  /// In en, this message translates to:
  /// **'Divisions'**
  String get settingsCourtFlow_divisions;

  /// No description provided for @settingsCourtFlow_districts.
  ///
  /// In en, this message translates to:
  /// **'Districts'**
  String get settingsCourtFlow_districts;

  /// No description provided for @settingsLowerCourtCategories_addTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add Court Category'**
  String get settingsLowerCourtCategories_addTooltip;

  /// No description provided for @settingsLowerCourtCategories_addTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Court Category'**
  String get settingsLowerCourtCategories_addTitle;

  /// No description provided for @settingsLowerCourtCategories_editTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Court Category'**
  String get settingsLowerCourtCategories_editTitle;

  /// No description provided for @settingsLowerCourtCategories_nameLabel.
  ///
  /// In en, this message translates to:
  /// **'Category name'**
  String get settingsLowerCourtCategories_nameLabel;

  /// No description provided for @settingsLowerCourtCategories_empty.
  ///
  /// In en, this message translates to:
  /// **'No court categories in this district yet.'**
  String get settingsLowerCourtCategories_empty;

  /// DIVISIONS / DISTRICTS / LOWER COURT CATEGORIES
  ///
  /// In en, this message translates to:
  /// **'{division} Division'**
  String settingsCourtFlow_divisionTitle(String division);

  /// DIVISIONS / DISTRICTS / LOWER COURT CATEGORIES
  ///
  /// In en, this message translates to:
  /// **'{district} Court Categories'**
  String settingsLowerCourtCategories_title(String district);

  /// No description provided for @settingsNotifications_title.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotifications_title;

  /// No description provided for @settingsNotifications_statusLabel.
  ///
  /// In en, this message translates to:
  /// **'Default Notification Status'**
  String get settingsNotifications_statusLabel;

  /// No description provided for @settingsNotifications_on.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get settingsNotifications_on;

  /// No description provided for @settingsNotifications_off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get settingsNotifications_off;

  /// No description provided for @settingsNotifications_dayOffsetLabel.
  ///
  /// In en, this message translates to:
  /// **'Notification Day Offset'**
  String get settingsNotifications_dayOffsetLabel;

  /// No description provided for @settingsNotifications_selectDayOffsetTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Day Offset'**
  String get settingsNotifications_selectDayOffsetTitle;

  /// No description provided for @settingsNotifications_keepOneOffset.
  ///
  /// In en, this message translates to:
  /// **'Select at least one day offset.'**
  String get settingsNotifications_keepOneOffset;

  /// No description provided for @settingsNotifications_offsetSameDay.
  ///
  /// In en, this message translates to:
  /// **'The Same Day'**
  String get settingsNotifications_offsetSameDay;

  /// No description provided for @settingsNotifications_offsetDayBefore.
  ///
  /// In en, this message translates to:
  /// **'The Day Before'**
  String get settingsNotifications_offsetDayBefore;

  /// Day-offset option for two or more days before the hearing, in the language's own digits.
  ///
  /// In en, this message translates to:
  /// **'Before {days} Days'**
  String settingsNotifications_offsetBeforeDays(int days);

  /// No description provided for @settingsNotifications_timeLabel.
  ///
  /// In en, this message translates to:
  /// **'Notification Time'**
  String get settingsNotifications_timeLabel;

  /// No description provided for @settingsNotifications_paymentAlertsLabel.
  ///
  /// In en, this message translates to:
  /// **'Admin Panel Notification'**
  String get settingsNotifications_paymentAlertsLabel;

  /// No description provided for @settingsNotifications_reminderBanner.
  ///
  /// In en, this message translates to:
  /// **'Notifications may not work reliably on your device. Tap to complete setup.'**
  String get settingsNotifications_reminderBanner;

  /// No description provided for @settingsNotifications_setupGuide.
  ///
  /// In en, this message translates to:
  /// **'Battery & Auto-Start Setup Guide'**
  String get settingsNotifications_setupGuide;

  /// No description provided for @settingsNotifications_setupGuideSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Required on Xiaomi, Oppo, Vivo and Realme Phones'**
  String get settingsNotifications_setupGuideSubtitle;

  /// No description provided for @settingsNotifications_sendTest.
  ///
  /// In en, this message translates to:
  /// **'Send Test Notification'**
  String get settingsNotifications_sendTest;

  /// No description provided for @settingsNotifications_sendTestSubtitle.
  ///
  /// In en, this message translates to:
  /// **'See how a hearing alert looks on this phone'**
  String get settingsNotifications_sendTestSubtitle;

  /// No description provided for @settingsNotifications_testSent.
  ///
  /// In en, this message translates to:
  /// **'Test Notification Sent'**
  String get settingsNotifications_testSent;

  /// No description provided for @settingsNotifications_testFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not show a notification. Check the app\'s notification permission.'**
  String get settingsNotifications_testFailed;

  /// No description provided for @notificationJob_channelName.
  ///
  /// In en, this message translates to:
  /// **'Hearing Alerts'**
  String get notificationJob_channelName;

  /// No description provided for @notificationJob_channelDescription.
  ///
  /// In en, this message translates to:
  /// **'Daily reminders for your upcoming hearings'**
  String get notificationJob_channelDescription;

  /// No description provided for @notificationJob_titleSameDay.
  ///
  /// In en, this message translates to:
  /// **'Hearing Today'**
  String get notificationJob_titleSameDay;

  /// No description provided for @notificationJob_titleDayBefore.
  ///
  /// In en, this message translates to:
  /// **'Hearing Tomorrow'**
  String get notificationJob_titleDayBefore;

  /// Title of an alert posted several days before the hearing.
  ///
  /// In en, this message translates to:
  /// **'Hearing in {days} Days'**
  String notificationJob_titleBeforeDays(String days);

  /// Party line of a hearing alert.
  ///
  /// In en, this message translates to:
  /// **'{petitioner} vs {respondent}'**
  String notificationJob_parties(String petitioner, String respondent);

  /// No description provided for @notificationJob_testTitle.
  ///
  /// In en, this message translates to:
  /// **'Test Notification'**
  String get notificationJob_testTitle;

  /// No description provided for @notificationJob_testBody.
  ///
  /// In en, this message translates to:
  /// **'Hearing alerts are working. This is how a hearing reminder will look.'**
  String get notificationJob_testBody;

  /// No description provided for @adminPush_channelName.
  ///
  /// In en, this message translates to:
  /// **'Payment Requests'**
  String get adminPush_channelName;

  /// No description provided for @adminPush_channelDescription.
  ///
  /// In en, this message translates to:
  /// **'Alerts when a payment request is waiting for approval'**
  String get adminPush_channelDescription;

  /// No description provided for @adminPush_title.
  ///
  /// In en, this message translates to:
  /// **'Payment Requests Pending'**
  String get adminPush_title;

  /// No description provided for @adminPush_bodyOne.
  ///
  /// In en, this message translates to:
  /// **'One payment request is waiting for your approval.'**
  String get adminPush_bodyOne;

  /// Body of the admin payment alert. The count arrives already written in the active language's own digits, so it stays a String.
  ///
  /// In en, this message translates to:
  /// **'{count} payment requests are waiting for your approval.'**
  String adminPush_bodyMany(String count);

  /// No description provided for @settingsBatteryGuide_intro.
  ///
  /// In en, this message translates to:
  /// **'Xiaomi, Oppo, Vivo, Realme and similar phones stop background alarms to save battery, so hearing reminders can fail silently. These two or three steps keep them working.'**
  String get settingsBatteryGuide_intro;

  /// No description provided for @settingsBatteryGuide_autoStartTitle.
  ///
  /// In en, this message translates to:
  /// **'Allow Auto-Start'**
  String get settingsBatteryGuide_autoStartTitle;

  /// No description provided for @settingsBatteryGuide_autoStartBody.
  ///
  /// In en, this message translates to:
  /// **'In your phone\'s settings, open Auto-start (or Startup manager) and allow Legal Case Diary to start by itself.'**
  String get settingsBatteryGuide_autoStartBody;

  /// No description provided for @settingsBatteryGuide_autoStartXiaomi.
  ///
  /// In en, this message translates to:
  /// **'Open App info for Legal Case Diary, then Permissions > Autostart, and allow it.'**
  String get settingsBatteryGuide_autoStartXiaomi;

  /// No description provided for @settingsBatteryGuide_autoStartRealme.
  ///
  /// In en, this message translates to:
  /// **'Open App info for Legal Case Diary, then Battery usage > Privacy Permissions > Allow auto launch.'**
  String get settingsBatteryGuide_autoStartRealme;

  /// No description provided for @settingsBatteryGuide_autoStartVivo.
  ///
  /// In en, this message translates to:
  /// **'Open Settings > Apps > Special app access > Autostart and allow Legal Case Diary. (Vivo has no autostart inside App info.)'**
  String get settingsBatteryGuide_autoStartVivo;

  /// No description provided for @settingsBatteryGuide_batteryTitle.
  ///
  /// In en, this message translates to:
  /// **'Set Battery Usage to Unrestricted'**
  String get settingsBatteryGuide_batteryTitle;

  /// No description provided for @settingsBatteryGuide_batteryBody.
  ///
  /// In en, this message translates to:
  /// **'Open Battery then App battery usage (or Battery optimization), choose Legal Case Diary and select Unrestricted / No restrictions.'**
  String get settingsBatteryGuide_batteryBody;

  /// No description provided for @settingsBatteryGuide_batteryXiaomi.
  ///
  /// In en, this message translates to:
  /// **'Open App info for Legal Case Diary, then Battery saver > No restriction.'**
  String get settingsBatteryGuide_batteryXiaomi;

  /// No description provided for @settingsBatteryGuide_batteryRealme.
  ///
  /// In en, this message translates to:
  /// **'Open App info for Legal Case Diary, then Battery usage > Allow background activity.'**
  String get settingsBatteryGuide_batteryRealme;

  /// No description provided for @settingsBatteryGuide_batteryVivo.
  ///
  /// In en, this message translates to:
  /// **'Open App info for Legal Case Diary, then Battery usage > Background power control > Allow background power usage.'**
  String get settingsBatteryGuide_batteryVivo;

  /// No description provided for @settingsBatteryGuide_exactTitle.
  ///
  /// In en, this message translates to:
  /// **'Allow Exact Alarms'**
  String get settingsBatteryGuide_exactTitle;

  /// No description provided for @settingsBatteryGuide_exactBody.
  ///
  /// In en, this message translates to:
  /// **'On Android 12 and newer, allow Alarms & reminders for Legal Case Diary; otherwise the daily reminder can arrive late.'**
  String get settingsBatteryGuide_exactBody;

  /// No description provided for @settingsBatteryGuide_takeMeThere.
  ///
  /// In en, this message translates to:
  /// **'Take Me There'**
  String get settingsBatteryGuide_takeMeThere;

  /// No description provided for @settingsBatteryGuide_exactAllowed.
  ///
  /// In en, this message translates to:
  /// **'Exact Alarms Are Already Allowed'**
  String get settingsBatteryGuide_exactAllowed;

  /// No description provided for @settingsBatteryGuide_batteryAllowed.
  ///
  /// In en, this message translates to:
  /// **'Battery Usage Is Already Unrestricted'**
  String get settingsBatteryGuide_batteryAllowed;

  /// No description provided for @settingsBatteryGuide_autoStartDone.
  ///
  /// In en, this message translates to:
  /// **'Auto-Start Marked As Done By You'**
  String get settingsBatteryGuide_autoStartDone;

  /// No description provided for @settingsBatteryGuide_markDone.
  ///
  /// In en, this message translates to:
  /// **'Mark As Done'**
  String get settingsBatteryGuide_markDone;

  /// No description provided for @settingsBatteryGuide_markNotDone.
  ///
  /// In en, this message translates to:
  /// **'Mark As Not Done'**
  String get settingsBatteryGuide_markNotDone;

  /// No description provided for @settingsBatteryGuide_openFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open that settings page. Please set it manually.'**
  String get settingsBatteryGuide_openFailed;

  /// No description provided for @settingsBatteryGuide_done.
  ///
  /// In en, this message translates to:
  /// **'Done, I\'ve Completed the Steps'**
  String get settingsBatteryGuide_done;

  /// No description provided for @settingsBatteryGuide_skip.
  ///
  /// In en, this message translates to:
  /// **'Skip for Now'**
  String get settingsBatteryGuide_skip;

  /// No description provided for @settingsBatteryGuide_skipNote.
  ///
  /// In en, this message translates to:
  /// **'You can finish this later from Settings → Notifications.'**
  String get settingsBatteryGuide_skipNote;

  /// No description provided for @settingsViewSettings_title.
  ///
  /// In en, this message translates to:
  /// **'View Settings'**
  String get settingsViewSettings_title;

  /// No description provided for @settingsViewSettings_sectionDisplay.
  ///
  /// In en, this message translates to:
  /// **'Display'**
  String get settingsViewSettings_sectionDisplay;

  /// No description provided for @settingsViewSettings_sectionFontSize.
  ///
  /// In en, this message translates to:
  /// **'Font Size'**
  String get settingsViewSettings_sectionFontSize;

  /// No description provided for @settingsViewSettings_sectionNavigation.
  ///
  /// In en, this message translates to:
  /// **'Navigation'**
  String get settingsViewSettings_sectionNavigation;

  /// No description provided for @settingsViewSettings_upcomingPeriod.
  ///
  /// In en, this message translates to:
  /// **'Upcoming Cases Period'**
  String get settingsViewSettings_upcomingPeriod;

  /// Number of days the Upcoming Cases screen looks ahead.
  ///
  /// In en, this message translates to:
  /// **'{days} Days'**
  String settingsViewSettings_days(int days);

  /// No description provided for @settingsViewSettings_caseListMode.
  ///
  /// In en, this message translates to:
  /// **'Case List Display'**
  String get settingsViewSettings_caseListMode;

  /// No description provided for @settingsViewSettings_caseListCompact.
  ///
  /// In en, this message translates to:
  /// **'Compact'**
  String get settingsViewSettings_caseListCompact;

  /// No description provided for @settingsViewSettings_caseListExpanded.
  ///
  /// In en, this message translates to:
  /// **'Expanded'**
  String get settingsViewSettings_caseListExpanded;

  /// No description provided for @settingsViewSettings_fontSizeDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get settingsViewSettings_fontSizeDefault;

  /// Current font size step when it is above Default. The step itself arrives already in the language's digits.
  ///
  /// In en, this message translates to:
  /// **'+{step}'**
  String settingsViewSettings_fontSizeMore(String step);

  /// Current font size step when it is below Default. The step itself arrives already in the language's digits.
  ///
  /// In en, this message translates to:
  /// **'-{step}'**
  String settingsViewSettings_fontSizeLess(String step);

  /// No description provided for @settingsViewSettings_fontSizeIncrease.
  ///
  /// In en, this message translates to:
  /// **'Increase Font Size'**
  String get settingsViewSettings_fontSizeIncrease;

  /// No description provided for @settingsViewSettings_fontSizeDecrease.
  ///
  /// In en, this message translates to:
  /// **'Decrease Font Size'**
  String get settingsViewSettings_fontSizeDecrease;

  /// No description provided for @settingsViewSettings_fontSizeReset.
  ///
  /// In en, this message translates to:
  /// **'Reset to Default'**
  String get settingsViewSettings_fontSizeReset;

  /// No description provided for @settingsViewSettings_bottomTabs.
  ///
  /// In en, this message translates to:
  /// **'Bottom Navigation'**
  String get settingsViewSettings_bottomTabs;

  /// Collapsed value of the Bottom Navigation dropdown: how many screens are in the bottom bar.
  ///
  /// In en, this message translates to:
  /// **'{count} Screens Selected'**
  String settingsViewSettings_bottomTabsCount(int count);

  /// No description provided for @settingsViewSettings_keepOneTab.
  ///
  /// In en, this message translates to:
  /// **'Keep at least one screen in the bottom bar.'**
  String get settingsViewSettings_keepOneTab;

  /// No description provided for @settingsViewSettings_sideNav.
  ///
  /// In en, this message translates to:
  /// **'Side Navigation Options'**
  String get settingsViewSettings_sideNav;

  /// Collapsed value of the Side Navigation Options dropdown: how many drawer sections are visible.
  ///
  /// In en, this message translates to:
  /// **'{shown} of {total} Sections Shown'**
  String settingsViewSettings_sideNavCount(int shown, int total);

  /// No description provided for @settingsViewSettings_landingPage.
  ///
  /// In en, this message translates to:
  /// **'Default Landing Page'**
  String get settingsViewSettings_landingPage;

  /// No description provided for @settingsGuidelines_title.
  ///
  /// In en, this message translates to:
  /// **'Guidelines & FAQs'**
  String get settingsGuidelines_title;

  /// No description provided for @settingsGuidelines_intro.
  ///
  /// In en, this message translates to:
  /// **'How the app works, and answers to the questions we are asked most often. Tap a card to expand it.'**
  String get settingsGuidelines_intro;

  /// No description provided for @settingsGuidelines_sectionGuidelines.
  ///
  /// In en, this message translates to:
  /// **'Guidelines'**
  String get settingsGuidelines_sectionGuidelines;

  /// No description provided for @settingsGuidelines_accountTitle.
  ///
  /// In en, this message translates to:
  /// **'Your Account'**
  String get settingsGuidelines_accountTitle;

  /// No description provided for @settingsGuidelines_accountBody1.
  ///
  /// In en, this message translates to:
  /// **'You create your account the first time you open the app — it takes a moment, and it is required for everyone, the free plan included. Everything you record afterwards belongs to that account.'**
  String get settingsGuidelines_accountBody1;

  /// No description provided for @settingsGuidelines_accountBody2.
  ///
  /// In en, this message translates to:
  /// **'Every account starts on the free plan, which is local to this device, and stays there until you upgrade. Because your diary was yours from the first case, upgrading needs nothing re-entered or transferred — cloud backup simply switches on.'**
  String get settingsGuidelines_accountBody2;

  /// No description provided for @settingsGuidelines_dailyCauseListTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily Cause List'**
  String get settingsGuidelines_dailyCauseListTitle;

  /// No description provided for @settingsGuidelines_dailyCauseListBody1.
  ///
  /// In en, this message translates to:
  /// **'The Daily Cause List shows the hearings you have recorded for a single date, grouped by court in your court hierarchy, with a total for the day. Use the calendar to choose another date; today is selected by default.'**
  String get settingsGuidelines_dailyCauseListBody1;

  /// No description provided for @settingsGuidelines_dailyCauseListBody2.
  ///
  /// In en, this message translates to:
  /// **'The list is built from your own case records, so it is only as accurate as they are. Keep each case\'s next date and latest step current, and record a hearing from the list itself as soon as you leave the courtroom. Cases whose hearing date has passed without an update appear under Overdue Dates until you record the outcome.'**
  String get settingsGuidelines_dailyCauseListBody2;

  /// No description provided for @settingsGuidelines_allCasesTitle.
  ///
  /// In en, this message translates to:
  /// **'All Cases'**
  String get settingsGuidelines_allCasesTitle;

  /// No description provided for @settingsGuidelines_allCasesBody1.
  ///
  /// In en, this message translates to:
  /// **'Every case you have, with the Active and Disposed counts above the list — tap a count to open that list. Search by party, counsel, case number or phone, narrow the list with Filter by Court and Newest/Oldest First, and switch between card and table view.'**
  String get settingsGuidelines_allCasesBody1;

  /// No description provided for @settingsGuidelines_activeCasesTitle.
  ///
  /// In en, this message translates to:
  /// **'Active Cases'**
  String get settingsGuidelines_activeCasesTitle;

  /// No description provided for @settingsGuidelines_activeCasesBody1.
  ///
  /// In en, this message translates to:
  /// **'Only the cases still running, with nothing disposed mixed in. Open one here to update it or to record the outcome of a hearing.'**
  String get settingsGuidelines_activeCasesBody1;

  /// No description provided for @settingsGuidelines_overdueDatesTitle.
  ///
  /// In en, this message translates to:
  /// **'Overdue Dates'**
  String get settingsGuidelines_overdueDatesTitle;

  /// No description provided for @settingsGuidelines_overdueDatesBody1.
  ///
  /// In en, this message translates to:
  /// **'Cases whose hearing date has passed without a recorded outcome, grouped by court and showing when each was last updated. Recording a new step or result removes the case from the list.'**
  String get settingsGuidelines_overdueDatesBody1;

  /// No description provided for @settingsGuidelines_upcomingCasesTitle.
  ///
  /// In en, this message translates to:
  /// **'Upcoming Cases'**
  String get settingsGuidelines_upcomingCasesTitle;

  /// No description provided for @settingsGuidelines_upcomingCasesBody1.
  ///
  /// In en, this message translates to:
  /// **'Hearings grouped by date, from tomorrow to the end of the period you set in Settings > View Settings > Upcoming Cases Period — 7 days by default. This is the list to check before leaving for court.'**
  String get settingsGuidelines_upcomingCasesBody1;

  /// No description provided for @settingsGuidelines_disposedCasesTitle.
  ///
  /// In en, this message translates to:
  /// **'Disposed Cases'**
  String get settingsGuidelines_disposedCasesTitle;

  /// No description provided for @settingsGuidelines_disposedCasesBody1.
  ///
  /// In en, this message translates to:
  /// **'The cases you have closed, each showing its disposal date, parties, final note and latest history. There is no Add Case button here; the Help button explains how a case is marked as disposed.'**
  String get settingsGuidelines_disposedCasesBody1;

  /// No description provided for @settingsGuidelines_referencesTitle.
  ///
  /// In en, this message translates to:
  /// **'Case References & Notes'**
  String get settingsGuidelines_referencesTitle;

  /// No description provided for @settingsGuidelines_referencesBody1.
  ///
  /// In en, this message translates to:
  /// **'Case Reference is your own library of citations, kept separately from any case. For each entry you can record the reference (for example, 25 DLR (AD) 142), the statute and section, a title and description, and private comments. Pin the entries you cite most often to keep them at the top of the list.'**
  String get settingsGuidelines_referencesBody1;

  /// No description provided for @settingsGuidelines_referencesBody2.
  ///
  /// In en, this message translates to:
  /// **'General notes belong in Notes, which also stands on its own. Both allow you to undo a deletion immediately after making it.'**
  String get settingsGuidelines_referencesBody2;

  /// No description provided for @settingsGuidelines_backupTitle.
  ///
  /// In en, this message translates to:
  /// **'Offline Backup & Restore'**
  String get settingsGuidelines_backupTitle;

  /// No description provided for @settingsGuidelines_backupBody1.
  ///
  /// In en, this message translates to:
  /// **'Your diary lives on this device. In Settings > Backup & Restore, choose Backup to Local Storage to write an encrypted copy to a location you choose — a memory card, a folder on the phone, or anywhere the system file picker can reach. You set a passphrase for the file, and the app never stores or sends it.'**
  String get settingsGuidelines_backupBody1;

  /// No description provided for @settingsGuidelines_backupBody2.
  ///
  /// In en, this message translates to:
  /// **'Restore from backup reads a backup file and replaces the contents of the app with the file\'s contents. This cannot be undone, so make a fresh backup before restoring. If no backup has been made in the current month, the app displays a reminder you can dismiss.'**
  String get settingsGuidelines_backupBody2;

  /// No description provided for @settingsGuidelines_securityTitle.
  ///
  /// In en, this message translates to:
  /// **'Security & Encryption'**
  String get settingsGuidelines_securityTitle;

  /// No description provided for @settingsGuidelines_securityBody1.
  ///
  /// In en, this message translates to:
  /// **'Your case diary is stored on this device in encrypted form. Backup files are encrypted with AES-256-GCM, using a key derived from your passphrase on the device itself with PBKDF2-HMAC-SHA256. Neither the passphrase nor the key is stored or transmitted anywhere.'**
  String get settingsGuidelines_securityBody1;

  /// No description provided for @settingsGuidelines_securityBody2.
  ///
  /// In en, this message translates to:
  /// **'In the offline version nothing leaves your phone except the account details you signed up with — nothing about your cases. Keep your passphrase somewhere safe — where a backup exists but its passphrase is lost, the file cannot be opened by us or by anyone else.'**
  String get settingsGuidelines_securityBody2;

  /// No description provided for @settingsGuidelines_sectionFaqs.
  ///
  /// In en, this message translates to:
  /// **'FAQs'**
  String get settingsGuidelines_sectionFaqs;

  /// No description provided for @settingsGuidelines_faqCatGettingStarted.
  ///
  /// In en, this message translates to:
  /// **'Getting started'**
  String get settingsGuidelines_faqCatGettingStarted;

  /// No description provided for @settingsGuidelines_faqCatGettingStartedQ1.
  ///
  /// In en, this message translates to:
  /// **'Does the app work without an internet connection?'**
  String get settingsGuidelines_faqCatGettingStartedQ1;

  /// No description provided for @settingsGuidelines_faqCatGettingStartedA1.
  ///
  /// In en, this message translates to:
  /// **'Yes — once your account exists. The app is built to work fully offline: adding and editing cases, the Daily Cause List, printing and backups all work with no connection. Your account is created once, when you first open the app, and does not need to be signed in again to use the diary. Online sync is not part of the offline version.'**
  String get settingsGuidelines_faqCatGettingStartedA1;

  /// No description provided for @settingsGuidelines_faqCatGettingStartedQ2.
  ///
  /// In en, this message translates to:
  /// **'How do I add a case?'**
  String get settingsGuidelines_faqCatGettingStartedQ2;

  /// No description provided for @settingsGuidelines_faqCatGettingStartedA2.
  ///
  /// In en, this message translates to:
  /// **'Tap the + button on any cases page. The case is then filed onto the relevant pages automatically, based on the information you enter.'**
  String get settingsGuidelines_faqCatGettingStartedA2;

  /// No description provided for @settingsGuidelines_faqCatGettingStartedQ3.
  ///
  /// In en, this message translates to:
  /// **'Where does a case appear after I add it?'**
  String get settingsGuidelines_faqCatGettingStartedQ3;

  /// No description provided for @settingsGuidelines_faqCatGettingStartedA3.
  ///
  /// In en, this message translates to:
  /// **'A case appears on more than one page, each answering a different question: Active Cases lists everything still running; Upcoming Cases lists hearings within your chosen period; Daily Cause List shows the hearings for one date; All Cases is the full list with sorting and court filtering; Overdue Dates shows cases whose hearing date has passed without an update; and Disposed Cases holds cases you have marked as disposed.'**
  String get settingsGuidelines_faqCatGettingStartedA3;

  /// No description provided for @settingsGuidelines_faqCatGettingStartedQ4.
  ///
  /// In en, this message translates to:
  /// **'What is the difference between updating a case and editing a case?'**
  String get settingsGuidelines_faqCatGettingStartedQ4;

  /// No description provided for @settingsGuidelines_faqCatGettingStartedA4.
  ///
  /// In en, this message translates to:
  /// **'Update records a new step or result and adds it to the case\'s history — use it after each hearing. Edit Case changes the case\'s own details, such as the parties, court or case number — use it to correct recorded information.'**
  String get settingsGuidelines_faqCatGettingStartedA4;

  /// No description provided for @settingsGuidelines_faqCatGettingStartedQ5.
  ///
  /// In en, this message translates to:
  /// **'How do I mark a case as disposed?'**
  String get settingsGuidelines_faqCatGettingStartedQ5;

  /// No description provided for @settingsGuidelines_faqCatGettingStartedA5.
  ///
  /// In en, this message translates to:
  /// **'Open the case in the Update screen or the Edit Case form and select নিষ্পত্তি (Disposed). For Appellate Division and High Court Division cases you can also type \"Disposed\" or \"নিষ্পত্তি\". The case then moves from Active Cases to Disposed Cases.'**
  String get settingsGuidelines_faqCatGettingStartedA5;

  /// No description provided for @settingsGuidelines_faqCatGettingStartedQ6.
  ///
  /// In en, this message translates to:
  /// **'How do I move a case back to Active Cases?'**
  String get settingsGuidelines_faqCatGettingStartedQ6;

  /// No description provided for @settingsGuidelines_faqCatGettingStartedA6.
  ///
  /// In en, this message translates to:
  /// **'Open the case and choose any step or result other than নিষ্পত্তি (Disposed). The case returns to Active Cases.'**
  String get settingsGuidelines_faqCatGettingStartedA6;

  /// No description provided for @settingsGuidelines_faqCatGettingStartedQ7.
  ///
  /// In en, this message translates to:
  /// **'What happens when I delete a case?'**
  String get settingsGuidelines_faqCatGettingStartedQ7;

  /// No description provided for @settingsGuidelines_faqCatGettingStartedA7.
  ///
  /// In en, this message translates to:
  /// **'The case is removed from your diary and frees a slot on the free plan. Deletion cannot be undone, so delete only cases you no longer need a record of. Notes and case references, by contrast, can be undone immediately after deleting.'**
  String get settingsGuidelines_faqCatGettingStartedA7;

  /// No description provided for @settingsGuidelines_faqCatGettingStartedQ8.
  ///
  /// In en, this message translates to:
  /// **'What is the Overdue Dates page?'**
  String get settingsGuidelines_faqCatGettingStartedQ8;

  /// No description provided for @settingsGuidelines_faqCatGettingStartedA8.
  ///
  /// In en, this message translates to:
  /// **'It lists cases whose hearing date has passed without a recorded outcome, with the date they were last updated. It is the fastest way to find matters you have not yet caught up on. Recording a new step or result removes the case from the list.'**
  String get settingsGuidelines_faqCatGettingStartedA8;

  /// No description provided for @settingsGuidelines_faqCatGettingStartedQ9.
  ///
  /// In en, this message translates to:
  /// **'Do I need an account?'**
  String get settingsGuidelines_faqCatGettingStartedQ9;

  /// No description provided for @settingsGuidelines_faqCatGettingStartedA9.
  ///
  /// In en, this message translates to:
  /// **'Yes. An account is required for everyone, the free plan included, and you create it the first time you open the app. Your diary belongs to that account, so when you upgrade to premium your existing cases are already yours — cloud backup switches on with nothing re-entered, exported or transferred.'**
  String get settingsGuidelines_faqCatGettingStartedA9;

  /// No description provided for @settingsGuidelines_faqCatFindingCases.
  ///
  /// In en, this message translates to:
  /// **'Finding and viewing cases'**
  String get settingsGuidelines_faqCatFindingCases;

  /// No description provided for @settingsGuidelines_faqCatFindingCasesQ1.
  ///
  /// In en, this message translates to:
  /// **'I added a case but can\'t find it with search.'**
  String get settingsGuidelines_faqCatFindingCasesQ1;

  /// No description provided for @settingsGuidelines_faqCatFindingCasesA1.
  ///
  /// In en, this message translates to:
  /// **'Search matches the script you entered. A case recorded in English is found with an English query, and a case recorded in Bengali with a Bengali query. A Bengali case number will not match an English search, and vice versa.'**
  String get settingsGuidelines_faqCatFindingCasesA1;

  /// No description provided for @settingsGuidelines_faqCatFindingCasesQ2.
  ///
  /// In en, this message translates to:
  /// **'How far ahead does the Upcoming Cases list show hearings?'**
  String get settingsGuidelines_faqCatFindingCasesQ2;

  /// No description provided for @settingsGuidelines_faqCatFindingCasesA2.
  ///
  /// In en, this message translates to:
  /// **'By default, the next 7 days. To change this, go to Settings > View Settings > Upcoming Cases Period.'**
  String get settingsGuidelines_faqCatFindingCasesA2;

  /// No description provided for @settingsGuidelines_faqCatFindingCasesQ3.
  ///
  /// In en, this message translates to:
  /// **'Can I change how cases are displayed?'**
  String get settingsGuidelines_faqCatFindingCasesQ3;

  /// No description provided for @settingsGuidelines_faqCatFindingCasesA3.
  ///
  /// In en, this message translates to:
  /// **'The default compact view uses cards to fit as much information as possible into as little space as possible. Switch to extended view using the toggle beside the search field on the Cases screen, or in Settings > View Settings > Case List View.'**
  String get settingsGuidelines_faqCatFindingCasesA3;

  /// No description provided for @settingsGuidelines_faqCatFindingCasesQ4.
  ///
  /// In en, this message translates to:
  /// **'What does the Daily Cause List show?'**
  String get settingsGuidelines_faqCatFindingCasesQ4;

  /// No description provided for @settingsGuidelines_faqCatFindingCasesA4.
  ///
  /// In en, this message translates to:
  /// **'The hearings recorded in your diary for one date, grouped by court in your court hierarchy, with a total for the day. Choose the date from the calendar; today is selected by default.'**
  String get settingsGuidelines_faqCatFindingCasesA4;

  /// No description provided for @settingsGuidelines_faqCatNotesAndPrinting.
  ///
  /// In en, this message translates to:
  /// **'Notes, references and printing'**
  String get settingsGuidelines_faqCatNotesAndPrinting;

  /// No description provided for @settingsGuidelines_faqCatNotesAndPrintingQ1.
  ///
  /// In en, this message translates to:
  /// **'What is the difference between Notes and Case References?'**
  String get settingsGuidelines_faqCatNotesAndPrintingQ1;

  /// No description provided for @settingsGuidelines_faqCatNotesAndPrintingA1.
  ///
  /// In en, this message translates to:
  /// **'Notes holds free-form notes with a title and body. Case Reference is a structured library of citations — reference, statute, section, description and private comments — which you can pin. Both are separate from your cases and neither is linked to one automatically.'**
  String get settingsGuidelines_faqCatNotesAndPrintingA1;

  /// No description provided for @settingsGuidelines_faqCatNotesAndPrintingQ2.
  ///
  /// In en, this message translates to:
  /// **'What can I print?'**
  String get settingsGuidelines_faqCatNotesAndPrintingQ2;

  /// No description provided for @settingsGuidelines_faqCatNotesAndPrintingA2.
  ///
  /// In en, this message translates to:
  /// **'A case\'s details, and case lists. Print produces a formatted PDF and uses the device\'s printing options. Print is not available on the Notes and Case Reference screens.'**
  String get settingsGuidelines_faqCatNotesAndPrintingA2;

  /// No description provided for @settingsGuidelines_faqCatNotesAndPrintingQ3.
  ///
  /// In en, this message translates to:
  /// **'How do I contact a client about a case?'**
  String get settingsGuidelines_faqCatNotesAndPrintingQ3;

  /// No description provided for @settingsGuidelines_faqCatNotesAndPrintingA3.
  ///
  /// In en, this message translates to:
  /// **'A case that carries the client\'s phone number offers Call, Message and WhatsApp actions, and a prepared message containing the client\'s name, the case number, the next hearing date and the court. Review the message before sending — the app cannot check that the number or the hearing date is current.'**
  String get settingsGuidelines_faqCatNotesAndPrintingA3;

  /// No description provided for @settingsGuidelines_faqCatBackupAndRestore.
  ///
  /// In en, this message translates to:
  /// **'Backup and restore'**
  String get settingsGuidelines_faqCatBackupAndRestore;

  /// No description provided for @settingsGuidelines_faqCatBackupAndRestoreQ1.
  ///
  /// In en, this message translates to:
  /// **'How do I back up my diary?'**
  String get settingsGuidelines_faqCatBackupAndRestoreQ1;

  /// No description provided for @settingsGuidelines_faqCatBackupAndRestoreA1.
  ///
  /// In en, this message translates to:
  /// **'Go to Settings > Backup & Restore and tap Backup to Local Storage. You choose where the file is saved and set a passphrase that encrypts it. Your account is already in place, so no internet connection is required.'**
  String get settingsGuidelines_faqCatBackupAndRestoreA1;

  /// No description provided for @settingsGuidelines_faqCatBackupAndRestoreQ2.
  ///
  /// In en, this message translates to:
  /// **'Does the app back up automatically?'**
  String get settingsGuidelines_faqCatBackupAndRestoreQ2;

  /// No description provided for @settingsGuidelines_faqCatBackupAndRestoreA2.
  ///
  /// In en, this message translates to:
  /// **'Not in the offline version — each backup is started by you. If no backup has been made in the current month, the app displays a reminder, which you can dismiss.'**
  String get settingsGuidelines_faqCatBackupAndRestoreA2;

  /// No description provided for @settingsGuidelines_faqCatBackupAndRestoreQ3.
  ///
  /// In en, this message translates to:
  /// **'I forgot my passphrase. Can you recover it?'**
  String get settingsGuidelines_faqCatBackupAndRestoreQ3;

  /// No description provided for @settingsGuidelines_faqCatBackupAndRestoreA3.
  ///
  /// In en, this message translates to:
  /// **'No. The passphrase is never stored, on your device or anywhere else, so a backup cannot be opened without it. If it is lost, make a fresh backup with a passphrase you can keep safely.'**
  String get settingsGuidelines_faqCatBackupAndRestoreA3;

  /// No description provided for @settingsGuidelines_faqCatBackupAndRestoreQ4.
  ///
  /// In en, this message translates to:
  /// **'What does restoring a backup do to my current data?'**
  String get settingsGuidelines_faqCatBackupAndRestoreQ4;

  /// No description provided for @settingsGuidelines_faqCatBackupAndRestoreA4.
  ///
  /// In en, this message translates to:
  /// **'Restoring replaces everything currently in the app with the contents of the backup file. It does not merge, and it cannot be undone. Back up your current diary first if there is anything in it you may still need. If the app already holds data, it asks you to confirm before anything is replaced.'**
  String get settingsGuidelines_faqCatBackupAndRestoreA4;

  /// No description provided for @settingsGuidelines_faqCatBackupAndRestoreQ5.
  ///
  /// In en, this message translates to:
  /// **'How do I move my diary to a new phone?'**
  String get settingsGuidelines_faqCatBackupAndRestoreQ5;

  /// No description provided for @settingsGuidelines_faqCatBackupAndRestoreA5.
  ///
  /// In en, this message translates to:
  /// **'Make a backup on your current phone and save the file somewhere the new phone can reach — a memory card, Google Drive, or an email to yourself. Install the app on the new phone, open Settings > Backup & Restore, and use Restore from backup with the same passphrase.'**
  String get settingsGuidelines_faqCatBackupAndRestoreA5;

  /// No description provided for @settingsGuidelines_faqCatBackupAndRestoreQ6.
  ///
  /// In en, this message translates to:
  /// **'Can I use a backup made by a different version of the app?'**
  String get settingsGuidelines_faqCatBackupAndRestoreQ6;

  /// No description provided for @settingsGuidelines_faqCatBackupAndRestoreA6.
  ///
  /// In en, this message translates to:
  /// **'Backups made by older versions are upgraded automatically when restored. A backup made by a newer version than the one you are running is refused, so update the app first and then restore.'**
  String get settingsGuidelines_faqCatBackupAndRestoreA6;

  /// No description provided for @settingsGuidelines_faqCatBackupAndRestoreQ7.
  ///
  /// In en, this message translates to:
  /// **'What happens to my data if I delete the app or lose my phone?'**
  String get settingsGuidelines_faqCatBackupAndRestoreQ7;

  /// No description provided for @settingsGuidelines_faqCatBackupAndRestoreA7.
  ///
  /// In en, this message translates to:
  /// **'In the offline version your diary is stored only on the device, so uninstalling the app or losing the phone also loses the data unless you hold a backup file. Keep a recent backup, and store a copy somewhere outside the phone.'**
  String get settingsGuidelines_faqCatBackupAndRestoreA7;

  /// No description provided for @settingsGuidelines_faqCatNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsGuidelines_faqCatNotifications;

  /// No description provided for @settingsGuidelines_faqCatNotificationsQ1.
  ///
  /// In en, this message translates to:
  /// **'Why didn\'t my hearing notification arrive?'**
  String get settingsGuidelines_faqCatNotificationsQ1;

  /// No description provided for @settingsGuidelines_faqCatNotificationsA1.
  ///
  /// In en, this message translates to:
  /// **'Most Android phones stop background apps to save battery, which prevents hearing alerts. In Settings > Notifications, tap Battery & Auto-Start Setup Guide and follow the steps for your phone, then use Send Test Notification to confirm that alerts arrive.'**
  String get settingsGuidelines_faqCatNotificationsA1;

  /// No description provided for @settingsGuidelines_faqCatNotificationsQ2.
  ///
  /// In en, this message translates to:
  /// **'Can I change when hearing notifications are sent?'**
  String get settingsGuidelines_faqCatNotificationsQ2;

  /// No description provided for @settingsGuidelines_faqCatNotificationsA2.
  ///
  /// In en, this message translates to:
  /// **'Yes. In Settings > Notifications you can choose the day offset — the same day, the day before, or a number of days before the hearing — and the time of day. Notifications can be turned off entirely from the same screen.'**
  String get settingsGuidelines_faqCatNotificationsA2;

  /// No description provided for @settingsGuidelines_faqCatLanguageAndDisplay.
  ///
  /// In en, this message translates to:
  /// **'Language and display'**
  String get settingsGuidelines_faqCatLanguageAndDisplay;

  /// No description provided for @settingsGuidelines_faqCatLanguageAndDisplayQ1.
  ///
  /// In en, this message translates to:
  /// **'How do I change the app language?'**
  String get settingsGuidelines_faqCatLanguageAndDisplayQ1;

  /// No description provided for @settingsGuidelines_faqCatLanguageAndDisplayA1.
  ///
  /// In en, this message translates to:
  /// **'Go to Settings > Language and choose English or বাংলা. The change applies throughout the app, and numbers are displayed in the numerals of the selected language. The app language does not change the language your case data was entered in, which is what search matches against.'**
  String get settingsGuidelines_faqCatLanguageAndDisplayA1;

  /// No description provided for @settingsGuidelines_faqCatFreePlanAndPremium.
  ///
  /// In en, this message translates to:
  /// **'Free plan and premium'**
  String get settingsGuidelines_faqCatFreePlanAndPremium;

  /// No description provided for @settingsGuidelines_faqCatFreePlanAndPremiumQ1.
  ///
  /// In en, this message translates to:
  /// **'Is the app free?'**
  String get settingsGuidelines_faqCatFreePlanAndPremiumQ1;

  /// No description provided for @settingsGuidelines_faqCatFreePlanAndPremiumA1.
  ///
  /// In en, this message translates to:
  /// **'Yes. Every account starts on the free plan, which costs nothing, holds up to 50 cases and keeps them on this device. Premium raises that limit and will add cloud backup and sync when it launches.'**
  String get settingsGuidelines_faqCatFreePlanAndPremiumA1;

  /// No description provided for @settingsGuidelines_faqCatFreePlanAndPremiumQ2.
  ///
  /// In en, this message translates to:
  /// **'Why can\'t I add a case?'**
  String get settingsGuidelines_faqCatFreePlanAndPremiumQ2;

  /// No description provided for @settingsGuidelines_faqCatFreePlanAndPremiumA2.
  ///
  /// In en, this message translates to:
  /// **'The free plan holds up to 50 cases. At the limit, the Add Case form opens the premium screen instead. Nothing is hidden or deleted — you can still view, edit, print and delete every case you have, and deleting a case frees a slot.'**
  String get settingsGuidelines_faqCatFreePlanAndPremiumA2;

  /// No description provided for @settingsGuidelines_faqCatFreePlanAndPremiumQ3.
  ///
  /// In en, this message translates to:
  /// **'What stays free?'**
  String get settingsGuidelines_faqCatFreePlanAndPremiumQ3;

  /// No description provided for @settingsGuidelines_faqCatFreePlanAndPremiumA3.
  ///
  /// In en, this message translates to:
  /// **'Everything except adding cases beyond the limit: viewing, editing, updating, deleting and printing cases, the Daily Cause List, client details and contact actions, Notes, Case References, and Backup & Restore.'**
  String get settingsGuidelines_faqCatFreePlanAndPremiumA3;

  /// No description provided for @settingsGuidelines_faqCatFreePlanAndPremiumQ4.
  ///
  /// In en, this message translates to:
  /// **'Why isn\'t cloud backup offered for free?'**
  String get settingsGuidelines_faqCatFreePlanAndPremiumQ4;

  /// No description provided for @settingsGuidelines_faqCatFreePlanAndPremiumA4.
  ///
  /// In en, this message translates to:
  /// **'Cloud backup and online mode depend on a backend service, which we pay for. Your subscription will cover the cost of storing your data securely online, which is why that service cannot be offered at no charge.'**
  String get settingsGuidelines_faqCatFreePlanAndPremiumA4;

  /// No description provided for @settingsGuidelines_faqCatFreePlanAndPremiumQ5.
  ///
  /// In en, this message translates to:
  /// **'Can I subscribe now?'**
  String get settingsGuidelines_faqCatFreePlanAndPremiumQ5;

  /// No description provided for @settingsGuidelines_faqCatFreePlanAndPremiumA5.
  ///
  /// In en, this message translates to:
  /// **'Not yet. The premium screen shows the available plans, but purchases open with the online version. Until then the offline app is fully usable, and your data stays on your device.'**
  String get settingsGuidelines_faqCatFreePlanAndPremiumA5;

  /// No description provided for @settingsGuidelines_faqCatCourtsAndCustomisation.
  ///
  /// In en, this message translates to:
  /// **'Courts and customisation'**
  String get settingsGuidelines_faqCatCourtsAndCustomisation;

  /// No description provided for @settingsGuidelines_faqCatCourtsAndCustomisationQ1.
  ///
  /// In en, this message translates to:
  /// **'Why are some district court names not what I expect?'**
  String get settingsGuidelines_faqCatCourtsAndCustomisationQ1;

  /// No description provided for @settingsGuidelines_faqCatCourtsAndCustomisationA1.
  ///
  /// In en, this message translates to:
  /// **'We sourced court names for all 64 districts from the Government\'s Cause List website (causelist.judiciary.gov.bd) and used them unchanged. You can rename any court to your preference in Settings > Edit Court/Steps.'**
  String get settingsGuidelines_faqCatCourtsAndCustomisationA1;

  /// No description provided for @settingsGuidelines_faqCatCourtsAndCustomisationQ2.
  ///
  /// In en, this message translates to:
  /// **'Can I add my own courts, case types, steps or on-behalf items?'**
  String get settingsGuidelines_faqCatCourtsAndCustomisationQ2;

  /// No description provided for @settingsGuidelines_faqCatCourtsAndCustomisationA2.
  ///
  /// In en, this message translates to:
  /// **'Yes. Settings > Edit Court/Steps lets you add, rename and delete the courts, case types, steps and on-behalf entries used in the Add and Edit Case forms. Deleting an item cannot be undone.'**
  String get settingsGuidelines_faqCatCourtsAndCustomisationA2;

  /// No description provided for @settingsGuidelines_faqCatCourtsAndCustomisationQ3.
  ///
  /// In en, this message translates to:
  /// **'Where do Tribunals and Special Tribunals appear?'**
  String get settingsGuidelines_faqCatCourtsAndCustomisationQ3;

  /// No description provided for @settingsGuidelines_faqCatCourtsAndCustomisationA3.
  ///
  /// In en, this message translates to:
  /// **'So that tribunals display the correct case types, steps and on-behalf options, we grouped them by subject:\n\nCivil tribunals → District Judge Court (Civil)\nCriminal tribunals → Sessions Judge Court (Criminal)\nCriminal tribunals in metropolitan areas → Metropolitan Sessions Judge Court (Criminal)'**
  String get settingsGuidelines_faqCatCourtsAndCustomisationA3;

  /// No description provided for @settingsGuidelines_faqCatCourtsAndCustomisationQ4.
  ///
  /// In en, this message translates to:
  /// **'I can\'t find the court I\'m looking for.'**
  String get settingsGuidelines_faqCatCourtsAndCustomisationQ4;

  /// No description provided for @settingsGuidelines_faqCatCourtsAndCustomisationA4.
  ///
  /// In en, this message translates to:
  /// **'Courts are listed under the following categories:\n\nDistrict Judge Court (Civil)\n1. District and Additional District Judge Courts\n2. Joint District Judge Courts\n3. Civil & Senior Civil Judge Courts\n4. Family Courts & Family Appeal Court\n5. Land Survey Tribunal & Land Survey Appeal Tribunal\n6. Commercial Court\n7. Labour Court\n\nSessions Judge Court (Criminal) and Metropolitan Sessions Judge Court (Criminal)\n1. Sessions and Additional Sessions Judge Courts\n2. Joint Sessions Judge Courts\n3. Women and Child Abuse Suppression Tribunal\n4. Child Violence Prevention Tribunal\n5. Special Tribunals\n\nChief Judicial Magistrate Court and Chief Metropolitan Magistrate Court\n1. Chief and Additional Chief Judicial Magistrate\n2. Special Magistrate Courts\n3. Speedy Trial Court\n4. Environment Court\n5. Forest Court\n6. Senior Judicial Magistrate Courts\n7. Judicial Magistrate Courts\n8. Cognizance Courts'**
  String get settingsGuidelines_faqCatCourtsAndCustomisationA4;

  /// No description provided for @settingsGuidelines_faqCatDataAndSupport.
  ///
  /// In en, this message translates to:
  /// **'Data, privacy and support'**
  String get settingsGuidelines_faqCatDataAndSupport;

  /// No description provided for @settingsGuidelines_faqCatDataAndSupportQ1.
  ///
  /// In en, this message translates to:
  /// **'Where is my data stored, and who can see it?'**
  String get settingsGuidelines_faqCatDataAndSupportQ1;

  /// No description provided for @settingsGuidelines_faqCatDataAndSupportA1.
  ///
  /// In en, this message translates to:
  /// **'In the offline version, everything you enter is stored on your device in encrypted form. Nothing is sent to us or to anyone else. Your account is what makes the diary yours from the first case — on the free plan it carries no case data anywhere. Backup files are encrypted and can only be opened with the passphrase you set. When the online version launches, what it stores and where will be described in its own topic before you use it.'**
  String get settingsGuidelines_faqCatDataAndSupportA1;

  /// No description provided for @settingsGuidelines_faqCatDataAndSupportQ2.
  ///
  /// In en, this message translates to:
  /// **'Is the app a substitute for court records?'**
  String get settingsGuidelines_faqCatDataAndSupportQ2;

  /// No description provided for @settingsGuidelines_faqCatDataAndSupportA2.
  ///
  /// In en, this message translates to:
  /// **'No. The app is a personal record-keeping tool for your own practice. The information in it is entered by you, and the official cause list and court records remain authoritative. Always verify a hearing date against the court before relying on it.'**
  String get settingsGuidelines_faqCatDataAndSupportA2;

  /// No description provided for @settingsGuidelines_faqCatDataAndSupportQ3.
  ///
  /// In en, this message translates to:
  /// **'My question isn\'t answered here.'**
  String get settingsGuidelines_faqCatDataAndSupportQ3;

  /// No description provided for @settingsGuidelines_faqCatDataAndSupportA3.
  ///
  /// In en, this message translates to:
  /// **'Open Settings > About > Support and write to us there — the message opens already carrying your app version and your phone model. Describe what you were doing when the problem occurred. You can also write to adv.asadusjaman@gmail.com.'**
  String get settingsGuidelines_faqCatDataAndSupportA3;

  /// No description provided for @settingsAbout_title.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout_title;

  /// Bundled app version, shown on the About and More About the App cards.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String settingsAbout_version(String version);

  /// No description provided for @settingsAbout_designedBy.
  ///
  /// In en, this message translates to:
  /// **'Designed & Developed By'**
  String get settingsAbout_designedBy;

  /// No description provided for @settingsAbout_role.
  ///
  /// In en, this message translates to:
  /// **'Advocate'**
  String get settingsAbout_role;

  /// No description provided for @settingsAbout_moreAboutApp.
  ///
  /// In en, this message translates to:
  /// **'More About the App'**
  String get settingsAbout_moreAboutApp;

  /// No description provided for @settingsAbout_privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get settingsAbout_privacyPolicy;

  /// No description provided for @settingsAbout_termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get settingsAbout_termsOfService;

  /// No description provided for @settingsAbout_support.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get settingsAbout_support;

  /// No description provided for @settingsAbout_dataSafetyTitle.
  ///
  /// In en, this message translates to:
  /// **'Data Safety'**
  String get settingsAbout_dataSafetyTitle;

  /// No description provided for @settingsAbout_dataSafetyBody.
  ///
  /// In en, this message translates to:
  /// **'Your diary and your backup files are stored on your device in encrypted form. Nothing is uploaded unless you send it.'**
  String get settingsAbout_dataSafetyBody;

  /// No description provided for @settingsAbout_actionPending.
  ///
  /// In en, this message translates to:
  /// **'Arrives in a later task'**
  String get settingsAbout_actionPending;

  /// No description provided for @settingsUpdate_entry.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get settingsUpdate_entry;

  /// No description provided for @settingsUpdate_appUpdate.
  ///
  /// In en, this message translates to:
  /// **'App Update'**
  String get settingsUpdate_appUpdate;

  /// No description provided for @settingsUpdate_appUpdateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Check for updates and update the app'**
  String get settingsUpdate_appUpdateSubtitle;

  /// No description provided for @settingsUpdate_autoUpdate.
  ///
  /// In en, this message translates to:
  /// **'Auto Check for Update'**
  String get settingsUpdate_autoUpdate;

  /// No description provided for @settingsUpdate_autoUpdateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose how often to check for updates'**
  String get settingsUpdate_autoUpdateSubtitle;

  /// No description provided for @settingsUpdate_networkTitle.
  ///
  /// In en, this message translates to:
  /// **'Update over Network'**
  String get settingsUpdate_networkTitle;

  /// No description provided for @settingsUpdate_networkSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose which network downloads the update'**
  String get settingsUpdate_networkSubtitle;

  /// No description provided for @settingsUpdate_networkWifi.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi Only'**
  String get settingsUpdate_networkWifi;

  /// No description provided for @settingsUpdate_networkMobileData.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi & Mobile Data'**
  String get settingsUpdate_networkMobileData;

  /// No description provided for @settingsUpdate_currentVersion.
  ///
  /// In en, this message translates to:
  /// **'Current Version:'**
  String get settingsUpdate_currentVersion;

  /// No description provided for @settingsUpdate_checkForUpdate.
  ///
  /// In en, this message translates to:
  /// **'Check for update'**
  String get settingsUpdate_checkForUpdate;

  /// No description provided for @settingsUpdate_checking.
  ///
  /// In en, this message translates to:
  /// **'Checking For Update'**
  String get settingsUpdate_checking;

  /// No description provided for @settingsUpdate_updateNow.
  ///
  /// In en, this message translates to:
  /// **'Update Now'**
  String get settingsUpdate_updateNow;

  /// No description provided for @settingsUpdate_later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get settingsUpdate_later;

  /// No description provided for @settingsUpdate_skipVersion.
  ///
  /// In en, this message translates to:
  /// **'Skip This Version'**
  String get settingsUpdate_skipVersion;

  /// No description provided for @settingsUpdate_newerVersion.
  ///
  /// In en, this message translates to:
  /// **'There is a newer version available ({version}).'**
  String settingsUpdate_newerVersion(String version);

  /// No description provided for @settingsUpdate_latestVersion.
  ///
  /// In en, this message translates to:
  /// **'You are on the latest {version} version.'**
  String settingsUpdate_latestVersion(String version);

  /// No description provided for @settingsUpdate_mobileDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Download Over Mobile Data?'**
  String get settingsUpdate_mobileDataTitle;

  /// No description provided for @settingsUpdate_mobileDataBody.
  ///
  /// In en, this message translates to:
  /// **'You are on mobile data and the update is a large download. Continue, or switch to Wi-Fi to download it there.'**
  String get settingsUpdate_mobileDataBody;

  /// No description provided for @settingsUpdate_mobileDataContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get settingsUpdate_mobileDataContinue;

  /// No description provided for @settingsUpdate_checkFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not check for an update right now. Please try again later.'**
  String get settingsUpdate_checkFailed;

  /// No description provided for @settingsUpdate_downloadFailed.
  ///
  /// In en, this message translates to:
  /// **'The update could not be downloaded. Please try again later.'**
  String get settingsUpdate_downloadFailed;

  /// No description provided for @settingsUpdate_installUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This device cannot install an update.'**
  String get settingsUpdate_installUnavailable;

  /// No description provided for @settingsUpdate_unverifiedRelease.
  ///
  /// In en, this message translates to:
  /// **'This update could not be verified, so it was not installed.'**
  String get settingsUpdate_unverifiedRelease;

  /// No description provided for @settingsUpdate_offlineToast.
  ///
  /// In en, this message translates to:
  /// **'Please connect to the internet and check for an update.'**
  String get settingsUpdate_offlineToast;

  /// No description provided for @settingsUpdate_frequencyOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get settingsUpdate_frequencyOff;

  /// No description provided for @settingsUpdate_frequencyEveryday.
  ///
  /// In en, this message translates to:
  /// **'Every Day'**
  String get settingsUpdate_frequencyEveryday;

  /// No description provided for @settingsUpdate_frequencyEvery3Days.
  ///
  /// In en, this message translates to:
  /// **'Every 3 Days'**
  String get settingsUpdate_frequencyEvery3Days;

  /// No description provided for @settingsUpdate_frequencyEvery7Days.
  ///
  /// In en, this message translates to:
  /// **'Every 7 Days'**
  String get settingsUpdate_frequencyEvery7Days;

  /// No description provided for @settingsUpdate_frequencyEveryMonth.
  ///
  /// In en, this message translates to:
  /// **'Every Month'**
  String get settingsUpdate_frequencyEveryMonth;

  /// No description provided for @settingsLegal_loadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open this document. Please try again.'**
  String get settingsLegal_loadFailed;

  /// No description provided for @settingsSupport_title.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get settingsSupport_title;

  /// No description provided for @settingsSupport_scopeTitle.
  ///
  /// In en, this message translates to:
  /// **'Before You Write To Us'**
  String get settingsSupport_scopeTitle;

  /// No description provided for @settingsSupport_helpTitle.
  ///
  /// In en, this message translates to:
  /// **'What can we help you with:'**
  String get settingsSupport_helpTitle;

  /// No description provided for @settingsSupport_faqCardPrefix.
  ///
  /// In en, this message translates to:
  /// **'Most questions are already answered in '**
  String get settingsSupport_faqCardPrefix;

  /// No description provided for @settingsSupport_faqCardSuffix.
  ///
  /// In en, this message translates to:
  /// **'.'**
  String get settingsSupport_faqCardSuffix;

  /// No description provided for @settingsSupport_scope.
  ///
  /// In en, this message translates to:
  /// **'We can help you with the app itself: how a feature works, something that is not behaving as it should, or a backup that will not restore. We cannot see your diary — it stays on your phone — and we cannot check, confirm or look up a hearing date for you.'**
  String get settingsSupport_scope;

  /// No description provided for @settingsSupport_faqLead.
  ///
  /// In en, this message translates to:
  /// **'Use Diagnostics to find errors in the app.'**
  String get settingsSupport_faqLead;

  /// No description provided for @settingsSupport_channelsLabel.
  ///
  /// In en, this message translates to:
  /// **'Write to Us'**
  String get settingsSupport_channelsLabel;

  /// No description provided for @settingsSupport_channelWhatsApp.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp'**
  String get settingsSupport_channelWhatsApp;

  /// No description provided for @settingsSupport_channelEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get settingsSupport_channelEmail;

  /// No description provided for @settingsSupport_messageSubject.
  ///
  /// In en, this message translates to:
  /// **'Legal Case Diary support'**
  String get settingsSupport_messageSubject;

  /// No description provided for @settingsSupport_messageIntro.
  ///
  /// In en, this message translates to:
  /// **'Hello, I need help with Legal Case Diary.'**
  String get settingsSupport_messageIntro;

  /// No description provided for @settingsSupport_messageVersion.
  ///
  /// In en, this message translates to:
  /// **'App version'**
  String get settingsSupport_messageVersion;

  /// No description provided for @settingsSupport_messagePhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get settingsSupport_messagePhone;

  /// No description provided for @settingsSupport_messageLanguage.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get settingsSupport_messageLanguage;

  /// No description provided for @settingsSupport_messagePrompt.
  ///
  /// In en, this message translates to:
  /// **'What happened, and what I did just before it:'**
  String get settingsSupport_messagePrompt;

  /// No description provided for @settingsSupport_warningTitle.
  ///
  /// In en, this message translates to:
  /// **'Never send these:'**
  String get settingsSupport_warningTitle;

  /// No description provided for @settingsSupport_warningBody.
  ///
  /// In en, this message translates to:
  /// **'Your passphrase, your diary database file, or a backup file. We will never ask for them, and a message that asks for them is not from us.'**
  String get settingsSupport_warningBody;

  /// No description provided for @settingsSupport_replyTitle.
  ///
  /// In en, this message translates to:
  /// **'When you will hear back:'**
  String get settingsSupport_replyTitle;

  /// No description provided for @settingsSupport_replyBody.
  ///
  /// In en, this message translates to:
  /// **'Support is handled by the app\'s developer alongside court work, so a reply usually takes one to two working days (Sunday to Thursday). There is no phone line and no live chat — the answer comes back to the WhatsApp or email address you wrote from.'**
  String get settingsSupport_replyBody;

  /// No description provided for @settingsSupport_unableToOpenWhatsApp.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp could not be opened.'**
  String get settingsSupport_unableToOpenWhatsApp;

  /// No description provided for @settingsSupport_unableToOpenEmail.
  ///
  /// In en, this message translates to:
  /// **'No email app could be opened.'**
  String get settingsSupport_unableToOpenEmail;

  /// No description provided for @settingsMoreAbout_title.
  ///
  /// In en, this message translates to:
  /// **'More About the App'**
  String get settingsMoreAbout_title;

  /// No description provided for @settingsMoreAbout_description.
  ///
  /// In en, this message translates to:
  /// **'Legal Case Diary is a complete offline case diary built for lawyers in Bangladesh. It organises your cases and hearings into a daily cause list, tracks upcoming and overdue dates so nothing is missed, and keeps your notes and case references beside them. Everything is entered by you and stored on your device in encrypted form — no account is required, and no data leaves your phone unless you send it.'**
  String get settingsMoreAbout_description;

  /// No description provided for @settingsMoreAbout_keyFeatures.
  ///
  /// In en, this message translates to:
  /// **'Key Features'**
  String get settingsMoreAbout_keyFeatures;

  /// No description provided for @settingsMoreAbout_featureDailyCauseList.
  ///
  /// In en, this message translates to:
  /// **'Daily Cause List'**
  String get settingsMoreAbout_featureDailyCauseList;

  /// No description provided for @settingsMoreAbout_featureOfflineBackup.
  ///
  /// In en, this message translates to:
  /// **'Offline Backup'**
  String get settingsMoreAbout_featureOfflineBackup;

  /// No description provided for @settingsMoreAbout_featureCaseReferences.
  ///
  /// In en, this message translates to:
  /// **'Case References'**
  String get settingsMoreAbout_featureCaseReferences;

  /// No description provided for @settingsMoreAbout_featureHearingNotifications.
  ///
  /// In en, this message translates to:
  /// **'Hearing Notifications'**
  String get settingsMoreAbout_featureHearingNotifications;

  /// No description provided for @settingsMoreAbout_rateApp.
  ///
  /// In en, this message translates to:
  /// **'Rate App'**
  String get settingsMoreAbout_rateApp;

  /// No description provided for @settingsMoreAbout_shareApp.
  ///
  /// In en, this message translates to:
  /// **'Share App'**
  String get settingsMoreAbout_shareApp;

  /// No description provided for @settingsMoreAbout_footer.
  ///
  /// In en, this message translates to:
  /// **'Designed & Developed by'**
  String get settingsMoreAbout_footer;

  /// Shown when a screen has no printable document (Notes, Case Reference).
  ///
  /// In en, this message translates to:
  /// **'Print is not available on this screen.'**
  String get print_notAvailable;

  /// Invite text handed to the Android share sheet by the Share action.
  ///
  /// In en, this message translates to:
  /// **'Legal Case Diary - a complete offline case diary for Bangladeshi lawyers.\nGet it here: {link}'**
  String appShare_invite(String link);

  /// Subject of the share intent carrying the app invite.
  ///
  /// In en, this message translates to:
  /// **'Legal Case Diary'**
  String get appShare_subject;

  /// Fallback message when no share target answers the invite.
  ///
  /// In en, this message translates to:
  /// **'No app to share with, so the invite was copied to your clipboard.'**
  String get appShare_copied;

  /// Shown when the share sheet itself failed.
  ///
  /// In en, this message translates to:
  /// **'Could Not Share the App'**
  String get appShare_failed;

  /// Title of the progress dialog while a document is rendered page by page.
  ///
  /// In en, this message translates to:
  /// **'Preparing Your Print'**
  String get print_preparing;

  /// Heading of the case-list table's narrow serial column. The short form is the only one that fits its 0.69 cm cell; Bengali uses the short ক্ৰম.
  ///
  /// In en, this message translates to:
  /// **'SL'**
  String get print_serialShort;

  /// Label of the day's date in the Daily Cause List printout's Date/Day/Month/Year line.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get print_dateLabel;

  /// Label of the weekday in the Daily Cause List printout's Date/Day/Month/Year line.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get print_dayLabel;

  /// Label of the month in the Daily Cause List printout's Date/Day/Month/Year line.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get print_monthLabel;

  /// Label of the year in the Daily Cause List printout's Date/Day/Month/Year line.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get print_yearLabel;

  /// The Daily Cause List printout's date line, e.g. 'Date: 10/10/26  Day: Saturday  Month: October  Year: 2026'.
  ///
  /// In en, this message translates to:
  /// **'{dateLabel}: {date}       {dayLabel}: {day}       {monthLabel}: {month}       {yearLabel}: {year}'**
  String print_dateLine(
    String dateLabel,
    String date,
    String dayLabel,
    String day,
    String monthLabel,
    String month,
    String yearLabel,
    String year,
  );

  /// Shown when rendering or presenting a print job failed; the user can try again.
  ///
  /// In en, this message translates to:
  /// **'Could Not Print'**
  String get print_failed;

  /// Shown when the current filters leave no rows to print.
  ///
  /// In en, this message translates to:
  /// **'Nothing to Print'**
  String get print_nothingToPrint;

  /// Footer line of every printed document.
  ///
  /// In en, this message translates to:
  /// **'Printed on {date}'**
  String print_printedOn(String date);

  /// Page counter of every printed document.
  ///
  /// In en, this message translates to:
  /// **'Page {page} of {total}'**
  String print_pageOf(int page, int total);

  /// No description provided for @localeScratch_title.
  ///
  /// In en, this message translates to:
  /// **'Localization Scratch'**
  String get localeScratch_title;

  /// No description provided for @localeScratch_greeting.
  ///
  /// In en, this message translates to:
  /// **'Hello'**
  String get localeScratch_greeting;

  /// No description provided for @localeScratch_englishSample.
  ///
  /// In en, this message translates to:
  /// **'This text is in English.'**
  String get localeScratch_englishSample;

  /// No description provided for @localeScratch_bengaliSample.
  ///
  /// In en, this message translates to:
  /// **'এই টেক্সটি বাংলায়।'**
  String get localeScratch_bengaliSample;

  /// Shows the currently selected language code.
  ///
  /// In en, this message translates to:
  /// **'Current language: {language}'**
  String localeScratch_currentLanguage(String language);

  /// No description provided for @auth_loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Log in to the app'**
  String get auth_loginSubtitle;

  /// No description provided for @auth_emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get auth_emailLabel;

  /// No description provided for @auth_emailHint.
  ///
  /// In en, this message translates to:
  /// **'example@gmail.com'**
  String get auth_emailHint;

  /// No description provided for @auth_passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get auth_passwordLabel;

  /// No description provided for @auth_passwordHint.
  ///
  /// In en, this message translates to:
  /// **'••••••••'**
  String get auth_passwordHint;

  /// No description provided for @auth_forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get auth_forgotPassword;

  /// No description provided for @auth_loginButton.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get auth_loginButton;

  /// No description provided for @auth_orContinueWith.
  ///
  /// In en, this message translates to:
  /// **'Or'**
  String get auth_orContinueWith;

  /// No description provided for @auth_googleLogin.
  ///
  /// In en, this message translates to:
  /// **'Login with Google'**
  String get auth_googleLogin;

  /// No description provided for @auth_googleSignup.
  ///
  /// In en, this message translates to:
  /// **'Sign Up with Google'**
  String get auth_googleSignup;

  /// No description provided for @auth_noAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get auth_noAccount;

  /// No description provided for @auth_signUpLink.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get auth_signUpLink;

  /// No description provided for @auth_haveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get auth_haveAccount;

  /// No description provided for @auth_loginLink.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get auth_loginLink;

  /// No description provided for @auth_signupTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get auth_signupTitle;

  /// No description provided for @auth_signupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start a stress-free journey of case management.'**
  String get auth_signupSubtitle;

  /// No description provided for @auth_fullNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get auth_fullNameLabel;

  /// No description provided for @auth_fullNameHint.
  ///
  /// In en, this message translates to:
  /// **'Type your name.'**
  String get auth_fullNameHint;

  /// No description provided for @auth_barAssociationLabel.
  ///
  /// In en, this message translates to:
  /// **'Bar Association'**
  String get auth_barAssociationLabel;

  /// No description provided for @auth_barAssociationHint.
  ///
  /// In en, this message translates to:
  /// **'Name of your district bar association.'**
  String get auth_barAssociationHint;

  /// No description provided for @auth_emailAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get auth_emailAddressLabel;

  /// No description provided for @auth_emailAddressHint.
  ///
  /// In en, this message translates to:
  /// **'example@gmail.com'**
  String get auth_emailAddressHint;

  /// No description provided for @auth_passwordHelper.
  ///
  /// In en, this message translates to:
  /// **'Must be at least 8 characters long.'**
  String get auth_passwordHelper;

  /// No description provided for @auth_confirmPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get auth_confirmPasswordLabel;

  /// No description provided for @auth_accountTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Account Type'**
  String get auth_accountTypeLabel;

  /// No description provided for @auth_accountTypeIndividual.
  ///
  /// In en, this message translates to:
  /// **'Individual'**
  String get auth_accountTypeIndividual;

  /// No description provided for @auth_accountTypeJoinFirm.
  ///
  /// In en, this message translates to:
  /// **'Join Existing Firm'**
  String get auth_accountTypeJoinFirm;

  /// No description provided for @auth_inviteCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Invite Code'**
  String get auth_inviteCodeLabel;

  /// No description provided for @auth_inviteCodeHint.
  ///
  /// In en, this message translates to:
  /// **'ABCDE12345'**
  String get auth_inviteCodeHint;

  /// No description provided for @auth_inviteCodeHelper.
  ///
  /// In en, this message translates to:
  /// **'Ask your firm owner for a single-use code.'**
  String get auth_inviteCodeHelper;

  /// No description provided for @auth_termsAgreePrefix.
  ///
  /// In en, this message translates to:
  /// **'I agree to the'**
  String get auth_termsAgreePrefix;

  /// No description provided for @auth_termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get auth_termsOfService;

  /// No description provided for @auth_termsAgreeJoin.
  ///
  /// In en, this message translates to:
  /// **'and'**
  String get auth_termsAgreeJoin;

  /// No description provided for @auth_privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get auth_privacyPolicy;

  /// No description provided for @auth_signUpButton.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get auth_signUpButton;

  /// No description provided for @auth_showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show Password'**
  String get auth_showPassword;

  /// No description provided for @auth_hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide Password'**
  String get auth_hidePassword;

  /// No description provided for @auth_clearEmail.
  ///
  /// In en, this message translates to:
  /// **'Clear Email'**
  String get auth_clearEmail;

  /// No description provided for @auth_continueWithoutAccount.
  ///
  /// In en, this message translates to:
  /// **'Continue Without An Account'**
  String get auth_continueWithoutAccount;

  /// No description provided for @auth_continueWithoutAccountNote.
  ///
  /// In en, this message translates to:
  /// **'Your cases stay on this device.'**
  String get auth_continueWithoutAccountNote;

  /// No description provided for @auth_checkEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Check Your Email'**
  String get auth_checkEmailTitle;

  /// AUTH
  ///
  /// In en, this message translates to:
  /// **'We sent a confirmation link to {email}. Open it, then log in.'**
  String auth_checkEmailMessage(String email);

  /// No description provided for @auth_backToLogin.
  ///
  /// In en, this message translates to:
  /// **'Back To Login'**
  String get auth_backToLogin;

  /// No description provided for @auth_useTheApp.
  ///
  /// In en, this message translates to:
  /// **'Use The App'**
  String get auth_useTheApp;

  /// No description provided for @auth_openMail.
  ///
  /// In en, this message translates to:
  /// **'Open Mail'**
  String get auth_openMail;

  /// No description provided for @auth_unableToOpenMail.
  ///
  /// In en, this message translates to:
  /// **'No mail app could be opened.'**
  String get auth_unableToOpenMail;

  /// No description provided for @auth_resendEmail.
  ///
  /// In en, this message translates to:
  /// **'Resend Email'**
  String get auth_resendEmail;

  /// No description provided for @auth_resendSent.
  ///
  /// In en, this message translates to:
  /// **'A new confirmation email has been sent.'**
  String get auth_resendSent;

  /// No description provided for @auth_changeEmail.
  ///
  /// In en, this message translates to:
  /// **'Change Email Address'**
  String get auth_changeEmail;

  /// No description provided for @auth_changeEmailPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Your Password'**
  String get auth_changeEmailPasswordTitle;

  /// No description provided for @auth_changeEmailPasswordPrompt.
  ///
  /// In en, this message translates to:
  /// **'Enter this account\'s password to continue.'**
  String get auth_changeEmailPasswordPrompt;

  /// No description provided for @auth_changeEmailAlreadyConfirmed.
  ///
  /// In en, this message translates to:
  /// **'That address is already confirmed. Log in instead.'**
  String get auth_changeEmailAlreadyConfirmed;

  /// No description provided for @auth_changeEmailRefused.
  ///
  /// In en, this message translates to:
  /// **'That account already has data. Log in and delete it from Settings instead.'**
  String get auth_changeEmailRefused;

  /// No description provided for @auth_emailConfirmedTitle.
  ///
  /// In en, this message translates to:
  /// **'Email Confirmed!'**
  String get auth_emailConfirmedTitle;

  /// AUTH
  ///
  /// In en, this message translates to:
  /// **'Your email address {email} is confirmed. You can use the app now.'**
  String auth_emailConfirmedMessage(String email);

  /// No description provided for @auth_forgotTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get auth_forgotTitle;

  /// No description provided for @auth_forgotSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your email and we will send a recovery code.'**
  String get auth_forgotSubtitle;

  /// No description provided for @auth_recoveryLinkSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a new password for your account.'**
  String get auth_recoveryLinkSubtitle;

  /// No description provided for @auth_sendCodeButton.
  ///
  /// In en, this message translates to:
  /// **'Send Code'**
  String get auth_sendCodeButton;

  /// No description provided for @auth_recoveryCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Recovery Code'**
  String get auth_recoveryCodeLabel;

  /// No description provided for @auth_recoveryCodeHelper.
  ///
  /// In en, this message translates to:
  /// **'Open the code we emailed you, then choose a new password.'**
  String get auth_recoveryCodeHelper;

  /// No description provided for @auth_recoverySent.
  ///
  /// In en, this message translates to:
  /// **'Code Sent'**
  String get auth_recoverySent;

  /// No description provided for @auth_newPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get auth_newPasswordLabel;

  /// No description provided for @auth_setPasswordButton.
  ///
  /// In en, this message translates to:
  /// **'Set New Password'**
  String get auth_setPasswordButton;

  /// No description provided for @auth_passwordUpdated.
  ///
  /// In en, this message translates to:
  /// **'Your password has been updated.'**
  String get auth_passwordUpdated;

  /// No description provided for @auth_errorInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Wrong email or password. Please try again.'**
  String get auth_errorInvalidCredentials;

  /// No description provided for @auth_errorEmailNotConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirm your email address first — open the link we sent you.'**
  String get auth_errorEmailNotConfirmed;

  /// No description provided for @auth_errorEmailInUse.
  ///
  /// In en, this message translates to:
  /// **'That email already has an account. Log in instead.'**
  String get auth_errorEmailInUse;

  /// No description provided for @auth_errorWeakPassword.
  ///
  /// In en, this message translates to:
  /// **'Choose a password with at least 8 characters.'**
  String get auth_errorWeakPassword;

  /// No description provided for @auth_errorRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please wait a few minutes and try again.'**
  String get auth_errorRateLimited;

  /// No description provided for @auth_errorInvalidCode.
  ///
  /// In en, this message translates to:
  /// **'That invite code is not valid. Check it with your firm owner.'**
  String get auth_errorInvalidCode;

  /// No description provided for @auth_errorTooManyAttempts.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please try again later.'**
  String get auth_errorTooManyAttempts;

  /// No description provided for @auth_errorFirmAdminOffline.
  ///
  /// In en, this message translates to:
  /// **'Connect to the internet to manage your firm.'**
  String get auth_errorFirmAdminOffline;

  /// No description provided for @auth_errorPremiumRequired.
  ///
  /// In en, this message translates to:
  /// **'Firm mode requires an active premium subscription.'**
  String get auth_errorPremiumRequired;

  /// No description provided for @firm_errorTierRequired.
  ///
  /// In en, this message translates to:
  /// **'Creating a chamber needs the Firm plan. Pro chambers cannot add associates.'**
  String get firm_errorTierRequired;

  /// No description provided for @firm_errorServer.
  ///
  /// In en, this message translates to:
  /// **'The server could not complete that request. Please try again.'**
  String get firm_errorServer;

  /// No description provided for @firm_errorUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'Your account is not allowed to do that.'**
  String get firm_errorUnauthorized;

  /// No description provided for @firm_errorUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Firm management is not available in this build.'**
  String get firm_errorUnavailable;

  /// No description provided for @auth_errorAlreadyMember.
  ///
  /// In en, this message translates to:
  /// **'You are already a member of this firm.'**
  String get auth_errorAlreadyMember;

  /// No description provided for @auth_joinedFirm.
  ///
  /// In en, this message translates to:
  /// **'You have joined the firm.'**
  String get auth_joinedFirm;

  /// No description provided for @auth_errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'No connection. Check your internet and try again.'**
  String get auth_errorNetwork;

  /// No description provided for @auth_errorUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Sign-in is not available in this build.'**
  String get auth_errorUnavailable;

  /// No description provided for @auth_errorGoogleFailed.
  ///
  /// In en, this message translates to:
  /// **'Google Sign-In could not complete. Please try again.'**
  String get auth_errorGoogleFailed;

  /// No description provided for @auth_errorAccountMismatch.
  ///
  /// In en, this message translates to:
  /// **'This device belongs to another account. Log in with that account, or restore a backup.'**
  String get auth_errorAccountMismatch;

  /// No description provided for @auth_errorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get auth_errorUnknown;

  /// No description provided for @auth_errorOwnDiary.
  ///
  /// In en, this message translates to:
  /// **'This account already has its own diary ({cases} cases). An associate\'s diary must be empty — sign up again using a different account with Join Existing Firm, or export your diary and delete this account.'**
  String auth_errorOwnDiary(int cases);

  /// No description provided for @auth_errorOwnDiaryNoCount.
  ///
  /// In en, this message translates to:
  /// **'This account already has its own diary. An associate\'s diary must be empty — sign up again using a different account with Join Existing Firm, or export your diary and delete this account.'**
  String get auth_errorOwnDiaryNoCount;

  /// No description provided for @auth_errorSeatsFull.
  ///
  /// In en, this message translates to:
  /// **'This firm\'s plan has {seats} seats and they are all in use. Ask the owner to remove an associate or sign out one of their own devices.'**
  String auth_errorSeatsFull(int seats);

  /// No description provided for @auth_errorSeatsFullNoCount.
  ///
  /// In en, this message translates to:
  /// **'This firm\'s plan has no free seats. Ask the owner to remove an associate or sign out one of their own devices.'**
  String get auth_errorSeatsFullNoCount;

  /// No description provided for @auth_errorFirmLapsed.
  ///
  /// In en, this message translates to:
  /// **'This firm\'s subscription has ended, so no new associate can join until the owner renews.'**
  String get auth_errorFirmLapsed;

  /// No description provided for @auth_errorAlreadyInFirm.
  ///
  /// In en, this message translates to:
  /// **'You are already in a firm. Ask that firm\'s owner to remove you before joining another.'**
  String get auth_errorAlreadyInFirm;

  /// No description provided for @auth_validationEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your email address.'**
  String get auth_validationEmailRequired;

  /// No description provided for @auth_validationEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get auth_validationEmailInvalid;

  /// No description provided for @auth_validationPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your password.'**
  String get auth_validationPasswordRequired;

  /// No description provided for @auth_validationPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Use at least 8 characters.'**
  String get auth_validationPasswordTooShort;

  /// No description provided for @auth_validationPasswordConfirmRequired.
  ///
  /// In en, this message translates to:
  /// **'Confirm your password.'**
  String get auth_validationPasswordConfirmRequired;

  /// No description provided for @auth_validationPasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Both passwords must match.'**
  String get auth_validationPasswordMismatch;

  /// No description provided for @auth_validationMandatory.
  ///
  /// In en, this message translates to:
  /// **'This field is mandatory.'**
  String get auth_validationMandatory;

  /// No description provided for @auth_validationInviteCodeRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your invite code.'**
  String get auth_validationInviteCodeRequired;

  /// No description provided for @auth_validationTermsRequired.
  ///
  /// In en, this message translates to:
  /// **'Accept the Terms of Service and Privacy Policy to continue.'**
  String get auth_validationTermsRequired;

  /// No description provided for @auth_sessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Your Session Expired. Sign In Again.'**
  String get auth_sessionExpired;

  /// No description provided for @auth_sessionExpiredAction.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get auth_sessionExpiredAction;

  /// No description provided for @manageAssociates_title.
  ///
  /// In en, this message translates to:
  /// **'Manage Firm'**
  String get manageAssociates_title;

  /// No description provided for @manageAssociates_ownerOnly.
  ///
  /// In en, this message translates to:
  /// **'Only the firm owner can manage the firm.'**
  String get manageAssociates_ownerOnly;

  /// No description provided for @manageAssociates_sectionMembers.
  ///
  /// In en, this message translates to:
  /// **'Associates'**
  String get manageAssociates_sectionMembers;

  /// No description provided for @manageAssociates_addAssociate.
  ///
  /// In en, this message translates to:
  /// **'Add Associate'**
  String get manageAssociates_addAssociate;

  /// No description provided for @manageAssociates_noMembers.
  ///
  /// In en, this message translates to:
  /// **'No Associates Yet.'**
  String get manageAssociates_noMembers;

  /// No description provided for @manageAssociates_statusNotSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Not Signed In'**
  String get manageAssociates_statusNotSignedIn;

  /// No description provided for @manageAssociates_signedOutNote.
  ///
  /// In en, this message translates to:
  /// **'This member\'s devices are signed out because the firm had no free slot. Remove them to free the seat, or admit them again when there is room.'**
  String get manageAssociates_signedOutNote;

  /// No description provided for @manageAssociates_capacityAdmit.
  ///
  /// In en, this message translates to:
  /// **'Admit Again'**
  String get manageAssociates_capacityAdmit;

  /// No description provided for @manageAssociates_capacitySignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out Devices'**
  String get manageAssociates_capacitySignOut;

  /// No description provided for @manageAssociates_capacitySignOutBody.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s devices will be signed out, and their unsynced work will be discarded. They stay a member and can be admitted again when there is room.'**
  String manageAssociates_capacitySignOutBody(String name);

  /// No description provided for @manageAssociates_noFreeSlot.
  ///
  /// In en, this message translates to:
  /// **'No free slot: the last slot is for your own device.'**
  String get manageAssociates_noFreeSlot;

  /// No description provided for @manageAssociates_capacitySignedOut.
  ///
  /// In en, this message translates to:
  /// **'Devices Signed Out.'**
  String get manageAssociates_capacitySignedOut;

  /// No description provided for @manageAssociates_capacityAdmitted.
  ///
  /// In en, this message translates to:
  /// **'Member Admitted.'**
  String get manageAssociates_capacityAdmitted;

  /// No description provided for @manageAssociates_unnamedMember.
  ///
  /// In en, this message translates to:
  /// **'Unnamed Member'**
  String get manageAssociates_unnamedMember;

  /// No description provided for @manageAssociates_createFirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Create a Firm'**
  String get manageAssociates_createFirmTitle;

  /// No description provided for @manageAssociates_firmNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Firm Name'**
  String get manageAssociates_firmNameLabel;

  /// No description provided for @manageAssociates_firmNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your chamber or firm name'**
  String get manageAssociates_firmNameHint;

  /// No description provided for @manageAssociates_addLogo.
  ///
  /// In en, this message translates to:
  /// **'Add Logo'**
  String get manageAssociates_addLogo;

  /// No description provided for @manageAssociates_changeLogo.
  ///
  /// In en, this message translates to:
  /// **'Change Logo'**
  String get manageAssociates_changeLogo;

  /// No description provided for @manageAssociates_removeLogo.
  ///
  /// In en, this message translates to:
  /// **'Remove Logo'**
  String get manageAssociates_removeLogo;

  /// No description provided for @manageAssociates_logoNeedsPlan.
  ///
  /// In en, this message translates to:
  /// **'An active chamber plan is needed to change the logo.'**
  String get manageAssociates_logoNeedsPlan;

  /// No description provided for @manageAssociates_createFirm.
  ///
  /// In en, this message translates to:
  /// **'Create Firm'**
  String get manageAssociates_createFirm;

  /// No description provided for @manageAssociates_goPremium.
  ///
  /// In en, this message translates to:
  /// **'Go Premium'**
  String get manageAssociates_goPremium;

  /// No description provided for @manageAssociates_joinFirm.
  ///
  /// In en, this message translates to:
  /// **'Join a Firm'**
  String get manageAssociates_joinFirm;

  /// No description provided for @manageAssociates_joinFirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Join a Firm'**
  String get manageAssociates_joinFirmTitle;

  /// No description provided for @manageAssociates_joinFirmIntro.
  ///
  /// In en, this message translates to:
  /// **'Enter the invitation code provided by your firm owner.'**
  String get manageAssociates_joinFirmIntro;

  /// No description provided for @manageAssociates_joinFirmCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Invitation Code'**
  String get manageAssociates_joinFirmCodeLabel;

  /// No description provided for @manageAssociates_joinFirmSend.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get manageAssociates_joinFirmSend;

  /// No description provided for @manageAssociates_joinFirmPlanTitle.
  ///
  /// In en, this message translates to:
  /// **'Join a Firm?'**
  String get manageAssociates_joinFirmPlanTitle;

  /// No description provided for @manageAssociates_joinFirmPlanBody.
  ///
  /// In en, this message translates to:
  /// **'Your individual plan will not be paused. While you are in the firm, the firm\'s plan covers your access, and the paid time on your own plan stays with your account and applies again if you leave the firm.'**
  String get manageAssociates_joinFirmPlanBody;

  /// No description provided for @manageAssociates_joinFirmContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get manageAssociates_joinFirmContinue;

  /// No description provided for @manageAssociates_changeName.
  ///
  /// In en, this message translates to:
  /// **'Change Firm Name'**
  String get manageAssociates_changeName;

  /// No description provided for @manageAssociates_changeNameTitle.
  ///
  /// In en, this message translates to:
  /// **'Change Firm Name'**
  String get manageAssociates_changeNameTitle;

  /// No description provided for @manageAssociates_nameUpdated.
  ///
  /// In en, this message translates to:
  /// **'Firm name updated.'**
  String get manageAssociates_nameUpdated;

  /// No description provided for @manageAssociates_inviteTitle.
  ///
  /// In en, this message translates to:
  /// **'Invite Code'**
  String get manageAssociates_inviteTitle;

  /// No description provided for @manageAssociates_inviteIntro.
  ///
  /// In en, this message translates to:
  /// **'Share this code with your associate. It works once, and this is the only time it is shown.'**
  String get manageAssociates_inviteIntro;

  /// No description provided for @manageAssociates_copyCode.
  ///
  /// In en, this message translates to:
  /// **'Copy Code'**
  String get manageAssociates_copyCode;

  /// No description provided for @manageAssociates_codeCopied.
  ///
  /// In en, this message translates to:
  /// **'Code Copied.'**
  String get manageAssociates_codeCopied;

  /// No description provided for @manageAssociates_shareCode.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get manageAssociates_shareCode;

  /// No description provided for @manageAssociates_shareFailed.
  ///
  /// In en, this message translates to:
  /// **'Could Not Share The Code'**
  String get manageAssociates_shareFailed;

  /// No description provided for @manageAssociates_inviteMessage.
  ///
  /// In en, this message translates to:
  /// **'Join my firm on Legal Case Diary. Invite code: {code}'**
  String manageAssociates_inviteMessage(String code);

  /// No description provided for @manageAssociates_sectionInvites.
  ///
  /// In en, this message translates to:
  /// **'Outstanding Invitation Codes'**
  String get manageAssociates_sectionInvites;

  /// No description provided for @manageAssociates_noInvites.
  ///
  /// In en, this message translates to:
  /// **'No unused invites.'**
  String get manageAssociates_noInvites;

  /// No description provided for @manageAssociates_inviteCreated.
  ///
  /// In en, this message translates to:
  /// **'Created {date}'**
  String manageAssociates_inviteCreated(String date);

  /// No description provided for @manageAssociates_revokeInvite.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get manageAssociates_revokeInvite;

  /// No description provided for @manageAssociates_revokeInviteTitle.
  ///
  /// In en, this message translates to:
  /// **'Revoke This Invite?'**
  String get manageAssociates_revokeInviteTitle;

  /// No description provided for @manageAssociates_revokeInviteBody.
  ///
  /// In en, this message translates to:
  /// **'The code will stop working immediately.'**
  String get manageAssociates_revokeInviteBody;

  /// No description provided for @manageAssociates_inviteRevoked.
  ///
  /// In en, this message translates to:
  /// **'Invite Revoked.'**
  String get manageAssociates_inviteRevoked;

  /// No description provided for @manageAssociates_permissionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get manageAssociates_permissionsTitle;

  /// No description provided for @manageAssociates_roleLabel.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get manageAssociates_roleLabel;

  /// No description provided for @manageAssociates_permissionAdd.
  ///
  /// In en, this message translates to:
  /// **'Add Cases, Notes etc'**
  String get manageAssociates_permissionAdd;

  /// No description provided for @manageAssociates_permissionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Cases, Notes etc'**
  String get manageAssociates_permissionEdit;

  /// No description provided for @manageAssociates_permissionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete Cases, Notes etc'**
  String get manageAssociates_permissionDelete;

  /// No description provided for @manageAssociates_savePermissions.
  ///
  /// In en, this message translates to:
  /// **'Save Permissions'**
  String get manageAssociates_savePermissions;

  /// No description provided for @manageAssociates_permissionsUpdated.
  ///
  /// In en, this message translates to:
  /// **'Permissions Updated.'**
  String get manageAssociates_permissionsUpdated;

  /// No description provided for @manageAssociates_removeAssociate.
  ///
  /// In en, this message translates to:
  /// **'Remove from Firm'**
  String get manageAssociates_removeAssociate;

  /// No description provided for @manageAssociates_removeAssociateTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove This Associate?'**
  String get manageAssociates_removeAssociateTitle;

  /// No description provided for @manageAssociates_removeAssociateBody.
  ///
  /// In en, this message translates to:
  /// **'They lose access to the firm\'s cases immediately, and the records they authored stay with the firm. Their phone keeps a copy of the firm until it next opens the app, and erases itself then. If you are still together, have them open the app once while you are connected, so you can see the erase happen. A phone that is never opened again can only be cleared by a factory reset or the platform\'s remote-wipe feature — no app can erase a device that is off.'**
  String get manageAssociates_removeAssociateBody;

  /// No description provided for @manageAssociates_associateRemoved.
  ///
  /// In en, this message translates to:
  /// **'Associate Removed.'**
  String get manageAssociates_associateRemoved;

  /// No description provided for @manageAssociates_sectionFirm.
  ///
  /// In en, this message translates to:
  /// **'Firm Management'**
  String get manageAssociates_sectionFirm;

  /// No description provided for @manageAssociates_dissolveFirm.
  ///
  /// In en, this message translates to:
  /// **'Dissolve Firm'**
  String get manageAssociates_dissolveFirm;

  /// No description provided for @manageAssociates_dissolveIntro.
  ///
  /// In en, this message translates to:
  /// **'Dissolving removes the firm and its invites. Every case, note and reference it holds stays with you as your own diary, and your plan keeps running.'**
  String get manageAssociates_dissolveIntro;

  /// No description provided for @manageAssociates_dissolveBlockedMembers.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{One associate is still in the firm. Remove them first.} other{{count} associates are still in the firm. Remove them first.}}'**
  String manageAssociates_dissolveBlockedMembers(int count);

  /// No description provided for @manageAssociates_dissolveBlockedPending.
  ///
  /// In en, this message translates to:
  /// **'Changes are still waiting to sync. Let them finish, then try again.'**
  String get manageAssociates_dissolveBlockedPending;

  /// No description provided for @manageAssociates_dissolveConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Dissolve This Firm?'**
  String get manageAssociates_dissolveConfirmTitle;

  /// No description provided for @manageAssociates_dissolveConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'The firm and its invites will be removed. Every case, note and reference it holds becomes your own diary, and the associates who wrote them lose access to them. Your plan is not cancelled, and your records keep the name of whoever wrote them. This cannot be undone.'**
  String get manageAssociates_dissolveConfirmBody;

  /// No description provided for @manageAssociates_dissolveDone.
  ///
  /// In en, this message translates to:
  /// **'Firm dissolved. Its cases are now your own diary.'**
  String get manageAssociates_dissolveDone;

  /// No description provided for @manageAssociates_capacityTitle.
  ///
  /// In en, this message translates to:
  /// **'Device Usage'**
  String get manageAssociates_capacityTitle;

  /// No description provided for @manageAssociates_inviteCodeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Code not available on this device.'**
  String get manageAssociates_inviteCodeUnavailable;

  /// No description provided for @manageAssociates_firmOverviewTitle.
  ///
  /// In en, this message translates to:
  /// **'What Is a Firm?'**
  String get manageAssociates_firmOverviewTitle;

  /// No description provided for @manageAssociates_firmOverviewCollaborateTitle.
  ///
  /// In en, this message translates to:
  /// **'Collaborate with Your Associates'**
  String get manageAssociates_firmOverviewCollaborateTitle;

  /// No description provided for @manageAssociates_firmOverviewCollaborateBody.
  ///
  /// In en, this message translates to:
  /// **'Share your diary with your associates so they can add cases, update court dates, and maintain your diary on your behalf — allowing you to focus on more pressing matters.'**
  String get manageAssociates_firmOverviewCollaborateBody;

  /// No description provided for @manageAssociates_firmOverviewDevicesTitle.
  ///
  /// In en, this message translates to:
  /// **'Multi-device Access'**
  String get manageAssociates_firmOverviewDevicesTitle;

  /// No description provided for @manageAssociates_firmOverviewDevicesBody.
  ///
  /// In en, this message translates to:
  /// **'Depending on your subscribed firm plan, access your diary on 5–20 devices and invite associates up to your plan\'s limit.'**
  String get manageAssociates_firmOverviewDevicesBody;

  /// No description provided for @manageAssociates_firmOverviewBackupTitle.
  ///
  /// In en, this message translates to:
  /// **'Cloud Backup and Offline Access'**
  String get manageAssociates_firmOverviewBackupTitle;

  /// No description provided for @manageAssociates_firmOverviewBackupBody.
  ///
  /// In en, this message translates to:
  /// **'Enjoy real-time cloud backup while retaining the ability to use your diary offline.'**
  String get manageAssociates_firmOverviewBackupBody;

  /// No description provided for @manageAssociates_firmOverviewReadyTitle.
  ///
  /// In en, this message translates to:
  /// **'Ready to Create Your Firm?'**
  String get manageAssociates_firmOverviewReadyTitle;

  /// No description provided for @manageAssociates_firmOverviewReadyPrefix.
  ///
  /// In en, this message translates to:
  /// **'Choose a firm plan from the'**
  String get manageAssociates_firmOverviewReadyPrefix;

  /// No description provided for @manageAssociates_firmOverviewReadySuffix.
  ///
  /// In en, this message translates to:
  /// **'page to create your firm and invite your first associate.'**
  String get manageAssociates_firmOverviewReadySuffix;

  /// No description provided for @syncNotice_permissionsChanged.
  ///
  /// In en, this message translates to:
  /// **'Your firm permissions changed; this pending action was not applied.'**
  String get syncNotice_permissionsChanged;

  /// No description provided for @syncNotice_clockSkew.
  ///
  /// In en, this message translates to:
  /// **'Your device clock is more than two minutes off from the server. Synced times may be wrong.'**
  String get syncNotice_clockSkew;

  /// No description provided for @membershipRevoked_title.
  ///
  /// In en, this message translates to:
  /// **'Your Access Ended'**
  String get membershipRevoked_title;

  /// No description provided for @membershipRevoked_body.
  ///
  /// In en, this message translates to:
  /// **'The firm owner removed this account. Everything the firm had on this device — its cases, notes, references, roster and pending work — has already been erased, and work that was still waiting to sync was discarded rather than sent. Your own records are safe with the firm. You can use this account again for an individual diary, or join another firm. If this phone had already been removed while it was switched off, this is the erase running now, the first time it was opened.'**
  String get membershipRevoked_body;

  /// No description provided for @membershipRevoked_eraseFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not finish erasing this device.'**
  String get membershipRevoked_eraseFailed;

  /// No description provided for @membershipRevoked_retry.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get membershipRevoked_retry;

  /// No description provided for @deleteRequest_confirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Request Deletion'**
  String get deleteRequest_confirmTitle;

  /// No description provided for @deleteRequest_confirmBody.
  ///
  /// In en, this message translates to:
  /// **'A firm member with delete permission has to approve it before the record is removed.'**
  String get deleteRequest_confirmBody;

  /// No description provided for @deleteRequest_confirmSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get deleteRequest_confirmSend;

  /// No description provided for @deleteRequest_sent.
  ///
  /// In en, this message translates to:
  /// **'Deletion request sent for approval.'**
  String get deleteRequest_sent;

  /// No description provided for @deleteRequest_failed.
  ///
  /// In en, this message translates to:
  /// **'Could not send the deletion request.'**
  String get deleteRequest_failed;

  /// No description provided for @deleteRequest_alreadyOpen.
  ///
  /// In en, this message translates to:
  /// **'A deletion request for this record is already open.'**
  String get deleteRequest_alreadyOpen;

  /// No description provided for @deleteRequests_title.
  ///
  /// In en, this message translates to:
  /// **'Delete Requests'**
  String get deleteRequests_title;

  /// No description provided for @deleteRequests_firmOnly.
  ///
  /// In en, this message translates to:
  /// **'Delete requests are only available to firm members.'**
  String get deleteRequests_firmOnly;

  /// No description provided for @deleteRequests_toReview.
  ///
  /// In en, this message translates to:
  /// **'Awaiting Your Review'**
  String get deleteRequests_toReview;

  /// No description provided for @deleteRequests_noneToReview.
  ///
  /// In en, this message translates to:
  /// **'No deletion requests awaiting review.'**
  String get deleteRequests_noneToReview;

  /// No description provided for @deleteRequests_previous.
  ///
  /// In en, this message translates to:
  /// **'Previous Delete Requests'**
  String get deleteRequests_previous;

  /// No description provided for @deleteRequests_clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get deleteRequests_clear;

  /// No description provided for @deleteRequests_clearSelected.
  ///
  /// In en, this message translates to:
  /// **'Clear Selected'**
  String get deleteRequests_clearSelected;

  /// No description provided for @deleteRequests_mine.
  ///
  /// In en, this message translates to:
  /// **'My Requests'**
  String get deleteRequests_mine;

  /// No description provided for @deleteRequests_noneMine.
  ///
  /// In en, this message translates to:
  /// **'You have not sent any deletion requests.'**
  String get deleteRequests_noneMine;

  /// No description provided for @deleteRequests_statusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get deleteRequests_statusPending;

  /// No description provided for @deleteRequests_statusApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get deleteRequests_statusApproved;

  /// No description provided for @deleteRequests_statusRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get deleteRequests_statusRejected;

  /// No description provided for @deleteRequests_statusStale.
  ///
  /// In en, this message translates to:
  /// **'Needs Reconfirmation'**
  String get deleteRequests_statusStale;

  /// No description provided for @deleteRequests_statusAlreadyDeleted.
  ///
  /// In en, this message translates to:
  /// **'Already Deleted'**
  String get deleteRequests_statusAlreadyDeleted;

  /// No description provided for @deleteRequests_requestedBy.
  ///
  /// In en, this message translates to:
  /// **'Requested by: {name}'**
  String deleteRequests_requestedBy(String name);

  /// No description provided for @deleteRequests_requestedOn.
  ///
  /// In en, this message translates to:
  /// **'Requested on: {date}'**
  String deleteRequests_requestedOn(String date);

  /// No description provided for @deleteRequests_unnamed.
  ///
  /// In en, this message translates to:
  /// **'A Record'**
  String get deleteRequests_unnamed;

  /// No description provided for @deleteRequests_entityCase.
  ///
  /// In en, this message translates to:
  /// **'Case'**
  String get deleteRequests_entityCase;

  /// No description provided for @deleteRequests_entityCaseHistory.
  ///
  /// In en, this message translates to:
  /// **'Case History'**
  String get deleteRequests_entityCaseHistory;

  /// No description provided for @deleteRequests_entityNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get deleteRequests_entityNote;

  /// No description provided for @deleteRequests_entityReference.
  ///
  /// In en, this message translates to:
  /// **'Reference'**
  String get deleteRequests_entityReference;

  /// No description provided for @deleteRequests_entityUnknown.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get deleteRequests_entityUnknown;

  /// No description provided for @deleteRequests_reviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Review Deletion Request'**
  String get deleteRequests_reviewTitle;

  /// No description provided for @deleteRequests_snapshot.
  ///
  /// In en, this message translates to:
  /// **'Requested Record'**
  String get deleteRequests_snapshot;

  /// No description provided for @deleteRequests_noteLabel.
  ///
  /// In en, this message translates to:
  /// **'Review Note (Optional)'**
  String get deleteRequests_noteLabel;

  /// No description provided for @deleteRequests_noteHint.
  ///
  /// In en, this message translates to:
  /// **'Add A Reason'**
  String get deleteRequests_noteHint;

  /// No description provided for @deleteRequests_noteClearText.
  ///
  /// In en, this message translates to:
  /// **'Clear texts'**
  String get deleteRequests_noteClearText;

  /// No description provided for @deleteRequests_approve.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get deleteRequests_approve;

  /// No description provided for @deleteRequests_reject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get deleteRequests_reject;

  /// No description provided for @deleteRequests_approveTitle.
  ///
  /// In en, this message translates to:
  /// **'Approve Deletion?'**
  String get deleteRequests_approveTitle;

  /// No description provided for @deleteRequests_approveBody.
  ///
  /// In en, this message translates to:
  /// **'The record will be deleted for everyone in the firm.'**
  String get deleteRequests_approveBody;

  /// No description provided for @deleteRequests_rejectTitle.
  ///
  /// In en, this message translates to:
  /// **'Reject Deletion Request?'**
  String get deleteRequests_rejectTitle;

  /// No description provided for @deleteRequests_rejectBody.
  ///
  /// In en, this message translates to:
  /// **'The record stays. The requester is told your decision.'**
  String get deleteRequests_rejectBody;

  /// No description provided for @deleteRequests_approved.
  ///
  /// In en, this message translates to:
  /// **'Deletion Approved.'**
  String get deleteRequests_approved;

  /// No description provided for @deleteRequests_rejected.
  ///
  /// In en, this message translates to:
  /// **'Deletion Request Rejected.'**
  String get deleteRequests_rejected;

  /// No description provided for @deleteRequests_failed.
  ///
  /// In en, this message translates to:
  /// **'Could not complete the review. Try again.'**
  String get deleteRequests_failed;

  /// No description provided for @deleteRequests_staleTitle.
  ///
  /// In en, this message translates to:
  /// **'This record changed'**
  String get deleteRequests_staleTitle;

  /// No description provided for @deleteRequests_staleBody.
  ///
  /// In en, this message translates to:
  /// **'It changed after the request was made. Approve to delete the version that exists now.'**
  String get deleteRequests_staleBody;

  /// No description provided for @deleteRequests_current.
  ///
  /// In en, this message translates to:
  /// **'As It Is Now'**
  String get deleteRequests_current;

  /// No description provided for @deleteRequests_original.
  ///
  /// In en, this message translates to:
  /// **'When the Request Was Made'**
  String get deleteRequests_original;

  /// No description provided for @deleteRequests_changed.
  ///
  /// In en, this message translates to:
  /// **'Changed'**
  String get deleteRequests_changed;

  /// No description provided for @deleteRequests_editWarnTitle.
  ///
  /// In en, this message translates to:
  /// **'Requested for Deletion'**
  String get deleteRequests_editWarnTitle;

  /// No description provided for @deleteRequests_editWarnBody.
  ///
  /// In en, this message translates to:
  /// **'{name} asked to delete this record on {date}. If you change it now, that request will have to be confirmed again.'**
  String deleteRequests_editWarnBody(String name, String date);

  /// No description provided for @deleteRequests_editWarnOwnBody.
  ///
  /// In en, this message translates to:
  /// **'You asked to delete this record on {date}. If you change it now, that request will have to be confirmed again.'**
  String deleteRequests_editWarnOwnBody(String date);

  /// No description provided for @deleteRequests_editWarnContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue Editing'**
  String get deleteRequests_editWarnContinue;

  /// No description provided for @deleteRequests_fieldCaseNumber.
  ///
  /// In en, this message translates to:
  /// **'Case Number'**
  String get deleteRequests_fieldCaseNumber;

  /// No description provided for @deleteRequests_fieldCaseType.
  ///
  /// In en, this message translates to:
  /// **'Case Type'**
  String get deleteRequests_fieldCaseType;

  /// No description provided for @deleteRequests_fieldPetitioner.
  ///
  /// In en, this message translates to:
  /// **'Petitioner'**
  String get deleteRequests_fieldPetitioner;

  /// No description provided for @deleteRequests_fieldRespondent.
  ///
  /// In en, this message translates to:
  /// **'Respondent'**
  String get deleteRequests_fieldRespondent;

  /// No description provided for @deleteRequests_fieldStep.
  ///
  /// In en, this message translates to:
  /// **'Step'**
  String get deleteRequests_fieldStep;

  /// No description provided for @deleteRequests_fieldResult.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get deleteRequests_fieldResult;

  /// No description provided for @deleteRequests_fieldTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get deleteRequests_fieldTitle;

  /// No description provided for @deleteRequests_fieldBody.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get deleteRequests_fieldBody;

  /// No description provided for @deleteRequests_fieldReference.
  ///
  /// In en, this message translates to:
  /// **'Reference And Page No'**
  String get deleteRequests_fieldReference;

  /// No description provided for @deleteRequests_fieldDescription.
  ///
  /// In en, this message translates to:
  /// **'Title And Description'**
  String get deleteRequests_fieldDescription;

  /// No description provided for @deleteRequests_unknownRequester.
  ///
  /// In en, this message translates to:
  /// **'A Firm Member'**
  String get deleteRequests_unknownRequester;

  /// No description provided for @deleteRequests_withdraw.
  ///
  /// In en, this message translates to:
  /// **'Withdraw Request'**
  String get deleteRequests_withdraw;

  /// No description provided for @deleteRequests_withdrawTitle.
  ///
  /// In en, this message translates to:
  /// **'Withdraw This Deletion Request?'**
  String get deleteRequests_withdrawTitle;

  /// No description provided for @deleteRequests_withdrawBody.
  ///
  /// In en, this message translates to:
  /// **'The record will not be deleted, and the request leaves the reviewers\' queue.'**
  String get deleteRequests_withdrawBody;

  /// No description provided for @deleteRequests_withdrawn.
  ///
  /// In en, this message translates to:
  /// **'Request Withdrawn.'**
  String get deleteRequests_withdrawn;

  /// No description provided for @deleteRequests_withdrawFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not withdraw the request.'**
  String get deleteRequests_withdrawFailed;

  /// No description provided for @payments_goPremium.
  ///
  /// In en, this message translates to:
  /// **'Go Premium'**
  String get payments_goPremium;

  /// No description provided for @payments_checkoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Checkout'**
  String get payments_checkoutTitle;

  /// No description provided for @payments_planSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get payments_planSummaryTitle;

  /// No description provided for @payments_amountValue.
  ///
  /// In en, this message translates to:
  /// **'৳{amount}'**
  String payments_amountValue(String amount);

  /// No description provided for @payments_transferTitle.
  ///
  /// In en, this message translates to:
  /// **'Transfer Instructions'**
  String get payments_transferTitle;

  /// No description provided for @payments_transferBody.
  ///
  /// In en, this message translates to:
  /// **'Send ৳{amount} to one of the numbers below using {sendMoney}, then carefully enter your payment details.'**
  String payments_transferBody(String amount, String sendMoney);

  /// No description provided for @payments_sendMoney.
  ///
  /// In en, this message translates to:
  /// **'Send Money'**
  String get payments_sendMoney;

  /// No description provided for @payments_copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get payments_copy;

  /// No description provided for @payments_copied.
  ///
  /// In en, this message translates to:
  /// **'Number Copied.'**
  String get payments_copied;

  /// No description provided for @payments_formTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment Details'**
  String get payments_formTitle;

  /// No description provided for @payments_methodLabel.
  ///
  /// In en, this message translates to:
  /// **'Payment Method'**
  String get payments_methodLabel;

  /// No description provided for @payments_methodBkash.
  ///
  /// In en, this message translates to:
  /// **'bKash'**
  String get payments_methodBkash;

  /// No description provided for @payments_methodNagad.
  ///
  /// In en, this message translates to:
  /// **'Nagad'**
  String get payments_methodNagad;

  /// No description provided for @payments_methodRocket.
  ///
  /// In en, this message translates to:
  /// **'Rocket'**
  String get payments_methodRocket;

  /// No description provided for @payments_phoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Sender Phone Number'**
  String get payments_phoneLabel;

  /// No description provided for @payments_phoneHint.
  ///
  /// In en, this message translates to:
  /// **'01XXXXXXXXX'**
  String get payments_phoneHint;

  /// No description provided for @payments_trxLabel.
  ///
  /// In en, this message translates to:
  /// **'Transaction ID (TrxID)'**
  String get payments_trxLabel;

  /// No description provided for @payments_trxHint.
  ///
  /// In en, this message translates to:
  /// **'Enter The TrxID'**
  String get payments_trxHint;

  /// No description provided for @payments_submit.
  ///
  /// In en, this message translates to:
  /// **'Submit Payment'**
  String get payments_submit;

  /// No description provided for @payments_numberUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Payment numbers are unavailable right now. Please try again later.'**
  String get payments_numberUnavailable;

  /// No description provided for @payments_errorPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid mobile number.'**
  String get payments_errorPhone;

  /// No description provided for @payments_errorTrx.
  ///
  /// In en, this message translates to:
  /// **'Enter the transaction ID.'**
  String get payments_errorTrx;

  /// No description provided for @payments_submitFailed.
  ///
  /// In en, this message translates to:
  /// **'Submission failed. Tap Retry.'**
  String get payments_submitFailed;

  /// No description provided for @payments_limitReached.
  ///
  /// In en, this message translates to:
  /// **'You\'ve reached today\'s submission limit. Please try again tomorrow.'**
  String get payments_limitReached;

  /// No description provided for @payments_duplicateTrx.
  ///
  /// In en, this message translates to:
  /// **'This transaction ID has already been submitted.'**
  String get payments_duplicateTrx;

  /// No description provided for @payments_submitSuccess.
  ///
  /// In en, this message translates to:
  /// **'Submission received. We will verify it shortly.'**
  String get payments_submitSuccess;

  /// No description provided for @payments_historyTitle.
  ///
  /// In en, this message translates to:
  /// **'Subscription History'**
  String get payments_historyTitle;

  /// No description provided for @payments_noSubmissions.
  ///
  /// In en, this message translates to:
  /// **'No subscription history yet.'**
  String get payments_noSubmissions;

  /// No description provided for @payments_statusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get payments_statusPending;

  /// No description provided for @payments_statusApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get payments_statusApproved;

  /// No description provided for @payments_statusRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get payments_statusRejected;

  /// No description provided for @payments_statusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get payments_statusCancelled;

  /// No description provided for @payments_cancelPlan.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get payments_cancelPlan;

  /// No description provided for @payments_cancelTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel Subscription?'**
  String get payments_cancelTitle;

  /// No description provided for @payments_cancelWarning.
  ///
  /// In en, this message translates to:
  /// **'A cancelled plan cannot be restored. Your account will move to Limited Access and keep only its reduced allowance until you buy another plan.'**
  String get payments_cancelWarning;

  /// No description provided for @payments_goBack.
  ///
  /// In en, this message translates to:
  /// **'Go Back'**
  String get payments_goBack;

  /// No description provided for @payments_confirmCancellation.
  ///
  /// In en, this message translates to:
  /// **'Confirm Cancellation'**
  String get payments_confirmCancellation;

  /// No description provided for @payments_cancelFailed.
  ///
  /// In en, this message translates to:
  /// **'The subscription could not be cancelled. Please try again.'**
  String get payments_cancelFailed;

  /// No description provided for @payments_cancelNoActivePlan.
  ///
  /// In en, this message translates to:
  /// **'There is no active plan to cancel.'**
  String get payments_cancelNoActivePlan;

  /// No description provided for @payments_cancelFirmMember.
  ///
  /// In en, this message translates to:
  /// **'This plan belongs to the firm. Only the firm owner can cancel it.'**
  String get payments_cancelFirmMember;

  /// No description provided for @payments_notesLabel.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get payments_notesLabel;

  /// Pre-expiry banner for an individual or a firm owner. 'days' arrives already written in the active language's digits.
  ///
  /// In en, this message translates to:
  /// **'Your subscription ends in {days} days, on {date}. Renew to keep syncing.'**
  String subscription_bannerEnding(String days, String date);

  /// Pre-expiry banner on the plan's last day; the 'two days or more' wording would read badly here.
  ///
  /// In en, this message translates to:
  /// **'Your subscription ends on {date}. Renew to keep syncing.'**
  String subscription_bannerEndingLastDay(String date);

  /// Pre-expiry banner for a firm member: the plan is the chamber's, so only the owner can pay.
  ///
  /// In en, this message translates to:
  /// **'Your firm\'s plan ends in {days} days, on {date}. Ask your firm owner to renew.'**
  String subscription_bannerEndingAssociate(String days, String date);

  /// Pre-expiry banner for a firm member on the plan's last day.
  ///
  /// In en, this message translates to:
  /// **'Your firm\'s plan ends on {date}. Ask your firm owner to renew.'**
  String subscription_bannerEndingAssociateLastDay(String date);

  /// No description provided for @subscription_reminderChannelName.
  ///
  /// In en, this message translates to:
  /// **'Subscription Reminders'**
  String get subscription_reminderChannelName;

  /// No description provided for @subscription_reminderChannelDescription.
  ///
  /// In en, this message translates to:
  /// **'Warnings before a paid plan ends'**
  String get subscription_reminderChannelDescription;

  /// No description provided for @subscription_reminderTitle.
  ///
  /// In en, this message translates to:
  /// **'Subscription Ending Soon'**
  String get subscription_reminderTitle;

  /// Phone reminder for an individual or a firm owner, posted seven and three days before the end date. 'days' arrives already written in the active language's digits.
  ///
  /// In en, this message translates to:
  /// **'Your subscription ends in {days} days, on {date}. Renew to keep syncing.'**
  String subscription_reminderBody(String days, String date);

  /// Phone reminder for a firm member, posted seven and three days before the chamber's plan ends.
  ///
  /// In en, this message translates to:
  /// **'Your firm\'s plan ends in {days} days, on {date}. Ask your firm owner to renew.'**
  String subscription_reminderBodyAssociate(String days, String date);

  /// No description provided for @subscription_bannerGrace.
  ///
  /// In en, this message translates to:
  /// **'Your subscription expired. Renew to avoid losing sync access.'**
  String get subscription_bannerGrace;

  /// No description provided for @subscription_bannerGraceCountdown.
  ///
  /// In en, this message translates to:
  /// **'Sync stops in {time}.'**
  String subscription_bannerGraceCountdown(String time);

  /// No description provided for @subscription_bannerExpiredOwner.
  ///
  /// In en, this message translates to:
  /// **'Your premium subscription has ended. Renew your subscription to restore sync.'**
  String get subscription_bannerExpiredOwner;

  /// No description provided for @subscription_bannerExpiredAssociate.
  ///
  /// In en, this message translates to:
  /// **'Your firm\'s premium subscription has ended. Contact your firm owner to renew.'**
  String get subscription_bannerExpiredAssociate;

  /// No description provided for @settingsManageAccount_plan.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get settingsManageAccount_plan;

  /// No description provided for @settingsManageAccount_expiry.
  ///
  /// In en, this message translates to:
  /// **'Expiry'**
  String get settingsManageAccount_expiry;

  /// No description provided for @settingsDiagnostics_title.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get settingsDiagnostics_title;

  /// No description provided for @settingsDiagnostics_reportBug.
  ///
  /// In en, this message translates to:
  /// **'Report Error Or Bug'**
  String get settingsDiagnostics_reportBug;

  /// No description provided for @settingsDiagnostics_reportBugTitle.
  ///
  /// In en, this message translates to:
  /// **'How Would You Like To Send It?'**
  String get settingsDiagnostics_reportBugTitle;

  /// No description provided for @settingsDiagnostics_reportBugBody.
  ///
  /// In en, this message translates to:
  /// **'The message includes your app version, phone and the error log below, so nothing else needs to be attached.'**
  String get settingsDiagnostics_reportBugBody;

  /// No description provided for @settingsDiagnostics_hint.
  ///
  /// In en, this message translates to:
  /// **'Errors this app has recorded. Case data, passwords and tokens are never written here.'**
  String get settingsDiagnostics_hint;

  /// No description provided for @settingsDiagnostics_empty.
  ///
  /// In en, this message translates to:
  /// **'No errors have been recorded.'**
  String get settingsDiagnostics_empty;

  /// No description provided for @settingsDiagnostics_clear.
  ///
  /// In en, this message translates to:
  /// **'Clear Log'**
  String get settingsDiagnostics_clear;

  /// No description provided for @settingsDiagnostics_cleared.
  ///
  /// In en, this message translates to:
  /// **'Error Log Cleared.'**
  String get settingsDiagnostics_cleared;

  /// No description provided for @settingsDiagnostics_copy.
  ///
  /// In en, this message translates to:
  /// **'Copy Diagnostics'**
  String get settingsDiagnostics_copy;

  /// No description provided for @settingsDiagnostics_copied.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics copied. Paste them into a message to us.'**
  String get settingsDiagnostics_copied;

  /// No description provided for @settingsAppLock_title.
  ///
  /// In en, this message translates to:
  /// **'App Lock'**
  String get settingsAppLock_title;

  /// No description provided for @settingsAppLock_setup.
  ///
  /// In en, this message translates to:
  /// **'Setup App Lock'**
  String get settingsAppLock_setup;

  /// No description provided for @settingsAppLock_changePin.
  ///
  /// In en, this message translates to:
  /// **'Change App Lock PIN'**
  String get settingsAppLock_changePin;

  /// No description provided for @settingsAppLock_enableFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Enable Fingerprint'**
  String get settingsAppLock_enableFingerprint;

  /// No description provided for @settingsAppLock_disableFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Disable Fingerprint'**
  String get settingsAppLock_disableFingerprint;

  /// No description provided for @settingsAppLock_whenToAsk.
  ///
  /// In en, this message translates to:
  /// **'When to Ask for PIN'**
  String get settingsAppLock_whenToAsk;

  /// No description provided for @settingsAppLock_whenAppStarts.
  ///
  /// In en, this message translates to:
  /// **'When the App Starts'**
  String get settingsAppLock_whenAppStarts;

  /// No description provided for @settingsAppLock_whenAppOpensAndReturns.
  ///
  /// In en, this message translates to:
  /// **'Every Time the App Opens'**
  String get settingsAppLock_whenAppOpensAndReturns;

  /// Title of the pin-pad dialog's first step; digits is the pin length in the active language.
  ///
  /// In en, this message translates to:
  /// **'Choose A {digits}-Digit PIN'**
  String settingsAppLock_choosePin(String digits);

  /// No description provided for @settingsAppLock_confirmPin.
  ///
  /// In en, this message translates to:
  /// **'Confirm Your PIN'**
  String get settingsAppLock_confirmPin;

  /// No description provided for @settingsAppLock_pinMismatch.
  ///
  /// In en, this message translates to:
  /// **'The PINs do not match. Start again.'**
  String get settingsAppLock_pinMismatch;

  /// No description provided for @settingsAppLock_setupDone.
  ///
  /// In en, this message translates to:
  /// **'App Lock is on.'**
  String get settingsAppLock_setupDone;

  /// No description provided for @settingsAppLock_setupFailed.
  ///
  /// In en, this message translates to:
  /// **'The PIN could not be saved. Try again.'**
  String get settingsAppLock_setupFailed;

  /// No description provided for @settingsAppLock_enterCurrentPin.
  ///
  /// In en, this message translates to:
  /// **'Enter Your Current PIN'**
  String get settingsAppLock_enterCurrentPin;

  /// No description provided for @settingsAppLock_newPin.
  ///
  /// In en, this message translates to:
  /// **'Enter A New PIN'**
  String get settingsAppLock_newPin;

  /// No description provided for @settingsAppLock_pinChanged.
  ///
  /// In en, this message translates to:
  /// **'App Lock PIN changed.'**
  String get settingsAppLock_pinChanged;

  /// No description provided for @settingsAppLock_currentPinWrong.
  ///
  /// In en, this message translates to:
  /// **'That PIN is not correct.'**
  String get settingsAppLock_currentPinWrong;

  /// No description provided for @settingsAppLock_unlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter Your PIN To Unlock'**
  String get settingsAppLock_unlockTitle;

  /// No description provided for @settingsAppLock_wrongPin.
  ///
  /// In en, this message translates to:
  /// **'Wrong PIN. Try Again.'**
  String get settingsAppLock_wrongPin;

  /// Shown while a wrong-pin lockout is still running; seconds is pre-formatted in the active language.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again in {seconds} seconds.'**
  String settingsAppLock_tooManyAttempts(String seconds);

  /// No description provided for @settingsAppLock_verifyForFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Verify Your Identity For App Lock'**
  String get settingsAppLock_verifyForFingerprint;

  /// No description provided for @settingsAppLock_fingerprintEnabled.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint Unlock Enabled.'**
  String get settingsAppLock_fingerprintEnabled;

  /// No description provided for @settingsAppLock_fingerprintDisabled.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint Unlock Disabled.'**
  String get settingsAppLock_fingerprintDisabled;

  /// No description provided for @settingsAppLock_fingerprintUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No fingerprint is available on this device.'**
  String get settingsAppLock_fingerprintUnavailable;

  /// No description provided for @settingsAppLock_useFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Unlock With Fingerprint'**
  String get settingsAppLock_useFingerprint;

  /// No description provided for @settingsAppLock_turnOff.
  ///
  /// In en, this message translates to:
  /// **'Turn Off App Lock'**
  String get settingsAppLock_turnOff;

  /// No description provided for @settingsAppLock_turnOffTitle.
  ///
  /// In en, this message translates to:
  /// **'Turn Off App Lock?'**
  String get settingsAppLock_turnOffTitle;

  /// No description provided for @settingsAppLock_turnOffBody.
  ///
  /// In en, this message translates to:
  /// **'The app will open without a PIN or fingerprint until you set App Lock up again.'**
  String get settingsAppLock_turnOffBody;

  /// No description provided for @settingsAppLock_turnOffConfirm.
  ///
  /// In en, this message translates to:
  /// **'Turn Off'**
  String get settingsAppLock_turnOffConfirm;

  /// No description provided for @settingsAppLock_turnedOff.
  ///
  /// In en, this message translates to:
  /// **'App Lock Is Off.'**
  String get settingsAppLock_turnedOff;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['bn', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'bn':
      return AppLocalizationsBn();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
