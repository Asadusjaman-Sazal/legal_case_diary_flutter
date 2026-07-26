import json
import os
from collections import defaultdict

ARB = 'lib/core/l10n/app_en.arb'
OUT_DIR = 'lib/core/l10n'

with open(ARB, encoding='utf-8') as f:
    arb = json.load(f)

keys = [k for k in arb.keys() if not k.startswith('@@') and not k.startswith('@')]

groups = defaultdict(list)
for k in keys:
    group = k.rsplit('_', 1)[0] if '_' in k else 'general'
    groups[group].append(k)

def to_pascal(snake):
    return ''.join(s.title() for s in snake.split('_'))

def to_camel(snake):
    parts = snake.split('_')
    return parts[0] + ''.join(s.title() for s in parts[1:])

# app_strings.dart
lines = [
    '/// L10n key references used by the UI and by `AppTranslations`.',
    '/// Generated from `lib/core/l10n/app_en.arb`.',
    'library;',
    '',
    'abstract class AppStrings {',
    '  AppStrings._();',
    '',
]
for group in sorted(groups):
    lines.append(f'  // {group}')
    lines.append(f'  static const String {to_camel(group)}Group = {json.dumps(group)};')
    for k in sorted(groups[group]):
        key_name = k[len(group) + 1:]
        const_name = to_camel(group) + to_pascal(key_name)
        lines.append(f'  static const String {const_name} = {json.dumps(k)};')
    lines.append('')
lines.append('}')
with open(os.path.join(OUT_DIR, 'app_strings.dart'), 'w', encoding='utf-8') as f:
    f.write('\n'.join(lines))

# app_translations.dart
mapping_entries = []
for group in sorted(groups):
    mapping_entries.append(f'    AppStrings.{to_camel(group)}Group: <String, String>{{')
    for k in sorted(groups[group]):
        key_name = k[len(group) + 1:]
        const_name = to_camel(group) + to_pascal(key_name)
        if k in ('caseDetailsScreen_entriesTotal', 'localeScratch_currentLanguage', 'messageTemplate_clientSms', 'messageTemplate_clientWhatsApp'):
            mapping_entries.append(f'      // {const_name} is parameterized; use typed helper below.')
        else:
            mapping_entries.append(f'      AppStrings.{const_name}: _loc.{k},')
    mapping_entries.append('    },')

