/// Excel (.xlsx) backup format (Task 15).
///
/// The app's canonical backup is the authenticated-encrypted container in
/// `backup_format.dart` / `backup_restore.dart`. This module adds a **plaintext
/// spreadsheet** covering the four tables a lawyer works with directly —
/// `cases`, `case_history`, `notes` and `case_references` — so the data can be
/// opened, read and edited in Excel. It is deliberately not a complete backup
/// and deliberately not encrypted; the task note records that as a known,
/// user-requested deviation from the plan's §12.3.1.
///
/// **Pure Dart**, like the rest of `core/backup`: no Flutter, no Drift, no
/// plugins. The caller supplies the column specs (it derives them from the
/// database schema, which is the only place they are authoritative), and this
/// file owns the container, the cell typing and the validation.
///
/// The OOXML/ZIP container is assembled here rather than through a spreadsheet
/// package: `excel` pins `xml <7`, which the PDF engine requires, so the two can
/// never coexist in this project. Writing is string-built part by part; reading
/// parses the very same parts, and also understands the shared-string table that
/// Excel writes when it re-saves a file, so an edited workbook still restores.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Sheet carrying the four tables' rows.
const String excelCasesSheet = 'Cases';

/// Sheet carrying the case-history rows.
const String excelCaseHistorySheet = 'Case History';

/// Sheet carrying the notes rows.
const String excelNotesSheet = 'Notes';

/// Sheet carrying the case-reference rows.
const String excelCaseReferencesSheet = 'Case References';

/// Sheet carrying the workbook's format metadata.
const String excelInfoSheet = 'Info';

/// Template-only sheets, in workbook order. They exist so the downloadable
/// **sample** shows the user the exact courts, case types, steps and roles their
/// own cases have to point at; a real backup never carries them, and the reader
/// skips them, so editing the sample and restoring it works as-is.
const String excelCourtsSheet = 'Courts';

/// Template-only sheet listing the case categories a case can be filed under.
const String excelCaseCategoriesSheet = 'Case Categories';

/// Template-only sheet listing the case types, by the name `cases.case_type`
/// stores.
const String excelCaseTypesSheet = 'Case Types';

/// Template-only sheet listing the procedural steps, by the name
/// `cases.last_step` stores.
const String excelStepsSheet = 'Steps';

/// Template-only sheet listing the representational roles a case can be filed
/// on behalf of.
const String excelOnBehalfsSheet = 'On Behalfs';

/// Template-only sheet explaining, in prose, how to add one's own cases.
const String excelGuideSheet = 'Guide';

/// Every template-only sheet name.
///
/// The reader accepts these and leaves them alone; they are documentation, not
/// data, so a workbook that still carries them imports exactly what its four data
/// sheets hold. Sheet names stay English identifiers for the same reason the data
/// sheets' do: one workbook has to work in either app language.
const Set<String> excelTemplateSheets = <String>{
  excelCourtsSheet,
  excelCaseCategoriesSheet,
  excelCaseTypesSheet,
  excelStepsSheet,
  excelOnBehalfsSheet,
  excelGuideSheet,
};

/// Sheet name → database table name, in workbook order.
///
/// Sheet names are **fixed English identifiers, not UI text**: one workbook has
/// to restore in either app language, so localizing them would produce files
/// that only one language can read. The Info sheet and the screen's explainer
/// both document them.
const Map<String, String> excelSheetTables = <String, String>{
  excelCasesSheet: 'cases',
  excelCaseHistorySheet: 'case_history',
  excelNotesSheet: 'notes',
  excelCaseReferencesSheet: 'case_references',
};

/// Info-sheet row identifying the file as one of ours.
const String excelFormatKey = 'format';

/// Value the [excelFormatKey] row must hold.
const String excelFormatValue = 'Legal Case Diary Excel Backup';

/// Info-sheet row holding the payload schema version.
const String excelSchemaVersionKey = 'schema_version';

/// Info-sheet row holding the app version that wrote the file.
const String excelAppVersionKey = 'app_version';

