/// The About screen's **App Update** card: check GitHub, and update when there
/// is a newer release.
///
/// The card is a *presentation* of the shared update flow — the checking, the
/// download, the install handoff, `Later` and `Skip This Version` all live in
/// `update_flow.dart`, because the side menu's **Check for update** row drives
/// exactly the same machine (user request). What is left here is the card's own
/// layout: the installed version line, then the button with the outcome under
/// it and, while a download runs, a progress bar.
///
///  * an update the launch check already found is **offered at once** when the
///    card appears — the check only ever reports, it never installs;
///  * the **Update over Network** preference is honoured before downloading: Wi
///    Fi Only (the default) asks once on mobile data, and the user may still
///    continue.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/constants/app_version.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import 'update_flow.dart';

/// The App Update card of the About screen's Update section.
class AppUpdateSection extends ConsumerStatefulWidget {
  const AppUpdateSection({super.key});

  @override
  ConsumerState<AppUpdateSection> createState() => _AppUpdateSectionState();
}

class _AppUpdateSectionState extends ConsumerState<AppUpdateSection> {
  /// The flow this card drives. Owned here so the card's layout — and the
  /// download it started — survive the card rebuilding.
  late final UpdateFlowController _flow = UpdateFlowController(
    ProviderScope.containerOf(context),
  );

  @override
  void dispose() {
    _flow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Current Version line.
        Text.rich(
          TextSpan(
            style: AppTypography.bodyMd,
            children: <TextSpan>[
              TextSpan(text: '${l.settingsUpdate_currentVersion} '),
              // V-prefixed, matching the drawer's own V{version} convention.
              TextSpan(
                text: 'V$appVersion',
                style: AppTypography.bodyMd.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        UpdateFlowBody(
          controller: _flow,
          layout: UpdateFlowLayout.card,
          showProgress: true,
        ),
      ],
    );
  }
}
