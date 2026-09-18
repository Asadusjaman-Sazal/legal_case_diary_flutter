/// Live per-user settings providers shared across features.
///
/// Settings are always per-user (Universal Working Rule 11), so readers that
/// must reflect a change made elsewhere — the case screens' view toggle, the
/// navigation drawer's side-nav options — watch the row's stream instead of
/// taking a one-shot read that can go stale.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/data/settings_repository.dart';
import 'repository_providers.dart';

/// Watches the live [UserSettings] row.
///
/// Widgets that render a stored preference should read this provider so a
/// write made anywhere in the app reaches them without a rebuild-time refresh.
/// Writers must still go through `settingsViewModelProvider` (or the
/// repository), which is what updates the row this stream is following.
final userSettingsStreamProvider = StreamProvider<UserSettings>((ref) async* {
  final repo = await ref.watch(settingsRepositoryProvider.future);
  yield* repo.watchSettings();
});
