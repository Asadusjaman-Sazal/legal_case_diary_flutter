/// The blocking extended-offline recovery screen (Task 19 Phase 5).
///
/// It replaces the **whole app** while the lock is set, which is how the plan's
/// "the UI disables editing/FAB with a recovery-required message" is honoured
/// most completely: there is no screen to edit on, no FAB to press, and no route
/// to reach one. The write guard in `SyncWriteHelper` is the second line, for a
/// path that never goes through the UI.
///
/// It is an overlay rather than a route on purpose: it must sit above every
/// screen and every route, including one the app opens on, and it must come back
/// on the next launch without any navigation happening. It renders its child
/// untouched when the lock is off, so it costs nothing in the normal case.
///
/// The passphrase fields are inline rather than the Backup screen's shared
/// dialog, because this widget sits *above* the app's navigator and so has none
/// to show a dialog on. The labels are the shared ones, so the copy stays the
/// same.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../shared/providers/database_provider.dart';
import '../../../sync/recovery_flow.dart';
import '../../../sync/sync_metadata_dao.dart';

/// How many days this device has been away, for the warning's wording.
final _offlineDaysProvider = FutureProvider<int>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  final last = await SyncMetadataDao(db).getIntValue(lastSuccessfulSyncAtKey);
  if (last == null) return 0;
  final delta = DateTime.now().toUtc().millisecondsSinceEpoch - last;
  return delta ~/ Duration.millisecondsPerDay;
});

/// Renders [child], or the blocking recovery screen while the lock is set.
class RecoveryRequiredScope extends ConsumerWidget {
  /// Creates the scope around [child].
  const RecoveryRequiredScope({required this.child, super.key});

  /// The application, shown whenever the device is not locked.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locked = ref.watch(recoveryRequiredProvider).value ?? false;
    if (!locked) return child;
    return const RecoveryRequiredScreen();
  }
}

/// The blocking screen itself.
class RecoveryRequiredScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const RecoveryRequiredScreen({super.key});

  @override
  ConsumerState<RecoveryRequiredScreen> createState() =>
      _RecoveryRequiredScreenState();
}

class _RecoveryRequiredScreenState
    extends ConsumerState<RecoveryRequiredScreen> {
  final _passphrase = TextEditingController();
  final _confirm = TextEditingController();

  /// True while the safety copy or the recovery is running.
  bool _busy = false;

  /// True once Proceed has been pressed and the confirmation is showing.
  bool _confirming = false;

  /// True once Close has been pressed, which explains what staying locked means.
  bool _closeNote = false;

  /// The last failure's message key, or null.
  String? _error;

  @override
  void dispose() {
    _passphrase.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final days = ref.watch(_offlineDaysProvider).value ?? 0;
    final copy = ref.watch(recoverySafetyCopyProvider).value;
    final path = copy?.path;
    final saved = copy?.complete ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.errorContainer,
                    borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
                  ),
                  child: const Icon(
                    Icons.cloud_off_outlined,
                    size: 32,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(l.recoveryLock_title, style: AppTypography.titleLg),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  saved && path != null
                      ? l.recoveryLock_message(days, path)
                      : l.recoveryLock_messageNoCopy(days),
                  style: AppTypography.bodyMd,
                ),
                const SizedBox(height: AppSpacing.lg),
                if (saved && path != null)
                  _savedCopy(l, path, copy?.checksum)
                else
                  _safetyCopyForm(l),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _error!,
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                if (_busy) ...[
                  Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(l.recoveryLock_working, style: AppTypography.bodySm),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                _actions(l, saved),
                if (_closeNote) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(l.recoveryLock_closeBody, style: AppTypography.bodySm),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The already-saved line: where the copy is, and enough of its checksum to
  /// identify it.
  Widget _savedCopy(AppLocalizations l, String path, String? checksum) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.recoveryLock_savedTo(path), style: AppTypography.bodySm),
          if (checksum != null)
            Text(
              checksum,
              style: AppTypography.bodySm,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      );

  /// The one-time step that has to succeed before anything may be erased.
  Widget _safetyCopyForm(AppLocalizations l) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(l.recoveryLock_saveTitle, style: AppTypography.titleMd),
      const SizedBox(height: AppSpacing.xs),
      Text(l.recoveryLock_saveBody, style: AppTypography.bodySm),
      const SizedBox(height: AppSpacing.md),
      TextField(
        key: const ValueKey('recovery-lock-passphrase'),
        controller: _passphrase,
        obscureText: true,
        decoration: InputDecoration(
          labelText: l.settingsBackupRestore_passphraseLabel,
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      TextField(
        key: const ValueKey('recovery-lock-passphrase-confirm'),
        controller: _confirm,
        obscureText: true,
        decoration: InputDecoration(
          labelText: l.settingsBackupRestore_passphraseConfirmLabel,
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      FilledButton(
        key: const ValueKey('recovery-lock-save'),
        onPressed: _busy ? null : _save,
        child: Text(l.recoveryLock_saveAction),
      ),
    ],
  );

  /// Close and Proceed, with Proceed's confirmation inline.
  Widget _actions(AppLocalizations l, bool saved) {
    if (_confirming) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.recoveryLock_proceedConfirmTitle,
            style: AppTypography.titleMd,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(l.recoveryLock_proceedConfirmBody, style: AppTypography.bodySm),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => setState(() => _confirming = false),
                child: Text(l.sharedActions_cancel),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton(
                key: const ValueKey('recovery-lock-proceed-confirm'),
                onPressed: _busy ? null : _proceed,
                child: Text(l.recoveryLock_proceed),
              ),
            ],
          ),
        ],
      );
    }
    return Row(
      children: [
        OutlinedButton(
          key: const ValueKey('recovery-lock-close'),
          onPressed: () => setState(() => _closeNote = true),
          child: Text(l.recoveryLock_close),
        ),
        const SizedBox(width: AppSpacing.sm),
        FilledButton(
          key: const ValueKey('recovery-lock-proceed'),
          onPressed: saved && !_busy
              ? () => setState(() => _confirming = true)
              : null,
          child: Text(l.recoveryLock_proceed),
        ),
      ],
    );
  }

  /// Writes the automatic safety copy with the passphrase the user chose.
  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final passphrase = _passphrase.text;
    if (passphrase.isEmpty) {
      setState(() => _error = l.settingsBackupRestore_passphraseRequired);
      return;
    }
    if (passphrase != _confirm.text) {
      setState(() => _error = l.settingsBackupRestore_passphraseMismatch);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final flow = await ref.read(recoveryFlowProvider.future);
    final copy = await flow.saveSafetyCopy(passphrase: passphrase);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = copy == null ? l.recoveryLock_saveFailed : null;
    });
  }

  /// Proceed: verify the copy, wipe, reconstruct and pull.
  Future<void> _proceed() async {
    final l = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _confirming = false;
      _error = null;
    });
    final flow = await ref.read(recoveryFlowProvider.future);
    final outcome = await flow.proceed();
    if (!mounted) return;
    setState(() {
      _busy = false;
      // Every non-recovered ending keeps the lock, which is the point: the
      // screen simply stays and the step can be tried again.
      _error = switch (outcome) {
        RecoveryOutcome.recovered => null,
        RecoveryOutcome.offline => l.recoveryLock_failed,
        _ => l.recoveryLock_failed,
      };
    });
  }
}
