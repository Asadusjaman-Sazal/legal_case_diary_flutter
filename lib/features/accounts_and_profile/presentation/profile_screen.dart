/// Profile screen: shows profile data (read view) and an editable form.
///
/// Task 12 Phase 2 (Part A): data is shown by default; a FAB opens an edit
/// sheet. The avatar edit button picks a profile picture, saved locally through
/// [profilePictureProvider] so it persists across launches and is reused by the
/// Manage Account screen; a red delete button clears it. The five fields are
/// kept in [profileFieldsProvider], so the navigation drawer header and the
/// case screens show the same values.
///
/// A new user starts with a blank profile: nothing is seeded, and each field
/// renders `—` (and the heading `Your Name`) until the user fills it in. Real
/// remote data binds in Part B (Task 17) via [ProfileRepository].
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../settings/presentation/settings_menu_card.dart';
import '../../settings/presentation/settings_sub_page_modal.dart';
import '../data/profile_name_store.dart';
import '../data/profile_picture_store.dart';

/// Profile screen matching `settings_profile\code.html`.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  // Editor controllers, seeded from the saved record when the sheet opens and
  // read back into it on Save. They start blank because a new user's profile is
  // blank — no mockup sample data is stored anywhere.
  final _fullName = TextEditingController();
  final _barAssociation = TextEditingController();
  final _membershipNo = TextEditingController();
  final _officeAddress = TextEditingController();
  final _mobile = TextEditingController();

  @override
  void dispose() {
    _fullName.dispose();
    _barAssociation.dispose();
    _membershipNo.dispose();
    _officeAddress.dispose();
    _mobile.dispose();
    super.dispose();
  }

  /// Picks an image from the gallery and saves it locally for persistence.
  Future<void> _pickAvatar() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      await ref.read(profilePictureProvider.notifier).setFromPath(picked.path);
    }
  }

  Future<void> _clearAvatar() =>
      ref.read(profilePictureProvider.notifier).clear();

  void _openEditSheet() {
    // Seed the editor with the saved record, so a sheet dismissed without
    // saving never leaves half-typed values behind for the next open.
    final saved = ref.read(profileFieldsProvider);
    _fullName.text = saved.fullName;
    _barAssociation.text = saved.barAssociation;
    _membershipNo.text = saved.membershipNo;
    _officeAddress.text = saved.officeAddress;
    _mobile.text = saved.mobile;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => _EditSheet(
        fullName: _fullName,
        barAssociation: _barAssociation,
        membershipNo: _membershipNo,
        officeAddress: _officeAddress,
        mobile: _mobile,
        onSave: () async {
          // Persist the whole record, so the read view and every other screen
          // that shows the user update together.
          await ref
              .read(profileFieldsProvider.notifier)
              .save(
                ProfileFields(
                  fullName: _fullName.text,
                  barAssociation: _barAssociation.text,
                  membershipNo: _membershipNo.text,
                  officeAddress: _officeAddress.text,
                  mobile: _mobile.text,
                ),
              );
          if (!sheetContext.mounted) return;
          Navigator.of(sheetContext).pop();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).settingsProfile_saved),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // The read view renders the saved record, not the editor's controllers.
    final profile = ref.watch(profileFieldsProvider);
    final displayName = profile.fullName;
    final avatarFile = ref.watch(profilePictureProvider);
    return SettingsSubPageModal(
      title: l.settingsProfile_title,
      floatingActionButton: FloatingActionButton(
        onPressed: _openEditSheet,
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        tooltip: l.settingsProfile_editTooltip,
        child: const Icon(Icons.edit_outlined),
      ),
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
              _ProfileHeader(
                fullName: displayName,
                avatarFile: avatarFile,
                onEditAvatar: _pickAvatar,
                onDeleteAvatar: avatarFile != null ? _clearAvatar : null,
              ),
              SizedBox(height: AppSpacing.lg),
              // Read-only data card.
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
                    _DataRow(
                      icon: Icons.person_outline,
                      label: l.settingsProfile_fullName,
                      value: displayName.isNotEmpty ? displayName : '—',
                    ),
                    _DataRow(
                      icon: Icons.account_balance_outlined,
                      label: l.settingsProfile_barAssociation,
                      value: profile.barAssociation.isNotEmpty
                          ? profile.barAssociation
                          : '—',
                    ),
                    _DataRow(
                      icon: Icons.badge_outlined,
                      label: l.settingsProfile_membershipNo,
                      value: profile.membershipNo.isNotEmpty
                          ? profile.membershipNo
                          : '—',
                    ),
                    _DataRow(
                      icon: Icons.location_on_outlined,
                      label: l.settingsProfile_officeAddress,
                      value: profile.officeAddress.isNotEmpty
                          ? profile.officeAddress
                          : '—',
                    ),
                    _DataRow(
                      icon: Icons.call_outlined,
                      label: l.settingsProfile_mobileNo,
                      value: profile.mobile.isNotEmpty
                          ? '+880 ${profile.mobile}'
                          : '—',
                    ),
                  ],
                ),
              ),
              SizedBox(height: AppSpacing.lg),
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
  final File? avatarFile;
  final VoidCallback onEditAvatar;
  final VoidCallback? onDeleteAvatar;

  const _ProfileHeader({
    required this.fullName,
    required this.avatarFile,
    required this.onEditAvatar,
    required this.onDeleteAvatar,
  });

  @override
  Widget build(BuildContext context) {
    final initials = fullName.isNotEmpty
        ? fullName.trim().split(RegExp(r'\s+')).map((e) => e[0]).take(2).join()
        : '?';
    final hasAvatar = avatarFile != null;
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
                image: hasAvatar
                    ? DecorationImage(
                        image: FileImage(avatarFile!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: hasAvatar
                  ? null
                  : Center(
                      child: Text(
                        initials.toUpperCase(),
                        style: AppTypography.headlineMd.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
            ),
            // Edit button (always present).
            GestureDetector(
              onTap: onEditAvatar,
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                  border: Border.all(color: AppColors.surface, width: 2),
                ),
                child: const Icon(
                  Icons.edit,
                  color: AppColors.onPrimary,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.sm),
        // Red delete button appears once a picture is selected, just left of
        // the name area (mirrors the round edit button position).
        if (hasAvatar && onDeleteAvatar != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: GestureDetector(
              onTap: onDeleteAvatar,
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.error,
                  border: Border.all(color: AppColors.surface, width: 2),
                ),
                child: const Icon(Icons.delete, color: Colors.white, size: 18),
              ),
            ),
          ),
        SizedBox(height: AppSpacing.md),
        Text(
          fullName.isNotEmpty
              ? AppLocalizations.of(
                  context,
                ).settingsProfile_displayName(fullName)
              : AppLocalizations.of(context).settingsProfile_yourName,
          style: AppTypography.titleLg.copyWith(color: AppColors.onBackground),
        ),
      ],
    );
  }
}

