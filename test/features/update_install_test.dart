/// The in-app update's handoff to Android's installer.
///
/// This is the part a widget test cannot drive — the install runs in Kotlin,
/// through a platform channel, and needs a real device — so what is pinned here
/// is the contract either side of it that *can* be checked:
///
///  * the downloaded APK **outlives the handoff**, because `startActivity` only
///    dispatches an intent and Android's installer opens the file afterwards. A
///    file deleted in that gap is one the installer cannot read, which is what
///    made selecting *Package Installer* do nothing at all;
///  * it is deleted later, at the next launch, once the app is running the
///    offered version (the install landed) or the offer has gone;
///  * and the Kotlin and manifest halves carry the two things whose absence
///    produces the same silent no-op — the URI granted to every resolver rather
///    than only to the intent, and the package-visibility entry that makes those
///    resolvers visible at all on Android 11+.
///
/// Plus the authenticity half of direct distribution (firm-mode §5.6): a
/// downloaded APK not signed like this app is **refused by the host**, nothing
/// is dispatched, and the refusal reaches the user as its own answer instead of
/// as "this device cannot install an update".
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:legal_case_diary/core/providers/repository_providers.dart';
import 'package:legal_case_diary/features/settings/data/update_metadata_store.dart';
import 'package:legal_case_diary/features/settings/data/update_release.dart';
import 'package:legal_case_diary/features/settings/data/update_repository.dart';
import 'package:legal_case_diary/features/settings/presentation/app_install.dart';
import 'package:legal_case_diary/features/settings/presentation/update_flow.dart';
import 'package:legal_case_diary/shared/providers/shared_preferences_provider.dart';
import 'package:legal_case_diary/sync/connectivity_monitor.dart';

import '../test_utils.dart';

const String _mainActivity =
    'android/app/src/main/kotlin/com/legumsoft/legalcasediary/MainActivity.kt';
const String _manifest = 'android/app/src/main/AndroidManifest.xml';

/// A repository whose download writes real bytes and touches no network.
class _ByteWritingRepository extends UpdateRepository {
  _ByteWritingRepository(this.downloads);

  final List<String> downloads;

  @override
  Future<DownloadProgress> downloadRelease(
    AppRelease release,
    List<int> target, {
    void Function(int received, int total)? onProgress,
  }) async {
    downloads.add(release.version);
    target.addAll(<int>[1, 2, 3]);
    onProgress?.call(target.length, target.length);
    return (received: target.length, total: target.length);
  }
}

/// A monitor that answers "online, on Wi-Fi", so nothing else is in the way.
class _AlwaysOnlineMonitor implements ConnectivityMonitor {
  @override
  Future<bool> isOnline() async => true;

  @override
  Future<bool> isOnMobileData() async => false;

  @override
  Stream<bool> get onlineChanges => const Stream<bool>.empty();
}

