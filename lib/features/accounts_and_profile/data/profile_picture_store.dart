/// Local profile picture store.
///
/// The picked image is copied into app documents storage (the picker path
/// lives in a cache directory the OS may purge) and its path is remembered in
/// [SharedPreferences], so the picture survives app restarts and is shared by
/// every screen that shows the user's profile.
///
/// Part A: local-only. Task 17 (Part B) uploads the file and stores the remote
/// URL; this local copy stays the offline source of truth.
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/providers/shared_preferences_provider.dart';

/// Preference key holding the absolute path of the saved profile picture.
const String profilePicturePathKey = 'profile_picture_path';

/// Folder (inside app documents) holding the saved profile picture.
const String _pictureDirName = 'profile_picture';

/// Reads and writes the user's profile picture file locally.
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

  /// Copies [sourcePath] into app storage, drops the previous picture, and
  /// persists the new path. Returns the saved file.
  Future<File> save(String sourcePath) async {
    final documents = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(documents.path, _pictureDirName));
    await dir.create(recursive: true);

    final extension = p.extension(sourcePath);
    final target = File(p.join(
      dir.path,
      'avatar_${DateTime.now().millisecondsSinceEpoch}'
          '${extension.isEmpty ? '.jpg' : extension}',
    ));
    await File(sourcePath).copy(target.path);

    await _deleteSavedFile();
    await _prefs.setString(profilePicturePathKey, target.path);
    return target;
  }

  /// Removes the saved picture file and its stored path.
  Future<void> clear() async {
    await _deleteSavedFile();
    await _prefs.remove(profilePicturePathKey);
  }

  /// Deletes the currently stored picture file, if any.
  Future<void> _deleteSavedFile() async {
    final path = _prefs.getString(profilePicturePathKey);
    if (path == null) return;
    final file = File(path);
    if (file.existsSync()) await file.delete();
  }
}

/// Riverpod state for the locally saved profile picture.
///
/// The initial value is read synchronously from [SharedPreferences], so every
/// screen (Profile, Manage Account) shows the same picture without an async
/// gap. Updates notify all listeners.
class ProfilePictureNotifier extends Notifier<File?> {
  late final ProfilePictureStore _store;

  @override
  File? build() {
    _store = ProfilePictureStore(ref.read(sharedPreferencesProvider));
    return _store.current();
  }

  /// Saves the image at [sourcePath] as the profile picture.
  Future<void> setFromPath(String sourcePath) async {
    state = await _store.save(sourcePath);
  }

  /// Clears the profile picture.
  Future<void> clear() async {
    await _store.clear();
    state = null;
  }
}

/// Public provider to read and update the saved profile picture.
final profilePictureProvider = NotifierProvider<ProfilePictureNotifier, File?>(
  ProfilePictureNotifier.new,
);
