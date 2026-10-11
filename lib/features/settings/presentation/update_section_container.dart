/// The About screen's **Update** entry: a collapsible card holding the App
/// Update and Auto Update sub-cards.
///
/// The user asked for "a sub menu called Update, inside it 2 collapsible
/// buttons (App Update and Auto Update)" and clarified that no separate Update
/// button was needed — the entry expands in place, exactly the shape the Backup
/// & Restore screen's collapsible sections use. Both sub-cards are the same
/// [SettingsMenuCard] sizing as the App Update button, and each expands its own
/// body.
library;

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import 'settings_menu_card.dart';
import 'update_schedule_card.dart';
import 'update_section.dart';

/// The collapsible Update entry: App Update + Auto Update.
class UpdateSectionContainer extends StatefulWidget {
  const UpdateSectionContainer({super.key});

  @override
  State<UpdateSectionContainer> createState() => _UpdateSectionContainerState();
}

class _UpdateSectionContainerState extends State<UpdateSectionContainer> {
  /// Whether App Update is unfolded. Defaults open.
  bool _appExpanded = true;

  /// Whether Auto Update is unfolded. Defaults folded (off).
  bool _autoExpanded = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      key: const ValueKey('update-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The top-level "Update" collapsible header.
        SettingsMenuCard(
          key: const ValueKey('update-section-header'),
          icon: Icons.system_update_alt_outlined,
          title: l.settingsUpdate_entry,
          subtitle: l.settingsUpdate_entrySubtitle,
          onTap: () => setState(() {
            // Toggle BOTH sub-cards together, since the whole entry is one
            // collapsible.
            _appExpanded = !_appExpanded;
          }),
          trailing: Icon(
            _appExpanded || _autoExpanded
                ? Icons.expand_less
                : Icons.expand_more,
            color: AppColors.tertiary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: _appExpanded || _autoExpanded
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _nestedCard(
                      id: 'update-app-update',
                      icon: Icons.update_outlined,
                      title: l.settingsUpdate_appUpdate,
                      subtitle: l.settingsUpdate_appUpdateSubtitle,
                      expanded: _appExpanded,
                      onTap: () => setState(
                        () => _appExpanded = !_appExpanded,
                      ),
                      child: const AppUpdateSection(),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _nestedCard(
                      id: 'update-auto-update',
                      icon: Icons.schedule_outlined,
                      title: l.settingsUpdate_autoUpdate,
                      subtitle: l.settingsUpdate_autoUpdateSubtitle,
                      expanded: _autoExpanded,
                      onTap: () => setState(
                        () => _autoExpanded = !_autoExpanded,
                      ),
                      child: const UpdateScheduleCard(),
                    ),
                  ],
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// One collapsible sub-card: a header button and its expanded body.
Widget _nestedCard({
  required String id,
  required IconData icon,
  required String title,
  required String subtitle,
  required bool expanded,
  required VoidCallback onTap,
  required Widget child,
}) =>
    Column(
      key: ValueKey(id),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsMenuCard(
          key: ValueKey('$id.header'),
          icon: icon,
          title: title,
          subtitle: subtitle,
          onTap: onTap,
          trailing: Icon(
            expanded ? Icons.expand_less : Icons.expand_more,
            color: AppColors.tertiary,
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: expanded
              ? Padding(
                  padding: const EdgeInsets.only(
                    top: AppSpacing.sm,
                    left: AppSpacing.sm,
                    right: AppSpacing.sm,
                  ),
                  child: child,
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );