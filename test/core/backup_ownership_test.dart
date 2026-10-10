/// Tests for the backup ownership gate (Task 15 follow-up, user request).
///
/// A backup's envelope names no owner, so the gate reads the **rows**: a file
/// that names an id this device is not — and no firm it belongs to — is refused
/// before anything is imported, while a file that names nobody (a sample workbook
/// filled in by hand) restores and has this device's identity stamped onto it.
/// These tests pin both halves, because a relaxation that is one row too wide is
/// how another account's data ends up on the device and then refuses to sync.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/core/backup/backup_ownership.dart';

/// This device's identity, and the firm it belongs to.
const String _mine = '11111111-1111-4111-8111-111111111111';

/// A colleague in the same firm: a different person, the same firm scope.
const String _colleague = '22222222-2222-4222-8222-222222222222';

/// An account this device has nothing to do with.
const String _stranger = '33333333-3333-4333-8333-333333333333';

/// This device's firm, and one it is not a member of.
const String _firm = '44444444-4444-4444-8444-444444444444';
const String _otherFirm = '55555555-5555-4555-8555-555555555555';

/// A table's ownership columns, as the repository reads them from the schema.
const BackupOwnerColumns _columns = BackupOwnerColumns(
  owner: 'user_id',
  firm: 'firm_id',
  audit: <String>['last_modified_by'],
);

/// Classifies [rows] of one `cases`-like table against this device.
BackupOwnership _classify(
  List<Map<String, dynamic>> rows, {
  String? firmId,
  String table = 'cases',
}) => classifyBackupOwnership(
  tables: <String, dynamic>{table: rows},
  columns: const <String, BackupOwnerColumns>{'cases': _columns},
  ownerId: _mine,
  firmId: firmId,
);

void main() {
  group('isOwnerIdValue', () {
    test('accepts a UUID in any case, and nothing else', () {
      expect(isOwnerIdValue(_mine), isTrue);
      expect(isOwnerIdValue(_mine.toUpperCase()), isTrue);
      expect(isOwnerIdValue('  $_mine  '), isTrue);
      expect(isOwnerIdValue(''), isFalse);
      expect(isOwnerIdValue('user-1'), isFalse);
      expect(isOwnerIdValue('example-court-id'), isFalse);
      expect(isOwnerIdValue('Alice'), isFalse);
      expect(isOwnerIdValue(null), isFalse);
      expect(isOwnerIdValue(7), isFalse);
      expect(isOwnerIdValue('11111111-1111-4111-8111-11111111111'), isFalse);
    });
  });

  group('classifyBackupOwnership', () {
    test('a file whose rows name this device is mine', () {
      expect(
        _classify(<Map<String, dynamic>>[
          <String, dynamic>{'id': 'n1', 'user_id': _mine},
        ]),
        BackupOwnership.mine,
      );
    });

    test('a file naming an account this device is not is refused', () {
      expect(
        _classify(<Map<String, dynamic>>[
          <String, dynamic>{'id': 'n1', 'user_id': _stranger},
        ]),
        BackupOwnership.anotherAccount,
      );
    });

    test('one foreign row is enough, however many of mine it holds', () {
      expect(
        _classify(<Map<String, dynamic>>[
          <String, dynamic>{'id': 'n1', 'user_id': _mine},
          <String, dynamic>{'id': 'n2', 'user_id': _stranger},
        ]),
        BackupOwnership.anotherAccount,
      );
    });

    test("a firm colleague's row counts as this device's own", () {
      expect(
        _classify(
          <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'n1',
              'user_id': _colleague,
              'firm_id': _firm,
            },
          ],
          firmId: _firm,
        ),
        BackupOwnership.mine,
      );
    });

    test('a colleague of another firm is still another account', () {
      expect(
        _classify(
          <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'n1',
              'user_id': _colleague,
              'firm_id': _otherFirm,
            },
          ],
          firmId: _firm,
        ),
        BackupOwnership.anotherAccount,
      );
    });

    test('a file that names no owner at all is ownerless', () {
      expect(
        _classify(<Map<String, dynamic>>[
          <String, dynamic>{'id': 'n1', 'title': 'Mine'},
        ]),
        BackupOwnership.ownerless,
      );
      expect(_classify(const <Map<String, dynamic>>[]), BackupOwnership.ownerless);
    });

    test('placeholder text in an owner cell names nobody', () {
      // The sample workbook's own placeholders, a blank cell, and a name typed
      // by hand: none of them can be an account id, which is what makes
      // restoring a hand-filled template safe.
      for (final value in <Object?>['', 'user_id', 'example-court-id', 'Alice']) {
        expect(
          _classify(<Map<String, dynamic>>[
            <String, dynamic>{'id': 'n1', 'user_id': value},
          ]),
          BackupOwnership.ownerless,
          reason: 'owner cell "$value"',
        );
      }
    });

    test('a table with no ownership columns is never consulted', () {
      // The pull-only caches name accounts in their own columns; they are not
      // authored data, so a stranger's id in one cannot refuse the file.
      expect(
        classifyBackupOwnership(
          tables: <String, dynamic>{
            'firms': <Map<String, dynamic>>[
              <String, dynamic>{'id': 'f1', 'owner_id': _stranger},
            ],
          },
          columns: const <String, BackupOwnerColumns>{'cases': _columns},
          ownerId: _mine,
        ),
        BackupOwnership.ownerless,
      );
    });

    test('a firm row with no user id is mine through its firm scope', () {
      expect(
        _classify(
          <Map<String, dynamic>>[
            <String, dynamic>{'id': 'n1', 'firm_id': _firm},
          ],
          firmId: _firm,
        ),
        BackupOwnership.mine,
      );
    });
  });

  group('stampRowOwnership', () {
    test('writes this device onto a row that names no owner', () {
      final row = <String, dynamic>{
        'id': 'n1',
        'user_id': '',
        'last_modified_by': 'user_id',
      };

      expect(
        stampRowOwnership(row, _columns, ownerId: _mine, firmId: _firm),
        isTrue,
      );
      expect(row['user_id'], _mine);
      expect(row['last_modified_by'], _mine);
      expect(row['firm_id'], _firm);
    });

    test('an individual device writes no firm scope', () {
      final row = <String, dynamic>{'id': 'n1'};

      stampRowOwnership(row, _columns, ownerId: _mine);

      expect(row['user_id'], _mine);
      expect(row['firm_id'], isNull);
    });

    test("a colleague's row keeps its author, firm and attribution", () {
      final row = <String, dynamic>{
        'id': 'n1',
        'user_id': _colleague,
        'firm_id': _firm,
        'last_modified_by': _colleague,
      };

      expect(
        stampRowOwnership(row, _columns, ownerId: _mine, firmId: _firm),
        isFalse,
      );
      expect(row['user_id'], _colleague);
      expect(row['firm_id'], _firm);
      expect(row['last_modified_by'], _colleague);
    });
  });
}
