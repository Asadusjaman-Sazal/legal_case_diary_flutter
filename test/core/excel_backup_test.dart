/// Excel backup format tests (Task 15).
///
/// The workbook is a hand-built OOXML/ZIP container, so these tests pin the two
/// things that make it trustworthy: a round trip that loses nothing, and
/// refusals precise enough to name the sheet and the spreadsheet row that is
/// wrong. One case builds a workbook the way **Excel** writes one — a shared
/// string table and `t="s"` cells, no inline strings — because the user is
/// expected to open, edit and re-save the file.
library;

import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/core/backup/excel_backup.dart';

/// The `cases` columns used throughout, mirroring the real table's shape.
const List<ExcelColumnSpec> _caseSpecs = <ExcelColumnSpec>[
  ExcelColumnSpec(name: 'id', required: true, kind: ExcelCellKind.text),
  ExcelColumnSpec(name: 'court_id', required: true, kind: ExcelCellKind.text),
  ExcelColumnSpec(
    name: 'case_number',
    required: true,
    kind: ExcelCellKind.text,
  ),
  ExcelColumnSpec(
    name: 'next_date',
    required: false,
    kind: ExcelCellKind.integer,
  ),
  ExcelColumnSpec(
    name: 'is_deleted',
    required: false,
    kind: ExcelCellKind.boolean,
  ),
  ExcelColumnSpec(name: 'updated_at', required: true, kind: ExcelCellKind.integer),
];

/// The `notes` columns used throughout.
const List<ExcelColumnSpec> _noteSpecs = <ExcelColumnSpec>[
  ExcelColumnSpec(name: 'id', required: true, kind: ExcelCellKind.text),
  ExcelColumnSpec(name: 'title', required: false, kind: ExcelCellKind.text),
];

/// Every sheet's specs; the two tables without specs still get a header row.
Map<String, List<ExcelColumnSpec>> _columns() =>
    <String, List<ExcelColumnSpec>>{
      'cases': _caseSpecs,
      'case_history': const <ExcelColumnSpec>[],
      'notes': _noteSpecs,
      'case_references': const <ExcelColumnSpec>[],
    };

/// One `cases` row exercising text, integer, boolean and null values.
const Map<String, dynamic> _caseRow = <String, dynamic>{
  'id': 'case-1',
  'court_id': 'court-1',
  'case_number': 'Civil Suit 42/2026',
  'next_date': 1758844800000,
  'is_deleted': false,
  'updated_at': 1758844800000,
};

/// One `notes` row, with the nullable column absent.
const Map<String, dynamic> _noteRow = <String, dynamic>{'id': 'note-1'};

List<int> _encoded({String? notesTitle}) => encodeExcelBackup(
  appVersion: '0.0.262',
  exportedAt: 1758844800000,
  schemaVersion: 1,
  columns: _columns(),
  tables: <String, List<Map<String, dynamic>>>{
    'cases': <Map<String, dynamic>>[_caseRow],
    'case_history': const <Map<String, dynamic>>[],
    'notes': <Map<String, dynamic>>[
      <String, dynamic>{..._noteRow, 'title': ?notesTitle},
    ],
    'case_references': const <Map<String, dynamic>>[],
  },
);

/// Decodes with a deterministic id generator so a generated id is assertable.
ExcelBackupData _decoded(List<int> bytes) => decodeExcelBackup(
  bytes,
  columns: _columns(),
  supportedSchemaVersion: 1,
  newId: () => 'generated-id',
);

