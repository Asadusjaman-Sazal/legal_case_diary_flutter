/// Plain date-picker helpers for forms and non-calendar date fields.
///
/// The badge calendar is intentionally excluded; it belongs only to the Daily
/// Cause List and is implemented separately in Task 09.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import '../../core/constants/app_spacing.dart';

/// Material date-picker localization used by the shared calendar picker.
class _FullDateMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const _FullDateMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      locale.languageCode == 'en' || locale.languageCode == 'bn';

  @override
  Future<MaterialLocalizations> load(Locale locale) {
    final localeName = locale.languageCode;
    final fullYearFormat = intl.DateFormat.y(localeName);
    final compactDateFormat = intl.DateFormat.yMd(localeName);
    final shortDateFormat = intl.DateFormat.yMMMd(localeName);
    final mediumDateFormat = intl.DateFormat('MMMM d, EEEE', localeName);
    final longDateFormat = intl.DateFormat.yMMMMEEEEd(localeName);
    final yearMonthFormat = intl.DateFormat.yMMMM(localeName);
    final shortMonthDayFormat = intl.DateFormat.MMMd(localeName);
    final decimalFormat = intl.NumberFormat.decimalPattern(localeName);
    final twoDigitZeroPaddedFormat = intl.NumberFormat('00', localeName);

    final localizations = localeName == 'bn'
        ? MaterialLocalizationBn(
            fullYearFormat: fullYearFormat,
            compactDateFormat: compactDateFormat,
            shortDateFormat: shortDateFormat,
            mediumDateFormat: mediumDateFormat,
            longDateFormat: longDateFormat,
            yearMonthFormat: yearMonthFormat,
            shortMonthDayFormat: shortMonthDayFormat,
            decimalFormat: decimalFormat,
            twoDigitZeroPaddedFormat: twoDigitZeroPaddedFormat,
          )
        : MaterialLocalizationEn(
            fullYearFormat: fullYearFormat,
            compactDateFormat: compactDateFormat,
            shortDateFormat: shortDateFormat,
            mediumDateFormat: mediumDateFormat,
            longDateFormat: longDateFormat,
            yearMonthFormat: yearMonthFormat,
            shortMonthDayFormat: shortMonthDayFormat,
            decimalFormat: decimalFormat,
            twoDigitZeroPaddedFormat: twoDigitZeroPaddedFormat,
          );
    return SynchronousFuture<MaterialLocalizations>(localizations);
  }

  @override
  bool shouldReload(_FullDateMaterialLocalizationsDelegate old) => false;
}

const _englishPickerMonths = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const _bengaliPickerMonths = <String>[
  'জানুঃ',
  'ফেব্রুঃ',
  'মার্চ',
  'এপ্রিল',
  'মে',
  'জুন',
  'জুলাই',
  'আগস্ট',
  'সেপ্টঃ',
  'অক্টোঃ',
  'নভেঃ',
  'ডিসেঃ',
];

const _englishPickerWeekdays = <String>[
  'Sun',
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
];

const _bengaliPickerWeekdays = <String>[
  'রবি',
  'সোম',
  'মঙ্গল',
  'বুধ',
  'বৃহঃ',
  'শুক্র',
  'শনি',
];

String _formatPickerHeaderDate(DateTime date, Locale locale) {
  final isBengali = locale.languageCode == 'bn';
  final monthLabels = isBengali ? _bengaliPickerMonths : _englishPickerMonths;
  final weekdayLabels = isBengali
      ? _bengaliPickerWeekdays
      : _englishPickerWeekdays;
  final day = intl.NumberFormat.decimalPattern(
    isBengali ? 'bn' : 'en',
  ).format(date.day);
  return '${monthLabels[date.month - 1]} $day, '
      '${weekdayLabels[date.weekday % DateTime.daysPerWeek]}';
}

class _PlainDatePickerDialog extends StatefulWidget {
  const _PlainDatePickerDialog({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.styleActions,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final bool styleActions;

  @override
  State<_PlainDatePickerDialog> createState() => _PlainDatePickerDialogState();
}

class _PlainDatePickerDialogState extends State<_PlainDatePickerDialog> {
  late DateTime _selectedDate = widget.initialDate;

  void _closeWithDate() => Navigator.of(context).pop(_selectedDate);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final datePickerTheme = DatePickerTheme.of(context);
    final defaults = DatePickerTheme.defaults(context);
    final headerForegroundColor =
        datePickerTheme.headerForegroundColor ??
        defaults.headerForegroundColor ??
        theme.colorScheme.onPrimary;
    final headerStyle =
        (datePickerTheme.headerHeadlineStyle ??
                defaults.headerHeadlineStyle ??
                theme.textTheme.headlineSmall)
            ?.copyWith(color: headerForegroundColor);
    final actionButtonStyle = widget.styleActions
        ? TextButton.styleFrom(
            alignment: Alignment.center,
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            fixedSize: const Size(132, 52),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          )
        : TextButton.styleFrom(
            alignment: Alignment.center,
            minimumSize: const Size(88, 52),
          );

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SizedBox(
          key: const ValueKey('plain-date-picker-surface'),
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                color:
                    datePickerTheme.headerBackgroundColor ??
                    defaults.headerBackgroundColor,
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                child: Text(
                  _formatPickerHeaderDate(
                    _selectedDate,
                    Localizations.localeOf(context),
                  ),
                  style: headerStyle,
                ),
              ),
              CalendarDatePicker(
                initialDate: _selectedDate,
                firstDate: widget.firstDate,
                lastDate: widget.lastDate,
                onDateChanged: (date) => setState(() => _selectedDate = date),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: widget.styleActions ? 132 : null,
                      height: 52,
                      child: TextButton(
                        style: actionButtonStyle,
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          MaterialLocalizations.of(context).cancelButtonLabel,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: widget.styleActions ? 132 : null,
                      height: 52,
                      child: TextButton(
                        style: actionButtonStyle,
                        onPressed: _closeWithDate,
                        child: Text(
                          MaterialLocalizations.of(context).okButtonLabel,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
  bool styleActions = false,
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

  return showDialog<DateTime>(
    context: context,
    builder: (context) => Localizations.override(
      context: context,
      delegates: const <LocalizationsDelegate<dynamic>>[
        _FullDateMaterialLocalizationsDelegate(),
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      child: _PlainDatePickerDialog(
        initialDate: effectiveInitialDate,
        firstDate: effectiveFirstDate,
        lastDate: effectiveLastDate,
        styleActions: styleActions,
      ),
    ),
  );
}
