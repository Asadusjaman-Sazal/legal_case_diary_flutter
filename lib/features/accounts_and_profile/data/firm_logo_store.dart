/// The chamber logo's local copy and its sync bookkeeping.
///
/// The file is the offline truth the side menu draws; the three preferences
/// beside it say what the remote copy is doing (which version was downloaded,
/// and whether a local change is waiting to go up or to be removed). They are
/// per-account like every other picture cache and are cleared on logout.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/providers/shared_preferences_provider.dart';

/// Preference key holding the absolute path of the saved chamber logo.
const String firmLogoPathKey = 'firm_logo_path';
const String _firmIdKey = 'firm_logo_firm_id';
const String _remoteVersionKey = 'firm_logo_remote_version';
const String _uploadPendingKey = 'firm_logo_upload_pending';
const String _deletePendingKey = 'firm_logo_delete_pending';

/// Folder (inside app documents) holding the saved chamber logo.
const String _logoDirName = 'firm_logo';

/// Reads and writes the chamber logo file and its remote-state preferences.
class FirmLogoStore {
  /// Creates a store backed by [prefs].
  FirmLogoStore(this._prefs);

  final SharedPreferences _prefs;

  /// The saved logo, or null when none is set or the file is gone.
  File? current() {
    final path = _prefs.getString(firmLogoPathKey);
    if (path == null) return null;
    final file = File(path);
    return file.existsSync() ? file : null;
  }

  /// The chamber the local file belongs to, or null.
  String? get firmId => _prefs.getString(_firmIdKey);

  /// The server version this file corresponds to, or null when it has never
  /// been synced (a fresh local choice, or an uploaded one awaiting its pull).
  int? get remoteVersion => _prefs.getInt(_remoteVersionKey);

  /// Whether a local picture is waiting to be uploaded.
  bool get uploadPending => _prefs.getBool(_uploadPendingKey) ?? false;

  /// Whether the remote copy is waiting to be deleted.
  bool get deletePending => _prefs.getBool(_deletePendingKey) ?? false;

  /// Writes [bytes] as [firmId]'s logo, replacing the previous file.
  Future<File> write(Uint8List bytes, String firmId) async {
    final documents = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(documents.path, _logoDirName));
    await dir.create(recursive: true);

    final target = File(p.join(dir.path, 'firm_$firmId.jpg'));
    final previous = _prefs.getString(firmLogoPathKey);
    if (previous != null &&
        previous != target.path &&
        File(previous).existsSync()) {
      await File(previous).delete();
    }
    await target.writeAsBytes(bytes, flush: true);
    await _prefs.setString(firmLogoPathKey, target.path);
    await _prefs.setString(_firmIdKey, firmId);
    return target;
  }

  /// Marks the local picture as waiting to go up, and cancels a pending delete.
  Future<void> markUploadPending() async {
    await _prefs.setBool(_uploadPendingKey, true);
    await _prefs.remove(_deletePendingKey);
  }

  /// The upload landed.
  Future<void> clearUploadPending() async {
    await _prefs.remove(_uploadPendingKey);
    // The server's new version is learned on the next pull.
    await _prefs.remove(_remoteVersionKey);
  }

  /// The local picture was removed while a remote copy existed.
  Future<void> markDeletePending() async {
    await _prefs.setBool(_deletePendingKey, true);
  }

  /// The remote copy is gone.
  Future<void> clearDeletePending() async {
    await _prefs.remove(_deletePendingKey);
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

  /// Deletes the local file and its path, leaving the remote bookkeeping.
  Future<void> removeLocal() async {
    final path = _prefs.getString(firmLogoPathKey);
    if (path != null) {
      final file = File(path);
      if (file.existsSync()) await file.delete();
    }
    await _prefs.remove(firmLogoPathKey);
  }

  /// The user deleted the picture: drop the local file and remember a remote
  /// delete when there is a remote copy to remove.
  Future<void> forgetLocal() async {
    final hadRemote = remoteVersion != null;
    await removeLocal();
    await _prefs.remove(_uploadPendingKey);
    if (hadRemote) {
      await markDeletePending();
    } else {
      await _prefs.remove(_deletePendingKey);
    }
  }

  /// Clears the local copy because the chamber's remote logo disappeared.
  Future<void> forgetRemote() async {
    await removeLocal();
    await _prefs.remove(_remoteVersionKey);
    await _prefs.remove(_uploadPendingKey);
    await _prefs.remove(_deletePendingKey);
  }

  /// Clears everything: logout, account switch, or a different chamber.
  Future<void> reset() async {
    await removeLocal();
    await _prefs.remove(_firmIdKey);
    await _prefs.remove(_remoteVersionKey);
    await _prefs.remove(_uploadPendingKey);
    await _prefs.remove(_deletePendingKey);
  }
}

/// The one store every reader and writer shares.
final firmLogoStoreProvider = Provider<FirmLogoStore>(
  (ref) => FirmLogoStore(ref.watch(sharedPreferencesProvider)),
);

/// Riverpod state for the locally saved chamber logo.
///
/// Read synchronously from [SharedPreferences], like the personal picture, so
/// the side menu shows the logo on its first frame rather than flashing a
/// fallback.
class FirmLogoNotifier extends Notifier<File?> {
  late final FirmLogoStore _store;

  @override
  File? build() {
    _store = ref.read(firmLogoStoreProvider);
    return _store.current();
  }

  /// A new local logo (already processed to 50 KB), waiting to be uploaded.
  Future<void> setBytes(Uint8List bytes, String firmId) async {
    state = await _store.write(bytes, firmId);
    await _store.markUploadPending();
  }

  /// Replaces the local file without changing what is pending (a legacy file
  /// compressed during its first upload).
  Future<void> replaceBytes(Uint8List bytes, String firmId) async {
    state = await _store.write(bytes, firmId);
  }

  /// The user removed the chamber logo.
  Future<void> clear() async {
    await _store.forgetLocal();
    state = null;
  }

  /// A downloaded logo from the chamber's bucket.
  Future<void> applyDownload(
    Uint8List bytes,
    String firmId,
    int version,
  ) async {
    state = await _store.write(bytes, firmId);
    await _store.clearPending();
    await _store.setRemoteVersion(version);
  }

  /// The chamber's remote logo is gone (removed by its owner elsewhere).
  Future<void> clearRemote() async {
    await _store.forgetRemote();
    state = null;
  }

  /// The upload landed: clear its pending state and let the next pull supply
  /// the new server version.
  ///
  /// A sentinel version is kept because the file is now remote: if the owner
  /// removes the logo before that pull arrives, the local copy must still know
  /// there is an object to delete. A real version (always ≥ 1) is greater than
  /// the sentinel, so the next pull downloads as usual.
  Future<void> markUploaded() async {
    await _store.clearUploadPending();
    await _store.setRemoteVersion(-1);
  }

  /// The remote delete landed.
  Future<void> markRemoteDeleted() async {
    await _store.clearDeletePending();
    state = null;
  }

  /// Logout, account switch, or a different chamber.
  Future<void> reset() async {
    await _store.reset();
    state = null;
  }
}

/// Public provider to read and update the saved chamber logo.
final firmLogoProvider = NotifierProvider<FirmLogoNotifier, File?>(
  FirmLogoNotifier.new,
);
