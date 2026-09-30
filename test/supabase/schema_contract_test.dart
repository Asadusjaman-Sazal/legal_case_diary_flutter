/// Structural contract over the Supabase migration files.
///
/// The migrations cannot be applied on this development host (no Docker, no
/// linked project), so the invariants that a real apply would prove are checked
/// here against the SQL text: every table's class-specific contract, RLS
/// coverage, index coverage, RPC security attributes and the absence of
/// secrets. Each phase of Task 16 extends this file with the invariants it
/// introduces.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Push/pull domain tables: the only class that gets the global sync contract.
const List<String> domainTables = <String>[
  'cases',
  'case_history',
  'notes',
  'case_references',
  'court_categories',
  'case_categories',
  'courts',
  'steps',
  'case_types',
  'on_behalfs',
  'delete_requests',
  'conflict_log',
];

/// Pull-only caches refreshed from the server.
const List<String> pullOnlyTables = <String>[
  'profiles',
  'firms',
  'firm_members',
];

/// Per-user preference tables; never firm-shared, no sync contract.
const List<String> preferenceTables = <String>[
  'user_preferences',
  'case_notification_preferences',
];

/// Server-managed/account/payment tables created by this task.
const List<String> serverManagedTables = <String>[
  'firm_invites',
  'payment_submissions',
  'payment_approval_events',
  'invite_attempts',
  'mutation_receipts',
  'app_admins',
];

/// Server-internal ledgers that must have RLS on and **no** policy at all.
const List<String> serverInternalTables = <String>[
  'invite_attempts',
  'mutation_receipts',
  'app_admins',
];

/// The global sync columns, which apply to [domainTables] only.
const List<String> syncColumns = <String>[
  'updated_at',
  'version',
  'server_updated_at',
  'synced_at',
  'is_deleted',
  'last_modified_by',
];

/// Tables this task must create (extended as phases land).
List<String> expectedTables() => <String>[
  ...domainTables,
  ...pullOnlyTables,
  ...preferenceTables,
  ...serverManagedTables,
];

Directory migrationDir() => Directory('supabase/migrations');

List<File> migrationFiles() {
  final files = migrationDir()
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.sql'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  return files;
}

String migrationSql() => migrationFiles()
    .map((file) => normalizeSql(file.readAsStringSync()))
    .join('\n');

/// SQL with CRLF checkouts normalized, so tests behave the same on Windows.
String normalizeSql(String sql) => sql.replaceAll('\r\n', '\n');

/// The body of one `create table if not exists public.<table> (...)` block.
String? tableBlock(String sql, String table) {
  final match = RegExp(
    'create table if not exists public\\.$table \\((.*?)\\n\\);',
    dotAll: true,
  ).firstMatch(sql);
  return match?.group(1);
}

/// Every table created by the migrations, in file order.
Set<String> createdTables(String sql) => RegExp(
      r'create table if not exists public\.(\w+)',
    ).allMatches(sql).map((match) => match.group(1)!).toSet();

/// The policy actions (`select`, `insert`, `update`, …) defined on one table.
///
/// Whitespace is allowed around `on` and `for`, because a long policy name is
/// wrapped onto the next line.
Set<String> policyActions(String sql, String table) => RegExp(
      r'create policy \w+\s+on public\.' + table + r'\s+for (\w+)',
      dotAll: true,
    )
        .allMatches(sql)
        .map((match) => match.group(1)!)
        .toSet();

/// The body of one `create or replace function public.<name>(...) $$ ... $$;`.
String? functionBlock(String sql, String name) {
  final start = sql.indexOf('create or replace function public.$name(');
  if (start < 0) return null;
  final end = sql.indexOf(r'$$;', start);
  return sql.substring(start, end < 0 ? sql.length : end);
}

