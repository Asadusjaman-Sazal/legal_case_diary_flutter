/// The deletion wait window: the screen the user sees between the typed
/// confirmation and the result toast.
///
/// Three things are pinned here, because each is a way the request could fail:
/// the sentence is on screen while the run is pending, back cannot dismiss it,
/// and the window closes only when the run answers.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/data_deletion_service.dart';
import 'package:legal_case_diary/features/accounts_and_profile/presentation/data_deletion_wait_window.dart';

/// The result a successful window reports.
const DataDeletionResult _done = DataDeletionResult(
  counts: <DataDeletionCategory, int>{},
  failed: false,
);

void main() {
  /// Pumps a host screen whose only button opens the wait window with [run].
  Future<void> pumpHost(
    WidgetTester tester,
    Future<DataDeletionResult> Function() run,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () =>
                    showDataDeletionWaitWindow(context, run: run),
                child: const Text('Start'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Start'));
    await tester.pump();
  }

  testWidgets('stays up, undismissable, until the deletion answers', (
    tester,
  ) async {
    final pending = Completer<DataDeletionResult>();
    await pumpHost(tester, () => pending.future);

    expect(find.text('Please Wait'), findsOneWidget);
    expect(find.text('Your data is currently being deleted.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // The back button cannot close the window: the deletion is not interruptible.
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Please Wait'), findsOneWidget);

    pending.complete(_done);
    await tester.pumpAndSettle();

    expect(find.text('Please Wait'), findsNothing);
  });

  testWidgets('a failing run still closes the window', (tester) async {
    await pumpHost(tester, () async => throw StateError('no database'));
    await tester.pumpAndSettle();

    // The window never outlives the run, so a failure cannot look like a hang.
    expect(find.text('Please Wait'), findsNothing);
  });
}
