/// Three-way conflict comparison tests — Task 19 Phase 3.
///
/// The verdict is a pure function of the three payloads, so it is tested with
/// nothing but maps: no database, no server, no widget. The properties that
/// matter are that disjoint edits merge, colliding or coupled edits do not, and
/// a tombstone is never merged.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:legal_case_diary/sync/conflict_rebase.dart';

void main() {
  group('planConflictRebase', () {
    test('independent fields merge, keeping both sides', () {
      final plan = planConflictRebase(
        base: <String, dynamic>{'id': 'c1', 'court_name': 'Old', 'order_index': 0},
        server: <String, dynamic>{
          'id': 'c1',
          'court_name': 'Theirs',
          'order_index': 0,
        },
        local: <String, dynamic>{'id': 'c1', 'court_name': 'Old', 'order_index': 5},
        changedFields: const <String>['order_index'],
      );

      expect(plan.verdict, ConflictVerdict.disjoint);
      expect(plan.mergeable, isTrue);
      expect(plan.payload!['court_name'], 'Theirs');
      expect(plan.payload!['order_index'], 5);
      expect(plan.mergedFields, const <String>['order_index']);
    });

    test('the same field changed twice to different values needs a person', () {
      final plan = planConflictRebase(
        base: <String, dynamic>{'id': 'c1', 'court_name': 'Old'},
        server: <String, dynamic>{'id': 'c1', 'court_name': 'Theirs'},
        local: <String, dynamic>{'id': 'c1', 'court_name': 'Mine'},
        changedFields: const <String>['court_name'],
      );

      expect(plan.verdict, ConflictVerdict.overlapping);
      expect(plan.mergeable, isFalse);
      expect(plan.payload, isNull);
      expect(plan.overlappingFields, const <String>['court_name']);
      expect(plan.reason, contains('court_name'));
    });

    test('the same field changed twice to the same value is not a conflict', () {
      final plan = planConflictRebase(
        base: <String, dynamic>{'id': 'c1', 'court_name': 'Old'},
        server: <String, dynamic>{'id': 'c1', 'court_name': 'Same'},
        local: <String, dynamic>{'id': 'c1', 'court_name': 'Same'},
        changedFields: const <String>['court_name'],
      );

      expect(plan.verdict, ConflictVerdict.disjoint);
      expect(plan.payload!['court_name'], 'Same');
    });

    test('two fields of one logical step, changed on both sides, are coupled', () {
      final plan = planConflictRebase(
        base: <String, dynamic>{
          'id': 'h1',
          'next_date': 100,
          'last_step': 'Hearing',
          'notes_results': 'None',
        },
        server: <String, dynamic>{
          'id': 'h1',
          'next_date': 200,
          'last_step': 'Hearing',
          'notes_results': 'None',
        },
        local: <String, dynamic>{
          'id': 'h1',
          'next_date': 100,
          'last_step': 'Hearing',
          'notes_results': 'Adjourned',
        },
        changedFields: const <String>['notes_results'],
      );

      expect(plan.verdict, ConflictVerdict.overlapping);
      expect(plan.mergeable, isFalse);
      expect(plan.coupledGroup, 'The Next Hearing Step');
      expect(plan.reason, contains('The Next Hearing Step'));
    });

    test('a tombstone is never merged, whatever the fields say', () {
      final plan = planConflictRebase(
        base: <String, dynamic>{'id': 'c1', 'court_name': 'Old'},
        server: <String, dynamic>{
          'id': 'c1',
          'court_name': 'Theirs',
          'is_deleted': true,
        },
        local: <String, dynamic>{'id': 'c1', 'order_index': 5},
        changedFields: const <String>['order_index'],
      );

      expect(plan.verdict, ConflictVerdict.tombstone);
      expect(plan.mergeable, isFalse);
      expect(plan.reason, contains('deleted'));
    });

    test('sync bookkeeping columns never make a conflict', () {
      final plan = planConflictRebase(
        base: <String, dynamic>{
          'id': 'c1',
          'version': 1,
          'updated_at': 1,
          'server_updated_at': '2026-09-01',
          'last_modified_by': 'user-1',
          'created_at': 1,
          'is_deleted': false,
          'court_name': 'Old',
        },
        server: <String, dynamic>{
          'id': 'c1',
          'version': 4,
          'updated_at': 99,
          'server_updated_at': '2026-09-30',
          'last_modified_by': 'user-2',
          'created_at': 1,
          'is_deleted': false,
          'court_name': 'Old',
        },
        local: <String, dynamic>{
          'id': 'c1',
          'version': 1,
          'updated_at': 50,
          'server_updated_at': '2026-09-01',
          'last_modified_by': 'user-1',
          'created_at': 1,
          'is_deleted': false,
          'court_name': 'Old',
        },
        changedFields: const <String>[],
      );

      expect(plan.verdict, ConflictVerdict.disjoint);
      expect(plan.mergedFields, isEmpty);
      expect(plan.payload!['version'], 4, reason: 'the server row is the base');
    });

    test('an empty change list falls back to every differing field', () {
      final plan = planConflictRebase(
        base: <String, dynamic>{'id': 'c1', 'court_name': 'Old'},
        server: <String, dynamic>{'id': 'c1', 'court_name': 'Old'},
        local: <String, dynamic>{'id': 'c1', 'court_name': 'Mine'},
        changedFields: const <String>[],
      );

      expect(plan.verdict, ConflictVerdict.disjoint);
      expect(plan.mergedFields, const <String>['court_name']);
      expect(plan.payload!['court_name'], 'Mine');
    });

    test('a null server value and an absent one are the same value', () {
      final plan = planConflictRebase(
        base: <String, dynamic>{'id': 'c1', 'firm_id': null},
        server: <String, dynamic>{'id': 'c1', 'firm_id': null},
        local: <String, dynamic>{'id': 'c1'},
        changedFields: const <String>['firm_id'],
      );

      expect(plan.verdict, ConflictVerdict.disjoint);
      expect(plan.mergedFields, isEmpty);
    });
  });
}
