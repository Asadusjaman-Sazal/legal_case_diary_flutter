/// Guards the two ARB resource files that hold every user-facing label.
///
/// The Settings screens read their labels from these files, so a key that only
/// exists in one language — or that loses a placeholder during a hand edit —
/// would silently fall back to English (or crash the getter). These tests keep
/// the two files in lockstep and keep the per-screen sections labelled so the
/// labels stay easy to find.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _enPath = 'lib/core/l10n/app_en.arb';
const String _bnPath = 'lib/core/l10n/app_bn.arb';

Map<String, dynamic> _arb(String path) =>
    json.decode(File(path).readAsStringSync()) as Map<String, dynamic>;

/// Message keys only — `@key` metadata and `@@locale` are skipped.
List<String> _keys(Map<String, dynamic> arb) =>
    arb.keys.where((k) => !k.startsWith('@')).toList();

Set<String> _placeholders(String message) =>
    RegExp(r'\{(\w+)').allMatches(message).map((m) => m.group(1)!).toSet();

void main() {
  final en = _arb(_enPath);
  final bn = _arb(_bnPath);

  test('both ARB files declare the same keys in the same order', () {
    expect(_keys(bn), _keys(en));
  });

  test('every key has a value in both languages', () {
    for (final key in _keys(en)) {
      expect((en[key] as String).trim(), isNotEmpty, reason: 'en/$key');
      expect((bn[key] as String).trim(), isNotEmpty, reason: 'bn/$key');
    }
  });

  test('bn keeps every placeholder the en message uses', () {
    for (final key in _keys(en)) {
      final enMessage = en[key] as String;
      // ICU plural/select branches read like placeholders to a simple parser
      // (`=1{View All ...}`), so they are checked by the parity test instead.
      if (enMessage.contains(', plural,') || enMessage.contains(', select,')) {
        continue;
      }
      expect(
        _placeholders(bn[key] as String),
        containsAll(_placeholders(enMessage)),
        reason: key,
      );
    }
  });

  test('the screen sections are marked so labels stay findable', () {
    final markers = en.keys
        .where((k) => k.startsWith('@@_section_'))
        .toList(growable: false);
    expect(markers, isNotEmpty);
    for (final section in <String>[
      'settingsMain',
      'settingsAccountProfile',
      'settingsProfile',
      'settingsManageAccount',
      'settingsOnlineSync',
      'settingsBackupRestore',
      'settingsEditCourtSteps',
      'settingsEditCourtNames',
      'settingsCourtNamesSteps',
      'settingsItemList',
      'settingsCourtList',
      'settingsLowerCourtCategories',
      'settingsNotifications',
      'settingsLanguage',
      'settingsViewSettings',
      'settingsGuidelines',
      'settingsAbout',
      'settingsMoreAbout',
    ]) {
      expect(markers, contains('@@_section_$section'), reason: section);
    }
  });
}
