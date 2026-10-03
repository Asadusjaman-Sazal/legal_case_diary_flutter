/// Shared test utilities for the Legal Case Diary test suite.
///
/// One helper so far: the error log every test needs once a view model records
/// into it. Kept here rather than in a feature's support file because the view
/// models that record span features, and a test should not have to import
/// another feature's harness to pump a widget.
library;

import 'package:flutter_riverpod/misc.dart' show Override;

import 'package:legal_case_diary/core/errors/error_log.dart';
import 'package:legal_case_diary/core/errors/error_log_provider.dart';

/// Adds an in-memory error log to [overrides], unless the caller already has.
///
/// main.dart always overrides `errorLogProvider`, and the view models record
/// into it as they let a failure out. Tests that also run through a harness
/// which seeds its own log — so the test can read it — must not be overridden
/// twice: Riverpod refuses a provider overridden twice in one container, so the
/// caller's own log wins rather than colliding.
List<Override> withErrorLog(List<Override> overrides) => <Override>[
  if (!overrides.any((o) => o.origin == errorLogProvider))
    errorLogProvider.overrideWithValue(ErrorLog()),
  ...overrides,
];