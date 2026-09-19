/// Hosts the extended ("table") case view: the header row, the horizontal
/// scroll that keeps the header aligned with the rows, and the column widths.
///
/// It also holds [CaseTableGroup], the pinned and foldable court group both case
/// list views draw a court with — the extended view over its rows, the compact
/// card list over its cards.
///
/// Widths are the one piece of table state the user owns: they are read from
/// the stored per-user settings when the screen opens, updated live while a
/// header rule is dragged, and written back when the drag ends. A screen only
/// supplies the rows, so no screen has to know how a column is sized.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../shared/widgets/case_table_row.dart';
import 'case_list_view_mode.dart';

/// Height of a pinned court heading in either case list view.
///
/// One line of the screen's group title plus the heading's own vertical padding,
/// which is the box a court heading already occupies in the list, scaled with
/// the user's text size so a larger label is never clipped by the band.
double caseTableGroupHeaderHeight(BuildContext context) {
  final style =
      Theme.of(context).textTheme.titleMedium ?? AppTypography.titleMd;
  final fontSize = style.fontSize ?? 16;
  final lineHeight = fontSize * (style.height ?? 1.5);
  return MediaQuery.textScalerOf(context).scale(lineHeight) + AppSpacing.sm * 2;
}

/// One court's cases, under a heading that stays at the top of the list for as
/// long as that court's cases are on screen.
///
/// Both case list views use it: the extended table passes its rows, the compact
/// list passes its cards, and a grouping screen gets the same pinned, foldable
/// heading either way. The screen hands it whatever widgets that view draws and
/// the heading behaviour is identical.
///
/// The heading and its cases are wrapped in a single [SliverMainAxisGroup], which
/// is what scopes the pinning to the court: the heading holds the top of the
/// list while its own cases are being read, then travels up and out as the next
/// court's heading arrives in its place. (Pinned headers placed side by side in
/// a scroll view pile up at the top instead — they would all stay on screen at
/// once — so the group is what makes the handover work.)
///
/// Tapping the heading folds the court away and tapping it again brings it back,
/// so a long day can be read as a list of courts and opened one at a time. A
/// court starts expanded ([initiallyCollapsed]) — the screen is handed the
/// court's stored fold state and [onToggle] writes the new one back, so both
/// views fold together and the choice survives a restart — and a folded court's
/// band carries a chevron pointing down. An expanded court shows no chevron at
/// all, since the cases below it are already on screen.
///
/// The band paints the screen background across the list's full width, which
/// also keeps the cases sliding underneath it hidden while it is pinned.
class CaseTableGroup extends StatefulWidget {
  /// The screen's own court heading (icon, name, hearing count), already laid
  /// out, including its own vertical padding.
  final Widget heading;

  /// Height of [heading]; use [caseTableGroupHeaderHeight].
  final double headingHeight;

  /// The court's cases, in the screen's order: cards in the compact list, table
  /// rows in the extended view.
  final List<Widget> rows;

  /// Whether the court starts with its cases hidden.
  ///
  /// Defaults to `false`: the extended view opens with every court expanded, so
  /// the rows are there to read straight away. A grouped screen passes the
  /// court's stored fold state here, which is what makes the user's choice
  /// survive leaving and re-opening the screen.
  final bool initiallyCollapsed;

  /// Called with the court's new fold state after a heading tap, so the host
  /// can persist the choice. A screen that does not store the state simply
  /// omits it and the group stays in memory for the visit.
  final void Function(bool collapsed)? onToggle;

  /// Creates one court's section of the extended view.
  const CaseTableGroup({
    required this.heading,
    required this.headingHeight,
    required this.rows,
    this.initiallyCollapsed = false,
    this.onToggle,
    super.key,
  });

  @override
  State<CaseTableGroup> createState() => _CaseTableGroupState();
}

class _CaseTableGroupState extends State<CaseTableGroup> {
  /// The one piece of view state this group owns. It lives here rather than in
  /// the host screen so a court's rows are simply unmounted while it is folded,
  /// and so each group answers its own heading's tap.
  late bool _collapsed = widget.initiallyCollapsed;

  void _toggle() {
    final collapsed = !_collapsed;
    setState(() => _collapsed = collapsed);
    widget.onToggle?.call(collapsed);
  }

  @override
  Widget build(BuildContext context) => SliverMainAxisGroup(
    slivers: [
      SliverPersistentHeader(
        pinned: true,
        delegate: _GroupHeadingDelegate(
          height: widget.headingHeight,
          child: _CaseTableHeading(
            height: widget.headingHeight,
            collapsed: _collapsed,
            onTap: _toggle,
            child: widget.heading,
          ),
        ),
      ),
      // A folded court contributes its heading only, so the next court's
      // heading comes straight up to the top behind it.
      if (!_collapsed)
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          sliver: SliverList.builder(
            itemCount: widget.rows.length,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: widget.rows[index],
            ),
          ),
        ),
    ],
  );
}

