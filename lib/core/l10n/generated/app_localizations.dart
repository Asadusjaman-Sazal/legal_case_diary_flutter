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

  /// No description provided for @allCasesScreen_title.
  ///
  /// In en, this message translates to:
  /// **'All Cases'**
  String get allCasesScreen_title;

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

  /// No description provided for @activeCasesScreen_title.
  ///
  /// In en, this message translates to:
  /// **'Active Cases'**
  String get activeCasesScreen_title;

  /// No description provided for @upcomingCasesScreen_title.
  ///
  /// In en, this message translates to:
  /// **'Upcoming Cases'**
  String get upcomingCasesScreen_title;

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

  /// Button revealing all case history entries.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{View All {count} History Entry} other{View All {count} History Entries}}'**
  String caseDetailsScreen_viewAllHistory(int count);

  /// Countdown shown on the Next Date highlight card.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{0 Days Remaining} =1{1 Day Remaining} other{{count} Days Remaining}}'**
  String caseDetailsScreen_daysRemaining(int count);

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

  /// No description provided for @addEditCaseSheet_offsetDaysBefore.
  ///
  /// In en, this message translates to:
  /// **'Before {count} days'**
  String addEditCaseSheet_offsetDaysBefore(Object count);

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
  /// **'Compact view'**
  String get casesModal_viewCompact;

  /// No description provided for @casesModal_viewExpanded.
  ///
  /// In en, this message translates to:
  /// **'Expanded view'**
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
  /// **'Available after sign-in (Task 17)'**
  String get sharedMessages_signInRequired;

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

  /// SMS sent to clients about an upcoming hearing.
  ///
  /// In en, this message translates to:
  /// **'Dear {clientName}, your case {caseNumber} is scheduled for hearing on {nextDate}. Please contact us if you have any questions.'**
  String messageTemplate_clientSms(
    String clientName,
    String caseNumber,
    String nextDate,
  );

  /// WhatsApp template sent to clients about an upcoming hearing.
  ///
  /// In en, this message translates to:
  /// **'Dear {clientName}, your case {caseNumber} is scheduled for hearing on {nextDate}. Please contact us if you have any questions.'**
  String messageTemplate_clientWhatsApp(
    String clientName,
    String caseNumber,
    String nextDate,
  );

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

  /// No description provided for @settingsScreen_viewSettings.
  ///
  /// In en, this message translates to:
  /// **'View Settings'**
  String get settingsScreen_viewSettings;

  /// No description provided for @settingsScreen_guidelines.
  ///
  /// In en, this message translates to:
  /// **'Guidelines'**
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
  /// **'Search settings'**
  String get settingsScreen_searchTooltip;

  /// No description provided for @settingsScreen_searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get settingsScreen_searchHint;

  /// No description provided for @settingsScreen_closeSearchTooltip.
  ///
  /// In en, this message translates to:
  /// **'Close search'**
  String get settingsScreen_closeSearchTooltip;

  /// No description provided for @settingsScreen_noResults.
  ///
  /// In en, this message translates to:
  /// **'No settings found'**
  String get settingsScreen_noResults;

  /// No description provided for @settingsAccountProfile_profileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your name, bar association, and membership details'**
  String get settingsAccountProfile_profileSubtitle;

  /// No description provided for @settingsAccountProfile_manageAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Password, subscription, and account settings'**
  String get settingsAccountProfile_manageAccountSubtitle;

  /// No description provided for @settingsProfile_title.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get settingsProfile_title;

  /// No description provided for @settingsProfile_editTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
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

  /// PROFILE
  ///
  /// In en, this message translates to:
  /// **'Adv. {name}'**
  String settingsProfile_displayName(String name);

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

  /// No description provided for @settingsManageAccount_subscriptionDetails.
  ///
  /// In en, this message translates to:
  /// **'Subscription Details'**
  String get settingsManageAccount_subscriptionDetails;

  /// No description provided for @settingsManageAccount_purchaseNewSubscription.
  ///
  /// In en, this message translates to:
  /// **'Purchase New Subscription'**
  String get settingsManageAccount_purchaseNewSubscription;

  /// No description provided for @settingsManageAccount_logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get settingsManageAccount_logout;

  /// No description provided for @settingsManageAccount_accountSettings.
  ///
  /// In en, this message translates to:
  /// **'Account Settings'**
  String get settingsManageAccount_accountSettings;

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

  /// No description provided for @settingsOnlineSync_title.
  ///
  /// In en, this message translates to:
  /// **'Online Sync'**
  String get settingsOnlineSync_title;

  /// No description provided for @settingsOnlineSync_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage your real-time data sync across all your devices.'**
  String get settingsOnlineSync_subtitle;

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

  /// No description provided for @settingsBackupRestore_title.
  ///
  /// In en, this message translates to:
  /// **'Backup & Restore'**
  String get settingsBackupRestore_title;

  /// No description provided for @settingsBackupRestore_sectionBackup.
  ///
  /// In en, this message translates to:
  /// **'Backup & Restore'**
  String get settingsBackupRestore_sectionBackup;

  /// No description provided for @settingsBackupRestore_sectionAutomaticBackup.
  ///
  /// In en, this message translates to:
  /// **'Automatic Backup'**
  String get settingsBackupRestore_sectionAutomaticBackup;

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
  /// **'Restore from backup'**
  String get settingsBackupRestore_restore;

  /// No description provided for @settingsBackupRestore_encryptionNote.
  ///
  /// In en, this message translates to:
  /// **'Backups are encrypted and stored in your local storage or cloud provider. Restoration will overwrite current data.'**
  String get settingsBackupRestore_encryptionNote;

  /// No description provided for @settingsBackupRestore_offlineNote.
  ///
  /// In en, this message translates to:
  /// **'Note: Restoration is available for offline accounts only.'**
  String get settingsBackupRestore_offlineNote;

  /// No description provided for @settingsBackupRestore_lastSuccessfulBackup.
  ///
  /// In en, this message translates to:
  /// **'Last successful backup'**
  String get settingsBackupRestore_lastSuccessfulBackup;

  /// No description provided for @settingsBackupRestore_lastBackupPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Oct 20, 2023 at 10:45 AM'**
  String get settingsBackupRestore_lastBackupPlaceholder;

  /// No description provided for @settingsBackupRestore_enginePending.
  ///
  /// In en, this message translates to:
  /// **'Backup engine arrives in Task 15'**
  String get settingsBackupRestore_enginePending;

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

  /// No description provided for @settingsEditCourtSteps_editItemTypes.
  ///
  /// In en, this message translates to:
  /// **'Edit Case Types, Step etc'**
  String get settingsEditCourtSteps_editItemTypes;

  /// No description provided for @settingsEditCourtSteps_editItemTypesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage case types, procedural steps, and on-behalf roles'**
  String get settingsEditCourtSteps_editItemTypesSubtitle;

  /// No description provided for @settingsEditCourtSteps_courtNamesCategories.
  ///
  /// In en, this message translates to:
  /// **'Edit Court Names'**
  String get settingsEditCourtSteps_courtNamesCategories;

  /// No description provided for @settingsEditCourtSteps_courtNamesCategoriesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Supreme Court divisions and district lower courts'**
  String get settingsEditCourtSteps_courtNamesCategoriesSubtitle;

  /// No description provided for @settingsEditCourtSteps_lowerCourtCategories.
  ///
  /// In en, this message translates to:
  /// **'Edit Lower Court Categories'**
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
  /// **'Court Names, Steps etc'**
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
  /// **'District & Sessions (Criminal)'**
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

  /// No description provided for @settingsCourtNamesSteps_catTribunals.
  ///
  /// In en, this message translates to:
  /// **'Tribunals'**
  String get settingsCourtNamesSteps_catTribunals;

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

  /// Day-offset option for two or more days before the hearing.
  ///
  /// In en, this message translates to:
  /// **'Before {days} Days'**
  String settingsNotifications_offsetBeforeDays(int days);

  /// No description provided for @settingsNotifications_timeLabel.
  ///
  /// In en, this message translates to:
  /// **'Notification Time'**
  String get settingsNotifications_timeLabel;

  /// No description provided for @settingsNotifications_reminderBanner.
  ///
  /// In en, this message translates to:
  /// **'Notifications May Not Work Reliably on Your Device. Tap to Complete Setup.'**
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

  /// No description provided for @settingsNotifications_setupGuidePending.
  ///
  /// In en, this message translates to:
  /// **'Setup Guide Arrives in Task 13'**
  String get settingsNotifications_setupGuidePending;

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

  /// No description provided for @settingsViewSettings_sectionNavigation.
  ///
  /// In en, this message translates to:
  /// **'Navigation'**
  String get settingsViewSettings_sectionNavigation;

  /// No description provided for @settingsViewSettings_upcomingPeriod.
  ///
  /// In en, this message translates to:
  /// **'Upcoming cases period'**
  String get settingsViewSettings_upcomingPeriod;

  /// Number of days the Upcoming Cases screen looks ahead.
  ///
  /// In en, this message translates to:
  /// **'{days} days'**
  String settingsViewSettings_days(int days);

  /// No description provided for @settingsViewSettings_caseListMode.
  ///
  /// In en, this message translates to:
  /// **'Case list display'**
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

  /// No description provided for @settingsViewSettings_bottomTabs.
  ///
  /// In en, this message translates to:
  /// **'Bottom navigation tabs'**
  String get settingsViewSettings_bottomTabs;

  /// No description provided for @settingsViewSettings_bottomTabsHint.
  ///
  /// In en, this message translates to:
  /// **'Choose the screens you want in the bottom bar, then drag them into the order you prefer.'**
  String get settingsViewSettings_bottomTabsHint;

  /// No description provided for @settingsViewSettings_keepOneTab.
  ///
  /// In en, this message translates to:
  /// **'Keep at least one screen in the bottom bar.'**
  String get settingsViewSettings_keepOneTab;

  /// No description provided for @settingsViewSettings_sideNav.
  ///
  /// In en, this message translates to:
  /// **'Side navigation options'**
  String get settingsViewSettings_sideNav;

  /// No description provided for @settingsViewSettings_landingPage.
  ///
  /// In en, this message translates to:
  /// **'Default landing page'**
  String get settingsViewSettings_landingPage;

  /// No description provided for @settingsGuidelines_title.
  ///
  /// In en, this message translates to:
  /// **'Guidelines'**
  String get settingsGuidelines_title;

  /// No description provided for @settingsGuidelines_intro.
  ///
  /// In en, this message translates to:
  /// **'Tap on any topic below to expand and view detailed administrative procedures.'**
  String get settingsGuidelines_intro;

  /// No description provided for @settingsGuidelines_dailyCauseListTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily Cause List Management'**
  String get settingsGuidelines_dailyCauseListTitle;

  /// No description provided for @settingsGuidelines_dailyCauseListBody1.
  ///
  /// In en, this message translates to:
  /// **'To ensure your daily schedule is accurate, synchronize your local diary with the court\'s official cause list. Navigate to the \'Cause List\' tab and tap the sync icon in the top right corner.'**
  String get settingsGuidelines_dailyCauseListBody1;

  /// No description provided for @settingsGuidelines_dailyCauseListBody2.
  ///
  /// In en, this message translates to:
  /// **'Note: Disposed cases will automatically move to the archive unless marked for active monitoring.'**
  String get settingsGuidelines_dailyCauseListBody2;

  /// No description provided for @settingsGuidelines_referencesTitle.
  ///
  /// In en, this message translates to:
  /// **'Managing Case References'**
  String get settingsGuidelines_referencesTitle;

  /// No description provided for @settingsGuidelines_referencesBody1.
  ///
  /// In en, this message translates to:
  /// **'When adding a new case, use the standardized format for case references to enable efficient search later. Enter the Case Type, Number, and Year (e.g., Writ Petition No. 1234 of 2023).'**
  String get settingsGuidelines_referencesBody1;

  /// No description provided for @settingsGuidelines_referencesBody2.
  ///
  /// In en, this message translates to:
  /// **'You can link relevant legal precedents to specific active cases within the \'Case Details\' view under the \'Notes\' section.'**
  String get settingsGuidelines_referencesBody2;

  /// No description provided for @settingsGuidelines_backupTitle.
  ///
  /// In en, this message translates to:
  /// **'Offline Backup & Restore'**
  String get settingsGuidelines_backupTitle;

  /// No description provided for @settingsGuidelines_backupBody1.
  ///
  /// In en, this message translates to:
  /// **'The Justice Ledger automatically performs a local backup every 24 hours. To configure cloud backups to Google Drive or secure enterprise servers, visit Settings > Backup Options.'**
  String get settingsGuidelines_backupBody1;

  /// No description provided for @settingsGuidelines_backupBody2.
  ///
  /// In en, this message translates to:
  /// **'If you need to restore data, ensure you have your encryption key available before initiating the recovery process.'**
  String get settingsGuidelines_backupBody2;

  /// No description provided for @settingsGuidelines_securityTitle.
  ///
  /// In en, this message translates to:
  /// **'Security & Encryption'**
  String get settingsGuidelines_securityTitle;

  /// No description provided for @settingsGuidelines_securityBody1.
  ///
  /// In en, this message translates to:
  /// **'All sensitive client data and case notes are protected using end-to-end AES-256 encryption. The decryption key remains solely on your device.'**
  String get settingsGuidelines_securityBody1;

  /// No description provided for @settingsGuidelines_securityBody2.
  ///
  /// In en, this message translates to:
  /// **'We recommend enabling biometric authentication (Face ID or Fingerprint) in the app settings to add an additional layer of security for daily access.'**
  String get settingsGuidelines_securityBody2;

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

  /// No description provided for @settingsAbout_emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get settingsAbout_emailLabel;

  /// No description provided for @settingsAbout_whatsappLabel.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp'**
  String get settingsAbout_whatsappLabel;

  /// No description provided for @settingsAbout_moreAboutApp.
  ///
  /// In en, this message translates to:
  /// **'More About the App'**
  String get settingsAbout_moreAboutApp;

  /// No description provided for @settingsAbout_faq.
  ///
  /// In en, this message translates to:
  /// **'FAQ'**
  String get settingsAbout_faq;

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
  /// **'Your data is stored locally on your device and encrypted in the cloud.'**
  String get settingsAbout_dataSafetyBody;

  /// No description provided for @settingsAbout_actionPending.
  ///
  /// In en, this message translates to:
  /// **'Arrives in a later task'**
  String get settingsAbout_actionPending;

  /// No description provided for @settingsMoreAbout_title.
  ///
  /// In en, this message translates to:
  /// **'More About the App'**
  String get settingsMoreAbout_title;

  /// No description provided for @settingsMoreAbout_checkUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get settingsMoreAbout_checkUpdates;

  /// No description provided for @settingsMoreAbout_description.
  ///
  /// In en, this message translates to:
  /// **'Justice Ledger is a comprehensive digital diary exclusively crafted for Bangladeshi lawyers. It is designed to streamline the management of daily cause lists, rigorously track upcoming and missed dates, and store vital case references securely. Built with precision and the demanding pace of legal professionals in mind, it ensures that your most critical data is always organized and instantly accessible.'**
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

  /// No description provided for @settingsMoreAbout_featureSecureSync.
  ///
  /// In en, this message translates to:
  /// **'Secure Sync'**
  String get settingsMoreAbout_featureSecureSync;

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
