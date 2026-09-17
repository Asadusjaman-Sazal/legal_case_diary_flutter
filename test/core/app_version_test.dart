/// Guards the bundled [appVersion] constant.
///
/// The About screens show this constant, so it has to agree with the two places
/// the project records its version: `pubspec.yaml` and the `## Current Version`
/// line in `docs/version_history.md`. The phase-completion protocol updates all
/// three, and this test fails the moment one of them is forgotten.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/core/constants/app_version.dart';

/// Version declared by `pubspec.yaml`'s `version:` line (build metadata
/// stripped, so `0.0.176+1` would compare as `0.0.176`).
String _pubspecVersion() {
  final line = File(
    'pubspec.yaml',
  ).readAsLinesSync().firstWhere((line) => line.startsWith('version:'));
  return line.split(':')[1].trim().split('+').first;
}

/// Version named by the `## Current Version` section of the history file.
String _documentedVersion() {
  final lines = File('docs/version_history.md').readAsLinesSync();
  final start = lines.indexWhere((line) => line.trim() == '## Current Version');
  final entry = lines
      .skip(start + 1)
      .firstWhere((line) => line.startsWith('Version: '));
  return entry.split(' - ').first.replaceFirst('Version: ', '').trim();
}

void main() {
  test('bundled version matches pubspec.yaml', () {
    expect(appVersion, _pubspecVersion());
  });

  test('bundled version matches docs/version_history.md Current Version', () {
    expect(appVersion, _documentedVersion());
  });
}
