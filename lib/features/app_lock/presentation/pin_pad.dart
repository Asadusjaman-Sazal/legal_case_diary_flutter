/// The App Lock pin pad: four dots, a numeric keypad, and the dialog that
/// drives a multi-step pin flow.
///
/// One pad serves every flow so they cannot drift apart visually: setup
/// (choose, then confirm), change (prove the old pin, then choose a new one),
/// and — through its own overlay logic in `app_lock_scope.dart` — the lock
/// screen itself. The pad owns only the digits under the dots; what an entered
/// pin *means* is decided by [PinPadStage], so the security decisions stay in
/// the callers that make them.
library;

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/utils/date_utils.dart';
import '../data/app_lock_store.dart';

/// One step of a pin flow.
class PinPadStage {
  /// Creates the stage.
  const PinPadStage({
    required this.title,
    this.verify,
    this.error,
    this.biometrics,
    this.restartAt = -1,
  });

  /// The dialog's title while this stage is current.
  final String title;

  /// How a complete pin is judged.
  ///
  /// Null means "accept it as captured" — the stage exists only to record the
  /// pin (the first entry of a setup, the new pin of a change). When it is
  /// given, returning false shows [error] and restarts the stage's entry, and
  /// the pin is never captured, so a rejected one cannot be reused.
  final Future<bool> Function(String pin, List<String> captured)? verify;

  /// Shown under the dots when [verify] says no.
  final String? error;

  /// The fingerprint check for this stage, or null when no glyph is shown.
  ///
  /// A `true` from it completes the stage the way a correct pin would, so a
  /// caller only passes it on stages where proving identity is acceptable in
  /// place of the pin — never on a stage that exists to capture one.
  final Future<bool> Function()? biometrics;

  /// Where a rejected pin sends the flow, or -1 to stay on this stage.
  ///
  /// A wrong *current* pin should simply be typed again; a mismatched
  /// confirmation invalidates everything proved so far and sends the user back
  /// — the stage the caller names. Captures from that stage onward are
  /// discarded, so the pins re-entered afterwards are the ones judged.
  final int restartAt;
}

/// Shows a pin flow over [context] and returns the pins the flow captured —
/// one per capturing stage — or null when the user cancelled.
Future<List<String>?> showPinFlowDialog(
  BuildContext context, {
  required List<PinPadStage> stages,
  required String cancelLabel,
}) => showDialog<List<String>>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _PinFlowDialog(stages: stages, cancelLabel: cancelLabel),
);

/// The pad: dots, keypad, message line, and the optional fingerprint glyph.
///
/// The caller keys the pad by stage and attempt, so every fresh attempt
/// rebuilds with an empty entry — which is also what makes a wrong pin shake
/// once per failure rather than on every message update.
class PinPad extends StatefulWidget {
  /// Creates the pad.
  const PinPad({
    super.key,
    this.message = '',
    this.errorMessage = false,
    this.enabled = true,
    this.showBiometrics = false,
    this.biometricsTooltip = '',
    required this.onCompleted,
    this.onBiometrics,
  });

  /// The line under the dots; empty hides it.
  final String message;

  /// Whether [message] is a failure (red) rather than neutral.
  final bool errorMessage;

  /// False while a verification runs or a lockout counts down.
  final bool enabled;

  /// Whether the fingerprint glyph is shown.
  final bool showBiometrics;

  /// Its tooltip; may be empty when the glyph is hidden.
  final String biometricsTooltip;

  /// Called with exactly four digits.
  final ValueChanged<String> onCompleted;

  /// The glyph's tap; null leaves it inert.
  final VoidCallback? onBiometrics;

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> with SingleTickerProviderStateMixin {
  /// A shake that ends where it started: +10, −10, back to zero, so neither a
  /// completed nor an interrupted animation leaves the keypad off-centre.
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );
  late final Animation<double> _slide = TweenSequence<double>([
    TweenSequenceItem(tween: Tween<double>(begin: 0, end: 10), weight: 1),
    TweenSequenceItem(tween: Tween<double>(begin: 10, end: -10), weight: 1),
    TweenSequenceItem(tween: Tween<double>(begin: -10, end: 0), weight: 1),
  ]).animate(_shake);

  String _entered = '';

  @override
  void initState() {
    super.initState();
    // A pad mounted already in an error state (its caller re-keyed it for the
    // next attempt) shakes immediately; a mount without an error stays still.
    if (widget.errorMessage) _shake.forward(from: 0);
  }

