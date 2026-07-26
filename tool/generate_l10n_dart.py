import json
import os
import re
from collections import defaultdict

ARB = 'lib/core/l10n/app_en.arb'
OUT_DIR = 'lib/core/l10n'

with open(ARB, encoding='utf-8') as f:
    arb = json.load(f)

# Drop metadata keys and placeholder-only metadata entries.
keys = [k for k in arb.keys() if not k.startswith('@@') and not k.startswith('@')]

# Group by the leading PascalCase screen/component token (everything before the last underscore).
groups = defaultdict(list)
for k in keys:
    if '_' in k:
        group = k.rsplit('_', 1)[0]
    else:
        group = 'general'
    groups[group].append(k)

# CamelCase / PascalCase helpers.
def to_pascal(snake):
    return ''.join(s.title() for s in snake.split('_'))

def to_camel(snake):
    parts = snake.split('_')
    return parts[0] + ''.join(s.title() for s in parts[1:])

# app_strings.dart
strings_lines = [
    '/// L10n key references used by the UI and by `AppTranslations`.',
    '/// Generated from `lib/core/l10n/app_en.arb` — do not edit manually.',
    'library;',
    '',
    'abstract class AppStrings {',
    '  AppStrings._();',
    '',
]

for group, group_keys in sorted(groups.items()):
    strings_lines.append(f'  // {group}')
    group_const = to_pascal(group) + 'Group'
    strings_lines.append(f'  static const String {to_camel(group)}Group = {json.dumps(group)};')
    for k in sorted(group_keys):
        # key constant: last segment, scoped by group.
        key_name = k[len(group) + 1:]
        const_name = to_camel(group) + to_pascal(key_name)
        strings_lines.append(f'  static const String {const_name} = {json.dumps(k)};')
    strings_lines.append('')
strings_lines.append('}')

with open(os.path.join(OUT_DIR, 'app_strings.dart'), 'w', encoding='utf-8') as f:
    f.write('\n'.join(strings_lines))

# app_translations.dart
dart_lines = [
    'import \'package:flutter/widgets.dart\';',
    '',
    'import \'../constants/app_strings.dart\';',
    'import \'generated/app_localizations.dart\';',
    '',
    '/// Central, hierarchical, screen-grouped access to the generated [AppLocalizations].',
    '///',
    '/// Instead of scattering raw string keys across the UI, use the typed',
    '/// [BuildContext] extension or the [grouped] map. Pre-seeded items (court',
    '/// categories, steps, case types, on-behalfs, divisions) and shared actions are',
    '/// grouped alongside screen-specific translations.',
    'class AppTranslations {',
    '  AppTranslations(this._loc);',
    '',
    '  final AppLocalizations _loc;',
    '',
    '  /// Returns a mutable snapshot of all translations grouped by screen / domain.',
    '  Map<String, Map<String, String>> get grouped => <String, Map<String, String>>{',
]

for group, group_keys in sorted(groups.items()):
    dart_lines.append(f'    AppStrings.{to_camel(group)}Group: <String, String>{{')
    for k in sorted(group_keys):
        key_name = k[len(group) + 1:]
        const_name = to_camel(group) + to_pascal(key_name)
        # Build the AppLocalizations getter reference.
        if k in ['caseDetailsScreen_entriesTotal', 'localeScratch_currentLanguage']:
            # Parameterized methods are exposed as typed helpers; skip the flat map.
            dart_lines.append(f'      // {const_name} is a parameterized method; use _loc.{k}(...).')
        elif k in ['messageTemplate_clientSms', 'messageTemplate_clientWhatsApp']:
            dart_lines.append(f'      // {const_name} is a parameterized message template; use _loc.{k}(...).')
        else:
            dart_lines.append(f'      AppStrings.{const_name}: _loc.{k},')
    dart_lines.append('    },')

