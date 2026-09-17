/// Slot helper for rows added through the Edit Court/Steps sub-menus.
///
/// Every list in this section sorts by `order_index` ascending and nothing
/// else, so a new row must take a slot *after* the rows already in its list.
/// Reusing `0` ties it with the first existing row (or falls back to name
/// order), which is why added rows used to appear second instead of last.
library;

/// The `order_index` a newly added row should take so it sorts last among the
/// rows whose current indexes are [existingIndexes].
///
/// Returns `0` for an empty list, and one past the highest current index
/// otherwise, so sparse indexes never collide with an existing row.
int nextOrderIndex(Iterable<int> existingIndexes) {
  var highest = -1;
  for (final index in existingIndexes) {
    if (index > highest) highest = index;
  }
  return highest + 1;
}
