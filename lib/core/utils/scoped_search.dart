/// One screen's scoped library search, run against its own Drift query.
///
/// Plan §12.1: each feature owns and constrains its own dataset, so the text
/// query is executed by SQL *after* that dataset's predicate rather than by
/// filtering whatever rows the screen happened to load.
///
/// The runner exists so the case lists, Notes and Case References cannot drift
/// on the two things that are easy to get wrong: a blank query must restore the
/// screen's own dataset (not an empty list), and a slow query must never
/// overwrite a newer query's result — every query carries a generation, and an
/// older answer that arrives late is dropped.
library;

/// The latest result of one screen's scoped search.
class ScopedSearch<T> {
  /// Creates a runner that fetches through [fetch].
  ScopedSearch({required this.fetch});

  /// Runs the screen's scoped query for a non-blank query.
  final Future<List<T>> Function(String query) fetch;

  /// Bumped on every query, so an older answer can be recognised and dropped.
  int _generation = 0;

  List<T>? _rows;

  /// The rows the newest query returned, or `null` while no query is in force
  /// (the screen then lists its own dataset, as it does before searching).
  List<T>? get rows => _rows;

  /// Whether a query is currently narrowing the screen.
  bool get isActive => _rows != null;

  /// Runs [query] and keeps its result unless a newer query has already run.
  ///
  /// A blank [query] clears the result synchronously, so closing the search bar
  /// restores the full list without another round trip.
  Future<void> run(String query) async {
    final trimmed = query.trim();
    final generation = ++_generation;
    if (trimmed.isEmpty) {
      _rows = null;
      return;
    }
    final results = await fetch(trimmed);
    if (generation != _generation) return; // a newer query already answered
    _rows = results;
  }
}