/// A read-only labelled row in the data card.
class _DataRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DataRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.lg * 0.55),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.onSurfaceVariant, size: 18),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.labelMd.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: AppSpacing.xs),
                Text(
                  value,
                  style: AppTypography.bodyLg.copyWith(
                    color: AppColors.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The edit form shown in a bottom sheet (mirrors the mockup's form fields).
class _EditSheet extends StatelessWidget {
  final TextEditingController fullName;
  final TextEditingController barAssociation;
  final TextEditingController membershipNo;
  final TextEditingController officeAddress;
  final TextEditingController mobile;
  final VoidCallback onSave;

  const _EditSheet({
    required this.fullName,
    required this.barAssociation,
    required this.membershipNo,
    required this.officeAddress,
    required this.mobile,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    // The form is taller than the space left above the keyboard, so it lives in
    // a scroll view: the sheet keeps its content-height size on a normal screen
    // and scrolls once the keyboard covers the bottom, instead of overflowing.
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.settingsProfile_editTitle, style: AppTypography.titleLg),
            SizedBox(height: AppSpacing.lg),
            _Field(
              icon: Icons.person_outline,
              label: l.settingsProfile_fullName,
              controller: fullName,
              hint: l.settingsProfile_fullNameHint,
            ),
            SizedBox(height: AppSpacing.lg),
            _Field(
              icon: Icons.account_balance_outlined,
              label: l.settingsProfile_barAssociation,
              controller: barAssociation,
              hint: l.settingsProfile_barAssociationHint,
            ),
            SizedBox(height: AppSpacing.lg),
            _Field(
              icon: Icons.badge_outlined,
              label: l.settingsProfile_membershipNo,
              controller: membershipNo,
              hint: l.settingsProfile_membershipNoHint,
            ),
            SizedBox(height: AppSpacing.lg),
            _Field(
              icon: Icons.location_on_outlined,
              label: l.settingsProfile_officeAddress,
              controller: officeAddress,
              hint: l.settingsProfile_officeAddressHint,
              maxLines: 3,
            ),
            SizedBox(height: AppSpacing.lg),
            _MobileField(controller: mobile),
            SizedBox(height: AppSpacing.md),
            SizedBox(
              // Shared sub-menu CTA height; see [settingsPrimaryButtonHeight].
              height: settingsPrimaryButtonHeight,
              child: FilledButton.icon(
                onPressed: onSave,
                icon: const Icon(Icons.save_outlined),
                label: Text(l.settingsProfile_save),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  textStyle: AppTypography.titleMd,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.md),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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

  const _Field({
    required this.icon,
    required this.label,
    required this.controller,
    required this.hint,
    this.maxLines = 1,
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
              Text(
                label,
                style: AppTypography.labelMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: AppSpacing.xs),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          cursorColor: AppColors.primary,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTypography.bodyMd.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
            filled: true,
            fillColor: AppColors.surfaceVariant,
            contentPadding: EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: maxLines > 1 ? AppSpacing.md : 14,
            ),
            border: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.cardBorder, width: 2),
            ),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.cardBorder, width: 2),
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
              Icon(
                Icons.call_outlined,
                color: AppColors.onSurfaceVariant,
                size: 18,
              ),
              SizedBox(width: AppSpacing.xs),
              Text(
                AppLocalizations.of(context).settingsProfile_mobileNo,
                style: AppTypography.labelMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
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
              child: Center(child: Text('+880', style: AppTypography.bodyMd)),
            ),
            SizedBox(width: AppSpacing.xs),
            Expanded(
              child: TextFormField(
                controller: controller,
                keyboardType: TextInputType.phone,
                cursorColor: AppColors.primary,
                decoration: InputDecoration(
                  hintText: '1XXXXXXXXX',
                  hintStyle: AppTypography.bodyMd.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceVariant,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  border: const UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: AppColors.cardBorder,
                      width: 2,
                    ),
                  ),
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: AppColors.cardBorder,
                      width: 2,
                    ),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.primary, width: 2),
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
