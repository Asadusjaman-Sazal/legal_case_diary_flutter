import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

/// Entry point of the Legal Case Diary application.
/// Task 01: Initial setup with ProviderScope.
void main() {
  runApp(
    const ProviderScope(
      child: App(),
    ),
  );
}