void main() {
  group('encode and decode', () {
    test('a round trip restores every value unchanged', () {
      final data = _decoded(_encoded());

      expect(data.schemaVersion, 1);
      expect(data.appVersion, '0.0.262');
      expect(data.exportedAt, 1758844800000);
      expect(data.tables['cases'], hasLength(1));

      final row = data.tables['cases']!.single;
      // The integer stays a whole number, the boolean stays a boolean, the
      // nullable column stays absent, and the text survives verbatim.
      expect(row['id'], 'case-1');
      expect(row['court_id'], 'court-1');
      expect(row['case_number'], 'Civil Suit 42/2026');
      expect(row['next_date'], 1758844800000);
      expect(row['is_deleted'], isFalse);
      expect(row.containsKey('title'), isFalse);
    });

    test('a nullable column that is filled comes back filled', () {
      final data = _decoded(_encoded(notesTitle: 'Hearing notes'));
      expect(data.tables['notes']!.single['title'], 'Hearing notes');
    });

    test('text that would break XML survives the trip', () {
      // Case text is user input: ampersands, angle brackets and quotes are all
      // ordinary legal titles, and any of them would corrupt the file if the
      // writer did not escape.
      const awkward = 'Rahim & Sons <"petitioner"> \u0007';
      final data = _decoded(_encoded(notesTitle: awkward));
      // The control character is dropped; the rest survives.
      expect(data.tables['notes']!.single['title'], 'Rahim & Sons <"petitioner"> ');
    });

    test('a workbook Excel re-saved with shared strings still restores', () {
      final data = _decoded(_excelStyleWorkbook());
      final row = data.tables['cases']!.single;
      expect(row['case_number'], 'Civil Suit 42/2026');
      expect(row['next_date'], 1758844800000);
      expect(row['is_deleted'], isFalse);
    });
  });

  group('the template', () {
    test('names every column of every data sheet, plus the Info sheet', () {
      final parts = _parts(
        buildExcelTemplate(
          appVersion: '0.0.262',
          schemaVersion: 1,
          columns: _columns(),
        ),
      );
      final workbook = parts['xl/workbook.xml']!;
      for (final sheet in <String>[...excelSheetTables.keys, excelInfoSheet]) {
        expect(workbook, contains('name="$sheet"'));
      }
      // The template is generated from the same spec the reader validates, so
      // its header row is exactly the column list.
      final cases = parts['xl/worksheets/sheet2.xml']!;
      for (final spec in _caseSpecs) {
        expect(cases, contains('<t xml:space="preserve">${spec.name}</t>'));
      }
    });

    test('carries one example row, and restores as data', () {
      final data = _decoded(
        buildExcelTemplate(
          appVersion: '0.0.262',
          schemaVersion: 1,
          columns: _columns(),
        ),
      );
      // The example row's id is the column name, so it is a real row rather than
      // a blank one — which is what proves the template is a valid starting
      // point and not just headers.
      expect(data.tables['cases']!.single['id'], 'id');
    });

    test('writes the extra reference sheets, and skips them on the way back', () {
      final bytes = buildExcelTemplate(
        appVersion: '0.0.262',
        schemaVersion: 1,
        columns: _columns(),
        // The caller fills the example case's foreign keys from its own data, so
        // the sample reads as a believable case instead of column names.
        exampleValues: <String, Map<String, Object?>>{
          'cases': <String, Object?>{'court_id': 'court-1'},
        },
        extraSheets: const <ExcelTemplateSheet>[
          ExcelTemplateSheet('Courts', <String>['Court ID'], <List<Object?>>[
            <Object?>['court-1'],
          ]),
          ExcelTemplateSheet('Guide', <String>['Guide'], <List<Object?>>[
            <Object?>['How To Add Your Own Cases'],
          ]),
        ],
      );

      final workbook = _parts(bytes)['xl/workbook.xml']!;
      expect(workbook, contains('name="Courts"'));
      expect(workbook, contains('name="Guide"'));

      // The reader tolerates the template's own extra sheets and reads only the
      // four data sheets — which is what lets the user fill in the very sample
      // they downloaded and restore it without deleting anything first.
      final data = _decoded(bytes);
      expect(data.tables.keys.toSet(), excelSheetTables.values.toSet());
      // The supplied value wins, and every other cell keeps its placeholder.
      expect(data.tables['cases']!.single['court_id'], 'court-1');
      expect(data.tables['cases']!.single['case_number'], 'case_number');
    });
  });

  group('refusals', () {
    test('a file whose Info sheet is missing is not a backup', () {
      expect(
        () => _decoded(_rewriteParts({'xl/workbook.xml': _workbookWithoutInfo})),
        _refusedBy(ExcelRefusalReason.notABackup, sheet: excelInfoSheet),
      );
    });

    test('a workbook with an extra sheet is refused by name', () {
      final parts = _parts(_encoded());
      parts['xl/worksheets/extra.xml'] = '<worksheet/>';
      parts['xl/workbook.xml'] = parts['xl/workbook.xml']!.replaceFirst(
        '</sheets>',
        '<sheet name="My Notes" sheetId="9" r:id="rId9"/></sheets>',
      );
      parts['xl/_rels/workbook.xml.rels'] = parts['xl/_rels/workbook.xml.rels']!
          .replaceFirst(
            '</Relationships>',
            '<Relationship Id="rId9" Type="$xmlnsDocRels/worksheet" '
            'Target="worksheets/extra.xml"/></Relationships>',
          );
      expect(
        () => _decoded(_zip(parts)),
        _refusedBy(ExcelRefusalReason.unknownSheet, sheet: 'My Notes'),
      );
    });

    test('a renamed column is refused by name', () {
      final data = _stringReplace(
        _encoded(),
        'xl/worksheets/sheet2.xml',
        '<t xml:space="preserve">case_number</t>',
        '<t xml:space="preserve">case_no</t>',
      );
      expect(
        () => _decoded(data),
        _refusedBy(ExcelRefusalReason.unknownColumn, sheet: 'Cases', column: 'case_no'),
      );
    });

    test('a header row missing a required column is refused by name', () {
      final data = _stringReplace(
        _encoded(),
        'xl/worksheets/sheet2.xml',
        '<c r="C1" t="inlineStr"><is><t xml:space="preserve">case_number</t></is></c>',
        '',
      );
      expect(
        () => _decoded(data),
        _refusedBy(
          ExcelRefusalReason.missingColumn,
          sheet: 'Cases',
          column: 'case_number',
        ),
      );
    });

    test('a blank required cell names the sheet and the spreadsheet row', () {
      // Row 2 is the first data row, so that is the number the user sees.
      final data = _stringReplace(
        _encoded(),
        'xl/worksheets/sheet2.xml',
        '<c r="B2" t="inlineStr"><is><t xml:space="preserve">court-1</t></is></c>',
        '',
      );
      expect(
        () => _decoded(data),
        _refusedBy(
          ExcelRefusalReason.missingValue,
          sheet: 'Cases',
          column: 'court_id',
          row: 2,
        ),
      );
    });

    test('text in an integer column is refused rather than dropped', () {
      final data = _stringReplace(
        _encoded(),
        'xl/worksheets/sheet2.xml',
        '<c r="D2"><v>1758844800000</v></c>',
        '<c r="D2" t="inlineStr"><is><t xml:space="preserve">next week</t></is></c>',
      );
      expect(
        () => _decoded(data),
        _refusedBy(
          ExcelRefusalReason.missingValue,
          sheet: 'Cases',
          column: 'next_date',
          row: 2,
        ),
      );
    });

    test('a newer schema version is refused', () {
      expect(
        () => decodeExcelBackup(
          _encoded(),
          columns: _columns(),
          supportedSchemaVersion: 0,
          newId: () => 'generated-id',
        ),
        _refusedBy(ExcelRefusalReason.newerVersion),
      );
    });

    test('bytes that are not a workbook are refused', () {
      expect(
        () => _decoded(utf8.encode('this is not a spreadsheet')),
        _refusedBy(ExcelRefusalReason.notASpreadsheet),
      );
    });
  });

  group('rows added by hand', () {
    test('a blank id becomes a new one, so a row can be typed in', () {
      final data = _stringReplace(
        _encoded(),
        'xl/worksheets/sheet2.xml',
        '<c r="A2" t="inlineStr"><is><t xml:space="preserve">case-1</t></is></c>',
        '',
      );
      expect(_decoded(data).tables['cases']!.single['id'], 'generated-id');
    });

    test('an entirely blank row is padding, not a record', () {
      final data = _stringReplace(
        _encoded(),
        'xl/worksheets/sheet2.xml',
        '</sheetData>',
        '<row r="9"></row></sheetData>',
      );
      expect(_decoded(data).tables['cases'], hasLength(1));
    });
  });
}

