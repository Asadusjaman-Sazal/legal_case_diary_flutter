/// The bounded post-payment approval watch.
///
/// A free account holds no Realtime socket, so the checkout starts this watch
/// instead of waiting for a ping: it re-reads the account on a fixed beat for a
/// fixed window, then stops. These pin the beat, the end of the window, and a
/// later submission restarting it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/core/providers/repository_providers.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/account_mode.dart';
import 'package:legal_case_diary/features/auth/data/auth_repository.dart';
import 'package:legal_case_diary/features/auth/presentation/auth_viewmodel.dart';
import 'package:legal_case_diary/features/payments/data/payment_repository.dart';
import 'package:legal_case_diary/features/payments/presentation/payment_approval_watch.dart';

void main() {
  /// Mounts the scope and returns the container plus the refresh counter.
  Future<(ProviderContainer, List<int>)> pumpWatch(WidgetTester tester) async {
    final refreshes = <int>[];
    final container = ProviderContainer(
      overrides: [
        authIdentityProvider.overrideWithValue(
          const AuthIdentity(userId: 'user-1'),
        ),
        accountRefreshProvider.overrideWithValue(() async {
          refreshes.add(refreshes.length + 1);
          return true;
        }),
        premiumAccessProvider.overrideWith((ref) async => false),
        // A fixed expiry: nothing the watch can mistake for an approval.
        paymentApprovalExpiryProvider.overrideWithValue(() async => 1000),
        myPaymentSubmissionsProvider.overrideWith(
          (ref) async => const <PaymentSubmission>[],
        ),
        mySubscriptionCancellationsProvider.overrideWith(
          (ref) async => const <SubscriptionCancellation>[],
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: PaymentApprovalWatchScope(child: SizedBox.shrink()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (container, refreshes);
  }

  testWidgets('re-reads the account on every beat while it is watching', (
    tester,
  ) async {
    final (container, refreshes) = await pumpWatch(tester);

    container.read(paymentApprovalWatchProvider.notifier).start();
    await tester.pump();
    expect(refreshes, isEmpty, reason: 'the first beat is one interval away');

    await tester.pump(paymentApprovalWatchInterval);
    await tester.pump();
    expect(refreshes, hasLength(1));

    await tester.pump(paymentApprovalWatchInterval);
    await tester.pump();
    expect(refreshes, hasLength(2));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('stops on its own when the window ends', (tester) async {
    final (container, refreshes) = await pumpWatch(tester);

    container.read(paymentApprovalWatchProvider.notifier).start();
    await tester.pump();

    for (var i = 0; i < paymentApprovalWatchTicks; i++) {
      await tester.pump(paymentApprovalWatchInterval);
      await tester.pump();
    }
    expect(refreshes, hasLength(paymentApprovalWatchTicks));
    expect(container.read(paymentApprovalWatchProvider), 0);

    // The window is spent: the next beats do nothing.
    await tester.pump(paymentApprovalWatchInterval * 3);
    await tester.pump();
    expect(refreshes, hasLength(paymentApprovalWatchTicks));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('a second submission restarts the window', (tester) async {
    final (container, refreshes) = await pumpWatch(tester);

    container.read(paymentApprovalWatchProvider.notifier).start();
    await tester.pump();
    for (var i = 0; i < paymentApprovalWatchTicks; i++) {
      await tester.pump(paymentApprovalWatchInterval);
      await tester.pump();
    }
    expect(container.read(paymentApprovalWatchProvider), 0);
    final firstRun = refreshes.length;

    container.read(paymentApprovalWatchProvider.notifier).start();
    await tester.pump();
    await tester.pump(paymentApprovalWatchInterval);
    await tester.pump();
    expect(refreshes.length, firstRun + 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('stops on the first changed expiry, even when already premium', (
    tester,
  ) async {
    var expiry = 1000;
    var refreshes = 0;
    final container = ProviderContainer(
      overrides: [
        authIdentityProvider.overrideWithValue(
          const AuthIdentity(userId: 'user-1'),
        ),
        accountRefreshProvider.overrideWithValue(() async {
          refreshes++;
          // The renewal (or plan change) lands in this pull.
          expiry = 2000;
          return true;
        }),
        // Already premium: the old free → premium condition would not stop it.
        premiumAccessProvider.overrideWith((ref) async => true),
        paymentApprovalExpiryProvider.overrideWithValue(() async => expiry),
        myPaymentSubmissionsProvider.overrideWith(
          (ref) async => const <PaymentSubmission>[],
        ),
        mySubscriptionCancellationsProvider.overrideWith(
          (ref) async => const <SubscriptionCancellation>[],
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: PaymentApprovalWatchScope(child: SizedBox.shrink()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    container.read(paymentApprovalWatchProvider.notifier).start();
    await tester.pump();
    await tester.pump();
    await tester.pump(paymentApprovalWatchInterval);
    await tester.pump();

    expect(refreshes, 1);
    expect(container.read(paymentApprovalWatchProvider), 0);

    // The change ended the watch; the remaining beats never run.
    await tester.pump(paymentApprovalWatchInterval * 3);
    await tester.pump();
    expect(refreshes, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
