/// The premium profile picture's local copy and its sync with the bucket.
///
/// The rules under test: a premium individual and a chamber owner sync; a free
/// account and a chamber member stay local; a lapsed account never uploads; an
/// owed upload or delete runs before the pulled version, so a stale pull cannot
/// overwrite a newer local choice; and a removed picture clears every device.
library;

import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:legal_case_diary/core/errors/error_log.dart';
import 'package:legal_case_diary/core/errors/error_log_provider.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/local/firms_dao.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/local/profiles_dao.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/profile_avatar_repository.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/profile_avatar_sync.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/profile_picture_store.dart';
import 'package:legal_case_diary/features/auth/data/auth_repository.dart';
import 'package:legal_case_diary/features/auth/presentation/auth_viewmodel.dart';
import 'package:legal_case_diary/shared/providers/database_provider.dart';
import 'package:legal_case_diary/shared/providers/shared_preferences_provider.dart';
import 'package:legal_case_diary/sync/connectivity_monitor.dart';

/// A Storage boundary whose answers and failures the test decides.
class _FakeAvatarRepository implements ProfileAvatarRepository {
  Uint8List answer = Uint8List.fromList(<int>[1, 2, 3]);
  bool fail = false;
  final List<String> uploads = <String>[];
  final List<String> downloads = <String>[];
  final List<String> removes = <String>[];

  @override
  Future<void> upload(Uint8List bytes, String path) async {
    uploads.add(path);
    if (fail) throw StateError('offline');
  }

  @override
  Future<Uint8List> download(String path) async {
    downloads.add(path);
    if (fail) throw StateError('offline');
    return answer;
  }

