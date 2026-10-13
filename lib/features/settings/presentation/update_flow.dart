/// The update flow — checking, offering, downloading, installing — in one place.
///
/// Two surfaces drive the same machine: the **App Update** card on
/// About > Update, and the **Check for update** row in the side menu (user
/// request). Both must check the same way, offer the same way, honour the same
/// Wi-Fi-only preference and show the same sentences, so the logic lives here
/// once and the two differ only in how they *lay it out*. A second copy would be
/// the thing that drifts — one of them learning about a new sentence or a new
/// refusal the other never gets.
///
/// The split is a controller plus a body:
///
///  * [UpdateFlowController] owns the state and the work — the check, the
///    download, the install handoff, Later, Skip This Version — as a
///    `ChangeNotifier`, so it survives a rebuild and can be driven from
///    anywhere.
///  * [UpdateFlowBody] renders it for one layout, and is all a surface adds.
///
/// **The controller holds no sentences.** A failure is stored as an
/// [UpdateFlowError], and the widget maps it to a localized line, so nothing
/// here needs a `BuildContext` or a locale — which is also what lets the same
/// controller outlive the widget that made it.
///
/// The **row layout** is deliberately narrower than the card's: the button, the
/// outcome line and the progress line, but not the `Later` / `Skip This
/// Version` pair. A navigation drawer is a list of destinations, and two text
/// actions inside one of its rows would be a menu inside a menu.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/constants/app_version.dart';
import '../../../core/errors/error_log.dart';
import '../../../core/errors/error_log_provider.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../sync/connectivity_monitor.dart';
import '../data/update_metadata_store.dart';
import '../data/update_release.dart';
import '../data/update_repository.dart';
import 'app_install.dart';
import 'settings_menu_card.dart' show settingsPrimaryButtonHeight;

/// The name a downloaded update waits in, inside the app's cache.
///
/// One fixed name, not a stamped one: the flow writes it, the launch
/// reconciliation finds it, and neither has to remember a path — the same
/// reason the backup's automatic file keeps a stem of its own.
const String updateApkFileName = 'legal_case_diary_update.apk';

/// The file a downloaded update waits in.
///
/// It lives in the app's cache, which the manifest's FileProvider already
/// exposes to the installer, and it is **not** deleted when the installer is
/// handed its URI — see [deleteUpdateApkIfStale].
Future<File> updateApkFile() async {
  final dir = await getApplicationCacheDirectory();
  return File('${dir.path}${Platform.pathSeparator}$updateApkFileName');
}

/// Deletes a downloaded update once it has served its purpose.
///
/// **The APK has to outlive the handoff.** `startActivity` only *dispatches*
/// the intent; Android's installer opens the content URI afterwards, and a file
/// deleted in between is one it cannot read — which is exactly what made
/// *Package Installer* appear in the chooser and then do nothing. So the flow
/// keeps the file, and this is what removes it: at the next launch, once
/// [stillOffered] is false, meaning either the app is now the offered version
/// (the install landed) or the offer is gone entirely (the check cleared it, or
/// the user skipped that release).
///
/// A file the OS will not let go of is left for the next launch rather than
/// treated as a failure — nothing here is worth failing a launch over.
Future<bool> deleteUpdateApkIfStale(
  File apk, {
  required bool stillOffered,
}) async {
  if (stillOffered) return false;
  if (!apk.existsSync()) return false;
  try {
    await apk.delete();
    return true;
  } on FileSystemException {
    return false;
  }
}

/// What the update flow is currently showing.
enum UpdatePhase {
  /// Never checked this session, or at rest after a result.
  idle,

  /// A check is in flight; the button says *Checking for update*.
  checking,

  /// The last check found a newer release; **Update Now** is offered.
  updateAvailable,

  /// The last check found nothing newer.
  upToDate,
}

/// Which surface the flow is being drawn on.
///
/// Only the presence of the `Later` / `Skip This Version` pair turns on this
/// flag, so a third layout has one obvious place to change.
enum UpdateFlowLayout {
  /// The About > Update card: the button, the sentence, and the ways out.
  card,

  /// A side-menu row: the button and the sentence line, nothing else.
  row,
}

/// A failure the flow can end in, ready to be given a sentence by the widget.
enum UpdateFlowError {
  /// The check could not run (no connection, or GitHub refused).
  checkFailed,

  /// The download or the install handoff failed.
  downloadFailed,

  /// The APK reached Android but this device cannot install an update.
  installUnavailable,
}

