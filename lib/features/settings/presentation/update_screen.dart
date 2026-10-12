/// The About screen's **Update** sub-page: the three updater cards.
///
/// Opened by About's **Update** row, which is the same row shape as Support
/// (user request: the entry used to be a larger card that expanded in place,
/// toggling both cards at once, and is now an ordinary menu row that opens a
/// screen of its own). The three collapsible cards are unchanged — **App
/// Update** open by default (the check, Update Now the progress bar, and the
/// Later / Skip This Version pair), **Auto Check for Update** folded by default
/// (the check frequency), and **Update over Network** folded by default (Wi-Fi
/// or Mobile Data).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../data/update_metadata_store.dart';
import 'settings_menu_card.dart';
import 'settings_sub_page_modal.dart';
import 'update_schedule_card.dart';
import 'update_section.dart';

/// The Update sub-page.
class UpdateScreen extends StatelessWidget {
  const UpdateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SettingsSubPageModal(
      title: l.settingsUpdate_entry,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.edgeMargin,
          AppSpacing.md,
          AppSpacing.edgeMargin,
          AppSpacing.lg,
        ),
        children: const [UpdateCards()],
      ),
    );
  }
}

/// The page's three cards: App Update (open), Auto Check for Update (folded)
/// and Update over Network (folded).
class UpdateCards extends StatefulWidget {
  const UpdateCards({super.key});

  @override
  State<UpdateCards> createState() => _UpdateCardsState();
}

class _UpdateCardsState extends State<UpdateCards> {
  /// Whether App Update is unfolded. Defaults open.
  bool _appExpanded = true;

  /// Whether Auto Check for Update is unfolded. Defaults folded (off).
  bool _autoExpanded = false;

  /// Whether Update over Network is unfolded. Defaults folded.
  bool _networkExpanded = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      key: const ValueKey('update-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _nestedCard(
          id: 'update-app-update',
          icon: Icons.update_outlined,
          title: l.settingsUpdate_appUpdate,
          subtitle: l.settingsUpdate_appUpdateSubtitle,
          expanded: _appExpanded,
          onTap: () => setState(() => _appExpanded = !_appExpanded),
          child: const AppUpdateSection(),
        ),
        const SizedBox(height: AppSpacing.sm),
        _nestedCard(
          id: 'update-auto-update',
          icon: Icons.schedule_outlined,
          title: l.settingsUpdate_autoUpdate,
          subtitle: l.settingsUpdate_autoUpdateSubtitle,
          expanded: _autoExpanded,
          onTap: () => setState(() => _autoExpanded = !_autoExpanded),
          child: const UpdateScheduleCard(),
        ),
        const SizedBox(height: AppSpacing.sm),
        _nestedCard(
          id: 'update-network',
          icon: Icons.wifi_outlined,
          title: l.settingsUpdate_networkTitle,
          subtitle: l.settingsUpdate_networkSubtitle,
          expanded: _networkExpanded,
          onTap: () => setState(() => _networkExpanded = !_networkExpanded),
          child: const UpdateNetworkCard(),
        ),
      ],
    );
  }
}

/// Which network an update may be downloaded over: Wi-Fi only (default), or
/// either Wi-Fi or mobile data.
///
/// Two buttons in the same filled style as Check For Update, so the choice
/// reads as one setting with two states rather than a list. Wi-Fi only is the
/// platform norm — a tens-of-megabytes APK should not ride cellular without the
/// user saying so — and the wider option is the one that allows both.
///
/// **Side by side when they fit, one after another when they do not** (user
/// request): the labels are long enough that equal halves overflow on a narrow
/// phone, especially with the app's font-size steps. The widths are *measured*
/// rather than compared against a fixed breakpoint, so a larger text step or a
/// longer translation stacks them instead of clipping.
class UpdateNetworkCard extends ConsumerWidget {
  const UpdateNetworkCard({super.key});

  /// A button's own horizontal padding, both sides (FilledButton/OutlinedButton
  /// default), which the share of the row must cover along with the text.
  static const double _buttonPadding = 32;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final selected = ref.watch(updateMetadataProvider).network;

    Widget button({
      required Key key,
      required String label,
      required UpdateNetwork network,
    }) => _NetworkButton(
      key: key,
      label: label,
      selected: selected == network,
      onTap: () =>
          ref.read(updateMetadataProvider.notifier).setNetwork(network),
    );

    final wifi = button(
      key: const ValueKey('update-network-wifi'),
      label: l.settingsUpdate_networkWifi,
      network: UpdateNetwork.wifi,
    );
    final both = button(
      key: const ValueKey('update-network-mobile'),
      label: l.settingsUpdate_networkMobileData,
      network: UpdateNetwork.mobileData,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final fits = _fitsSideBySide(
          context,
          <String>[
            l.settingsUpdate_networkWifi,
            l.settingsUpdate_networkMobileData,
          ],
          constraints.maxWidth,
        );
        if (!fits) {
          // Full length, one after another, with the same gap either way.
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              wifi,
              const SizedBox(height: AppSpacing.sm),
              both,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: wifi),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: both),
          ],
        );
      },
    );
  }

  /// Whether every [label] fits its half of [availableWidth].
  ///
  /// Measured with the button's own text style and the active text scaler, so
  /// the answer follows a larger font step rather than assuming one.
  static bool _fitsSideBySide(
    BuildContext context,
    List<String> labels,
    double availableWidth,
  ) {
    final perButton = (availableWidth - AppSpacing.sm) / 2;
    if (perButton <= _buttonPadding) return false;
    for (final label in labels) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: AppTypography.labelLg),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      if (painter.width + _buttonPadding > perButton) return false;
    }
    return true;
  }
}

/// One of the two network buttons.
///
/// Selected is the filled dark button (white ink), unselected the outlined one,
/// so the pair stays legible whichever is chosen — the same two treatments the
/// app already uses for filled and outlined actions.
class _NetworkButton extends StatelessWidget {
  const _NetworkButton({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // A floor rather than a fixed height: at a large font step a long label
    // wraps, and a hard box would clip it. The minimum keeps every button in
    // the card the same height as Check For Update.
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
    );
    final child = Text(label, textAlign: TextAlign.center);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: settingsPrimaryButtonHeight),
      child: selected
          ? FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                textStyle: AppTypography.labelLg,
                shape: shape,
              ),
              child: child,
            )
          : OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: AppColors.primary,
                side: BorderSide(color: AppColors.outlineVariant),
                textStyle: AppTypography.labelLg,
                shape: shape,
              ),
              child: child,
            ),
    );
  }
}

/// One collapsible card: a header button and its expanded body.
Widget _nestedCard({
  required String id,
  required IconData icon,
  required String title,
  required String subtitle,
  required bool expanded,
  required VoidCallback onTap,
  required Widget child,
}) => Column(
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