/// Guidelines screen: expandable administrative-procedure topics.
///
/// Body mirrors `mockup_html_screens/guidelines/code.html`: an intro line and
/// four accordion cards. Opening one closes the others and gives the open card
/// a `primary` border, exactly like the mockup's script.
library;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/l10n/generated/app_localizations.dart';
import '../settings_sub_page_modal.dart';

/// One guideline topic: icon, title and its body paragraphs.
class _Topic {
  final IconData icon;
  final String Function(AppLocalizations) title;
  final List<String Function(AppLocalizations)> paragraphs;

  const _Topic({
    required this.icon,
    required this.title,
    required this.paragraphs,
  });
}

/// The four topics, in mockup order.
const List<_Topic> _topics = <_Topic>[
  _Topic(
    icon: Icons.event_note_outlined,
    title: _dailyCauseListTitle,
    paragraphs: <String Function(AppLocalizations)>[
      _dailyCauseListBody1,
      _dailyCauseListBody2,
    ],
  ),
  _Topic(
    icon: Icons.library_books_outlined,
    title: _referencesTitle,
    paragraphs: <String Function(AppLocalizations)>[
      _referencesBody1,
      _referencesBody2,
    ],
  ),
  _Topic(
    icon: Icons.cloud_sync_outlined,
    title: _backupTitle,
    paragraphs: <String Function(AppLocalizations)>[_backupBody1, _backupBody2],
  ),
  _Topic(
    icon: Icons.shield_outlined,
    title: _securityTitle,
    paragraphs: <String Function(AppLocalizations)>[
      _securityBody1,
      _securityBody2,
    ],
  ),
];

String _dailyCauseListTitle(AppLocalizations l) =>
    l.settingsGuidelines_dailyCauseListTitle;
String _dailyCauseListBody1(AppLocalizations l) =>
    l.settingsGuidelines_dailyCauseListBody1;
String _dailyCauseListBody2(AppLocalizations l) =>
    l.settingsGuidelines_dailyCauseListBody2;
String _referencesTitle(AppLocalizations l) =>
    l.settingsGuidelines_referencesTitle;
String _referencesBody1(AppLocalizations l) =>
    l.settingsGuidelines_referencesBody1;
String _referencesBody2(AppLocalizations l) =>
    l.settingsGuidelines_referencesBody2;
String _backupTitle(AppLocalizations l) => l.settingsGuidelines_backupTitle;
String _backupBody1(AppLocalizations l) => l.settingsGuidelines_backupBody1;
String _backupBody2(AppLocalizations l) => l.settingsGuidelines_backupBody2;
String _securityTitle(AppLocalizations l) => l.settingsGuidelines_securityTitle;
String _securityBody1(AppLocalizations l) => l.settingsGuidelines_securityBody1;
String _securityBody2(AppLocalizations l) => l.settingsGuidelines_securityBody2;

/// Guidelines screen.
class GuidelinesScreen extends StatefulWidget {
  const GuidelinesScreen({super.key});

  @override
  State<GuidelinesScreen> createState() => _GuidelinesScreenState();
}

class _GuidelinesScreenState extends State<GuidelinesScreen> {
  /// Index of the open topic; null when all are collapsed.
  int? _openIndex;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SettingsSubPageModal(
      title: l.settingsGuidelines_title,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.edgeMargin,
          AppSpacing.lg,
          AppSpacing.edgeMargin,
          AppSpacing.xl,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: Text(
              l.settingsGuidelines_intro,
              style: AppTypography.bodyMd.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          for (var index = 0; index < _topics.length; index++) ...[
            if (index > 0) const SizedBox(height: AppSpacing.sm),
            _TopicCard(
              topic: _topics[index],
              open: _openIndex == index,
              // Mockup behaviour: one topic open at a time, tapping it again
              // collapses it.
              onToggle: () => setState(
                () => _openIndex = _openIndex == index ? null : index,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One accordion card: icon chip + title header, body revealed when open.
class _TopicCard extends StatelessWidget {
  final _Topic topic;
  final bool open;
  final VoidCallback onToggle;

  const _TopicCard({
    required this.topic,
    required this.open,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Material(
      color: AppColors.surfaceContainerLowest,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        // The open card switches to the mockup's `border-primary`.
        borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
        side: BorderSide(
          color: open ? AppColors.primary : AppColors.outlineVariant,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surfaceContainer,
                    ),
                    child: Icon(
                      topic.icon,
                      size: 20,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.gutter),
                  Expanded(
                    child: Text(
                      topic.title(l),
                      style: AppTypography.titleMd.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.expand_more,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (open)
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.surfaceContainerLow,
                border: Border(
                  top: BorderSide(color: AppColors.outlineVariant),
                ),
              ),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < topic.paragraphs.length; i++) ...[
                    if (i > 0) const SizedBox(height: AppSpacing.sm),
                    Text(
                      topic.paragraphs[i](l),
                      style: AppTypography.bodyMd.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
