/// Keeps the premium profile picture in step with its bucket.
///
/// Runs at the end of a successful profile refresh and, detached, right after
/// the user picks or removes a picture. The order is the same as the chamber
/// logo's: an owed delete or upload is handled before the pulled version is
/// followed, so a stale pull can never overwrite a newer local choice, and a
/// successful upload stops the run because the cached version still describes
/// the previous file.
///
/// Only a **premium individual or chamber owner** uploads; the bucket policy is
/// the boundary, this is the polite half. Free accounts and chamber members
/// keep their picture local, and a lapsed account keeps reading and deleting
/// but cannot upload.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_log_provider.dart';
import '../../../shared/providers/database_provider.dart';
import '../../../sync/connectivity_monitor.dart';
import '../../auth/presentation/auth_viewmodel.dart';
import '../../settings/data/premium_access.dart';
import 'avatar_image_processor.dart';
import 'local/profiles_dao.dart';
import 'profile_avatar_repository.dart';
import 'profile_picture_store.dart';
import 'profile_repository.dart' show AccountRole;

/// The one function every refresh and every picture change calls.
final profileAvatarSyncProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    final identity = ref.read(authIdentityProvider);
    if (identity == null) return;
    final userId = identity.userId;

    final db = await ref.read(databaseProvider.future);
    final profile = await ProfilesDao(db).getById(userId);
    if (profile == null) return;

    final notifier = ref.read(profilePictureProvider.notifier);
    final store = ref.read(profilePictureStoreProvider);
    final online = ref.read(isOnlineProvider).value ?? true;
    final repository = ref.read(profileAvatarRepositoryProvider);
    final remotePath = '$userId.jpg';

    // 1. A delete the user asked for, waiting for a connection.
    if (store.deletePending) {
      if (!online) return;
      try {
        await repository.remove(remotePath);
        await notifier.markRemoteDeleted();
      } on Object catch (error) {
        await _log(ref, error);
      }
      return;
    }

    // 2. A local picture waiting to go up. The server repeats the rule; a
    //    member is premium through the chamber but must not upload their own,
    //    because the chamber's logo is the workspace identity.
    if (store.uploadPending) {
      if (!online) return;
      final isMember =
          profile.firmId != null && profile.role != AccountRole.owner;
      if (isMember) return;
      if (await resolvePremiumAccess(db, userId) != true) return;

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
          await notifier.replaceBytes(bytes);
        }
        await repository.upload(bytes, remotePath);
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

    if (profile.avatarPath != null) {
      final stale =
          localMissing ||
          localVersion == null ||
          profile.avatarVersion > localVersion;
      if (!stale || !online) return;
      try {
        final bytes = await repository.download(profile.avatarPath!);
        await notifier.applyDownload(bytes, profile.avatarVersion);
      } on Object catch (error) {
        await _log(ref, error);
      }
      return;
    }

    // No remote picture. A downloaded copy is cleared; a purely local file (a
    // pending upload, or a free account's own picture) is left alone. The
    // sentinel (-1) is a just-uploaded file whose version the next pull has not
    // named yet, so a stale row must not wipe the user's own upload.
    if (localVersion != null && localVersion >= 0) {
      await notifier.clearRemote();
    }
  };
});

/// A failed sync is retried on the next refresh; it never reaches a screen.
Future<void> _log(Ref ref, Object error) async {
  try {
    await ref.read(errorLogProvider).record('profile.avatar', error);
  } on Object {
    // Logging is best-effort too.
  }
}
