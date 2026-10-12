/// Support screen: how to reach the developer, and what support can and cannot
/// do — reached from Settings > About > Support.
///
/// **No mockup exists for this screen** (the mockups stop at About), so it is
/// built from the chrome the other Settings sub-pages already share —
/// `SettingsSubPageModal`, `settings_controls.dart` and the app's tokens. What
/// the screen must do is fixed by the About row that opens it and by the app's
/// own rules:
///
/// * it leads with **Diagnostics**, because the app's own error log answers
///   "what went wrong" before anybody has to write in;
/// * one card under **Before You Write To Us** says what support can and cannot
///   do (nobody should write in expecting a hearing date to be checked — the
///   diary never leaves the phone), what must never be sent (the passphrase,
///   the database, a backup file) and how long a reply really takes;
/// * that card opens with the sentence that sends a user to **Guidelines &
///   FAQs**, whose name is a bold, underlined link inside it;
/// * **both channels open empty** (0.0.487, user request): Support is for
///   writing in your own words, so WhatsApp opens a bare chat and the mail app
///   a draft carrying only the subject. The pre-filled report has not gone
///   away — it is what **Diagnostics > Report Error Or Bug** sends — so the two
///   screens divide cleanly into *write to us* and *report with the data*.
///
/// [buildSupportMessage] and [writeToSupport] still live here for the
/// Diagnostics screen, which owns the pre-filled message now. The channels
/// launch through the shared contact launcher, so no test needs WhatsApp
/// installed.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/errors/error_log.dart';
import '../../../../core/l10n/generated/app_localizations.dart';
import '../../../../core/providers/contact_providers.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/contact_launcher.dart';
import '../../data/diagnostics_report.dart';
import '../../data/support_diagnostics.dart';
import '../settings_controls.dart';
import '../settings_sub_page_modal.dart';

/// The developer's WhatsApp number, as the About card used to carry it.
/// Mockup data, like the address below — the screen shows it so the user knows
/// who is being written to.
const String supportWhatsAppNumber = '+8801835252721';

/// The developer's email address, as the About card used to carry it.
const String supportEmailAddress = 'adv.asadusjaman@gmail.com';

/// The channels the screen offers, in the order they are shown.
enum SupportChannel { whatsApp, email }

/// The pre-filled message both channels open with.
///
/// The user reads it in WhatsApp or the mail app, before sending, which is why
/// nothing here is a secret and why the phone line is left out when the device
/// could not be read: the message is never wrong, just shorter.
///
/// [entries] are the error log as it stands when the user taps a channel, and
/// they are rendered by `buildDiagnosticsReport` — the **same** header the
/// Diagnostics screen copies and shares — so a pasted report and a sent message
/// quote identical facts. It goes **before** the prompt, so the user's own
/// description is the last thing in the message. The encrypted bundle cannot
/// serve this purpose: it is sealed with the backup passphrase, which is the one
/// thing a stuck user must never be asked for.
///
/// The header is printed even for an empty log — "Errors Recorded: 0" is itself
/// the answer to "is anything wrong?" — so the format is the same every time and
/// there is one block of facts rather than the version appearing twice.
String buildSupportMessage({
  required AppLocalizations l,
  required Locale locale,
  required SupportDeviceFacts facts,
  List<ErrorLogEntry> entries = const <ErrorLogEntry>[],
  DateTime? generatedAt,
}) {
  final phone = <String>[
    facts.model ?? '',
    facts.osVersion ?? '',
  ].where((part) => part.isNotEmpty).join(' · ');
  final language = locale.languageCode == 'bn'
      ? l.settingsScreen_languageBengali
      : l.settingsScreen_languageEnglish;

  // One merged format, shared with the Diagnostics screen's own button: the
  // facts live in the report header rather than being printed twice.
  final report = buildDiagnosticsReport(
    entries: entries,
    generatedAt: generatedAt,
    phone: phone.isEmpty ? null : phone,
    language: language,
  );

  return <String>[
    l.settingsSupport_messageIntro,
    '',
    report,
    '',
    l.settingsSupport_messagePrompt,
  ].join('\n');
}

