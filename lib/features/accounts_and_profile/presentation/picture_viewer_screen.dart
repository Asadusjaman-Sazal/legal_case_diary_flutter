/// The full-screen viewer for the profile picture and the firm logo.
///
/// The Profile and Manage Firm screens show their picture without any overlay
/// controls: tapping the picture opens this page, whose standard sub-page header
/// carries the back arrow, the **Delete** action (only when a picture exists)
/// and **Edit**. The image itself is drawn on black.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../settings/presentation/settings_sub_page_modal.dart';

/// A picture on black, with the viewer's header actions.
class PictureViewerScreen extends ConsumerWidget {
  /// Creates the viewer.
  const PictureViewerScreen({
    required this.title,
    required this.body,
    required this.hasImage,
    required this.editTooltip,
    required this.onEdit,
    this.onDelete,
    super.key,
  });

  /// The header title: *Profile Picture* or *Firm Logo*.
  final String title;

  /// The current picture, or its placeholder, filling the black area.
  final Widget body;

  /// Whether there is a picture to delete; read live so a first save reveals it.
  final bool Function(WidgetRef ref) hasImage;

  /// The Edit action's tooltip.
  final String editTooltip;

  /// Opens the source chooser and the selection page.
  final Future<void> Function(BuildContext context) onEdit;

  /// Deletes the picture; null when there is only a placeholder.
  final Future<void> Function()? onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final canDelete = onDelete != null && hasImage(ref);

    return SettingsSubPageModal(
      title: title,
      // A picture is not a syncing list: the viewer must not pull-to-sync.
      pullToSync: false,
      actions: [
        // The pair sits a little further from the edge, with 50% more space
        // between them than the old 4 px (user request).
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (canDelete) ...[
                _headerAction(
                  icon: Icons.delete,
                  color: AppColors.error,
                  tooltip: l.sharedActions_delete,
                  onTap: () async {
                    await onDelete!();
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
                const SizedBox(width: 6),
              ],
              _headerAction(
                icon: Icons.edit,
                color: AppColors.primary,
                tooltip: editTooltip,
                onTap: () => onEdit(context),
              ),
            ],
          ),
        ),
      ],
      child: ColoredBox(
        color: Colors.black,
        child: SizedBox.expand(child: body),
      ),
    );
  }

  /// One round header action, slightly larger than the old picture buttons.
  Widget _headerAction({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) => Tooltip(
    message: tooltip,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    ),
  );
}
