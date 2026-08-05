/// Searchable single-select and multi-select dropdown.
///
/// The widget owns only transient picker state. Selected values remain owned by
/// the host screen through [value], [selectedValues], and the callbacks.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';
import '../../core/l10n/generated/app_localizations.dart';

/// A generic dropdown that opens a centered searchable selection dialog.
class CustomDropdown<T> extends StatelessWidget {
  /// Optional field label displayed above the control.
  final String? label;

  /// Placeholder displayed when no value is selected.
  final String? hint;

  /// Items available for selection.
  final List<T> items;

  /// Current single-select value.
  final T? value;

  /// Current multi-select values.
  final List<T> selectedValues;

  /// Whether multiple items may be selected before confirming.
  final bool multiSelect;

  /// Whether the picker includes its search box. Defaults to enabled; callers
  /// such as the Day Offset field can explicitly disable it.
  final bool searchable;

  /// Converts an item into visible text.
  final String Function(T item) itemLabel;

  /// Called after a single item is selected.
  final ValueChanged<T?>? onChanged;

  /// Called after a multi-select selection is confirmed.
  final ValueChanged<List<T>>? onMultiChanged;

  /// Modal title. Defaults to [label] or [hint].
  final String? modalTitle;

  /// Search-field hint. Defaults to the localized Search label.
  final String? searchHint;

  /// Optional key for identifying this field in widget tests or forms.
  final Key? fieldKey;

  /// Optional fill color for an empty host-form field.
  final Color? emptyFillColor;

  /// Optional fill color for a selected host-form field.
  final Color? selectedFillColor;

  /// Optional callback when a disabled field is tapped.
  final VoidCallback? onDisabledTap;

  /// Whether the field is enabled.
  final bool enabled;

  /// Creates a searchable single-select or multi-select dropdown.
  const CustomDropdown({
    required this.items,
    required this.itemLabel,
    this.hint,
    this.label,
    this.value,
    this.selectedValues = const [],
    this.multiSelect = false,
    this.searchable = true,
    this.onChanged,
    this.onMultiChanged,
    this.modalTitle,
    this.searchHint,
    this.fieldKey,
    this.emptyFillColor,
    this.selectedFillColor,
    this.onDisabledTap,
    this.enabled = true,
    super.key,
  });

  String _selectedText(String emptyLabel) {
    if (multiSelect) {
      if (selectedValues.isEmpty) return emptyLabel;
      return selectedValues.map(itemLabel).join(', ');
    }
    return value == null ? emptyLabel : itemLabel(value as T);
  }

  bool get _hasSelection =>
      multiSelect ? selectedValues.isNotEmpty : value != null;

  Future<void> _openPicker(BuildContext context) async {
    if (!enabled) return;
    final l = AppLocalizations.of(context);
    final emptyLabel = hint ?? l.customDropdown_selectOption;
    final size = MediaQuery.sizeOf(context);

    await showDialog<void>(
      context: context,
      barrierColor: AppColors.overlay54,
      builder: (context) => Dialog(
        insetPadding: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        ),
        child: SizedBox(
          key: const ValueKey('custom-dropdown-dialog'),
          width: size.width * .92,
          height: math.max(
            1,
            math.min(
              size.height * .9,
              size.height - MediaQuery.viewInsetsOf(context).bottom - 16,
            ),
          ),
          child: _DropdownPicker<T>(
            title: modalTitle ?? label ?? emptyLabel,
            items: items,
            selectedValue: value,
            selectedValues: selectedValues,
            multiSelect: multiSelect,
            searchable: searchable,
            itemLabel: itemLabel,
            searchHint: searchHint ?? l.customDropdown_search,
            noResultsLabel: l.customDropdown_noResults,
            doneLabel: l.customDropdown_done,
            clearLabel: l.customDropdown_clear,
            selectedLabel: l.customDropdown_selected,
            onSelected: onChanged,
            onMultiSelected: onMultiChanged,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final field = InkWell(
      key: fieldKey,
      onTap: enabled ? () => _openPicker(context) : onDisabledTap,
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      child: InputDecorator(
        isEmpty: !_hasSelection,
        decoration: InputDecoration(
          enabled: enabled,
          fillColor: _hasSelection ? selectedFillColor : emptyFillColor,
          suffixIcon: const Icon(Icons.expand_more),
          hintText: hint,
        ),
        child: Text(
          _selectedText(
            hint ?? AppLocalizations.of(context).customDropdown_selectOption,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.bodyMd.copyWith(
            color: _hasSelection
                ? AppColors.onSurface
                : AppColors.onSurfaceVariant,
          ),
        ),
      ),
    );

    if (label == null) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label!, style: AppTypography.labelLg),
        const SizedBox(height: AppSpacing.xs),
        field,
      ],
    );
  }
}

class _DropdownPicker<T> extends StatefulWidget {
  final String title;
  final List<T> items;
  final T? selectedValue;
  final List<T> selectedValues;
  final bool multiSelect;
  final bool searchable;
  final String Function(T item) itemLabel;
  final String searchHint;
  final String noResultsLabel;
  final String doneLabel;
  final String clearLabel;
  final String selectedLabel;
  final ValueChanged<T?>? onSelected;
  final ValueChanged<List<T>>? onMultiSelected;

