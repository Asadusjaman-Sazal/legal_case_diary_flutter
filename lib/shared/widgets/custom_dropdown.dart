/// Searchable single-select and multi-select dropdown.
///
/// The widget owns only transient picker state. Selected values remain owned by
/// the host screen through [value], [selectedValues], and the callbacks.
library;

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';
import '../../core/l10n/generated/app_localizations.dart';

/// A generic dropdown that opens a searchable modal list.
class CustomDropdown<T> extends StatelessWidget {
  /// Optional field label displayed above the control.
  final String? label;

  /// Placeholder displayed when no value is selected.
  ///
  /// When omitted, the current locale's generic selection label is used.
  final String? hint;

  /// Items available for selection.
  final List<T> items;

  /// Current single-select value.
  final T? value;

  /// Current multi-select values.
  final List<T> selectedValues;

  /// Whether multiple items may be selected before confirming.
  final bool multiSelect;

  /// Whether the modal includes a search field.
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
    this.searchable = false,
    this.onChanged,
    this.onMultiChanged,
    this.modalTitle,
    this.searchHint,
    this.fieldKey,
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

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DropdownPicker<T>(
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
        onSelected: onChanged,
        onMultiSelected: onMultiChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final field = InkWell(
      key: fieldKey,
      onTap: enabled ? () => _openPicker(context) : null,
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      child: InputDecorator(
        isEmpty: !_hasSelection,
        decoration: InputDecoration(
          enabled: enabled,
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
        .toList();
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

  void _confirmMulti() {
    widget.onMultiSelected?.call(
      widget.items.where(_selected.contains).toList(growable: false),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _filteredItems;
    return SafeArea(
      child: Material(
        color: AppColors.surfaceContainerLowest,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSpacing.sheetRadius),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(widget.title, style: AppTypography.titleLg),
                      ),
                      IconButton(
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).closeButtonTooltip,
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                if (widget.searchable)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      0,
                      AppSpacing.md,
                      AppSpacing.sm,
                    ),
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: widget.searchHint,
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                          tooltip: MaterialLocalizations.of(
                            context,
                          ).deleteButtonTooltip,
                          onPressed: () => setState(_searchController.clear),
                          icon: const Icon(Icons.clear),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                Flexible(
                  child: filteredItems.isEmpty
                      ? Center(child: Text(widget.noResultsLabel))
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: filteredItems.length,
                          itemBuilder: (context, index) {
                            final item = filteredItems[index];
                            final selected = widget.multiSelect
                                ? _selected.contains(item)
                                : item == widget.selectedValue;
                            return ListTile(
                              key: ValueKey<T>(item),
                              title: Text(widget.itemLabel(item)),
                              selected: selected,
                              selectedTileColor: AppColors.secondaryHover,
                              onTap: widget.multiSelect
                                  ? () => _toggleMulti(item)
                                  : () => _selectSingle(item),
                              trailing: widget.multiSelect
                                  ? Checkbox(
                                      value: selected,
                                      onChanged: (_) => _toggleMulti(item),
                                    )
                                  : selected
                                  ? const Icon(
                                      Icons.check,
                                      color: AppColors.secondary,
                                    )
                                  : null,
                            );
                          },
                        ),
                ),
                if (widget.multiSelect)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _confirmMulti,
                        child: Text(widget.doneLabel),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