/// Owns the update flow's state and work, shared by every surface that drives it.
class UpdateFlowController extends ChangeNotifier {
  /// Creates a controller over [container], which is kept for the repositories
  /// and stores the work needs.
  ///
  /// A [ProviderContainer] rather than a `WidgetRef` on purpose: a `WidgetRef`
  /// belongs to the widget that made it and must not outlive it, while this
  /// controller deliberately does — the drawer can close mid-download, and the
  /// About card can rebuild under it.
  UpdateFlowController(this._container) {
    // An update the launch check already found is offered at once — no second
    // lookup, and it works with no connection. The session deferral is ignored
    // here on purpose: opening this screen (or this menu) *is* the user asking
    // to look.
    final metadata = _container.read(updateMetadataProvider);
    if (shouldOfferRelease(
      release: metadata.availableRelease,
      skippedVersion: metadata.skippedVersion,
    )) {
      _phase = UpdatePhase.updateAvailable;
      _release = metadata.availableRelease;
    }
  }

  final ProviderContainer _container;

  UpdatePhase _phase = UpdatePhase.idle;
  AppRelease? _release;
  double? _progress;
  bool _downloading = false;
  UpdateFlowError? _error;

  /// Set when this controller is disposed, so a late download cannot notify a
  /// listener that has gone — the drawer can close while one is running.
  bool _disposed = false;

  /// The current phase.
  UpdatePhase get phase => _phase;

  /// The offered release, when there is one.
  AppRelease? get release => _release;

  /// Download progress fraction, or null while not downloading.
  double? get progress => _progress;

  /// Whether a download is running.
  bool get downloading => _downloading;

  /// The failure to report, or null.
  UpdateFlowError? get error => _error;

  /// The button's own label for the current phase.
  String buttonLabel(AppLocalizations l) => switch (_phase) {
    UpdatePhase.checking => l.settingsUpdate_checking,
    UpdatePhase.updateAvailable => l.settingsUpdate_updateNow,
    _ => l.settingsUpdate_checkForUpdate,
  };

  /// The button's leading icon for the current phase; null while checking, where
  /// the body draws a spinner instead.
  IconData? buttonIcon() => switch (_phase) {
    UpdatePhase.checking => null,
    UpdatePhase.updateAvailable => Icons.download_outlined,
    _ => Icons.system_update_alt_outlined,
  };

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// The button's work: check, or (when a release is offered) download+install.
  Future<void> check() async {
    if (_downloading) return;

    // Update Now: download + install.
    if (_phase == UpdatePhase.updateAvailable && _release != null) {
      await _downloadAndInstall(_release!);
      return;
    }

    _set(() {
      _phase = UpdatePhase.checking;
      _error = null;
    });
    final outcome = await _container
        .read(updateRepositoryProvider)
        .checkForLatestRelease();
    if (_disposed) return;

    // A release the user skipped is not offered again — the check still ran,
    // but it counts as nothing newer, which is what "skip this version" means.
    final offer = shouldOfferRelease(
      release: outcome.release,
      skippedVersion: _container.read(updateMetadataProvider).skippedVersion,
    );

    if (offer) {
      _set(() {
        _phase = UpdatePhase.updateAvailable;
        _release = outcome.release;
      });
    } else if (outcome.result == ReleaseCheckResult.upToDate ||
        outcome.isUpdate) {
      _set(() {
        _phase = UpdatePhase.upToDate;
        _release = null;
      });
    } else {
      // The user gets a sentence; the technical cause goes to the diagnostics
      // log. Showing the raw cause would put English developer text ("GitHub
      // responded 403") in front of a Bengali user.
      recordFailure(_container.read(errorLogProvider), 'update.check', outcome.error!);
      _set(() {
        _phase = UpdatePhase.idle;
        _error = UpdateFlowError.checkFailed;
      });
    }
  }

  /// Installs [release] straight away.
  ///
  /// The path for a surface that learned about the offer from the **store**
  /// rather than from its own check — the launch check's finding, which a
  /// second controller in another widget never saw. Without this it would have
  /// to re-run the check to notice what the app already knows.
  Future<void> updateNow(AppRelease release) => _downloadAndInstall(release);

  /// Hides the offered update until the app is next launched.
  void later() {
    _container.read(updateDeferredProvider.notifier).defer();
    _set(() {
      _phase = UpdatePhase.idle;
      _release = null;
    });
  }

  /// Retires this exact release until a newer one appears.
  Future<void> skip() async {
    final release = _release;
    if (release == null) return;
    await _container
        .read(updateMetadataProvider.notifier)
        .skipVersion(release.version);
    if (_disposed) return;
    _set(() {
      _phase = UpdatePhase.idle;
      _release = null;
    });
  }

  /// Applies [change] and tells the listeners — unless this controller has been
  /// thrown away while the work was in flight.
  void _set(void Function() change) {
    if (_disposed) return;
    change();
    notifyListeners();
  }

