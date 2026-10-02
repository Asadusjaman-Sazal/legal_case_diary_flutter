/// Source-level guard for the bottom navigation's screen transition.
///
/// Switching screens from the bottom nav must not animate: the default
/// zoom-and-fade was making some users feel unwell, so those routes are built as
/// `NoTransitionPage`s. That is a one-word change to undo and an easy one to
/// make by accident while editing the router, and nothing else in the suite
/// would notice — a page transition is motion, not behaviour a widget test
/// asserts. So the declaration itself is pinned here, by reading the router.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:legal_case_diary/core/router/app_router.dart';
import 'package:legal_case_diary/shared/widgets/bottom_nav_bar.dart';

const String _routerSource = 'lib/core/router/app_router.dart';

/// `AppRoutes` constant name → its path, so a tab's route value can be traced
/// back to the constant the router declares it under.
const Map<String, String> _routeConstants = <String, String>{
  AppRoutes.dailyCauseList: 'dailyCauseList',
  AppRoutes.allCases: 'allCases',
  AppRoutes.activeCases: 'activeCases',
  AppRoutes.upcomingCases: 'upcomingCases',
  AppRoutes.overdueDates: 'overdueDates',
  AppRoutes.disposedCases: 'disposedCases',
  AppRoutes.notes: 'notes',
  AppRoutes.caseReference: 'caseReference',
  // Task 22: the Admin Panel is offered in the bottom bar, so the same
  // no-motion rule guards it as any other tab.
  AppRoutes.adminPanel: 'adminPanel',
};

/// One route's own declaration: from its `path:` up to the next `GoRoute(`.
String _routeDeclaration(String source, String name) {
  final marker = 'path: AppRoutes.$name,';
  final start = source.indexOf(marker);
  if (start < 0) return '';
  final end = source.indexOf('GoRoute(', start + marker.length);
  return source.substring(start, end < 0 ? source.length : end);
}

void main() {
  final source = File(_routerSource).readAsStringSync();

  test('every bottom nav screen is declared as a NoTransitionPage', () {
    for (final tab in bottomNavTabDefs) {
      final name = _routeConstants[tab.route];
      expect(
        name,
        isNotNull,
        reason:
            'tab "${tab.key}" points at ${tab.route}, which no AppRoutes '
            'constant here maps — add it so its transition is guarded too',
      );
      final declaration = _routeDeclaration(source, name!);
      expect(
        declaration,
        isNotEmpty,
        reason: '${tab.route} is not declared in the router',
      );
      expect(
        declaration,
        contains('NoTransitionPage'),
        reason:
            'the ${tab.key} screen switches with a transition; the bottom nav '
            'must change screens with no motion at all',
      );
      expect(
        declaration,
        isNot(contains('builder: (context')),
        reason:
            'the ${tab.key} screen is back on the animated page builder; '
            'use pageBuilder with NoTransitionPage',
      );
    }
  });

  test('the rule covers every screen the bottom nav can show', () {
    // Guards against a tab being added without this file noticing: the loop
    // above can only check routes that appear in its map.
    final mapped = _routeConstants.keys.toSet();
    for (final tab in bottomNavTabDefs) {
      expect(
        mapped,
        contains(tab.route),
        reason: 'tab "${tab.key}" (${tab.route}) is not guarded',
      );
    }
  });
}
