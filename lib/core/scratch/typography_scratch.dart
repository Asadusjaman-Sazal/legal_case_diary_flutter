import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../constants/app_typography.dart';

/// Scratch widget used in Task 02 Phase 1 to verify that every custom font
/// declared in `pubspec.yaml` actually loads and renders at runtime.
///
/// Each sample uses a distinct font family and weight so a visual inspection (or
/// a widget test that pumps this page) can confirm the assets are wired correctly.
class TypographyScratch extends StatelessWidget {
  const TypographyScratch({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Typography Scratch'),
        backgroundColor: AppColors.surface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _section('Manrope (Headlines)'),
            Text('Manrope Bold 30', style: AppTypography.headlineLg),
            const SizedBox(height: AppSpacing.sm),
            Text('Manrope SemiBold 24', style: AppTypography.headlineMd),
            const SizedBox(height: AppSpacing.sm),
            Text('Manrope SemiBold 20', style: AppTypography.titleLg),

            _section('Inter (Body)'),
            Text('Inter SemiBold 16', style: AppTypography.titleMd),
            const SizedBox(height: AppSpacing.sm),
            Text('Inter Regular 16', style: AppTypography.bodyLg),
            const SizedBox(height: AppSpacing.sm),
            Text('Inter Regular 14', style: AppTypography.bodyMd),
            const SizedBox(height: AppSpacing.sm),
            Text('Inter Regular 12', style: AppTypography.bodySm),

            _section('IBM Plex Sans (Labels & Data)'),
            Text('IBM Plex Sans Medium 14', style: AppTypography.labelLg),
            const SizedBox(height: AppSpacing.sm),
            Text('IBM Plex Sans Medium 12', style: AppTypography.labelMd),
            const SizedBox(height: AppSpacing.sm),
            Text('IBM Plex Sans Bold 14', style: AppTypography.caseNumber),

            _section('Tiro Bangla (Bengali)'),
            Text(
              'বাংলা লেখার নমুনা — সব ফন্ট সঠিকভাবে লোড হয়েছে কিনা তা যাচাই করুন।',
              style: AppTypography.bengaliBodyLg,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'বাংলা মাধ্যমিক লেখা',
              style: AppTypography.bengaliBodyMd,
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String label) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.lg,
        bottom: AppSpacing.xs,
      ),
      child: Text(
        label,
        style: AppTypography.labelMd.copyWith(
          color: AppColors.tertiary,
        ),
      ),
    );
  }
}