/// Matches a refusal with the given reason and place.
Matcher _refusedBy(
  ExcelRefusalReason reason, {
  String? sheet,
  String? column,
  int? row,
}) => throwsA(
  isA<ExcelBackupRefusal>()
      .having((refusal) => refusal.reason, 'reason', reason)
      .having((refusal) => refusal.sheet, 'sheet', sheet)
      .having((refusal) => refusal.column, 'column', column)
      .having((refusal) => refusal.row, 'row', row),
);

/// The workbook's parts as text, keyed by part path.
Map<String, String> _parts(List<int> bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);
  return <String, String>{
    for (final file in archive.files)
      if (file.isFile) file.name: utf8.decode(file.readBytes()!),
  };
}

/// Re-zips [parts] into workbook bytes.
List<int> _zip(Map<String, String> parts) {
  final archive = Archive();
  for (final part in parts.entries) {
    final bytes = utf8.encode(part.value);
    archive.add(ArchiveFile(part.key, bytes.length, bytes));
  }
  return ZipEncoder().encode(archive);
}

/// Replaces one string inside one part and re-zips the workbook.
///
/// Used to break a real workbook in exactly one way, so each refusal test proves
/// the check it names rather than a whole malformed file.
List<int> _stringReplace(
  List<int> bytes,
  String part,
  String from,
  String to,
) {
  final parts = _parts(bytes);
  final body = parts[part];
  expect(body, isNotNull, reason: 'the part $part should exist');
  expect(body, contains(from), reason: 'the fragment to replace should exist');
  parts[part] = body!.replaceFirst(from, to);
  return _zip(parts);
}

