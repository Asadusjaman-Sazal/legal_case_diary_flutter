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

  /// No description provided for @upcomingCasesScreen_title.
  ///
  /// In en, this message translates to:
  /// **'Upcoming Cases'**
  String get upcomingCasesScreen_title;

  /// No description provided for @general_tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get general_tomorrow;

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

  /// No description provided for @disposedCasesScreen_title.
  ///
  /// In en, this message translates to:
  /// **'Disposed Cases'**
  String get disposedCasesScreen_title;

  /// No description provided for @caseCard_disposed.
  ///
  /// In en, this message translates to:
  /// **'Disposed:'**
  String get caseCard_disposed;

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

  /// No description provided for @activeCasesScreen_title.
  ///
  /// In en, this message translates to:
  /// **'Active Cases'**
  String get activeCasesScreen_title;

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
  /// **'Bengali'**
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

  /// No description provided for @settingsProfile_title.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get settingsProfile_title;

  /// No description provided for @settingsManageAccount_title.
  ///
  /// In en, this message translates to:
  /// **'Manage Account'**
  String get settingsManageAccount_title;

  /// No description provided for @settingsOnlineSync_title.
  ///
  /// In en, this message translates to:
  /// **'Online Sync'**
  String get settingsOnlineSync_title;

  /// No description provided for @settingsBackupRestore_title.
  ///
  /// In en, this message translates to:
  /// **'Backup & Restore'**
  String get settingsBackupRestore_title;

  /// No description provided for @settingsNotifications_title.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotifications_title;

  /// No description provided for @settingsViewSettings_title.
  ///
  /// In en, this message translates to:
  /// **'View Settings'**
  String get settingsViewSettings_title;

  /// No description provided for @settingsGuidelines_title.
  ///
  /// In en, this message translates to:
  /// **'Guidelines'**
  String get settingsGuidelines_title;

  /// No description provided for @settingsAbout_title.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout_title;

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
  /// **'Executive Magistrate & Others Courts'**
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
