/// Bengali Material localizations for the time-picker window.
///
/// Flutter's Bengali Material bundle asks for a 24-hour clock
/// (`TimeOfDayFormat.H_colon_mm`), so the window Settings → Notifications opens
/// in বাংলা drops the AM/PM toggle and puts 0–23 on the dial: a different
/// window from the English one, which is the 12-hour window the mockup draws.
/// This bundle is the Bengali one with only that format switched to `h:mm a`.
/// Every string, weekday, tooltip and digit stays Bengali, and AM/PM keeps the
/// Latin letters Flutter's Bengali bundle already uses for them.
///
/// It is applied with `Localizations.override` around the picker alone, so no
/// other Material widget in the app changes behaviour.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';

/// Bengali Material strings and digits, laid out on the English 12-hour clock.
///
/// Only the clock format is overridden; the Bengali Material bundle supplies
/// every other string. The date and number formats the base class keeps are the
/// Bengali ones, so the hours and minutes it renders read `০৫:০০`.
class BengaliTimePickerLocalizations extends MaterialLocalizationBn {
  /// Builds the bundle with Bengali date and number formats.
  BengaliTimePickerLocalizations()
    : super(
        localeName: 'bn',
        fullYearFormat: DateFormat.y('bn'),
        compactDateFormat: DateFormat.yMd('bn'),
        shortDateFormat: DateFormat.yMMMd('bn'),
        mediumDateFormat: DateFormat.MMMEd('bn'),
        longDateFormat: DateFormat.yMMMMEEEEd('bn'),
        yearMonthFormat: DateFormat.yMMMM('bn'),
        shortMonthDayFormat: DateFormat.MMMd('bn'),
        decimalFormat: NumberFormat.decimalPattern('bn'),
        twoDigitZeroPaddedFormat: NumberFormat('00', 'bn'),
      );

  /// The English window's layout: `h:mm` with an AM/PM toggle beside it.
  ///
  /// Bengali Material asks for [TimeOfDayFormat.H_colon_mm] — the 24-hour dial
  /// with no day-period control at all.
  @override
  TimeOfDayFormat get timeOfDayFormatRaw => TimeOfDayFormat.h_colon_mm_space_a;
}

/// Serves [BengaliTimePickerLocalizations] for বাংলা and nothing else.
///
/// Handing this to `Localizations.override` first in the delegate list wins:
/// `Localizations` only loads the first delegate that supports the locale.
class BengaliTimePickerLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  /// Creates the delegate.
  const BengaliTimePickerLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'bn';

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      SynchronousFuture<MaterialLocalizations>(BengaliTimePickerLocalizations());

  @override
  bool shouldReload(covariant LocalizationsDelegate<MaterialLocalizations> old) =>
      false;
}
