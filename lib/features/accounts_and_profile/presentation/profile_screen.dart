/// Profile screen: shows the profile form per the `settings_profile` mockup.
///
/// Task 12 Phase 2 (Part A): the form is editable locally with offline
/// defaults; the Save action is a local-only confirmation. Real profile data
/// binds in Part B (Task 17), which wires [ProfileRepository].
library;

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../settings/presentation/settings_sub_page_modal.dart';

/// Profile screen matching `settings_profile\code.html`.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _fullName = TextEditingController(text: 'Asadusjaman');
  final _barAssociation = TextEditingController(text: 'Dhaka Bar Association');
  final _membershipNo = TextEditingController(text: '1557');
  final _officeAddress =
      TextEditingController(text: 'Chamber 402, High Court Annex, Dhaka-1000');
  final _mobile = TextEditingController(text: '1812332721');

  @override
  void dispose() {
    _fullName.dispose();
    _barAssociation.dispose();
    _membershipNo.dispose();
    _officeAddress.dispose();
    _mobile.dispose();
    super.dispose();
  }

  void _save() {
    // Part A: local-only confirmation. Task 17 persists via ProfileRepository.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile saved (offline)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _fullName.text.trim();
    return SettingsSubPageModal(
      title: 'Profile',
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.edgeMargin,
          AppSpacing.sm,
          AppSpacing.edgeMargin,
          AppSpacing.xl,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children: [
              // Profile picture + name.
              _ProfileHeader(fullName: displayName),
              SizedBox(height: AppSpacing.xl),
              // Form card.
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(AppSpacing.md),
                  border: Border.all(color: AppColors.outlineVariant),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Field(
                      icon: Icons.person_outline,
                      label: 'Full Name',
                      controller: _fullName,
                      hint: 'Enter your full name',
                      onChanged: () => setState(() {}),
                    ),
                    SizedBox(height: AppSpacing.lg),
                    _Field(
                      icon: Icons.account_balance_outlined,
                      label: 'Bar Association',
                      controller: _barAssociation,
                      hint: 'Enter bar association name',
                    ),
                    SizedBox(height: AppSpacing.lg),
                    _Field(
                      icon: Icons.badge_outlined,
                      label: 'Membership No.',
                      controller: _membershipNo,
                      hint: 'Enter registration number',
                    ),
                    SizedBox(height: AppSpacing.lg),
                    _Field(
                      icon: Icons.location_on_outlined,
                      label: 'Office Address',
                      controller: _officeAddress,
                      hint: 'Enter your office address',
                      maxLines: 3,
                    ),
                    SizedBox(height: AppSpacing.lg),
                    _MobileField(controller: _mobile),
                    SizedBox(height: AppSpacing.md),
                    SizedBox(
                      height: 56,
                      child: FilledButton.icon(
                        onPressed: _save,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Save Profile'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.onPrimary,
                          textStyle: AppTypography.titleMd,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppSpacing.md),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: AppSpacing.lg),
              // Info box.
              Container(
                decoration: BoxDecoration(
                  color: AppColors.secondaryContainer.withValues(alpha: 0.1),
                  border: Border.all(
                    color: AppColors.secondary.withValues(alpha: 0.2),
                  ),
                  borderRadius: BorderRadius.circular(AppSpacing.md),
                ),
                padding: EdgeInsets.all(AppSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline,
                        color: AppColors.secondary, size: 18),
                    SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        'These details will be used to automatically populate '
                        'headers on generated Cause Lists and Client Reports.',
                        style: AppTypography.bodySm
                            .copyWith(color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Circular avatar with name heading, mirroring the mockup's picture section.
class _ProfileHeader extends StatelessWidget {
  final String fullName;

  const _ProfileHeader({required this.fullName});

  @override
  Widget build(BuildContext context) {
    final initials = fullName.isNotEmpty
        ? fullName.trim().split(RegExp(r'\s+')).map((e) => e[0]).take(2).join()
        : '?';
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
                color: AppColors.surfaceContainerHighest,
              ),
              child: Center(
                child: Text(
                  initials.toUpperCase(),
                  style: AppTypography.headlineMd
                      .copyWith(color: AppColors.onSurfaceVariant),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(AppSpacing.xs),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary,
                border: Border.all(color: AppColors.surface, width: 2),
              ),
              child: const Icon(Icons.edit,
                  color: AppColors.onPrimary, size: 18),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.md),
        Text(
          fullName.isNotEmpty ? 'Adv. $fullName' : 'Your Name',
          style: AppTypography.titleLg.copyWith(color: AppColors.onBackground),
        ),
      ],
    );
  }
}

/// A labelled form field matching the mockup's filled-input style.
class _Field extends StatelessWidget {
  final IconData icon;
  final String label;
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final VoidCallback? onChanged;

  const _Field({
    required this.icon,
    required this.label,
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Row(
            children: [
              Icon(icon, color: AppColors.onSurfaceVariant, size: 18),
              SizedBox(width: AppSpacing.xs),
              Text(label,
                  style: AppTypography.labelMd
                      .copyWith(color: AppColors.onSurfaceVariant)),
            ],
          ),
        ),
        SizedBox(height: AppSpacing.xs),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          onChanged: (_) => onChanged?.call(),
          cursorColor: AppColors.primary,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
            filled: true,
            fillColor: AppColors.surfaceVariant,
            contentPadding: EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: maxLines > 1 ? AppSpacing.md : 14,
            ),
            border: const UnderlineInputBorder(
              borderSide:
                  BorderSide(color: AppColors.cardBorder, width: 2),
            ),
            enabledBorder: const UnderlineInputBorder(
              borderSide:
                  BorderSide(color: AppColors.cardBorder, width: 2),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

/// Mobile number field with a fixed `+880` prefix box, per the mockup.
class _MobileField extends StatelessWidget {
  final TextEditingController controller;

  const _MobileField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Row(
            children: [
              Icon(Icons.call_outlined,
                  color: AppColors.onSurfaceVariant, size: 18),
              SizedBox(width: AppSpacing.xs),
              Text('Mobile No.',
                  style: AppTypography.labelMd
                      .copyWith(color: AppColors.onSurfaceVariant)),
            ],
          ),
        ),
        SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Container(
              height: 48,
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                border: const Border(
                  bottom: BorderSide(color: AppColors.outlineVariant, width: 2),
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8),
                ),
              ),
              child: Center(
                child: Text('+880', style: AppTypography.bodyMd),
              ),
            ),
            SizedBox(width: AppSpacing.xs),
            Expanded(
              child: TextFormField(
                controller: controller,
                keyboardType: TextInputType.phone,
                cursorColor: AppColors.primary,
                decoration: InputDecoration(
                  hintText: '1XXXXXXXXX',
                  hintStyle: AppTypography.bodyMd
                      .copyWith(color: AppColors.onSurfaceVariant),
                  filled: true,
                  fillColor: AppColors.surfaceVariant,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  border: const UnderlineInputBorder(
                    borderSide:
                        BorderSide(color: AppColors.cardBorder, width: 2),
                  ),
                  enabledBorder: const UnderlineInputBorder(
                    borderSide:
                        BorderSide(color: AppColors.cardBorder, width: 2),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide:
                        BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
