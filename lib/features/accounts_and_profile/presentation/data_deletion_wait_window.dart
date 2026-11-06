/// The mandatory wait window while the user's data is being deleted.
///
/// **The request (0.0.811, user request).** Pressing Delete Selected used to
/// start a deletion that can take a while with nothing on screen — the user
/// could take the app for idle and close it mid-run. This window is the whole
/// answer: it appears before the service is read and stays until the deletion
/// finishes, with no action, no barrier dismissal and no back route, so the app
/// cannot be used until the run is over.
///
/// **One window, every entry point.** Manage Account's two cards and Backup &
/// Restore's restore guard all run `runDataDeletionFlow`, and that flow opens
/// this window, so no caller can start a deletion without it.
///
/// **It owns the run.** The given [run] is started in `initState` and its result
/// is what the window closes with; a thrown error closes it with a failed
/// [DataDeletionResult] rather than leaving the window up. It is a centred
/// pop-over, so it is built on the shared frame (rule 17) and adds no
/// measurements or actions of its own.
library;

import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_dialog_actions.dart';
import '../data/data_deletion_service.dart';

/// Opens the deletion wait window and answers with the run's result.
///
/// A window that somehow closes without a result — it should not — answers with
/// a failed result, so a caller's message can never claim a deletion it did not
/// see finish.
Future<DataDeletionResult> showDataDeletionWaitWindow(
  BuildContext context, {
  required Future<DataDeletionResult> Function() run,
}) async =>
    await showDialog<DataDeletionResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DataDeletionWaitWindow(run: run),
    ) ??
    const DataDeletionResult(
      counts: <DataDeletionCategory, int>{},
      failed: true,
    );

/// The window itself: a spinner and one sentence, until [run] finishes.
class DataDeletionWaitWindow extends StatefulWidget {
  /// Creates the window.
  const DataDeletionWaitWindow({required this.run, super.key});

  /// The work the window waits for; started once, when the window opens.
  final Future<DataDeletionResult> Function() run;

  @override
  State<DataDeletionWaitWindow> createState() => _DataDeletionWaitWindowState();
}

class _DataDeletionWaitWindowState extends State<DataDeletionWaitWindow> {
  @override
  void initState() {
    super.initState();
    _run();
  }

  /// Runs the deletion and closes the window with what it answered.
  Future<void> _run() async {
    DataDeletionResult result;
    try {
      result = await widget.run();
    } on Object {
      // The service reports its own failures; this is the provider or the run
      // itself being unreadable. The window still closes, and the caller's
      // toast says the deletion could not be done.
      result = const DataDeletionResult(
        counts: <DataDeletionCategory, int>{},
        failed: true,
      );
    }
    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // No back route while the deletion runs: closing the window would leave the
    // run with nowhere to report and the user unsure whether it finished.
    return PopScope(
      canPop: false,
      child: AppDialogFrame(
        dialogKey: const ValueKey('data-deletion-wait'),
        title: Text(l.settingsManageAccount_deleteDataWaitTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l.settingsManageAccount_deleteDataWaitBody,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMd,
            ),
          ],
        ),
        // A wait is not a question: the window has nothing to press.
        actions: (_) => const <AppDialogAction>[],
      ),
    );
  }
}
