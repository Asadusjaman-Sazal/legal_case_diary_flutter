/// Catches what nothing else catches.
///
/// Every other failure path in this app is a `try`/`catch` inside a feature: the
/// sync worker, the repositories, the auth flows. What none of them can see is a
/// framework assertion, a build error, or an `async` throw nobody awaited — and
/// those are precisely the faults that reach a user as a blank screen or a
/// silent no-op with nothing anywhere to explain them.
///
/// This closes that hole in one place, at startup.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'error_log.dart';

/// Records every error Flutter or the platform reports, then lets the handler
/// that was already installed run.
///
/// **The delegation is the point.** A capture that swallowed would hide the very
/// failures it exists to find, and would change the debug output the rest of the
/// project is read through. So Flutter's own presenter still runs, and the
/// platform's previous handler still gets its say — and, because returning false
/// keeps the default behaviour (a crash in debug, a log in release), an error
/// that used to be visible is never made invisible by being recorded.
void installErrorCapture(ErrorLog log) {
  final previousFlutterHandler = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    // Not awaited: the handler is synchronous by contract, and the write is a
    // diagnostics errand that must not delay the frame that is failing.
    unawaited(log.record('framework', details.exception));
    if (previousFlutterHandler != null) {
      previousFlutterHandler(details);
    } else {
      FlutterError.presentError(details);
    }
  };

  final previousPlatformHandler = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    unawaited(log.record('platform', error));
    return previousPlatformHandler?.call(error, stack) ?? false;
  };
}