/// Info-sheet row holding the export time in epoch milliseconds.
const String excelExportedAtKey = 'exported_at';

/// How one column's value is written to, and read from, a cell.
///
/// The caller maps its database column types onto these, which keeps this file
/// free of any schema or database dependency.
enum ExcelCellKind {
  /// Anything textual, including JSON blobs and date strings.
  text,

  /// A whole number — the app stores every date and timestamp as epoch-millis.
  integer,

  /// A fractional number.
  real,

  /// A yes/no flag, written as Excel's own TRUE/FALSE.
  boolean,
}

/// One column a data sheet must carry.
class ExcelColumnSpec {
  /// Column name as stored in the database — also the sheet's header text.
  final String name;

  /// Whether a blank cell is refused in this column.
  ///
  /// True for a NOT NULL column with no SQL default, which is exactly what the
  /// database would refuse at `INSERT` time — refusing it here instead means the
  /// user is told which sheet and row are wrong rather than meeting a rolled-back
  /// import.
  final bool required;

  /// How the value round-trips through a cell.
  final ExcelCellKind kind;

  /// Creates a column spec.
  const ExcelColumnSpec({
    required this.name,
    required this.required,
    required this.kind,
  });
}

/// Why a workbook was refused, and where it went wrong.
enum ExcelRefusalReason {
  /// Not a readable spreadsheet: not a ZIP, or missing the workbook parts.
  notASpreadsheet,

  /// The Info sheet is absent or does not carry our format marker.
  notABackup,

  /// Written by a newer build than this one.
  newerVersion,

  /// One of the four data sheets is absent.
  missingSheet,

  /// A data sheet holds no rows at all, so it has no header row.
  emptySheet,

  /// The workbook holds a sheet this format does not define.
  unknownSheet,

  /// A sheet's header row omits a column this build expects.
  missingColumn,

  /// A sheet's header row names a column this build does not know.
  unknownColumn,

  /// A cell the database requires is blank.
  missingValue,
}

/// Thrown when a workbook is not in the backup format.
///
/// [sheet], [column] and [row] locate the problem so the screen can name the
/// sheet and the spreadsheet row in the user's own language; [row] is the
/// **spreadsheet** row number (the header row is 1), which is what the user sees
/// in Excel. Nothing here carries case data.
class ExcelBackupRefusal implements Exception {
  /// What was wrong.
  final ExcelRefusalReason reason;

  /// Sheet the problem is in, when it is sheet-specific.
  final String? sheet;

  /// Column the problem is in, when the header row is at fault.
  final String? column;

  /// Spreadsheet row number, when a cell is at fault.
  final int? row;

  /// Creates a refusal.
  const ExcelBackupRefusal(this.reason, {this.sheet, this.column, this.row});

  @override
  String toString() =>
      'ExcelBackupRefusal(${reason.name}'
      '${sheet == null ? '' : ', sheet: $sheet'}'
      '${column == null ? '' : ', column: $column'}'
      '${row == null ? '' : ', row: $row'})';
}

/// A workbook decoded back into database rows.
class ExcelBackupData {
  /// Payload schema version the Info sheet declared.
  final int schemaVersion;

  /// App version that wrote the file.
  final String appVersion;

  /// Export time in epoch milliseconds.
  final int exportedAt;

  /// Table name → rows, each row a column-name → value map.
  final Map<String, List<Map<String, dynamic>>> tables;

  /// Creates the decoded workbook.
  const ExcelBackupData({
    required this.schemaVersion,
    required this.appVersion,
    required this.exportedAt,
    required this.tables,
  });
}

// ---------------------------------------------------------------------------
// Writing
// ---------------------------------------------------------------------------

