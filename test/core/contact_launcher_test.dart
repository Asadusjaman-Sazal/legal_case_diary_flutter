/// The mail-app entry point of the `ContactLauncher` seam.
///
/// The defect this pins: a `mailto:` URI is a *compose* request by definition
/// (RFC 6068), so the chooser Android raises for it can only offer each mail
/// app's compose activity — the user picks Gmail and gets an empty draft instead
/// of their mailbox. Open Mail therefore asks for Android's own "the email app"
/// intent (`MAIN` plus the `APP_EMAIL` category), and this file states the action
/// and the category it sends, and that a platform which cannot answer falls back
/// to the `mailto:` chooser rather than reporting a success it did not have.
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/core/services/contact_launcher.dart';

/// The channel `url_launcher`'s default implementation uses away from a device.
const MethodChannel _urlLauncherChannel = MethodChannel(
  'plugins.flutter.io/url_launcher',
);

/// What the mocked mail app answers; false stands in for no handler at all.
bool _handled = true;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// The URLs `url_launcher` was asked to open, in order.
  late List<String> launched;

  setUp(() {
    _handled = true;
    launched = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_urlLauncherChannel, (call) async {
          switch (call.method) {
            case 'launch':
              launched.add((call.arguments as Map)['url'] as String);
              return _handled;
            case 'canLaunch':
              return _handled;
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_urlLauncherChannel, null);
  });

  test('Open Mail asks Android for the email app, not a mailto: route', () {
    // `MAIN` plus `APP_EMAIL` is the OS's own "the email app" request: it opens
    // the app on its main screen, and where several apps declare the category
    // Android raises its own chooser of app entries.
    expect(androidMailAppIntent.action, 'android.intent.action.MAIN');
    expect(androidMailAppIntent.category, 'android.intent.category.APP_EMAIL');
    // No recipient and no subject: nothing here asks anyone to write anything.
    expect(androidMailAppIntent.data, isNull);
    expect(androidMailAppIntent.arguments, isNull);
  });

  test('a platform that cannot answer falls back to the mailto: chooser', () async {
    // This host is not Android, and the plugin says so by answering `false` to
    // `canResolveActivity` — so the fallback is the path taken, rather than a
    // silent success on a platform that cannot open anything.
    expect(await const UrlContactLauncher().openMailApp(), isTrue);
    expect(launched, ['mailto:']);
  });

  test('the fallback reports a device where nothing handles mail', () async {
    _handled = false;
    expect(await const UrlContactLauncher().openMailApp(), isFalse);
  });
}
