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
    // diagnostics errand that must not delay the frame that is failing. The
    // detail is built here because only this handler holds the [details] — a
    // bare `toString()` of the exception would lose the library and context
    // that turn a `FlutterError` into something fixable.
    unawaited(
      log.record(
        'framework',
        details.exception,
        detail: describeFlutterError(details),
      ),
    );
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

/// A framework error's message, with where the framework reported it.
///
/// The label for one of these is the bare word `FlutterError`, so the message
/// is the only thing that names it — "A RenderFlex overflowed by 12 pixels on
/// the right." — and the library and context ("rendering library · during
/// layout") are what make it a place to look.
String describeFlutterError(FlutterErrorDetails details) {
  final where = <String>[
    if (details.library != null) details.library!,
    if (details.context != null) details.context.toString(),
  ].join(' · ');
  final message = details.exception.toString();
  return where.isEmpty ? message : '$message ($where)';
}
