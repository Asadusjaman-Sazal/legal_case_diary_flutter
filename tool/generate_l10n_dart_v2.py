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

# --------------------------------------------------------------------------
# app_strings.dart
# --------------------------------------------------------------------------
strings_lines = [
    '/// L10n key references used by the UI and by `AppTranslations`.',
    '/// Generated from `lib/core/l10n/app_en.arb`.',
    'library;',
    '',
    'abstract class AppStrings {',
    '  AppStrings._();',
    '',
]
for group in sorted(groups):
    strings_lines.append(f'  // {group}')
    strings_lines.append(f'  static const String {to_camel(group)}Group = {json.dumps(group)};')
    for k in sorted(groups[group]):
        key_name = k[len(group) + 1:]
        const_name = to_camel(group) + to_pascal(key_name)
        strings_lines.append(f'  static const String {const_name} = {json.dumps(k)};')
    strings_lines.append('')
strings_lines.append('}')

with open(os.path.join(OUT_DIR, 'app_strings.dart'), 'w', encoding='utf-8') as f:
    f.write('\n'.join(strings_lines))

# --------------------------------------------------------------------------
# app_translations.dart
# --------------------------------------------------------------------------
parameterized = {
    'caseDetailsScreen_entriesTotal',
    'localeScratch_currentLanguage',
    'messageTemplate_clientSms',
    'messageTemplate_clientWhatsApp',
}

dart_lines = [
    "import 'package:flutter/widgets.dart';",
    '',
    "import '../constants/app_strings.dart';",
    "import 'generated/app_localizations.dart';",
    '',
    '/// Central, hierarchical, screen-grouped access to the generated [AppLocalizations].',
    '///',
    '/// Pre-seeded items (court categories, steps, case types, on-behalfs, divisions)',
    '/// and shared actions live alongside screen-specific translations. The [grouped]',
    '/// map is the canonical hierarchical structure; the [raw] getter exposes the',
    '/// generated [AppLocalizations] instance for direct typed access when needed.',
    'class AppTranslations {',
    '  AppTranslations(this._loc);',
    '',
    '  final AppLocalizations _loc;',
    '',
    '  /// Direct typed access to the generated localizations instance.',
    '  AppLocalizations get raw => _loc;',
    '',
    '  /// Hierarchical nested map of translations grouped by screen / domain.',
    '  ///',
    '  /// Parameterized keys (placeholders / message templates) are omitted from',
    '  /// this map and should be accessed through the typed helpers on [raw].',
    '  Map<String, Map<String, String>> get grouped => <String, Map<String, String>>{',
]

for group in sorted(groups):
    dart_lines.append(f'    AppStrings.{to_camel(group)}Group: <String, String>{{')
    for k in sorted(groups[group]):
        key_name = k[len(group) + 1:]
        const_name = to_camel(group) + to_pascal(key_name)
        if k in parameterized:
            dart_lines.append(f'      // {const_name}: parameterized; use _loc.{k}(...).')
        else:
            dart_lines.append(f'      AppStrings.{const_name}: _loc.{k},')
    dart_lines.append('    },')

dart_lines += [
    '  };',
    '}',  # end class
    '',
    '/// BuildContext extension for convenient access.',
    '///',
    '/// Example: `context.l10n.grouped[AppStrings.allCasesGroup][AppStrings.allCasesTitle]`',
    'extension AppL10n on BuildContext {',
    '  AppTranslations get l10n => AppTranslations(AppLocalizations.of(this));',
    '}',
    '',
]

with open(os.path.join(OUT_DIR, 'app_translations.dart'), 'w', encoding='utf-8') as f:
    f.write('\n'.join(dart_lines))

print('Generated app_strings.dart and app_translations.dart')
