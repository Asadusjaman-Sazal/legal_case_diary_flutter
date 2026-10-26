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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
import '../../../shared/providers/database_provider.dart';
import '../../../sync/connectivity_monitor.dart';
import '../../../sync/sync_service.dart';
import '../../../sync/sync_status_providers.dart';
import '../../auth/presentation/auth_viewmodel.dart';
import '../../auth/presentation/auth_widgets.dart';
import '../../cases/data/local/cases_dao.dart';
import '../../settings/presentation/settings_controls.dart';
import '../../settings/presentation/settings_menu_card.dart';
import '../../settings/presentation/settings_sub_page_modal.dart';
import '../data/account_mode.dart';
import '../data/avatar_image_processor.dart';
import '../data/firm_capacity.dart';
import '../data/firm_invite_code_store.dart';
import '../data/firm_logo_repository.dart';
import '../data/firm_logo_store.dart';
import '../data/firm_logo_sync.dart';
import 'image_crop_screen.dart';
import 'image_source_sheet.dart';
import 'picture_viewer_screen.dart';
import '../data/firm_repository.dart';
import '../data/profile_repository.dart' show AccountRole;

/// The account's own live case count — the "empty diary" qualification for
/// joining a firm (0.0.654).
///
/// Scoped exactly as `join_firm` scopes its refusal: the rows an individual
/// holds, with no firm. A count that has not arrived yet is null, and the join
/// button is not offered on a guess.
final _ownCaseCountProvider = StreamProvider<int>((ref) async* {
  final db = await ref.watch(databaseProvider.future);
  yield* CasesDao(db).watchNonDeletedCaseCount();
});

