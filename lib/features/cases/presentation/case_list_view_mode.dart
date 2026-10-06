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
import '../../../core/utils/date_utils.dart';
import '../../accounts_and_profile/data/account_mode.dart';
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
  // The stored row changed: ask for the premium preference push that carries
  // it to the account. Detached, so the toggle never waits on the network.
  ref.read(pushPreferencesProvider)();
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
  ref.read(pushPreferencesProvider)();
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

/// The court groups the user has folded away in [screenId], safe to read during
/// a build.
///
/// A fold lasts one day: only folds stamped with today's Bangladesh civil day
/// count, so the first time a grouped case list is opened on a new day every
/// court is showing again. Empty is also what the stream's first emission and a
/// fresh install give, both of which mean "every court opens expanded".
Set<String> watchCaseTableCollapsedCourts(WidgetRef ref, String screenId) =>
    _foldedCourtsToday(ref.watch(userSettingsStreamProvider).value, screenId);

/// The folds in [screenId] that were made today, or none when the last one was
/// made on an earlier day.
///
/// The stamp is compared against [AppDateUtils.bangladeshTodayStartOfDay], the
/// app's civil day everywhere, so "today" turns over at Bangladesh midnight. A
/// missing stamp counts as an earlier day, which is what an install that
/// upgraded from a build without stamps gets: fully expanded.
Set<String> _foldedCourtsToday(UserSettings? settings, String screenId) {
  if (settings?.caseTableCollapsedDays[screenId] !=
      AppDateUtils.bangladeshTodayStartOfDay()) {
    // Mutable: the write path adds the court the user just folded to this set.
    return <String>{};
  }
  return {...?settings?.caseTableCollapsedCourts[screenId]};
}

/// Persists one court group's folded ↔ expanded choice in [screenId].
///
/// Same read-modify-write contract as [setCaseListViewMode]: the whole stored
/// row is read back first so no other preference can be dropped, the entry is
/// removed entirely once a screen has nothing folded (so a fresh install and a
/// fully reopened screen store the same row), and the settings ViewModel is
/// invalidated so the Settings screens keep showing the row just written.
///
/// The write starts from [_foldedCourtsToday], so an earlier day's folds can
/// never come back when the user folds something new — the new day's first fold
/// replaces them and is stamped with today.
Future<void> setCaseTableCourtCollapsed(
  WidgetRef ref, {
  required String screenId,
  required String courtId,
  required bool collapsed,
}) async {
  final repo = await ref.read(settingsRepositoryProvider.future);
  final current = await repo.getSettings();
  final groups = <String, List<String>>{
    ...current.caseTableCollapsedCourts,
  };
  final days = <String, int>{...current.caseTableCollapsedDays};
  final ids = _foldedCourtsToday(current, screenId);
  if (collapsed) {
    ids.add(courtId);
  } else {
    ids.remove(courtId);
  }
  if (ids.isEmpty) {
    groups.remove(screenId);
    days.remove(screenId);
  } else {
    groups[screenId] = ids.toList();
    days[screenId] = AppDateUtils.bangladeshTodayStartOfDay();
  }
  await repo.upsertSettings(
    current.copyWith(
      caseTableCollapsedCourts: groups,
      caseTableCollapsedDays: days,
    ),
  );
  ref.read(pushPreferencesProvider)();
  ref.invalidate(settingsViewModelProvider);
}
