/// Widget tests for the database guard and recovery dialog.
/// Implemented in Task 03 Phase 1.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/database/database_factory.dart';
import 'package:legal_case_diary/shared/providers/database_provider.dart';
import 'package:legal_case_diary/shared/widgets/database_guard.dart';

void main() {
  group('DatabaseGuard', () {
    testWidgets('shows a recovery dialog when the database cannot be opened', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWith((_) async {
            throw DatabaseFactoryException('key missing');
          }),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: const DatabaseGuard(child: Text('App Ready')),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('App Ready'), findsNothing);
      expect(find.text('Database Locked'), findsOneWidget);
      expect(find.text('Reset Local Database'), findsOneWidget);
    });

    testWidgets(
      'passes through to the child when the database opens successfully',
      (tester) async {
        late AppDatabase db;
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWith((_) async {
              db = AppDatabase(NativeDatabase.memory());
              return db;
            }),
          ],
        );

        addTearDown(() async => await db.close());

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: const Locale('en'),
              home: const DatabaseGuard(child: Text('App Ready')),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('App Ready'), findsOneWidget);
        expect(find.text('Database Locked'), findsNothing);
      },
    );
  });
}
