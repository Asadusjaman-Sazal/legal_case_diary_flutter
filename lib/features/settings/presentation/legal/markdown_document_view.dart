/// Draws a parsed Markdown document with the app's own typography.
///
/// The parser lives in `markdown_document.dart`; this file only paints what it
/// produces. Styles come from the design tokens rather than the Markdown
/// defaults, and Bengali text uses the Tiro Bangla styles the rest of the app
/// uses for Bengali, so a Bengali legal document reads as well as any other
/// screen in the app.
library;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import 'markdown_document.dart';

/// Renders [markdown] as a scrollable, styled document.
class MarkdownDocumentView extends StatelessWidget {
  /// The raw Markdown source.
  final String markdown;

  const MarkdownDocumentView({super.key, required this.markdown});

  @override
  Widget build(BuildContext context) {
    final bengali = Localizations.localeOf(context).languageCode == 'bn';
    final blocks = parseMarkdown(markdown);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.edgeMargin,
        AppSpacing.md,
        AppSpacing.edgeMargin,
        AppSpacing.xl,
      ),
      itemCount: blocks.length,
      itemBuilder: (context, index) =>
          _block(blocks[index], bengali: bengali, first: index == 0),
    );
  }

  Widget _block(
    MarkdownBlock block, {
    required bool bengali,
    required bool first,
  }) {
    final base = _body(bengali);
    switch (block) {
      case MarkdownHeading(:final level, :final spans):
        return Padding(
          padding: EdgeInsets.only(
            top: first ? 0 : AppSpacing.lg,
            bottom: AppSpacing.sm,
          ),
          child: Text.rich(
            TextSpan(children: _spans(spans, _heading(level, bengali))),
          ),
        );
      case MarkdownParagraph(:final spans):
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Text.rich(
            TextSpan(children: _spans(spans, base)),
            textAlign: TextAlign.start,
          ),
        );
      case MarkdownBullets(:final items):
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // A bullet that aligns with the first line of its text.
                      Padding(
                        padding: EdgeInsets.only(
                          top: (base.fontSize ?? 14) * 0.42,
                          right: AppSpacing.sm,
                        ),
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            color: AppColors.onSurfaceVariant,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text.rich(TextSpan(children: _spans(item, base))),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      case MarkdownQuote(:final paragraphs):
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: const BoxDecoration(
            color: AppColors.surfaceContainerLow,
            border: Border(
              left: BorderSide(color: AppColors.secondary, width: 3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final paragraph in paragraphs)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text.rich(
                    TextSpan(children: _spans(paragraph, base)),
                  ),
                ),
            ],
          ),
        );
      case MarkdownRule():
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Divider(height: 1, color: AppColors.outlineVariant),
        );
      case MarkdownTable(:final header, :final rows):
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: _table(header, rows, base),
        );
    }
  }

  Widget _table(
    List<List<MarkdownSpan>> header,
    List<List<List<MarkdownSpan>>> rows,
    TextStyle base,
  ) {
    final headerStyle = base.copyWith(
      color: AppColors.onSurface,
      fontWeight: FontWeight.w700,
    );
    return Table(
      border: TableBorder(
        horizontalInside: BorderSide(color: AppColors.outlineVariant),
        top: BorderSide(color: AppColors.outlineVariant),
        bottom: BorderSide(color: AppColors.outlineVariant),
      ),
      defaultColumnWidth: const FlexColumnWidth(),
      children: [
        if (header.isNotEmpty)
          TableRow(
            decoration: const BoxDecoration(
              color: AppColors.surfaceContainerLow,
            ),
            children: [
              for (final cell in header)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Text.rich(
                    TextSpan(children: _spans(cell, headerStyle)),
                  ),
                ),
            ],
          ),
        for (final row in rows)
          TableRow(
            children: [
              for (final cell in row)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Text.rich(TextSpan(children: _spans(cell, base))),
                ),
            ],
          ),
      ],
    );
  }

  /// Body text: the Bengali style under `bn`, the Latin one otherwise.
  TextStyle _body(bool bengali) => bengali
      ? AppTypography.bengaliBodyMd.copyWith(color: AppColors.onSurfaceVariant)
      : AppTypography.bodyMd.copyWith(
          color: AppColors.onSurfaceVariant,
          height: 1.6,
        );

  TextStyle _heading(int level, bool bengali) {
    if (bengali) {
      return switch (level) {
        1 => AppTypography.bengaliTitleMd.copyWith(
            fontSize: 22,
            height: 1.4,
            color: AppColors.primary,
          ),
        2 => AppTypography.bengaliTitleMd.copyWith(
            fontSize: 18,
            color: AppColors.primary,
          ),
        _ => AppTypography.bengaliTitleMd.copyWith(color: AppColors.primary),
      };
    }
    return switch (level) {
      1 => AppTypography.headlineMd.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
        ),
      2 => AppTypography.titleLg.copyWith(color: AppColors.primary),
      _ => AppTypography.titleMd.copyWith(color: AppColors.primary),
    };
  }

  List<TextSpan> _spans(List<MarkdownSpan> spans, TextStyle base) => [
    for (final span in spans)
      TextSpan(
        text: span.text,
        style: span.code
            ? base.copyWith(
                fontFamily: 'monospace',
                fontSize: (base.fontSize ?? 14) * 0.92,
                color: AppColors.secondary,
              )
            : base.copyWith(
                fontWeight: span.bold ? FontWeight.w700 : base.fontWeight,
                color: span.bold ? AppColors.onSurface : base.color,
                fontStyle: span.italic ? FontStyle.italic : base.fontStyle,
              ),
      ),
  ];
}
