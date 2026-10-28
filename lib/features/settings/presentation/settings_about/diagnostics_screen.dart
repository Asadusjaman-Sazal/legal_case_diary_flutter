/// The Diagnostics viewer: what this app has recorded going wrong.
///
/// The reader is whoever has the phone in their hand — a user reporting a fault,
/// or a developer handed one — so it shows the entries newest first with no
/// filtering and nothing to hunt for, each with the failure's own message under
/// its label, because a bare `FlutterError` names nothing and cannot be fixed.
/// The message is recorded with the entry (see `ErrorLog`); it can quote a
/// server's reply, so it lives here on the user's device and leaves only inside
/// a report the user copies or sends, which they can read first.
///
/// No mockup exists for this screen, so rule 9 does not bind it: it is a
/// Settings sub-page like its neighbours, wearing [SettingsSubPageModal] and the
/// shared typography rather than inventing a style.
///
/// **Report Error Or Bug leads the actions (0.0.487, user request).** It prompts
/// for the channel — the same WhatsApp and email the Support screen offers —
/// and opens it with the app's one support message already written: the intro,
/// the diagnostics header (version, phone, language, generated, error count),
/// the log, then the prompt for the user's own description. It is shown
/// **whether or not** anything was recorded, because a fault that left no entry
/// still needs reporting and "Errors Recorded: 0" is itself an answer. Copy and
/// Clear stay hidden on an empty log, since there is nothing for them to act on.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/errors/error_log.dart';
import '../../../../core/errors/error_log_provider.dart';
import '../../../../core/l10n/generated/app_localizations.dart';
import '../../../../core/providers/contact_providers.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../../../shared/widgets/app_dialog_actions.dart';
import '../../data/diagnostics_report.dart';
import '../../data/support_diagnostics.dart';
import 'support_screen.dart';
import '../settings_menu_card.dart';
import '../settings_sub_page_modal.dart';

