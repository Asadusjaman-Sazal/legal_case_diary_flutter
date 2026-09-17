/// Court categories inside one district, reached from Edit Court Names.
///
/// Settings → Edit Court/Steps → Edit Court Names → Lower Courts → Division →
/// District lands here. The categories are the same ones Settings → Edit Lower
/// Court Categories manages, derived through [districtCourtCategories] — a
/// pre-seeded category with no court in the district is not offered, and a
/// category the user added belongs to the district it was added to. Tapping a
/// card opens that category's court names.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/pre_seeded_data.dart';
import '../../../../core/l10n/generated/app_localizations.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../core/router/app_router.dart';
import '../../../../database/app_database.dart';
import '../../../../shared/providers/locale_provider.dart';
import '../../data/court_categories_repository.dart';
import '../../data/courts_repository.dart';
import '../../data/district_court_categories.dart';
import '../settings_menu_card.dart';
import '../settings_sub_page_modal.dart';
import 'court_category_label.dart';

/// Picker for a district's court categories (Edit Court Names walkthrough).
class DistrictCourtCategoryScreen extends ConsumerWidget {
  /// Division id (e.g. `dhaka`).
  final String division;

  /// District id (e.g. `dhaka`).
  final String district;

  const DistrictCourtCategoryScreen({
    super.key,
    required this.division,
    required this.district,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final isBn = locale.languageCode == 'bn';
    final districtLabel = isBn
        ? districtLabelBn[district] ?? district
        : districtLabelEn[district] ?? district;

    final courtsAsync = ref.watch(courtsRepositoryProvider);
    final categoriesAsync = ref.watch(courtCategoriesRepositoryProvider);
    final l = AppLocalizations.of(context);

    return SettingsSubPageModal(
      title: l.settingsLowerCourtCategories_title(districtLabel),
      subtitle: l.settingsEditCourtNames_lowerCourts,
      child: _buildBody(context, courtsAsync, categoriesAsync),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AsyncValue<CourtsRepository> courtsAsync,
    AsyncValue<CourtCategoriesRepository> categoriesAsync,
  ) {
    final error = courtsAsync.error ?? categoriesAsync.error;
    if (error != null) {
      return Center(
        child: Text(
          AppLocalizations.of(context).sharedMessages_error('$error'),
        ),
      );
    }

    final courtsRepo = courtsAsync.whenOrNull(data: (repo) => repo);
    final categoriesRepo = categoriesAsync.whenOrNull(data: (repo) => repo);
    if (courtsRepo == null || categoriesRepo == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return _DistrictCategoryList(
      division: division,
      district: district,
      courtsRepo: courtsRepo,
      categoriesRepo: categoriesRepo,
    );
  }
}

/// Reactive list of the categories that hold courts in this district.
class _DistrictCategoryList extends ConsumerWidget {
  final String division;
  final String district;
  final CourtsRepository courtsRepo;
  final CourtCategoriesRepository categoriesRepo;

  const _DistrictCategoryList({
    required this.division,
    required this.district,
    required this.courtsRepo,
    required this.categoriesRepo,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      StreamBuilder<List<CourtCategory>>(
        stream: categoriesRepo.watchAll(),
        builder: (context, categorySnapshot) {
          if (categorySnapshot.hasError) {
            return Center(
              child: Text(
                AppLocalizations.of(
                  context,
                ).sharedMessages_error('${categorySnapshot.error}'),
              ),
            );
          }
          if (!categorySnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final categories = categorySnapshot.data!;
          return StreamBuilder<List<Court>>(
            stream: courtsRepo.watchAll(),
            builder: (context, courtSnapshot) {
              if (courtSnapshot.hasError) {
                return Center(
                  child: Text(
                    AppLocalizations.of(
                      context,
                    ).sharedMessages_error('${courtSnapshot.error}'),
                  ),
                );
              }
              if (!courtSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final items = districtCourtCategories(
                categories: categories,
                courts: courtSnapshot.data!,
                division: division,
                district: district,
              );
              if (items.isEmpty) {
                return Center(
                  child: Text(
                    AppLocalizations.of(
                      context,
                    ).settingsLowerCourtCategories_empty,
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final category = items[index];
                  // Shared sub-menu card; keeps the mockup's forward arrow as
                  // its trailing affordance.
                  return SettingsMenuCard(
                    icon: Icons.balance_outlined,
                    title: courtCategoryLabel(context, category),
                    trailing: const Icon(
                      Icons.arrow_forward_ios,
                      color: AppColors.tertiary,
                      size: 18,
                    ),
                    onTap: () => context.push(
                      Uri(
                        path: AppRoutes.settingsCourtList,
                        queryParameters: <String, String>{
                          'higherLower': lowerCourtsOption,
                          'division': division,
                          'district': district,
                          'category': category.id,
                        },
                      ).toString(),
                      extra: category.nameKey,
                    ),
                  );
                },
              );
            },
          );
        },
      );
}
