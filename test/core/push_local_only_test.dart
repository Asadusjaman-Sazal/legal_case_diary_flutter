/// Source-level guards for the admin push path.
///
/// Two rules cannot be checked by running the app on this host, because FCM's
/// background isolate never exists here: the message handler must stay purely
/// local, and the Firebase packages must stay behind one boundary. Reading the
/// sources is cheap, and both would otherwise rot silently as the feature grows —
/// the same reasoning (and shape) as `notification_local_only_test.dart` for the
/// daily hearing job.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _folder = 'lib/core/push/';

/// Files that make up the push layer.
List<File> _sources() => Directory(_folder)
    .listSync()
    .whereType<File>()
    .where((file) => file.path.endsWith('.dart'))
    .toList();

/// Import URIs of one source file, as written in the file.
List<String> _imports(File file) => RegExp(r"import\s+'([^']+)'")
    .allMatches(file.readAsStringSync())
    .map((match) => match.group(1)!)
    .toList();

String _name(File file) => file.uri.pathSegments.last;

/// The file with its comments stripped, so a documented rule is not mistaken for
/// a broken one.
String _code(File file) => file
    .readAsLinesSync()
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  test('the push sources exist', () {
    expect(
      _sources().map(_name),
      containsAll(<String>[
        'admin_push_scope.dart',
        'device_token_repository.dart',
        'payment_alert_message.dart',
        'push_gateway.dart',
      ]),
    );
  });

  test('Firebase packages are imported by the gateway alone', () {
    const firebase = <String>['firebase_core', 'firebase_messaging'];
    for (final file in _sources()) {
      for (final import in _imports(file)) {
        if (!firebase.any(import.contains)) continue;
        expect(
          _name(file),
          'push_gateway.dart',
          reason: '$_name imports $import — the SDK belongs behind the gateway, '
              'so call sites (and the Windows port) stay free of it.',
        );
      }
    }
  });

  test('the message path never reaches a network, database or sync API', () {
    // The registration half is a deliberate server write, and the scope is its
    // caller; everything that runs *on a message* — the foreground listener, the
    // background isolate and the words they post — must not touch any of these.
    const forbiddenPackages = <String>[
      'supabase',
      'http/',
      'dio',
      'web_socket_channel',
      'drift',
    ];
    const forbiddenSymbols = <String>[
      'Supabase',
      'sync_queue',
      'SyncWriteHelper',
      'AppDatabase',
      'HttpClient',
    ];

    for (final file in _sources().where(
      (file) => !<String>[
        'device_token_repository.dart',
        'admin_push_scope.dart',
      ].contains(_name(file)),
    )) {
      for (final import in _imports(file)) {
        for (final package in forbiddenPackages) {
          expect(
            import.contains(package),
            isFalse,
            reason: '${file.path} imports $import — a push handler must stay '
                'local (plan §12.3: no background network, GPS or Supabase '
                'calls), which is what keeps its battery cost at one '
                'notification.',
          );
        }
      }
      for (final symbol in forbiddenSymbols) {
        expect(
          _code(file).contains(symbol),
          isFalse,
          reason: '$symbol appears in ${file.path} — the message path must do '
              'nothing but post the count it was sent.',
        );
      }
    }
  });

  test('the background entry point stays annotated and posts through the gateway', () {
    final gateway = File('${_folder}push_gateway.dart').readAsStringSync();

    expect(
      gateway.contains("@pragma('vm:entry-point')"),
      isTrue,
      reason: 'FCM resolves the handler by callback handle; without the '
          'annotation a release build can strip it.',
    );
    expect(
      gateway.contains(
        'Future<void> pushGatewayBackgroundHandler(RemoteMessage message)',
      ),
      isTrue,
      reason: 'The handler has to be top-level with FCM\'s own signature.',
    );
    expect(
      gateway.contains(
        'FirebaseMessaging.onBackgroundMessage(pushGatewayBackgroundHandler)',
      ),
      isTrue,
      reason: 'A message that arrives while the app is closed is only handled '
          'if it was registered before the app was stopped.',
    );
    expect(
      gateway.contains('applyPaymentAlert(message.data)'),
      isTrue,
      reason: 'Both halves post the same line through one function.',
    );
  });

  test('the count is one notification id, replaced and cleared', () {
    // The user's decision: ten requests read as one line, not ten notifications.
    // A stacked id, or a missing cancel, is exactly how that breaks.
    final gateway = File(
      'lib/core/notifications/android_notification_gateway.dart',
    ).readAsStringSync();

    expect(gateway.contains('static const int paymentAlertNotificationId'), isTrue);
    expect(gateway.contains('id: paymentAlertNotificationId'), isTrue);
    expect(
      gateway.contains('await _plugin.cancel(id: paymentAlertNotificationId)'),
      isTrue,
      reason: 'A total of zero has to take the line down, not announce it.',
    );
  });

  test('the count is never composed on the server', () {
    // The words live in the ARB files, which is what makes বাংলা correct; the
    // sender sends numbers. This is the client's half of that contract.
    final message = File('${_folder}payment_alert_message.dart').readAsStringSync();

    expect(message.contains('adminPush_bodyMany('), isTrue);
    expect(
      message.contains('AppDateUtils.formatDigits('),
      isTrue,
      reason: 'The count is written in the active language\'s own digits.',
    );
    expect(
      message.contains('payload: paymentAlertPayload'),
      isTrue,
      reason: 'The line has to carry the marker a tap resolves into a screen — '
          'without it a tap would open a case detail named after the marker.',
    );
  });
}
