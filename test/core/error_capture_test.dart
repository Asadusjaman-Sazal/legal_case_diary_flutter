/// The global capture's one piece of formatting: what a framework error's
/// detail line says.
///
/// A framework error records as the bare label `FlutterError`, so this text is
/// the only thing that names it — the message first, then the library and
/// context that turn it into a place to look (0.0.406).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/core/errors/error_capture.dart';

void main() {
  test('a framework error\'s detail carries its message and where it came from', () {
    final details = FlutterErrorDetails(
      exception: FlutterError(
        'A RenderFlex overflowed by 12 pixels on the right.',
      ),
      library: 'rendering library',
      context: ErrorDescription('during layout'),
    );

    expect(
      describeFlutterError(details),
      'A RenderFlex overflowed by 12 pixels on the right. '
      '(rendering library · during layout)',
    );
  });

  test('a framework error with nowhere to point is just its message', () {
    final details = FlutterErrorDetails(
      exception: FlutterError('setState() called after dispose()'),
      library: '',
    );

    expect(
      describeFlutterError(details),
      'setState() called after dispose()',
    );
  });
}
