/// The chamber logo's local copy and its sync with the bucket.
///
/// The order under test is the part a user would notice if it broke: an owed
/// upload or delete runs before the pulled version is followed, so a stale pull
/// can never overwrite a newer local choice; a member never uploads; a lapsed
/// chamber never uploads; and a logo removed on one device disappears on the
/// others.
library;

import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:legal_case_diary/core/errors/error_log.dart';
import 'package:legal_case_diary/core/errors/error_log_provider.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/firm_logo_repository.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/firm_logo_store.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/firm_logo_sync.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/local/firms_dao.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/local/profiles_dao.dart';
import 'package:legal_case_diary/features/auth/data/auth_repository.dart';
import 'package:legal_case_diary/features/auth/presentation/auth_viewmodel.dart';
import 'package:legal_case_diary/shared/providers/database_provider.dart';
import 'package:legal_case_diary/shared/providers/shared_preferences_provider.dart';
import 'package:legal_case_diary/sync/connectivity_monitor.dart';

/// A Storage boundary whose answers and failures the test decides.
class _FakeLogoRepository implements FirmLogoRepository {
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
  late _FakeLogoRepository repository;
  late bool online;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
    tempDir = await Directory.systemTemp.createTemp('firm_logo_sync_test');
    // The store resolves its folder through path_provider, which no test
    // platform provides.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => call.method == 'getApplicationDocumentsDirectory'
              ? tempDir.path
              : null,
        );
    db = AppDatabase(NativeDatabase.memory());
    repository = _FakeLogoRepository();
    online = true;
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

  /// The owner (user-1) and the chamber, with the logo state a test needs.
  Future<void> seed({
    String role = 'owner',
    String ownerId = 'user-1',
    bool live = true,
    String? logoPath,
    int logoVersion = 0,
  }) async {
    final expiry = DateTime.now()
        .add(Duration(days: live ? 30 : -3))
        .millisecondsSinceEpoch;
    await ProfilesDao(db).upsert(
      ProfilesCompanion(
        id: const Value('user-1'),
        fullName: const Value('Zaid'),
        role: Value(role),
        firmId: const Value('firm-1'),
        subscriptionStatus: Value(live ? 'premium' : 'free'),
        subscriptionExpiry: Value(expiry),
        createdAt: const Value(1),
      ),
    );
    await FirmsDao(db).upsert(
      FirmsCompanion(
        id: const Value('firm-1'),
        name: const Value('Rahman & Associates'),
        ownerId: Value(ownerId),
        subscriptionStatus: Value(live ? 'premium' : 'free'),
        subscriptionExpiry: Value(expiry),
        tier: const Value('firm'),
        logoPath: Value(logoPath),
        logoVersion: Value(logoVersion),
        createdAt: const Value(1),
      ),
    );
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
        firmLogoRepositoryProvider.overrideWithValue(repository),
        isOnlineProvider.overrideWith((ref) => Stream<bool>.value(online)),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  /// Stores [bytes] as the local logo, the way a save or a download does.
  Future<void> writeLocal(
    ProviderContainer c,
    Uint8List bytes, {
    int? version,
    bool uploadPending = false,
  }) async {
    await c.read(firmLogoStoreProvider).write(bytes, 'firm-1');
    if (version != null) {
      await c.read(firmLogoStoreProvider).setRemoteVersion(version);
    }
    if (uploadPending) {
      await c.read(firmLogoStoreProvider).markUploadPending();
    }
  }

  Future<void> sync(ProviderContainer c) =>
      c.read(firmLogoSyncProvider)();

  test('a newer remote logo is downloaded and remembered', () async {
    await seed(logoPath: 'firm-1.jpg', logoVersion: 2);
    final c = container();

    await sync(c);

    expect(repository.downloads, <String>['firm-1.jpg']);
    final store = c.read(firmLogoStoreProvider);
    expect(store.remoteVersion, 2);
    expect(store.current(), isNotNull);
    expect(c.read(firmLogoProvider), isNotNull);
    expect(
      await c.read(firmLogoProvider)!.readAsBytes(),
      repository.answer,
    );
  });

  test('a matching version is not downloaded again', () async {
    await seed(logoPath: 'firm-1.jpg', logoVersion: 2);
    final c = container();
    await writeLocal(c, Uint8List.fromList(<int>[9]), version: 2);

    await sync(c);

    expect(repository.downloads, isEmpty);
  });

  test('a logo removed elsewhere clears the synced local copy', () async {
    await seed(logoVersion: 3);
    final c = container();
    await writeLocal(c, Uint8List.fromList(<int>[9]), version: 2);

    await sync(c);

    final store = c.read(firmLogoStoreProvider);
    expect(store.current(), isNull);
    expect(store.remoteVersion, isNull);
    expect(c.read(firmLogoProvider), isNull);
  });

  test('the owner uploads a pending logo, and does not re-download it', () async {
    await seed(logoPath: 'firm-1.jpg', logoVersion: 1);
    final c = container();
    await writeLocal(
      c,
      Uint8List.fromList(<int>[7, 7, 7]),
      uploadPending: true,
    );

    await sync(c);

    expect(repository.uploads, <String>['firm-1.jpg']);
    expect(repository.downloads, isEmpty);
    final store = c.read(firmLogoStoreProvider);
    expect(store.uploadPending, isFalse);
    // A sentinel says the file is remote even before the next pull names its
    // version, so a removal right after the upload still deletes the object.
    expect(store.remoteVersion, -1);
  });

  test('a member never uploads, even with a pending local logo', () async {
    await seed(role: 'associate', ownerId: 'user-2');
    final c = container();
    await writeLocal(
      c,
      Uint8List.fromList(<int>[7]),
      uploadPending: true,
    );

    await sync(c);

    expect(repository.uploads, isEmpty);
    expect(c.read(firmLogoStoreProvider).uploadPending, isTrue);
  });

  test('a lapsed chamber owner never uploads', () async {
    await seed(live: false);
    final c = container();
    await writeLocal(
      c,
      Uint8List.fromList(<int>[7]),
      uploadPending: true,
    );

    await sync(c);

    expect(repository.uploads, isEmpty);
    expect(c.read(firmLogoStoreProvider).uploadPending, isTrue);
  });

  test('a pending delete removes the remote object and forgets it', () async {
    await seed(logoPath: 'firm-1.jpg', logoVersion: 2);
    final c = container();
    await writeLocal(c, Uint8List.fromList(<int>[9]), version: 2);
    await c.read(firmLogoProvider.notifier).clear();

    await sync(c);

    expect(repository.removes, <String>['firm-1.jpg']);
    final store = c.read(firmLogoStoreProvider);
    expect(store.deletePending, isFalse);
    expect(store.remoteVersion, isNull);
    expect(store.current(), isNull);
  });

  test('a failed upload keeps the logo pending for the next refresh', () async {
    await seed();
    final c = container();
    await writeLocal(
      c,
      Uint8List.fromList(<int>[7]),
      uploadPending: true,
    );
    repository.fail = true;

    await sync(c);

    expect(repository.uploads, <String>['firm-1.jpg']);
    expect(repository.downloads, isEmpty);
    final store = c.read(firmLogoStoreProvider);
    expect(store.uploadPending, isTrue);
    expect(store.remoteVersion, isNull);
  });

  test('a just-uploaded logo is not cleared by a stale pull', () async {
    await seed();
    final c = container();
    await writeLocal(c, Uint8List.fromList(<int>[9]));
    await c.read(firmLogoStoreProvider).setRemoteVersion(-1);

    await sync(c);

    // The cached firm row has not caught up with the upload yet; the owner's
    // own file must survive until it does.
    expect(c.read(firmLogoStoreProvider).current(), isNotNull);
    expect(c.read(firmLogoStoreProvider).remoteVersion, -1);
  });

  test('leaving the chamber clears the logo and its bookkeeping', () async {
    await seed(logoPath: 'firm-1.jpg', logoVersion: 2);
    final c = container();
    await writeLocal(c, Uint8List.fromList(<int>[9]), version: 2);

    // The profile no longer names a firm.
    await ProfilesDao(db).upsert(
      const ProfilesCompanion(
        id: Value('user-1'),
        fullName: Value('Zaid'),
        role: Value('individual'),
        firmId: Value(null),
        subscriptionStatus: Value('free'),
        createdAt: Value(1),
      ),
    );

    await sync(c);

    final store = c.read(firmLogoStoreProvider);
    expect(store.current(), isNull);
    expect(store.firmId, isNull);
    expect(store.remoteVersion, isNull);
  });

  test('a different chamber starts with no logo', () async {
    await seed(logoPath: 'firm-1.jpg', logoVersion: 2);
    final c = container();
    // A file belonging to another chamber, already on the device.
    await c.read(firmLogoStoreProvider).write(
      Uint8List.fromList(<int>[9]),
      'old-firm',
    );

    await sync(c);

    final store = c.read(firmLogoStoreProvider);
    expect(store.firmId, 'firm-1');
    expect(repository.downloads, <String>['firm-1.jpg']);
  });

  test('the local folder is inside the documents directory', () async {
    final c = container();
    final file = await c
        .read(firmLogoStoreProvider)
        .write(Uint8List.fromList(<int>[1]), 'firm-1');

    expect(p.isWithin(tempDir.path, file.path), isTrue);
  });
}
