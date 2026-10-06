/// Widget tests for the blocking recovery overlay (Task 19 Phase 5).
///
/// The scope's whole job is to be invisible when the lock is off and to be the
/// only thing on screen when it is on, so both halves are pinned — along with the
/// one gate that matters on the screen itself: Proceed stays disabled until a
/// completed safety copy is recorded, because erasing without a verified copy is
/// the one irreversible mistake this flow exists to prevent.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/settings/data/backup_metadata_store.dart';
import 'package:legal_case_diary/features/settings/data/backup_repository.dart';
import 'package:legal_case_diary/features/sync/presentation/recovery_required_screen.dart';
import 'package:legal_case_diary/shared/providers/database_provider.dart';
import 'package:legal_case_diary/shared/providers/shared_preferences_provider.dart';
import 'package:legal_case_diary/sync/recovery_lock.dart';
import 'package:legal_case_diary/sync/sync_metadata_dao.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    db = AppDatabase(NativeDatabase.memory());
    await db.customSelect('select 1').get();
  });

  tearDown(() async => db.close());

  Future<void> pumpApp(WidgetTester tester, {bool encrypt = false}) async {
    final prefs = await SharedPreferences.getInstance();
    // Encryption is off by default; a test that wants the passphrase fields
    // turns it on the way the Backup & Restore section does.
    if (encrypt) await prefs.setBool(backupEncryptionEnabledKey, true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWith((_) async => db),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const RecoveryRequiredScope(child: Text('App content')),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Runs one test body and always unmounts before it ends, because the lock's
  /// stream schedules a zero-duration timer when it closes.
  Future<void> withApp(
    WidgetTester tester,
    Future<void> Function() body,
  ) async {
    try {
      await body();
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    }
  }

  /// Records a completed safety copy, as a real export would.
  Future<void> recordArchive() async {
    final metadata = SyncMetadataDao(db);
    await metadata.setValue(archivePathKey, 'C:/tmp/safety.lcbak');
    await metadata.setValue(archiveChecksumKey, 'abc123');
    await metadata.setValue(archiveStateKey, archiveStateComplete);
  }

  testWidgets('an unlocked device sees the app, not the screen', (
    tester,
  ) async {
    await withApp(tester, () async {
      await pumpApp(tester);

      expect(find.text('App content'), findsOneWidget);
      expect(find.text('Offline For Too Long'), findsNothing);
    });
  });

  testWidgets('with encryption off the safety copy asks for no passphrase', (
    tester,
  ) async {
    await RecoveryLock(db).engage(at: 0);
    await withApp(tester, () async {
      await pumpApp(tester);

      // The copy is still required before Proceed, but nothing is sealed, so no
      // passphrase field appears.
      expect(
        find.byKey(const ValueKey('recovery-lock-save')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('recovery-lock-passphrase')),
        findsNothing,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('recovery-lock-proceed')),
            )
            .onPressed,
        isNull,
      );
    });
  });

  testWidgets('a locked device is blocked and cannot proceed without a copy', (
    tester,
  ) async {
    await RecoveryLock(db).engage(at: 0);
    await withApp(tester, () async {
      await pumpApp(tester, encrypt: true);

      // The app itself is gone: there is no editable surface at all.
      expect(find.text('App content'), findsNothing);
      expect(find.text('Offline For Too Long'), findsOneWidget);
      expect(
        find.textContaining('A Safety Copy Must Be Saved'),
        findsOneWidget,
      );
      // The copy step is offered, with the passphrase fields when encryption is
      // on, and Proceed is not yet available.
      expect(
        find.byKey(const ValueKey('recovery-lock-passphrase')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('recovery-lock-proceed')),
            )
            .onPressed,
        isNull,
      );
    });
  });

  testWidgets('a recorded copy names the file and unlocks Proceed', (
    tester,
  ) async {
    await RecoveryLock(db).engage(at: 0);
    await recordArchive();
    await withApp(tester, () async {
      await pumpApp(tester);

      expect(
        find.text('Safety Copy Saved To C:/tmp/safety.lcbak'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('recovery-lock-passphrase')),
        findsNothing,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('recovery-lock-proceed')),
            )
            .onPressed,
        isNotNull,
      );

      // Proceed asks first, and cancelling changes nothing.
      await tester.tap(find.byKey(const ValueKey('recovery-lock-proceed')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('The Safety Copy You Saved Is The Only Way Back'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(await RecoveryLock(db).isRequired(), isTrue);
    });
  });
}
