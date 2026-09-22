/// Guidelines & FAQs screen: how the app works, plus the questions users ask.
///
/// Two sections in one scroll: the four `Guidelines` cards that explain how a
/// part of the app behaves, and the `FAQs` cards grouped by topic. Every card is
/// an accordion — one open at a time, tapping the open card closes it again,
/// exactly the interaction `mockup_html_screens/guidelines/code.html` defines.
///
/// The copy lives in the ARB files. It covers the shipped offline app (its
/// 50-case free plan, encrypted local backups and the monthly reminder) plus the
/// product decision that every user creates an account when the app is first
/// opened — the sole case where the copy describes a flow the offline Part A
/// build does not carry yet, because it is what the free plan and the later
/// upgrade to cloud backup both rest on. Features that arrive with the online
/// version are named as such rather than documented as if they were here.
library;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/l10n/generated/app_localizations.dart';
import '../settings_controls.dart';
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

/// One question and its answer.
class _FaqEntry {
  final String Function(AppLocalizations) question;
  final String Function(AppLocalizations) answer;

  const _FaqEntry({required this.question, required this.answer});
}

/// One FAQ topic card: icon, title and the questions it holds.
class _FaqCategory {
  final IconData icon;
  final String Function(AppLocalizations) title;
  final List<_FaqEntry> entries;

  const _FaqCategory({
    required this.icon,
    required this.title,
    required this.entries,
  });
}

