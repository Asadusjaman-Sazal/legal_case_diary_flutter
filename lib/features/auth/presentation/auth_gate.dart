/// The sign-in gate: who has to sign in, and in what order it is decided.
///
/// Two of the plan's rules meet here and must both hold:
///
/// * **An account is required** — the in-app FAQ already tells the user they
///   create one the first time they open the app, and the diary belongs to that
///   account, which is what lets premium switch on years of existing cases with
///   nothing re-entered, exported or transferred.
/// * **An offline lawyer is never locked out of their own diary.** So the gate
///   is decided *once*, from facts already on the device: a device whose local
///   database already holds rows the *user* wrote is let straight through and is
///   asked to sign in rather than forced to; a device with nothing on it opens
///   the Login screen, because there is nothing to lock away.
///
/// The discriminator is deliberately **user-authored rows**: seeded reference
/// data exists on every install, old or new, and the per-install identity is
/// minted by the first settings read — neither can tell the two apart.
library;

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/database_provider.dart';
import '../data/auth_repository.dart';
import '../data/local_auth_service.dart';
import 'auth_viewmodel.dart';

/// Whether the local database already holds rows the user authored.
///
/// Cases, notes and case references are the free user's own work; the seeded
/// courts, steps, case types and roles are not, and neither are the settings and
/// sync-metadata rows that exist on a brand-new install too.
final authLocalDataExistsProvider = FutureProvider<bool>((ref) async {
  try {
    final db = await ref.watch(databaseProvider.future);

    Future<bool> hasRows(
      TableInfo<Table, dynamic> table,
      Expression<int> count,
    ) async {
      final query = db.selectOnly(table)..addColumns([count]);
      return (await query.map((row) => row.read(count) ?? 0).getSingle()) > 0;
    }

    if (await hasRows(db.cases, db.cases.id.count())) return true;
    if (await hasRows(db.notes, db.notes.id.count())) return true;
    return hasRows(db.caseReferences, db.caseReferences.id.count());
  } catch (_) {
    // A database that cannot be read is the recovery dialog's problem, not the
    // gate's: never turn it into a locked diary.
    return false;
  }
});

/// Whether this launch must pass through the Login screen.
///
/// False as soon as the device has a session, has satisfied the gate before, or
/// already holds the user's own data.
final authGateRequiredProvider = FutureProvider<bool>((ref) async {
  final local = ref.watch(localAuthServiceProvider);
  if (local.gateSatisfied || local.cachedUserId != null) return false;

  final AuthIdentity? session = await ref.watch(authSessionProvider.future);
  if (session != null) return false;

  return !(await ref.watch(authLocalDataExistsProvider.future));
});
