/// `PullToSync` tests.
///
/// The gesture exists only for premium accounts, runs the same forced sync as
/// the header button, reloads the page when it has a reload, and works on a
/// short page that does not fill the screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/features/accounts_and_profile/data/account_mode.dart';
import 'package:legal_case_diary/shared/widgets/pull_to_sync.dart';
import 'package:legal_case_diary/sync/sync_service.dart';

/// A sync engine that records a manual retry without a server.
class _RecordingSyncService extends SyncService {
  _RecordingSyncService(super._ref);

  int retries = 0;

  @override
  Future<void> retryNow() async => retries++;
}

void main() {
  testWidgets('premium pulls run the forced sync and the page reload', (
    tester,
  ) async {
    late _RecordingSyncService sync;
    var reloads = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          premiumAccessProvider.overrideWith((ref) async => true),
          syncServiceProvider.overrideWith((ref) {
            sync = _RecordingSyncService(ref);
            return sync;
          }),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: PullToSync(
              onReload: () async => reloads++,
              child: ListView(
                children: const [SizedBox(height: 60, child: Text('One row'))],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(RefreshIndicator), findsOneWidget);
    await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
    await tester.pumpAndSettle();

    expect(sync.retries, 1);
    expect(reloads, 1);
  });

  testWidgets('a short page is pulled without moving under the finger', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [premiumAccessProvider.overrideWith((ref) async => true)],
        child: MaterialApp(
          home: Scaffold(
            body: PullToSync(
              child: ListView(
                children: const [SizedBox(height: 60, child: Text('One row'))],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The Android 12+ stretch effect is what drags the whole page; the pull
    // must show the spinner instead.
    expect(find.byType(StretchingOverscrollIndicator), findsNothing);

    await tester.drag(find.byType(ListView), const Offset(0, 20));
    await tester.pump();
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position;
    expect(
      position.pixels,
      0,
      reason: 'the content stays inside its bounds instead of following',
    );
    await tester.pumpAndSettle();
  });

  testWidgets('a free account gets no pull gesture', (tester) async {
    var reloads = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [premiumAccessProvider.overrideWith((ref) async => false)],
        child: MaterialApp(
          home: Scaffold(
            body: PullToSync(
              onReload: () async => reloads++,
              child: ListView(
                children: const [SizedBox(height: 60, child: Text('One row'))],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(RefreshIndicator), findsNothing);
    expect(find.text('One row'), findsOneWidget);
    expect(reloads, 0);
  });
}
