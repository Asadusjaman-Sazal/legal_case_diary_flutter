/// View model for the Admin Panel: whether to show it, the two payment lists,
/// and the result of the last action.
///
/// Task 22, MVVM + Riverpod, matching `payment_viewmodel.dart`.
///
/// Two decisions live here rather than in the screen. First, admin status is its
/// own provider, because the **navigation** needs the answer before the panel
/// does — a screen that only discovered it was not an admin after it opened
/// would flash its contents to everyone. Second, an action never mutates the
/// local list: it reloads from the server, so what the admin sees is always what
/// the server holds, and the Resolved section fills from the server's own record
/// rather than from a guess about what just happened.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_providers.dart';
import '../data/admin_repository.dart';

/// Whether the signed-in account is an admin.
///
/// False while loading and false when the call fails, so nothing that reads this
/// can show the panel before the server has actually said yes.
final adminStatusProvider = FutureProvider<bool>((ref) async {
  return ref.watch(adminRepositoryProvider).isAdmin();
});

/// Every payment submission, as the server sees them.
///
/// Refetches after each action, so this is the server's state and never a local
/// guess. The screen splits it into Pending and Resolved.
final adminPaymentRequestsProvider = FutureProvider<List<AdminPaymentRequest>>((
  ref,
) async {
  final isAdmin = await ref.watch(adminStatusProvider.future);
  if (!isAdmin) return const <AdminPaymentRequest>[];
  return ref.watch(adminRepositoryProvider).listPaymentRequests();
});

/// Every account that never confirmed its address, newest first.
///
/// The Non-verified Accounts page's list; empty for a non-admin, like the
/// payment list.
final adminUnconfirmedAccountsProvider =
    FutureProvider<List<AdminUnconfirmedAccount>>((ref) async {
      final isAdmin = await ref.watch(adminStatusProvider.future);
      if (!isAdmin) return const <AdminUnconfirmedAccount>[];
      return ref.watch(adminRepositoryProvider).listUnconfirmedAccounts();
    });

/// Every citation in the server-wide library, as the server holds it.
///
/// Empty for a non-admin, like the other admin lists: the panel's page is only
/// reached from an admin row, and a queued read from an account that has lost
/// the grant must not show anything either.
final adminSharedReferencesProvider =
    FutureProvider<List<AdminSharedReference>>((ref) async {
      final isAdmin = await ref.watch(adminStatusProvider.future);
      if (!isAdmin) return const <AdminSharedReference>[];
      return ref.watch(adminRepositoryProvider).listSharedReferences();
    });

/// How many citations the server-wide library holds, for the panel's row.
final adminSharedReferenceCountProvider = Provider<int>(
  (ref) => ref.watch(adminSharedReferencesProvider).value?.length ?? 0,
);

/// The payment submissions still to be decided.
///
/// The panel's Payment Requests row counts this, and
/// [adminPendingCountProvider] adds it to the unconfirmed accounts. Answers 0
/// for anything but a finished, successful read — loading, a failure, a
/// non-admin.
final adminPendingPaymentsProvider = Provider<int>(
  (ref) =>
      ref
          .watch(adminPaymentRequestsProvider)
          .value
          ?.where((request) => request.isPending)
          .length ??
      0,
);

/// The accounts that never confirmed their address.
///
/// The panel's Non-verified Accounts row counts this.
final adminUnconfirmedCountProvider = Provider<int>(
  (ref) => ref.watch(adminUnconfirmedAccountsProvider).value?.length ?? 0,
);

/// How many things the Admin Panel is waiting on: the payment submissions still
/// to be decided **plus** the accounts that never confirmed.
///
/// The side menu's badge reads this, so it answers **0 for anything but a
/// finished, successful read** — loading, a failure, a non-admin — and can never
/// keep the menu from drawing. Only read once [adminStatusProvider] is true.
final adminPendingCountProvider = Provider<int>(
  (ref) =>
      ref.watch(adminPendingPaymentsProvider) +
      ref.watch(adminUnconfirmedCountProvider),
);