  /// Downloads [release] into the app cache, then hands it to the installer.
  ///
  /// The download accumulates into a growable [bytes] list (the repository
  /// appends chunks) and verifies the file's stated size before installing, so
  /// a truncated download is refused here rather than reaching Android's
  /// installer half-built. The cache copy is deleted after the handoff.
  ///
  /// **The Wi-Fi-only preference is honoured first.** On mobile data the user is
  /// asked once, naming what the download costs them, and may still proceed —
  /// they asked for the update, so refusing outright would be the worse answer.
  Future<void> _downloadAndInstall(AppRelease release) async {
    if (!await _allowedByNetworkPreference()) return;
    if (_disposed) return;

    _set(() {
      _downloading = true;
      _progress = 0;
      _error = null;
    });
    try {
      final file = await updateApkFile();
      final bytes = <int>[];

      await _container
          .read(updateRepositoryProvider)
          .downloadRelease(
            release,
            bytes,
            onProgress: (received, total) {
              if (total > 0 && !_disposed) {
                _progress = received / total;
                notifyListeners();
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

      // **The file is deliberately not deleted here.** `installDownloadedApk`
      // returns as soon as the intent is dispatched, and Android's installer
      // reads the URI after that — deleting the APK at this point is what made
      // selecting *Package Installer* do nothing at all. It is removed by
      // `deleteUpdateApkIfStale` at the next launch instead.
      final installed = await installDownloadedApk(file.path);

      // The offer has been acted on, so it is no longer news: dropping it here
      // is what keeps the dot from outliving the update it pointed at. This is
      // best-effort — the install already happened, so a preferences failure
      // must not be reported as a download failure, and the worst case (the
      // dot lingers until `recordCheck` next clears it) is harmless.
      if (installed) {
        try {
          await _container
              .read(updateMetadataProvider.notifier)
              .clearAvailableRelease();
        } on Object catch (clearError) {
          recordFailure(_container.read(errorLogProvider), 'update.clear', clearError);
        }
      }

      _set(() {
        _downloading = false;
        _progress = null;
        // The handoff is the end of the app's part; Android owns the rest.
        _phase = installed ? UpdatePhase.upToDate : UpdatePhase.idle;
        if (!installed) _error = UpdateFlowError.installUnavailable;
      });
    } on Object catch (e) {
      // A truncated download, a refused connection, an unwritable cache: all
      // the same sentence to the user, with the cause kept in the log.
      recordFailure(_container.read(errorLogProvider), 'update.download', e);
      _set(() {
        _downloading = false;
        _progress = null;
        _error = UpdateFlowError.downloadFailed;
      });
    }
  }

  /// Whether the download may go ahead under **Update over Network**.
  ///
  /// Wi-Fi only (the default) asks once when the device is on mobile data; the
  /// user can still continue, because they are the one who tapped Update Now.
  /// The wider option proceeds without a word.
  Future<bool> _allowedByNetworkPreference() async {
    if (_container.read(updateMetadataProvider).network != UpdateNetwork.wifi) {
      return true;
    }
    final onMobile = await _container
        .read(connectivityMonitorProvider)
        .isOnMobileData();
    if (!onMobile) return true;
    return await _confirmMobileData() ?? false;
  }

  /// The one question before spending the user's mobile data.
  ///
  /// Needs a widget, so it is asked with whatever context the surface injected;
  /// a controller with no context (a test, a headless run) simply proceeds.
  Future<bool?> _confirmMobileData() async {
    final context = dialogContext;
    if (context == null || !context.mounted) return true;
    final l = AppLocalizations.of(context);
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.settingsUpdate_mobileDataTitle),
        content: Text(l.settingsUpdate_mobileDataBody),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(112, 48)),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.sharedActions_cancel),
          ),
          FilledButton(
            key: const ValueKey('update-mobile-continue'),
            style: FilledButton.styleFrom(minimumSize: const Size(112, 48)),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.settingsUpdate_mobileDataContinue),
          ),
        ],
      ),
    );
  }

  /// A `BuildContext` a dialog can be raised from, set by the surface while it
  /// is mounted. The one thing here that needs a widget, and only for the
  /// mobile-data question.
  BuildContext? dialogContext;
}

/// Renders a [UpdateFlowController] in one of the layouts.
class UpdateFlowBody extends StatefulWidget {
  /// Creates the body.
  const UpdateFlowBody({
    required this.controller,
    required this.layout,
    this.showButton = true,
    this.showProgress = false,
    super.key,
  });

  /// The flow to render.
  final UpdateFlowController controller;

  /// Which surface this is, and therefore what else is drawn.
  final UpdateFlowLayout layout;

  /// Whether to draw the button. The card draws it; a drawer row is itself the
  /// button, so it draws only the outcome line underneath.
  final bool showButton;

  /// Whether to draw a download progress bar under the button. The card has
  /// room for it; a drawer row draws the same progress as a hairline instead.
  final bool showProgress;

  @override
  State<UpdateFlowBody> createState() => _UpdateFlowBodyState();
}

