/// Manage Associates screen: create the firm, invite associates, and read the
/// roster.
///
/// Task 20 Phase 1 replaces Task 17 Phase 5's stub with the real screen — the
/// plan's `manage_associates_screen.dart`, marked `[Design-deferred]`, so there
/// is no mockup HTML and its layout was confirmed with the user before it was
/// built: the established Settings sub-page shell, an offline state that
/// replaces the body, and cards sized by the shared Settings size contract.
///
/// Two rules shape everything here:
///
///  * **Firm administration is online-only** (plan §1). Offline, the body is the
///    shared "Connect to the internet to manage your firm" message rather than
///    controls that must fail — an invite cannot be created, revoked or redeemed
///    without the server, and the roster is a live read.
///  * **Firm mode requires premium** (plan §6). An individual on a free
///    entitlement is sent to the Paywall instead of to a create-firm form;
///    `ensure_firm` enforces the same rule server-side, so this is the polite
///    half of one decision rather than the only half.
///
/// The roster is read through [firmMembersListProvider] rather than cached:
/// `firm_members` is the pull-only cache of **this** account's own membership
/// (AGENTS.md rule 4), and it must not become a second copy of the firm's.
///
/// Adding the first associate is what creates the firm (plan §1, Account Mode
/// Detection): the create-firm card calls `ensure_firm`, which is the only path
/// from individual to owner, and then generates the invite code — the owner has
/// to exist before the code that invites into their firm can.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/errors/error_log.dart';
import '../../../core/errors/error_log_provider.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/providers/print_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/app_share_service.dart';
import '../../../core/utils/date_utils.dart';
import '../../../sync/connectivity_monitor.dart';
import '../../../sync/sync_service.dart';
import '../../../sync/sync_status_providers.dart';
import '../../auth/presentation/auth_viewmodel.dart';
import '../../auth/presentation/auth_widgets.dart';
import '../../settings/presentation/settings_controls.dart';
import '../../settings/presentation/settings_menu_card.dart';
import '../../settings/presentation/settings_sub_page_modal.dart';
import '../data/account_mode.dart';
import '../data/avatar_image_processor.dart';
import '../data/firm_capacity.dart';
import '../data/firm_logo_repository.dart';
import '../data/firm_logo_store.dart';
import '../data/firm_logo_sync.dart';
import '../data/firm_repository.dart';
import '../data/profile_repository.dart' show AccountRole;

/// Manage Associates: firm creation, invites and the roster.
class ManageAssociatesScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const ManageAssociatesScreen({super.key});

  @override
  ConsumerState<ManageAssociatesScreen> createState() =>
      _ManageAssociatesScreenState();
}