/// Opens [channel] with the pre-filled support message.
///
/// Shared by this screen's two channel rows and by the Diagnostics screen's
/// **Report Error Or Bug** button, so the channel choice, the message and the
/// "no app could handle it" fallback are written once rather than twice.
/// Returns true when an app took the URI; when none could, the user is told
/// rather than left with a dead tap.
Future<bool> writeToSupport({
  required BuildContext context,
  required ContactLauncher launcher,
  required SupportChannel channel,
  required SupportDeviceFacts facts,
  required List<ErrorLogEntry> entries,
}) async {
  final l = AppLocalizations.of(context);
  final body = buildSupportMessage(
    l: l,
    locale: Localizations.localeOf(context),
    facts: facts,
    entries: entries,
  );
  final uri = switch (channel) {
    SupportChannel.whatsApp => whatsAppUri(
      whatsAppNumber(supportWhatsAppNumber)!,
      body,
    ),
    SupportChannel.email => mailtoUri(
      supportEmailAddress,
      l.settingsSupport_messageSubject,
      body,
    ),
  };

  final opened = await launcher.open(uri);
  if (opened || !context.mounted) return opened;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(switch (channel) {
        SupportChannel.whatsApp => l.settingsSupport_unableToOpenWhatsApp,
        SupportChannel.email => l.settingsSupport_unableToOpenEmail,
      }),
    ),
  );
  return false;
}

/// Support screen.
class SupportScreen extends ConsumerStatefulWidget {
  /// Creates the Support screen.
  const SupportScreen({super.key});

  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  /// Opens the chosen channel with **nothing written for the user**.
  ///
  /// This screen used to hand the app's whole support message — version, phone,
  /// language and the error log — to WhatsApp and the mail app. That made every
  /// enquiry arrive pre-worded, and the request is now the opposite (0.0.487):
  /// Support is for a user who wants to say it in their own words. The log is
  /// not lost — **Diagnostics** carries exactly that message into the same two
  /// channels — so the division is deliberate: *write to us* here, *report a
  /// fault with the data attached* there.
  ///
  /// WhatsApp opens the chat with an empty composer; the mail app opens a draft
  /// with the subject filled and an empty body, so a reply can still be
  /// recognised as support without the user deleting anything.
  Future<void> _write(AppLocalizations l, SupportChannel channel) async {
    final uri = switch (channel) {
      SupportChannel.whatsApp => whatsAppChatUri(
        whatsAppNumber(supportWhatsAppNumber)!,
      ),
      SupportChannel.email => mailtoUri(
        supportEmailAddress,
        l.settingsSupport_messageSubject,
        '',
      ),
    };

    final opened = await ref.read(contactLauncherProvider).open(uri);
    if (opened || !mounted) return;

    // No app can handle the URI: say so instead of leaving a dead tap.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(switch (channel) {
          SupportChannel.whatsApp => l.settingsSupport_unableToOpenWhatsApp,
          SupportChannel.email => l.settingsSupport_unableToOpenEmail,
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return SettingsSubPageModal(
      title: l.settingsSupport_title,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.edgeMargin,
          AppSpacing.md,
          AppSpacing.edgeMargin,
          AppSpacing.xl,
        ),
        children: [
          // The app's own error log is the first thing to reach for, so it leads
          // the screen. The FAQs are no longer a row of their own (user
          // request): they are linked from the card below instead, where the
          // sentence that sends a user to them actually sits.
          Text(
            l.settingsSupport_faqLead,
            style: AppTypography.bodyMd.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SettingsLinkRow(
            label: l.settingsDiagnostics_title,
            onTap: () => context.push(AppRoutes.settingsDiagnostics),
          ),
          const SizedBox(height: AppSpacing.lg),
          SettingsSectionLabel(l.settingsSupport_channelsLabel),
          const SizedBox(height: AppSpacing.sm),
          _ChannelCard(
            channelKey: 'support-whatsapp',
            icon: Icons.chat_outlined,
            iconColor: AppColors.success,
            label: l.settingsSupport_channelWhatsApp,
            value: supportWhatsAppNumber,
            onTap: () => _write(l, SupportChannel.whatsApp),
          ),
          const SizedBox(height: AppSpacing.sm),
          _ChannelCard(
            channelKey: 'support-email',
            icon: Icons.mail_outline,
            iconColor: AppColors.secondary,
            label: l.settingsSupport_channelEmail,
            value: supportEmailAddress,
            onTap: () => _write(l, SupportChannel.email),
          ),
          const SizedBox(height: AppSpacing.lg),
          // One card under one heading (user request): the three notes were
          // separate cards, and reading them as a set is what they are. The
          // heading above it is the group's own name; the first thing *on* the
          // card is the sentence that sends a user to the FAQs, so the most
          // common answer is the first thing they meet.
          SettingsSectionLabel(l.settingsSupport_scopeTitle),
          const SizedBox(height: AppSpacing.sm),
          _HelpCard(
            l: l,
            onOpenGuidelines: () => context.push(AppRoutes.settingsGuidelines),
          ),
        ],
      ),
    );
  }
}