void main() {
  // No widget is pumped here, so nothing else sets the binding up — and the
  // path_provider channel is mocked through it.
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory cache;

  setUp(() {
    cache = Directory.systemTemp.createTempSync('lcb_update_cache');
    // `updateApkFile` resolves through path_provider, which no test platform
    // provides — so the cache directory is answered by hand.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => call.method == 'getApplicationCacheDirectory'
              ? cache.path
              : null,
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    if (cache.existsSync()) cache.deleteSync(recursive: true);
  });

  group('deleteUpdateApkIfStale', () {
    test('keeps the APK while an update is still being offered', () async {
      // The case the bug was: the file must survive its own handoff, because
      // Android's installer reads it after `startActivity` returns.
      final apk = await updateApkFile();
      await apk.writeAsBytes(<int>[1, 2, 3]);

      final deleted = await deleteUpdateApkIfStale(apk, stillOffered: true);

      expect(deleted, isFalse);
      expect(apk.existsSync(), isTrue);
    });

    test('deletes it once nothing is being offered', () async {
      // Either the install landed (the app is now that version) or the offer
      // went away — both mean the file has served its purpose.
      final apk = await updateApkFile();
      await apk.writeAsBytes(<int>[1, 2, 3]);

      final deleted = await deleteUpdateApkIfStale(apk, stillOffered: false);

      expect(deleted, isTrue);
      expect(apk.existsSync(), isFalse);
    });

    test('nothing to delete is not an error', () async {
      final apk = await updateApkFile();
      expect(await deleteUpdateApkIfStale(apk, stillOffered: false), isFalse);
    });

    test('a file the OS will not release is left, not thrown over', () async {
      // Best-effort: a launch must not fail over a leftover file, and the next
      // launch tries again.
      final apk = await updateApkFile();
      await apk.writeAsBytes(<int>[1]);
      // A directory where the file should be: `delete` cannot remove it as a
      // file, which stands in for any OS refusal.
      await apk.delete();
      Directory(apk.path).createSync();

      expect(await deleteUpdateApkIfStale(apk, stillOffered: false), isFalse);
    });
  });

  test('the APK lives in the app cache, under one name', () async {
    // One name, and the same one the Kotlin side is handed as a path — the
    // FileProvider maps the cache directory it sits in.
    final apk = await updateApkFile();
    expect(p.dirname(apk.path), cache.path);
    expect(p.basename(apk.path), updateApkFileName);
  });

  group('installDownloadedApk', () {
    /// Answers the install channel as the host would.
    void answerHost(Future<Object?> Function(MethodCall call) handler) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(appInstallChannel, handler);
    }

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(appInstallChannel, null);
    });

    test('a handoff Android accepted is reported as such', () async {
      answerHost((call) async => null);

      expect(
        await installDownloadedApk('/cache/app.apk'),
        ApkInstallOutcome.handedOff,
      );
    });

    test('a host refusal is the unverified outcome, not a failed install', () async {
      // The distinction the user reads: "this update could not be verified" is
      // not "this device cannot install an update".
      answerHost(
        (call) async => throw PlatformException(
          code: apkUnverifiedSignatureCode,
          message: 'not signed by this app',
        ),
      );

      expect(
        await installDownloadedApk('/cache/app.apk'),
        ApkInstallOutcome.unverified,
      );
    });

    test('another refusal from the host keeps its old meaning', () async {
      answerHost(
        (call) async => throw PlatformException(code: 'missing_apk'),
      );

      expect(
        await installDownloadedApk('/cache/app.apk'),
        ApkInstallOutcome.unsupported,
      );
    });

    test('a platform with no install hook installs nothing and claims nothing', () async {
      // No handler at all, which is what a test or a desktop build looks like.
      expect(
        await installDownloadedApk('/cache/app.apk'),
        ApkInstallOutcome.unsupported,
      );
    });
  });

  group('a refused update (firm-mode §5.6)', () {
    /// Releases far ahead of the app, so the fixtures cannot go stale.
    const offered = AppRelease(
      version: '99.99.999',
      downloadUrl: 'https://x.test/app.apk',
    );

    /// What the fake download was asked for, cleared between cases.
    final downloads = <String>[];

    /// The host's answer for a release it cannot authenticate.
    Future<Object?> refuseInstall(MethodCall call) async {
      throw PlatformException(code: apkUnverifiedSignatureCode);
    }

    Future<ProviderContainer> containerOffering(
      UpdateRepository repo,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        updateAvailableReleaseKey: jsonEncode(offered.toJson()),
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: withErrorLog(<Override>[
          updateRepositoryProvider.overrideWithValue(repo),
          sharedPreferencesProvider.overrideWithValue(prefs),
          connectivityMonitorProvider.overrideWithValue(_AlwaysOnlineMonitor()),
        ]),
      );
      addTearDown(container.dispose);
      return container;
    }

    tearDown(() {
      downloads.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(appInstallChannel, null);
    });

    test('the update is not installed, and the reason is its own', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(appInstallChannel, refuseInstall);
      final repo = _ByteWritingRepository(downloads);
      final container = await containerOffering(repo);
      final flow = UpdateFlowController(container);
      addTearDown(flow.dispose);

      await flow.updateNow(offered);

      expect(downloads, <String>['99.99.999'], reason: 'the download happened');
      expect(flow.error, UpdateFlowError.unverifiedRelease);
      expect(
        flow.phase,
        UpdatePhase.idle,
        reason: 'a refusal is not "you are on the latest version"',
      );
      expect(
        container.read(updateMetadataProvider).availableRelease?.version,
        offered.version,
        reason: 'the offer is not retired behind the user, and still stands',
      );
    });

    test('a handoff Android accepted still clears the offer', () async {
      // The accepted case, unchanged: the dot must not outlive the update it
      // pointed at, and the refusal path must not have moved that.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(appInstallChannel, (call) async => null);
      final repo = _ByteWritingRepository(downloads);
      final container = await containerOffering(repo);
      final flow = UpdateFlowController(container);
      addTearDown(flow.dispose);

      await flow.updateNow(offered);

      expect(flow.error, isNull);
      expect(flow.phase, UpdatePhase.upToDate);
      expect(container.read(updateMetadataProvider).availableRelease, isNull);
    });
  });

  group('the Android half (read from source, since no test can run it)', () {
    late String kotlin;
    late String manifest;

    setUp(() {
      kotlin = File(_mainActivity).readAsStringSync();
      manifest = File(_manifest).readAsStringSync();
    });

    test('the URI is granted to every resolver, not only to the intent', () {
      // FLAG_GRANT_READ_URI_PERMISSION on the intent is not enough once Android
      // shows a chooser: the chooser does not forward the grant to the app the
      // user picks, so the installer gets a content:// URI it cannot read and
      // does nothing. This is the fix for the reported symptom.
      // Matched with the call's opening bracket: a bare name would still match
      // a renamed symbol, so the assertion would pass on a file that no longer
      // calls it at all.
      expect(kotlin, contains('queryIntentActivities('));
      expect(kotlin, contains('grantUriPermission('));
      expect(
        kotlin,
        contains('Intent.FLAG_GRANT_READ_URI_PERMISSION'),
        reason: 'the grant is read access',
      );
    });

    test('the install intent is VIEW with the APK mime type', () {
      expect(kotlin, contains('application/vnd.android.package-archive'));
      expect(
        kotlin,
        contains('Intent.FLAG_ACTIVITY_NEW_TASK'),
        reason: 'the installer opens in its own task, not on top of ours',
      );
    });

    test('the downloaded APK must be signed like this app', () {
      // Direct distribution puts no store review between a release and a diary,
      // so the host is what tells a release of ours from anything else: the
      // archive's signing certificate against the installed app's own.
      expect(kotlin, contains('apkSignatureMatchesInstalledApp('));
      expect(
        kotlin,
        contains('getPackageArchiveInfo('),
        reason: 'the downloaded archive is read',
      );
      expect(
        kotlin,
        contains('getPackageInfo(packageName,'),
        reason: 'and compared with the app already installed',
      );
      expect(
        kotlin,
        contains('MessageDigest.getInstance("SHA-256")'),
        reason: 'certificate bytes are hashed, not compared as text',
      );
      // minSdk is 24, so the pre-28 spelling is reachable at runtime; the check
      // must work on both rather than only on a modern phone.
      expect(kotlin, contains('GET_SIGNING_CERTIFICATES'));
      expect(kotlin, contains('GET_SIGNATURES'));
    });

    test('the check runs before the file is exposed or handed over', () {
      // Order, not mere presence: an APK checked *after* the installer was
      // offered it has already been offered an APK nobody verified.
      final check = kotlin.indexOf('apkSignatureMatchesInstalledApp(file)');
      final refusal = kotlin.indexOf('unverified_signature');
      final exposed = kotlin.indexOf('FileProvider.getUriForFile(');
      final dispatch = kotlin.indexOf('startActivity(');

      expect(check, isNonNegative, reason: 'the install path calls it');
      expect(refusal, greaterThan(check));
      expect(
        refusal,
        lessThan(exposed),
        reason: 'a refused APK is never given a content URI',
      );
      expect(
        refusal,
        lessThan(dispatch),
        reason: 'and no installer is offered it',
      );
      expect(
        kotlin.indexOf('return@setMethodCallHandler', refusal),
        isNonNegative,
        reason: 'the refusal leaves the handler rather than falling through',
      );
    });

    test('the package-visibility entry declares that intent', () {
      // Android 11+ hides every app handling an intent that is not declared, so
      // without this the resolver list is empty and the grants above never
      // happen — the same silent no-op by a different route.
      expect(
        manifest,
        contains('android.intent.action.VIEW'),
        reason: 'the installer is reachable',
      );
      expect(
        manifest,
        contains('application/vnd.android.package-archive'),
        reason: 'declared for the APK mime type',
      );
      expect(
        manifest,
        contains('android.permission.REQUEST_INSTALL_PACKAGES'),
        reason: 'and the app may ask the OS to install',
      );
    });
  });
}
