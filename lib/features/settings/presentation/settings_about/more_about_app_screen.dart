/// About screen: app identity, developer card, and app-info links.
///
/// Body mirrors `mockup_html_screens/settings_about/code.html`. Three deliberate
/// additions/changes on top of that mockup (user-approved, Task 12 Phase 4):
/// the bundled app version is shown under the app name, the app logo comes from
/// `assets/icons/app_logo.png` in the placeholder gavel's 64 × 64 frame, and
/// the developer photo comes from `assets/images/dev_profile.jpg` because
/// Part A may not load the mockup's remote image. The mockup's personal
/// placeholder data (name, email, phone, court, copyright) stays hard-coded,
/// matching the earlier placeholder-data decision for mockup-only content.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/constants/app_version.dart';
import '../../../../core/l10n/generated/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../settings_controls.dart';
import '../settings_sub_page_modal.dart';

/// Bundled developer photo (mockup uses a remote image; Part A is offline).
const String _developerPhoto = 'assets/images/dev_profile.jpg';

/// Bundled app logo shown in the identity card.
const String _appLogo = 'assets/icons/app_logo.png';

/// Side of the square logo frame, unchanged from the placeholder gavel chip.
const double _logoSize = 64;

/// About screen.
class MoreAboutAppScreen extends StatelessWidget {
  const MoreAboutAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SettingsSubPageModal(
      title: l.settingsAbout_title,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.edgeMargin,
          AppSpacing.md,
          AppSpacing.edgeMargin,
          AppSpacing.lg,
        ),
        children: [
          const _AppTitleCard(),
          const SizedBox(height: AppSpacing.md),
          const _DeveloperCard(),
          const SizedBox(height: AppSpacing.md),
          // Menu rows; only "More About the App" has a screen so far, and
          // More/FAQ/Privacy/Terms/Support arrive with later tasks.
          _MenuRow(
            label: l.settingsAbout_moreAboutApp,
            onTap: () => context.push(AppRoutes.settingsMoreAbout),
          ),
          const SizedBox(height: AppSpacing.xs),
          _MenuRow(
            label: l.settingsAbout_faq,
            onTap: () => _showPending(context, l),
          ),
          const SizedBox(height: AppSpacing.xs),
          _MenuRow(
            label: l.settingsAbout_privacyPolicy,
            onTap: () => _showPending(context, l),
          ),
          const SizedBox(height: AppSpacing.xs),
          _MenuRow(
            label: l.settingsAbout_termsOfService,
            onTap: () => _showPending(context, l),
          ),
          const SizedBox(height: AppSpacing.xs),
          _MenuRow(
            label: l.settingsAbout_support,
            onTap: () => _showPending(context, l),
          ),
          const SizedBox(height: AppSpacing.md),
          _DataSafetyCard(
            title: l.settingsAbout_dataSafetyTitle,
            body: l.settingsAbout_dataSafetyBody,
          ),
          const SizedBox(height: AppSpacing.lg),
          // Mockup placeholder copyright line.
          Text(
            '© 2025 ASADUSJAMAN SAZAL',
            textAlign: TextAlign.center,
            style: AppTypography.labelMd.copyWith(
              color: AppColors.outline,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  /// Part A notice for the rows whose screens are not built yet.
  void _showPending(BuildContext context, AppLocalizations l) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l.settingsAbout_actionPending)));
  }
}

/// App identity card: app logo, app name and the bundled version.
class _AppTitleCard extends StatelessWidget {
  const _AppTitleCard();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      decoration: settingsCardDecoration(),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          Container(
            width: _logoSize,
            height: _logoSize,
            clipBehavior: Clip.antiAlias,
            // White like the card behind it, so the logo's transparent side
            // margins blend into the card instead of showing as dark bands.
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
            ),
            // The logo is shown whole inside the placeholder's frame; the
            // placeholder gavel returns if the asset is missing.
            child: Image.asset(
              _appLogo,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Center(
                // Ink on the white frame, not the placeholder's white-on-navy.
                child: Icon(Icons.gavel, size: 32, color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l.appTitle,
            style: AppTypography.titleLg.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l.settingsAbout_version(appVersion),
            style: AppTypography.bodySm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Developer profile card with the floating label from the mockup.
class _DeveloperCard extends StatelessWidget {
  const _DeveloperCard();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      decoration: settingsCardDecoration(),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Column(
              children: [
                const _DeveloperAvatar(),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Asadusjaman Sazal',
                  style: AppTypography.titleLg.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l.settingsAbout_role.toUpperCase(),
                  style: AppTypography.labelLg.copyWith(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'District & Sessions Judge Court, Narayanganj.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMd.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _ContactRow(
                  icon: Icons.mail_outline,
                  iconColor: AppColors.secondary,
                  label: l.settingsAbout_emailLabel,
                  value: 'adv.asadusjaman@gmail.com',
                ),
                const SizedBox(height: AppSpacing.sm),
                _ContactRow(
                  icon: Icons.chat_outlined,
                  iconColor: AppColors.success,
                  label: l.settingsAbout_whatsappLabel,
                  value: '+8801835252721',
                ),
              ],
            ),
          ),
          // Floating "Designed & developed by" label, breaking the top edge.
          Positioned(
            top: -AppSpacing.sm,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                color: AppColors.surfaceContainerLowest,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Text(
                  l.settingsAbout_designedBy.toUpperCase(),
                  style: AppTypography.labelMd.copyWith(
                    color: AppColors.outline,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Round developer photo with an initials fallback if the asset is missing.
class _DeveloperAvatar extends StatelessWidget {
  const _DeveloperAvatar();

  @override
  Widget build(BuildContext context) => ClipOval(
    child: Image.asset(
      _developerPhoto,
      width: 96,
      height: 96,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        width: 96,
        height: 96,
        color: AppColors.surfaceContainer,
        alignment: Alignment.center,
        child: Text('AS', style: AppTypography.titleLg),
      ),
    ),
  );
}

/// One contact row: round icon chip, uppercase label, value.
class _ContactRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _ContactRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
      border: Border.all(color: AppColors.outlineVariant),
    ),
    padding: const EdgeInsets.all(AppSpacing.sm),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surfaceContainerLowest,
          ),
          child: Icon(icon, size: 20, color: iconColor),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: AppTypography.labelMd.copyWith(color: AppColors.outline),
              ),
              Text(
                value,
                style: AppTypography.titleMd.copyWith(color: AppColors.primary),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// One white menu row: title plus the shared chevron.
class _MenuRow extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _MenuRow({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surfaceContainerLowest,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
      side: BorderSide(color: AppColors.outlineVariant),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTypography.titleMd.copyWith(color: AppColors.primary),
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.outline),
          ],
        ),
      ),
    ),
  );
}

/// Tinted "Data Safety" note from the mockup.
class _DataSafetyCard extends StatelessWidget {
  final String title;
  final String body;

  const _DataSafetyCard({required this.title, required this.body});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.tertiaryFixed,
      borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
      border: Border.all(color: AppColors.secondaryFixedDim),
    ),
    padding: const EdgeInsets.all(AppSpacing.md),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surfaceContainerLowest,
          ),
          child: const Icon(Icons.shield_outlined, color: AppColors.secondary),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: AppTypography.titleMd.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                body,
                style: AppTypography.bodyMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
