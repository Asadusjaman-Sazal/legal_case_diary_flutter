/// Applies every file in `supabase/migrations/` to the one writable Supabase
/// project, in filename order, through `psql` — and records each version in
/// `supabase_migrations.schema_migrations` exactly where, and in exactly the
/// shape, the Supabase CLI keeps them. So after a run here, `supabase db push`
/// sees the whole set as already applied instead of re-applying it.
///
///   dart run tool/apply_supabase_migrations.dart --dry-run   # plan, no database
///   dart run tool/apply_supabase_migrations.dart             # apply for real
///
/// Why not the CLI alone: `supabase db push` needs `supabase link`, an
/// interactive database password and a Docker-less local stack this host does
/// not have, and `apply_migration` (the connector) takes its SQL as a request
/// argument, which cannot carry the 363 KB generated seed. `psql` is already
/// installed and the session pooler answers from here.
///
/// Guards, because this is the only thing in the repo that writes to Postgres:
///   * the connection string must resolve to [writableProjectRef] and must not
///     mention the live project AGENTS.md rule 12 forbids, or nothing runs;
///   * each migration file is applied in **one transaction together with its
///     bookkeeping row**, so a file that fails half-way leaves no trace and is
///     never recorded as applied;
///   * versions already recorded are skipped, so a second run applies only what
///     is new and is safe to repeat at any time.
///
/// The SQL this tool itself runs — the four bootstrap statements the CLI also
/// issues — is kept in [supabaseBootstrapStatements] and rendered into the
/// ledger `supabase/AllSupabaseSql.md` by `tool/generate_all_supabase_sql.dart`,
/// because AGENTS.md rule 13 covers every statement, not only the versioned ones.
library;

import 'dart:convert';
import 'dart:io';

// ---------------------------------------------------------------------------
// Project scope — AGENTS.md rule 12. Exactly one project may be written to.
// ---------------------------------------------------------------------------

/// The only project this repo is ever applied to: "Legal Case Diary"
/// (org `xrjmednwyszriubyjzgb`, `ap-south-1`).
const String writableProjectRef = 'lsthasywrdrhuuxnykau';

/// Live project that must never be read or written in any way. Named here only
/// so the guard can refuse it, loudly, if its ref ever reaches this tool.
const String offLimitsProjectRef = 'ykbwzodadijtiizobehk';
const String offLimitsProjectName = 'Swanirvor-23';

// ---------------------------------------------------------------------------
// Paths and connection details
// ---------------------------------------------------------------------------

/// Migration folder, relative to the project root.
const String migrationsDir = 'supabase/migrations';

/// Git-ignored file holding `SUPABASE_DB_URL`; see `supabase/README.md`.
const String envFilePath = 'supabase/.env.local';
const String dbUrlVariable = 'SUPABASE_DB_URL';

/// Left in `.env.local` until the user pastes the database password in.
const String placeholderPassword = 'REPLACE_WITH_DB_PASSWORD';

/// The CLI's migration history table, spelled once.
const String historyTable = 'supabase_migrations.schema_migrations';

/// The client binary this tool drives.
const String psqlExecutable = 'psql';

// ---------------------------------------------------------------------------
// The Supabase CLI's own bookkeeping SQL
//
// Copied verbatim from `pkg/migration/history.go` so this tool and the CLI
// cannot disagree about the table they share. `--dry-run` never sends these.
// ---------------------------------------------------------------------------

/// One SQL statement with the comment that says what it does.
class SqlStatement {
  const SqlStatement(this.label, this.sql);

  /// Why the statement exists, rendered above it in the ledger and in psql logs.
  final String label;

  /// The statement, without its terminating semicolon.
  final String sql;

  /// The statement as it is actually sent.
  String get terminated => '$sql;';
}

/// The statements that must run before the first apply, in order: the CLI's
/// `CREATE_VERSION_SCHEMA`, `CREATE_VERSION_TABLE`, `ADD_STATEMENTS_COLUMN` and
/// `ADD_NAME_COLUMN`.
const List<SqlStatement> supabaseBootstrapStatements = <SqlStatement>[
  SqlStatement(
    'Create the migration-history schema.',
    'CREATE SCHEMA IF NOT EXISTS supabase_migrations',
  ),
  SqlStatement(
    'Create the migration-history table.',
    'CREATE TABLE IF NOT EXISTS '
        'supabase_migrations.schema_migrations (version text NOT NULL PRIMARY KEY)',
  ),
  SqlStatement(
    'Add the statements column '
        '(absent on projects whose history predates the CLI column).',
    'ALTER TABLE supabase_migrations.schema_migrations '
        'ADD COLUMN IF NOT EXISTS statements text[]',
  ),
  SqlStatement(
    'Add the name column.',
    'ALTER TABLE supabase_migrations.schema_migrations '
        'ADD COLUMN IF NOT EXISTS name text',
  ),
];

