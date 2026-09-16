/// Derivation of the lower-court categories that exist inside a district.
///
/// The Settings "Lower Court Categories" screen and the Add/Edit Case form must
/// agree on this list, so both call [districtCourtCategories] rather than
/// re-deriving it. A category counts as present in a district when it either
/// has at least one court there (every pre-seeded category) or was created by
/// the user for that district (custom categories are district-scoped).
library;

import '../../../core/constants/pre_seeded_data.dart';
import '../../../database/app_database.dart';

/// Court categories available for [district] inside [division].
///
/// Returns lower-court categories only, in the order supplied by [categories]
/// (the canonical `order_index` order used by the Add/Edit Case form). A
/// pre-seeded category with no court in the district is omitted; a user-created
/// category is included only in the district it was added to.
List<CourtCategory> districtCourtCategories({
  required List<CourtCategory> categories,
  required List<Court> courts,
  required String? division,
  required String? district,
}) {
  final lower = categories
      .where((item) => item.courtLevel == 'lower')
      .toList(growable: false);
  if (district == null) return lower;

  final withCourts = courts
      .where(
        (court) =>
            court.higherLowerCourts == lowerCourtsOption &&
            court.division == division &&
            court.district == district,
      )
      .map((court) => court.courtCategoryId)
      .toSet();

  return lower
      .where(
        (item) =>
            withCourts.contains(item.id) ||
            (item.isCustom &&
                item.division == division &&
                item.district == district),
      )
      .toList(growable: false);
}

/// The `order_index` a newly created category should take so it sorts last
/// among the lower-court categories.
int nextLowerCourtCategoryOrderIndex(List<CourtCategory> categories) {
  var highest = -1;
  for (final category in categories) {
    if (category.courtLevel == 'lower' && category.orderIndex > highest) {
      highest = category.orderIndex;
    }
  }
  return highest + 1;
}

/// New `order_index` values that move [reordered] into the ordering slots its
/// members already occupy in [canonical].
///
/// Category order is global (`order_index`), while this screen reorders only the
/// categories present in one district. Reusing the slots the district's
/// categories already hold keeps every other category — and therefore every
/// other district and the Add/Edit Case form — in its existing relative order.
Map<String, int> reorderedCategoryOrderIndexes({
  required List<CourtCategory> canonical,
  required List<CourtCategory> reordered,
}) {
  final movedIds = reordered.map((category) => category.id).toSet();
  final slots = <int>[
    for (final category in canonical)
      if (movedIds.contains(category.id)) category.orderIndex,
  ];

  return <String, int>{
    for (var index = 0; index < reordered.length; index++)
      reordered[index].id: slots[index],
  };
}
