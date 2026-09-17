/// Court Category screen: division picker for Lower Courts.
/// Mirrors `courtCategory_lowerCourts-Division`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/pre_seeded_data.dart';
import '../../../../core/l10n/generated/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../shared/providers/locale_provider.dart';
import '../settings_menu_card.dart';
import '../settings_sub_page_modal.dart';

/// Division picker screen for Lower Courts.
class CourtCategoryScreen extends ConsumerWidget {
  /// Active walkthrough, e.g. [AppRoutes.lowerCourtCategoryFlow] when reached
  /// from Settings → Edit Court/Steps → Lower Court Categories. Null keeps the
  /// Edit Court Names & Categories walkthrough.
  final String? flow;

  const CourtCategoryScreen({super.key, this.flow});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final isBn = locale.languageCode == 'bn';

    final divisions = districtIdsByDivision.keys.toList();

    final l = AppLocalizations.of(context);

    return SettingsSubPageModal(
      title: l.settingsEditCourtNames_lowerCourts,
      subtitle: l.settingsCourtFlow_divisions,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: divisions.length,
        itemBuilder: (context, index) {
          final id = divisions[index];
          final label = isBn
              ? divisionLabelBn[id] ?? id
              : divisionLabelEn[id] ?? id;
          // Shared sub-menu card, so this screen matches the Account & Profile
          // card size.
          return SettingsMenuCard(
            icon: Icons.location_city_outlined,
            title: label,
            onTap: () => context.push(
              '${AppRoutes.settingsDistrictList}?division=$id'
              '${flow == null ? '' : '&flow=$flow'}',
            ),
          );
        },
      ),
    );
  }
}