void main() {
  final files = migrationFiles();
  final sql = migrationSql();

  group('migration files', () {
    test('are named with an ordered timestamp and a snake_case purpose', () {
      expect(files, isNotEmpty);
      final names = files.map((file) => file.uri.pathSegments.last).toList();
      expect(names.toSet().length, names.length, reason: 'duplicate migration');
      for (final name in names) {
        expect(
          RegExp(r'^\d{14}_[a-z0-9_]+\.sql$').hasMatch(name),
          isTrue,
          reason: '$name must be <yyyyMMddHHmmss>_<purpose>.sql',
        );
      }
      final sorted = [...names]..sort();
      expect(names, sorted, reason: 'apply order is filename order');
    });

    test('open with a purpose header comment', () {
      for (final file in files) {
        final first = normalizeSql(file.readAsStringSync()).split('\n').first;
        expect(
          first.startsWith('--'),
          isTrue,
          reason: '${file.path} must document its purpose in a header comment',
        );
      }
    });

    test('create tables idempotently', () {
      expect(
        RegExp(r'^create table (?!if not exists)',
                multiLine: true, caseSensitive: false)
            .hasMatch(sql),
        isFalse,
        reason: 'every create table must be `create table if not exists`',
      );
    });

    test('enable RLS in the same file that creates a table', () {
      // A partially-applied push must never leave a reachable table behind, so
      // protection cannot wait for a later migration.
      for (final file in files) {
        final fileSql = normalizeSql(file.readAsStringSync());
        for (final table in createdTables(fileSql)) {
          expect(
            RegExp('alter table public\\.$table enable row level security')
                .hasMatch(fileSql),
            isTrue,
            reason: '${file.path} creates public.$table without enabling RLS',
          );
        }
      }
    });

    test('do not carry credentials', () {
      for (final secret in <String>[
        'eyJhbGciOi',
        'service_role',
        'SUPABASE_SERVICE_ROLE_KEY',
        'BEGIN PRIVATE KEY',
      ]) {
        expect(sql, isNot(contains(secret)), reason: 'found $secret');
      }
    });
  });

  group('table classes', () {
    test('every expected table is created exactly once', () {
      for (final table in expectedTables()) {
        final count = RegExp('create table if not exists public\\.$table \\(')
            .allMatches(sql)
            .length;
        expect(count, 1, reason: 'public.$table must be created exactly once');
      }
    });

    test('the global sync columns land on the domain class only', () {
      for (final table in domainTables) {
        final block = tableBlock(sql, table);
        expect(block, isNotNull, reason: 'missing create table for $table');
        for (final column in syncColumns) {
          expect(
            RegExp('\\b$column\\b').hasMatch(block!),
            isTrue,
            reason: '$table must carry the sync column $column',
          );
        }
      }
      for (final table in <String>[
        ...pullOnlyTables,
        ...preferenceTables,
        ...serverManagedTables,
      ]) {
        final block = tableBlock(sql, table);
        if (block == null) continue;
        expect(
          block.contains('server_updated_at'),
          isFalse,
          reason: '$table is not domain-synced and must not carry '
              'server_updated_at',
        );
        expect(
          block.contains('is_deleted'),
          isFalse,
          reason: '$table is not a soft-deletable domain table',
        );
      }
    });

    test('unique constraints required by the sync contract exist', () {
      expect(
        RegExp(r'source_mutation_id text not null unique')
            .hasMatch(tableBlock(sql, 'case_history')!),
        isTrue,
        reason: 'case_history.source_mutation_id must be unique for idempotency',
      );
      expect(
        RegExp(r'transaction_id text not null unique')
            .hasMatch(tableBlock(sql, 'payment_submissions')!),
        isTrue,
        reason: 'payment_submissions.transaction_id must be unique',
      );
    });

    test('client-generated row keys are text and identity columns are uuid', () {
      for (final table in domainTables) {
        final block = tableBlock(sql, table)!;
        expect(
          block.contains('id text primary key'),
          isTrue,
          reason: '$table keeps the client-generated text key',
        );
      }
      expect(tableBlock(sql, 'cases')!.contains('user_id uuid not null'), isTrue);
      expect(
        tableBlock(sql, 'case_history')!.contains('created_by uuid not null'),
        isTrue,
      );
    });
  });

  group('row-level security', () {
    test('is enabled on every table the task creates', () {
      for (final table in expectedTables()) {
        expect(
          RegExp('alter table public\\.$table enable row level security')
              .hasMatch(sql),
          isTrue,
          reason: '$table must have RLS enabled',
        );
      }
    });

    test('never grants DELETE on a soft-deletable domain table', () {
      final deleteTargets = RegExp(
        r'create policy \w+ on public\.(\w+)\s+for delete',
        dotAll: true,
      )
          .allMatches(sql)
          .map((match) => match.group(1)!)
          .toSet();
      // Removing an associate is the one legitimate hard delete in the schema.
      expect(deleteTargets, <String>{'firm_members'});
      for (final table in domainTables) {
        expect(deleteTargets, isNot(contains(table)));
      }
    });

    test('scopes case data to self or the same firm', () {
      for (final table in <String>[
        'cases',
        'case_history',
        'notes',
        'case_references',
      ]) {
        final policies = policyActions(sql, table);
        expect(policies, <String>{'select', 'insert', 'update'}, reason: table);
      }
      expect(
        RegExp(r'user_id = auth\.uid\(\)\s+or firm_id = public\.current_firm_id\(\)')
            .hasMatch(sql),
        isTrue,
      );
      expect(sql, contains('or public.can_edit_firm(firm_id)'));
    });

    test('delete_requests is an audit trail the requester or reviewer edits', () {
      expect(
        sql,
        contains("(requested_by = auth.uid() and status = 'pending')"),
      );
      expect(sql, contains('or public.can_delete_firm(firm_id)'));
      expect(
        policyActions(sql, 'delete_requests'),
        isNot(contains('delete')),
        reason: 'the delete-request queue is an audit trail',
      );
    });

    test('the six reference tables share one matrix, built-ins readable by all', () {
      const referenceTables = <String>[
        'court_categories',
        'case_categories',
        'courts',
        'steps',
        'case_types',
        'on_behalfs',
      ];
      for (final table in referenceTables) {
        expect(sql, contains("'$table'"));
      }
      // The rule is split across concatenated format() literals in the file, so
      // it is checked in halves rather than as one contiguous string.
      expect(
        sql,
        contains('is_custom = false or user_id = auth.uid() or '),
        reason: 'pre-seeded rows must be readable by every authenticated user',
      );
      expect(sql, contains('firm_id = public.current_firm_id())'));
      for (final action in <String>['select', 'insert', 'update']) {
        expect(sql, contains('on public.%1\$I for $action to '));
      }
    });

    test('account, firm and preference rows keep their own scope', () {
      // Self or same-firm profiles: Manage Associates and "edited by [Name]".
      expect(
        sql,
        contains('or (firm_id is not null and firm_id = public.current_firm_id())'),
      );
      // Only the sign-up trigger creates a profile, and nothing deletes one.
      expect(policyActions(sql, 'profiles'), isNot(contains('insert')));
      expect(policyActions(sql, 'profiles'), isNot(contains('delete')));
      expect(sql, contains('create policy firm_members_insert_owner'));
      expect(
        sql,
        contains('using (public.is_firm_owner(firm_id))'),
        reason: 'firm administration is owner-only',
      );
      expect(policyActions(sql, 'payment_submissions'), <String>{'select', 'insert'});
      expect(
        policyActions(sql, 'payment_submissions'),
        isNot(contains('update')),
        reason: 'approval is the RPC; there is no client update path',
      );
      expect(
        sql,
        contains('user_id = auth.uid()\n    or public.is_admin()'),
        reason: 'owners read their own approval receipts, admins read all',
      );
      for (final table in preferenceTables) {
        expect(
          policyActions(sql, table),
          <String>{'select', 'insert', 'update'},
          reason: table,
        );
      }
    });
  });

  group('server-internal tables', () {
    test('deny every direct client command', () {
      for (final table in serverInternalTables) {
        expect(
          RegExp('alter table public\\.$table enable row level security')
              .hasMatch(sql),
          isTrue,
          reason: '$table must have RLS enabled',
        );
        expect(
          RegExp('create policy [^;]*on public\\.$table', dotAll: true)
              .hasMatch(sql),
          isFalse,
          reason: '$table is server-internal and must have no policy',
        );
      }
    });

    test('keep the attempts index the rate limiter counts through', () {
      expect(
        RegExp(r'create index if not exists invite_attempts_user_attempted_at_idx\s+on public\.invite_attempts \(user_id, attempted_at desc\)')
            .hasMatch(sql),
        isTrue,
      );
    });

    test('refuse mutation of the admin registry and the audit ledger', () {
      expect(
        RegExp(r'before update on public\.app_admins').hasMatch(sql),
        isTrue,
        reason: 'a grant is immutable; revocation is a delete',
      );
      expect(
        RegExp(r'before update or delete on public\.payment_approval_events')
            .hasMatch(sql),
        isTrue,
      );
    });
  });

  group('sync triggers and guards', () {
    test('the shared trigger functions exist and are attached to the class', () {
      for (final name in <String>[
        'set_server_updated_at',
        'enforce_delete_transition',
        'enforce_no_resurrection',
        'broadcast_row_change',
      ]) {
        expect(functionBlock(sql, name), isNotNull, reason: 'missing $name');
      }

      // Attached in one loop over the domain class: the loop's table array must
      // name every domain table, and each of the four per-table triggers must
      // be created from a format() template.
      for (final table in domainTables) {
        expect(sql, contains("'$table'"));
      }
      for (final kind in <String>[
        'server_updated_at',
        'delete_transition',
        'resurrection_guard',
        'broadcast',
      ]) {
        expect(
          sql,
          contains('create trigger trg_%1\$s_$kind'),
          reason: 'no trigger template for $kind',
        );
      }
    });

    test('server_updated_at is the only delta cursor and is trigger-assigned', () {
      final block = functionBlock(sql, 'set_server_updated_at')!;
      expect(block, contains('new.server_updated_at := now()'));
      expect(block, contains('return new'));
    });

    test('a delete transition needs can_delete unless the row is individual', () {
      final block = functionBlock(sql, 'enforce_delete_transition')!;
      expect(block, contains('old.is_deleted = false and new.is_deleted = true'));
      expect(block, contains('public.can_delete_firm(old.firm_id)'));
      expect(block, contains('old.firm_id is not null'));
    });

    test('resurrection needs the transaction-local admin flag only', () {
      final block = functionBlock(sql, 'enforce_no_resurrection')!;
      expect(block, contains('old.is_deleted = true and new.is_deleted = false'));
      expect(block, contains("current_setting('app.allow_resurrection', true)"));
      // The guard must not weigh client clocks, versions or editor ids.
      for (final forbidden in <String>[
        'old.updated_at',
        'new.updated_at',
        'old.version',
        'new.version',
        'last_modified_by',
      ]) {
        expect(block, isNot(contains(forbidden)), reason: forbidden);
      }
    });

    test('the free-tier ceiling serializes its count-and-insert', () {
      final block = functionBlock(sql, 'enforce_free_case_limit')!;
      expect(block, contains('public.is_premium(new.user_id)'));
      expect(block, contains('pg_advisory_xact_lock'));
      expect(block, contains('c_free_case_limit constant integer := 50'));
      expect(block, contains('and c.is_deleted = false'));
    });

    test('the payment rate limit overwrites client time and counts server time', () {
      final block = functionBlock(sql, 'enforce_payment_rate_limit')!;
      expect(block, contains('new.submitted_at := now()'));
      expect(block, contains('c_daily_limit constant integer := 3'));
      expect(block, contains("interval '24 hours'"));
      expect(block, contains('s.submitted_at'));
    });
  });

  group('entitlement', () {
    test('is always derived from expiry plus the 48h grace, never from status', () {
      final block = functionBlock(sql, 'is_premium')!;
      expect(block, contains("interval '48 hours' > now()"));
      expect(block, contains('p.subscription_expiry is not null'));
      expect(block, isNot(contains('subscription_status')));
    });
  });

  group('SECURITY DEFINER RPCs', () {
    test('approve_payment is hardened, admin-gated and idempotent', () {
      final block = functionBlock(sql, 'approve_payment')!;
      expect(block, contains('security definer'));
      expect(block, contains('set search_path = pg_catalog, public'));
      expect(block, contains('public.is_admin()'));
      expect(block, contains('for update'));
      expect(block, contains("'not_found'"));
      expect(block, contains("'already_resolved'"));
      expect(block, contains("'invalid_plan'"));
      expect(block, contains("'invalid_amount'"));
      expect(block, contains('greatest(coalesce(v_previous_expiry, now()), now())'));
      expect(block, contains("interval '1 month'"));
      expect(block, contains("interval '1 year'"));
      expect(block, contains('insert into public.payment_approval_events'));
      // `anon` must be named: Supabase's default privileges grant EXECUTE on
      // every new `public` function directly to `anon`, and that direct grant
      // survives `revoke ... from public` (verified against the live project).
      expect(
        sql,
        contains(
            'revoke all on function public.approve_payment(uuid) from public, anon'),
      );
      expect(
        sql,
        contains('grant execute on function public.approve_payment(uuid) to authenticated'),
      );
      expect(
        sql,
        contains('revoke all on function public.join_firm(text) from public, anon'),
      );
    });

    test('join_firm limits attempts, hashes, and returns instead of raising', () {
      final block = functionBlock(sql, 'join_firm')!;
      expect(block, contains('security definer'));
      expect(block, contains('set search_path = pg_catalog, public'));
      expect(block, contains('c_max_failures constant integer := 5'));
      expect(block, contains("c_window constant interval := interval '15 minutes'"));
      expect(block, contains('public.sha256_hex'));
      expect(block, contains("i.used_by is null"));
      expect(block, contains('i.revoked = false'));
      expect(block, contains('insert into public.firm_members'));
      expect(block, contains('update public.profiles p'));
      expect(block, contains('delete from public.invite_attempts a where a.user_id = v_user_id'));
      // A failed match must reach the attempt insert through a return, never by
      // inserting and then raising (which would roll the attempt back).
      expect(block, contains("return jsonb_build_object('status', 'invalid_code')"));
      final invalidAt = block.indexOf("'invalid_code'");
      final raiseBefore = block
          .substring(0, invalidAt)
          .contains("raise exception 'invalid_code'");
      expect(raiseBefore, isFalse);
      expect(
        sql,
        contains('grant execute on function public.join_firm(text) to authenticated'),
      );
    });
  });

  group('server-authoritative columns', () {
    test('client UPDATE goes at table level, not only per column', () {
      // The column-only form does not work: Supabase grants table-level
      // privileges on every `public` table to `anon`/`authenticated`, and a
      // table-level GRANT is not undone by a column-level REVOKE. Proven against
      // the live project — after the column-only version,
      // has_column_privilege('authenticated','public.profiles',
      // 'subscription_expiry','UPDATE') was still true. So the table-level
      // privilege must be dropped first, then granted back per column.
      for (final table in <String>[
        'payment_submissions',
        'profiles',
        'firms',
      ]) {
        expect(
          sql,
          contains('revoke update on public.$table from authenticated, anon'),
          reason: '$table must lose table-level UPDATE before any column grant',
        );
      }

      // Only the columns a client legitimately edits come back.
      expect(
        sql,
        contains('grant update (full_name) on public.profiles to authenticated'),
      );
      expect(sql, contains('grant update (name) on public.firms to authenticated'));

      // Approval state has no client write path at all, so nothing is granted
      // back on payment_submissions...
      expect(
        RegExp(r'grant update \([^)]*\) on public\.payment_submissions')
            .hasMatch(sql),
        isFalse,
      );
      // ...and no server-owned column is named in any GRANT, which is also the
      // default for a column a later migration adds.
      for (final column in <String>[
        'status',
        'approved_at',
        'approved_by',
        'subscription_status',
        'subscription_expiry',
        'role',
        'firm_id',
        'owner_id',
      ]) {
        expect(
          RegExp('grant update \\([^)]*\\b$column\\b').hasMatch(sql),
          isFalse,
          reason: '$column must stay server-only',
        );
      }
    });

    test('the firm expiry mirror is the only firms.subscription_expiry writer', () {
      expect(
        RegExp(r'after update of subscription_expiry on public\.profiles')
            .hasMatch(sql),
        isTrue,
      );
      expect(
        sql,
        contains('where f.owner_id = new.id'),
        reason: 'only owner rows mirror',
      );
    });
  });

  group('realtime', () {
    test('the ping carries only the table and the row id', () {
      final block = functionBlock(sql, 'broadcast_row_change')!;
      expect(block, contains('realtime.send'));
      expect(block, contains("'row_change'"));
      expect(block, contains("'firm:' || (v_row ->> 'firm_id')"));
      expect(block, contains("'user:' || (v_row ->> 'user_id')"));
      expect(block, contains("'user:' || (v_row ->> 'requested_by')"));
      expect(
        block,
        contains("jsonb_build_object('table', TG_TABLE_NAME, 'id', v_row ->> 'id')"),
        reason: 'the payload is the table and the id, never the row',
      );
    });

    test('topic access is authorized per subscriber', () {
      final block = functionBlock(sql, 'can_read_topic')!;
      expect(block, contains("'user:' || coalesce(auth.uid()::text, '')"));
      expect(block, contains("'firm:' || public.current_firm_id()::text"));
      expect(
        sql,
        contains('create policy realtime_messages_read_own_topics on realtime.messages'),
      );
    });
  });

  group('indexes', () {
    test('every domain table is index-backed for the composite cursor', () {
      // Created from one loop over the class, so the table array must name
      // every domain table and the templates must exist.
      for (final table in domainTables) {
        expect(sql, contains("'$table'"));
      }
      expect(sql, contains('create index if not exists %1\$s_delta_idx'));
      expect(sql, contains('(server_updated_at, id)'));
      expect(sql, contains('(firm_id, server_updated_at, id)'));
      expect(sql, contains('(user_id, server_updated_at, id)'));
      // delete_requests has no user_id: its scope is the requester.
      expect(
        sql,
        contains('delete_requests_requester_delta_idx'),
      );
    });

    test('the payment window and the invite attempts are indexed', () {
      expect(
        RegExp(r'create index if not exists payment_submissions_user_submitted_at_idx\s+on public\.payment_submissions \(user_id, submitted_at desc\)')
            .hasMatch(sql),
        isTrue,
      );
      expect(
        sql,
        contains('on public.invite_attempts (user_id, attempted_at desc)'),
      );
    });
  });

  group('tombstone purge', () {
    test('keeps tombstones long enough for the extended-offline rule', () {
      final block = functionBlock(sql, 'purge_tombstones')!;
      expect(block, contains('p_retention_days integer default 180'));
      expect(block, contains('is_deleted = true'));
      expect(block, contains(r'server_updated_at < $1'));
      expect(block, contains('make_interval(days => p_retention_days)'));
      // The cutoff comes from the retention argument, never from a client time.
      expect(block, contains('v_cutoff := now() - '));
      expect(
        block,
        isNot(contains('and updated_at <')),
        reason: 'the client-edited column never decides a purge',
      );
    });

    test('deletes children before parents', () {
      final block = functionBlock(sql, 'purge_tombstones')!;
      final order = <String>[
        'case_history',
        'cases',
        'case_types',
        'courts',
        'case_categories',
        'court_categories',
      ];
      var cursor = 0;
      for (final table in order) {
        final at = block.indexOf("'$table'");
        expect(at, greaterThan(cursor), reason: '$table is out of FK order');
        cursor = at;
      }
    });

    test('schedules itself only when pg_cron is available', () {
      expect(sql, contains('create extension if not exists pg_cron'));
      expect(sql, contains("cron.schedule("));
      expect(sql, contains("'purge-tombstones'"));
      expect(sql, contains("'15 3 * * *'"));
      expect(
        sql,
        contains('public.purge_tombstones()'),
        reason: 'the scheduled statement must call the purge function',
      );
    });
  });

  group('sign-up trigger', () {
    test('creates one individual profile per new auth user', () {
      expect(
        RegExp(r'create trigger on_auth_user_created\s+after insert on auth\.users')
            .hasMatch(sql),
        isTrue,
      );
      final function = sql.substring(
        sql.indexOf('create or replace function public.handle_new_user()'),
        sql.indexOf('create trigger on_auth_user_created'),
      );
      expect(function, contains("'individual'"));
      expect(function, contains('security definer'));
      expect(function, contains('on conflict (id) do nothing'));
    });
  });

  group('push_changes', () {
    test('is a hardened SECURITY DEFINER granted to authenticated only', () {
      final block = functionBlock(sql, 'push_changes')!;
      expect(block, contains('security definer'));
      expect(block, contains('set search_path = pg_catalog, public'));
      expect(
        sql,
        contains(
            'revoke all on function public.push_changes(jsonb) from public, anon'),
      );
      expect(
        sql,
        contains(
            'grant execute on function public.push_changes(jsonb) to authenticated'),
      );
      // Its SECURITY DEFINER helpers stay unreachable to every client role.
      expect(
        sql,
        contains('revoke all on function public.sync_can_write(text, jsonb, text)'),
      );
      expect(
        sql,
        contains('revoke all on function public.has_sync_entitlement(uuid)'),
      );
    });

    test('rejects a non-array batch and requires the row contract keys', () {
      final block = functionBlock(sql, 'push_changes')!;
      expect(block, contains("jsonb_typeof(rows) <> 'array'"));
      for (final key in <String>[
        'mutation_id',
        'entity_type',
        'entity_id',
        'operation',
      ]) {
        expect(block, contains(key), reason: key);
      }
      // One result per submitted row, returned in input order.
      expect(block, contains('array_fill(null::jsonb'));
      expect(block, contains('jsonb_agg(v_results[k] order by k)'));
    });

    test('maps exactly the twelve domain tables and orders them FK-safely', () {
      final map = functionBlock(sql, 'sync_entity_table')!;
      for (final table in domainTables) {
        expect(map, contains("'$table'"), reason: '$table is missing');
      }
      // Nothing outside the class may be reachable through the pipeline.
      for (final table in <String>[
        ...pullOnlyTables,
        ...preferenceTables,
        'payment_submissions',
        'firm_invites',
        'payment_approval_events',
      ]) {
        expect(map, isNot(contains("'$table'")), reason: '$table is out of class');
      }

      final rank = functionBlock(sql, 'sync_dependency_rank')!;
      // Config tables rank 0, cases rank 1, everything dependent rank 2 — so a
      // batch applies its foreign keys in the only order that can succeed.
      for (final table in <String>[
        'court_categories',
        'case_categories',
        'courts',
        'steps',
        'case_types',
        'on_behalfs',
      ]) {
        expect(rank, contains("'$table' then 0"), reason: '$table must rank 0');
      }
      expect(rank, contains("'cases' then 1"));
      for (final table in <String>['case_history', 'notes', 'case_references']) {
        expect(rank, contains("'$table' then 2"), reason: '$table must rank 2');
      }
    });

    test('derives firm-aware entitlement, never from a stored status', () {
      final block = functionBlock(sql, 'has_sync_entitlement')!;
      expect(block, contains("interval '48 hours' > now()"));
      expect(block, contains('p.firm_id is not null'));
      expect(block, contains('from public.firms f'));
      expect(block, isNot(contains('subscription_status')));
    });

    test('re-checks writes against the RLS rules explicitly', () {
      final block = functionBlock(sql, 'sync_can_write')!;
      expect(block, contains('public.current_firm_id()'));
      expect(block, contains('public.can_edit_firm'));
      expect(block, contains('public.can_delete_firm'));
      // A built-in reference row is not client-writable.
      expect(block, contains("p_row ->> 'is_custom'"));
    });

    test('accepts an update only on an exact base_version match', () {
      final block = functionBlock(sql, 'push_changes')!;
      expect(block, contains('for update'));
      expect(block, contains("v_base_version <> (v_existing ->> 'version')::int"));
      expect(block, contains("'version_conflict'"));
      // The server assigns the next version and the editor; the client cannot.
      expect(block, contains("'version', v_old_version + 1"));
      expect(block, contains("'version', 1"));
      expect(block, contains("'last_modified_by', v_actor::text"));
      expect(block, contains("- 'version'"));
    });

    test('is idempotent through mutation_receipts', () {
      final block = functionBlock(sql, 'push_changes')!;
      expect(block, contains('public.mutation_receipts'));
      expect(block, contains("'mutation_id_reused'"));
      expect(block, contains('insert into public.mutation_receipts'));
      expect(block, contains('on conflict (mutation_id) do nothing'));
      expect(block, contains('v_receipt.request_hash = v_hash'));
    });

    test('returns tombstones and already_resolved instead of applying them', () {
      final block = functionBlock(sql, 'push_changes')!;
      expect(block, contains("'tombstone'"));
      expect(block, contains("'already_resolved'"));
      expect(block, contains("'not_found'"));
      // The tombstone decision reads the authoritative is_deleted, not a clock.
      expect(block, contains("(v_existing ->> 'is_deleted')::boolean = true"));
    });

    test('creates authoritative history only for a changed next_date', () {
      final block = functionBlock(sql, 'push_changes')!;
      expect(block, contains("(v_final ->> 'next_date') is distinct from"));
      expect(block, contains("v_row -> 'provisional_history'"));
      expect(block, contains('insert into public.case_history select * from'));
      expect(block, contains("'source_mutation_id'"));
      expect(block, contains("'result_case_version'"));
      // Only an accepted case update reaches it; a rejection creates nothing.
      expect(block, contains("v_status = 'accepted' and v_table = 'cases'"));
    });

    test('cascade-deletes case_history on an accepted case delete', () {
      final block = functionBlock(sql, 'push_changes')!;
      expect(block, contains('update public.case_history t'));
      expect(block, contains(r'where t.case_id = $3 and t.is_deleted = false'));
      expect(block, contains("'children'"));
    });
  });

  group('sync_server_time', () {
    test('is a plain stable clock read, granted to authenticated only', () {
      final block = functionBlock(sql, 'sync_server_time')!;
      expect(block, contains('select now()'));
      expect(block, contains('stable'));
      expect(block, isNot(contains('security definer')));
      expect(
        sql,
        contains(
            'revoke all on function public.sync_server_time() from public, anon'),
      );
      expect(
        sql,
        contains('grant execute on function public.sync_server_time() to authenticated'),
      );
    });
  });
}
