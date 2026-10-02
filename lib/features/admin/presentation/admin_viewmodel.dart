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
final adminPaymentRequestsProvider =
    FutureProvider<List<AdminPaymentRequest>>((ref) async {
      final isAdmin = await ref.watch(adminStatusProvider.future);
      if (!isAdmin) return const <AdminPaymentRequest>[];
      return ref.watch(adminRepositoryProvider).listPaymentRequests();
    });

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
  static final provider = NotifierProvider<AdminActionViewModel, AdminActionState>(
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
