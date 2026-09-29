/// Compares the seeded reference tables on the writable Supabase project with
/// the app's own seed constants, so "does the server hold the same list as the
/// app?" is one command instead of a dashboard by-eye comparison.
///
///   dart run tool/check_supabase_seed.dart
///
/// Read-only: it issues one `select count(*)` per table and nothing else, so it
/// never appears in `supabase/AllSupabaseSql.md` (that ledger records the SQL the
/// project *ships* — the migrations and the applier's bootstrap). Exits non-zero
/// if any table disagrees with `lib/core/constants/pre_seeded_data.dart`.
///
/// Why counting by eye misleads: the Supabase Table Editor shows 100 rows per
/// page, and a single PostgREST response stops at the project's `max_rows` (1000
/// by default). The two largest tables here — 1,016 courts and 160 case types —
/// are therefore the two that look truncated, while the small ones look complete.
/// The numbers this tool prints are whole-table counts.
library;

import 'dart:io';

import 'package:legal_case_diary/core/constants/pre_seeded_data.dart';

import 'apply_supabase_migrations.dart';

/// One seeded table, with the app-side count it must equal.
class SeededTable {
  const SeededTable(this.table, this.appCount, this.source);

  /// Table name in `public`.
  final String table;

  /// Rows the app's constants hold for it.
  final int appCount;

  /// Which constant the number comes from, for an operator reading the output.
  final String source;
}

/// The six editable reference tables and their app-side counts, derived the same
/// way `tool/generate_supabase_seed.dart` derives them — so the two cannot drift
/// without `test/supabase/seed_parity_test.dart` failing.
List<SeededTable> expectedSeedCounts() => <SeededTable>[
      SeededTable('court_categories', seedCategories.length, 'seedCategories'),
      SeededTable(
        'case_categories',
        seedCategories.fold<int>(0, (t, c) => t + c.caseCategories.length),
        'seedCategories[].caseCategories',
      ),
      SeededTable('courts', allSeedCourts.length, 'allSeedCourts'),
      SeededTable(
        'steps',
        seedCategories.fold<int>(0, (t, c) => t + c.steps.length),
        'seedCategories[].steps',
      ),
      SeededTable(
        'case_types',
        seedCategories.fold<int>(0, (t, c) => t + c.allCaseTypes.length),
        'seedCategories[].allCaseTypes',
      ),
      SeededTable(
        'on_behalfs',
        seedCategories.fold<int>(0, (t, c) => t + c.onBehalfs.length),
        'seedCategories[].onBehalfs',
      ),
    ];

Future<void> main(List<String> args) async {
  final unknown = args.where((arg) => arg != '--help').toList();
  if (unknown.isNotEmpty) {
    stderr.writeln('Unknown argument: ${unknown.join(' ')}');
    stderr.writeln('Usage: dart run tool/check_supabase_seed.dart');
    exitCode = 2;
    return;
  }

  try {
    final envFile = File(envFilePath);
    if (!envFile.existsSync()) {
      throw ToolFailure('No $envFilePath — it holds $dbUrlVariable=... for the '
          'project\'s Session pooler URI (supabase/README.md).');
    }

    // Same one-project guard as the applier: this never reads anywhere but
    // `lsthasywrdrhuuxnykau` (AGENTS.md rule 12).
    final url = readConnectionUrl(envFile.readAsStringSync());
    final ref = assertProjectInScope(url);

    stdout.writeln('Project $ref vs lib/core/constants/pre_seeded_data.dart '
        '(read-only, whole-table counts).');

    final differences = <String>[];
    for (final seeded in expectedSeedCounts()) {
      final live = int.parse(
        (await psqlQuery(url, 'select count(*) from public.${seeded.table}'))
            .trim(),
      );
      final same = live == seeded.appCount;
      if (!same) {
        differences.add(seeded.table);
      }
      stdout.writeln('  ${same ? 'same   ' : 'DIFFERS'} '
          '${seeded.table.padRight(17)} '
          'app ${seeded.appCount.toString().padLeft(5)}  '
          'Supabase ${live.toString().padLeft(5)}   '
          '(${seeded.source})');
    }

    if (differences.isEmpty) {
      stdout.writeln('Every seeded table matches. The dashboard shows 100 rows '
          'per page — the counts above are the whole tables.');
      return;
    }

    stderr.writeln('DIFFERS: ${differences.join(', ')}. The migration and the '
        'constants disagree — run `dart run tool/generate_supabase_seed.dart`, '
        'apply the new seed migration, and re-run this.');
    exitCode = 1;
  } on ToolFailure catch (failure) {
    stderr.writeln(failure.message);
    exitCode = 1;
  }
}