/// Builds the regular backups workbook: the four data sheets plus `Info`.
///
/// Only the columns in [columns] are written, in that order, so the headers the
/// user edits are the same list the reader validates against — one definition,
/// and it comes from the database schema.
List<int> encodeExcelBackup({
  required String appVersion,
  required int exportedAt,
  required int schemaVersion,
  required Map<String, List<ExcelColumnSpec>> columns,
  required Map<String, List<Map<String, dynamic>>> tables,
}) {
  final sheets = <_Sheet>[
    _Sheet(excelInfoSheet, <String>['key', 'value'], <List<Object?>>[
      <Object?>[excelFormatKey, excelFormatValue],
      <Object?>[excelSchemaVersionKey, schemaVersion],
      <Object?>[excelAppVersionKey, appVersion],
      <Object?>[excelExportedAtKey, exportedAt],
    ]),
  ];
  for (final entry in excelSheetTables.entries) {
    final specs = columns[entry.value] ?? const <ExcelColumnSpec>[];
    final rows = tables[entry.value] ?? const <Map<String, dynamic>>[];
    sheets.add(
      _Sheet(
        entry.key,
        <String>[for (final spec in specs) spec.name],
        <List<Object?>>[
          for (final row in rows) <Object?>[
            for (final spec in specs) row[spec.name],
          ],
        ],
      ),
    );
  }
  return _workbookBytes(sheets);
}

/// One extra sheet the sample carries: a reference table the user reads, or the
/// Guide's prose. Never written by a real export and never read back.
class ExcelTemplateSheet {
  /// Sheet name, as Excel shows it.
  final String name;

  /// Header row; may be empty for a sheet that is pure prose.
  final List<String> headers;

  /// Data rows, one cell list each.
  final List<List<Object?>> rows;

  /// Creates a template-only sheet.
  const ExcelTemplateSheet(this.name, this.headers, this.rows);
}

/// Builds the sample template: the same headers, with one example row per sheet.
///
/// Generated from [columns] rather than shipped as an asset, so the template can
/// never drift from the reader that validates a real file. The example values are
/// the column kinds' own placeholders, not anybody's case data, except where
/// [exampleValues] supplies a real value — the caller fills the foreign keys of
/// the example case from its own reference data, so the sample row reads as a
/// believable case instead of a wall of column names.
///
/// [extraSheets] are the reference and Guide sheets the sample adds; a real
/// export passes none.
List<int> buildExcelTemplate({
  required String appVersion,
  required int schemaVersion,
  required Map<String, List<ExcelColumnSpec>> columns,
  Map<String, Map<String, Object?>> exampleValues = const {},
  List<ExcelTemplateSheet> extraSheets = const [],
}) {
  final sheets = <_Sheet>[
    _Sheet(excelInfoSheet, <String>['key', 'value'], <List<Object?>>[
      <Object?>[excelFormatKey, excelFormatValue],
      <Object?>[excelSchemaVersionKey, schemaVersion],
      <Object?>[excelAppVersionKey, appVersion],
      <Object?>[excelExportedAtKey, 0],
    ]),
  ];
  for (final entry in excelSheetTables.entries) {
    final specs = columns[entry.value] ?? const <ExcelColumnSpec>[];
    final overrides = exampleValues[entry.value] ?? const <String, Object?>{};
    sheets.add(
      _Sheet(
        entry.key,
        <String>[for (final spec in specs) spec.name],
        <List<Object?>>[
          <Object?>[
            for (final spec in specs)
              overrides.containsKey(spec.name)
                  ? overrides[spec.name]
                  : _templateValue(spec),
          ],
        ],
      ),
    );
  }
  for (final extra in extraSheets) {
    sheets.add(_Sheet(extra.name, extra.headers, extra.rows));
  }
  return _workbookBytes(sheets);
}

/// One placeholder cell for the template's example row.
Object? _templateValue(ExcelColumnSpec spec) => switch (spec.kind) {
  ExcelCellKind.integer => 0,
  ExcelCellKind.real => 0.0,
  ExcelCellKind.boolean => false,
  ExcelCellKind.text => spec.name,
};

/// One sheet to write: its name, its header row, and its data rows.
class _Sheet {
  final String name;
  final List<String> headers;
  final List<List<Object?>> rows;

  const _Sheet(this.name, this.headers, this.rows);
}

