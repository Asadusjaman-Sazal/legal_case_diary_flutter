/// Phase 10's lapse allowance, pinned at the rule's own boundary.
///
/// The widget surfaces read these numbers; this file proves the numbers are the
/// tier's, that the writable set is the **most recently updated** rows, that a
/// deletion promotes the next row, and that a waiting downgrade counts from the
/// instant it starts — the one mirrored rule the server owns.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/payments/data/payment_plans.dart';
import 'package:legal_case_diary/features/payments/data/plan_allowance.dart';
import 'package:legal_case_diary/features/settings/data/write_allowance.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    // The allowance counts rows, it does not resolve their courts or roles; the
    // fixtures below carry ids only, so the reference checks are switched off
    // for this connection.
    await db.customStatement('PRAGMA foreign_keys = OFF');
  });

  tearDown(() => db.close());

  /// Seeds [count] live cases, oldest first: `case-0` has the oldest
  /// `updated_at` and `case-(count-1)` the newest.
  Future<void> seedCases(int count) async {
    for (var i = 0; i < count; i++) {
      await db.into(db.cases).insert(
        CasesCompanion(
          id: Value('case-$i'),
          userId: const Value('user-1'),
          courtId: const Value('court-1'),
          caseType: const Value('Civil'),
          caseNumber: Value('N$i'),
          petitioner: const Value('Petitioner'),
          respondent: const Value('Respondent'),
          onBehalfId: const Value('role-1'),
          createdAt: Value(i + 1),
          updatedAt: Value(i + 1),
          isDeleted: const Value(false),
        ),
      );
    }
  }

  /// Seeds [count] live notes, oldest first.
  Future<void> seedNotes(int count) async {
    for (var i = 0; i < count; i++) {
      await db.into(db.notes).insert(
        NotesCompanion(
          id: Value('note-$i'),
          userId: const Value('user-1'),
          title: Value('Note $i'),
          body: const Value('body'),
          createdAt: Value(i + 1),
          updatedAt: Value(i + 1),
          isDeleted: const Value(false),
        ),
      );
    }
  }

  group('the tier numbers', () {
    test('each tier carries its ceiling and its lapse allowance', () {
      expect(SubscriptionTier.free.caseCeiling, 50);
      expect(SubscriptionTier.starter.caseCeiling, 500);
      expect(SubscriptionTier.pro.caseCeiling, 1000);
      expect(SubscriptionTier.firm.caseCeiling, 2500);
      expect(SubscriptionTier.firmPlus.caseCeiling, 6000);
      // Enterprise is the one uncapped tier.
      expect(SubscriptionTier.enterprise.caseCeiling, isNull);
      // The allowances, not the ceilings.
      expect(SubscriptionTier.starter.lapseAllowance, 100);
      expect(SubscriptionTier.pro.lapseAllowance, 250);
      expect(SubscriptionTier.firm.lapseAllowance, 500);
      expect(SubscriptionTier.firmPlus.lapseAllowance, 1000);
      expect(SubscriptionTier.enterprise.lapseAllowance, 2000);
      // Free is never "lapsed": it has the wall instead.
      expect(SubscriptionTier.free.lapseAllowance, 0);
    });
  });

  group('the tier in force', () {
    final now = DateTime.utc(2026, 10, 17, 12);

    test('a waiting downgrade applies from its own instant', () {
      final before = now.subtract(const Duration(minutes: 1));
      final after = now;
      expect(
        effectiveTier(
          tier: SubscriptionTier.firmPlus,
          pendingKey: 'firm',
          pendingFromMs: after.millisecondsSinceEpoch,
          now: now,
        ),
        SubscriptionTier.firm,
      );
      expect(
        effectiveTier(
          tier: SubscriptionTier.firmPlus,
          pendingKey: 'firm',
          pendingFromMs: after.add(const Duration(days: 1)).millisecondsSinceEpoch,
          now: now,
        ),
        SubscriptionTier.firmPlus,
        reason: 'the paid period is still running at ${before.toIso8601String()}',
      );
    });

    test('an incomplete pair leaves the stored tier standing', () {
      expect(
        effectiveTier(tier: SubscriptionTier.firm, pendingKey: 'pro'),
        SubscriptionTier.firm,
      );
      expect(
        effectiveTier(tier: SubscriptionTier.firm, pendingFromMs: 1),
        SubscriptionTier.firm,
      );
    });
  });

  group('what may be written', () {
    test('premium carries the tier case ceiling and no other ceiling', () async {
      await seedCases(3);
      final allowance = await resolveWriteAllowance(
        db,
        tier: SubscriptionTier.pro,
        premium: true,
      );

      // The paid ladder enforces its case ceiling; notes and references stay
      // uncapped while the subscription is live.
      expect(allowance.caseAddCeiling, 1000);
      expect(allowance.noteAddCeiling, isNull);
      expect(allowance.writableCaseIds, isNull);
      expect(allowance.isCaseWritable('case-0'), isTrue);
      expect(allowance.canAddCase(), isTrue);
      expect(allowance.isLapsed, isFalse);
    });

    test('a genuinely free account keeps the 50-case add wall only', () async {
      await seedCases(50);
      final allowance = await resolveWriteAllowance(
        db,
        tier: SubscriptionTier.free,
        premium: false,
      );

      expect(allowance.caseAddCeiling, 50);
      expect(allowance.canAddCase(), isFalse);
      // Free's wall is on adding, never on editing its own cases.
      expect(allowance.writableCaseIds, isNull);
      expect(allowance.isCaseWritable('case-0'), isTrue);
      expect(allowance.noteAddCeiling, isNull);
      expect(allowance.referenceAddCeiling, isNull);
    });

    test('a lapsed Pro keeps its 250 most recent cases writable', () async {
      await seedCases(300);
      final allowance = await resolveWriteAllowance(
        db,
        tier: SubscriptionTier.pro,
        premium: false,
      );

      expect(allowance.isLapsed, isTrue);
      expect(allowance.caseAddCeiling, 250);
      expect(allowance.writableCaseIds, hasLength(250));
      // The most recently updated stay editable; the archive is read-only.
      expect(allowance.isCaseWritable('case-299'), isTrue);
      expect(allowance.isCaseWritable('case-50'), isTrue);
      expect(allowance.isCaseWritable('case-49'), isFalse);
      expect(allowance.isCaseWritable('case-0'), isFalse);
      expect(allowance.readOnlyCases, 50);
      expect(allowance.canAddCase(), isFalse);
      // Reading is never capped: the set only decides editing.
      expect(await db.select(db.cases).get(), hasLength(300));
    });

    test('deleting a writable row promotes the next one', () async {
      await seedCases(300);
      final before = await resolveWriteAllowance(
        db,
        tier: SubscriptionTier.pro,
        premium: false,
      );
      expect(before.isCaseWritable('case-49'), isFalse);

      // Delete the newest row, which is inside the allowance.
      await (db.update(db.cases)..where((row) => row.id.equals('case-299')))
          .write(const CasesCompanion(isDeleted: Value(true)));

      final after = await resolveWriteAllowance(
        db,
        tier: SubscriptionTier.pro,
        premium: false,
      );
      expect(after.liveCases, 299);
      expect(after.writableCaseIds, hasLength(250));
      expect(after.isCaseWritable('case-49'), isTrue);
      expect(after.isCaseWritable('case-48'), isFalse);
    });

    test('the chamber tiers scale the allowance', () async {
      await seedCases(1);
      final firm = await resolveWriteAllowance(
        db,
        tier: SubscriptionTier.firm,
        premium: false,
      );
      final firmPlus = await resolveWriteAllowance(
        db,
        tier: SubscriptionTier.firmPlus,
        premium: false,
      );
      expect(firm.caseAddCeiling, 500);
      expect(firmPlus.caseAddCeiling, 1000);
    });

    test('notes carry the same ceiling and the same order', () async {
      await seedNotes(300);
      final allowance = await resolveWriteAllowance(
        db,
        tier: SubscriptionTier.pro,
        premium: false,
      );

      expect(allowance.noteAddCeiling, 250);
      expect(allowance.writableNoteIds, hasLength(250));
      expect(allowance.isNoteWritable('note-299'), isTrue);
      expect(allowance.isNoteWritable('note-49'), isFalse);
      expect(allowance.liveNotes, 300);
      expect(allowance.readOnlyNotes, 50);
    });
  });
}
