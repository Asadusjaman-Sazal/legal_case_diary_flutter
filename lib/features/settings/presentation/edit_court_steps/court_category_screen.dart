/// Court Category screen: division picker for Lower Courts.
/// Mirrors `courtCategory_lowerCourts-Division`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/pre_seeded_data.dart';
import '../../../../core/router/app_router.dart';
import '../../../../shared/providers/locale_provider.dart';
import '../settings_menu_card.dart';
import '../settings_sub_page_modal.dart';

/// Division picker screen for Lower Courts.
class CourtCategoryScreen extends ConsumerWidget {
  const CourtCategoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final isBn = locale.languageCode == 'bn';

    final divisions = districtIdsByDivision.keys.toList();

    return SettingsSubPageModal(
      title: 'Lower Courts',
      subtitle: 'Divisions',
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
              '${AppRoutes.settingsDistrictList}?division=$id',
            ),
          );
        },
      ),
    );
  }
}