/// The CLI's `UPSERT_MIGRATION_VERSION` with this file's version and name
/// inlined — written inside the same transaction as the migration body, so a
/// file is either fully applied and recorded, or neither.
///
/// `statements` is recorded as NULL on purpose: the CLI only reads `version` to
/// decide what is pending, and splitting a file into the CLI's own statement
/// array needs the CLI's parser.
/// ponytail: NULL statements, upgrade path is to record them if a future CLI
/// command ever reads the column.
String upsertVersionRowSql({required String version, required String name}) {
  return 'INSERT INTO $historyTable(version, name, statements) '
      'VALUES (${sqlLiteral(version)}, ${sqlLiteral(name)}, NULL) '
      'ON CONFLICT (version) DO UPDATE SET name = EXCLUDED.name, '
      'statements = EXCLUDED.statements';
}

/// Quotes a value for inlining, refusing anything that could break out of the
/// literal. Versions and names come from validated file names, so the check is
/// a backstop rather than a sanitizer.
String sqlLiteral(String value) {
  if (value.contains("'") || value.contains('\n') || value.contains('\r')) {
    throw ToolFailure('Refusing to inline $value into SQL.');
  }
  return "'$value'";
}

/// Renders statements as one psql script, each under its own label comment.
String renderSqlScript(Iterable<SqlStatement> statements) => statements
    .map((statement) => '-- ${statement.label}\n${statement.terminated}')
    .join('\n');

// ---------------------------------------------------------------------------
// Migration files
// ---------------------------------------------------------------------------

/// One migration file, parsed the way the CLI parses a file name:
/// `20260929100000_phase1_core_schema.sql` is version `20260929100000`
/// and name `phase1_core_schema`.
class MigrationRecord {
  const MigrationRecord({
    required this.fileName,
    required this.version,
    required this.name,
    required this.bytes,
  });

  final String fileName;
  final String version;
  final String name;
  final int bytes;

  /// Human-readable size for the run log.
  String get size => bytes < 1024 ? '$bytes B' : '${(bytes / 1024).round()} KB';
}

/// File-name shape the CLI accepts — a 14-digit version, an underscore, any
/// name, `.sql`. Deliberately no stricter than the CLI, so a file the CLI would
/// apply is never refused here.
final RegExp migrationFileNamePattern = RegExp(r'^(\d{14})_(.+)\.sql$');

/// Parses one file name, or throws [ToolFailure] explaining what is wrong.
MigrationRecord parseMigrationFile(String fileName, {int bytes = 0}) {
  final match = migrationFileNamePattern.firstMatch(fileName);
  if (match == null) {
    throw ToolFailure(
      'Migration name "$fileName" is not `<14 digits>_<name>.sql`, which is the '
      'only shape the Supabase CLI reads. Rename the file; do not rename it here.',
    );
  }

  // The name is inlined into the version row as a string literal, so a quote or a
  // space — which no `supabase migration new` run produces — stops the run before
  // anything reaches Postgres.
  final name = match.group(2)!;
  if (name.contains("'") || name.contains(RegExp(r'\s'))) {
    throw ToolFailure(
      'Migration name "$fileName" contains a quote or a space, which cannot be '
      'recorded safely in $historyTable. Rename the file.',
    );
  }

  return MigrationRecord(
    fileName: fileName,
    version: match.group(1)!,
    name: name,
    bytes: bytes,
  );
}

