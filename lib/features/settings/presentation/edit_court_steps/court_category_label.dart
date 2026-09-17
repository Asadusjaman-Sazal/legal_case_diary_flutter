/// Localized label for a court category.
///
/// Built-in categories store their localization key in `name_key` (e.g.
/// `lowerCourtCategory_districtCourtsCivil`); categories the user added store
/// the typed name, which is shown as-is. The Lower Court Categories screen and
/// the Edit Court Names district walkthrough both list categories through this
/// helper, so the same category always reads the same in both places.
library;

import 'package:flutter/widgets.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/l10n/app_translations.dart';
import '../../../../database/app_database.dart';

/// Localized label for [category].
String courtCategoryLabel(BuildContext context, CourtCategory category) =>
    courtCategoryName(context, category.nameKey);

/// Localized label for a stored category name key.
///
/// [nameKey] is either one of the seeded category keys or a name the user
/// typed; an unknown key is returned unchanged.
String courtCategoryName(BuildContext context, String nameKey) {
  final grouped = context.l10n.grouped;
  return grouped[AppStrings.lowerCourtCategoryGroup]?[nameKey] ??
      grouped[AppStrings.courtCategoryGroup]?[nameKey] ??
      nameKey;
}
