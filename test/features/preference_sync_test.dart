/// Tests for the premium per-user preference sync (plan §4).
///
/// `user_preferences` was empty on the server while the app kept writing
/// settings on the device, because the documented self-scoped preference path
/// had never been built. These tests pin that path: the two preference tables
/// travel to the account's own rows and come back newest-wins, per-user, and
/// never through the domain queue.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/core/providers/repository_providers.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/account_mode.dart';
import 'package:legal_case_diary/features/auth/data/auth_repository.dart';
import 'package:legal_case_diary/features/auth/presentation/auth_viewmodel.dart';
import 'package:legal_case_diary/features/settings/data/local/case_notification_preferences_dao.dart';
import 'package:legal_case_diary/features/settings/data/local/user_preferences_dao.dart';
import 'package:legal_case_diary/features/settings/data/preference_sync_service.dart';

import 'account_mode_test.dart' show seedProfile;
import 'auth_test_support.dart';

/// A [PreferenceRemote] the test drives: it holds the account's rows in memory
/// and records what the service asked it to save.
class _FakePreferenceRemote implements PreferenceRemote {
  /// The account the fake is signed in as; null stands for a signed-out device.
  String? userId = 'user-1';

  /// The account's own `user_preferences` row, or null when it has none.
  Map<String, Object?>? userPreferences;

  /// The account's own `case_notification_preferences` rows, by case id.
  Map<String, Map<String, Object?>> casePreferences =
      <String, Map<String, Object?>>{};

  /// Which case ids the account actually holds.
  Set<String> knownCaseIds = <String>{};

  /// Every `user_preferences` row written, in order.
  final List<Map<String, Object?>> savedUserPreferences =
      <Map<String, Object?>>[];

  /// Every `case_notification_preferences` batch written, in order.
  final List<List<Map<String, Object?>>> savedCasePreferences =
      <List<Map<String, Object?>>>[];

  /// When set, every call throws it — an unreachable server.
  Object? failure;

  void _reach() {
    final error = failure;
    if (error != null) throw error;
  }

  @override
  String? get currentUserId => userId;

  @override
  Future<Map<String, Object?>?> fetchUserPreferences() async {
    _reach();
    return userPreferences;
  }

  @override
  Future<void> saveUserPreferences(Map<String, Object?> row) async {
    _reach();
    savedUserPreferences.add(row);
    userPreferences = row;
  }

  @override
  Future<List<Map<String, Object?>>> fetchCasePreferences() async {
    _reach();
    return casePreferences.values.toList();
  }

  @override
  Future<void> saveCasePreferences(List<Map<String, Object?>> rows) async {
    _reach();
    savedCasePreferences.add(rows);
    for (final row in rows) {
      final caseId = row['case_id'];
      if (caseId is String) casePreferences[caseId] = row;
    }
  }

  @override
  Future<Set<String>> fetchKnownCaseIds(List<String> caseIds) async {
    _reach();
    return caseIds.where(knownCaseIds.contains).toSet();
  }
}

/// A [PreferenceSyncService] that only counts how often it was asked to run.
class _RecordingPreferenceSync implements PreferenceSyncService {
  /// How many reconcile attempts were made.
  int calls = 0;

  @override
  Future<bool> synchronize() async {
    calls++;
    return true;
  }
}

