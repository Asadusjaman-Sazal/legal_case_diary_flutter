/// District list screen: districts under a division.
/// Mirrors `courtCategory_lowerCourts-Districts`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/pre_seeded_data.dart';
import '../../../../core/l10n/generated/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../shared/providers/locale_provider.dart';
import '../settings_menu_card.dart';
import '../settings_sub_page_modal.dart';

/// District list for a chosen division.
class DistrictListScreen extends ConsumerWidget {
  /// Division ID passed via route query parameter.
  final String division;

  /// Active walkthrough. [AppRoutes.lowerCourtCategoryFlow] routes a district
  /// into its Lower Court Categories list instead of its list of courts.
  final String? flow;

  const DistrictListScreen({super.key, required this.division, this.flow});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final isBn = locale.languageCode == 'bn';
    final divisionLabel = isBn
        ? divisionLabelBn[division] ?? division
        : divisionLabelEn[division] ?? division;

    final districts = districtIdsByDivision[division] ?? const <String>[];
    final l = AppLocalizations.of(context);

    return SettingsSubPageModal(
      title: l.settingsCourtFlow_divisionTitle(divisionLabel),
      subtitle: l.settingsCourtFlow_districts,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: districts.length,
        itemBuilder: (context, index) {
          final id = districts[index];
          final label = isBn
              ? districtLabelBn[id] ?? id
              : districtLabelEn[id] ?? id;
          // Shared sub-menu card; keeps the mockup's forward arrow as its
          // trailing affordance.
          return SettingsMenuCard(
            icon: Icons.location_on_outlined,
            title: label,
            trailing: const Icon(
              Icons.arrow_forward_ios,
              color: AppColors.tertiary,
              size: 18,
            ),
            onTap: () => context.push(
              flow == AppRoutes.lowerCourtCategoryFlow
                  ? '${AppRoutes.settingsLowerCourtCategoryList}'
                        '?division=$division&district=$id'
                  : '${AppRoutes.settingsCourtList}'
                        '?division=$division&district=$id',
            ),
          );
        },
      ),
    );
  }
}
