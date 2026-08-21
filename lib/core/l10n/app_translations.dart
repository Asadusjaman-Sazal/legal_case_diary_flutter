import 'package:flutter/widgets.dart';

import '../../core/constants/pre_seeded_data.dart' as seed;
import 'app_strings.dart';
import 'generated/app_localizations.dart';

/// Central, hierarchical, screen-grouped access to the generated [AppLocalizations].
///
/// WARNING: This file is manually maintained. The generate_l10n.py script
/// regenerates app_strings.dart and a simpler version of this file from ARB.
/// Do not run that script without preserving the seedLabel() method and the
/// manual grouped-map structure below.
///
/// Pre-seeded items (court categories, steps, case types, on-behalfs, divisions)
/// and shared actions live alongside screen-specific translations. The [grouped]
/// map is the canonical hierarchical structure; the [raw] getter exposes the
/// generated [AppLocalizations] instance for direct typed access when needed.
class AppTranslations {
  AppTranslations(this._loc);

  final AppLocalizations _loc;

  /// Direct typed access to the generated localizations instance.
  AppLocalizations get raw => _loc;

  /// Resolves a seed data stable ID to its localized label.
  ///
  /// Looks up the label from the pre-seeded data maps based on the current
  /// locale. Returns [fallbackEn] if the ID is not found in any map.
  String seedLabel(String stableId, {String fallbackEn = ''}) {
    final isBengali = _loc.localeName.startsWith('bn');
    // Check each label map in priority order.
    final maps = isBengali
        ? <Map<String, String>>[
            seed.caseCategoryLabelBn,
            seed.stepLabelBn,
            seed.caseTypeLabelBn,
            seed.onBehalfLabelBn,
            seed.courtLabelBn,
            seed.districtLabelBn,
            seed.divisionLabelBn,
          ]
        : <Map<String, String>>[
            seed.caseCategoryLabelEn,
            seed.stepLabelEn,
            seed.caseTypeLabelEn,
            seed.onBehalfLabelEn,
            seed.courtLabelEn,
            seed.districtLabelEn,
            seed.divisionLabelEn,
          ];
    for (final map in maps) {
      if (map.containsKey(stableId)) return map[stableId]!;
    }
    return fallbackEn;
  }

