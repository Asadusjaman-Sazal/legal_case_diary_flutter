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
library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:legal_case_diary/features/settings/presentation/update_flow.dart';

const String _mainActivity =
    'android/app/src/main/kotlin/com/legalcasediary/app/MainActivity.kt';
const String _manifest = 'android/app/src/main/AndroidManifest.xml';

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