/// Lets the detached push/pull attempts run to completion.
///
/// A push runs on its own, so a test has to give the microtask queue and the
/// database's I/O a few turns before asserting on what it did.
Future<void> settle() async {
  for (var i = 0; i < 32; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// Seeds this device's own `user_preferences` row.
Future<void> seedLocalPreferences(
  AppDatabase db, {
  String userId = 'user-1',
  String? language = 'en',
  String? viewSettingsJson,
  bool notificationEnabled = false,
  int? notificationTime,
  String? notificationDefaultOffsets,
  required int updatedAt,
}) => UserPreferencesDao(db).upsert(
  UserPreferencesCompanion(
    userId: Value(userId),
    language: Value(language),
    viewSettingsJson: Value(viewSettingsJson),
    notificationEnabled: Value(notificationEnabled),
    notificationTime: Value(notificationTime),
    notificationDefaultOffsets: Value(notificationDefaultOffsets),
    updatedAt: Value(updatedAt),
  ),
);

/// Seeds one of this device's per-case notification preferences.
Future<void> seedLocalCasePreference(
  AppDatabase db, {
  String userId = 'user-1',
  required String caseId,
  bool enabled = true,
  String? offsets,
  int? timeMinutes,
  required int updatedAt,
}) => CaseNotificationPreferencesDao(db).upsert(
  CaseNotificationPreferencesCompanion(
    userId: Value(userId),
    caseId: Value(caseId),
    enabled: Value(enabled),
    offsets: Value(offsets),
    timeMinutes: Value(timeMinutes),
    updatedAt: Value(updatedAt),
  ),
);

/// One `user_preferences` row as the server would return it.
Map<String, Object?> serverUserPreferences({
  String? language = 'en',
  String? viewSettingsJson,
  bool notificationEnabled = false,
  int? notificationTime,
  String? notificationDefaultOffsets,
  required int updatedAt,
}) => <String, Object?>{
  'user_id': 'user-1',
  'language': language,
  'theme': null,
  'view_settings_json': viewSettingsJson,
  'notification_enabled': notificationEnabled,
  'notification_time': notificationTime,
  'notification_default_offsets': notificationDefaultOffsets,
  'updated_at': updatedAt,
};

/// One `case_notification_preferences` row as the server would return it.
Map<String, Object?> serverCasePreferences(
  String caseId, {
  bool enabled = true,
  String? offsets,
  int? timeMinutes,
  required int updatedAt,
}) => <String, Object?>{
  'user_id': 'user-1',
  'case_id': caseId,
  'enabled': enabled,
  'offsets': offsets,
  'time_minutes': timeMinutes,
  'updated_at': updatedAt,
};

void main() {
  // The reconcile is asserted against a real in-memory database; only the server
  // boundary is a fake, because the comparison rules are what is under test.
  group('The reconcile', () {
    late AppDatabase db;
    late _FakePreferenceRemote remote;
    late PreferenceSyncService service;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      remote = _FakePreferenceRemote();
      service = PreferenceSyncService(remote, db);
    });

    tearDown(() => db.close());

    group('The account row', () {
      test(
        'the payload names the server\'s own columns, and never the theme',
        () async {
          await seedLocalPreferences(
            db,
            language: 'bn',
            viewSettingsJson: '{"font_size_step":2}',
            notificationEnabled: true,
            notificationTime: 540,
            notificationDefaultOffsets: '[1,2]',
            updatedAt: 200,
          );
          final row = (await UserPreferencesDao(db).getByUserId('user-1'))!;

          expect(userPreferencesPayload(row), <String, Object?>{
            'user_id': 'user-1',
            'language': 'bn',
            'view_settings_json': '{"font_size_step":2}',
            'notification_enabled': true,
            'notification_time': 540,
            'notification_default_offsets': '[1,2]',
            'updated_at': 200,
          });
          // Nothing in the app writes `theme`; sending the stored null could
          // only erase a value the account set elsewhere.
          expect(userPreferencesPayload(row).containsKey('theme'), isFalse);
        },
      );

      test('the companion reads the server\'s columns back', () {
        final companion = userPreferencesCompanion(
          serverUserPreferences(
            language: 'bn',
            notificationEnabled: true,
            notificationTime: 600,
            notificationDefaultOffsets: '[3]',
            viewSettingsJson: '{"font_size_step":1}',
            updatedAt: 500,
          ),
          userId: 'user-1',
        );

        expect(companion.userId.value, 'user-1');
        expect(companion.language.value, 'bn');
        expect(companion.notificationEnabled.value, isTrue);
        expect(companion.notificationTime.value, 600);
        expect(companion.notificationDefaultOffsets.value, '[3]');
        expect(companion.viewSettingsJson.value, '{"font_size_step":1}');
        expect(companion.updatedAt.value, 500);
      });

      test(
        'a local row newer than the account\'s is pushed, and is not overwritten',
        () async {
          await seedLocalPreferences(db, language: 'bn', updatedAt: 200);
          remote.userPreferences = serverUserPreferences(
            language: 'en',
            updatedAt: 100,
          );

          expect(await service.synchronize(), isTrue);

          expect(remote.savedUserPreferences.single, <String, Object?>{
            'user_id': 'user-1',
            'language': 'bn',
            'view_settings_json': null,
            'notification_enabled': false,
            'notification_time': null,
            'notification_default_offsets': null,
            'updated_at': 200,
          });
          final local = (await UserPreferencesDao(db).getByUserId('user-1'))!;
          expect(local.language, 'bn', reason: 'the older row never wins');
          expect(local.updatedAt, 200);
        },
      );

      test('a newer account row is adopted, and nothing is pushed', () async {
        await seedLocalPreferences(db, language: 'en', updatedAt: 100);
        remote.userPreferences = serverUserPreferences(
          language: 'bn',
          notificationEnabled: true,
          notificationTime: 600,
          updatedAt: 200,
        );

        expect(await service.synchronize(), isTrue);

        final local = (await UserPreferencesDao(db).getByUserId('user-1'))!;
        expect(local.language, 'bn');
        expect(local.notificationEnabled, isTrue);
        expect(local.notificationTime, 600);
        expect(local.updatedAt, 200);
        expect(remote.savedUserPreferences, isEmpty);
      });

      test(
        'a device that never stored a row takes the account\'s first',
        () async {
          remote.userPreferences = serverUserPreferences(
            language: 'bn',
            updatedAt: 300,
          );

          expect(await service.synchronize(), isTrue);

          final local = (await UserPreferencesDao(db).getByUserId('user-1'))!;
          expect(local.language, 'bn');
          expect(local.updatedAt, 300);
          expect(remote.savedUserPreferences, isEmpty);
        },
      );

      test('an account with no row of its own takes this device\'s', () async {
        await seedLocalPreferences(db, language: 'bn', updatedAt: 300);

        expect(await service.synchronize(), isTrue);

        expect(remote.savedUserPreferences, hasLength(1));
        expect(remote.savedUserPreferences.single['language'], 'bn');
      });

      test('an equal stamp writes nothing either way', () async {
        await seedLocalPreferences(db, language: 'bn', updatedAt: 100);
        remote.userPreferences = serverUserPreferences(
          language: 'en',
          updatedAt: 100,
        );

        expect(await service.synchronize(), isTrue);

        expect(remote.savedUserPreferences, isEmpty);
        final local = (await UserPreferencesDao(db).getByUserId('user-1'))!;
        expect(local.language, 'bn');
      });

      test(
        'a save that could not reach the server is sent by the next attempt',
        () async {
          await seedLocalPreferences(db, language: 'bn', updatedAt: 200);
          remote.failure = Exception('offline');

          expect(
            await service.synchronize(),
            isFalse,
            reason: 'the attempt failed',
          );
          expect(remote.savedUserPreferences, isEmpty);
          // The retry is the comparison, not a flag: the local row is still the
          // newer one, so the next attempt sends it.
          expect(
            (await UserPreferencesDao(db).getByUserId('user-1'))!.updatedAt,
            200,
          );

          remote.failure = null;
          expect(await service.synchronize(), isTrue);
          expect(remote.savedUserPreferences, hasLength(1));
          expect(remote.savedUserPreferences.single['language'], 'bn');
        },
      );

      test('no account means nothing is read or written', () async {
        await seedLocalPreferences(db, language: 'bn', updatedAt: 200);
        remote.userId = null;

        expect(await service.synchronize(), isFalse);

        expect(remote.savedUserPreferences, isEmpty);
        expect(
          (await UserPreferencesDao(db).getByUserId('user-1'))!.language,
          'bn',
        );
      });

      test('a build with no backend is inert', () async {
        await seedLocalPreferences(db, language: 'bn', updatedAt: 200);
        final offline = PreferenceSyncService(
          const OfflinePreferenceRemote(),
          db,
        );

        expect(await offline.synchronize(), isFalse);

        expect(remote.savedUserPreferences, isEmpty);
        expect(
          (await UserPreferencesDao(db).getByUserId('user-1'))!.language,
          'bn',
        );
      });
    });

    group('The per-case rows', () {
      test('each row travels the way its own stamp says', () async {
        await seedLocalCasePreference(
          db,
          caseId: 'case-a',
          enabled: false,
          updatedAt: 200,
        );
        await seedLocalCasePreference(db, caseId: 'case-b', updatedAt: 50);
        remote.casePreferences = <String, Map<String, Object?>>{
          'case-a': serverCasePreferences(
            'case-a',
            enabled: true,
            updatedAt: 100,
          ),
          'case-c': serverCasePreferences(
            'case-c',
            timeMinutes: 480,
            updatedAt: 300,
          ),
        };
        remote.knownCaseIds = <String>{'case-a', 'case-b', 'case-c'};

        expect(await service.synchronize(), isTrue);

        // This device's two newer rows go up; the account's older one does not.
        final pushed = remote.savedCasePreferences.single;
        expect(pushed, hasLength(2));
        expect(pushed, containsAll(<Map<String, Object?>>[
          <String, Object?>{
            'user_id': 'user-1',
            'case_id': 'case-a',
            'enabled': false,
            'offsets': null,
            'time_minutes': null,
            'updated_at': 200,
          },
          <String, Object?>{
            'user_id': 'user-1',
            'case_id': 'case-b',
            'enabled': true,
            'offsets': null,
            'time_minutes': null,
            'updated_at': 50,
          },
        ]));

        final dao = CaseNotificationPreferencesDao(db);
        // The local row was the newer one, so it stands.
        expect((await dao.get('user-1', 'case-a'))!.enabled, isFalse);
        // The account's newer row was adopted, and its brand-new one came down.
        expect((await dao.get('user-1', 'case-c'))!.timeMinutes, 480);
      });

      test(
        'a preference for a case the account does not hold is not sent',
        () async {
          await seedLocalCasePreference(db, caseId: 'case-new', updatedAt: 500);
          remote.knownCaseIds = <String>{};

          expect(await service.synchronize(), isTrue);

          expect(remote.savedCasePreferences, isEmpty);
          // The row waits on the device until the case reaches the account.
          expect(
            (await CaseNotificationPreferencesDao(
              db,
            ).get('user-1', 'case-new'))!.updatedAt,
            500,
          );
        },
      );

      test(
        'an account row for a case this device does not have yet is kept',
        () async {
          remote.casePreferences = <String, Map<String, Object?>>{
            'case-remote': serverCasePreferences(
              'case-remote',
              timeMinutes: 420,
              updatedAt: 300,
            ),
          };

          expect(await service.synchronize(), isTrue);

          expect(
            (await CaseNotificationPreferencesDao(
              db,
            ).get('user-1', 'case-remote'))!.timeMinutes,
            420,
          );
          expect(remote.savedCasePreferences, isEmpty);
        },
      );
    });

    group('The table class', () {
      test(
        'a pushed preference creates no queue entry and touches no firm-shared table',
        () async {
          await seedLocalPreferences(db, language: 'bn', updatedAt: 200);
          await seedLocalCasePreference(db, caseId: 'case-a', updatedAt: 200);
          remote.knownCaseIds = <String>{'case-a'};

          expect(await service.synchronize(), isTrue);

          expect(remote.savedUserPreferences, hasLength(1));
          expect(remote.savedCasePreferences.single, hasLength(1));
          // Per-user preferences are never a queued domain mutation, and they
          // never land in the editable reference data a firm shares (rule 4).
          expect(await db.select(db.syncQueue).get(), isEmpty);
          expect(await db.select(db.courtCategories).get(), isEmpty);
          expect(await db.select(db.courts).get(), isEmpty);
          expect(await db.select(db.caseTypes).get(), isEmpty);
          expect(await db.select(db.steps).get(), isEmpty);
          expect(await db.select(db.onBehalfs).get(), isEmpty);
        },
      );
    });
  });

  group('The premium gate', () {
    late _RecordingPreferenceSync recorder;

    setUp(() => recorder = _RecordingPreferenceSync());

    /// A live container for [auth], with the preference sync recorded rather
    /// than run, and the session already restored.
    Future<(ProviderContainer, AuthTestHarness)> containerFor(
      FakeAuthRepository auth,
    ) async {
      final harness = AuthTestHarness(auth: auth);
      final overrides = await harness.setUp(
        extra: <Override>[
          preferenceSyncServiceProvider.overrideWith((_) async => recorder),
        ],
      );
      final container = ProviderContainer(overrides: overrides);
      addTearDown(() async {
        container.dispose();
        await harness.tearDown();
        await auth.dispose();
      });
      await container.read(authViewModelProvider.future);
      return (container, harness);
    }

    /// A fake signed in as the account every other test uses.
    FakeAuthRepository signedIn() =>
        FakeAuthRepository(identity: const AuthIdentity(userId: 'user-1'));

    test('a free account never reaches the server', () async {
      final (container, _) = await containerFor(signedIn());

      container.read(pushPreferencesProvider)();
      await settle();

      expect(recorder.calls, 0, reason: 'plan §6: a free plan does not sync');
    });

    test('a premium account syncs', () async {
      final (container, harness) = await containerFor(signedIn());
      await seedProfile(
        harness.db,
        userId: 'user-1',
        subscriptionExpiry: DateTime.now()
            .toUtc()
            .add(const Duration(days: 30))
            .millisecondsSinceEpoch,
      );

      container.read(pushPreferencesProvider)();
      await settle();

      expect(recorder.calls, 1);
    });

    test('a signed-out device syncs nothing', () async {
      final (container, _) = await containerFor(FakeAuthRepository());

      container.read(pushPreferencesProvider)();
      await settle();

      expect(recorder.calls, 0);
    });
  });
}