/// The tappable band around one court's heading, carrying the down chevron that
/// says the court's cases are hidden under it.
///
/// The whole band is the tap target, not just the arrow, because the heading is
/// the widest thing on the line; the band's own background is what hides the
/// cases scrolling underneath it while it is pinned.
class _CaseTableHeading extends StatelessWidget {
  final double height;
  final bool collapsed;
  final VoidCallback onTap;

  /// The heading the host screen built, inset by the band's own padding.
  final Widget child;

  const _CaseTableHeading({
    required this.height,
    required this.collapsed,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: ClipRect(
      child: Material(
        color: AppColors.background,
        child: InkWell(
          key: const ValueKey('case-table-group-toggle'),
          onTap: onTap,
          // The heading's own vertical padding is already part of `height`, so
          // only the horizontal gutter is added here — as is the arrow, which
          // sits at the end of the band where the hearing count already is.
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                Expanded(child: child),
                // Only a hidden court says so: the chevron points down under a
                // folded heading, and an expanded one draws nothing, because
                // its rows are already on screen.
                if (collapsed) ...[
                  const SizedBox(width: AppSpacing.xs),
                  const Icon(
                    Icons.keyboard_arrow_down,
                    key: ValueKey('case-table-group-collapsed'),
                    size: 20,
                    color: AppColors.onSurfaceVariant,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Sizes the pinned band the heading is drawn in.
class _GroupHeadingDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;

  const _GroupHeadingDelegate({required this.height, required this.child});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => SizedBox(
    height: height,
    // The band is laid out to exactly this height; clipping keeps an unusually
    // large text scale from painting outside it.
    child: ClipRect(child: child),
  );

  @override
  bool shouldRebuild(_GroupHeadingDelegate oldDelegate) =>
      oldDelegate.height != height || oldDelegate.child != child;
}

/// The extended case view: one header row over the screen's own rows.
class CaseTableView extends ConsumerStatefulWidget {
  /// The columns this screen shows, in render order. Defaults to every column;
  /// a screen that shows the court as a group heading passes a list without
  /// [CaseTableColumn.court].
  final List<CaseTableColumn> columns;

  /// Label of the date column, named by the host screen ("Next Date", "Previous
  /// Date" or "Disposed").
  final String dateLabel;

  /// Builds the vertically scrolling body — court groups, date headers and rows
  /// — at the table's exact width. The rows must be built with the widths it is
  /// handed so their columns line up with the header.
  final Widget Function(
    BuildContext context,
    Map<CaseTableColumn, double> widths,
  )
  builder;

  /// Creates the extended-view host.
  const CaseTableView({
    this.columns = caseTableColumnOrder,
    required this.dateLabel,
    required this.builder,
    super.key,
  });

  @override
  ConsumerState<CaseTableView> createState() => _CaseTableViewState();
}

class _CaseTableViewState extends ConsumerState<CaseTableView> {
  /// The widths in use. Seeded with the defaults so the first frame is already
  /// a table; replaced by the stored widths as soon as they load.
  Map<CaseTableColumn, double> _widths = resolveCaseTableWidths(const {});

  /// Set once the user drags a rule. From then on the live widths win, so a
  /// slow settings read can never fight the drag in progress.
  bool _resized = false;

  @override
  void initState() {
    super.initState();
    _loadStoredWidths();
  }

  /// Opens the table at the sizes the user last left it in; an install that has
  /// never dragged a rule keeps the built-in defaults.
  Future<void> _loadStoredWidths() async {
    try {
      final repo = await ref.read(settingsRepositoryProvider.future);
      final stored = (await repo.getSettings()).caseTableColumnWidths;
      if (!mounted || _resized) return;
      setState(() => _widths = resolveCaseTableWidths(stored));
    } catch (_) {
      // A failed read leaves the defaults in place rather than breaking the
      // list: the column sizes are a convenience, not data.
    }
  }

  /// Applies one resize delta to [column], clamped to the column's range.
  void _resize(CaseTableColumn column, double delta) {
    if (delta == 0) return;
    final current = _widths[column]!;
    final next = (current + delta).clamp(
      caseTableMinColumnWidth(column),
      caseTableMaxColumnWidth,
    );
    if (next == current) return;
    setState(() {
      _resized = true;
      _widths = {..._widths, column: next};
    });
  }

  /// Stores the widths the drag settled on.
  Future<void> _persist() =>
      setCaseTableColumnWidths(ref, caseTableStoredWidths(_widths));

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final minimum = caseTableMinimumWidth(widget.columns, _widths);
        final width = minimum > constraints.maxWidth
            ? minimum
            : constraints.maxWidth;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: width,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    0,
                  ),
                  child: CaseTableHeader(
                    widths: _widths,
                    columns: widget.columns,
                    dateLabel: widget.dateLabel,
                    onResizeDelta: _resize,
                    onResizeEnd: _persist,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Expanded(child: widget.builder(context, _widths)),
              ],
            ),
          ),
        );
      },
    );
  }
}
