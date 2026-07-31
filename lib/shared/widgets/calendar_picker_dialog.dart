/// Dialog shell reserved for the Daily Cause List badge calendar.
///
/// The badge counts, month navigation, and date selection belong to Task 09.
/// This phase only provides a composable dialog boundary for that future UI.
library;

import 'package:flutter/material.dart';

/// A deliberately minimal dialog boundary for the Daily Cause List calendar.
///
/// [child] is an optional injection point for previews and future composition;
/// Task 09 will replace the default empty content with the badge calendar.
class CalendarPickerDialog extends StatelessWidget {
  /// Optional content rendered inside the dialog shell.
  final Widget child;

  /// Creates the Task 09-deferred calendar dialog shell.
  const CalendarPickerDialog({this.child = const SizedBox.shrink(), super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(child: child);
  }
}
