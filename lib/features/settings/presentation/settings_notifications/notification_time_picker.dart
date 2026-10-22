/// The one notification-time window used everywhere a time is chosen.
///
/// Settings → Notifications and the Add/Edit Case form's Notification Time
/// field both open this, so the two surfaces can never drift: the Bengali
/// 12-hour window ([BengaliTimePickerLocalizations]), the bold title, the dark
/// hour/minute and AM/PM boxes and the dialog action size travel with the call
/// rather than with a screen. [showNotificationTimePicker] returns the picked
/// time or null when the user backs out.
library;

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/l10n/generated/app_localizations.dart';
import 'bengali_time_picker_localizations.dart';

/// The dialog action size and text style the app's dialogs share — 112x48 at
/// 16 pt, the same pair `confirm_dialogs.dart`, `backup_dialogs.dart` and the
/// Exit App window use.
const Size _dialogActionSize = Size(112, 48);
const TextStyle _dialogActionTextStyle = TextStyle(fontSize: 16);

/// Cancel/OK and the picker's own colours.
///
/// The active hour, minute or AM/PM box is black with white text; the other
/// boxes stay white with black text, as the picker looked before. The help
/// text is the picker's title: bold, in the app's black.
final TimePickerThemeData notificationTimePickerTheme = TimePickerThemeData(
  cancelButtonStyle: TextButton.styleFrom(
    minimumSize: _dialogActionSize,
    textStyle: _dialogActionTextStyle,
  ),
  confirmButtonStyle: TextButton.styleFrom(
    minimumSize: _dialogActionSize,
    textStyle: _dialogActionTextStyle,
  ),
  helpTextStyle: AppTypography.titleMd.copyWith(
    color: AppColors.secondary,
    fontWeight: FontWeight.w700,
  ),
  hourMinuteColor: WidgetStateColor.resolveWith(
    (states) => states.contains(WidgetState.selected)
        ? AppColors.secondary
        : Colors.white,
  ),
  hourMinuteTextColor: WidgetStateColor.resolveWith(
    (states) => states.contains(WidgetState.selected)
        ? Colors.white
        : AppColors.secondary,
  ),
  dayPeriodColor: WidgetStateColor.resolveWith(
    (states) => states.contains(WidgetState.selected)
        ? AppColors.secondary
        : Colors.white,
  ),
  dayPeriodTextColor: WidgetStateColor.resolveWith(
    (states) => states.contains(WidgetState.selected)
        ? Colors.white
        : AppColors.secondary,
  ),
  dayPeriodBorderSide: const BorderSide(color: AppColors.outlineVariant),
);

/// Opens the notification-time window on [initialMinutes] (since midnight).
///
/// The window is Flutter's stock dialog, styled above: the 12-hour dial with
/// its AM/PM toggle (Flutter's Bengali bundle asks for a 24-hour clock, see
/// [BengaliTimePickerLocalizations]), the bold title, and the bundled gear tick
/// as the hour/minute hand is dragged.
Future<TimeOfDay?> showNotificationTimePicker(
  BuildContext context, {
  required int initialMinutes,
}) {
  final l = AppLocalizations.of(context);
  return showDialog<TimeOfDay>(
    context: context,
    builder: (context) => Localizations.override(
      context: context,
      delegates: const <LocalizationsDelegate<dynamic>>[
        BengaliTimePickerLocalizationsDelegate(),
      ],
      child: TimePickerTheme(
        data: notificationTimePickerTheme,
        child: _ClickingTimePicker(
          child: TimePickerDialog(
            initialTime: TimeOfDay(
              hour: initialMinutes ~/ 60,
              minute: initialMinutes % 60,
            ),
            helpText: l.notificationTimePicker_title,
          ),
        ),
      ),
    ),
  );
}

/// Plays the bundled gear tick. Tests replace this with a counter so the audio
/// plugin is never touched in a widget test.
@visibleForTesting
void Function() gearClickPlayer = _playGearClick;

/// The one low-latency player for the tick, created on first use.
AudioPlayer? _gearAudio;

/// Plays the gear tick, replacing a still-playing tick so a fast drag keeps a
/// crisp ratchet.
Future<void> _playGearClickAsync() async {
  try {
    var player = _gearAudio;
    if (player == null) {
      player = AudioPlayer(playerId: 'notification-time-gear');
      // Low latency keeps the tick on the hand's movement instead of after it.
      await player.setPlayerMode(PlayerMode.lowLatency);
      await player.setReleaseMode(ReleaseMode.stop);
      _gearAudio = player;
    }
    await player.stop();
    await player.play(AssetSource('sounds/gear_click.wav'));
  } catch (_) {
    // A device with no audio route must never break the time window.
  }
}

void _playGearClick() => unawaited(_playGearClickAsync());

/// Plays the gear tick as the hour/minute hand is dragged.
///
/// Flutter's time window reports no dial-move callback, so a [Listener] hears
/// the drags that move it. The ticks are throttled to a ratchet-like pace
/// instead of firing on every pointer sample.
class _ClickingTimePicker extends StatefulWidget {
  /// The stock time window.
  final Widget child;

  const _ClickingTimePicker({required this.child});

  @override
  State<_ClickingTimePicker> createState() => _ClickingTimePickerState();
}

class _ClickingTimePickerState extends State<_ClickingTimePicker> {
  /// Shortest gap between two clicks while a hand is dragged.
  static const Duration _clickGap = Duration(milliseconds: 80);

  DateTime? _lastClick;

  /// True while a finger is down, so a stray move with no press stays silent.
  bool _dragging = false;

  void _playClick(PointerMoveEvent event) {
    if (!_dragging) return;
    final now = DateTime.now();
    final last = _lastClick;
    if (last != null && now.difference(last) < _clickGap) return;
    _lastClick = now;
    gearClickPlayer();
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: (_) => _dragging = true,
    onPointerMove: _playClick,
    onPointerUp: (_) => _dragging = false,
    onPointerCancel: (_) => _dragging = false,
    child: widget.child,
  );
}