/// Assembles the OOXML parts into a ZIP and returns the file's bytes.
List<int> _workbookBytes(List<_Sheet> sheets) {
  final parts = <String, String>{
    '[Content_Types].xml': _contentTypesXml(sheets.length),
    '_rels/.rels': _rootRelsXml,
    'xl/workbook.xml': _workbookXml(sheets),
    'xl/_rels/workbook.xml.rels': _workbookRelsXml(sheets.length),
    // A minimal style sheet: Excel tolerates its absence, but shipping one keeps
    // every cell on an explicit, known format.
    'xl/styles.xml': _stylesXml,
  };
  for (var i = 0; i < sheets.length; i++) {
    parts['xl/worksheets/sheet${i + 1}.xml'] = _sheetXml(sheets[i]);
  }

  final archive = Archive();
  for (final part in parts.entries) {
    final bytes = utf8.encode(part.value);
    archive.add(ArchiveFile(part.key, bytes.length, bytes));
  }
  return ZipEncoder().encode(archive);
}

String _contentTypesXml(int sheetCount) {
  final buffer = StringBuffer()
    ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
    ..write('<Types xmlns="$xmlnsContentTypes">')
    ..write(
      '<Default Extension="rels" ContentType="application/vnd.'
      'openxmlformats-package.relationships+xml"/>',
    )
    ..write('<Default Extension="xml" ContentType="application/xml"/>')
    ..write(
      '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.'
      'openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>',
    )
    ..write(
      '<Override PartName="/xl/styles.xml" ContentType="application/vnd.'
      'openxmlformats-officedocument.spreadsheetml.styles+xml"/>',
    );
  for (var i = 1; i <= sheetCount; i++) {
    buffer.write(
      '<Override PartName="/xl/worksheets/sheet$i.xml" '
      'ContentType="application/vnd.openxmlformats-officedocument.'
      'spreadsheetml.worksheet+xml"/>',
    );
  }
  buffer.write('</Types>');
  return buffer.toString();
}

String get _rootRelsXml =>
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Relationships xmlns="$xmlnsPackageRels">'
    '<Relationship Id="rId1" Type="$relTypeOfficeDocument" '
    'Target="xl/workbook.xml"/>'
    '</Relationships>';

String _workbookXml(List<_Sheet> sheets) {
  final buffer = StringBuffer()
    ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
    ..write('<workbook xmlns="$xmlnsSpreadsheet" xmlns:r="$xmlnsDocRels">')
    ..write('<sheets>');
  for (var i = 0; i < sheets.length; i++) {
    buffer.write(
      '<sheet name="${_xml(sheets[i].name)}" sheetId="${i + 1}" '
      'r:id="rId${i + 1}"/>',
    );
  }
  buffer.write('</sheets></workbook>');
  return buffer.toString();
}

String _workbookRelsXml(int sheetCount) {
  final buffer = StringBuffer()
    ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
    ..write('<Relationships xmlns="$xmlnsPackageRels">');
  for (var i = 1; i <= sheetCount; i++) {
    buffer.write(
      '<Relationship Id="rId$i" Type="$relTypeWorksheet" '
      'Target="worksheets/sheet$i.xml"/>',
    );
  }
  buffer.write(
    '<Relationship Id="rId${sheetCount + 1}" Type="$relTypeStyles" '
    'Target="styles.xml"/>',
  );
  buffer.write('</Relationships>');
  return buffer.toString();
}

String get _stylesXml =>
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<styleSheet xmlns="$xmlnsSpreadsheet">'
    '<fonts count="1"><font/></fonts>'
    '<fills count="1"><fill/></fills>'
    '<borders count="1"><border/></borders>'
    '<cellStyleXfs count="1"><xf/></cellStyleXfs>'
    '<cellXfs count="1"><xf/></cellXfs>'
    '</styleSheet>';

/// One worksheet: the header row, then one row per record.
///
/// Text is written as an inline string (`t="inlineStr"`) so no shared-string
/// table has to be built or kept in step; every cell carries its own reference so
/// a reader never has to infer the column from position.
String _sheetXml(_Sheet sheet) {
  final buffer = StringBuffer()
    ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
    ..write('<worksheet xmlns="$xmlnsSpreadsheet"><sheetData>')
    ..write(_rowXml(1, sheet.headers));
  for (var i = 0; i < sheet.rows.length; i++) {
    buffer.write(_rowXml(i + 2, sheet.rows[i]));
  }
  buffer.write('</sheetData></worksheet>');
  return buffer.toString();
}

