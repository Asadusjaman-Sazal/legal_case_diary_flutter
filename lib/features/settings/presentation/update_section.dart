/// The About screen's **App Update** section: check GitHub, and update when
/// there is a newer release.
///
/// Body of the first collapsible card under the About screen's *Update* entry.
///
///  * The card defaults **unfolded**.
///  * First line: the installed version, `Current Version: V0.0.479`.
///  * A full-width **Check For Update** button (same size as the Backup screen's
///    buttons). Tapping it changes the label to *Checking For Update* with a
///    spinner, runs [UpdateRepository] against GitHub, and then either finds a
///    newer release — the button becomes **Update Now** and the next line says
///    *There Is A Newer Version Available (Vx.y.z)* — or reports *You're On The
///    Latest Version* with a green check mark.
///  * Tapping **Update Now** downloads the APK into the app cache, showing a
///    progress bar until the download finishes, then hands the file to
///    Android's installer and deletes the cache copy.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/constants/app_version.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/providers/repository_providers.dart';
import '../data/update_release.dart';
import '../data/update_repository.dart';
import 'app_install.dart';
import 'settings_menu_card.dart' show settingsPrimaryButtonHeight;

/// What the update check is currently showing.
enum _UpdatePhase {
  /// Never checked this session, or at rest after a result.
  idle,

  /// A check is in flight; the button says *Checking For Update*.
  checking,

  /// The last check found a newer release; [Update Now] is offered.
  updateAvailable,

  /// The last check found nothing newer.
  upToDate,
}

/// The App Update card of the About screen's Update section.
class AppUpdateSection extends ConsumerStatefulWidget {
  const AppUpdateSection({super.key});

  @override
  ConsumerState<AppUpdateSection> createState() => _AppUpdateSectionState();
}

class _AppUpdateSectionState extends ConsumerState<AppUpdateSection> {
  _UpdatePhase _phase = _UpdatePhase.idle;

  /// The newer release [Update Now] installs, set when found.
  AppRelease? _release;

  /// Download progress fraction (0..1), null while not downloading.
  double? _progress;

  /// True while a download is in flight, so a tap cannot start a second.
  bool _downloading = false;

  /// The last attempt's failure message, shown when not null.
  String? _error;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
        _buildButton(l),
        const SizedBox(height: AppSpacing.sm),
        _buildFeedback(l),
      ],
    );
  }

  /// The check/install button, and the download progress bar under it.
  Widget _buildButton(AppLocalizations l) {
    final label = switch (_phase) {
      _UpdatePhase.checking => l.settingsUpdate_checking,
      _UpdatePhase.updateAvailable => l.settingsUpdate_updateNow,
      _ => l.settingsUpdate_checkForUpdate,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: settingsPrimaryButtonHeight,
          child: FilledButton.icon(
            onPressed: _downloading ? null : _onPressed,
            icon: _phase == _UpdatePhase.checking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.onPrimary,
                    ),
                  )
                : Icon(
                    _phase == _UpdatePhase.updateAvailable
                        ? Icons.download_outlined
                        : Icons.system_update_alt_outlined,
                    size: 20,
                  ),
            label: Text(label),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              textStyle: AppTypography.labelLg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
              ),
            ),
          ),
        ),
        if (_downloading && _progress != null) ...[
          const SizedBox(height: AppSpacing.sm),
          LinearProgressIndicator(
            key: const ValueKey('update-download-progress'),
            value: _progress,
            minHeight: 6,
            backgroundColor: AppColors.surfaceContainer,
            color: AppColors.primary,
          ),
        ],
      ],
    );
  }

  /// The outcome line under the button, when there is one to show.
  Widget _buildFeedback(AppLocalizations l) {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        child: Text(
          _error!,
          style: AppTypography.bodySm.copyWith(color: AppColors.error),
        ),
      );
    }
    switch (_phase) {
      case _UpdatePhase.updateAvailable:
        return Row(
          children: [
            const Icon(Icons.info_outline, color: AppColors.primary, size: 18),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                l.settingsUpdate_newerVersion(_release?.displayName ?? ''),
                style: AppTypography.bodyMd,
              ),
            ),
          ],
        );
      case _UpdatePhase.upToDate:
        return Row(
          children: [
            const Icon(
              Icons.check_circle,
              color: AppColors.success,
              size: 18,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                l.settingsUpdate_latest,
                style: AppTypography.bodyMd,
              ),
            ),
          ],
        );
      case _UpdatePhase.idle:
      case _UpdatePhase.checking:
        return const SizedBox.shrink();
    }
  }

  /// The button's work: check, or (when a release is offered) download+install.
  Future<void> _onPressed() async {
    if (_downloading) return;

    // Update Now: download + install.
    if (_phase == _UpdatePhase.updateAvailable && _release != null) {
      await _downloadAndInstall(_release!);
      return;
    }

    final l = AppLocalizations.of(context);
    setState(() {
      _phase = _UpdatePhase.checking;
      _error = null;
    });
    final outcome = await ref
        .read(updateRepositoryProvider)
        .checkForLatestRelease();
    if (!mounted) return;

    if (outcome.isUpdate) {
      setState(() {
        _phase = _UpdatePhase.updateAvailable;
        _release = outcome.release;
      });
    } else if (outcome.result == ReleaseCheckResult.upToDate) {
      setState(() {
        _phase = _UpdatePhase.upToDate;
        _release = null;
      });
    } else {
      setState(() {
        _phase = _UpdatePhase.idle;
        _error = outcome.error ?? l.settingsUpdate_checkFailed;
      });
    }
  }

  /// Downloads [release] into the app cache, then hands it to the installer.
  ///
  /// The download accumulates into a growable [bytes] list (the repository
  /// appends chunks) and verifies the file's stated size before installing, so
  /// a truncated download is refused here rather than reaching Android's
  /// installer half-built. The cache copy is deleted after the handoff.
  Future<void> _downloadAndInstall(AppRelease release) async {
    setState(() {
      _downloading = true;
      _progress = 0;
      _error = null;
    });
    try {
      final dir = await getApplicationCacheDirectory();
      final file = File('${dir.path}/legal_case_diary_update.apk');
      final bytes = <int>[];

      await ref.read(updateRepositoryProvider).downloadRelease(
        release,
        bytes,
        onProgress: (received, total) {
          if (total > 0 && mounted) {
            setState(() => _progress = received / total);
          }
        },
      );

      if (release.size != null && bytes.length != release.size) {
        throw HttpException(
          'Downloaded size ${bytes.length} != ${release.size}',
        );
      }

      final sink = file.openWrite();
      sink.add(bytes);
      await sink.close();

      final installed = await installDownloadedApk(file.path);
      if (file.existsSync()) file.deleteSync();
      if (!mounted) return;

      setState(() {
        _downloading = false;
        _progress = null;
        // The handoff is the end of the app's part; Android owns the rest.
        _phase = installed ? _UpdatePhase.upToDate : _UpdatePhase.idle;
        if (!installed) {
          _error = AppLocalizations.of(context).settingsUpdate_installUnavailable;
        }
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _progress = null;
        _error = e.toString();
      });
    }
  }
}