/// Shared controls for the Settings sub-page bodies.
///
/// Notifications, View Settings and About all render the same three pieces: a
/// white bordered section card, a Title Case section label, and a full-width
/// 48 px control row — plus the picker dialogs those rows open. They live here
/// so those screens cannot drift apart the way the mockups' repeated markup
/// would otherwise allow.
library;

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';

/// The dropdown window's shape: the same 8 px corners as the Update window's
/// Next Date calendar, with no edge of its own — the elevation alone lifts the
/// white panel off the screen.
final ShapeBorder settingsPopoverWindowShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(AppSpacing.cardRadius * 2),
);

/// The drawer account popover's elevation, reused by the View Settings pickers.
const double settingsPopoverWindowElevation = 8;

/// White bordered card used by every Settings sub-page section.
BoxDecoration settingsCardDecoration({
  Color color = AppColors.surfaceContainerLowest,
}) => BoxDecoration(
  color: color,
  // Radius matches the mockups' `rounded-xl`.
  borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
  border: Border.all(color: AppColors.outlineVariant),
);

/// Section heading (mockup `label-md` + tracking).
class SettingsSectionLabel extends StatelessWidget {
  /// Label text; written in Title Case, like every other label in the app.
  final String text;

  const SettingsSectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: AppTypography.labelMd.copyWith(
      color: AppColors.onSurfaceVariant,
      letterSpacing: 0.6, // tracking-wider at 12 px.
    ),
  );
}

/// Bordered row that opens another screen: label on the left, a chevron right.
///
/// About's menu rows and Support's Guidelines & FAQs link are the same control,
/// so it lives here rather than being copied into each screen.
class SettingsLinkRow extends StatelessWidget {
  /// Row label, stored in sentence case (the screens decide on casing).
  final String label;

  /// Opens the destination.
  final VoidCallback onTap;

  /// Draws a small attention dot before the chevron.
  ///
  /// Used by the updater's row: something is waiting behind this row that the
  /// user has not been told about any other way.
  final bool showDot;

  const SettingsLinkRow({
    super.key,
    required this.label,
    required this.onTap,
    this.showDot = false,
  });

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
            if (showDot) ...[
              const UpdateDot(),
              const SizedBox(width: AppSpacing.sm),
            ],
            const Icon(Icons.chevron_right, color: AppColors.outline),
          ],
        ),
      ),
    ),
  );
}

/// The small "an update is available" dot.
///
/// Green, as the user asked for the update indicator. A dot rather than a count
/// pill: there is at most one thing to say, and a number would imply more.
class UpdateDot extends StatelessWidget {
  const UpdateDot({super.key});

  /// Diameter of the dot.
  static const double size = 10;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      color: AppColors.success,
    ),
  );
}

/// Full-width 48 px control row: label on the left, an affordance on the right.
///
/// Used by the Notifications and View Settings pickers, whose mockup markup is
/// a borderless-looking button pretending to be a select.
class SettingsPickerRow extends StatelessWidget {
  /// Currently selected value, already localized.
  final String text;

  /// Trailing icon (`expand_more`, `schedule`, …).
  final IconData icon;

  /// Opens the picker.
  final VoidCallback onTap;

  const SettingsPickerRow({
    super.key,
    required this.text,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surfaceContainerLowest,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      side: BorderSide(color: AppColors.outlineVariant),
    ),
    child: InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 48,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: [
              // One line only: a multi-value picker (several day offsets) can
              // hand over more text than the row's 48 px can hold.
              Expanded(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyLg,
                ),
              ),
              Icon(icon, color: AppColors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    ),
  );
}

/// One half of a two-option segmented control (mockup ON/OFF pair).
class SettingsChoiceButton extends StatelessWidget {
  /// Button label, e.g. "On" / "Off".
  final String label;

  /// Optional leading icon.
  final IconData? icon;

  /// Whether this option is the active one.
  final bool selected;

  /// Selects this option.
  final VoidCallback onTap;