String _rowXml(int rowNumber, List<Object?> values) {
  final buffer = StringBuffer('<row r="$rowNumber">');
  for (var i = 0; i < values.length; i++) {
    final reference = '${_columnLetters(i)}$rowNumber';
    final value = values[i];
    if (value == null) {
      // Left out entirely: an absent cell and an empty cell read back the same,
      // and the reader treats a blank as null.
      continue;
    }
    if (value is bool) {
      buffer.write('<c r="$reference" t="b"><v>${value ? 1 : 0}</v></c>');
    } else if (value is num) {
      buffer.write('<c r="$reference"><v>$value</v></c>');
    } else {
      buffer.write(
        '<c r="$reference" t="inlineStr"><is>'
        '<t xml:space="preserve">${_xml('$value')}</t></is></c>',
      );
    }
  }
  buffer.write('</row>');
  return buffer.toString();
}

/// `0` → `A`, `25` → `Z`, `26` → `AA`.
String _columnLetters(int index) {
  var remaining = index;
  final letters = <int>[];
  while (remaining >= 0) {
    letters.insert(0, 65 + (remaining % 26));
    remaining = remaining ~/ 26 - 1;
  }
  return String.fromCharCodes(letters);
}

/// Escapes [text] for XML, dropping the control characters XML 1.0 forbids.
///
/// Case text is user input, and a single stray control byte would make the whole
/// workbook unreadable, so it is filtered here rather than at every call site.
String _xml(String text) {
  final cleaned = String.fromCharCodes(
    text.codeUnits.where(
      (unit) =>
          unit == 0x09 ||
          unit == 0x0A ||
          unit == 0x0D ||
          (unit >= 0x20 && unit != 0xFFFE && unit != 0xFFFF),
    ),
  );
  return cleaned
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}

// ---------------------------------------------------------------------------
// Reading
// ---------------------------------------------------------------------------

/// Decodes a workbook written by [encodeExcelBackup], or one Excel re-saved.
///
/// Validates in the order that reports the most useful problem first: is it a
/// spreadsheet, is it ours, is it a version this build understands, are the
/// sheets and header rows exactly ours, and does every row fill what the database
/// requires. [columns] is the same spec the export used.
///
/// A blank `id` becomes a fresh id from [newId], which is what makes a row that
/// was added by hand importable; every other blank in a required column is
/// refused, named by sheet and spreadsheet row.
ExcelBackupData decodeExcelBackup(
  List<int> bytes, {
  required Map<String, List<ExcelColumnSpec>> columns,
  required int supportedSchemaVersion,
  required String Function() newId,
}) {
  final parts = _unzip(bytes);
  final shared = _sharedStrings(parts);
  final bodies = _sheetBodies(parts);

  // Sheet names first: an unrecognised sheet is refused before anything is read,
  // so a workbook that is not ours is never half-interpreted. The template's
  // reference and Guide sheets are accepted and then ignored, which is what lets
  // the user fill in the very sample they downloaded and restore it.
  final allowed = <String>{
    excelInfoSheet,
    ...excelSheetTables.keys,
    ...excelTemplateSheets,
  };
  for (final name in bodies.keys) {
    if (!allowed.contains(name)) {
      throw ExcelBackupRefusal(ExcelRefusalReason.unknownSheet, sheet: name);
    }
  }

  final infoBody = bodies[excelInfoSheet];
  if (infoBody == null) {
    throw const ExcelBackupRefusal(
      ExcelRefusalReason.notABackup,
      sheet: excelInfoSheet,
    );
  }
  final metadata = _readInfo(_readRows(infoBody, shared));
  if (metadata.schemaVersion > supportedSchemaVersion) {
    throw const ExcelBackupRefusal(ExcelRefusalReason.newerVersion);
  }

  final tables = <String, List<Map<String, dynamic>>>{};
  for (final entry in excelSheetTables.entries) {
    final body = bodies[entry.key];
    if (body == null) {
      throw ExcelBackupRefusal(ExcelRefusalReason.missingSheet, sheet: entry.key);
    }
    tables[entry.value] = _readTable(
      sheet: entry.key,
      specs: columns[entry.value] ?? const <ExcelColumnSpec>[],
      rows: _readRows(body, shared),
      newId: newId,
    );
  }

  return ExcelBackupData(
    schemaVersion: metadata.schemaVersion,
    appVersion: metadata.appVersion,
    exportedAt: metadata.exportedAt,
    tables: tables,
  );
}