dart_code = f"""import 'package:flutter/widgets.dart';

import '../constants/app_strings.dart';
import 'generated/app_localizations.dart';

/// Central, hierarchical, screen-grouped access to the generated [AppLocalizations].
///
/// Pre-seeded items (court categories, steps, case types, on-behalfs, divisions)
/// and shared actions live alongside screen-specific translations. Use the typed
/// [BuildContext] extension for daily UI work, or inspect [grouped] for the
/// full nested map.
class AppTranslations {{
  AppTranslations(this._loc);

  final AppLocalizations _loc;

  /// Hierarchical nested map of all simple (non-parameterized) translations,
  /// grouped by screen / domain.
  Map<String, Map<String, String>> get grouped => <String, Map<String, String>>{{
{'\n'.join(mapping_entries)}
  }};

  // Typed screen / domain helpers
  AllCasesL10n get allCasesScreen => AllCasesL10n(_loc);
  DailyCauseListL10n get dailyCauseListScreen => DailyCauseListL10n(_loc);
  CaseDetailsL10n get caseDetailsScreen => CaseDetailsL10n(_loc);
  SettingsL10n get settingsScreen => SettingsL10n(_loc);
  SharedActionsL10n get sharedActions => SharedActionsL10n(_loc);
  MessageTemplatesL10n get messageTemplates => MessageTemplatesL10n(_loc);
  PreSeededL10n get preSeeded => PreSeededL10n(_loc);
}}

/// BuildContext extension for convenient access.
///
/// Example: `context.l10n.allCasesScreen.title`
extension AppL10n on BuildContext {{
  AppTranslations get l10n => AppTranslations(AppLocalizations.of(this));
}}

/// All Cases screen labels.
class AllCasesL10n {{
  const AllCasesL10n(this._loc);
  final AppLocalizations _loc;
  String get title => _loc.allCasesScreen_title;
  String get activeCases => _loc.allCasesScreen_activeCases;
  String get disposedCases => _loc.allCasesScreen_disposedCases;
  String get filterByCourt => _loc.allCasesScreen_filterByCourt;
  String get newestFirst => _loc.allCasesScreen_newestFirst;
  String get oldestFirst => _loc.allCasesScreen_oldestFirst;
  String get caseType => _loc.allCasesScreen_caseType;
  String get caseNumber => _loc.allCasesScreen_caseNumber;
  String get onBehalf => _loc.allCasesScreen_onBehalf;
  String get petitionerVsRespondent => _loc.allCasesScreen_petitionerVsRespondent;
  String get nextDate => _loc.allCasesScreen_nextDate;
  String get lastStep => _loc.allCasesScreen_lastStep;
  String get phone => _loc.allCasesScreen_phone;
  String get message => _loc.allCasesScreen_message;
  String get update => _loc.allCasesScreen_update;
}}

/// Daily Cause List screen labels.
class DailyCauseListL10n {{
  const DailyCauseListL10n(this._loc);
  final AppLocalizations _loc;
  String get title => _loc.dailyCauseListScreen_title;
  String get today => _loc.dailyCauseListScreen_today;
  String get tomorrow => _loc.dailyCauseListScreen_tomorrow;
  String get calendarLabel => _loc.dailyCauseListScreen_calendarLabel;
}}

/// Case Details screen labels.
class CaseDetailsL10n {{
  const CaseDetailsL10n(this._loc);
  final AppLocalizations _loc;
  String get title => _loc.caseDetailsScreen_title;
  String get delete => _loc.caseDetailsScreen_delete;
  String get editCase => _loc.caseDetailsScreen_editCase;
  String get close => _loc.caseDetailsScreen_close;
  String get onBehalfOf => _loc.caseDetailsScreen_onBehalfOf;
  String get petitioner => _loc.caseDetailsScreen_petitioner;
  String get respondent => _loc.caseDetailsScreen_respondent;
  String get leadCounsel => _loc.caseDetailsScreen_leadCounsel;
  String get caseTitleAndRemark => _loc.caseDetailsScreen_caseTitleAndRemark;
  String get sectionsOrCaseTitle => _loc.caseDetailsScreen_sectionsOrCaseTitle;
  String get remarksOrCaseSummary => _loc.caseDetailsScreen_remarksOrCaseSummary;
  String get caseHistory => _loc.caseDetailsScreen_caseHistory;
  String get phone => _loc.caseDetailsScreen_phone;
  String get message => _loc.caseDetailsScreen_message;
  String entriesTotal(int count) => _loc.caseDetailsScreen_entriesTotal(count);
}}

/// Settings screen labels.
class SettingsL10n {{
  const SettingsL10n(this._loc);
  final AppLocalizations _loc;
  String get title => _loc.settingsScreen_title;
  String get accountAndProfile => _loc.settingsScreen_accountAndProfile;
  String get profile => _loc.settingsScreen_profile;
  String get manageAccount => _loc.settingsScreen_manageAccount;
  String get onlineSync => _loc.settingsScreen_onlineSync;
  String get backupAndRestore => _loc.settingsScreen_backupAndRestore;
  String get editCourtSteps => _loc.settingsScreen_editCourtSteps;
  String get notifications => _loc.settingsScreen_notifications;
  String get language => _loc.settingsScreen_language;
  String get languageEnglish => _loc.settingsScreen_languageEnglish;
  String get languageBengali => _loc.settingsScreen_languageBengali;
  String get viewSettings => _loc.settingsScreen_viewSettings;
  String get guidelines => _loc.settingsScreen_guidelines;
  String get about => _loc.settingsScreen_about;
}}

/// Shared action labels.
class SharedActionsL10n {{
  const SharedActionsL10n(this._loc);
  final AppLocalizations _loc;
  String get save => _loc.sharedActions_save;
  String get cancel => _loc.sharedActions_cancel;
  String get delete => _loc.sharedActions_delete;
  String get edit => _loc.sharedActions_edit;
  String get search => _loc.sharedActions_search;
  String get add => _loc.sharedActions_add;
  String get update => _loc.sharedActions_update;
  String get close => _loc.sharedActions_close;
  String get yes => _loc.sharedActions_yes;
  String get no => _loc.sharedActions_no;
}}

/// Client notification message templates.
class MessageTemplatesL10n {{
  const MessageTemplatesL10n(this._loc);
  final AppLocalizations _loc;
  String clientSms(String clientName, String caseNumber, String nextDate) =>
      _loc.messageTemplate_clientSms(clientName, caseNumber, nextDate);
  String clientWhatsApp(String clientName, String caseNumber, String nextDate) =>
      _loc.messageTemplate_clientWhatsApp(clientName, caseNumber, nextDate);
}}

/// Pre-seeded domain labels keyed by stable IDs.
class PreSeededL10n {{
  const PreSeededL10n(this._loc);
  
