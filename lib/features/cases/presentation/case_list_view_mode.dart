/// Compact ↔ extended ("table") case-list view plumbing.
///
/// The case-list screens share one stored preference — `case_list_display_mode`
/// (Settings → View Settings → Case List Display) — so the header toggle and the
/// Settings picker can never disagree. Screens read the live row through
/// [userSettingsStreamProvider]; this file owns the single write path.
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

/// Whether the extended view is the stored selection.
///
/// Reads the live settings row rather than the settings ViewModel: the
/// ViewModel reports `loading` between a write and its refresh, and a nullable
/// state would flash the compact list mid-toggle.
bool isCaseListExtendedView(UserSettings? settings) =>
    settings?.caseListDisplayMode == caseListViewModeExpanded;

/// Persists the compact ↔ extended choice.
///
/// The full row is read back before it is written so no other preference can be
/// lost (the settings ViewModel's one-field update falls back to defaults while
/// its state is loading). The ViewModel is then invalidated so the Settings
/// screens, which read it instead of the stream, show the new mode next time
/// they build — the same "the arrangement must survive" rule the bottom-nav
/// order fix (0.0.200) had to satisfy.
Future<void> setCaseListViewMode(WidgetRef ref, {required bool compact}) async {
  final repo = await ref.read(settingsRepositoryProvider.future);
  final current = await repo.getSettings();
  await repo.upsertSettings(
    current.copyWith(
      caseListDisplayMode: compact
          ? caseListViewModeCompact
          : caseListViewModeExpanded,
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

/// The live compact ↔ extended selection, safe to read during a build.
///
/// Defaults to the compact view until the stream's first emission, which is the
/// stored default for a fresh install.
bool watchCaseListExtendedView(WidgetRef ref) =>
    isCaseListExtendedView(ref.watch(userSettingsStreamProvider).value);