/// The workbook's sheets as raw XML text, keyed by the sheet name Excel shows.
///
/// The name lives in the workbook part, not in the worksheet part, so the two are
/// joined through the workbook's relationship ids.
Map<String, String> _sheetBodies(Map<String, String> parts) {
  final workbook = parts['xl/workbook.xml'];
  if (workbook == null) {
    throw const ExcelBackupRefusal(ExcelRefusalReason.notASpreadsheet);
  }
  final rels = <String, String>{};
  final relPart = parts['xl/_rels/workbook.xml.rels'];
  if (relPart != null) {
    for (final relationship in _parse(relPart).findAllElements('Relationship')) {
      final id = relationship.getAttribute('Id');
      final target = relationship.getAttribute('Target');
      if (id != null && target != null) rels[id] = target;
    }
  }

  final bodies = <String, String>{};
  for (final sheet in _parse(workbook).findAllElements('sheet')) {
    final name = sheet.getAttribute('name');
    final id = sheet.getAttribute('r:id') ?? sheet.getAttribute('id');
    if (name == null || id == null) continue;
    final target = rels[id];
    if (target == null) continue;
    final path = target.startsWith('/')
        ? target.substring(1)
        : 'xl/${target.replaceFirst(RegExp(r'^\./'), '')}';
    final body = parts[path];
    if (body != null) bodies[name] = body;
  }
  if (bodies.isEmpty) {
    throw const ExcelBackupRefusal(ExcelRefusalReason.notASpreadsheet);
  }
  return bodies;
}

/// Unzips the workbook into its parts, keyed by part path.
Map<String, String> _unzip(List<int> bytes) {
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes);
  } catch (_) {
    throw const ExcelBackupRefusal(ExcelRefusalReason.notASpreadsheet);
  }
  final parts = <String, String>{};
  for (final file in archive.files) {
    if (!file.isFile) continue;
    final content = file.readBytes();
    if (content == null) continue;
    parts[file.name] = utf8.decode(content, allowMalformed: true);
  }
  if (parts.isEmpty) {
    throw const ExcelBackupRefusal(ExcelRefusalReason.notASpreadsheet);
  }
  return parts;
}

/// The shared-string table, when the workbook has one.
///
/// Excel writes one whenever it saves, so reading it is what lets a workbook the
/// user opened and re-saved in Excel still restore.
List<String> _sharedStrings(Map<String, String> parts) {
  final part = parts['xl/sharedStrings.xml'];
  if (part == null) return const <String>[];
  return <String>[
    for (final item in _parse(part).findAllElements('si'))
      item
          .findAllElements('t')
          .map((text) => text.innerText)
          .join(),
  ];
}

/// Parses XML, reporting a readable refusal rather than a parser exception.
XmlDocument _parse(String source) {
  try {
    return XmlDocument.parse(source);
  } catch (_) {
    throw const ExcelBackupRefusal(ExcelRefusalReason.notASpreadsheet);
  }
}

