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
import 'package:flutter/foundation.dart';
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
  } catch (error, stackTrace) {
    // Never break the picker, but leave a trace in debug: a missing plugin or
    // asset would otherwise be indistinguishable from "the phone is silent".
    assert(() {
      debugPrint('Gear tick failed: $error\n$stackTrace');
      return true;
    }());
  }
}

void _playGearClick() => unawaited(_playGearClickAsync());

/// Plays the gear tick when the visible hour/minute actually changes.
///
/// Flutter's time window reports no dial-change callback, so a [Listener] hears
/// the drag and the picker's own header is read after each frame: a tick plays
/// only when the displayed hour/minute changed, not for a drag that moves over
/// the window without changing the time.
class _ClickingTimePicker extends StatefulWidget {
  /// The stock time window.
  final Widget child;

  const _ClickingTimePicker({required this.child});

  @override
  State<_ClickingTimePicker> createState() => _ClickingTimePickerState();
}

class _ClickingTimePickerState extends State<_ClickingTimePicker> {
  /// Addresses the time window's subtree so its texts can be read.
  final GlobalKey _subtreeKey = GlobalKey();

  /// True while a finger is down, so hover or a stray move stays silent.
  bool _dragging = false;

  /// One comparison per frame is enough; extra pointer samples share it.
  bool _checkScheduled = false;

  /// The texts the window showed at the last comparison.
  List<String> _lastTexts = const <String>[];

  /// Logs the first real change of a drag once.
  bool _loggedChange = false;

  /// Every text the open window currently shows, in tree order.
  List<String> _visibleTexts() {
    final context = _subtreeKey.currentContext;
    if (context == null) return const <String>[];
    final texts = <String>[];
    void visit(Element element) {
      final widget = element.widget;
      if (widget is Text && widget.data != null) texts.add(widget.data!);
      element.visitChildren(visit);
    }

    visit(context as Element);
    return texts;
  }

  /// Compares the window's texts after the next frame; a changed hour or minute
  /// is the only thing that may play the tick.
  void _scheduleCheck() {
    if (_checkScheduled) return;
    _checkScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScheduled = false;
      if (!mounted) return;
      final texts = _visibleTexts();
      if (listEquals(texts, _lastTexts)) return;
      _lastTexts = texts;
      assert(() {
        if (!_loggedChange) {
          _loggedChange = true;
          debugPrint('Gear tick: time changed');
        }
        return true;
      }());
      gearClickPlayer();
    });
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: (_) {
      _dragging = true;
      _loggedChange = false;
      _lastTexts = _visibleTexts();
    },
    onPointerMove: (_) {
      if (_dragging) _scheduleCheck();
    },
    onPointerUp: (_) {
      _dragging = false;
      _scheduleCheck();
    },
    onPointerCancel: (_) {
      _dragging = false;
      _scheduleCheck();
    },
    child: KeyedSubtree(key: _subtreeKey, child: widget.child),
  );
}