  /// Hierarchical nested map of translations grouped by screen / domain.
  ///
  /// Parameterized keys (placeholders / message templates) are omitted from
  /// this map and should be accessed through the typed helpers on [raw].
  Map<String, Map<String, String>> get grouped => <String, Map<String, String>>{
    AppStrings.activeCasesScreenGroup: <String, String>{
      AppStrings.activeCasesScreenTitle: _loc.activeCasesScreen_title,
    },
    AppStrings.addEditCaseSheetGroup: <String, String>{
      AppStrings.addEditCaseSheetCasenumber: _loc.addEditCaseSheet_caseNumber,
      AppStrings.addEditCaseSheetCaseremarks: _loc.addEditCaseSheet_caseRemarks,
      AppStrings.addEditCaseSheetCasetitleandsection:
          _loc.addEditCaseSheet_caseTitleAndSection,
      AppStrings.addEditCaseSheetCourtcategory:
          _loc.addEditCaseSheet_courtCategory,
      AppStrings.addEditCaseSheetDayoffset: _loc.addEditCaseSheet_dayOffset,
      AppStrings.addEditCaseSheetDistrict: _loc.addEditCaseSheet_district,
      AppStrings.addEditCaseSheetDivision: _loc.addEditCaseSheet_division,
      AppStrings.addEditCaseSheetEdittitle: _loc.addEditCaseSheet_editTitle,
      AppStrings.addEditCaseSheetHigherorlowercourt:
          _loc.addEditCaseSheet_higherOrLowerCourt,
      AppStrings.addEditCaseSheetNameofcourt: _loc.addEditCaseSheet_nameOfCourt,
      AppStrings.addEditCaseSheetNextdate: _loc.addEditCaseSheet_nextDate,
      AppStrings.addEditCaseSheetNote: _loc.addEditCaseSheet_note,
      AppStrings.addEditCaseSheetNotification:
          _loc.addEditCaseSheet_notification,
      AppStrings.addEditCaseSheetOnbehalf: _loc.addEditCaseSheet_onBehalf,
      AppStrings.addEditCaseSheetPetitioner: _loc.addEditCaseSheet_petitioner,
      AppStrings.addEditCaseSheetPartyphone: _loc.addEditCaseSheet_partyPhone,
      AppStrings.addEditCaseSheetYear: _loc.addEditCaseSheet_year,
      AppStrings.addEditCaseSheetRespondent: _loc.addEditCaseSheet_respondent,
      AppStrings.addEditCaseSheetPickdate: _loc.addEditCaseSheet_pickDate,
      AppStrings.addEditCaseSheetSave: _loc.addEditCaseSheet_save,
      AppStrings.addEditCaseSheetStep: _loc.addEditCaseSheet_step,
      AppStrings.addEditCaseSheetTitle: _loc.addEditCaseSheet_title,
    },
    AppStrings.allCasesScreenGroup: <String, String>{
      AppStrings.allCasesScreenActivecases: _loc.allCasesScreen_activeCases,
      AppStrings.allCasesScreenCasenumber: _loc.allCasesScreen_caseNumber,
      AppStrings.allCasesScreenCasetype: _loc.allCasesScreen_caseType,
      AppStrings.allCasesScreenDisposedcases: _loc.allCasesScreen_disposedCases,
      AppStrings.allCasesScreenFilterbycourt: _loc.allCasesScreen_filterByCourt,
      AppStrings.allCasesScreenLaststep: _loc.allCasesScreen_lastStep,
      AppStrings.allCasesScreenMessage: _loc.allCasesScreen_message,
      AppStrings.allCasesScreenNewestfirst: _loc.allCasesScreen_newestFirst,
      AppStrings.allCasesScreenNextdate: _loc.allCasesScreen_nextDate,
      AppStrings.allCasesScreenOldestfirst: _loc.allCasesScreen_oldestFirst,
      AppStrings.allCasesScreenOnbehalf: _loc.allCasesScreen_onBehalf,
      AppStrings.allCasesScreenPetitionervsrespondent:
          _loc.allCasesScreen_petitionerVsRespondent,
      AppStrings.allCasesScreenPhone: _loc.allCasesScreen_phone,
      AppStrings.allCasesScreenTitle: _loc.allCasesScreen_title,
      AppStrings.allCasesScreenUpdate: _loc.allCasesScreen_update,
    },
    AppStrings.caseDetailsScreenGroup: <String, String>{
      AppStrings.caseDetailsScreenCasehistory:
          _loc.caseDetailsScreen_caseHistory,
      AppStrings.caseDetailsScreenCasetitleandremark:
          _loc.caseDetailsScreen_caseTitleAndRemark,
      AppStrings.caseDetailsScreenClose: _loc.caseDetailsScreen_close,
      AppStrings.caseDetailsScreenDelete: _loc.caseDetailsScreen_delete,
      AppStrings.caseDetailsScreenEditcase: _loc.caseDetailsScreen_editCase,
      // caseDetailsScreenEntriestotal: parameterized; use _loc.caseDetailsScreen_entriesTotal(...).
      AppStrings.caseDetailsScreenLeadcounsel:
          _loc.caseDetailsScreen_leadCounsel,
      AppStrings.caseDetailsScreenMessage: _loc.caseDetailsScreen_message,
      AppStrings.caseDetailsScreenOnbehalfof: _loc.caseDetailsScreen_onBehalfOf,
      AppStrings.caseDetailsScreenPetitioner: _loc.caseDetailsScreen_petitioner,
      AppStrings.caseDetailsScreenPhone: _loc.caseDetailsScreen_phone,
      AppStrings.caseDetailsScreenRemarksorcasesummary:
          _loc.caseDetailsScreen_remarksOrCaseSummary,
      AppStrings.caseDetailsScreenRespondent: _loc.caseDetailsScreen_respondent,
      AppStrings.caseDetailsScreenSectionsorcasetitle:
          _loc.caseDetailsScreen_sectionsOrCaseTitle,
      AppStrings.caseDetailsScreenTitle: _loc.caseDetailsScreen_title,
    },
    AppStrings.caseReferenceScreenGroup: <String, String>{
      AppStrings.caseReferenceScreenCommentsnotes:
          _loc.caseReferenceScreen_commentsNotes,
      AppStrings.caseReferenceScreenReferenceandpageno:
          _loc.caseReferenceScreen_referenceAndPageNo,
      AppStrings.caseReferenceScreenSectionorarticle:
          _loc.caseReferenceScreen_sectionOrArticle,
      AppStrings.caseReferenceScreenStatute: _loc.caseReferenceScreen_statute,
      AppStrings.caseReferenceScreenTitle: _loc.caseReferenceScreen_title,
      AppStrings.caseReferenceScreenTitleanddescription:
          _loc.caseReferenceScreen_titleAndDescription,
    },
    AppStrings.caseTypeGroup: <String, String>{
      AppStrings.caseTypeAppeal: _loc.caseType_appeal,
      AppStrings.caseTypeCivil: _loc.caseType_civil,
      AppStrings.caseTypeCriminal: _loc.caseType_criminal,
      AppStrings.caseTypeRevision: _loc.caseType_revision,
      AppStrings.caseTypeWrit: _loc.caseType_writ,
    },
    AppStrings.courtCategoryGroup: <String, String>{
      AppStrings.courtCategoryAppellatedivision:
          _loc.courtCategory_appellateDivision,
      AppStrings.courtCategoryHighcourtdivision:
          _loc.courtCategory_highCourtDivision,
      AppStrings.courtCategoryLowerdivisionalcourts:
          _loc.courtCategory_lowerDivisionalCourts,
    },
    AppStrings.customDropdownGroup: <String, String>{
      AppStrings.customDropdownSelectOption: _loc.customDropdown_selectOption,
      AppStrings.customDropdownSearch: _loc.customDropdown_search,
      AppStrings.customDropdownNoResults: _loc.customDropdown_noResults,
      AppStrings.customDropdownDone: _loc.customDropdown_done,
    },
    AppStrings.dailyCauseListScreenGroup: <String, String>{
      AppStrings.dailyCauseListScreenCalendarlabel:
          _loc.dailyCauseListScreen_calendarLabel,
      AppStrings.dailyCauseListScreenTitle: _loc.dailyCauseListScreen_title,
      AppStrings.dailyCauseListScreenToday: _loc.dailyCauseListScreen_today,
      AppStrings.dailyCauseListScreenTomorrow:
          _loc.dailyCauseListScreen_tomorrow,
    },
    AppStrings.disposedCasesScreenGroup: <String, String>{
      AppStrings.disposedCasesScreenDisposed: _loc.disposedCasesScreen_disposed,
      AppStrings.disposedCasesScreenTitle: _loc.disposedCasesScreen_title,
    },
    AppStrings.divisionGroup: <String, String>{
      AppStrings.divisionBarishal: _loc.division_barishal,
      AppStrings.divisionChattagram: _loc.division_chattagram,
      AppStrings.divisionDhaka: _loc.division_dhaka,
      AppStrings.divisionKhulna: _loc.division_khulna,
      AppStrings.divisionMymensingh: _loc.division_mymensingh,
      AppStrings.divisionRajshahi: _loc.division_rajshahi,
      AppStrings.divisionRangpur: _loc.division_rangpur,
      AppStrings.divisionSylhet: _loc.division_sylhet,
    },
    AppStrings.generalGroup: <String, String>{
      AppStrings.generalAppName: _loc.appName,
      AppStrings.generalAppTitle: _loc.appTitle,
    },
    AppStrings.localeScratchGroup: <String, String>{
      AppStrings.localeScratchBengalisample: _loc.localeScratch_bengaliSample,
      // localeScratchCurrentlanguage: parameterized; use _loc.localeScratch_currentLanguage(...).
      AppStrings.localeScratchEnglishsample: _loc.localeScratch_englishSample,
      AppStrings.localeScratchGreeting: _loc.localeScratch_greeting,
      AppStrings.localeScratchTitle: _loc.localeScratch_title,
    },
    AppStrings.lowerCourtCategoryGroup: <String, String>{
      AppStrings.lowerCourtCategoryChiefjudicialmagistrate:
          _loc.lowerCourtCategory_chiefJudicialMagistrate,
      AppStrings.lowerCourtCategoryChiefmetropolitanmagistrate:
          _loc.lowerCourtCategory_chiefMetropolitanMagistrate,
      AppStrings.lowerCourtCategoryDistrictcourtscivil:
          _loc.lowerCourtCategory_districtCourtsCivil,
      AppStrings.lowerCourtCategoryDistrictsessionscriminal:
          _loc.lowerCourtCategory_districtSessionsCriminal,
      AppStrings.lowerCourtCategoryMetropolitansessionsjudgecriminal:
          _loc.lowerCourtCategory_metropolitanSessionsJudgeCriminal,
      AppStrings.lowerCourtCategoryExecutivemagistrate:
          _loc.lowerCourtCategory_executiveMagistrate,
      AppStrings.lowerCourtCategoryTribunals: _loc.lowerCourtCategory_tribunals,
    },
    // messageTemplate: Intentionally omitted from the grouped map because
    // the message templates are parameterized and must be accessed through
    // the typed helpers on [raw] (e.g. _loc.messageTemplate_clientSms(...)).
    AppStrings.notesScreenGroup: <String, String>{
      AppStrings.notesScreenDelete: _loc.notesScreen_delete,
      AppStrings.notesScreenModified: _loc.notesScreen_modified,
      AppStrings.notesScreenPin: _loc.notesScreen_pin,
      AppStrings.notesScreenTitle: _loc.notesScreen_title,
    },
    AppStrings.onBehalfGroup: <String, String>{
      AppStrings.onBehalfAccused: _loc.onBehalf_accused,
      AppStrings.onBehalfAppellant: _loc.onBehalf_appellant,
      AppStrings.onBehalfDefendant: _loc.onBehalf_defendant,
      AppStrings.onBehalfPetitioner: _loc.onBehalf_petitioner,
      AppStrings.onBehalfPlaintiff: _loc.onBehalf_plaintiff,
      AppStrings.onBehalfRespondent: _loc.onBehalf_respondent,
      AppStrings.onBehalfWritPetitioner: _loc.onBehalf_writPetitioner,
      AppStrings.onBehalfState: _loc.onBehalf_state,
      AppStrings.onBehalfVictim: _loc.onBehalf_victim,
      AppStrings.onBehalfComplainant: _loc.onBehalf_complainant,
      AppStrings.onBehalfInformant: _loc.onBehalf_informant,
      AppStrings.onBehalfApplicant: _loc.onBehalf_applicant,
      AppStrings.onBehalfClaimant: _loc.onBehalf_claimant,
      AppStrings.onBehalfObjector: _loc.onBehalf_objector,
    },
    AppStrings.overdueDatesScreenGroup: <String, String>{
      AppStrings.overdueDatesScreenLastupdated:
          _loc.overdueDatesScreen_lastUpdated,
      AppStrings.overdueDatesScreenTitle: _loc.overdueDatesScreen_title,
    },
    AppStrings.settingsAboutGroup: <String, String>{
      AppStrings.settingsAboutTitle: _loc.settingsAbout_title,
    },
    AppStrings.settingsBackupRestoreGroup: <String, String>{
      AppStrings.settingsBackupRestoreTitle: _loc.settingsBackupRestore_title,
    },
    AppStrings.settingsGuidelinesGroup: <String, String>{
      AppStrings.settingsGuidelinesTitle: _loc.settingsGuidelines_title,
    },
    AppStrings.settingsManageAccountGroup: <String, String>{
      AppStrings.settingsManageAccountTitle: _loc.settingsManageAccount_title,
    },
    AppStrings.settingsNotificationsGroup: <String, String>{
      AppStrings.settingsNotificationsTitle: _loc.settingsNotifications_title,
    },
    AppStrings.settingsOnlineSyncGroup: <String, String>{
      AppStrings.settingsOnlineSyncTitle: _loc.settingsOnlineSync_title,
    },
    AppStrings.settingsProfileGroup: <String, String>{
      AppStrings.settingsProfileTitle: _loc.settingsProfile_title,
    },
    AppStrings.settingsScreenGroup: <String, String>{
      AppStrings.settingsScreenAbout: _loc.settingsScreen_about,
      AppStrings.settingsScreenAccountandprofile:
          _loc.settingsScreen_accountAndProfile,
      AppStrings.settingsScreenBackupandrestore:
          _loc.settingsScreen_backupAndRestore,
      AppStrings.settingsScreenEditcourtsteps:
          _loc.settingsScreen_editCourtSteps,
      AppStrings.settingsScreenGuidelines: _loc.settingsScreen_guidelines,
      AppStrings.settingsScreenLanguage: _loc.settingsScreen_language,
      AppStrings.settingsScreenLanguagebengali:
          _loc.settingsScreen_languageBengali,
      AppStrings.settingsScreenLanguageenglish:
          _loc.settingsScreen_languageEnglish,
      AppStrings.settingsScreenManageaccount: _loc.settingsScreen_manageAccount,
      AppStrings.settingsScreenNotifications: _loc.settingsScreen_notifications,
      AppStrings.settingsScreenOnlinesync: _loc.settingsScreen_onlineSync,
      AppStrings.settingsScreenProfile: _loc.settingsScreen_profile,
      AppStrings.settingsScreenTitle: _loc.settingsScreen_title,
      AppStrings.settingsScreenViewsettings: _loc.settingsScreen_viewSettings,
    },
    AppStrings.settingsViewSettingsGroup: <String, String>{
      AppStrings.settingsViewSettingsTitle: _loc.settingsViewSettings_title,
    },
    AppStrings.sharedActionsGroup: <String, String>{
      AppStrings.sharedActionsAdd: _loc.sharedActions_add,
      AppStrings.sharedActionsCancel: _loc.sharedActions_cancel,
      AppStrings.sharedActionsClose: _loc.sharedActions_close,
      AppStrings.sharedActionsDelete: _loc.sharedActions_delete,
      AppStrings.sharedActionsEdit: _loc.sharedActions_edit,
      AppStrings.sharedActionsNo: _loc.sharedActions_no,
      AppStrings.sharedActionsSave: _loc.sharedActions_save,
      AppStrings.sharedActionsSearch: _loc.sharedActions_search,
      AppStrings.sharedActionsUpdate: _loc.sharedActions_update,
      AppStrings.sharedActionsYes: _loc.sharedActions_yes,
    },
    AppStrings.sharedDialogsGroup: <String, String>{
      AppStrings.sharedDialogsCancel: _loc.sharedDialogs_cancel,
      AppStrings.sharedDialogsConfirmdeletemessage:
          _loc.sharedDialogs_confirmDeleteMessage,
      AppStrings.sharedDialogsConfirmdeletetitle:
          _loc.sharedDialogs_confirmDeleteTitle,
      AppStrings.sharedDialogsOk: _loc.sharedDialogs_ok,
    },
    AppStrings.stepGroup: <String, String>{
      AppStrings.stepDisposed: _loc.step_disposed,
      AppStrings.stepFiled: _loc.step_filed,
      AppStrings.stepHearing: _loc.step_hearing,
      AppStrings.stepPending: _loc.step_pending,
    },
    AppStrings.upcomingCasesScreenGroup: <String, String>{
      AppStrings.upcomingCasesScreenTitle: _loc.upcomingCasesScreen_title,
    },
  };
}

/// BuildContext extension for convenient access.
///
/// Example: `context.l10n.grouped[AppStrings.allCasesGroup][AppStrings.allCasesTitle]`
extension AppL10n on BuildContext {
  AppTranslations get l10n => AppTranslations(AppLocalizations.of(this));
}