/// Reads, copies and clears the app's error log.
///
/// Every entry is stamped in Latin digits with an unambiguous
/// `yyyy-MM-dd HH:mm:ss` layout: a diagnostic is compared with a log on another
/// machine, not read as prose, so the Bengali numeral form the rest of the app
/// uses would work against it. The formatter lives with the report that carries
/// the same stamps (`diagnosticStamp`), so the screen and the pasted text
/// cannot drift apart.
class DiagnosticsScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const DiagnosticsScreen({super.key});

  @override
  ConsumerState<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends ConsumerState<DiagnosticsScreen> {
  @override
  Widget build(BuildContext context) {
    final log = ref.watch(errorLogProvider);
    // The log is a ChangeNotifier, so a failure recorded while this screen is
    // open appears here at once, and a Clear empties the list it was tapped on.
    return ListenableBuilder(
      listenable: log,
      builder: (context, _) => _body(context, log),
    );
  }

  /// Asks which channel to write on, then opens it with the log attached.
  ///
  /// The prompt is a small window rather than two buttons on the screen: the
  /// Diagnostics screen's job is to show the log, and a pair of channel buttons
  /// beside Copy would make three actions competing for the same eye. The
  /// message is the app's one support format, so what arrives is identical to
  /// what the Support screen sends.
  Future<void> _reportBug(ErrorLog log) async {
    final l = AppLocalizations.of(context);
    final channel = await showAppDialog<SupportChannel>(
      context,
      title: Text(l.settingsDiagnostics_reportBugTitle),
      content: Text(l.settingsDiagnostics_reportBugBody),
      actions: (dialogContext) => [
        AppDialogAction(
          key: const ValueKey('diagnostics-report-whatsapp'),
          label: l.settingsSupport_channelWhatsApp,
          onPressed: () =>
              Navigator.of(dialogContext).pop(SupportChannel.whatsApp),
        ),
        AppDialogAction(
          key: const ValueKey('diagnostics-report-email'),
          label: l.settingsSupport_channelEmail,
          onPressed: () =>
              Navigator.of(dialogContext).pop(SupportChannel.email),
        ),
      ],
    );
    if (channel == null || !mounted) return;

    // The device facts are read here rather than kept in state: this screen has
    // no use for them until the moment they are sent.
    final facts = await ref.read(supportDeviceFactsProvider).read();
    if (!mounted) return;

    await writeToSupport(
      context: context,
      launcher: ref.read(contactLauncherProvider),
      channel: channel,
      facts: facts,
      entries: log.entries,
    );
  }

  /// The screen's body, rebuilt whenever the log changes.
  Widget _body(BuildContext context, ErrorLog log) {
    final l = AppLocalizations.of(context);
    final entries = log.entries;

    return SettingsSubPageModal(
      title: l.settingsDiagnostics_title,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.edgeMargin,
          AppSpacing.md,
          AppSpacing.edgeMargin,
          AppSpacing.xl,
        ),
        children: [
          Text(
            l.settingsDiagnostics_hint,
            style: AppTypography.bodySm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // The two actions sit in the body, above the log they act on, rather
          // than in the header: the header keeps the title and the back button
          // alone. Full width each, stacked, like the About screen's pair — a
          // side-by-side pair would give each label 124 px inside the button at
          // 360 dp, and the Bengali "ডায়াগ্রনস্টিকস কপি করুন" measures 135 px
          // there, so it would wrap to two lines and the pair would misalign.
          // They are shown only when there is a log to act on.
          // The report is the point of the log, so the ways to send it come
          // first — and they are shown **whether or not** anything was
          // recorded: a user reporting a fault that left no entry still needs
          // to reach the developer, and "Errors Recorded: 0" is often exactly
          // what the developer needs to know.
          _ActionButton(
            key: const ValueKey('diagnostics-report-bug'),
            onPressed: () => _reportBug(log),
            label: l.settingsDiagnostics_reportBug,
          ),
          const SizedBox(height: AppSpacing.md),
          if (entries.isNotEmpty) ...[
            _ActionButton(
              // The report is the point of the log: it is the one form of it
              // that can leave the phone. Nothing to encrypt and no passphrase
              // to ask for, because an entry is a time, an area and a redacted
              // label.
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: buildDiagnosticsReport(entries: entries)),
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l.settingsDiagnostics_copied)),
                );
              },
              label: l.settingsDiagnostics_copy,
            ),
            const SizedBox(height: AppSpacing.md),
            _ActionButton(
              filled: false,
              onPressed: () async {
                await ref.read(errorLogProvider).clear();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l.settingsDiagnostics_cleared)),
                );
              },
              label: l.settingsDiagnostics_clear,
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          if (entries.isEmpty)
            _EmptyLog(text: l.settingsDiagnostics_empty)
          else
            for (final entry in entries) _EntryRow(entry: entry),
        ],
      ),
    );
  }
}

/// One of the screen's two actions, full width at the shared Settings CTA
/// height so it matches every other Settings button.
///
/// Both styles are spelled out because this app's theme paints `FilledButton`
/// and `OutlinedButton` black; filled is the primary action (copying the
/// report), outlined the secondary.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.onPressed,
    required this.label,
    this.filled = true,
    super.key,
  });

  final VoidCallback onPressed;
  final String label;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
    );
    return SizedBox(
      width: double.infinity,
      height: settingsPrimaryButtonHeight,
      child: filled
          ? FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                textStyle: AppTypography.labelLg,
                shape: shape,
              ),
              child: Text(label),
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.outlineVariant),
                textStyle: AppTypography.labelLg,
                shape: shape,
              ),
              child: Text(label),
            ),
    );
  }
}

/// What an empty log says.
class _EmptyLog extends StatelessWidget {
  const _EmptyLog({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
  );
}

/// One entry: what failed, the failure's own message, and when and where.
class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry});

  final ErrorLogEntry entry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(entry.label, style: AppTypography.bodyMd),
        // The failure's own message, so a bare `FlutterError` or
        // `AuthFailure(unknown)` row says what actually happened. Full text,
        // wrapped — this screen is where the reader identifies the fault.
        if (entry.detail != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            entry.detail!,
            style: AppTypography.bodySm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${entry.area} · ${diagnosticStamp(DateTime.fromMillisecondsSinceEpoch(entry.at))}',
          style: AppTypography.bodySm.copyWith(color: AppColors.outline),
        ),
      ],
    ),
  );
}