class _UpdateFlowBodyState extends State<UpdateFlowBody> {
  @override
  void initState() {
    super.initState();
    // The mobile-data question is the only thing in the flow that needs a
    // widget; hand the controller this one while it is alive.
    widget.controller.dialogContext = context;
  }

  @override
  void dispose() {
    widget.controller.dialogContext = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) => _content(context),
  );

  Widget _content(BuildContext context) {
    final l = AppLocalizations.of(context);
    final controller = widget.controller;
    final progress = controller.progress;
    // Read from the live phase, inside the builder, for the same reason the
    // drawer's row is: computed outside it, the button would never change.
    final installingFill = controller.phase == UpdatePhase.updateAvailable
        ? AppColors.success
        : AppColors.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // The card draws the button; a drawer row *is* the button, so it asks
        // for the outcome line alone.
        if (widget.showButton)
          SizedBox(
            height: settingsPrimaryButtonHeight,
            child: FilledButton.icon(
              onPressed: controller.downloading ? null : controller.check,
              // Green once there is something to install (user request), the
              // same signal the side menu's row gives with green ink. Here the
              // button is *filled*, so green is the fill and the label stays
              // white — the app's primary button in the colour that means "this
              // is the action", rather than the black one it wears while there
              // is only a check to run.
              key: const ValueKey('update-flow-button'),
              icon: controller.phase == UpdatePhase.checking
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.onPrimary,
                      ),
                    )
                  : Icon(controller.buttonIcon(), size: 20),
              label: Text(controller.buttonLabel(l)),
              style: FilledButton.styleFrom(
                backgroundColor: installingFill,
                foregroundColor: AppColors.onPrimary,
                textStyle: AppTypography.labelLg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
                ),
              ),
            ),
          ),
        if (controller.downloading && progress != null) ...[
          const SizedBox(height: AppSpacing.sm),
          widget.showProgress
              ? LinearProgressIndicator(
                  key: const ValueKey('update-download-progress'),
                  value: progress,
                  minHeight: 6,
                  backgroundColor: AppColors.surfaceContainer,
                  color: AppColors.primary,
                )
              // The drawer's own progress line: the same reading in the space a
              // nav row has, which is a hairline rather than a 6 px bar.
              : ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    key: const ValueKey('update-download-progress-line'),
                    value: progress,
                    minHeight: 3,
                    backgroundColor: AppColors.outlineVariant,
                    color: AppColors.primary,
                  ),
                ),
        ],
        _feedback(l, controller),
      ],
    );
  }

  /// The outcome line under the button, when there is one to show.
  Widget _feedback(AppLocalizations l, UpdateFlowController controller) {
    final error = controller.error;
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        child: Text(
          _errorText(l, error),
          style: AppTypography.bodySm.copyWith(color: AppColors.error),
        ),
      );
    }
    switch (controller.phase) {
      case UpdatePhase.updateAvailable:
        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      l.settingsUpdate_newerVersion(
                        controller.release?.displayName ?? '',
                      ),
                      style: AppTypography.bodyMd,
                    ),
                  ),
                ],
              ),
              // Deferring without being nagged, and retiring this one release —
              // so an available update is never an unclearable badge. Only the
              // card offers these; a drawer row would be a menu inside a menu.
              if (widget.layout == UpdateFlowLayout.card)
                Row(
                  children: [
                    TextButton(
                      key: const ValueKey('update-later'),
                      onPressed: controller.later,
                      style: TextButton.styleFrom(
                        textStyle: AppTypography.labelLg,
                      ),
                      child: Text(l.settingsUpdate_later),
                    ),
                    TextButton(
                      key: const ValueKey('update-skip-version'),
                      onPressed: controller.skip,
                      style: TextButton.styleFrom(
                        textStyle: AppTypography.labelLg,
                      ),
                      child: Text(l.settingsUpdate_skipVersion),
                    ),
                  ],
                ),
            ],
          ),
        );
      case UpdatePhase.upToDate:
        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: Row(
            children: [
              const Icon(
                Icons.check_circle,
                color: AppColors.success,
                size: 18,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  // The version is named (user request): "you are on the latest
                  // version" leaves the reader to go and find out which.
                  l.settingsUpdate_latestVersion('V$appVersion'),
                  style: AppTypography.bodyMd,
                ),
              ),
            ],
          ),
        );
      case UpdatePhase.idle:
      case UpdatePhase.checking:
        return const SizedBox.shrink();
    }
  }

  /// The sentence for a failure, so the controller never holds copy.
  String _errorText(AppLocalizations l, UpdateFlowError error) => switch (error) {
    UpdateFlowError.checkFailed => l.settingsUpdate_checkFailed,
    UpdateFlowError.downloadFailed => l.settingsUpdate_downloadFailed,
    UpdateFlowError.installUnavailable => l.settingsUpdate_installUnavailable,
  };
}