  const SettingsChoiceButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: SizedBox(
      height: 48,
      child: Material(
        // The active half is the filled black control, matching every other
        // active state in the app.
        color: selected ? Colors.black : AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          side: BorderSide(
            color: selected ? Colors.black : AppColors.outlineVariant,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 20,
                  color: selected
                      ? AppColors.onPrimary
                      : AppColors.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Text(
                label,
                style: AppTypography.labelLg.copyWith(
                  color: selected
                      ? AppColors.onPrimary
                      : AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Single-select list shown inside a picker dialog (mockup's day-offset /
/// landing-page modals): selected row in `secondary` with a filled check.
class SettingsOptionRow extends StatelessWidget {
  /// Localized option label.
  final String label;

  /// Whether this option is the active one.
  final bool selected;

  /// Selects this option.
  final VoidCallback onTap;

  const SettingsOptionRow({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.bodyLg.copyWith(
                color: selected ? AppColors.secondary : AppColors.onSurface,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
          if (selected)
            const Icon(Icons.check_circle, color: AppColors.secondary),
        ],
      ),
    ),
  );
}

/// Multi-select picker dialog: a dark header over one check-mark row per
/// option, reporting every tick as it happens.
///
/// View Settings (bottom navigation, side navigation) and Notifications (day
/// offsets) all need "tick as many as you like" over the same list, so the
/// dialog lives here instead of being copied into each screen. [onChanged]
/// fires on every toggle — there is no confirm button — because the screens
/// behind it store each change straight away.
class SettingsMultiSelectDialog<T extends Object> extends StatefulWidget {
  /// Dialog title, shown in the header bar.
  final String title;

  /// Every candidate value, in display order.
  final List<T> order;

  /// Values that start out ticked.
  final Set<T> selected;

  /// Localized label of one value.
  final String Function(T value) labelOf;

  /// Called with the (display order, ticked values in that order) after a tick.
  final void Function(List<T> order, List<T> selected) onChanged;

  /// Whether rows can be dragged into a new order.
  final bool reorderable;

  /// How many values must stay ticked.
  final int minSelected;

  /// Shown when the user tries to go below [minSelected].
  final String? minSelectedMessage;

  /// Draws the window like the drawer's account popover — rounded, bordered and
  /// floating — instead of the plain Settings dialog. Off by default so screens
  /// outside View Settings keep their current window.
  final bool popoverWindow;

  const SettingsMultiSelectDialog({
    super.key,
    required this.title,
    required this.order,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
    this.reorderable = false,
    this.minSelected = 0,
    this.minSelectedMessage,
    this.popoverWindow = false,
  });

  @override
  State<SettingsMultiSelectDialog<T>> createState() =>
      _SettingsMultiSelectDialogState<T>();
}

class _SettingsMultiSelectDialogState<T extends Object>
    extends State<SettingsMultiSelectDialog<T>> {
  /// Display order of every candidate, as it stands in this dialog.
  late final List<T> _order = List<T>.of(widget.order);

  /// Currently ticked values.
  late final Set<T> _selected = Set<T>.of(widget.selected);

  /// The in-window warning shown when the last required tick is refused.
  ///
  /// It lives inside the dialog rather than in a SnackBar: the dialogs above
  /// the Add/Update Case windows cover the screen, so a SnackBar behind the
  /// barrier would never be seen.
  String? _minSelectionWarning;

  /// The ticked values in display order — the order the caller stores them in.
  List<T> get _orderedSelection => <T>[
    for (final value in _order)
      if (_selected.contains(value)) value,
  ];

  /// Ticks or unticks [value], refusing to drop below [minSelected].
  void _toggle(T value) {
    final removing = _selected.contains(value);
    if (removing && _selected.length <= widget.minSelected) {
      final message = widget.minSelectedMessage;
      if (message != null) {
        setState(() => _minSelectionWarning = message);
      }
      return;
    }
    setState(() {
      _minSelectionWarning = null;
      if (removing) {
        _selected.remove(value);
      } else {
        _selected.add(value);
      }
    });
    widget.onChanged(_order, _orderedSelection);
  }

  /// Moves one row and re-reports the selection in its new order.
  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      final moved = _order.removeAt(oldIndex);
      _order.insert(newIndex, moved);
    });
    widget.onChanged(_order, _orderedSelection);
  }

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(AppSpacing.md),
    backgroundColor: AppColors.surfaceContainerLowest,
    elevation: widget.popoverWindow ? settingsPopoverWindowElevation : null,
    clipBehavior: widget.popoverWindow ? Clip.antiAlias : Clip.none,
    shape: widget.popoverWindow
        ? settingsPopoverWindowShape
        : RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
          ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SettingsPickerDialogHeader(
          title: widget.title,
          enlarged: widget.popoverWindow,
        ),
        Flexible(child: widget.reorderable ? _draggableRows() : _rows()),
      ],
    ),
  );

  /// Rows the user can drag into a new order (bottom navigation).
  Widget _draggableRows() => ReorderableListView.builder(
    shrinkWrap: true,
    buildDefaultDragHandles: false,
    itemCount: _order.length,
    onReorderItem: _reorder,
    itemBuilder: (context, index) => Row(
      key: ValueKey<T>(_order[index]),
      children: [
        Expanded(child: _row(index)),
        // The drag handle is what makes the item reorderable; the item itself
        // still shows no screen icon.
        ReorderableDragStartListener(
          index: index,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Icon(Icons.drag_indicator, color: AppColors.tertiary),
          ),
        ),
      ],
    ),
  );

  /// Rows in fixed order (side navigation options, day offsets).
  Widget _rows() => ListView.builder(
    shrinkWrap: true,
    itemCount: _order.length,
    itemBuilder: (context, index) => _row(index),
  );

  /// One check-mark row, with the divider the picker lists use between rows.
  Widget _row(int index) {
    final value = _order[index];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (index > 0)
          const Divider(height: 1, color: AppColors.outlineVariant),
        SettingsOptionRow(
          key: ValueKey<T>(value),
          label: widget.labelOf(value),
          selected: _selected.contains(value),
          onTap: () => _toggle(value),
        ),
      ],
    );
  }
}

/// Header of a picker dialog, matching the mockup's dark header bar.
///
/// The title is centred between a spacer and the close button, so it gets the
/// widest text area the bar can offer, and it is fitted to that area: a long
/// title such as "Side Navigation Options" stays on one line (scaling down by
/// the few percent it needs) instead of wrapping into two.
class SettingsPickerDialogHeader extends StatelessWidget {
  /// Dialog title.
  final String title;

  /// Grows the bar to 1.25× its normal 48 px height, for the View Settings
  /// dropdown windows. Off by default so the Notifications picker keeps its
  /// current header.
  final bool enlarged;

  const SettingsPickerDialogHeader({
    super.key,
    required this.title,
    this.enlarged = false,
  });

  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.primaryContainer,
    constraints: BoxConstraints(minHeight: enlarged ? 48 * 1.25 : 0),
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
    child: Row(
      children: [
        // Mirrors the close button so the title stays centred in the bar.
        const SizedBox(width: 48),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              maxLines: 1,
              softWrap: false,
              textAlign: TextAlign.center,
              style: AppTypography.titleLg.copyWith(color: AppColors.onPrimary),
            ),
          ),
        ),
        IconButton(
          key: const ValueKey('settings-picker-close'),
          icon: const Icon(Icons.close, color: AppColors.onPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    ),
  );
}