  const _DropdownPicker({
    required this.title,
    required this.items,
    required this.selectedValue,
    required this.selectedValues,
    required this.multiSelect,
    required this.searchable,
    required this.itemLabel,
    required this.searchHint,
    required this.noResultsLabel,
    required this.doneLabel,
    required this.clearLabel,
    required this.selectedLabel,
    required this.onSelected,
    required this.onMultiSelected,
  });

  @override
  State<_DropdownPicker<T>> createState() => _DropdownPickerState<T>();
}

class _DropdownPickerState<T> extends State<_DropdownPicker<T>> {
  late final TextEditingController _searchController;
  late Set<T> _selected;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _selected = <T>{...widget.selectedValues};
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<T> get _filteredItems {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return widget.items;
    return widget.items
        .where((item) => widget.itemLabel(item).toLowerCase().contains(query))
        .toList(growable: false);
  }

  void _selectSingle(T item) {
    widget.onSelected?.call(item);
    Navigator.of(context).pop();
  }

  void _toggleMulti(T item) {
    setState(() {
      if (!_selected.add(item)) _selected.remove(item);
    });
  }

  void _clearMulti() => setState(_selected.clear);

  void _confirmMulti() {
    widget.onMultiSelected?.call(
      widget.items.where(_selected.contains).toList(growable: false),
    );
    Navigator.of(context).pop();
  }

  Widget _titleBar(BuildContext context) {
    return Container(
      key: const ValueKey('custom-dropdown-title-bar'),
      width: double.infinity,
      height: 60,
      color: Colors.black,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 56),
            child: Text(
              key: const ValueKey('custom-dropdown-title'),
              widget.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.titleLg.copyWith(color: Colors.white),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              key: const ValueKey('custom-dropdown-close'),
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              onPressed: () => Navigator.of(context).pop(),
              color: Colors.white,
              icon: const Icon(Icons.close),
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchField() => SizedBox(
    height: 48,
    child: TextField(
      key: const ValueKey('custom-dropdown-search'),
      controller: _searchController,
      autofocus: false,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: widget.searchHint,
        hintStyle: AppTypography.bodySm.copyWith(color: AppColors.tertiary),
        prefixIcon: const Icon(Icons.search),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      ),
      onChanged: (_) => setState(() {}),
    ),
  );

  Widget _searchArea() {
    if (!widget.searchable) return const SizedBox.shrink();
    if (!widget.multiSelect) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: _searchField(),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: _searchField()),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            flex: 3,
            child: SizedBox(
              key: const ValueKey('custom-dropdown-selected-values'),
              height: 56,
              child: InputDecorator(
                decoration: InputDecoration(labelText: widget.selectedLabel),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Text(
                    _selected.isEmpty
                        ? '—'
                        : _selected.map(widget.itemLabel).join(', '),
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemList(List<T> filteredItems) {
    if (filteredItems.isEmpty) {
      return Center(child: Text(widget.noResultsLabel));
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      itemCount: filteredItems.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = filteredItems[index];
        final selected = widget.multiSelect
            ? _selected.contains(item)
            : item == widget.selectedValue;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: selected ? AppColors.secondaryHover : Colors.transparent,
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              key: ValueKey<T>(item),
              title: Text(widget.itemLabel(item)),
              selected: selected,
              selectedColor: AppColors.secondary,
              onTap: widget.multiSelect
                  ? () => _toggleMulti(item)
                  : () => _selectSingle(item),
              trailing: widget.multiSelect
                  ? Checkbox(
                      value: selected,
                      onChanged: (_) => _toggleMulti(item),
                    )
                  : selected
                  ? const Icon(Icons.check, color: AppColors.secondary)
                  : null,
            ),
          ),
        );
      },
    );
  }

  Widget _actions() {
    if (!widget.multiSelect) {
      return Padding(
        key: const ValueKey('custom-dropdown-single-actions'),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            key: const ValueKey('custom-dropdown-close-action'),
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.black),
              minimumSize: const Size.fromHeight(60),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(MaterialLocalizations.of(context).closeButtonLabel),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        key: const ValueKey('custom-dropdown-multi-actions'),
        children: [
          Expanded(
            child: OutlinedButton(
              key: const ValueKey('custom-dropdown-clear'),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.black),
                minimumSize: const Size.fromHeight(60),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              ),
              onPressed: _clearMulti,
              child: Text(widget.clearLabel),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: FilledButton(
              key: const ValueKey('custom-dropdown-done'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(60),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              ),
              onPressed: _confirmMulti,
              child: Text(widget.doneLabel),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainerLowest,
      child: SafeArea(
        child: Column(
          children: [
            _titleBar(context),
            _searchArea(),
            Expanded(child: _itemList(_filteredItems)),
            const Divider(height: 1),
            _actions(),
          ],
        ),
      ),
    );
  }
}