/// The three notes as one card: what support can help with, what must never be
/// sent, and how long a reply takes.
///
/// Each note keeps its own icon, title and body — the card style the screen
/// already used — but they share one border, because they are three answers to
/// one question rather than three subjects.
///
/// **Nothing here is red any more** (user request): the warning note used to sit
/// on an error-tinted card, which read as an alarm for advice the user has not
/// done anything to deserve. It is one part of an ordinary card now, in the
/// app's normal ink.
class _HelpCard extends StatelessWidget {
  const _HelpCard({required this.l, required this.onOpenGuidelines});

  /// Localized copy, passed down so the card does not re-resolve the locale
  /// three times over.
  final AppLocalizations l;

  /// Opens Guidelines & FAQs; the caller owns the route.
  final VoidCallback onOpenGuidelines;

  @override
  Widget build(BuildContext context) {
    final body = AppTypography.bodyMd.copyWith(
      color: AppColors.onSurfaceVariant,
      height: 1.5,
    );
    return Container(
      key: const ValueKey('support-help-card'),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The FAQs sentence leads the card, before any title: most questions
          // are answered there, so it is what a user should try first.
          _InlineLinkSentence(
            l: l,
            style: body,
            onTap: onOpenGuidelines,
          ),
          const SizedBox(height: AppSpacing.md),
          _HelpNote(
            icon: Icons.help_outline,
            title: l.settingsSupport_helpTitle,
            body: l.settingsSupport_scope,
          ),
          const Divider(height: AppSpacing.lg, color: AppColors.outlineVariant),
          _HelpNote(
            icon: Icons.gpp_maybe_outlined,
            title: l.settingsSupport_warningTitle,
            body: l.settingsSupport_warningBody,
          ),
          const Divider(height: AppSpacing.lg, color: AppColors.outlineVariant),
          _HelpNote(
            icon: Icons.schedule_outlined,
            title: l.settingsSupport_replyTitle,
            body: l.settingsSupport_replyBody,
          ),
        ],
      ),
    );
  }
}

/// "Most questions are already answered in **Guidelines & FAQs**." — with the
/// screen name a bold, underlined, tappable link.
///
/// Built from three ARB pieces rather than one string split at runtime, the way
/// the Online Sync screen's free-plan sentence is: the prefix, the link and the
/// closing punctuation are each the language's own — an English "." against a
/// Bengali "।" — so nothing depends on a translated string keeping a marker in
/// the right place. The joining spaces live in the pieces, not in code.
class _InlineLinkSentence extends StatelessWidget {
  const _InlineLinkSentence({
    required this.l,
    required this.style,
    required this.onTap,
  });

  final AppLocalizations l;
  final TextStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      style: style,
      children: [
        TextSpan(text: l.settingsSupport_faqCardPrefix),
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: GestureDetector(
            key: const ValueKey('support-guidelines-link'),
            onTap: onTap,
            child: Text(
              l.settingsGuidelines_title,
              style: style.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.primary,
              ),
            ),
          ),
        ),
        TextSpan(text: l.settingsSupport_faqCardSuffix),
      ],
    ),
  );
}

/// One note inside [_HelpCard]: icon chip, title, body.
class _HelpNote extends StatelessWidget {
  const _HelpNote({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surfaceContainer,
        ),
        child: Icon(icon, color: AppColors.secondary),
      ),
      const SizedBox(width: AppSpacing.md),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTypography.titleMd.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              body,
              style: AppTypography.bodyMd.copyWith(
                color: AppColors.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

/// One channel: icon chip, Title Case label, the address it writes to, chevron.
class _ChannelCard extends StatelessWidget {
  /// Stable key part, so the tests address the channel they mean.
  final String channelKey;
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _ChannelCard({
    required this.channelKey,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    key: ValueKey(channelKey),
    color: AppColors.surfaceContainerLowest,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
      side: BorderSide(color: AppColors.outlineVariant),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              // A grey chip on the white card, like the Guidelines cards' chips.
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surfaceContainer,
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTypography.labelMd.copyWith(
                      color: AppColors.outline,
                    ),
                  ),
                  Text(
                    value,
                    style: AppTypography.titleMd.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.outline),
          ],
        ),
      ),
    ),
  );
}