/// The firm screen: firm creation, invites and the roster.
///
/// Named **Manage Firm** once the account has one and **Create a Firm** until
/// then, in its own title and on its menu row (0.0.654, user request).
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

    return SettingsSubPageModal(
      // Titled by the account's own state, like its menu row: an individual is
      // here to create a firm, an owner to manage one.
      title: ref.watch(firmModeProvider)
          ? l.manageAssociates_title
          : l.manageAssociates_createFirmTitle,
      child: body,
    );
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
          name: firmName,
          onOpenPicture: () => _openLogoViewer(context),
          onRename: _busy || firm == null ? null : _renameFirm,
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
                        createdLabel: l.manageAssociates_inviteCreated(
                          AppDateUtils.formatDateDDMMYYYY(
                            invite.createdAt,
                            locale: locale,
                          ),
                        ),
                        // The server keeps only a hash, so the code is here only
                        // when **this device** generated the invite (user ruling
                        // 2026-10-26).
                        code: ref
                            .read(firmInviteCodeStoreProvider)
                            .codeFor(invite.id),
                        unavailableLabel:
                            l.manageAssociates_inviteCodeUnavailable,
                        copyLabel: l.manageAssociates_copyCode,
                        revokeLabel: l.manageAssociates_revokeInvite,
                        onCopy: _copyInviteCode,
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
    // The join path needs an empty diary: `join_firm` refuses an account that
    // already holds its own rows, so a non-zero count offers nothing.
    final ownCaseCount = ref.watch(_ownCaseCountProvider).value;
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
        // reads as two sections rather than one long card chain. It shares its
        // words with the page title while the account has no firm, so it is
        // keyed for anyone measuring the page (0.0.654).
        Text(
          l.manageAssociates_createFirmTitle,
          key: const ValueKey('firm-form-title'),
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
        // The other way into a firm (0.0.654, user request): an account that
        // signed up with its own diary can still join a colleague's chamber by
        // redeeming an owner's code, while that diary is empty.
        if (ownCaseCount == 0) ...[
          const SizedBox(height: AppSpacing.md),
          _SecondaryButton(
            key: const ValueKey('manage-associates-join-firm'),
            icon: Icons.group_add_outlined,
            label: l.manageAssociates_joinFirm,
            onPressed: _busy ? null : _joinFirm,
          ),
        ],
      ],
    );
  }

  /// Starts the join path: a paying individual is warned about their own plan
  /// first, then the code is asked for.
  ///
  /// The warning is not ceremony: joining does not pause or cancel the plan. It
  /// is **ignored** while the account holds a firm — only the firm's expiry
  /// counts there — and the paid time stays on the account and applies again if
  /// it leaves (plan, *A Member May Not Buy A Personal Plan*).
  Future<void> _joinFirm() async {
    final l = AppLocalizations.of(context);
    if (ref.read(premiumAccessProvider).value == true) {
      final proceed = await _confirm(
        context: context,
        title: l.manageAssociates_joinFirmPlanTitle,
        body: l.manageAssociates_joinFirmPlanBody,
        confirmLabel: l.manageAssociates_joinFirmContinue,
        // The Exit App-styled window the rest of this screen's windows use, in
        // the primary colour: this is a step forward, not a deletion.
        matchesInviteCodeWindow: true,
        destructive: false,
      );
      if (!proceed || !mounted) return;
    }

    final redemption = await showDialog<InviteRedemption>(
      context: context,
      builder: (_) => const _JoinFirmDialog(),
    );
    if (!mounted || redemption == null) return;
    _say(
      context,
      redemption.status == InviteRedemptionStatus.alreadyMember
          ? l.auth_errorAlreadyMember
          : l.auth_joinedFirm,
    );
  }

  /// Renames the firm, through a window carrying its current name.
  ///
  /// The write is the owner's one client-writable column on `firms`, and the
  /// refresh behind it is what brings the new name into the cache this card
  /// reads — the row itself is not this device's to keep.
  Future<void> _renameFirm() async {
    final l = AppLocalizations.of(context);
    final current = ref.read(accountFirmProvider).value;
    if (current == null) return;

    final name = await showDialog<String>(
      context: context,
      builder: (_) => _FirmNameDialog(initialName: current.name),
    );
    if (name == null || !mounted) return;

    await _run(() async {
      await ref.read(firmRepositoryProvider).updateFirmName(name);
      await ref.read(accountRefreshProvider)();
      if (!mounted) return;
      _say(context, l.manageAssociates_nameUpdated);
    });
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
      final invite = await _newInvite();
      if (!mounted) return;
      ref.invalidate(firmMembersListProvider);
      await _showInviteCode(invite);
    });
  }

  /// Puts an invite's remembered code on the clipboard and says so.
  ///
  /// A SnackBar is right here: no window is open on top of the roster when this
  /// runs, so the message lands where it can be read.
  Future<void> _copyInviteCode(String code) async {
    final l = AppLocalizations.of(context);
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    _say(context, l.manageAssociates_codeCopied);
  }

  /// Generates one invite and remembers its code on this device.
  ///
  /// The server keeps only a hash, so this is the one moment the plaintext can be
  /// kept — and keeping it is what lets the Outstanding Invites list print it
  /// again (user ruling 2026-10-26).
  Future<GeneratedInvite> _newInvite() async {
    final invite = await ref.read(firmRepositoryProvider).createInvite();
    await ref
        .read(firmInviteCodeStoreProvider)
        .remember(invite.inviteId, invite.code);
    return invite;
  }

  /// Generates one invite for an existing firm and shows its code.
  Future<void> _addAssociate() => _run(() async {
    final invite = await _newInvite();
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
      // The Invite Code window's corner and action size (user request).
      matchesInviteCodeWindow: true,
    );
    if (!confirmed) return;
    await _run(() async {
      await ref.read(firmRepositoryProvider).revokeInvite(inviteId);
      // A revoked code can never be redeemed, so this device stops remembering
      // it (no server copy exists to clean up — only the hash is stored).
      await ref.read(firmInviteCodeStoreProvider).forget(inviteId);
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

  /// Picks a chamber logo through the source chooser, selects its 148:100 area,
  /// shrinks it to 50 KB, and stores it locally first.
  ///
  /// The upload is detached: a save must never wait on the network, and a
  /// failure leaves the local picture waiting for the next refresh. A known
  /// lapsed entitlement is told up front; an entitlement still loading is
  /// allowed to try, because the bucket's policy is the boundary either way.
  Future<void> _pickFirmLogo(BuildContext viewerContext) async {
    final l = AppLocalizations.of(viewerContext);
    final navigator = Navigator.of(viewerContext);
    if (_busy) return;
    if (ref.read(premiumAccessProvider).value == false) {
      _say(context, l.manageAssociates_logoNeedsPlan);
      return;
    }
    final firmId = ref.read(accountFirmProvider).value?.id;
    if (firmId == null) return;

    final bytes = await pickPictureBytes(viewerContext);
    if (bytes == null || !mounted) return;

    try {
      final source = await prepareCropSource(bytes);
      if (!mounted) return;
      final selection = await navigator.push<CropSelection>(
        MaterialPageRoute(
          builder: (_) => ImageCropScreen(
            source: source,
            // The firm card's wide frame, so the logo shows exactly the area
            // the user chose (user ruling 2026-10-26).
            aspectRatio: _firmLogoFrameWidth / _firmLogoFrameHeight,
            circular: false,
            title: l.imageCrop_title,
          ),
        ),
      );
      if (selection == null || !mounted) return;
      final processed = await processCroppedImage(
        selection.source,
        selection.rect,
        targetWidth: avatarMaxSide,
        targetHeight:
            (avatarMaxSide * _firmLogoFrameHeight / _firmLogoFrameWidth)
                .round(),
        rotationQuarterTurns: selection.rotationQuarterTurns,
      );
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

  void _openLogoViewer(BuildContext context) {
    final l = AppLocalizations.of(context);
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PictureViewerScreen(
          title: l.firmLogo_title,
          hasImage: (ref) => ref.watch(firmLogoProvider) != null,
          editTooltip: l.sharedActions_edit,
          onEdit: _pickFirmLogo,
          onDelete: _removeFirmLogo,
          body: Consumer(
            builder: (context, ref, _) {
              final logo = ref.watch(firmLogoProvider);
              if (logo != null) {
                return Image.file(logo, fit: BoxFit.contain);
              }
              return Center(
                child: Container(
                  width: 360,
                  height: 243,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
                    border: Border.all(color: AppColors.outlineVariant),
                  ),
                  child: const Icon(
                    Icons.apartment_outlined,
                    color: AppColors.primary,
                    size: 96,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
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

  /// Opens the invite code in the app's pop-over window (0.0.651, user request:
  /// it used to rise as a bottom sheet).
  Future<void> _showInviteCode(GeneratedInvite invite) => showDialog<void>(
    context: context,
    builder: (_) => _InviteCodeDialog(invite: invite),
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

/// The chamber's identity: its logo in a rectangular frame and the firm's name
/// in bold beneath it.
///
/// The picture is the control (user request): the frame opens the full-screen
/// viewer, whose header carries Edit and Delete. The separate round picture
/// buttons under the frame are gone. The name keeps its own pencil, because it
/// is a field rather than a picture.
class _FirmCard extends ConsumerWidget {
  const _FirmCard({
    required this.name,
    required this.onOpenPicture,
    required this.onRename,
  });

  /// The firm's name, drawn bold and centred under the frame.
  final String name;

  /// Opens the full-screen logo viewer.
  final VoidCallback onOpenPicture;

  /// Opens the rename window (0.0.654, user request); null while a call runs.
  final VoidCallback? onRename;

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
          Center(
            child: GestureDetector(
              key: const ValueKey('firm-logo-open'),
              onTap: onOpenPicture,
              child: Container(
                key: const ValueKey('firm-logo-frame'),
                width: _firmLogoFrameWidth,
                height: _firmLogoFrameHeight,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
                  border: Border.all(color: AppColors.outlineVariant),
                  image: hasLogo
                      ? DecorationImage(
                          image: FileImage(logo),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                // The fallback the round avatar used to draw: the chamber is a
                // firm with no picture yet, not a missing image.
                child: hasLogo
                    ? null
                    : const Icon(
                        Icons.apartment_outlined,
                        color: AppColors.primary,
                        size: 32,
                      ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // The same round pencil the logo carries, beside the name: the name
          // takes the line when it needs it, and the pencil drops to the next
          // line rather than squeezing a long chamber name (user request).
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              Text(
                name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.titleLg.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              _PictureAction(
                key: const ValueKey('firm-name-change'),
                icon: Icons.edit,
                color: AppColors.primary,
                tooltip: l.manageAssociates_changeName,
                onTap: onRename,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Width of the firm's rectangular logo frame.
const double _firmLogoFrameWidth = 148;

/// Height of the firm's rectangular logo frame.
const double _firmLogoFrameHeight = 100;

/// A round picture action, drawn exactly like the Profile screen's edit and
/// delete buttons: a filled circle with a white icon and a white rim.
class _PictureAction extends StatelessWidget {
  const _PictureAction({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
    super.key,
  });

  /// The glyph inside the circle.
  final IconData icon;

  /// The circle's fill.
  final Color color;

  /// Spoken label for screen readers; there is no visible text (user request).
  final String tooltip;

  /// Runs the action; null greys the circle out while a call is in flight.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.4 : 1,
        child: Container(
          // The Profile picture edit/delete buttons' own padding (user request:
          // the firm's logo and name actions must match their size).
          padding: const EdgeInsets.all(AppSpacing.xs),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(color: AppColors.surface, width: 2),
          ),
          child: Icon(icon, color: AppColors.onPrimary, size: 18),
        ),
      ),
    ),
  );
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
            // The title the user chose for this card (0.0.653): *Seats and
            // Devices* described the parts rather than the number under it.
            // The shared `settingsSubscription_usageSeats` is untouched, because
            // Manage Plan's usage meters still use it.
            l.manageAssociates_capacityTitle,
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

/// One outstanding invite: when it was created, its code when this device knows
/// it, and the way to revoke it.
///
/// The server keeps only the code's SHA-256 hash, so the plaintext can only come
/// from the local store: an invite made on another phone says so instead of
/// inventing one.
class _InviteRow extends StatelessWidget {
  const _InviteRow({
    required this.id,
    required this.createdLabel,
    required this.code,
    required this.unavailableLabel,
    required this.copyLabel,
    required this.onCopy,
    required this.revokeLabel,
    required this.onRevoke,
  });

  final String id;
  final String createdLabel;

  /// The plaintext code, known only when this device generated the invite.
  final String? code;

  /// What the row says when this device never held the code.
  final String unavailableLabel;

  /// Spoken/screen-reader label for the tappable code.
  final String copyLabel;

  /// Copies the code; only called when [code] is non-null.
  final ValueChanged<String> onCopy;

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
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(createdLabel, style: AppTypography.bodyMd),
              const SizedBox(height: 2),
              // The code under the date, a step smaller and tappable to copy
              // (user request, 0.0.653). A code this device never saw says so
              // rather than disappearing, so the row keeps its shape.
              if (code != null)
                GestureDetector(
                  key: ValueKey('manage-associates-invite-code-$id'),
                  onTap: () => onCopy(code!),
                  child: Tooltip(
                    message: copyLabel,
                    child: Text(
                      code!,
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                )
              else
                Text(
                  unavailableLabel,
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        // Black fill with white text (user request): the revoke action is the
        // list's one control, and it wears the app's primary action colour.
        FilledButton(
          key: ValueKey('manage-associates-revoke-$id'),
          onPressed: onRevoke,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.35),
            disabledForegroundColor: AppColors.onPrimary,
            minimumSize: const Size(0, 40),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          ),
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
///
/// [matchesInviteCodeWindow] gives the window the **Invite Code** window's
/// corner (8 px) and its centred action size (112 x 48 at 16 pt). Only the revoke
/// confirmation asks for it — the other three windows on this screen keep the
/// app's standard confirmation look (user request, 0.0.653).
Future<bool> _confirm({
  required String title,
  required String body,
  required String confirmLabel,
  required BuildContext context,
  bool matchesInviteCodeWindow = false,
  bool destructive = true,
}) async {
  final l = AppLocalizations.of(context);
  final actionSize = matchesInviteCodeWindow ? const Size(112, 48) : null;
  const actionText = TextStyle(fontSize: 16);
  final answer = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        title,
        // Centred only where the request asked for the Invite Code window: the
        // other windows are unchanged.
        textAlign: matchesInviteCodeWindow ? TextAlign.center : null,
      ),
      shape: matchesInviteCodeWindow
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius * 2),
            )
          : null,
      // Scrollable: the removal warning is several sentences long on purpose
      // (the owner is told what cannot be reached, and what to do about it), and
      // a fixed Text would clip it on a phone.
      content: SingleChildScrollView(child: Text(body)),
      actionsAlignment: matchesInviteCodeWindow
          ? MainAxisAlignment.center
          : null,
      actions: [
        TextButton(
          style: matchesInviteCodeWindow
              ? TextButton.styleFrom(
                  minimumSize: actionSize,
                  textStyle: actionText,
                )
              : null,
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l.sharedActions_cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            // Red only where the action destroys something: the join warning's
            // *Continue* is a step forward and keeps the primary colour.
            backgroundColor: destructive ? AppColors.error : AppColors.primary,
            foregroundColor: destructive
                ? AppColors.onError
                : AppColors.onPrimary,
            minimumSize: actionSize,
            textStyle: matchesInviteCodeWindow ? actionText : null,
          ),
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
          // Full height and filled red with white text (user request, 0.0.653):
          // the outlined red button read as an optional action, and a dissolve
          // is the most consequential one on this screen.
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.delete_forever_outlined),
              label: Text(actionLabel),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: AppColors.onError,
                disabledBackgroundColor: AppColors.error.withValues(
                  alpha: 0.38,
                ),
                minimumSize: const Size.fromHeight(settingsPrimaryButtonHeight),
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

/// A secondary action at the primary button's size: the same height and corner,
/// outlined instead of filled, so it reads as the other half of a pair rather
/// than a lesser link (0.0.654).
class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: Icon(icon, size: 20),
    label: Text(label),
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.primary,
      textStyle: AppTypography.titleMd,
      side: const BorderSide(color: AppColors.primary),
      minimumSize: const Size.fromHeight(settingsPrimaryButtonHeight),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
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
class _InviteCodeDialog extends ConsumerStatefulWidget {
  const _InviteCodeDialog({required this.invite});

  /// The freshly generated invite.
  final GeneratedInvite invite;

  @override
  ConsumerState<_InviteCodeDialog> createState() => _InviteCodeDialogState();
}

class _InviteCodeDialogState extends ConsumerState<_InviteCodeDialog> {
  /// The one line of feedback the window shows, or null before any action.
  ///
  /// Shown **inside** the window rather than as a SnackBar: a SnackBar lives in
  /// the Scaffold behind this dialog, so the confirmation the user asked for (a
  /// copy proves itself) would never be seen.
  String? _note;

  /// Whether [_note] is a success (green tick) or a failure (red).
  bool _noteOk = true;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Dialog(
      // The Exit App window's shape and white panel, with its side margins
      // pulled in from 40 to 16 (0.0.652, user request): the Exit-App-sized
      // buttons are wide, and at the old margins they could not share a row on
      // any phone.
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.lg,
      ),
      backgroundColor: AppColors.surfaceContainerLowest,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius * 2),
      ),
      child: SingleChildScrollView(
        // 16 px inside rather than 24, so the buttons get the room the wider
        // window bought them.
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Centred, like the Exit App window's title.
            Text(
              l.manageAssociates_inviteTitle,
              textAlign: TextAlign.center,
              style: AppTypography.titleLg,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l.manageAssociates_inviteIntro,
              textAlign: TextAlign.center,
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
                widget.invite.code,
                textAlign: TextAlign.center,
                style: AppTypography.titleLg.copyWith(letterSpacing: 4),
              ),
            ),
            if (_note != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                key: const ValueKey('invite-code-note'),
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _noteOk ? Icons.check_circle : Icons.error_outline,
                    size: 16,
                    color: _noteOk ? AppColors.success : AppColors.error,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      _note!,
                      style: AppTypography.bodySm.copyWith(
                        color: _noteOk ? AppColors.success : AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            // The Exit App window's action size (112 x 48 at 16 pt), in a Wrap
            // so the narrow window stacks them instead of overflowing — and so
            // a longer Bengali label grows rather than clipping. The rows are
            // spaced exactly as the code box and the buttons above them are
            // (0.0.654, user request), so the window reads as one column.
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: AppSpacing.lg,
              children: [
                OutlinedButton(
                  key: const ValueKey('invite-code-copy'),
                  onPressed: _copy,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(112, 48),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                  child: Text(l.manageAssociates_copyCode),
                ),
                OutlinedButton(
                  key: const ValueKey('invite-code-share'),
                  onPressed: _share,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(112, 48),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                  child: Text(l.manageAssociates_shareCode),
                ),
                FilledButton(
                  key: const ValueKey('invite-code-close'),
                  onPressed: () => Navigator.of(context).maybePop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    minimumSize: const Size(112, 48),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                  child: Text(l.sharedActions_close),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Puts the code on the clipboard and confirms it in the window.
  Future<void> _copy() async {
    final l = AppLocalizations.of(context);
    await Clipboard.setData(ClipboardData(text: widget.invite.code));
    if (!mounted) return;
    setState(() {
      _noteOk = true;
      _note = l.manageAssociates_codeCopied;
    });
  }

  /// Hands the code to the platform's share sheet.
  ///
  /// The same service Settings > Share uses, so a device with no share target
  /// still ends with the code on the clipboard instead of a dead tap — and that
  /// outcome is reported in the same line, for the same reason.
  Future<void> _share() async {
    final l = AppLocalizations.of(context);
    final outcome = await ref
        .read(appShareServiceProvider)
        .shareApp(
          message: l.manageAssociates_inviteMessage(widget.invite.code),
          subject: l.manageAssociates_inviteTitle,
        );
    if (!mounted) return;

    switch (outcome) {
      case AppShareOutcome.copiedToClipboard:
        setState(() {
          _noteOk = true;
          _note = l.manageAssociates_codeCopied;
        });
      case AppShareOutcome.failed:
        setState(() {
          _noteOk = false;
          _note = l.manageAssociates_shareFailed;
        });
      case AppShareOutcome.shared:
      case AppShareOutcome.dismissed:
        break;
    }
  }
}

/// The Join a Firm window: the owner's invitation code, and the two actions.
///
/// Built like the Invite Code window — the same panel, corner and action size —
/// so the app's firm windows read as one family. A refusal is shown **in** the
/// window rather than behind it, so a mistyped code can be corrected without
/// reopening anything.
class _JoinFirmDialog extends ConsumerStatefulWidget {
  const _JoinFirmDialog();

  @override
  ConsumerState<_JoinFirmDialog> createState() => _JoinFirmDialogState();
}

class _JoinFirmDialogState extends ConsumerState<_JoinFirmDialog> {
  final TextEditingController _code = TextEditingController();

  bool _busy = false;
  Object? _failure;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final canSend = !_busy && _code.text.trim().isNotEmpty;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.lg,
      ),
      backgroundColor: AppColors.surfaceContainerLowest,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius * 2),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.manageAssociates_joinFirmTitle,
              textAlign: TextAlign.center,
              style: AppTypography.titleLg,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l.manageAssociates_joinFirmIntro,
              textAlign: TextAlign.center,
              style: AppTypography.bodySm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const ValueKey('join-firm-code'),
              controller: _code,
              enabled: !_busy,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              style: AppTypography.bodyLg,
              // The Send button reads the field, so a keystroke must rebuild it.
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: l.manageAssociates_joinFirmCodeLabel,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
              ),
            ),
            if (_failure != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                failureText(l, _failure) ?? l.auth_errorUnknown,
                key: const ValueKey('join-firm-error'),
                textAlign: TextAlign.center,
                style: AppTypography.bodySm.copyWith(color: AppColors.error),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: AppSpacing.lg,
              children: [
                TextButton(
                  key: const ValueKey('join-firm-cancel'),
                  onPressed: _busy
                      ? null
                      : () => Navigator.of(context).maybePop(),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(112, 48),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                  child: Text(l.sharedActions_cancel),
                ),
                FilledButton(
                  key: const ValueKey('join-firm-send'),
                  onPressed: canSend ? _send : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    minimumSize: const Size(112, 48),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                  child: Text(l.manageAssociates_joinFirmSend),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Redeems the code and closes with the server's answer.
  ///
  /// The membership is the server's to grant, so nothing local is written here:
  /// the profile refresh caches the new firm and role, and the delta pull that
  /// follows (detached, because the join has already succeeded) brings the
  /// chamber's rows. A joining account has no rows of its own, which is why the
  /// pull cannot overwrite anything.
  Future<void> _send() async {
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      final redemption = await ref
          .read(firmRepositoryProvider)
          .redeemInvite(_code.text.trim());
      await ref.read(accountRefreshProvider)();
      unawaited(ref.read(syncServiceProvider).syncNow(force: true, pull: true));
      if (!mounted) return;
      Navigator.of(context).maybePop(redemption);
    } on Object catch (error) {
      if (!mounted) return;
      // Recorded here for the same reason the screen records its own: a refused
      // code is exactly what the diagnostics log has to be able to answer.
      recordFailure(ref.read(errorLogProvider), 'firm.join', error);
      setState(() {
        _busy = false;
        _failure = error;
      });
    }
  }
}

/// The rename window: the firm's current name, editable, with Cancel and Save.
class _FirmNameDialog extends StatefulWidget {
  const _FirmNameDialog({required this.initialName});

  /// The name the window opens on.
  final String initialName;

  @override
  State<_FirmNameDialog> createState() => _FirmNameDialogState();
}

class _FirmNameDialogState extends State<_FirmNameDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initialName,
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final canSave = _name.text.trim().isNotEmpty;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.lg,
      ),
      backgroundColor: AppColors.surfaceContainerLowest,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius * 2),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.manageAssociates_changeNameTitle,
              textAlign: TextAlign.center,
              style: AppTypography.titleLg,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const ValueKey('firm-name-input'),
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              style: AppTypography.bodyLg,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: l.manageAssociates_firmNameLabel,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: AppSpacing.lg,
              children: [
                TextButton(
                  key: const ValueKey('firm-name-cancel'),
                  onPressed: () => Navigator.of(context).maybePop(),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(112, 48),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                  child: Text(l.sharedActions_cancel),
                ),
                FilledButton(
                  key: const ValueKey('firm-name-save'),
                  onPressed: canSave
                      ? () => Navigator.of(context).maybePop(_name.text.trim())
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    minimumSize: const Size(112, 48),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                  child: Text(l.sharedActions_save),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows [message] over the current screen.
void _say(BuildContext context, String message) => ScaffoldMessenger.of(
  context,
).showSnackBar(SnackBar(content: Text(message)));
