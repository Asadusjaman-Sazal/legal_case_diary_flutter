/// Shared mapping between a `sync_queue` entity type and its server/Drift table.
///
/// The queue stores a singular `entity_type` (`case`, `note`, …) while the Drift
/// table and the Supabase table are plural (`cases`, `notes`, …). This is the one
/// place that translation lives, mirroring the server's `sync_entity_table()`
/// allow-list (Task 18 Phase 1), so the client can never name a table the RPC
/// would refuse.
///
/// The dependency order is the FK-safe push order the plan requires: the six
/// editable config tables first, then `cases`, then everything that may
/// reference a case or is a leaf. `sync_dependency_rank` mirrors the server's
/// function of the same name.
library;

import 'dart:convert';

/// `entity_type` -> the table it maps to, for all twelve domain tables.
const Map<String, String> syncTableByEntityType = <String, String>{
  'case': 'cases',
  'case_history': 'case_history',
  'note': 'notes',
  'reference': 'case_references',
  'court_category': 'court_categories',
  'case_category': 'case_categories',
  'court': 'courts',
  'step': 'steps',
  'case_type': 'case_types',
  'on_behalf': 'on_behalfs',
  'delete_request': 'delete_requests',
  'conflict_log': 'conflict_log',
};

/// The reverse map, used by the delta pull to name a table's entity type.
final Map<String, String> syncEntityTypeByTable = <String, String>{
  for (final entry in syncTableByEntityType.entries) entry.value: entry.key,
};

/// The server table for [entityType], or null when it is outside the class.
String? syncTableForEntity(String entityType) =>
    syncTableByEntityType[entityType];

/// The queue entity type for server [table], or null when it is out of class.
String? syncEntityForTable(String table) => syncEntityTypeByTable[table];

/// The FK-safe processing rank; lower is applied first.
int syncDependencyRank(String entityType) => switch (entityType) {
  'court_category' ||
  'case_category' ||
  'court' ||
  'step' ||
  'case_type' ||
  'on_behalf' => 0,
  'case' => 1,
  'case_history' || 'note' || 'reference' || 'delete_request' || 'conflict_log' => 2,
  _ => 3,
};

/// All twelve entity types in FK-safe order, for a full pull or a batch walk.
const List<String> pushEntityTypesInDependencyOrder = <String>[
  'court_category',
  'case_category',
  'court',
  'step',
  'case_type',
  'on_behalf',
  'case',
  'case_history',
  'note',
  'reference',
  'delete_request',
  'conflict_log',
];

/// The same twelve tables in the same FK-safe order, for the delta pull.
final List<String> syncPullTablesInDependencyOrder = <String>[
  for (final entityType in pushEntityTypesInDependencyOrder)
    syncTableByEntityType[entityType]!,
];

/// Converts one `snake_case` key to `camelCase`.
String snakeToCamel(String key) {
  if (!key.contains('_')) return key;
  final parts = key.split('_');
  final buffer = StringBuffer(parts.first);
  for (final part in parts.skip(1)) {
    if (part.isEmpty) continue;
    buffer
      ..write(part[0].toUpperCase())
      ..write(part.substring(1));
  }
  return buffer.toString();
}

/// Converts a `snake_case`-keyed map (server/queue payload) to `camelCase`.
Map<String, dynamic> snakeToCamelMap(Map<String, dynamic> snake) =>
    snake.map((key, value) => MapEntry(snakeToCamel(key), value));

/// Decodes a JSON object string into a map; an empty or malformed value is an
/// empty map, never a thrown error, because a single bad queue row must not stop
/// a batch.
Map<String, dynamic> decodeJsonObject(String json) {
  if (json.isEmpty) return <String, dynamic>{};
  try {
    final decoded = const JsonCodec().decode(json);
    if (decoded is Map) return decoded.cast<String, dynamic>();
  } on Object {
    // Fall through to the empty map.
  }
  return <String, dynamic>{};
}

/// Decodes a JSON array string into a list of strings.
List<String> decodeJsonStringList(String json) {
  if (json.isEmpty) return const <String>[];
  try {
    final decoded = const JsonCodec().decode(json);
    if (decoded is List) {
      return decoded.whereType<String>().toList(growable: false);
    }
  } on Object {
    // Fall through to the empty list.
  }
  return const <String>[];
}