/// How one admin action ended.
enum AdminActionPhase {
  /// Nothing attempted yet.
  idle,

  /// The call is in flight.
  running,

  /// The call succeeded.
  success,

  /// The call was refused; [AdminActionState.failure] says how.
  failure,
}

/// The observable state of the last approve/reject.
class AdminActionState {
  /// Creates a state.
  const AdminActionState({
    this.phase = AdminActionPhase.idle,
    this.failure,
    this.actedOn,
  });

  /// The current phase.
  final AdminActionPhase phase;

  /// The refusal category when [phase] is [AdminActionPhase.failure].
  final AdminActionFailure? failure;

  /// The submission the last action was about, so the screen can clear only
  /// that row's spinner and message rather than all of them.
  final String? actedOn;

  /// True while a call is in flight.
  bool get isRunning => phase == AdminActionPhase.running;

  /// True when the last attempt succeeded.
  bool get succeeded => phase == AdminActionPhase.success;
}

/// Owns the approve and reject calls for the panel.
class AdminActionViewModel extends Notifier<AdminActionState> {
  /// Riverpod provider for [AdminActionViewModel].
  static final provider =
      NotifierProvider<AdminActionViewModel, AdminActionState>(
        () => AdminActionViewModel(),
      );

  @override
  AdminActionState build() => const AdminActionState();

  /// Approves [submissionId], then reloads the lists from the server.
  Future<void> approve(String submissionId) =>
      _run(submissionId, (repository) => repository.approve(submissionId));

  /// Rejects [submissionId] with an optional [note], then reloads.
  Future<void> reject(String submissionId, {String? note}) => _run(
    submissionId,
    (repository) => repository.reject(submissionId, note: note),
  );

  /// Returns the panel to idle, so a stale success banner does not outlive the
  /// message that explained it.
  void clear() => state = const AdminActionState();

  Future<void> _run(
    String submissionId,
    Future<AdminActionFailure?> Function(AdminRepository repository) call,
  ) async {
    state = AdminActionState(
      phase: AdminActionPhase.running,
      actedOn: submissionId,
    );
    final failure = await call(ref.read(adminRepositoryProvider));
    if (failure == null) {
      // The server is the only account of what is resolved, so ask it again
      // rather than moving the row locally.
      ref.invalidate(adminPaymentRequestsProvider);
    }
    state = AdminActionState(
      phase: failure == null
          ? AdminActionPhase.success
          : AdminActionPhase.failure,
      failure: failure,
      actedOn: submissionId,
    );
  }
}

/// Owns the removal of an unconfirmed account.
///
/// The same shape as [AdminActionViewModel] — one call, then a reload from the
/// server, so the list is always the server's record rather than a local guess —
/// but a separate notifier, because the two actions live on different screens and
/// a shared state would let one screen's banner appear on the other.
class AdminDeleteAccountViewModel extends Notifier<AdminActionState> {
  /// Riverpod provider for [AdminDeleteAccountViewModel].
  static final provider =
      NotifierProvider<AdminDeleteAccountViewModel, AdminActionState>(
        () => AdminDeleteAccountViewModel(),
      );

  @override
  AdminActionState build() => const AdminActionState();

  /// Removes the unconfirmed account [userId], then reloads the list.
  Future<void> delete(String userId) async {
    state = AdminActionState(phase: AdminActionPhase.running, actedOn: userId);
    final failure = await ref
        .read(adminRepositoryProvider)
        .deleteUnconfirmedAccount(userId);
    if (failure == null) {
      ref.invalidate(adminUnconfirmedAccountsProvider);
    }
    state = AdminActionState(
      phase: failure == null
          ? AdminActionPhase.success
          : AdminActionPhase.failure,
      failure: failure,
      actedOn: userId,
    );
  }

  /// Returns the page to idle, so a stale message does not outlive its subject.
  void clear() => state = const AdminActionState();
}
