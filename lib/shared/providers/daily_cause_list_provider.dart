import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/date_utils.dart' show AppDateUtils;

/// In-memory provider for the Daily Cause List's currently selected date.
///
/// Holds the Bangladesh civil date (epoch ms at start of day). It persists for
/// the app's lifetime — surviving navigation away from and back to the screen —
/// and resets to today only on a fresh app start or when the user picks another
/// date. It is intentionally not persisted to disk.
class DailyCauseListSelectedDateNotifier extends Notifier<int> {
  @override
  int build() => AppDateUtils.bangladeshTodayStartOfDay();

  /// Updates the selected date.
  void select(int date) => state = date;
}

/// Public provider for the Daily Cause List's selected civil date.
final dailyCauseListSelectedDateProvider =
    NotifierProvider<DailyCauseListSelectedDateNotifier, int>(
  DailyCauseListSelectedDateNotifier.new,
);