/// Every migration on disk, in version (= filename) order — the order they must
/// be applied in.
List<MigrationRecord> listMigrations({String dir = migrationsDir}) {
  final directory = Directory(dir);
  if (!directory.existsSync()) {
    throw ToolFailure('No $dir directory — run this from the project root.');
  }

  final files = directory
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.sql'))
      .map((file) => file.uri.pathSegments.last)
      .toList()
    ..sort();

  if (files.isEmpty) {
    throw ToolFailure('$dir holds no .sql files.');
  }

  final migrations = files
      .map((name) => parseMigrationFile(name, bytes: File('$dir/$name').lengthSync()))
      .toList();

  final seen = <String>{};
  for (final migration in migrations) {
    if (!seen.add(migration.version)) {
      throw ToolFailure(
        'Two migrations share version ${migration.version}; the CLI would treat '
        'them as one. Rename one of them.',
      );
    }
  }
  return migrations;
}

/// Reads the connection string out of the `.env.local` text.
String readConnectionUrl(String envFileContents) {
  for (final line in const LineSplitter().convert(envFileContents)) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    if (!trimmed.startsWith('$dbUrlVariable=')) continue;

    var value = trimmed.substring(dbUrlVariable.length + 1).trim();
    final quoted = value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'")));
    if (quoted) value = value.substring(1, value.length - 1);
    if (value.isEmpty) break;
    return value;
  }
  throw ToolFailure(
    'No $dbUrlVariable=... line in $envFilePath. Copy the Session pooler URI of '
    'project $writableProjectRef into it (supabase/README.md).',
  );
}

/// The project a connection string points at: the `postgres.<ref>` user of the
/// session pooler, or the `db.<ref>.supabase.co` direct host.
String projectRefFromConnectionUrl(String url) {
  final uri = Uri.parse(url);

  final user = uri.userInfo.split(':').first;
  const prefix = 'postgres.';
  if (user.startsWith(prefix) && user.length > prefix.length) {
    return user.substring(prefix.length);
  }

  final match =
      RegExp(r'^db\.([a-z0-9]+)\.supabase\.(?:co|in|net)$').firstMatch(uri.host);
  if (match != null) return match.group(1)!;

  throw ToolFailure(
    'Cannot tell which project ${maskConnectionUrl(url)} points at. Expected the '
    'session pooler user `postgres.<project-ref>` or the host '
    '`db.<project-ref>.supabase.co`.',
  );
}

/// Refuses to run unless the connection string points at [writableProjectRef]
/// and nowhere near [offLimitsProjectRef]. Returns the ref it approved.
String assertProjectInScope(String url) {
  if (url.contains(offLimitsProjectRef)) {
    throw ToolFailure(
      'STOP: this connection string names $offLimitsProjectRef '
      '("$offLimitsProjectName"), which is live and must never be touched '
      '(AGENTS.md rule 12). Nothing was sent to any database.',
    );
  }

  final ref = projectRefFromConnectionUrl(url);
  if (ref != writableProjectRef) {
    throw ToolFailure(
      'STOP: this connection string points at project "$ref". The only writable '
      'project is $writableProjectRef ("Legal Case Diary"), and '
      '$offLimitsProjectRef ("$offLimitsProjectName") must never be touched. '
      'Nothing was sent to any database.',
    );
  }
  return ref;
}

/// The same URL with the password replaced, for every line this tool prints.
String maskConnectionUrl(String url) {
  final uri = Uri.parse(url);
  if (uri.userInfo.isEmpty) return url;
  return uri
      .replace(userInfo: '${uri.userInfo.split(':').first}:***')
      .toString();
}

