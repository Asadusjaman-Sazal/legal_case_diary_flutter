/// Source-level guard for the unified active black.
///
/// Every active / selected state now uses the same black as the buttons, the
/// side menu and the Language picker; the action blue was retired, and the pale
/// blue tints became neutral grey. A colour is a one-line change that no widget
/// test would notice, so the palette and the active-state widgets are pinned
/// here by reading the sources.
///
/// One exception is allowed, and only this one: the Case Detail screen's Next
/// Date card, which the user asked to keep its long-standing blue. It is named
/// in [_allowedBlues] rather than left unnamed, so the rule stays enforced
/// everywhere else.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _colorsSource = 'lib/core/constants/app_colors.dart';

/// The hex values that were the app's blue accents; none may survive in `lib/`.
const List<String> _retiredBlues = <String>[
  '0xFF2563EB',
  '0xFF316BF3',
  '0xFFDBE1FF',
  '0xFFB4C5FF',
  '0xFFD3E4FE',
  '0xFFDAE2FD',
  '0xFFBEC6E0',
  '0xFF0D2563EB',
];

/// The one deliberate exception to the blue ban: the Case Detail screen's Next
/// Date card, which the user asked to keep the blue it has always had. Keyed by
/// the normalized (`/`-separated) source path, so the map works on Windows too.
/// Every other file still counts as an offender.
const Map<String, Set<String>> _allowedBlues = <String, Set<String>>{
  'lib/features/cases/presentation/case_detail/case_detail_screen.dart': <String>{
    '0xFF316BF3',
  },
};

/// Widgets whose selected state used the dark ink instead of the pure black.
const List<String> _activeStateWidgets = <String>[
  'lib/shared/widgets/bottom_nav_bar.dart',
  'lib/shared/widgets/calendar_picker_dialog.dart',
  'lib/shared/widgets/date_picker_helper.dart',
  'lib/features/settings/presentation/settings_controls.dart',
  'lib/features/cases/presentation/daily_cause_list/daily_cause_list_screen.dart',
];

void main() {
  test('the active colour tokens are black, not blue', () {
    final source = File(_colorsSource).readAsStringSync();
    expect(
      source,
      contains('static const Color secondary = Color(0xFF000000);'),
      reason: 'the active/selected accent must be the unified black',
    );
    expect(
      source,
      contains('static const Color secondaryContainer = Color(0xFF000000);'),
      reason: 'the highlight-container fill must be the unified black',
    );
  });

  test('no blue accent survives in lib/ outside the documented exception', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final normalizedPath = entity.path.replaceAll(r'\', '/');
      final allowed = _allowedBlues[normalizedPath] ?? const <String>{};
      final text = entity.readAsStringSync();
      for (final blue in _retiredBlues) {
        if (text.contains(blue) && !allowed.contains(blue)) {
          offenders.add('$normalizedPath: $blue');
        }
      }
      if (RegExp(r'Colors\.blue\b').hasMatch(text)) {
        offenders.add('$normalizedPath: Colors.blue');
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('the active-state widgets mark their choice with Colors.black', () {
    for (final path in _activeStateWidgets) {
      expect(
        File(path).readAsStringSync(),
        contains('Colors.black'),
        reason: '$path should mark its active state with the unified black',
      );
    }
  });
}
