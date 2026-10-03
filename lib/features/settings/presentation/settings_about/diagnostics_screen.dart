/// The Diagnostics viewer: what this app has recorded going wrong.
///
/// The reader is whoever has the phone in their hand — a user reporting a fault,
/// or a developer handed one — so it shows the entries newest first with no
/// filtering and nothing to hunt for. The log is redacted where it is *written*
/// (see `ErrorLog`), so nothing on this screen can leak a case field, a
/// password, a token or a raw server message.
///
/// No mockup exists for this screen, so rule 9 does not bind it: it is a
/// Settings sub-page like its neighbours, wearing [SettingsSubPageModal] and the
/// shared typography rather than inventing a style.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/errors/error_log.dart';
import '../../../../core/errors/error_log_provider.dart';
import '../../../../core/l10n/generated/app_localizations.dart';
import '../settings_sub_page_modal.dart';

/// One recorded failure, as this screen draws it.
///
/// Deliberately Latin digits and an unambiguous `YYYY-MM-DD HH:MM:SS` stamp: a
/// diagnostic is compared with a log on another machine, not read as prose, so
/// the Bengali numeral form the rest of the app uses would work against it.
final DateFormat _stamp = DateFormat('yyyy-MM-dd HH:mm:ss');

/// Reads and clears the app's error log.
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

  /// The screen's body, rebuilt whenever the log changes.
  Widget _body(BuildContext context, ErrorLog log) {
    final l = AppLocalizations.of(context);
    final entries = log.entries;

    return SettingsSubPageModal(
      title: l.settingsDiagnostics_title,
      actions: [
        if (entries.isNotEmpty)
          TextButton(
            onPressed: () async {
              await ref.read(errorLogProvider).clear();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l.settingsDiagnostics_cleared)),
              );
            },
            child: Text(l.settingsDiagnostics_clear),
          ),
      ],
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
          if (entries.isEmpty)
            _EmptyLog(text: l.settingsDiagnostics_empty)
          else
            for (final entry in entries) _EntryRow(entry: entry),
        ],
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

/// One line of the log: when, where, and what failed.
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
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${entry.area} · ${_stamp.format(DateTime.fromMillisecondsSinceEpoch(entry.at))}',
          style: AppTypography.bodySm.copyWith(color: AppColors.outline),
        ),
      ],
    ),
  );
}
