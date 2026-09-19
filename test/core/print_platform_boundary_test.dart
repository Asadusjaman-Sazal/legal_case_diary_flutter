/// Source-level guards for the print layer (Task 14 Phase 1).
///
/// The rules these check cannot be observed by running the app here: the print
/// plugin is a platform channel that only answers on a device, and the offline
/// rule for Part A is a property of the sources, not of a call. Reading them is
/// cheap, and both would otherwise rot as the feature grows.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _folder = 'lib/core/print/';

/// Files that make up the print layer.
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

void main() {
  test('the print sources exist', () {
    expect(
      _sources().map(_name),
      containsAll([
        'print_document.dart',
        'pdf_native_renderer.dart',
        'print_service.dart',
      ]),
    );
  });

  test('only the print service imports the printing plugin', () {
    for (final file in _sources()) {
      for (final import in _imports(file)) {
        if (!import.contains('printing')) continue;
        expect(
          _name(file),
          'print_service.dart',
          reason: '${_name(file)} imports $import — the platform package belongs '
              'behind the service, so screens, tests and the Windows port stay '
              'free of it.',
        );
      }
    }
  });

  test('the document model stays free of plugins, database and Flutter', () {
    final imports = _imports(File('${_folder}print_document.dart'));
    for (final forbidden in <String>[
      'package:pdf/',
      'package:printing/',
      'package:flutter/',
      'drift',
      'supabase',
    ]) {
      expect(
        imports.any((import) => import.contains(forbidden)),
        isFalse,
        reason: 'print_document.dart must stay pure Dart: it is the single place '
            'the printed wording is decided, and it is tested without a host.',
      );
    }
  });

  test('nothing on the print path is networked (Part A stays offline)', () {
    const forbidden = <String>[
      'supabase_flutter',
      'http/',
      'dio',
      'web_socket_channel',
    ];
    for (final file in _sources()) {
      for (final import in _imports(file)) {
        for (final package in forbidden) {
          expect(
            import.contains(package),
            isFalse,
            reason: '${_name(file)} imports $import — printing is a local '
                'operation (plan §12.3).',
          );
        }
      }
    }
  });
}
