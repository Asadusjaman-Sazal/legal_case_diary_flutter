/// The one notification-time window used everywhere a time is chosen.
///
/// Settings → Notifications and the Add/Edit Case form's Notification Time
/// field both open this, so the two surfaces can never drift: the Bengali
/// 12-hour window ([BengaliTimePickerLocalizations]) and the dialog action size
/// travel with the call rather than with a screen. [showNotificationTimePicker]
/// returns the picked time or null when the user backs out.
library;

import 'package:flutter/material.dart';

import 'bengali_time_picker_localizations.dart';

/// The dialog action size and text style the app's dialogs share — 112x48 at
/// 16 pt, the same pair `confirm_dialogs.dart`, `backup_dialogs.dart` and the
/// Exit App window use.
const Size _dialogActionSize = Size(112, 48);
const TextStyle _dialogActionTextStyle = TextStyle(fontSize: 16);

/// Cancel/OK inside the time window, sized like every other dialog button.
///
/// Flutter sizes them to their own label, which drifts with the language.
final TimePickerThemeData notificationTimePickerTheme = TimePickerThemeData(
  cancelButtonStyle: TextButton.styleFrom(
    minimumSize: _dialogActionSize,
    textStyle: _dialogActionTextStyle,
  ),
  confirmButtonStyle: TextButton.styleFrom(
    minimumSize: _dialogActionSize,
    textStyle: _dialogActionTextStyle,
  ),
);

/// Opens the notification-time window on [initialMinutes] (since midnight).
///
/// The window is Flutter's, but two things are pinned so বাংলা shows what
/// English shows: the 12-hour dial with its AM/PM toggle (Flutter's Bengali
/// bundle asks for a 24-hour clock, see [BengaliTimePickerLocalizations]) and
/// the dialog action size above.
Future<TimeOfDay?> showNotificationTimePicker(
  BuildContext context, {
  required int initialMinutes,
}) => showTimePicker(
  context: context,
  initialTime: TimeOfDay(
    hour: initialMinutes ~/ 60,
    minute: initialMinutes % 60,
  ),
  builder: (context, child) => Localizations.override(
    context: context,
    delegates: const <LocalizationsDelegate<dynamic>>[
      BengaliTimePickerLocalizationsDelegate(),
    ],
    child: TimePickerTheme(
      data: notificationTimePickerTheme,
      child: child ?? const SizedBox.shrink(),
    ),
  ),
);