/// A sheet's cells, as `row index (0-based, header first)` → `column index → value`.
///
/// The cell reference (`r`) gives both, and Excel always writes it; when it is
/// missing the position in the row is used instead.
List<List<Object?>> _readRows(String sheetXml, List<String> shared) {
  final rows = <List<Object?>>[];
  for (final row in _parse(sheetXml).findAllElements('row')) {
    final cells = <Object?>[];
    var fallback = 0;
    for (final cell in row.findAllElements('c')) {
      final reference = cell.getAttribute('r');
      final index = reference == null ? fallback++ : _columnIndex(reference);
      while (cells.length <= index) {
        cells.add(null);
      }
      cells[index] = _cellValue(cell, shared);
    }
    rows.add(cells);
  }
  return rows;
}

/// A cell reference's column index: `A3` → `0`, `AB12` → `27`.
int _columnIndex(String reference) {
  var index = 0;
  for (final code in reference.codeUnits) {
    if (code < 0x41 || code > 0x5A) break;
    index = index * 26 + (code - 0x40);
  }
  return index - 1;
}

/// One cell's value, as `null`, `num`, `bool` or `String`.
Object? _cellValue(XmlElement cell, List<String> shared) {
  final type = cell.getAttribute('t');
  if (type == 'inlineStr') {
    final inline = cell.findElements('is');
    if (inline.isEmpty) return null;
    final text = inline.first
        .findAllElements('t')
        .map((element) => element.innerText)
        .join();
    return text.isEmpty ? null : text;
  }
  final values = cell.findElements('v');
  if (values.isEmpty) return null;
  final raw = values.first.innerText;
  return switch (type) {
    's' => _sharedValue(raw, shared),
    'b' => raw == '1' || raw.toLowerCase() == 'true',
    'str' => raw.isEmpty ? null : raw,
    _ => num.tryParse(raw) ?? (raw.isEmpty ? null : raw),
  };
}

/// Looks a shared-string index up, treating a malformed index as absent.
String? _sharedValue(String raw, List<String> shared) {
  final index = int.tryParse(raw);
  if (index == null || index < 0 || index >= shared.length) return null;
  final text = shared[index];
  return text.isEmpty ? null : text;
}

/// The `Info` sheet's metadata rows.
_ExcelInfo _readInfo(List<List<Object?>> rows) {
  final entries = <String, Object?>{};
  for (final row in rows) {
    if (row.isEmpty) continue;
    final key = row[0];
    if (key is! String) continue;
    entries[key.trim()] = row.length > 1 ? row[1] : null;
  }
  if ('${entries[excelFormatKey]}'.trim() != excelFormatValue) {
    throw const ExcelBackupRefusal(
      ExcelRefusalReason.notABackup,
      sheet: excelInfoSheet,
    );
  }
  final version = _asInt(entries[excelSchemaVersionKey]);
  if (version == null) {
    throw const ExcelBackupRefusal(
      ExcelRefusalReason.notABackup,
      sheet: excelInfoSheet,
      column: excelSchemaVersionKey,
    );
  }
  return _ExcelInfo(
    schemaVersion: version,
    appVersion: '${entries[excelAppVersionKey] ?? ''}',
    exportedAt: _asInt(entries[excelExportedAtKey]) ?? 0,
  );
}

/// The `Info` sheet's metadata.
class _ExcelInfo {
  final int schemaVersion;
  final String appVersion;
  final int exportedAt;

  const _ExcelInfo({
    required this.schemaVersion,
    required this.appVersion,
    required this.exportedAt,
  });
}

