/// The chamber logo's Storage boundary.
///
/// The bucket is private and holds one flat file per chamber,
/// `{firm_id}.jpg`; the server's policies decide who may read, write and
/// delete it. This interface is the seam every sync test uses, so no test needs
/// a Storage backend.
library;

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/repository_providers.dart';

/// The private bucket holding every chamber logo.
const String firmLogoBucket = 'firm-avatars';

/// The operations the app needs from the firm-logo bucket.
abstract class FirmLogoRepository {
  /// Writes (or replaces) the logo at [path].
  Future<void> upload(Uint8List bytes, String path);

  /// Reads the logo at [path].
  Future<Uint8List> download(String path);

  /// Removes the logo at [path].
  Future<void> remove(String path);
}

/// The repository used when this build has no backend configured.
class UnavailableFirmLogoRepository implements FirmLogoRepository {
  /// Creates the repository.
  const UnavailableFirmLogoRepository();

  @override
  Future<void> upload(Uint8List bytes, String path) async {}

  @override
  Future<Uint8List> download(String path) async => Uint8List(0);

  @override
  Future<void> remove(String path) async {}
}

/// Talks to the `firm-avatars` bucket under the caller's own session.
class SupabaseFirmLogoRepository implements FirmLogoRepository {
  /// Creates the repository over [client].
  SupabaseFirmLogoRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<void> upload(Uint8List bytes, String path) async {
    await _client.storage.from(firmLogoBucket).uploadBinary(
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
      _client.storage.from(firmLogoBucket).download(path);

  @override
  Future<void> remove(String path) =>
      _client.storage.from(firmLogoBucket).remove(<String>[path]);
}

/// The repository for this build.
final firmLogoRepositoryProvider = Provider<FirmLogoRepository>((ref) {
  final client = ref.watch(activeSupabaseClientProvider);
  return client == null
      ? const UnavailableFirmLogoRepository()
      : SupabaseFirmLogoRepository(client);
});
