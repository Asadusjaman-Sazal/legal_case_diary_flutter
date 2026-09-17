/// ViewModel for the user settings feature.
///
/// Exposes the current [UserSettings] reactively. UI code should use
/// `.select()` to subscribe only to the properties it needs, e.g.
/// `ref.watch(settingsViewModelProvider.select((s) => s.valueOrNull?.language))`.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_providers.dart';
import '../data/settings_repository.dart';

/// AsyncNotifier for the settings feature.
///
/// The initial build loads settings once from the repository. Further updates
/// are reflected by calling [saveSettings] or [refresh]; external changes are
/// not automatically watched in this phase.
class SettingsViewModel extends AsyncNotifier<UserSettings> {
  /// Riverpod provider for [SettingsViewModel].
  static final provider = AsyncNotifierProvider<SettingsViewModel, UserSettings>(
    () => SettingsViewModel(),
  );

  @override
  FutureOr<UserSettings> build() async {
    final repo = await ref.watch(settingsRepositoryProvider.future);
    return repo.getSettings();
  }

  /// Reloads settings and updates state.
  Future<void> refresh() async {
    state = const AsyncValue<UserSettings>.loading();
    try {
      final repo = await ref.read(settingsRepositoryProvider.future);
      final settings = await repo.getSettings();
      state = AsyncValue.data(settings);
    } catch (error, stackTrace) {
      state = AsyncValue<UserSettings>.error(error, stackTrace);
    }
  }

  /// Persists the given settings and refreshes the state.
  Future<void> saveSettings(UserSettings settings) async {
    final repo = await ref.read(settingsRepositoryProvider.future);
    await repo.upsertSettings(settings);
    await refresh();
  }

  /// Applies [transform] to the settings currently held and persists the
  /// result, so a Settings screen changes one field without rebuilding the
  /// whole [UserSettings] value. Named `updateSettings` because Riverpod 3's
  /// notifier already defines `update`.
  Future<void> updateSettings(
    UserSettings Function(UserSettings current) transform,
  ) async {
    final current = state.value ?? const UserSettings();
    await saveSettings(transform(current));
  }
}

/// Global provider alias for the settings ViewModel.
final settingsViewModelProvider = SettingsViewModel.provider;
