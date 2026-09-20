/// Support screen: how to reach the developer, and what support can and cannot
/// do — reached from Settings > About > Support.
///
/// **No mockup exists for this screen** (the mockups stop at About), so it is
/// built from the chrome the other Settings sub-pages already share —
/// `SettingsSubPageModal`, `settings_controls.dart` and the app's tokens. What
/// the screen must do is fixed by the About row that opens it and by the app's
/// own rules:
///
/// * it states its scope before offering any channel, so nobody writes in
///   expecting a hearing date to be checked (the diary never leaves the phone);
/// * it answers the common questions first, by linking to Guidelines & FAQs;
/// * both channels open with the same pre-filled diagnostics message the screen
///   shows, so the user can read exactly what will be sent before sending it;
/// * it says plainly what must never be sent (the passphrase, the database, a
///   backup file) and how long a reply really takes.
///
/// The message is built by [buildSupportMessage] from `appVersion` and the
/// device facts behind `supportDeviceFactsProvider`, and the channels launch
/// through the shared contact launcher, so no test needs WhatsApp installed.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/constants/app_version.dart';
import '../../../../core/l10n/generated/app_localizations.dart';
import '../../../../core/providers/contact_providers.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/contact_launcher.dart';
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
/// The screen renders this same string above the channels, which is the point:
/// what the user reads is exactly what the app writes into WhatsApp or the mail
/// body. The phone line is left out when the device could not be read, so the
/// message is never wrong, just shorter.
String buildSupportMessage({
  required AppLocalizations l,
  required Locale locale,
  required SupportDeviceFacts facts,
}) {
  final phone = <String>[
    facts.model ?? '',
    facts.osVersion ?? '',
  ].where((part) => part.isNotEmpty).join(' · ');
  final language = locale.languageCode == 'bn'
      ? l.settingsScreen_languageBengali
      : l.settingsScreen_languageEnglish;

  return <String>[
    l.settingsSupport_messageIntro,
    '',
    '${l.settingsSupport_messageVersion}: $appVersion',
    if (phone.isNotEmpty) '${l.settingsSupport_messagePhone}: $phone',
    '${l.settingsSupport_messageLanguage}: $language',
    '',
    l.settingsSupport_messagePrompt,
  ].join('\n');
}

/// Support screen.
class SupportScreen extends ConsumerStatefulWidget {
  /// Creates the Support screen.
  const SupportScreen({super.key});

  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  /// The device facts the message carries; empty until (or unless) they read,
  /// because the screen shows its copy immediately rather than waiting.
  SupportDeviceFacts _facts = const SupportDeviceFacts();

  @override
  void initState() {
    super.initState();
    _readFacts();
  }

  Future<void> _readFacts() async {
    final facts = await ref.read(supportDeviceFactsProvider).read();
    if (!mounted) return;
    setState(() => _facts = facts);
  }

  /// Opens the chosen channel with the message already written.
  Future<void> _write(AppLocalizations l, SupportChannel channel) async {
    final body = buildSupportMessage(
      l: l,
      locale: Localizations.localeOf(context),
      facts: _facts,
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
    final message = buildSupportMessage(
      l: l,
      locale: Localizations.localeOf(context),
      facts: _facts,
    );

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
          // Scope first: what support can and cannot do, before any channel.
          _BodyCard(text: l.settingsSupport_scope),
          const SizedBox(height: AppSpacing.lg),
          // Most questions are already answered, so the FAQs come next.
          Text(
            l.settingsSupport_faqLead,
            style: AppTypography.bodyMd.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SettingsLinkRow(
            label: l.settingsGuidelines_title,
            onTap: () => context.push(AppRoutes.settingsGuidelines),
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
          const SizedBox(height: AppSpacing.sm),
          Text(
            l.settingsSupport_channelsHint,
            style: AppTypography.bodySm.copyWith(color: AppColors.outline),
          ),
          const SizedBox(height: AppSpacing.lg),
          // The message the channels open with, shown before it is sent.
          _MessageCard(label: l.settingsSupport_previewLabel, message: message),
          const SizedBox(height: AppSpacing.lg),
          _NoteCard(
            icon: Icons.gpp_maybe_outlined,
            color: AppColors.error,
            background: AppColors.errorContainer,
            border: AppColors.error,
            bodyColor: AppColors.onErrorContainer,
            chipColor: AppColors.surfaceContainerLowest,
            title: l.settingsSupport_warningTitle,
            body: l.settingsSupport_warningBody,
          ),
          const SizedBox(height: AppSpacing.md),
          _NoteCard(
            icon: Icons.schedule_outlined,
            color: AppColors.secondary,
            title: l.settingsSupport_replyTitle,
            body: l.settingsSupport_replyBody,
          ),
        ],
      ),
    );
  }
}

/// White card holding one paragraph of copy.
class _BodyCard extends StatelessWidget {
  final String text;

  const _BodyCard({required this.text});

  @override
  Widget build(BuildContext context) => Container(
    decoration: settingsCardDecoration(),
    padding: const EdgeInsets.all(AppSpacing.md),
    child: Text(
      text,
      style: AppTypography.bodyMd.copyWith(
        color: AppColors.onSurfaceVariant,
        height: 1.5,
      ),
    ),
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

/// The message both channels open with, in a subdued block.
class _MessageCard extends StatelessWidget {
  final String label;
  final String message;

  const _MessageCard({required this.label, required this.message});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
      border: Border.all(color: AppColors.outlineVariant),
    ),
    padding: const EdgeInsets.all(AppSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsSectionLabel(label),
        const SizedBox(height: AppSpacing.sm),
        Text(
          message,
          // The tests read this Text to prove the opened message is the shown one.
          key: const ValueKey('support-message-preview'),
          style: AppTypography.bodyMd.copyWith(
            color: AppColors.onSurface,
            height: 1.5,
          ),
        ),
      ],
    ),
  );
}

/// Tinted note card: icon, title, body — the warning and the reply time.
class _NoteCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color background;
  final Color border;
  final Color? bodyColor;
  final Color? chipColor;
  final String title;
  final String body;

  const _NoteCard({
    required this.icon,
    required this.color,
    this.background = AppColors.surfaceContainerLowest,
    this.border = AppColors.outlineVariant,
    this.bodyColor,
    this.chipColor,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
      border: Border.all(color: border),
    ),
    padding: const EdgeInsets.all(AppSpacing.md),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          // Grey on the white card; the warning card passes a white chip so it
          // still reads on its tint.
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: chipColor ?? AppColors.surfaceContainer,
          ),
          child: Icon(icon, color: color),
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
                  color: bodyColor ?? AppColors.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
