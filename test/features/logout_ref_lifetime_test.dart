/// Guards the branched logout against a widget-`ref` lifetime bug.
///
/// `runBranchedLogout` is handed a **widget** `ref` (a drawer popover or a
/// screen) and then awaits real I/O — the database, the sync push, the save
/// dialog. Riverpod forbids touching a widget `ref` once its widget is
/// unmounted, so a `ref.read` *after* an await throws
/// `Bad state: Using "ref" when a widget is about to or has been unmounted`.
///
/// The device hit exactly that: tapping Logout in the side menu's account
/// popover crashed when the popover went away during the flow. Every provider
/// value the orchestration needs is therefore read **before the first await**;
/// this test pops the owning route mid-flow to prove it.
library;

import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/auth/data/logout_flow.dart';
import 'package:legal_case_diary/features/auth/presentation/logout_dialogs.dart';
import 'package:legal_case_diary/shared/providers/shared_preferences_provider.dart';

void main() {
  testWidgets(
    'the logout still runs when the widget that opened it unmounts mid-flow',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      // Held open, so the owning route can be popped while the flow awaits it —
      // exactly what a real device does while the database is read.
      final gate = Completer<LogoutFlow>();
      var sessionsEnded = 0;

      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            logoutFlowProvider.overrideWith((ref) => gate.future),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp(
            navigatorKey: navigatorKey,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => navigatorKey.currentState!.push(
                    MaterialPageRoute<void>(
                      // The surface that owns the `ref`, like the popover: it is
                      // disposed while the flow is still waiting.
                      builder: (_) => Scaffold(
                        body: Consumer(
                          builder: (context, ref, _) => TextButton(
                            key: const Key('logout'),
                            onPressed: () => runBranchedLogout(context, ref),
                            child: const Text('Log Out'),
                          ),
                        ),
                      ),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('logout')));
      await tester.pump();

      // The owning route leaves before the flow provider answers.
      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();

      // Now the flow answers; a `ref.read` after the await would throw here.
      gate.complete(
        LogoutFlow(
          db: db,
          premium: true,
          online: false,
          runBacklogPush: () async => null,
          endSession: () async => sessionsEnded++,
        ),
      );
      await tester.pumpAndSettle();

      // The logout completed rather than crashing on a dead `ref`.
      expect(sessionsEnded, 1);
      expect(tester.takeException(), isNull);
    },
  );
}