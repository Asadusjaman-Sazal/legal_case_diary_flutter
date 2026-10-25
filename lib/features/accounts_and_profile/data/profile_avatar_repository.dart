/// The profile picture's Storage boundary.
///
/// The `individual-avatars` bucket is private and holds one flat
/// `{user_id}.jpg` per account; the server's policies decide who may read,
/// write and delete it.
/// This interface is the seam the sync tests use, so no test needs a Storage
/// backend.
library;

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/repository_providers.dart';

/// The private bucket holding every individual account's picture.
const String profileAvatarBucket = 'individual-avatars';

/// The operations the app needs from the profile-picture bucket.
abstract class ProfileAvatarRepository {
  /// Writes (or replaces) the picture at [path].
  Future<void> upload(Uint8List bytes, String path);

  /// Reads the picture at [path].
  Future<Uint8List> download(String path);

  /// Removes the picture at [path].
  Future<void> remove(String path);
}

/// The repository used when this build has no backend configured.
class UnavailableProfileAvatarRepository implements ProfileAvatarRepository {
  /// Creates the repository.
  const UnavailableProfileAvatarRepository();

  @override
  Future<void> upload(Uint8List bytes, String path) async {}

  @override
  Future<Uint8List> download(String path) async => Uint8List(0);

  @override
  Future<void> remove(String path) async {}
}

/// Talks to the `individual-avatars` bucket under the caller's own session.
class SupabaseProfileAvatarRepository implements ProfileAvatarRepository {
  /// Creates the repository over [client].
  SupabaseProfileAvatarRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<void> upload(Uint8List bytes, String path) async {
    await _client.storage.from(profileAvatarBucket).uploadBinary(
      path,
      bytes,
      fileOptions: const FileOptions(
        contentType: 'image/jpeg',
        upsert: true,
      ),
    );
  }

  @override
  Future<Uint8List> download(String path) =>
      _client.storage.from(profileAvatarBucket).download(path);

  @override
  Future<void> remove(String path) =>
      _client.storage.from(profileAvatarBucket).remove(<String>[path]);
}

/// The repository for this build.
final profileAvatarRepositoryProvider = Provider<ProfileAvatarRepository>((
  ref,
) {
  final client = ref.watch(activeSupabaseClientProvider);
  return client == null
      ? const UnavailableProfileAvatarRepository()
      : SupabaseProfileAvatarRepository(client);
});