/// The guideline topics: the account first, then the six case screens in the
/// drawer's canonical order (Daily Cause List follows Active Cases there, but it
/// is the mockup's own first topic and is kept at the head of the screen
/// cards), then the three reference topics.
const List<_Topic> _topics = <_Topic>[
  _Topic(
    icon: Icons.person_outline,
    title: _accountTitle,
    paragraphs: <String Function(AppLocalizations)>[
      _accountBody1,
      _accountBody2,
    ],
  ),
  _Topic(
    icon: Icons.event_note_outlined,
    title: _dailyCauseListTitle,
    paragraphs: <String Function(AppLocalizations)>[
      _dailyCauseListBody1,
      _dailyCauseListBody2,
    ],
  ),
  _Topic(
    icon: Icons.list_alt_outlined,
    title: _allCasesTitle,
    paragraphs: <String Function(AppLocalizations)>[_allCasesBody1],
  ),
  _Topic(
    icon: Icons.work_outline,
    title: _activeCasesTitle,
    paragraphs: <String Function(AppLocalizations)>[_activeCasesBody1],
  ),
  _Topic(
    icon: Icons.error_outline,
    title: _overdueDatesTitle,
    paragraphs: <String Function(AppLocalizations)>[_overdueDatesBody1],
  ),
  _Topic(
    icon: Icons.event_outlined,
    title: _upcomingCasesTitle,
    paragraphs: <String Function(AppLocalizations)>[_upcomingCasesBody1],
  ),
  _Topic(
    icon: Icons.gavel_outlined,
    title: _disposedCasesTitle,
    paragraphs: <String Function(AppLocalizations)>[_disposedCasesBody1],
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

String _accountTitle(AppLocalizations l) => l.settingsGuidelines_accountTitle;
String _accountBody1(AppLocalizations l) => l.settingsGuidelines_accountBody1;
String _accountBody2(AppLocalizations l) => l.settingsGuidelines_accountBody2;
String _allCasesTitle(AppLocalizations l) => l.settingsGuidelines_allCasesTitle;
String _allCasesBody1(AppLocalizations l) => l.settingsGuidelines_allCasesBody1;
String _activeCasesTitle(AppLocalizations l) =>
    l.settingsGuidelines_activeCasesTitle;
String _activeCasesBody1(AppLocalizations l) =>
    l.settingsGuidelines_activeCasesBody1;
String _overdueDatesTitle(AppLocalizations l) =>
    l.settingsGuidelines_overdueDatesTitle;
String _overdueDatesBody1(AppLocalizations l) =>
    l.settingsGuidelines_overdueDatesBody1;
String _upcomingCasesTitle(AppLocalizations l) =>
    l.settingsGuidelines_upcomingCasesTitle;
String _upcomingCasesBody1(AppLocalizations l) =>
    l.settingsGuidelines_upcomingCasesBody1;
String _disposedCasesTitle(AppLocalizations l) =>
    l.settingsGuidelines_disposedCasesTitle;
String _disposedCasesBody1(AppLocalizations l) =>
    l.settingsGuidelines_disposedCasesBody1;
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

/// The FAQ groups, in the order a new user meets them: getting started, the
/// everyday questions, then data safety and support.
const List<_FaqCategory> _faqCategories = <_FaqCategory>[
  _FaqCategory(
    icon: Icons.play_circle_outline,
    title: _gettingStartedTitle,
    entries: <_FaqEntry>[
      _FaqEntry(
        question: _gettingStartedQ1,
        answer: _gettingStartedA1,
      ),
      _FaqEntry(question: _gettingStartedQ2, answer: _gettingStartedA2),
      _FaqEntry(question: _gettingStartedQ3, answer: _gettingStartedA3),
      _FaqEntry(question: _gettingStartedQ4, answer: _gettingStartedA4),
      _FaqEntry(question: _gettingStartedQ5, answer: _gettingStartedA5),
      _FaqEntry(question: _gettingStartedQ6, answer: _gettingStartedA6),
      _FaqEntry(question: _gettingStartedQ7, answer: _gettingStartedA7),
      _FaqEntry(question: _gettingStartedQ8, answer: _gettingStartedA8),
      _FaqEntry(question: _gettingStartedQ9, answer: _gettingStartedA9),
    ],
  ),
  _FaqCategory(
    icon: Icons.search,
    title: _findingCasesTitle,
    entries: <_FaqEntry>[
      _FaqEntry(question: _findingCasesQ1, answer: _findingCasesA1),
      _FaqEntry(question: _findingCasesQ2, answer: _findingCasesA2),
      _FaqEntry(question: _findingCasesQ3, answer: _findingCasesA3),
      _FaqEntry(question: _findingCasesQ4, answer: _findingCasesA4),
    ],
  ),
  _FaqCategory(
    icon: Icons.description_outlined,
    title: _notesAndPrintingTitle,
    entries: <_FaqEntry>[
      _FaqEntry(question: _notesAndPrintingQ1, answer: _notesAndPrintingA1),
      _FaqEntry(question: _notesAndPrintingQ2, answer: _notesAndPrintingA2),
      _FaqEntry(question: _notesAndPrintingQ3, answer: _notesAndPrintingA3),
    ],
  ),
  _FaqCategory(
    icon: Icons.backup_outlined,
    title: _backupAndRestoreTitle,
    entries: <_FaqEntry>[
      _FaqEntry(question: _backupAndRestoreQ1, answer: _backupAndRestoreA1),
      _FaqEntry(question: _backupAndRestoreQ2, answer: _backupAndRestoreA2),
      _FaqEntry(question: _backupAndRestoreQ3, answer: _backupAndRestoreA3),
      _FaqEntry(question: _backupAndRestoreQ4, answer: _backupAndRestoreA4),
      _FaqEntry(question: _backupAndRestoreQ5, answer: _backupAndRestoreA5),
      _FaqEntry(question: _backupAndRestoreQ6, answer: _backupAndRestoreA6),
      _FaqEntry(question: _backupAndRestoreQ7, answer: _backupAndRestoreA7),
    ],
  ),
  _FaqCategory(
    icon: Icons.notifications_none,
    title: _notificationsFaqTitle,
    entries: <_FaqEntry>[
      _FaqEntry(question: _notificationsQ1, answer: _notificationsA1),
      _FaqEntry(question: _notificationsQ2, answer: _notificationsA2),
    ],
  ),
  _FaqCategory(
    icon: Icons.translate,
    title: _languageAndDisplayTitle,
    entries: <_FaqEntry>[
      _FaqEntry(question: _languageAndDisplayQ1, answer: _languageAndDisplayA1),
    ],
  ),
  _FaqCategory(
    icon: Icons.workspace_premium_outlined,
    title: _freePlanAndPremiumTitle,
    entries: <_FaqEntry>[
      _FaqEntry(question: _freePlanAndPremiumQ1, answer: _freePlanAndPremiumA1),
      _FaqEntry(question: _freePlanAndPremiumQ2, answer: _freePlanAndPremiumA2),
      _FaqEntry(question: _freePlanAndPremiumQ3, answer: _freePlanAndPremiumA3),
      _FaqEntry(question: _freePlanAndPremiumQ4, answer: _freePlanAndPremiumA4),
      _FaqEntry(question: _freePlanAndPremiumQ5, answer: _freePlanAndPremiumA5),
    ],
  ),
  _FaqCategory(
    icon: Icons.account_balance_outlined,
    title: _courtsAndCustomisationTitle,
    entries: <_FaqEntry>[
      _FaqEntry(
        question: _courtsAndCustomisationQ1,
        answer: _courtsAndCustomisationA1,
      ),
      _FaqEntry(
        question: _courtsAndCustomisationQ2,
        answer: _courtsAndCustomisationA2,
      ),
      _FaqEntry(
        question: _courtsAndCustomisationQ3,
        answer: _courtsAndCustomisationA3,
      ),
      _FaqEntry(
        question: _courtsAndCustomisationQ4,
        answer: _courtsAndCustomisationA4,
      ),
    ],
  ),
  _FaqCategory(
    icon: Icons.privacy_tip_outlined,
    title: _dataAndSupportTitle,
    entries: <_FaqEntry>[
      _FaqEntry(question: _dataAndSupportQ1, answer: _dataAndSupportA1),
      _FaqEntry(question: _dataAndSupportQ2, answer: _dataAndSupportA2),
      _FaqEntry(question: _dataAndSupportQ3, answer: _dataAndSupportA3),
    ],
  ),
];

String _gettingStartedTitle(AppLocalizations l) =>
    l.settingsGuidelines_faqCatGettingStarted;
String _gettingStartedQ1(AppLocalizations l) =>
    l.settingsGuidelines_faqCatGettingStartedQ1;
String _gettingStartedA1(AppLocalizations l) =>
    l.settingsGuidelines_faqCatGettingStartedA1;
String _gettingStartedQ2(AppLocalizations l) =>
    l.settingsGuidelines_faqCatGettingStartedQ2;
String _gettingStartedA2(AppLocalizations l) =>
    l.settingsGuidelines_faqCatGettingStartedA2;
String _gettingStartedQ3(AppLocalizations l) =>
    l.settingsGuidelines_faqCatGettingStartedQ3;
String _gettingStartedA3(AppLocalizations l) =>
    l.settingsGuidelines_faqCatGettingStartedA3;
String _gettingStartedQ4(AppLocalizations l) =>
    l.settingsGuidelines_faqCatGettingStartedQ4;
String _gettingStartedA4(AppLocalizations l) =>
    l.settingsGuidelines_faqCatGettingStartedA4;
String _gettingStartedQ5(AppLocalizations l) =>
    l.settingsGuidelines_faqCatGettingStartedQ5;
String _gettingStartedA5(AppLocalizations l) =>
    l.settingsGuidelines_faqCatGettingStartedA5;
String _gettingStartedQ6(AppLocalizations l) =>
    l.settingsGuidelines_faqCatGettingStartedQ6;
String _gettingStartedA6(AppLocalizations l) =>
    l.settingsGuidelines_faqCatGettingStartedA6;
String _gettingStartedQ7(AppLocalizations l) =>
    l.settingsGuidelines_faqCatGettingStartedQ7;
String _gettingStartedA7(AppLocalizations l) =>
    l.settingsGuidelines_faqCatGettingStartedA7;
String _gettingStartedQ8(AppLocalizations l) =>
    l.settingsGuidelines_faqCatGettingStartedQ8;
String _gettingStartedA8(AppLocalizations l) =>
    l.settingsGuidelines_faqCatGettingStartedA8;
String _gettingStartedQ9(AppLocalizations l) =>
    l.settingsGuidelines_faqCatGettingStartedQ9;
String _gettingStartedA9(AppLocalizations l) =>
    l.settingsGuidelines_faqCatGettingStartedA9;

String _findingCasesTitle(AppLocalizations l) =>
    l.settingsGuidelines_faqCatFindingCases;
String _findingCasesQ1(AppLocalizations l) =>
    l.settingsGuidelines_faqCatFindingCasesQ1;
String _findingCasesA1(AppLocalizations l) =>
    l.settingsGuidelines_faqCatFindingCasesA1;
String _findingCasesQ2(AppLocalizations l) =>
    l.settingsGuidelines_faqCatFindingCasesQ2;
String _findingCasesA2(AppLocalizations l) =>
    l.settingsGuidelines_faqCatFindingCasesA2;
String _findingCasesQ3(AppLocalizations l) =>
    l.settingsGuidelines_faqCatFindingCasesQ3;
String _findingCasesA3(AppLocalizations l) =>
    l.settingsGuidelines_faqCatFindingCasesA3;
String _findingCasesQ4(AppLocalizations l) =>
    l.settingsGuidelines_faqCatFindingCasesQ4;
String _findingCasesA4(AppLocalizations l) =>
    l.settingsGuidelines_faqCatFindingCasesA4;

String _notesAndPrintingTitle(AppLocalizations l) =>
    l.settingsGuidelines_faqCatNotesAndPrinting;
String _notesAndPrintingQ1(AppLocalizations l) =>
    l.settingsGuidelines_faqCatNotesAndPrintingQ1;
String _notesAndPrintingA1(AppLocalizations l) =>
    l.settingsGuidelines_faqCatNotesAndPrintingA1;
String _notesAndPrintingQ2(AppLocalizations l) =>
    l.settingsGuidelines_faqCatNotesAndPrintingQ2;
String _notesAndPrintingA2(AppLocalizations l) =>
    l.settingsGuidelines_faqCatNotesAndPrintingA2;
String _notesAndPrintingQ3(AppLocalizations l) =>
    l.settingsGuidelines_faqCatNotesAndPrintingQ3;
String _notesAndPrintingA3(AppLocalizations l) =>
    l.settingsGuidelines_faqCatNotesAndPrintingA3;

String _backupAndRestoreTitle(AppLocalizations l) =>
    l.settingsGuidelines_faqCatBackupAndRestore;
String _backupAndRestoreQ1(AppLocalizations l) =>
    l.settingsGuidelines_faqCatBackupAndRestoreQ1;
String _backupAndRestoreA1(AppLocalizations l) =>
    l.settingsGuidelines_faqCatBackupAndRestoreA1;
String _backupAndRestoreQ2(AppLocalizations l) =>
    l.settingsGuidelines_faqCatBackupAndRestoreQ2;
String _backupAndRestoreA2(AppLocalizations l) =>
    l.settingsGuidelines_faqCatBackupAndRestoreA2;
String _backupAndRestoreQ3(AppLocalizations l) =>
    l.settingsGuidelines_faqCatBackupAndRestoreQ3;
String _backupAndRestoreA3(AppLocalizations l) =>
    l.settingsGuidelines_faqCatBackupAndRestoreA3;
String _backupAndRestoreQ4(AppLocalizations l) =>
    l.settingsGuidelines_faqCatBackupAndRestoreQ4;
String _backupAndRestoreA4(AppLocalizations l) =>
    l.settingsGuidelines_faqCatBackupAndRestoreA4;
String _backupAndRestoreQ5(AppLocalizations l) =>
    l.settingsGuidelines_faqCatBackupAndRestoreQ5;
String _backupAndRestoreA5(AppLocalizations l) =>
    l.settingsGuidelines_faqCatBackupAndRestoreA5;
String _backupAndRestoreQ6(AppLocalizations l) =>
    l.settingsGuidelines_faqCatBackupAndRestoreQ6;
String _backupAndRestoreA6(AppLocalizations l) =>
    l.settingsGuidelines_faqCatBackupAndRestoreA6;
String _backupAndRestoreQ7(AppLocalizations l) =>
    l.settingsGuidelines_faqCatBackupAndRestoreQ7;
String _backupAndRestoreA7(AppLocalizations l) =>
    l.settingsGuidelines_faqCatBackupAndRestoreA7;

String _notificationsFaqTitle(AppLocalizations l) =>
    l.settingsGuidelines_faqCatNotifications;
String _notificationsQ1(AppLocalizations l) =>
    l.settingsGuidelines_faqCatNotificationsQ1;
String _notificationsA1(AppLocalizations l) =>
    l.settingsGuidelines_faqCatNotificationsA1;
String _notificationsQ2(AppLocalizations l) =>
    l.settingsGuidelines_faqCatNotificationsQ2;
String _notificationsA2(AppLocalizations l) =>
    l.settingsGuidelines_faqCatNotificationsA2;

String _languageAndDisplayTitle(AppLocalizations l) =>
    l.settingsGuidelines_faqCatLanguageAndDisplay;
String _languageAndDisplayQ1(AppLocalizations l) =>
    l.settingsGuidelines_faqCatLanguageAndDisplayQ1;
String _languageAndDisplayA1(AppLocalizations l) =>
    l.settingsGuidelines_faqCatLanguageAndDisplayA1;

String _freePlanAndPremiumTitle(AppLocalizations l) =>
    l.settingsGuidelines_faqCatFreePlanAndPremium;
String _freePlanAndPremiumQ1(AppLocalizations l) =>
    l.settingsGuidelines_faqCatFreePlanAndPremiumQ1;
String _freePlanAndPremiumA1(AppLocalizations l) =>
    l.settingsGuidelines_faqCatFreePlanAndPremiumA1;
String _freePlanAndPremiumQ2(AppLocalizations l) =>
    l.settingsGuidelines_faqCatFreePlanAndPremiumQ2;
String _freePlanAndPremiumA2(AppLocalizations l) =>
    l.settingsGuidelines_faqCatFreePlanAndPremiumA2;
String _freePlanAndPremiumQ3(AppLocalizations l) =>
    l.settingsGuidelines_faqCatFreePlanAndPremiumQ3;
String _freePlanAndPremiumA3(AppLocalizations l) =>
    l.settingsGuidelines_faqCatFreePlanAndPremiumA3;
String _freePlanAndPremiumQ4(AppLocalizations l) =>
    l.settingsGuidelines_faqCatFreePlanAndPremiumQ4;
String _freePlanAndPremiumA4(AppLocalizations l) =>
    l.settingsGuidelines_faqCatFreePlanAndPremiumA4;
String _freePlanAndPremiumQ5(AppLocalizations l) =>
    l.settingsGuidelines_faqCatFreePlanAndPremiumQ5;
String _freePlanAndPremiumA5(AppLocalizations l) =>
    l.settingsGuidelines_faqCatFreePlanAndPremiumA5;

String _courtsAndCustomisationTitle(AppLocalizations l) =>
    l.settingsGuidelines_faqCatCourtsAndCustomisation;
String _courtsAndCustomisationQ1(AppLocalizations l) =>
    l.settingsGuidelines_faqCatCourtsAndCustomisationQ1;
String _courtsAndCustomisationA1(AppLocalizations l) =>
    l.settingsGuidelines_faqCatCourtsAndCustomisationA1;
String _courtsAndCustomisationQ2(AppLocalizations l) =>
    l.settingsGuidelines_faqCatCourtsAndCustomisationQ2;
String _courtsAndCustomisationA2(AppLocalizations l) =>
    l.settingsGuidelines_faqCatCourtsAndCustomisationA2;
String _courtsAndCustomisationQ3(AppLocalizations l) =>
    l.settingsGuidelines_faqCatCourtsAndCustomisationQ3;
String _courtsAndCustomisationA3(AppLocalizations l) =>
    l.settingsGuidelines_faqCatCourtsAndCustomisationA3;
String _courtsAndCustomisationQ4(AppLocalizations l) =>
    l.settingsGuidelines_faqCatCourtsAndCustomisationQ4;
String _courtsAndCustomisationA4(AppLocalizations l) =>
    l.settingsGuidelines_faqCatCourtsAndCustomisationA4;

String _dataAndSupportTitle(AppLocalizations l) =>
    l.settingsGuidelines_faqCatDataAndSupport;
String _dataAndSupportQ1(AppLocalizations l) =>
    l.settingsGuidelines_faqCatDataAndSupportQ1;
String _dataAndSupportA1(AppLocalizations l) =>
    l.settingsGuidelines_faqCatDataAndSupportA1;
String _dataAndSupportQ2(AppLocalizations l) =>
    l.settingsGuidelines_faqCatDataAndSupportQ2;
String _dataAndSupportA2(AppLocalizations l) =>
    l.settingsGuidelines_faqCatDataAndSupportA2;
String _dataAndSupportQ3(AppLocalizations l) =>
    l.settingsGuidelines_faqCatDataAndSupportQ3;
String _dataAndSupportA3(AppLocalizations l) =>
    l.settingsGuidelines_faqCatDataAndSupportA3;

/// Guidelines & FAQs screen.
class GuidelinesScreen extends StatefulWidget {
  const GuidelinesScreen({super.key});

  @override
  State<GuidelinesScreen> createState() => _GuidelinesScreenState();
}

class _GuidelinesScreenState extends State<GuidelinesScreen> {
  /// Id of the open card — `g0`… for guidelines, `f0`… for FAQs. One card is
  /// open at a time across both sections; null means all collapsed.
  String? _openId;

  void _toggle(String id) =>
      setState(() => _openId = _openId == id ? null : id);

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
          SettingsSectionLabel(l.settingsGuidelines_sectionGuidelines),
          const SizedBox(height: AppSpacing.sm),
          for (var index = 0; index < _topics.length; index++) ...[
            if (index > 0) const SizedBox(height: AppSpacing.sm),
            _TopicCard(
              topic: _topics[index],
              open: _openId == 'g$index',
              onToggle: () => _toggle('g$index'),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          SettingsSectionLabel(l.settingsGuidelines_sectionFaqs),
          const SizedBox(height: AppSpacing.sm),
          for (var index = 0; index < _faqCategories.length; index++) ...[
            if (index > 0) const SizedBox(height: AppSpacing.sm),
            _FaqCategoryCard(
              category: _faqCategories[index],
              open: _openId == 'f$index',
              onToggle: () => _toggle('f$index'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Shared accordion chrome: icon chip + title header, body revealed when open.
///
/// The open card switches to the mockup's `border-primary`, and the chevron
/// turns half a revolution so the open card is obvious without colour alone.
class _ExpandableCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool open;
  final VoidCallback onToggle;
  final List<Widget> children;

  const _ExpandableCard({
    required this.icon,
    required this.title,
    required this.open,
    required this.onToggle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainerLowest,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
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
                      icon,
                      size: 20,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.gutter),
                  Expanded(
                    child: Text(
                      title,
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
                children: children,
              ),
            ),
        ],
      ),
    );
  }
}

/// One guideline topic card.
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
    return _ExpandableCard(
      icon: topic.icon,
      title: topic.title(l),
      open: open,
      onToggle: onToggle,
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
    );
  }
}

/// One FAQ topic card: every question in the group with its answer beneath.
class _FaqCategoryCard extends StatelessWidget {
  final _FaqCategory category;
  final bool open;
  final VoidCallback onToggle;

  const _FaqCategoryCard({
    required this.category,
    required this.open,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _ExpandableCard(
      icon: category.icon,
      title: category.title(l),
      open: open,
      onToggle: onToggle,
      children: [
        for (var i = 0; i < category.entries.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.md),
          Text(
            category.entries[i].question(l),
            style: AppTypography.bodyMd.copyWith(
              color: AppColors.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            category.entries[i].answer(l),
            style: AppTypography.bodyMd.copyWith(
              color: AppColors.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ],
    );
  }
}