/// Reads one data sheet into database rows, refusing anything off-format.
///
/// The header row must name this build's columns for the table; it may list them
/// in any order, because a spreadsheet user reordering columns is harmless as
/// long as every column is there. A column the header omits is left out of every
/// row, so the database's own default applies to it — which is what keeps an
/// older workbook restorable after the schema gains a nullable column.
List<Map<String, dynamic>> _readTable({
  required String sheet,
  required List<ExcelColumnSpec> specs,
  required List<List<Object?>> rows,
  required String Function() newId,
}) {
  if (rows.isEmpty) {
    throw ExcelBackupRefusal(ExcelRefusalReason.emptySheet, sheet: sheet);
  }
  final known = <String, ExcelColumnSpec>{
    for (final spec in specs) spec.name: spec,
  };
  final header = rows.first;
  final positions = <String, int>{};
  for (var i = 0; i < header.length; i++) {
    final name = header[i];
    if (name == null) continue;
    final column = '$name'.trim();
    if (column.isEmpty) continue;
    final spec = known[column];
    if (spec == null) {
      throw ExcelBackupRefusal(
        ExcelRefusalReason.unknownColumn,
        sheet: sheet,
        column: column,
      );
    }
    positions[column] = i;
  }
  // A column the database requires must be named in the header row: leaving it
  // out would make every row fail at INSERT time with nothing to point at.
  for (final spec in specs) {
    if (spec.required && !positions.containsKey(spec.name)) {
      throw ExcelBackupRefusal(
        ExcelRefusalReason.missingColumn,
        sheet: sheet,
        column: spec.name,
      );
    }
  }

  final table = <Map<String, dynamic>>[];
  for (var i = 1; i < rows.length; i++) {
    final row = rows[i];
    // A row that is entirely blank is padding, not data: Excel files commonly
    // carry trailing empty rows.
    if (row.every((cell) => cell == null || '$cell'.trim().isEmpty)) continue;
    final record = <String, dynamic>{};
    for (final spec in specs) {
      final position = positions[spec.name];
      if (position == null) continue;
      final value = position < row.length ? row[position] : null;
      final blank = value == null || (value is String && value.trim().isEmpty);
      if (blank) {
        // A blank id is the one required cell that may be blank: it is what makes
        // a row added by hand in Excel importable.
        if (spec.name == 'id' && spec.required) {
          record['id'] = newId();
        } else if (spec.required) {
          throw ExcelBackupRefusal(
            ExcelRefusalReason.missingValue,
            sheet: sheet,
            column: spec.name,
            row: i + 1,
          );
        }
        // A blank optional cell is left out, so the column's default applies.
        continue;
      }
      final coerced = _coerce(value, spec.kind);
      if (coerced == null) {
        // A value that is present but cannot be a value of this column, e.g. text
        // typed into a date. Refused rather than silently dropped.
        throw ExcelBackupRefusal(
          ExcelRefusalReason.missingValue,
          sheet: sheet,
          column: spec.name,
          row: i + 1,
        );
      }
      record[spec.name] = coerced;
    }
    table.add(record);
  }
  return table;
}

/// Converts a cell's value into the Dart value the column expects.
Object? _coerce(Object? value, ExcelCellKind kind) {
  final text = '$value'.trim();
  return switch (kind) {
    ExcelCellKind.integer => _asInt(value),
    ExcelCellKind.real => value is num ? value.toDouble() : double.tryParse(text),
    // Excel's own TRUE/FALSE cell, and the text a user might type instead.
    ExcelCellKind.boolean => value is bool
        ? value
        : text == '1' || text.toLowerCase() == 'true',
    ExcelCellKind.text => '$value',
  };
}

/// [value] as a whole number, accepting a whole-numbered double from a cell.
int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) {
    final parsed = int.tryParse(value.trim());
    if (parsed != null) return parsed;
    return double.tryParse(value.trim())?.toInt();
  }
  return null;
}

// ---------------------------------------------------------------------------
// OOXML namespace and relationship identifiers
// ---------------------------------------------------------------------------

const String xmlnsSpreadsheet =
    'http://schemas.openxmlformats.org/spreadsheetml/2006/main';
const String xmlnsDocRels =
    'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
const String xmlnsContentTypes =
    'http://schemas.openxmlformats.org/package/2006/content-types';
const String xmlnsPackageRels =
    'http://schemas.openxmlformats.org/package/2006/relationships';
const String relTypeOfficeDocument =
    'http://schemas.openxmlformats.org/officeDocument/2006/relationships/'
    'officeDocument';
const String relTypeWorksheet =
    'http://schemas.openxmlformats.org/officeDocument/2006/relationships/'
    'worksheet';
const String relTypeStyles =
    'http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles';

/// The `Uint8List` view of a workbook's bytes, for the archive sink.
Uint8List excelBytes(List<int> bytes) => Uint8List.fromList(bytes);