dart_lines.add('  };')
dart_lines.append('')
dart_lines += [
    '  /// Typed screen helpers for the most common screens.',
    '  AllCasesL10n get allCasesScreen => AllCasesL10n(_loc);',
    '  DailyCauseListL10n get dailyCauseListScreen => DailyCauseListL10n(_loc);',
    '  CaseDetailsL10n get caseDetailsScreen => CaseDetailsL10n(_loc);',
    '  SettingsL10n get settingsScreen => SettingsL10n(_loc);',
    '  SharedActionsL10n get sharedActions => SharedActionsL10n(_loc);',
    '  MessageTemplatesL10n get messageTemplates => MessageTemplatesL10n(_loc);',
    '  PreSeededL10n get preSeeded => PreSeededL10n(_loc);',
    '}
',
    '/// BuildContext extension for convenient access: `context.l10n.allCasesScreen.title`.',
    'extension AppL10n on BuildContext {',
    '  AppTranslations get l10n => AppTranslations(AppLocalizations.of(this));',
    '}
',
    '/// All Cases screen labels.',
    'class AllCasesL10n {',
    '  const AllCasesL10n(this._loc);',
    '  final AppLocalizations _loc;',
    '  String get title => _loc.allCasesScreen_title;',
    '  String get activeCases => _loc.allCasesScreen_activeCases;',
    '  String get disposedCases => _loc.allCasesScreen_disposedCases;',
    '  String get filterByCourt => _loc.allCasesScreen_filterByCourt;',
    '  String get newestFirst => _loc.allCasesScreen_newestFirst;',
    '  String get oldestFirst => _loc.allCasesScreen_oldestFirst;',
    '  String get caseType => _loc.allCasesScreen_caseType;',
    '  String get caseNumber => _loc.allCasesScreen_caseNumber;',
    '  String get onBehalf => _loc.allCasesScreen_onBehalf;',
    '  String get petitionerVsRespondent => _loc.allCasesScreen_petitionerVsRespondent;',
    '  String get nextDate => _loc.allCasesScreen_nextDate;',
    '  String get lastStep => _loc.allCasesScreen_lastStep;',
    '  String get phone => _loc.allCasesScreen_phone;',
    '  String get message => _loc.allCasesScreen_message;',
    '  String get update => _loc.allCasesScreen_update;',
    '}
',
    '/// Daily Cause List screen labels.',
    'class DailyCauseListL10n {',
    '  const DailyCauseListL10n(this._loc);',
    '  final AppLocalizations _loc;',
    '  String get title => _loc.dailyCauseListScreen_title;',
    '  String get today => _loc.dailyCauseListScreen_today;',
    '  String get tomorrow => _loc.dailyCauseListScreen_tomorrow;',
    '  String get calendarLabel => _loc.dailyCauseListScreen_calendarLabel;',
    '}
',
    '/// Case Details screen labels.',
    'class CaseDetailsL10n {',
    '  const CaseDetailsL10n(this._loc);',
    '  final AppLocalizations _loc;',
    '  String get title => _loc.caseDetailsScreen_title;',
    '  String get delete => _loc.caseDetailsScreen_delete;',
    '  String get editCase => _loc.caseDetailsScreen_editCase;',
    '  String get close => _loc.caseDetailsScreen_close;',
    '  String get onBehalfOf => _loc.caseDetailsScreen_onBehalfOf;',
    '  String get petitioner => _loc.caseDetailsScreen_petitioner;',
    '  String get respondent => _loc.caseDetailsScreen_respondent;',
    '  String get leadCounsel => _loc.caseDetailsScreen_leadCounsel;',
    '  String get caseTitleAndRemark => _loc.caseDetailsScreen_caseTitleAndRemark;',
    '  String get sectionsOrCaseTitle => _loc.caseDetailsScreen_sectionsOrCaseTitle;',
    '  String get remarksOrCaseSummary => _loc.caseDetailsScreen_remarksOrCaseSummary;',
    '  String get caseHistory => _loc.caseDetailsScreen_caseHistory;',
    '  String get phone => _loc.caseDetailsScreen_phone;',
    '  String get message => _loc.caseDetailsScreen_message;',
    '  String entriesTotal(int count) => _loc.caseDetailsScreen_entriesTotal(count);',
    '}
',
    '/// Settings screen labels.',
    'class SettingsL10n {',
    '  const SettingsL10n(this._loc);',
    '  final AppLocalizations _loc;',
    '  String get title => _loc.settingsScreen_title;',
    '  String get accountAndProfile => _loc.settingsScreen_accountAndProfile;',
    '  String get profile => _loc.settingsScreen_profile;',
    '  String get manageAccount => _loc.settingsScreen_manageAccount;',
    '  String get onlineSync => _loc.settingsScreen_onlineSync;',
    '  String get backupAndRestore => _loc.settingsScreen_backupAndRestore;',
    '  String get editCourtSteps => _loc.settingsScreen_editCourtSteps;',
    '  String get notifications => _loc.settingsScreen_notifications;',
    '  String get language => _loc.settingsScreen_language;',
    '  String get languageEnglish => _loc.settingsScreen_languageEnglish;',
    '  String get languageBengali => _loc.settingsScreen_languageBengali;',
    '  String get viewSettings => _loc.settingsScreen_viewSettings;',
    '  String get guidelines => _loc.settingsScreen_guidelines;',
    '  String get about => _loc.settingsScreen_about;',
    '}
',
    '/// Shared action labels.',
    'class SharedActionsL10n {',
    '  const SharedActionsL10n(this._loc);',
    '  final AppLocalizations _loc;',
    '  String get save => _loc.sharedActions_save;',
    '  String get cancel => _loc.sharedActions_cancel;',
    '  String get delete => _loc.sharedActions_delete;',
    '  String get edit => _loc.sharedActions_edit;',
    '  String get search => _loc.sharedActions_search;',
    '  String get add => _loc.sharedActions_add;',
    '  String get update => _loc.sharedActions_update;',
    '  String get close => _loc.sharedActions_close;',
    '  String get yes => _loc.sharedActions_yes;',
    '  String get no => _loc.sharedActions_no;',
    '}
',
    '/// Client notification message templates.',
    'class MessageTemplatesL10n {',
    '  const MessageTemplatesL10n(this._loc);',
    '  final AppLocalizations _loc;',
    '  String clientSms(String clientName, String caseNumber, String nextDate) => _loc.messageTemplate_clientSms(clientName, caseNumber, nextDate);',
    '  String clientWhatsApp(String clientName, String caseNumber, String nextDate) => _loc.messageTemplate_clientWhatsApp(clientName, caseNumber, nextDate);',
    '}
',
    '/// Pre-seeded domain labels keyed by stable IDs.',
    'class PreSeededL10n {',
    '  const PreSeededL10n(this._loc);',
    '  final AppLocalizations _loc;',
    '  String get appellateDivision => _loc.courtCategory_appellateDivision;',
    '  String get highCourtDivision => _loc.courtCategory_highCourtDivision;',
    '  String get lowerDivisionalCourts => _loc.courtCategory_lowerDivisionalCourts;',
    '  String get districtSessionsCriminal => _loc.lowerCourtCategory_districtSessionsCriminal;',
    '  String get districtCourtsCivil => _loc.lowerCourtCategory_districtCourtsCivil;',
    '  String get chiefJudicialMagistrate => _loc.lowerCourtCategory_chiefJudicialMagistrate;',
    '  String get chiefMetropolitanMagistrate => _loc.lowerCourtCategory_chiefMetropolitanMagistrate;',
    '  String get executiveMagistrate => _loc.lowerCourtCategory_executiveMagistrate;',
    '  String get tribunals => _loc.lowerCourtCategory_tribunals;',
    '  String get plaintiff => _loc.onBehalf_plaintiff;',
    '  String get defendant => _loc.onBehalf_defendant;',
    '  String get accused => _loc.onBehalf_accused;',
    '  String get appellant => _loc.onBehalf_appellant;',
    '  String get petitioner => _loc.onBehalf_petitioner;',
    '  String get respondent => _loc.onBehalf_respondent;',
    '  String get civil => _loc.caseType_civil;',
    '  String get criminal => _loc.caseType_criminal;',
    '  String get writ => _loc.caseType_writ;',
    '  String get appeal => _loc.caseType_appeal;',
    '  String get revision => _loc.caseType_revision;',
    '  String get filed => _loc.step_filed;',
    '  String get hearing => _loc.step_hearing;',
    '  String get disposed => _loc.step_disposed;',
    '  String get pending => _loc.step_pending;',
    '  String get dhaka => _loc.division_dhaka;',
    '  String get chattagram => _loc.division_chattagram;',
    '  String get rajshahi => _loc.division_rajshahi;',
    '  String get khulna => _loc.division_khulna;',
    '  String get barishal => _loc.division_barishal;',
    '  String get sylhet => _loc.division_sylhet;',
    '  String get rangpur => _loc.division_rangpur;',
    '  String get mymensingh => _loc.division_mymensingh;',
    '}
',
]

with open(os.path.join(OUT_DIR, 'app_translations.dart'), 'w', encoding='utf-8') as f:
    f.write('\n'.join(dart_lines))

print('Generated lib/core/l10n/app_strings.dart and lib/core/l10n/app_translations.dart')
