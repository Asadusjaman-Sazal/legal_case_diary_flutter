/// Local profile picture store, with the cloud copy's bookkeeping.
///
/// The processed JPEG is copied into app documents storage (the picker path
/// lives in a cache directory the OS may purge) and its path is remembered in
/// [SharedPreferences], so the picture survives restarts and every screen that
/// shows the user's profile draws the same file.
///
/// The local file is the offline truth. Three more preferences describe the
/// remote copy: the server version the file matches, whether a local picture is
/// waiting to go up, and whether the remote one is waiting to be deleted. They
/// exist only for the premium cloud copy (0.0.630); a free account simply never
/// acts on them.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/providers/shared_preferences_provider.dart';
import 'avatar_image_processor.dart';

/// Preference key holding the absolute path of the saved profile picture.
const String profilePicturePathKey = 'profile_picture_path';
const String _remoteVersionKey = 'profile_avatar_remote_version';
const String _uploadPendingKey = 'profile_avatar_upload_pending';
const String _deletePendingKey = 'profile_avatar_delete_pending';

/// Folder (inside app documents) holding the saved profile picture.
const String _pictureDirName = 'profile_picture';

/// Reads and writes the user's profile picture file and its remote state.
class ProfilePictureStore {
  /// Creates a store backed by [prefs].
  ProfilePictureStore(this._prefs);

  /// Preferences holding the saved picture path.
  final SharedPreferences _prefs;

  /// The saved picture, or null when none is set or the file is gone.
  File? current() {
    final path = _prefs.getString(profilePicturePathKey);
    if (path == null) return null;
    final file = File(path);
    return file.existsSync() ? file : null;
  }

  /// The server version this file corresponds to, or null when it has never
  /// been synced (a fresh local choice, or an upload awaiting its pull).
  int? get remoteVersion => _prefs.getInt(_remoteVersionKey);

  /// Whether a local picture is waiting to be uploaded.
  bool get uploadPending => _prefs.getBool(_uploadPendingKey) ?? false;

  /// Whether the remote copy is waiting to be deleted.
  bool get deletePending => _prefs.getBool(_deletePendingKey) ?? false;

  /// Writes [bytes] as the saved picture, replacing the previous file.
  Future<File> saveBytes(Uint8List bytes) async {
    final documents = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(documents.path, _pictureDirName));
    await dir.create(recursive: true);

    final target = File(
      p.join(dir.path, 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg'),
    );
    final previous = _prefs.getString(profilePicturePathKey);
    if (previous != null &&
        previous != target.path &&
        File(previous).existsSync()) {
      await File(previous).delete();
    }
    await target.writeAsBytes(bytes, flush: true);
    await _prefs.setString(profilePicturePathKey, target.path);
    return target;
  }

  /// Removes the saved file and its path, leaving the remote bookkeeping.
  Future<void> removeLocal() async {
    final path = _prefs.getString(profilePicturePathKey);
    if (path != null) {
      final file = File(path);
      if (file.existsSync()) await file.delete();
    }
    await _prefs.remove(profilePicturePathKey);
  }

  /// The old name for [removeLocal], kept for callers that only unset a file.
  Future<void> clear() => removeLocal();

  /// Marks the local picture as waiting to go up, cancelling a pending delete.
  Future<void> markUploadPending() async {
    await _prefs.setBool(_uploadPendingKey, true);
    await _prefs.remove(_deletePendingKey);
  }

  /// The upload landed; the next pull supplies the new server version.
  Future<void> clearUploadPending() async {
    await _prefs.remove(_uploadPendingKey);
    await _prefs.remove(_remoteVersionKey);
  }

  /// Remembers which server version the local file matches.
  Future<void> setRemoteVersion(int version) async {
    await _prefs.setInt(_remoteVersionKey, version);
  }

  /// Drops both work flags without touching the downloaded version.
  Future<void> clearPending() async {
    await _prefs.remove(_uploadPendingKey);
    await _prefs.remove(_deletePendingKey);
  }