class _ManageAssociatesScreenState
    extends ConsumerState<ManageAssociatesScreen> {
  /// The firm name typed while this account is still an individual.
  final TextEditingController _firmNameController = TextEditingController();

  /// Set while a server call is in flight, so no control can be tapped twice.
  bool _busy = false;

  /// The last failure to show; cleared when a new attempt starts.
  Object? _failure;

  @override
  void dispose() {
    _firmNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // Unknown connectivity counts as online, the same choice Task 17 Phase 4
    // made: a wrong "offline" would hide an operation the server accepts.
    final online = ref.watch(isOnlineProvider).value ?? true;
    final signedIn = ref.watch(authIdentityProvider) != null;
    final owner = ref.watch(canManageFirmProvider);

    final Widget body;
    if (!online) {
      body = _MessageBody(l.auth_errorFirmAdminOffline);
    } else if (!signedIn) {
      // A firm needs an account to belong to; there is nothing to administer on
      // a device that never signed in.
      body = _MessageBody(l.sharedMessages_signInRequired);
    } else if (owner) {
      body = _rosterBody(l);
    } else if (ref.watch(canOpenManageAssociatesProvider)) {
      body = _firmSetupBody(l);
    } else {
      // A firm member who is not the owner: the entry point hides this screen,
      // and a deep link into it must not offer a create-firm form either — the
      // server would refuse it, and an associate who took it at face value would
      // be told they could leave their own firm.
      body = _MessageBody(l.manageAssociates_ownerOnly);
    }

    return SettingsSubPageModal(title: l.manageAssociates_title, child: body);
  }

  /// The owner's view: the firm, the invite action, the roster and the invites.
  ///
  /// The roster and the outstanding invites are both **live reads** and both are
  /// invalidated rather than cached after a change, which is what keeps this
  /// screen from becoming a second copy of the firm's server state (AGENTS.md
  /// rule 4: `firm_members` and `firm_invites` are not this device's to own).
  Widget _rosterBody(AppLocalizations l) {
    final firm = ref.watch(accountFirmProvider).value;
    final firmName = firm?.name ?? '';
    final members = ref.watch(firmMembersListProvider);
    final invites = ref.watch(firmInvitesListProvider);
    // The owner's shared-capacity picture: associates and the owner's own
    // devices against the tier's slots.
    final capacity = ref.watch(firmCapacityViewProvider);
    final noFreeSlot = capacity != null && !capacity.canAddAssociate;
    final addBlockReason = capacity == null
        ? null
        : capacity.frozen
        ? l.settingsSubscription_capacityFrozenBody
        : noFreeSlot
        ? l.manageAssociates_noFreeSlot
        : null;

    // Dissolving is server-only work and the push runs before the pull: a queued
    // local edit still names this chamber, so it would be refused and rolled
    // back the moment the chamber stopped existing. The action therefore waits
    // for the queue, and says so, rather than losing an edit it cannot see.
    final pendingWrites =
        ref.watch(syncQueueEntriesProvider).value?.isNotEmpty ?? false;
    // Null until the roster is read: an unknown count is not "nobody left".
    final membersLeft = members.value
        ?.where((member) => member.role != AccountRole.owner)
        .length;

    // A read that fails here only becomes an error state the banner draws, so
    // the providers behind these two watches are what remember it — the
    // roster is the thing on this screen an owner cannot work out for
    // themselves, and a listener in this build would write it once per frame.
    final locale = Localizations.localeOf(context).toString();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.edgeMargin,
        AppSpacing.md,
        AppSpacing.edgeMargin,
        AppSpacing.xl,
      ),
      children: [
        if (_failure != null) ...[
          AuthErrorBanner(text: _failureText(l)),
          const SizedBox(height: AppSpacing.md),
        ],
        _FirmCard(
          label: l.settingsManageAccount_firm,
          name: firmName,
          onChange: _busy || firm == null ? null : _pickFirmLogo,
          onRemove: _busy || firm == null ? null : _removeFirmLogo,
        ),
        if (capacity != null) ...[
          const SizedBox(height: AppSpacing.gutter),
          _CapacityCard(capacity: capacity, l: l),
        ],
        const SizedBox(height: AppSpacing.gutter),
        _PrimaryButton(
          icon: Icons.person_add_alt_1_outlined,
          label: l.manageAssociates_addAssociate,
          onPressed: _busy || addBlockReason != null ? null : _addAssociate,
        ),
        if (addBlockReason != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            addBlockReason,
            style: AppTypography.bodySm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        SettingsSectionLabel(l.manageAssociates_sectionMembers),
        const SizedBox(height: AppSpacing.sm),
        members.when(
          data: (rows) => rows.isEmpty
              ? _InfoRow(text: l.manageAssociates_noMembers)
              : Column(
                  children: [
                    for (final member in rows) ...[
                      _MemberRow(
                        member: member,
                        l: l,
                        // The owner's own row is not the roster's to edit: their
                        // permissions are structural (`firms.owner_id`), so a
                        // flag on their `firm_members` row would not change what
                        // they may do. Tapping it opens nothing at all.
                        onTap: member.role == AccountRole.owner
                            ? null
                            : () => _editMember(member),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ],
                ),
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          ),
          // A refused or failed read is reported, never swallowed: the roster is
          // the one thing on this screen the owner cannot infer.
          error: (error, _) => AuthErrorBanner(
            text: failureText(l, error) ?? l.auth_errorUnknown,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SettingsSectionLabel(l.manageAssociates_sectionInvites),
        const SizedBox(height: AppSpacing.sm),
        invites.when(
          data: (rows) => rows.isEmpty
              ? _InfoRow(text: l.manageAssociates_noInvites)
              : Column(
                  children: [
                    for (final invite in rows) ...[
                      _InviteRow(
                        id: invite.id,
                        // The code itself is unrecoverable — only its hash is
                        // stored — so a row is named by when it was made.
                        createdLabel: l.manageAssociates_inviteCreated(
                          AppDateUtils.formatDateDDMMYYYY(
                            invite.createdAt,
                            locale: locale,
                          ),
                        ),
                        revokeLabel: l.manageAssociates_revokeInvite,
                        onRevoke: _busy ? null : () => _revokeInvite(invite.id),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ],
                ),
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => AuthErrorBanner(
            text: failureText(l, error) ?? l.auth_errorUnknown,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SettingsSectionLabel(l.manageAssociates_sectionFirm),
        const SizedBox(height: AppSpacing.sm),
        _DissolveCard(
          intro: l.manageAssociates_dissolveIntro,
          // One reason at a time, in the order the action has to clear them.
          note: membersLeft == null
              ? null
              : membersLeft > 0
              ? l.manageAssociates_dissolveBlockedMembers(membersLeft)
              : pendingWrites
              ? l.manageAssociates_dissolveBlockedPending
              : null,
          actionLabel: l.manageAssociates_dissolveFirm,
          onPressed: membersLeft == 0 && !pendingWrites && !_busy
              ? _dissolveFirm
              : null,
        ),
      ],
    );
  }

  /// The individual's view: what a firm is, then the form that creates one.
  Widget _firmSetupBody(AppLocalizations l) {
    final premium = ref.watch(premiumAccessProvider);
    final free = premium.value == false;
    final canSubmit =
        !_busy &&
        !premium.isLoading &&
        _firmNameController.text.trim().isNotEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.edgeMargin,
        AppSpacing.md,
        AppSpacing.edgeMargin,
        AppSpacing.xl,
      ),
      children: [
        if (_failure != null) ...[
          AuthErrorBanner(text: _failureText(l)),
          const SizedBox(height: AppSpacing.md),
        ],
        // The explainer comes first: the form below it assumes the reader has
        // already decided a firm is worth creating.
        const _FirmOverview(),
        const SizedBox(height: AppSpacing.lg),
        // The form's own heading, in the explainer's title size, so the page
        // reads as two sections rather than one long card chain.
        Text(
          l.manageAssociates_createFirmTitle,
          style: AppTypography.titleLg.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          decoration: settingsCardDecoration(),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.manageAssociates_firmNameLabel,
                style: AppTypography.labelMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                key: const ValueKey('manage-associates-firm-name'),
                controller: _firmNameController,
                enabled: !_busy,
                textCapitalization: TextCapitalization.words,
                style: AppTypography.bodyLg,
                // The submit button reads the field, so a keystroke must rebuild
                // it — otherwise it would stay disabled over a typed name.
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: l.manageAssociates_firmNameHint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // Free entitlement: say why, and send the tap to the Paywall rather than
        // to a form whose submit the server would refuse.
        if (free) ...[
          AuthErrorBanner(text: l.auth_errorPremiumRequired),
          const SizedBox(height: AppSpacing.sm),
        ],
        _PrimaryButton(
          icon: free
              ? Icons.workspace_premium_outlined
              : Icons.apartment_outlined,
          label: free
              ? l.manageAssociates_goPremium
              : l.manageAssociates_createFirm,
          onPressed: canSubmit ? _createFirm : null,
        ),
      ],
    );
  }

  /// Creates the firm and shows the first invite code.
  Future<void> _createFirm() async {
    // A firm is a premium feature (plan §6). The check is the client half of the
    // rule `ensure_firm` enforces; the button is disabled until entitlement is
    // known, so this never guesses at a loading value.
    if (ref.read(premiumAccessProvider).value != true) {
      context.push(AppRoutes.paywall);
      return;
    }

    final name = _firmNameController.text.trim();
    await _run(() async {
      final repository = ref.read(firmRepositoryProvider);
      await repository.ensureFirm(name);
      // The cached profile and membership carry the new firm and the owner role;
      // without this the screen would still believe it is an individual and this
      // account would not count as firm mode until the next launch.
      await ref.read(accountRefreshProvider)();
      final invite = await repository.createInvite();
      if (!mounted) return;
      ref.invalidate(firmMembersListProvider);
      await _showInviteCode(invite);
    });
  }

  /// Generates one invite for an existing firm and shows its code.
  Future<void> _addAssociate() => _run(() async {
    final invite = await ref.read(firmRepositoryProvider).createInvite();
    if (!mounted) return;
    // The new code joins the outstanding list as soon as this sheet closes.
    ref.invalidate(firmInvitesListProvider);
    await _showInviteCode(invite);
  });

  /// Revokes an unused invite, after confirming it.
  ///
  /// The confirmation is not ceremony: a revoked code stops working instantly
  /// and its plaintext is unrecoverable, so the associate holding it cannot be
  /// re-told what it was — the owner has to send a fresh one.
  Future<void> _revokeInvite(String inviteId) async {
    final l = AppLocalizations.of(context);
    final confirmed = await _confirm(
      context: context,
      title: l.manageAssociates_revokeInviteTitle,
      body: l.manageAssociates_revokeInviteBody,
      confirmLabel: l.manageAssociates_revokeInvite,
    );
    if (!confirmed) return;
    await _run(() async {
      await ref.read(firmRepositoryProvider).revokeInvite(inviteId);
      if (!mounted) return;
      ref.invalidate(firmInvitesListProvider);
      _say(context, l.manageAssociates_inviteRevoked);
    });
  }

  /// Dissolves the firm, after confirming it, and turns the ledger into the
  /// owner's own diary.
  Future<void> _dissolveFirm() async {
    final l = AppLocalizations.of(context);
    final confirmed = await _confirm(
      context: context,
      title: l.manageAssociates_dissolveConfirmTitle,
      body: l.manageAssociates_dissolveConfirmBody,
      confirmLabel: l.manageAssociates_dissolveFirm,
    );
    if (!confirmed) return;
    await _run(() async {
      // The logo belongs to the chamber and goes with it. Removed before the
      // dissolve, while this account is still its owner and the storage policy
      // still admits the delete; a failure is logged and must not block the
      // dissolve, which is the user's real request.
      final firmId = ref.read(accountFirmProvider).value?.id;
      if (firmId != null) {
        try {
          await ref.read(firmLogoRepositoryProvider).remove('$firmId.jpg');
        } on Object catch (error) {
          recordFailure(ref.read(errorLogProvider), 'firm.logo', error);
        }
      }
      try {
        await ref.read(firmRepositoryProvider).dissolveFirm();
      } on DissolveRefusal {
        // The server's roster is newer than this screen's: show the count the
        // refusal carries and re-read the roster behind it.
        if (mounted) ref.invalidate(firmMembersListProvider);
        rethrow;
      }
      // The profile no longer names a firm, which is what makes this account
      // individual again and drops the cached chamber.
      await ref.read(accountRefreshProvider)();
      if (!mounted) return;
      ref.invalidate(firmMembersListProvider);
      ref.invalidate(firmInvitesListProvider);
      // Pull once before saying it is done: the rows the server unscoped must
      // arrive locally without their old `firm_id`, or the next push would
      // offer the server a chamber that no longer exists.
      await ref.read(syncServiceProvider).syncNow(force: true, pull: true);
      if (!mounted) return;
      _say(context, l.manageAssociates_dissolveDone);
    });
  }

  /// Picks a chamber logo, shrinks it to 50 KB, and stores it locally first.
  ///
  /// The upload is detached: a save must never wait on the network, and a
  /// failure leaves the local picture waiting for the next refresh. A known
  /// lapsed entitlement is told up front; an entitlement still loading is
  /// allowed to try, because the bucket's policy is the boundary either way.
  Future<void> _pickFirmLogo() async {
    final l = AppLocalizations.of(context);
    if (ref.read(premiumAccessProvider).value == false) {
      _say(context, l.manageAssociates_logoNeedsPlan);
      return;
    }
    final firmId = ref.read(accountFirmProvider).value?.id;
    if (firmId == null) return;

    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 90,
    );
    if (picked == null || !mounted) return;

    try {
      final bytes = await File(picked.path).readAsBytes();
      final processed = await processAvatar(bytes);
      await ref.read(firmLogoProvider.notifier).setBytes(processed, firmId);
      if (!mounted) return;
      unawaited(ref.read(firmLogoSyncProvider)());
    } on AvatarImageException {
      if (mounted) _say(context, l.shared_avatarUnreadable);
    } on Object catch (error) {
      recordFailure(ref.read(errorLogProvider), 'firm.logo', error);
      if (mounted) _say(context, l.shared_avatarUnreadable);
    }
  }

  /// Removes the chamber logo, locally at once and from Storage when possible.
  Future<void> _removeFirmLogo() async {
    await ref.read(firmLogoProvider.notifier).clear();
    if (!mounted) return;
    unawaited(ref.read(firmLogoSyncProvider)());
  }

  /// Opens one member's permissions sheet.
  Future<void> _editMember(FirmMemberSummary member) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _MemberSheet(member: member),
      );

  /// Runs [action] with the busy flag and the failure banner wired up.
  ///
  /// One place owns both, so every call on this screen behaves the same way and
  /// no failure can be silently dropped.
  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      await action();
    } on Object catch (error) {
      if (!mounted) return;
      // Remembered here, because this screen shows the failure rather than
      // rethrowing it: a refused invite is precisely the report this log has to
      // be able to answer, and without this it would leave no trace at all.
      recordFailure(ref.read(errorLogProvider), 'firm.action', error);
      setState(() => _failure = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The message for the last failure, never a raw server string.
  String _failureText(AppLocalizations l) =>
      failureText(l, _failure) ?? l.auth_errorUnknown;

  Future<void> _showInviteCode(GeneratedInvite invite) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _InviteCodeSheet(invite: invite),
      );
}

/// Centred single-message body (offline, or no account).
class _MessageBody extends StatelessWidget {
  const _MessageBody(this.text);

  /// The message to show.
  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: AuthErrorBanner(text: text),
    ),
  );
}

/// What a firm is, shown while the account has none, above the create-firm
/// form (user request).
///
/// The form used to arrive with nothing explaining why an individual would want
/// a firm, and the plan that pays for one is bought on another screen — so the
/// last paragraph names **Subscription Plans**, which is a link into the paywall
/// opened on its **Firm** cards — bold and underlined in the sentence's own
/// size, so the words beside it are not pushed out of step (user request). The
/// body is written as prose sentences (the descriptions) under bold labels, per
/// the app's casing rule.
class _FirmOverview extends StatelessWidget {
  const _FirmOverview();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      decoration: settingsCardDecoration(),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.manageAssociates_firmOverviewTitle,
            style: AppTypography.titleLg.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.md),
          _OverviewPoint(
            icon: Icons.groups_outlined,
            title: l.manageAssociates_firmOverviewCollaborateTitle,
            body: l.manageAssociates_firmOverviewCollaborateBody,
          ),
          const SizedBox(height: AppSpacing.md),
          _OverviewPoint(
            icon: Icons.devices_outlined,
            title: l.manageAssociates_firmOverviewDevicesTitle,
            body: l.manageAssociates_firmOverviewDevicesBody,
          ),
          const SizedBox(height: AppSpacing.md),
          _OverviewPoint(
            icon: Icons.cloud_upload_outlined,
            title: l.manageAssociates_firmOverviewBackupTitle,
            body: l.manageAssociates_firmOverviewBackupBody,
          ),
          const SizedBox(height: AppSpacing.md),
          // A rule, because the paragraph under it changes subject: from what a
          // firm is to how to get one.
          const Divider(height: 1, color: AppColors.outlineVariant),
          const SizedBox(height: AppSpacing.md),
          Text(
            l.manageAssociates_firmOverviewReadyTitle,
            style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text.rich(
            TextSpan(
              style: AppTypography.bodyMd.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
              children: [
                TextSpan(
                  text: '${l.manageAssociates_firmOverviewReadyPrefix} ',
                ),
                // A widget span rather than a tap recognizer: the recognizer
                // needs disposing and the link needs a target size, and this is
                // how the Sign Up card's two document links are built.
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: GestureDetector(
                    key: const ValueKey('manage-associates-plans-link'),
                    onTap: () => context.push(AppRoutes.paywallFromFirmSetup),
                    child: Text(
                      l.paywall_title,
                      // The sentence's own size: the link is marked by its
                      // weight and underline, not by standing taller than the
                      // words beside it.
                      style: AppTypography.bodyMd.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
                TextSpan(
                  text: ' ${l.manageAssociates_firmOverviewReadySuffix}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One bold label and its sentence, with the icon that names the point.
class _OverviewPoint extends StatelessWidget {
  const _OverviewPoint({
    required this.icon,
    required this.title,
    required this.body,
  });

  /// The point's own icon.
  final IconData icon;

  /// Bold lead-in, read as the point's label.
  final String title;

  /// The sentence that explains it.
  final String body;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Nudged down to sit on the first line of the sentence beside it rather
      // than on the top of the paragraph's box.
      Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Icon(icon, size: 20, color: AppColors.primary),
      ),
      const SizedBox(width: AppSpacing.md),
      Expanded(
        child: Text.rich(
          TextSpan(
            style: AppTypography.bodyMd.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
            children: [
              // The label and its sentence are one paragraph, so the bold run
              // ends in the colon the sentence carries on from.
              TextSpan(
                text: '$title: ',
                style: AppTypography.bodyMd.copyWith(
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextSpan(text: body),
            ],
          ),
        ),
      ),
    ],
  );
}

/// The firm header card: what this account's firm is called.
/// The chamber's identity: its logo, its name, and the owner's two actions.
///
/// The card shows the local copy immediately (the provider is synchronous), so
/// a newly chosen logo appears before its upload finishes. Remove is offered
/// only when there is something to remove.
class _FirmCard extends ConsumerWidget {
  const _FirmCard({
    required this.label,
    required this.name,
    required this.onChange,
    required this.onRemove,
  });

  final String label;
  final String name;
  final VoidCallback? onChange;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final logo = ref.watch(firmLogoProvider);
    final hasLogo = logo != null;

    return Container(
      decoration: settingsCardDecoration(),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.surfaceContainerLow,
                backgroundImage: logo != null ? FileImage(logo) : null,
                child: logo == null
                    ? const Icon(
                        Icons.apartment_outlined,
                        color: AppColors.primary,
                        size: 28,
                      )
                    : null,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    Text(name, style: AppTypography.bodyLg),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.gutter),
          // Wrapped, not a Row: at a large text setting the two labels may not
          // fit side by side on a narrow phone.
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                TextButton(
                  key: const ValueKey('firm-logo-change'),
                  style: TextButton.styleFrom(textStyle: AppTypography.labelLg),
                  onPressed: onChange,
                  child: Text(
                    hasLogo
                        ? l.manageAssociates_changeLogo
                        : l.manageAssociates_addLogo,
                  ),
                ),
                if (hasLogo)
                  TextButton(
                    key: const ValueKey('firm-logo-remove'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                      textStyle: AppTypography.labelLg,
                    ),
                    onPressed: onRemove,
                    child: Text(l.manageAssociates_removeLogo),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The owner's shared-capacity card: slots used, a pending shrink, and the
/// states that block a new join.
class _CapacityCard extends StatelessWidget {
  const _CapacityCard({required this.capacity, required this.l});

  final FirmCapacityView capacity;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final shrinkDate = capacity.shrinkAt == null
        ? ''
        : AppDateUtils.formatDateDDMMYYYY(
            capacity.shrinkAt!.millisecondsSinceEpoch,
            locale: locale,
          );

    return Container(
      decoration: settingsCardDecoration(),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.settingsSubscription_usageSeats,
            style: AppTypography.labelMd.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l.settingsSubscription_usageOfLimit(
              '${capacity.used}',
              '${capacity.slots}',
            ),
            style: AppTypography.titleMd,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l.settingsSubscription_usageSeatsNote,
            style: AppTypography.bodySm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          if (capacity.shrinkPending && capacity.shrinkAt != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              l.settingsSubscription_capacityShrinkTitle,
              style: AppTypography.titleMd,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l.settingsSubscription_capacityShrinkBody(
                shrinkDate,
                '${capacity.pendingSlots}',
                '${capacity.associates}',
                '${capacity.ownerDevices}',
              ),
              style: AppTypography.bodySm,
            ),
          ],
          if (capacity.signedOut > 0) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              l.settingsSubscription_usageSignedOut(capacity.signedOut),
              style: AppTypography.bodySm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
          if (capacity.overRoster) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              l.settingsSubscription_capacityOverBody,
              style: AppTypography.bodySm.copyWith(color: AppColors.error),
            ),
          ],
          if (capacity.overDevices) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              l.settingsSubscription_capacityDevicesOverBody,
              style: AppTypography.bodySm.copyWith(color: AppColors.error),
            ),
          ],
          if (capacity.frozen) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              l.settingsSubscription_capacityFrozenBody,
              style: AppTypography.bodySm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One associate: name on the left, role on the right, an edit affordance when
/// the row can be edited.
class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member, required this.l, this.onTap});

  final FirmMemberSummary member;
  final AppLocalizations l;

  /// Opens the permissions sheet; null for the owner's own row, which is not
  /// editable from the roster.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            ),
            child: const Icon(Icons.person_outline, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  member.fullName.isEmpty
                      ? l.manageAssociates_unnamedMember
                      : member.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyLg,
                ),
                if (member.capacitySignedOutAt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    l.manageAssociates_statusNotSignedIn,
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _RoleChip(label: _roleLabel(l, member.role)),
          if (onTap != null) ...[
            const SizedBox(width: AppSpacing.xs),
            const Icon(Icons.chevron_right, color: AppColors.outline),
          ],
        ],
      ),
    );

    if (onTap == null) {
      return Container(decoration: settingsCardDecoration(), child: content);
    }
    return Material(
      color: AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
        side: BorderSide(color: AppColors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('manage-associates-member-${member.userId}'),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

/// One outstanding invite: when it was created, and the way to revoke it.
///
/// The row never shows the code — the server keeps only its SHA-256 hash, so the
/// plaintext is genuinely unrecoverable once the "shown once" sheet is closed.
class _InviteRow extends StatelessWidget {
  const _InviteRow({
    required this.id,
    required this.createdLabel,
    required this.revokeLabel,
    required this.onRevoke,
  });

  final String id;
  final String createdLabel;
  final String revokeLabel;
  final VoidCallback? onRevoke;

  @override
  Widget build(BuildContext context) => Container(
    decoration: settingsCardDecoration(),
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    ),
    child: Row(
      children: [
        const Icon(Icons.vpn_key_outlined, color: AppColors.primary),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: Text(createdLabel, style: AppTypography.bodyMd)),
        TextButton(
          key: ValueKey('manage-associates-revoke-$id'),
          onPressed: onRevoke,
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          child: Text(revokeLabel),
        ),
      ],
    ),
  );
}

/// One permission, as a labelled switch.
class _PermissionToggle extends StatelessWidget {
  const _PermissionToggle({
    required this.label,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final bool value;
  final bool enabled;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile.adaptive(
    contentPadding: EdgeInsets.zero,
    title: Text(label, style: AppTypography.bodyLg),
    value: value,
    onChanged: enabled ? onChanged : null,
  );
}

/// The permissions sheet for one member: role, the three flags, and removal.
///
/// Owner-only by construction (only the owner reaches this screen) and
/// **online-only**, like every other firm-administration write: the sheet does
/// the write itself and invalidates the roster afterwards, so the list behind it
/// always shows what the server just accepted.
class _MemberSheet extends ConsumerStatefulWidget {
  const _MemberSheet({required this.member});

  final FirmMemberSummary member;

  @override
  ConsumerState<_MemberSheet> createState() => _MemberSheetState();
}

class _MemberSheetState extends ConsumerState<_MemberSheet> {
  late String _role = widget.member.role == AccountRole.viewer
      ? AccountRole.viewer
      : AccountRole.associate;
  late bool _canAdd = widget.member.canAdd;
  late bool _canEdit = widget.member.canEdit;
  late bool _canDelete = widget.member.canDelete;

  bool _busy = false;
  Object? _failure;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final capacity = ref.watch(firmCapacityViewProvider);
    final flagged = widget.member.capacitySignedOutAt != null;
    final showSignOut =
        !flagged &&
        capacity != null &&
        (capacity.shrinkPending || capacity.overRoster || capacity.overDevices);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.member.fullName.isEmpty
                  ? l.manageAssociates_unnamedMember
                  : widget.member.fullName,
              style: AppTypography.titleLg,
            ),
            if (flagged) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                l.manageAssociates_signedOutNote,
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            if (_failure != null) ...[
              AuthErrorBanner(
                text: failureText(l, _failure) ?? l.auth_errorUnknown,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            SettingsSectionLabel(l.manageAssociates_permissionsTitle),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l.manageAssociates_roleLabel,
              style: AppTypography.labelMd.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            // A member is an associate or a viewer; `owner` is not a choice,
            // because ownership is `firms.owner_id` and not a row flag.
            Row(
              children: [
                SettingsChoiceButton(
                  key: const ValueKey('member-role-associate'),
                  label: l.settingsManageAccount_roleAssociate,
                  selected: _role == AccountRole.associate,
                  onTap: _busy
                      ? () {}
                      : () => setState(() => _role = AccountRole.associate),
                ),
                const SizedBox(width: AppSpacing.sm),
                SettingsChoiceButton(
                  key: const ValueKey('member-role-viewer'),
                  label: l.settingsManageAccount_roleViewer,
                  selected: _role == AccountRole.viewer,
                  onTap: _busy
                      ? () {}
                      : () => setState(() => _role = AccountRole.viewer),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _PermissionToggle(
              label: l.manageAssociates_permissionAdd,
              value: _canAdd,
              enabled: !_busy,
              onChanged: (value) => setState(() => _canAdd = value),
            ),
            _PermissionToggle(
              label: l.manageAssociates_permissionEdit,
              value: _canEdit,
              enabled: !_busy,
              onChanged: (value) => setState(() => _canEdit = value),
            ),
            _PermissionToggle(
              label: l.manageAssociates_permissionDelete,
              value: _canDelete,
              enabled: !_busy,
              onChanged: (value) => setState(() => _canDelete = value),
            ),
            const SizedBox(height: AppSpacing.md),
            _PrimaryButton(
              icon: Icons.check_outlined,
              label: l.manageAssociates_savePermissions,
              onPressed: _busy ? null : _save,
            ),
            if (flagged) ...[
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  key: const ValueKey('member-admit'),
                  onPressed: _busy ? null : _admit,
                  icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                  label: Text(l.manageAssociates_capacityAdmit),
                ),
              ),
            ] else if (showSignOut) ...[
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  key: const ValueKey('member-sign-out'),
                  onPressed: _busy ? null : _signOut,
                  icon: const Icon(Icons.logout_outlined, size: 18),
                  label: Text(l.manageAssociates_capacitySignOut),
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                key: const ValueKey('member-remove'),
                onPressed: _busy ? null : _remove,
                icon: const Icon(Icons.person_remove_alt_1_outlined, size: 18),
                label: Text(l.manageAssociates_removeAssociate),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Writes the role and the three flags, then closes on success.
  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    await _run(() async {
      await ref
          .read(firmRepositoryProvider)
          .updateMemberPermissions(
            userId: widget.member.userId,
            role: _role,
            canAdd: _canAdd,
            canEdit: _canEdit,
            canDelete: _canDelete,
          );
      if (!mounted) return;
      ref.invalidate(firmMembersListProvider);
      Navigator.of(context).maybePop();
      _say(context, l.manageAssociates_permissionsUpdated);
    });
  }

  /// Removes the member, after a confirmation that names what it costs.
  Future<void> _remove() async {
    final l = AppLocalizations.of(context);
    final confirmed = await _confirm(
      context: context,
      title: l.manageAssociates_removeAssociateTitle,
      body: l.manageAssociates_removeAssociateBody,
      confirmLabel: l.manageAssociates_removeAssociate,
    );
    if (!confirmed) return;
    await _run(() async {
      await ref.read(firmRepositoryProvider).removeMember(widget.member.userId);
      if (!mounted) return;
      ref.invalidate(firmMembersListProvider);
      Navigator.of(context).maybePop();
      _say(context, l.manageAssociates_associateRemoved);
    });
  }

  /// Signs a seated member's devices out for capacity, after a confirmation.
  Future<void> _signOut() async {
    final l = AppLocalizations.of(context);
    final name = widget.member.fullName.isEmpty
        ? l.manageAssociates_unnamedMember
        : widget.member.fullName;
    final confirmed = await _confirm(
      context: context,
      title: l.manageAssociates_capacitySignOut,
      body: l.manageAssociates_capacitySignOutBody(name),
      confirmLabel: l.manageAssociates_capacitySignOut,
    );
    if (!confirmed) return;
    await _run(() async {
      await ref
          .read(firmRepositoryProvider)
          .signOutMember(widget.member.userId);
      if (!mounted) return;
      ref.invalidate(firmMembersListProvider);
      Navigator.of(context).maybePop();
      _say(context, l.manageAssociates_capacitySignedOut);
    });
  }

  /// Clears a capacity-signed-out member's marker when the chamber has room.
  Future<void> _admit() async {
    final l = AppLocalizations.of(context);
    await _run(() async {
      await ref.read(firmRepositoryProvider).admitMember(widget.member.userId);
      if (!mounted) return;
      ref.invalidate(firmMembersListProvider);
      Navigator.of(context).maybePop();
      _say(context, l.manageAssociates_capacityAdmitted);
    });
  }

  /// Runs [action] with the busy flag and the failure banner wired up.
  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      await action();
    } on Object catch (error) {
      if (!mounted) return;
      // Remembered here, because this screen shows the failure rather than
      // rethrowing it: a refused invite is precisely the report this log has to
      // be able to answer, and without this it would leave no trace at all.
      recordFailure(ref.read(errorLogProvider), 'firm.action', error);
      setState(() => _failure = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// A titled confirmation window, with the destructive action in the error colour.
Future<bool> _confirm({
  required String title,
  required String body,
  required String confirmLabel,
  required BuildContext context,
}) async {
  final l = AppLocalizations.of(context);
  final answer = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      // Scrollable: the removal warning is several sentences long on purpose
      // (the owner is told what cannot be reached, and what to do about it), and
      // a fixed Text would clip it on a phone.
      content: SingleChildScrollView(child: Text(body)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l.sharedActions_cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return answer ?? false;
}

/// The role label for [role]; the account screen's own words, reused.
String _roleLabel(AppLocalizations l, String role) => switch (role) {
  AccountRole.owner => l.settingsManageAccount_roleOwner,
  AccountRole.associate => l.settingsManageAccount_roleAssociate,
  AccountRole.viewer => l.settingsManageAccount_roleViewer,
  _ => l.settingsManageAccount_roleIndividual,
};

/// The dissolve card: what it does, why it is unavailable, and the action.
///
/// In the error colour rather than the primary one, because it is the one
/// destructive action in firm administration — and disabled rather than hidden
/// while the roster holds anyone, so the owner can see what stands in the way.
class _DissolveCard extends StatelessWidget {
  const _DissolveCard({
    required this.intro,
    required this.note,
    required this.actionLabel,
    required this.onPressed,
  });

  /// What dissolving does, in plain words.
  final String intro;

  /// Why the action is unavailable right now, or null when it is available.
  final String? note;

  /// The action's own label.
  final String actionLabel;

  /// Runs the dissolve; null disables the button.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final note = this.note;
    return Container(
      decoration: settingsCardDecoration(),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            intro,
            style: AppTypography.bodyMd.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          if (note != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              note,
              style: AppTypography.bodyMd.copyWith(color: AppColors.error),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.delete_forever_outlined),
              label: Text(actionLabel),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A small role pill.
class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: AppSpacing.xs,
    ),
    decoration: BoxDecoration(
      color: AppColors.surfaceContainer,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
    ),
    child: Text(
      label,
      style: AppTypography.labelMd.copyWith(color: AppColors.onSurfaceVariant),
    ),
  );
}

/// A single muted line where a list has nothing in it yet.
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    decoration: settingsCardDecoration(),
    padding: const EdgeInsets.all(AppSpacing.md),
    child: Text(
      text,
      style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
    ),
  );
}

/// The screen's primary action, at the shared Settings button height.
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: onPressed,
    icon: Icon(icon, size: 20),
    label: Text(label),
    style: FilledButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.onPrimary,
      textStyle: AppTypography.titleMd,
      minimumSize: const Size.fromHeight(settingsPrimaryButtonHeight),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
    ),
  );
}

/// The invite code, shown exactly once.
///
/// The plaintext exists only here and in the associate's hands: it is never
/// cached, never written to the database and never logged
/// ([GeneratedInvite.toString] omits it), so closing this sheet is the only
/// thing that can happen to it — it cannot be shown again from anywhere.
class _InviteCodeSheet extends ConsumerWidget {
  const _InviteCodeSheet({required this.invite});

  /// The freshly generated invite.
  final GeneratedInvite invite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.manageAssociates_inviteTitle, style: AppTypography.titleLg),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l.manageAssociates_inviteIntro,
              style: AppTypography.bodySm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: settingsCardDecoration(
                color: AppColors.surfaceContainer,
              ),
              child: SelectableText(
                invite.code,
                textAlign: TextAlign.center,
                style: AppTypography.titleLg.copyWith(letterSpacing: 4),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('invite-code-copy'),
                    onPressed: () => _copy(context, l),
                    icon: const Icon(Icons.copy_all_outlined, size: 18),
                    label: Text(l.manageAssociates_copyCode),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('invite-code-share'),
                    onPressed: () => _share(context, ref, l),
                    icon: const Icon(Icons.share_outlined, size: 18),
                    label: Text(l.manageAssociates_shareCode),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey('invite-code-close'),
                onPressed: () => Navigator.of(context).maybePop(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  textStyle: AppTypography.titleMd,
                  minimumSize: const Size.fromHeight(
                    settingsPrimaryButtonHeight,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                  ),
                ),
                child: Text(l.sharedActions_close),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Puts the code on the clipboard and says so.
  Future<void> _copy(BuildContext context, AppLocalizations l) async {
    await Clipboard.setData(ClipboardData(text: invite.code));
    if (!context.mounted) return;
    _say(context, l.manageAssociates_codeCopied);
  }

  /// Hands the code to the platform's share sheet.
  ///
  /// The same service Settings > Share uses, so a device with no share target
  /// still ends with the code on the clipboard instead of a dead tap.
  Future<void> _share(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
  ) async {
    final outcome = await ref
        .read(appShareServiceProvider)
        .shareApp(
          message: l.manageAssociates_inviteMessage(invite.code),
          subject: l.manageAssociates_inviteTitle,
        );
    if (!context.mounted) return;

    switch (outcome) {
      case AppShareOutcome.copiedToClipboard:
        _say(context, l.manageAssociates_codeCopied);
      case AppShareOutcome.failed:
        _say(context, l.manageAssociates_shareFailed);
      case AppShareOutcome.shared:
      case AppShareOutcome.dismissed:
        break;
    }
  }
}

/// Shows [message] over the current screen.
void _say(BuildContext context, String message) => ScaffoldMessenger.of(
  context,
).showSnackBar(SnackBar(content: Text(message)));
