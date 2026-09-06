/// Profile screen: shows profile data (read view) and an editable form.
///
/// Task 12 Phase 2 (Part A): data is shown by default; a FAB opens an edit
/// sheet. The avatar edit button picks a profile picture, and a red delete
/// button appears beside it to clear the picture. Real persistence binds in
/// Part B (Task 17) via [ProfileRepository].
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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

  // Selected profile picture (Part A: in-memory only; persisted in Task 17).
  File? _avatarFile;

  @override
  void dispose() {
    _fullName.dispose();
    _barAssociation.dispose();
    _membershipNo.dispose();
    _officeAddress.dispose();
    _mobile.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _avatarFile = File(picked.path));
    }
  }

  void _clearAvatar() => setState(() => _avatarFile = null);

  void _openEditSheet() {
    // Editable controllers operate directly on the same state, so the read
    // view reflects edits when the sheet is saved.
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
        onSave: () {
          Navigator.of(sheetContext).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile saved (offline)')),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _fullName.text.trim();
    return SettingsSubPageModal(
      title: 'Profile',
      floatingActionButton: FloatingActionButton(
        onPressed: _openEditSheet,
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        tooltip: 'Edit profile',
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
                avatarFile: _avatarFile,
                onEditAvatar: _pickAvatar,
                onDeleteAvatar: _avatarFile != null ? _clearAvatar : null,
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
                      label: 'Full Name',
                      value: displayName.isNotEmpty ? displayName : '—',
                    ),
                    _DataRow(
                      icon: Icons.account_balance_outlined,
                      label: 'Bar Association',
                      value: _barAssociation.text.isNotEmpty
                          ? _barAssociation.text
                          : '—',
                    ),
                    _DataRow(
                      icon: Icons.badge_outlined,
                      label: 'Membership No.',
                      value: _membershipNo.text.isNotEmpty
                          ? _membershipNo.text
                          : '—',
                    ),
                    _DataRow(
                      icon: Icons.location_on_outlined,
                      label: 'Office Address',
                      value: _officeAddress.text.isNotEmpty
                          ? _officeAddress.text
                          : '—',
                    ),
                    _DataRow(
                      icon: Icons.call_outlined,
                      label: 'Mobile No.',
                      value: _mobile.text.isNotEmpty ? '+880 ${_mobile.text}' : '—',
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
        ? fullName
            .trim()
            .split(RegExp(r'\s+'))
            .map((e) => e[0])
            .take(2)
            .join()
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
                        style: AppTypography.headlineMd
                            .copyWith(color: AppColors.onSurfaceVariant),
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
                child: const Icon(Icons.edit,
                    color: AppColors.onPrimary, size: 18),
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
                child: const Icon(Icons.delete,
                    color: Colors.white, size: 18),
              ),
            ),
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
                  style: AppTypography.labelMd
                      .copyWith(color: AppColors.onSurfaceVariant),
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
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Edit Profile', style: AppTypography.titleLg),
          SizedBox(height: AppSpacing.lg),
          _Field(
            icon: Icons.person_outline,
            label: 'Full Name',
            controller: fullName,
            hint: 'Enter your full name',
          ),
          SizedBox(height: AppSpacing.lg),
          _Field(
            icon: Icons.account_balance_outlined,
            label: 'Bar Association',
            controller: barAssociation,
            hint: 'Enter bar association name',
          ),
          SizedBox(height: AppSpacing.lg),
          _Field(
            icon: Icons.badge_outlined,
            label: 'Membership No.',
            controller: membershipNo,
            hint: 'Enter registration number',
          ),
          SizedBox(height: AppSpacing.lg),
          _Field(
            icon: Icons.location_on_outlined,
            label: 'Office Address',
            controller: officeAddress,
            hint: 'Enter your office address',
            maxLines: 3,
          ),
          SizedBox(height: AppSpacing.lg),
          _MobileField(controller: mobile),
          SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 56,
            child: FilledButton.icon(
              onPressed: onSave,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save Profile'),
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
