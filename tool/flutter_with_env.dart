/// Runs the Flutter tool with this build's Supabase credentials injected.
///
/// `lib/core/constants/supabase_config.dart` reads `SUPABASE_URL`,
/// `SUPABASE_ANON_KEY` and `GOOGLE_WEB_CLIENT_ID` through
/// `String.fromEnvironment`, so they are **compile-time** constants: every run
/// or build has to pass `--dart-define-from-file=env.json`. Forgetting the flag
/// is silent — the app simply starts in its offline shape and sign-in reports
/// that the build has no backend — so this wrapper is the one place the flag is
/// added, and it fails loudly when the file is missing instead of producing an
/// offline build by accident.
///
/// Debug and release go through the same path, because the wrapper just forwards
/// every argument it is given:
///
///   `dart run tool/flutter_with_env.dart run -d <device>`
///   `dart run tool/flutter_with_env.dart build apk --release`
///
/// `env.json` stays git-ignored (`.gitignore`), so no credential enters the
/// repository; a machine or CI job needs its own copy before building. An
/// absolute path is passed to Flutter, so the wrapper can be invoked from any
/// working directory.
library;

import 'dart:io';

/// The git-ignored file that holds this build's credentials.
const String envFileName = 'env.json';

/// Forwards [args] to `flutter` with the credentials file appended.
Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dart run tool/flutter_with_env.dart <flutter args...>\n'
      '  e.g. dart run tool/flutter_with_env.dart run -d <device>\n'
      '       dart run tool/flutter_with_env.dart build apk --release',
    );
    exitCode = 2;
    return;
  }

  // The project root is the tool/ directory's parent, so the credentials file
  // is found regardless of the directory the wrapper was invoked from.
  final root = File.fromUri(Platform.script).parent.parent;
  final config = File(
    '${root.path}${Platform.pathSeparator}$envFileName',
  );

  if (!config.existsSync()) {
    stderr.writeln(
      'No $envFileName found at ${config.path}.\n'
      'Without it this build would start offline and sign-in would report that '
      'the build has no backend. Create $envFileName with the keys '
      'SUPABASE_URL, SUPABASE_ANON_KEY and GOOGLE_WEB_CLIENT_ID before '
      'building.',
    );
    exitCode = 2;
    return;
  }

  // On Windows the SDK ships `flutter.bat`; passing it explicitly resolves
  // reliably where a bare `flutter` would look for `flutter.exe`.
  final flutter = Platform.isWindows ? 'flutter.bat' : 'flutter';
  final process = await Process.start(
    flutter,
    [...args, '--dart-define-from-file=${config.path}'],
    workingDirectory: Directory.current.path,
    mode: ProcessStartMode.inheritStdio,
  );
  exitCode = await process.exitCode;
}