/// Replaces the workbook's sheet list with one that omits the Info sheet.
List<int> _rewriteParts(Map<String, String> replacements) {
  final parts = _parts(_encoded())..addAll(replacements);
  return _zip(parts);
}

/// The workbook part listing only the four data sheets.
String get _workbookWithoutInfo =>
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<workbook xmlns="$xmlnsSpreadsheet" xmlns:r="$xmlnsDocRels"><sheets>'
    '<sheet name="$excelCasesSheet" sheetId="1" r:id="rId2"/>'
    '</sheets></workbook>';

/// A workbook shaped the way **Excel** saves one: a shared-string table and
/// `t="s"` cells instead of the inline strings this app writes.
///
/// Independent of the writer on purpose — it is the only fixture here that does
/// not come from our own encoder, so it proves the reader understands a file
/// that has been through Excel.
List<int> _excelStyleWorkbook() {
  final shared = <String>[
    excelFormatKey,
    excelFormatValue,
    excelSchemaVersionKey,
    excelAppVersionKey,
    excelExportedAtKey,
    'id',
    'court_id',
    'case_number',
    'next_date',
    'is_deleted',
    'updated_at',
    'case-1',
    'court-1',
    'Civil Suit 42/2026',
    'title',
  ];
  String reference(int index) => '<c t="s"><v>$index</v></c>';

  final sheets = <String, String>{
    'Info': '<row r="1">${reference(0)}${reference(1)}</row>'
        '<row r="2">${reference(2)}<c><v>1</v></c></row>'
        '<row r="3">${reference(3)}${reference(1)}</row>'
        '<row r="4">${reference(4)}<c><v>1758844800000</v></c></row>',
    excelCasesSheet: '<row r="1">${reference(5)}${reference(6)}${reference(7)}'
        '${reference(8)}${reference(9)}${reference(10)}</row>'
        '<row r="2">${reference(11)}${reference(12)}${reference(13)}'
        '<c><v>1758844800000</v></c><c t="b"><v>0</v></c>'
        '<c><v>1758844800000</v></c></row>',
    excelCaseHistorySheet: '<row r="1"></row>',
    excelNotesSheet: '<row r="1">${reference(5)}${reference(14)}</row>',
    excelCaseReferencesSheet: '<row r="1"></row>',
  };

  final parts = <String, String>{
    'xl/sharedStrings.xml':
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<sst xmlns="$xmlnsSpreadsheet" count="${shared.length}">'
        '${shared.map((text) => '<si><t>$text</t></si>').join()}</sst>',
  };
  final rels = StringBuffer();
  final sheetTags = StringBuffer();
  var index = 0;
  for (final sheet in sheets.entries) {
    index++;
    parts['xl/worksheets/sheet$index.xml'] =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<worksheet xmlns="$xmlnsSpreadsheet"><sheetData>'
        '${sheet.value}</sheetData></worksheet>';
    rels.write(
      '<Relationship Id="rId$index" Type="$xmlnsDocRels/worksheet" '
      'Target="worksheets/sheet$index.xml"/>',
    );
    sheetTags.write(
      '<sheet name="${sheet.key}" sheetId="$index" r:id="rId$index"/>',
    );
  }
  parts['xl/workbook.xml'] =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<workbook xmlns="$xmlnsSpreadsheet" xmlns:r="$xmlnsDocRels">'
      '<sheets>$sheetTags</sheets></workbook>';
  parts['xl/_rels/workbook.xml.rels'] =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="$xmlnsPackageRels">$rels</Relationships>';
  return _zip(parts);
}