  @override
  Future<void> remove(String path) async {
    removes.add(path);
    if (fail) throw StateError('offline');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late Directory tempDir;
  late AppDatabase db;
  late _FakeAvatarRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
    tempDir = await Directory.systemTemp.createTemp('profile_avatar_sync_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => call.method == 'getApplicationDocumentsDirectory'
              ? tempDir.path
              : null,
        );
    db = AppDatabase(NativeDatabase.memory());
    repository = _FakeAvatarRepository();
  });

  tearDown(() async {
    await db.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  /// The signed-in account, with the picture state a test needs.
  Future<void> seed({
    String role = 'individual',
    String? firmId,
    String ownerId = 'user-1',
    bool live = true,
    String? avatarPath,
    int avatarVersion = 0,
  }) async {
    final expiry = DateTime.now()
        .add(Duration(days: live ? 30 : -3))
        .millisecondsSinceEpoch;
    await ProfilesDao(db).upsert(
      ProfilesCompanion(
        id: const Value('user-1'),
        fullName: const Value('Zaid'),
        role: Value(role),
        firmId: Value(firmId),
        subscriptionStatus: Value(live ? 'premium' : 'free'),
        subscriptionExpiry: Value(expiry),
        avatarPath: Value(avatarPath),
        avatarVersion: Value(avatarVersion),
        createdAt: const Value(1),
      ),
    );
    if (firmId != null) {
      await FirmsDao(db).upsert(
        FirmsCompanion(
          id: Value(firmId),
          name: const Value('Rahman & Associates'),
          ownerId: Value(ownerId),
          subscriptionStatus: Value(live ? 'premium' : 'free'),
          subscriptionExpiry: Value(expiry),
          tier: const Value('firm'),
          createdAt: const Value(1),
        ),
      );
    }
  }

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWith((_) async => db),
        authIdentityProvider.overrideWithValue(
          const AuthIdentity(userId: 'user-1', email: 'zaid@example.com'),
        ),
        errorLogProvider.overrideWithValue(ErrorLog()),
        profileAvatarRepositoryProvider.overrideWithValue(repository),
        isOnlineProvider.overrideWith((ref) => Stream<bool>.value(true)),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  /// Writes a local picture, the way a save or a download does.
  Future<void> writeLocal(
    ProviderContainer c,
    Uint8List bytes, {
    int? version,
    bool uploadPending = false,
  }) async {
    final store = c.read(profilePictureStoreProvider);
    await store.saveBytes(bytes);
    if (version != null) await store.setRemoteVersion(version);
    if (uploadPending) await store.markUploadPending();
  }

  Future<void> sync(ProviderContainer c) =>
      c.read(profileAvatarSyncProvider)();

  test('a newer remote picture is downloaded and remembered', () async {
    await seed(avatarPath: 'user-1.jpg', avatarVersion: 2);
    final c = container();

    await sync(c);

    expect(repository.downloads, <String>['user-1.jpg']);
    final store = c.read(profilePictureStoreProvider);
    expect(store.remoteVersion, 2);
    expect(store.current(), isNotNull);
    expect(c.read(profilePictureProvider), isNotNull);
  });

  test('a matching version is not downloaded again', () async {
    await seed(avatarPath: 'user-1.jpg', avatarVersion: 2);
    final c = container();
    await writeLocal(c, Uint8List.fromList(<int>[9]), version: 2);

    await sync(c);

    expect(repository.downloads, isEmpty);
  });

  test('a picture removed elsewhere clears the synced local copy', () async {
    await seed(avatarVersion: 3);
    final c = container();
    await writeLocal(c, Uint8List.fromList(<int>[9]), version: 2);

    await sync(c);

    final store = c.read(profilePictureStoreProvider);
    expect(store.current(), isNull);
    expect(store.remoteVersion, isNull);
    expect(c.read(profilePictureProvider), isNull);
  });

  test('a premium individual uploads a pending picture, then stops', () async {
    await seed(avatarPath: 'user-1.jpg', avatarVersion: 1);
    final c = container();
    await writeLocal(
      c,
      Uint8List.fromList(<int>[7, 7, 7]),
      uploadPending: true,
    );

    await sync(c);

    expect(repository.uploads, <String>['user-1.jpg']);
    expect(repository.downloads, isEmpty);
    final store = c.read(profilePictureStoreProvider);
    expect(store.uploadPending, isFalse);
    // The sentinel says the file is remote before the next pull names its
    // version, so a removal right after the upload still deletes the object.
    expect(store.remoteVersion, -1);
  });

  test('a free individual never uploads', () async {
    await seed(live: false);
    final c = container();
    await writeLocal(c, Uint8List.fromList(<int>[7]), uploadPending: true);

    await sync(c);

    expect(repository.uploads, isEmpty);
    expect(c.read(profilePictureStoreProvider).uploadPending, isTrue);
  });

  test('a chamber member never uploads, even while the chamber is premium', () async {
    await seed(role: 'associate', firmId: 'firm-1', ownerId: 'user-2');
    final c = container();
    await writeLocal(c, Uint8List.fromList(<int>[7]), uploadPending: true);

    await sync(c);

    expect(repository.uploads, isEmpty);
    expect(c.read(profilePictureStoreProvider).uploadPending, isTrue);
  });

  test('a chamber owner uploads through the chamber plan', () async {
    await seed(role: 'owner', firmId: 'firm-1');
    final c = container();
    await writeLocal(c, Uint8List.fromList(<int>[7]), uploadPending: true);

    await sync(c);

    expect(repository.uploads, <String>['user-1.jpg']);
  });

  test('a lapsed chamber owner never uploads', () async {
    await seed(role: 'owner', firmId: 'firm-1', live: false);
    final c = container();
    await writeLocal(c, Uint8List.fromList(<int>[7]), uploadPending: true);

    await sync(c);

    expect(repository.uploads, isEmpty);
    expect(c.read(profilePictureStoreProvider).uploadPending, isTrue);
  });

  test('a pending delete removes the remote object and forgets it', () async {
    await seed(avatarPath: 'user-1.jpg', avatarVersion: 2);
    final c = container();
    await writeLocal(c, Uint8List.fromList(<int>[9]), version: 2);
    await c.read(profilePictureProvider.notifier).clear();

    await sync(c);

    expect(repository.removes, <String>['user-1.jpg']);
    final store = c.read(profilePictureStoreProvider);
    expect(store.deletePending, isFalse);
    expect(store.remoteVersion, isNull);
    expect(store.current(), isNull);
  });

  test('a failed upload keeps the picture pending for the next refresh', () async {
    await seed();
    final c = container();
    await writeLocal(c, Uint8List.fromList(<int>[7]), uploadPending: true);
    repository.fail = true;

    await sync(c);

    expect(repository.uploads, <String>['user-1.jpg']);
    expect(repository.downloads, isEmpty);
    final store = c.read(profilePictureStoreProvider);
    expect(store.uploadPending, isTrue);
    expect(store.remoteVersion, isNull);
  });

  test('a just-uploaded picture is not cleared by a stale pull', () async {
    await seed();
    final c = container();
    await writeLocal(c, Uint8List.fromList(<int>[9]));
    await c.read(profilePictureStoreProvider).setRemoteVersion(-1);

    await sync(c);

    // The cached profile row has not caught up with the upload yet; the user's
    // own file must survive until it does.
    expect(c.read(profilePictureStoreProvider).current(), isNotNull);
    expect(c.read(profilePictureStoreProvider).remoteVersion, -1);
  });
}