  @override
  void didUpdateWidget(PinPad old) {
    super.didUpdateWidget(old);
    if (widget.errorMessage && !old.errorMessage) _shake.forward(from: 0);
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  void _tap(String digit) {
    if (!widget.enabled || _entered.length >= appLockPinLength) return;
    _entered += digit;
    if (_entered.length == appLockPinLength) {
      widget.onCompleted(_entered);
    } else {
      setState(() {});
    }
  }

  void _backspace() {
    if (!widget.enabled || _entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = l.localeName;

    return AnimatedBuilder(
      animation: _slide,
      builder: (context, child) =>
          Transform.translate(offset: Offset(_slide.value, 0), child: child),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Dots(
            filled: _entered.length,
            error: widget.errorMessage,
            length: appLockPinLength,
          ),
          // A reserved line, so a message appearing never jumps the keypad.
          SizedBox(
            height: 40,
            child: Center(
              child: Text(
                widget.message,
                key: const ValueKey('pin-pad-message'),
                textAlign: TextAlign.center,
                style: AppTypography.bodyMd.copyWith(
                  color: widget.errorMessage
                      ? AppColors.error
                      : AppColors.onSurfaceVariant,
                ),
              ),
            ),
          ),
          // Keypad: 1-9 over three rows, then empty / 0 / backspace, with
          // every digit in the active language's numerals.
          for (final row in const <List<String>>[
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
          ])
            Row(children: [for (final d in row) _digitKey(d, locale)]),
          Row(
            children: [
              const Expanded(child: SizedBox.shrink()),
              _digitKey('0', locale),
              Expanded(
                child: Center(
                  child: IconButton(
                    key: const ValueKey('pin-pad-backspace'),
                    onPressed: widget.enabled && _entered.isNotEmpty
                        ? _backspace
                        : null,
                    tooltip: l.sharedActions_delete,
                    icon: Icon(
                      Icons.backspace_outlined,
                      color: widget.enabled && _entered.isNotEmpty
                          ? AppColors.onSurface
                          : AppColors.outlineVariant,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (widget.showBiometrics) ...[
            const SizedBox(height: AppSpacing.sm),
            IconButton(
              key: const ValueKey('pin-pad-fingerprint'),
              onPressed: widget.enabled ? widget.onBiometrics : null,
              tooltip: widget.biometricsTooltip,
              iconSize: 34,
              icon: Icon(
                Icons.fingerprint,
                color: widget.enabled
                    ? AppColors.primary
                    : AppColors.outlineVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// One digit button, 120 × 52 of touch area.
  Widget _digitKey(String digit, String locale) => Expanded(
    child: Center(
      child: InkWell(
        onTap: widget.enabled ? () => _tap(digit) : null,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: SizedBox(
          width: 64,
          height: 52,
          child: Center(
            child: Text(
              AppDateUtils.formatDigits(
                int.parse(digit),
                locale,
                grouping: false,
              ),
              style: AppTypography.titleLg.copyWith(
                color: widget.enabled
                    ? AppColors.onSurface
                    : AppColors.outlineVariant,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// The entry dots: filled ones are the digits typed so far.
class _Dots extends StatelessWidget {
  const _Dots({required this.filled, required this.error, required this.length});

  final int filled;
  final bool error;
  final int length;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (var i = 0; i < length; i++)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < filled
                  ? (error ? AppColors.error : AppColors.primary)
                  : null,
              border: Border.all(
                color: error ? AppColors.error : AppColors.outlineVariant,
              ),
            ),
          ),
        ),
    ],
  );
}

/// The dialog that walks its stages, one entered pin at a time.
class _PinFlowDialog extends StatefulWidget {
  const _PinFlowDialog({required this.stages, required this.cancelLabel});

  final List<PinPadStage> stages;
  final String cancelLabel;

  @override
  State<_PinFlowDialog> createState() => _PinFlowDialogState();
}

class _PinFlowDialogState extends State<_PinFlowDialog> {
  int _stage = 0;
  int _attempt = 0;
  bool _busy = false;
  String _message = '';
  bool _error = false;
  final List<String> _captured = <String>[];

  /// The stage each captured pin came from, for [PinPadStage.restartAt].
  final List<int> _capturedFrom = <int>[];

  PinPadStage get _current => widget.stages[_stage];

  Future<void> _onCompleted(String pin) async {
    if (_busy) return;
    setState(() => _busy = true);
    final stage = _current;
    bool verdict;
    try {
      verdict = stage.verify == null
          ? true
          : await stage.verify!(pin, List<String>.unmodifiable(_captured));
    } on Object {
      // A verification that throws is wrong, same as a pin that does not
      // match: the stage restarts rather than the dialog crashing.
      verdict = false;
    }
    if (!mounted) return;
    if (!verdict) {
      setState(() {
        _busy = false;
        _error = true;
        _message = stage.error ?? '';
        _attempt++;
        // A rejected pin retires the stage's own entry and every capture
        // behind the restart point: what is re-typed must be what is judged.
        final back = stage.restartAt >= 0 ? stage.restartAt : _stage;
        while (_capturedFrom.isNotEmpty && _capturedFrom.last >= back) {
          _capturedFrom.removeLast();
          _captured.removeLast();
        }
        _stage = back;
      });
      return;
    }
    if (stage.verify == null) {
      _captured.add(pin);
      _capturedFrom.add(_stage);
    }
    _advance();
  }

  Future<void> _onBiometrics() async {
    if (_busy || _current.biometrics == null) return;
    setState(() => _busy = true);
    bool proven;
    try {
      proven = await _current.biometrics!();
    } on Object {
      proven = false;
    }
    if (!mounted) return;
    if (proven) {
      // Identity proved where the stage accepts it; the pin stays unentered.
      _advance();
    } else {
      // The system prompt showed its own failure; stay put, quietly.
      setState(() => _busy = false);
    }
  }

  void _advance() {
    if (_stage + 1 >= widget.stages.length) {
      Navigator.of(context).pop(List<String>.unmodifiable(_captured));
      return;
    }
    setState(() {
      _stage++;
      _attempt = 0;
      _busy = false;
      _error = false;
      _message = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final stage = _current;
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(stage.title),
      content: PinPad(
        key: ValueKey('$_stage-$_attempt'),
        message: _message,
        errorMessage: _error,
        enabled: !_busy,
        showBiometrics: stage.biometrics != null,
        biometricsTooltip: l.settingsAppLock_useFingerprint,
        onCompleted: _onCompleted,
        onBiometrics: stage.biometrics != null ? _onBiometrics : null,
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          key: const ValueKey('pin-flow-cancel'),
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(widget.cancelLabel),
        ),
      ],
    );
  }
}
