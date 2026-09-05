/// District list screen: districts under a division.
/// Mirrors `courtCategory_lowerCourts-Districts`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/constants/pre_seeded_data.dart';
import '../../../../core/router/app_router.dart';
import '../../../../shared/providers/locale_provider.dart';
import '../settings_sub_page_modal.dart';

/// District list for a chosen division.
class DistrictListScreen extends ConsumerWidget {
  /// Division ID passed via route query parameter.
  final String division;

  const DistrictListScreen({super.key, required this.division});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final isBn = locale.languageCode == 'bn';
    final divisionLabel = isBn
        ? divisionLabelBn[division] ?? division
        : divisionLabelEn[division] ?? division;

    final districts = districtIdsByDivision[division] ?? const <String>[];

    return SettingsSubPageModal(
      title: '$divisionLabel Division',
      subtitle: 'Districts',
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: districts.length,
        itemBuilder: (context, index) {
          final id = districts[index];
          final label = isBn
              ? districtLabelBn[id] ?? id
              : districtLabelEn[id] ?? id;
          return Card(
            elevation: 0,
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: AppColors.surfaceContainer),
            ),
            child: ListTile(
              leading: const Icon(Icons.location_on_outlined, color: AppColors.primary),
              title: Text(label, style: AppTypography.bodyLg),
              trailing: const Icon(Icons.arrow_forward_ios, color: AppColors.tertiary, size: 18),
              onTap: () => context.push(
                '${AppRoutes.settingsCourtList}?division=$division&district=$id',
              ),
            ),
          );
        },
      ),
    );
  }
}