/// A failure the user can act on, printed without a stack trace.
class ToolFailure implements Exception {
  const ToolFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

// ---------------------------------------------------------------------------
// psql
// ---------------------------------------------------------------------------

/// `--no-psqlrc` so a local psqlrc cannot change AUTOCOMMIT or output format,
/// `--no-password` so a wrong password fails immediately instead of waiting at a
/// prompt, and `ON_ERROR_STOP` so a failing statement ends the run.
/// ponytail: the URL (password included) travels on the command line; masking it
/// in the environment with PGPASSWORD is the upgrade path if that ever matters.
List<String> psqlArguments(String url, List<String> rest) => <String>[
      url,
      '--no-psqlrc',
      '--no-password',
      '-v',
      'ON_ERROR_STOP=1',
      ...rest,
    ];

/// Runs one statement and returns its unaligned, tuple-only output.
Future<String> psqlQuery(String url, String sql) async {
  final ProcessResult result;
  try {
    result = await Process.run(psqlExecutable, psqlArguments(url, <String>[
      '--no-align',
      '--tuples-only',
      '--command',
      sql,
    ]));
  } on ProcessException {
    throw ToolFailure(_psqlMissing);
  }
  if (result.exitCode != 0) {
    throw ToolFailure(
      'psql failed on `${sql.split('\n').first}`:\n'
      '${_indent('${result.stderr}'.trim())}',
    );
  }
  return '${result.stdout}';
}

/// Runs a whole script from stdin in a single transaction.
Future<void> psqlScript(String url, String script) async {
  final Process process;
  try {
    process = await Process.start(
      psqlExecutable,
      psqlArguments(url, <String>['--single-transaction', '--file', '-']),
    );
  } on ProcessException {
    throw ToolFailure(_psqlMissing);
  }

  // Drain both pipes concurrently: a NOTICE-heavy run can fill stderr while we
  // are still reading stdout, which would deadlock a sequential read.
  final output = Future.wait<String>(<Future<String>>[
    process.stdout.transform(utf8.decoder).join(),
    process.stderr.transform(utf8.decoder).join(),
  ]);
  process.stdin.write(script);
  await process.stdin.flush();
  await process.stdin.close();

  final pipe = await output;
  final stdoutText = pipe[0].trimRight();
  final stderrText = pipe[1].trimRight();
  final exitCode = await process.exitCode;

  if (exitCode != 0) {
    throw ToolFailure(
      'psql exited $exitCode; the whole file was rolled back and nothing was '
      'recorded as applied:\n${_indent(stderrText.isEmpty ? '(no stderr)' : stderrText)}',
    );
  }

  final summary = renderPsqlOutput(stdoutText, stderrText);
  if (summary.isNotEmpty) stdout.writeln(summary);
}

/// psql is louder than this tool needs: it prints one status tag per statement,
/// and on a first apply every `drop ... if exists` in the set announces itself.
/// Both are expected, so they are counted and summarized rather than reprinted.
/// Anything else — a real NOTICE such as pg_cron being unavailable — is kept
/// verbatim, so nothing that matters is hidden.
String renderPsqlOutput(String stdoutText, String stderrText) {
  final kept = <String>[];
  var suppressed = 0;

  for (final line in const LineSplitter().convert(stdoutText)) {
    if (line.trim().isEmpty) continue;
    if (psqlStatusTag.hasMatch(line.trim())) {
      suppressed++;
      continue;
    }
    kept.add(line);
  }
  for (final line in const LineSplitter().convert(stderrText)) {
    if (line.trim().isEmpty) continue;
    if (benignNotice.hasMatch(line)) {
      suppressed++;
      continue;
    }
    kept.add(line);
  }

  final lines = <String>[...kept.map(_indent)];
  if (suppressed > 0) {
    lines.add(_indent('($suppressed expected psql lines hidden: statement tags '
        'and `... does not exist, skipping` notices.)'));
  }
  return lines.join('\n');
}

/// psql's per-statement status, e.g. `CREATE TABLE`, `ALTER TABLE`, `INSERT 0 8`.
/// Deliberately all-uppercase-and-spaces only, so `ERROR:` and `NOTICE:` lines
/// can never match it.
final RegExp psqlStatusTag = RegExp(r'^[A-Z][A-Z ]+( \d+)?( \d+)?$');

/// The `drop ... if exists` and re-run announcements, which are the point of an
/// idempotent migration set rather than a problem.
final RegExp benignNotice =
    RegExp(r'NOTICE:.*(?:does not exist|already exists), skipping\s*$');

const String _psqlMissing =
    'psql was not found on PATH. Install the PostgreSQL client tools, or apply '
    'with the CLI instead: npx supabase link --project-ref $writableProjectRef '
    '&& npx supabase db push (supabase/README.md).';

String _indent(String text) =>
    text.split('\n').map((line) => '      $line').join('\n');

// ---------------------------------------------------------------------------
// The run
// ---------------------------------------------------------------------------

Future<void> main(List<String> args) async {
  final unknown = args.where((arg) => arg != '--dry-run').toList();
  if (unknown.isNotEmpty) {
    stderr.writeln('Unknown argument: ${unknown.join(' ')}');
    stderr.writeln(usage);
    exitCode = 2;
    return;
  }

  final dryRun = args.contains('--dry-run');

  try {
    final migrations = listMigrations();

    final envFile = File(envFilePath);
    if (!envFile.existsSync()) {
      throw ToolFailure(
        'No $envFilePath. It holds $dbUrlVariable=... and is git-ignored; see '
        'supabase/README.md for the two lines to put in it.',
      );
    }

    final url = readConnectionUrl(envFile.readAsStringSync());
    final ref = assertProjectInScope(url);
    final masked = maskConnectionUrl(url);

    if (dryRun) {
      _printPlan(ref, masked, migrations);
      return;
    }

    if (url.contains(placeholderPassword)) {
      throw ToolFailure(
        'Password "$placeholderPassword" is still in $envFilePath. Replace it '
        'with the database password of project $ref (Supabase dashboard > '
        'Project Settings > Database), then run this again.',
      );
    }

    final preflight = (await psqlQuery(
      url,
      'select current_database(), current_user',
    ))
        .trim()
        .split('|');

    stdout.writeln('Connected to "${preflight.first}" as "${preflight.last}" '
        '— project $ref.');
    stdout.writeln('Connection: $masked');

    // Bootstrap once; every statement is `if not exists`, so a linked project
    // whose CLI already made the table is untouched.
    await psqlScript(url, renderSqlScript(supabaseBootstrapStatements));
    stdout.writeln('History table ready: $historyTable.');

    final applied = await readAppliedVersions(url);
    final appliedSet = applied.toSet();
    final localVersions = migrations.map((m) => m.version).toSet();
    final pending =
        migrations.where((m) => !appliedSet.contains(m.version)).toList();

    for (final version in applied.where((v) => !localVersions.contains(v))) {
      stderr.writeln(
        'WARNING: $version is recorded on the project but no local file exists '
        'for it — the drift `supabase migration list` warns about.',
      );
    }

    stdout.writeln('${applied.length} of ${migrations.length} migrations already '
        'recorded; ${pending.length} to apply.');
    if (pending.isEmpty) {
      stdout.writeln('Nothing to do.');
      return;
    }

    for (final migration in pending) {
      stdout.write('  ${migration.version} ${migration.name} '
          '(${migration.size}) ... ');
      final body = normalizeNewlines(
        File('$migrationsDir/${migration.fileName}').readAsStringSync(),
      ).trimRight();

      // One transaction: the file, then the row that says it was applied.
      final record = upsertVersionRowSql(
        version: migration.version,
        name: migration.name,
      );
      await psqlScript(
        url,
        '$body\n\n'
        '-- Record ${migration.version} — ${migration.name} as applied.\n'
        '$record;\n',
      );
      stdout.writeln('applied');
    }

    final recorded = await readAppliedVersions(url);
    stdout.writeln('Done: ${recorded.length} versions recorded on project '
        '$ref. `supabase db push` will now skip all of them.');
  } on ToolFailure catch (failure) {
    stderr.writeln(failure.message);
    exitCode = 1;
  }
}

/// The versions already recorded on the project, ascending.
Future<List<String>> readAppliedVersions(String url) async {
  final output = await psqlQuery(
    url,
    'SELECT version FROM $historyTable ORDER BY version',
  );
  return const LineSplitter()
      .convert(output)
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
}

/// Line endings are LF on disk regardless of checkout, so a CRLF working copy
/// cannot leak `\r` into the SQL.
String normalizeNewlines(String sql) => sql.replaceAll('\r\n', '\n');

void _printPlan(String ref, String masked, List<MigrationRecord> migrations) {
  stdout.writeln('Project  : $ref');
  stdout.writeln('Connection: $masked');
  stdout.writeln('Source   : $migrationsDir — ${migrations.length} migrations');
  stdout.writeln('DRY RUN  : nothing is sent to Postgres.');
  stdout.writeln();
  for (var index = 0; index < migrations.length; index++) {
    final migration = migrations[index];
    final number = '${index + 1}'.padLeft(2);
    stdout.writeln('  $number. ${migration.version}  ${migration.name}  '
        '(${migration.size})');
  }
  stdout.writeln();
  stdout.writeln('Each file runs as one psql transaction together with its row in '
      '$historyTable, in the order above.');
  stdout.writeln('Apply with: dart run tool/apply_supabase_migrations.dart');
}

const String usage = '''
Applies supabase/migrations/*.sql to project $writableProjectRef through psql,
recording each version in $historyTable.

  dart run tool/apply_supabase_migrations.dart --dry-run   plan only, no database
  dart run tool/apply_supabase_migrations.dart             apply for real

The connection string is read from $envFilePath ($dbUrlVariable).
''';
