/// Compact ↔ extended ("table") case-list view plumbing.
///
/// The choice is **per screen**: the header toggle on All Cases can show the
/// table while Daily Cause List stays a card list, and each screen remembers
/// its own choice across restarts. Screens read the live row through
/// [userSettingsStreamProvider]; this file owns the single write path.
///
/// Storage is the per-screen map `case_list_display_modes` (screen id → mode)
/// inside the existing `view_settings_json` blob, with the older global
/// `case_list_display_mode` (Settings → View Settings → Case List Display) kept
/// as the default for every screen the user has not switched on its own. A
/// screen id is the bottom-navigation key, the app's single source of screen
/// identity, so the two can never drift apart.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_providers.dart';
import '../../../core/providers/settings_providers.dart';
import '../../settings/data/settings_repository.dart';
import '../../settings/presentation/settings_viewmodel.dart';

/// Stored value: the compact card list (the app default).
const String caseListViewModeCompact = 'compact';

/// Stored value: the extended horizontal-row view.
const String caseListViewModeExpanded = 'expanded';

/// Stable per-screen ids for the view choice.
///
/// Each id is the screen's bottom-navigation key (`bottomNavTabDefs`), so a
/// stored choice follows the screen wherever it is placed and never collides
/// with another.
class CaseListScreenId {
  CaseListScreenId._();

  /// All Cases.
  static const String allCases = 'all_cases';

  /// Active Cases.
  static const String active = 'active';

  /// Daily Cause List.
  static const String dailyCauseList = 'daily_cause_list';

  /// Overdue Dates.
  static const String overdue = 'overdue';

  /// Upcoming Cases.
  static const String upcoming = 'upcoming';

  /// Disposed Cases.
  static const String disposed = 'disposed';
}

/// Whether [screenId] should render the extended view.
///
/// The screen's own stored choice wins; a screen that has never been switched
/// follows the global [UserSettings.caseListDisplayMode], which is the app
/// default (`compact`) on a fresh install.
bool isCaseListExtendedView(UserSettings? settings, String screenId) {
  final mode =
      settings?.caseListDisplayModes[screenId] ?? settings?.caseListDisplayMode;
  return mode == caseListViewModeExpanded;
}

/// Persists one screen's compact ↔ extended choice.
///
/// The full row is read back before it is written so no other preference can be
/// lost (the settings ViewModel's one-field update falls back to defaults while
/// its state is loading). The ViewModel is then invalidated so the Settings
/// screens, which read it instead of the stream, show the new mode next time
/// they build — the same "the arrangement must survive" rule the bottom-nav
/// order fix (0.0.200) had to satisfy.
Future<void> setCaseListViewMode(
  WidgetRef ref, {
  required String screenId,
  required bool compact,
}) async {
  final repo = await ref.read(settingsRepositoryProvider.future);
  final current = await repo.getSettings();
  await repo.upsertSettings(
    current.copyWith(
      caseListDisplayModes: <String, String>{
        ...current.caseListDisplayModes,
        screenId: compact ? caseListViewModeCompact : caseListViewModeExpanded,
      },
    ),
  );
  ref.invalidate(settingsViewModelProvider);
}

/// Persists the extended view's column widths after a resize drag.
///
/// Same read-modify-write contract as [setCaseListViewMode]: the whole stored
/// row is read back first so no other preference can be dropped, and the
/// settings ViewModel is invalidated so the Settings screens keep showing the
/// row that was just written.
Future<void> setCaseTableColumnWidths(
  WidgetRef ref,
  Map<String, double> widths,
) async {
  final repo = await ref.read(settingsRepositoryProvider.future);
  final current = await repo.getSettings();
  await repo.upsertSettings(current.copyWith(caseTableColumnWidths: widths));
  ref.invalidate(settingsViewModelProvider);
}

/// The live compact ↔ extended selection for [screenId], safe to read during a
/// build.
///
/// Defaults to the compact view until the stream's first emission, which is the
/// stored default for a fresh install.
bool watchCaseListExtendedView(WidgetRef ref, String screenId) =>
    isCaseListExtendedView(
      ref.watch(userSettingsStreamProvider).value,
      screenId,
    );
