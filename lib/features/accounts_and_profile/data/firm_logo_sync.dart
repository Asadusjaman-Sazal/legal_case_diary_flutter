/// Keeps the chamber logo in step with its bucket.
///
/// Runs at the end of a successful profile refresh and, detached, right after
/// the owner changes the logo. The order matters: an owed delete or upload is
/// handled before the pulled version is followed, so a stale pull can never
/// overwrite a newer local choice — and after a successful upload the method
/// stops, because the cached version still describes the previous file.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_log_provider.dart';
import '../../../shared/providers/database_provider.dart';
import '../../../sync/connectivity_monitor.dart';
import '../../auth/presentation/auth_viewmodel.dart';
import '../../settings/data/premium_access.dart';
import 'avatar_image_processor.dart';
import 'firm_logo_repository.dart';
import 'firm_logo_store.dart';
import 'local/firms_dao.dart';
import 'local/profiles_dao.dart';

/// The one function every refresh and every logo change calls.
final firmLogoSyncProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    final identity = ref.read(authIdentityProvider);
    if (identity == null) return;

    final db = await ref.read(databaseProvider.future);
    final profile = await ProfilesDao(db).getById(identity.userId);
    final firmId = profile?.firmId;
    final notifier = ref.read(firmLogoProvider.notifier);
    final store = ref.read(firmLogoStoreProvider);

    // No chamber: a dissolved firm or a removed member leaves nothing behind.
    if (firmId == null) {
      if (store.firmId != null || store.current() != null) {
        await notifier.reset();
      }
      return;
    }
    // A different chamber: the old logo is not this one's.
    if (store.firmId != null && store.firmId != firmId) {
      await notifier.reset();
    }

    final firm = await FirmsDao(db).getById(firmId);
    if (firm == null) return;

    final online = ref.read(isOnlineProvider).value ?? true;
    final repository = ref.read(firmLogoRepositoryProvider);

    // 1. A delete the owner asked for, waiting for a connection.
    if (store.deletePending) {
      if (!online) return;
      try {
        await repository.remove('$firmId.jpg');
        await notifier.markRemoteDeleted();
      } on Object catch (error) {
        await _log(ref, error);
      }
      return;
    }

    // 2. A local picture waiting to go up. Only the owner may upload, and only
    //    while the chamber's plan is live; otherwise it waits for the renewal.
    if (store.uploadPending) {
      if (!online) return;
      if (firm.ownerId != identity.userId) return;
      // The same derivation every gate uses: the chamber's expiry for a firm
      // account, the account's own otherwise.
      if (await resolvePremiumAccess(db, identity.userId) != true) return;

      final file = store.current();
      if (file == null) {
        await store.clearPending();
        return;
      }
      try {
        var bytes = await file.readAsBytes();
        // A picture saved before the 50 KB pipeline existed is compressed once,
        // here, and the local copy is replaced with the small one.
        if (bytes.length > avatarMaxBytes) {
          bytes = await processAvatar(bytes);
          await notifier.replaceBytes(bytes, firmId);
        }
        await repository.upload(bytes, '$firmId.jpg');
        await notifier.markUploaded();
      } on AvatarImageException {
        // The file cannot be decoded: drop it rather than retry forever. The
        // remote copy, if any, is downloaded again on the next refresh.
        await notifier.clearRemote();
      } on Object catch (error) {
        await _log(ref, error);
      }
      // The cached version describes the previous file; the next pull catches up.
      return;
    }

    // 3. Follow the pulled version.
    final localVersion = store.remoteVersion;
    final localMissing = store.current() == null;

    if (firm.logoPath != null) {
      final stale =
          localMissing ||
          localVersion == null ||
          firm.logoVersion > localVersion;
      if (!stale || !online) return;
      try {
        final bytes = await repository.download(firm.logoPath!);
        await notifier.applyDownload(bytes, firmId, firm.logoVersion);
      } on Object catch (error) {
        await _log(ref, error);
      }
      return;
    }

    // No remote logo. A downloaded copy is cleared; a purely local file (a
    // pending upload, or one a member somehow has) is left alone. The sentinel
    // (-1) is a just-uploaded file whose version the next pull has not named
    // yet, so a stale row must not wipe the owner's own upload.
    if (localVersion != null && localVersion >= 0) {
      await notifier.clearRemote();
    }
  };
});

/// A failed sync is retried on the next refresh; it never reaches a screen.
Future<void> _log(Ref ref, Object error) async {
  try {
    await ref.read(errorLogProvider).record('firm.logo', error);
  } on Object {
    // Logging is best-effort too.
  }
}