  /// The user deleted the picture: drop the local file and remember a remote
  /// delete when there is a remote copy to remove.
  Future<void> forgetLocal() async {
    final hadRemote = remoteVersion != null;
    await removeLocal();
    await _prefs.remove(_uploadPendingKey);
    if (hadRemote) {
      await _prefs.setBool(_deletePendingKey, true);
    } else {
      await _prefs.remove(_deletePendingKey);
    }
  }

  /// The remote copy is gone, or a just-uploaded file must be re-downloaded.
  Future<void> forgetRemote() async {
    await removeLocal();
    await _prefs.remove(_remoteVersionKey);
    await _prefs.remove(_uploadPendingKey);
    await _prefs.remove(_deletePendingKey);
  }

  /// The remote delete landed.
  Future<void> clearDeletePending() async {
    await _prefs.remove(_deletePendingKey);
    await _prefs.remove(_remoteVersionKey);
  }

  /// Logout or an account switch: no picture and no remote bookkeeping.
  Future<void> reset() async {
    await removeLocal();
    await _prefs.remove(_remoteVersionKey);
    await _prefs.remove(_uploadPendingKey);
    await _prefs.remove(_deletePendingKey);
  }
}

/// The one store every reader and writer shares.
final profilePictureStoreProvider = Provider<ProfilePictureStore>(
  (ref) => ProfilePictureStore(ref.watch(sharedPreferencesProvider)),
);

/// Riverpod state for the locally saved profile picture.
///
/// The initial value is read synchronously from [SharedPreferences], so every
/// screen (Profile, Manage Account, the drawer) shows the same picture without
/// an async gap. Updates notify all listeners.
class ProfilePictureNotifier extends Notifier<File?> {
  late final ProfilePictureStore _store;

  @override
  File? build() {
    _store = ref.read(profilePictureStoreProvider);
    return _store.current();
  }

  /// Processes the image at [sourcePath] and saves it as the profile picture.
  ///
  /// Throws [AvatarImageException] when the file cannot be read as an image;
  /// the screen shows that as one message and keeps the previous picture.
  Future<void> setFromPath(String sourcePath) async {
    final bytes = await File(sourcePath).readAsBytes();
    final processed = await processAvatar(bytes);
    state = await _store.saveBytes(processed);
    await _store.markUploadPending();
  }

  /// Saves already-processed bytes (the test seam, and a re-save).
  Future<void> setBytes(Uint8List bytes) async {
    state = await _store.saveBytes(bytes);
    await _store.markUploadPending();
  }

  /// Clears the profile picture, remembering a remote delete when there is one.
  Future<void> clear() async {
    await _store.forgetLocal();
    state = null;
  }

  /// A downloaded picture from the account's bucket.
  Future<void> applyDownload(Uint8List bytes, int version) async {
    state = await _store.saveBytes(bytes);
    await _store.clearPending();
    await _store.setRemoteVersion(version);
  }

  /// The account's remote picture is gone (removed elsewhere).
  Future<void> clearRemote() async {
    await _store.forgetRemote();
    state = null;
  }

  /// The upload landed: clear its pending state and keep a sentinel version so
  /// a removal before the next pull still deletes the object.
  Future<void> markUploaded() async {
    await _store.clearUploadPending();
    await _store.setRemoteVersion(-1);
  }

  /// The remote delete landed.
  Future<void> markRemoteDeleted() async {
    await _store.clearDeletePending();
    state = null;
  }

  /// Replaces the local file without changing what is pending (a legacy file
  /// compressed during its first upload).
  Future<void> replaceBytes(Uint8List bytes) async {
    state = await _store.saveBytes(bytes);
  }

  /// Logout or an account switch: no picture, no pending remote work.
  Future<void> reset() async {
    await _store.reset();
    state = null;
  }
}

/// Public provider to read and update the saved profile picture.
final profilePictureProvider = NotifierProvider<ProfilePictureNotifier, File?>(
  ProfilePictureNotifier.new,
);
