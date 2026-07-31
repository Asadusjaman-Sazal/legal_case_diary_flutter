/// Plain date-picker helpers for forms and non-calendar date fields.
///
/// The badge calendar is intentionally excluded; it belongs only to the Daily
/// Cause List and is implemented separately in Task 09.
library;

import 'package:flutter/material.dart';

/// Returns the date-only value used as the default picker selection.
///
/// Keeping this calculation separate makes the today-default rule reusable and
/// straightforward to test without opening a platform dialog.
DateTime plainDatePickerInitialDate([DateTime? now]) {
  return DateUtils.dateOnly(now ?? DateTime.now());
}

/// Opens a plain Material date picker defaulting to today.
///
/// [initialDate] may be supplied by an edit form. When omitted, the picker
/// opens on today's date. The returned value is date-only, or `null` when the
/// user cancels.
Future<DateTime?> showPlainDatePicker(
  BuildContext context, {
  DateTime? initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
}) async {
  final today = plainDatePickerInitialDate();
  final effectiveFirstDate = DateUtils.dateOnly(
    firstDate ?? DateTime(today.year - 100),
  );
  final effectiveLastDate = DateUtils.dateOnly(
    lastDate ?? DateTime(today.year + 100),
  );
  if (effectiveFirstDate.isAfter(effectiveLastDate)) {
    throw ArgumentError.value(
      lastDate,
      'lastDate',
      'must be on or after firstDate',
    );
  }
  final requestedDate = DateUtils.dateOnly(initialDate ?? today);
  final effectiveInitialDate = requestedDate.isBefore(effectiveFirstDate)
      ? effectiveFirstDate
      : requestedDate.isAfter(effectiveLastDate)
      ? effectiveLastDate
      : requestedDate;

  return showDatePicker(
    context: context,
    initialDate: effectiveInitialDate,
    firstDate: effectiveFirstDate,
    lastDate: effectiveLastDate,
  );
}
