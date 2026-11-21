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
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/errors/error_log.dart';
import '../../../core/errors/error_log_provider.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/providers/device_providers.dart';
import '../../../core/providers/print_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/app_share_service.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_dialog_actions.dart';
import '../../../shared/widgets/usage_meter.dart';
import '../../../sync/connectivity_monitor.dart';
import '../../../sync/sync_service.dart';
import '../../../sync/sync_status_providers.dart';
import '../../auth/data/device_registration.dart';
import '../../auth/presentation/auth_viewmodel.dart';
import '../../auth/presentation/auth_widgets.dart';
import '../../settings/presentation/settings_controls.dart';
import '../../settings/presentation/settings_menu_card.dart';
import '../../settings/presentation/settings_sub_page_modal.dart';
import '../data/account_mode.dart';
import '../data/avatar_image_processor.dart';
import '../data/firm_capacity.dart';
import '../data/firm_devices.dart';
import '../data/firm_invite_code_store.dart';
import '../data/firm_logo_repository.dart';
import '../data/firm_logo_store.dart';
import '../data/firm_logo_sync.dart';
import 'image_crop_screen.dart';
import 'image_source_sheet.dart';
import 'picture_viewer_screen.dart';
import '../data/firm_repository.dart';
import '../data/profile_picture_store.dart';
import '../data/profile_repository.dart' show AccountRole;

/// The firm screen: firm creation, invites and the roster.
///
/// Named **Manage Firm** once the account has one and **Create a Firm** until
/// then, in its own title and on its menu row (0.0.654, user request). A member
/// of somebody else's chamber reads the same page as a **chamber-named,
/// read-only** view of it (0.0.666, user request): the firm's identity and its
/// people, with no control anywhere on it.
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

  /// Which server call is in flight, or null when nothing is running.
  ///
  /// A value rather than a bare flag, so only the button that started the work
  /// draws a spinner; every other control is still disabled through [_busy].
  _BusyAction? _busyAction;

  /// Whether any server call is in flight.
  bool get _busy => _busyAction != null;

  /// The last failure to show; cleared when a new attempt starts.
  Object? _failure;

  /// Whether the capacity card's device lists are open.
  bool _devicesExpanded = false;

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
    final identity = ref.watch(authIdentityProvider);
    final signedIn = identity != null;
    final owner = ref.watch(canManageFirmProvider);
    // The only picture this device can read is the signed-in account's own, so
    // its row shows the saved file and every other row shows initials.
    final selfUserId = identity?.userId ?? '';

    final Widget body;
    if (!online) {
      body = _MessageBody(l.auth_errorFirmAdminOffline);
    } else if (!signedIn) {
      // A firm needs an account to belong to; there is nothing to administer on
      // a device that never signed in.
      body = _MessageBody(l.sharedMessages_signInRequired);
    } else if (owner) {
      body = _rosterBody(l, selfUserId);
    } else if (ref.watch(canOpenManageAssociatesProvider)) {
      body = _firmSetupBody(l);
    } else if (ref.watch(firmMemberProvider)) {
      // An associate or viewer of somebody else's chamber: what the firm is and
      // who is in it, with nothing to change (0.0.666, user request).
      body = _memberBody(l, selfUserId);
    } else {
      // A firm member who is not the owner: the entry point hides this screen,
      // and a deep link into it must not offer a create-firm form either — the
      // server would refuse it, and an associate who took it at face value would
      // be told they could leave their own firm.
      body = _MessageBody(l.manageAssociates_ownerOnly);
    }

    return SettingsSubPageModal(
      // Titled by the account's own state, like its menu row: an individual is
      // here to create a firm, an owner to manage one, and a member to read the
      // chamber they belong to — which is the chamber's own name.
      title: ref.watch(firmMemberProvider)
          ? _firmTitle(l)
          : ref.watch(firmModeProvider)
          ? l.manageAssociates_title
          : l.manageAssociates_createFirmTitle,
      // The two lists this page draws are live server reads, not synced
      // tables, so the pull needs its own reload behind the sync (0.0.712).
      onReload: _reloadFirmReads,
      child: body,
    );
  }

  /// Re-reads the roster and the outstanding invites after a pull.
  ///
  /// The shell's pull runs the diary sync and then this. Without it a pull on
  /// this page would spin, release and show exactly the rows it already had:
  /// `firm_members` and `firm_invites` never travel through the sync. Both are
  /// awaited so the spinner covers the fetch, and a failed read is settled here
  /// rather than escaping into the gesture — the page already draws it as its
  /// own banner.
  Future<void> _reloadFirmReads() async {
    ref.invalidate(firmMembersListProvider);
    ref.invalidate(firmInvitesListProvider);
    // The expanded capacity card lists the chamber's devices from the same
    // server answer the Devices screen reads; a pull re-asks for it too.
    ref.invalidate(firmDeviceListProvider);
    try {
      await Future.wait([
        ref.read(firmMembersListProvider.future),
        ref.read(firmInvitesListProvider.future),
      ]);
    } on Object {
      // Shown by the screen's banner; the pull itself must finish.
    }
  }

  /// The owner's view: the firm, the invite action, the roster and the invites.
  ///
  /// The roster and the outstanding invites are both **live reads** and both are
  /// invalidated rather than cached after a change, which is what keeps this
  /// screen from becoming a second copy of the firm's server state (AGENTS.md
  /// rule 4: `firm_members` and `firm_invites` are not this device's to own).
  Widget _rosterBody(AppLocalizations l, String selfUserId) {
    final firm = ref.watch(accountFirmProvider).value;
    final firmName = firm?.name ?? '';
    final members = ref.watch(firmMembersListProvider);
    final avatarFile = ref.watch(profilePictureProvider);
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
          readOnly: false,
          onOpenPicture: () => _openLogoViewer(context),
          onRename: _busy || firm == null ? null : _renameFirm,
        ),
        if (capacity != null) ...[
          const SizedBox(height: AppSpacing.gutter),
          _CapacityCard(
            capacity: capacity,
            l: l,
            expanded: _devicesExpanded,
            onToggle: () =>
                setState(() => _devicesExpanded = !_devicesExpanded),
          ),
        ],
        const SizedBox(height: AppSpacing.gutter),
        _sectionTitle(l.manageAssociates_sectionMembers),
        const SizedBox(height: AppSpacing.sm),
        members.when(
          data: (rows) => _memberList(
            rows: rows,
            l: l,
            selfUserId: selfUserId,
            avatarFile: avatarFile,
            editable: true,
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
        // The action sits at the end of its own list (user request): Add
        // Associate is the last thing under the Members heading.
        const SizedBox(height: AppSpacing.md),
        _PrimaryButton(
          icon: Icons.person_add_alt_1_outlined,
          label: l.manageAssociates_addAssociate,
          busy: _busyAction == _BusyAction.add,
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
        _sectionTitle(l.manageAssociates_sectionInvites),
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
                        newCodeLabel: l.manageAssociates_newCode,
                        deleteLabel: l.manageAssociates_deleteInvite,
                        onCopy: _copyInviteCode,
                        onNewCode: _busy
                            ? null
                            : () => _replaceInvite(invite.id),
                        onDelete: _busy ? null : () => _deleteInvite(invite.id),
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
        _sectionTitle(l.manageAssociates_sectionFirm),
        const SizedBox(height: AppSpacing.sm),
        _DissolveCard(
          intro: l.manageAssociates_dissolveIntro,
          busy: _busyAction == _BusyAction.dissolve,
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

  /// The Members list, shared by the owner's editable page and the member's
  /// read-only one: owner first, then names A–Z (blank names last), with the
  /// "only member" line when nobody else has joined.
  Widget _memberList({
    required List<FirmMemberSummary> rows,
    required AppLocalizations l,
    required String selfUserId,
    required File? avatarFile,
    required bool editable,
  }) {
    final sorted = _sortedMembers(rows);
    final hasAssociates = rows.any((row) => row.role != AccountRole.owner);
    if (sorted.isEmpty) {
      return _InfoRow(text: l.manageAssociates_noMembers);
    }
    return Column(
      children: [
        for (final member in sorted) ...[
          _MemberRow(
            member: member,
            l: l,
            selfUserId: selfUserId,
            avatarFile: avatarFile,
            // The owner's own row is not the roster's to edit: their
            // permissions are structural (`firms.owner_id`), so a flag on their
            // `firm_members` row would not change what they may do.
            onTap: editable && member.role != AccountRole.owner
                ? () => _editMember(member)
                : null,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (!hasAssociates) _InfoRow(text: l.manageAssociates_aloneInFirm),
      ],
    );
  }

  /// The chamber's own name, or the plain *Firm* while its row has not been
  /// pulled yet — a header is never left empty.
  String _firmTitle(AppLocalizations l) {
    final name = ref.watch(accountFirmProvider).value?.name ?? '';
    return name.isEmpty ? l.settingsFirm_title : name;
  }

  /// A member's view of the chamber: its identity, then its people, read-only.
  ///
  /// There is nothing here to act on and that is the whole point: inviting,
  /// permission toggles, renaming, dissolving and the capacity card are the
  /// owner's (and the capacity card's number is not even readable by a member —
  /// the server hands an account only its own devices). The roster is the same
  /// live read the owner's body uses, which the server's own rules already
  /// allow for every member of the chamber, and every row is drawn without a
  /// tap so the page cannot look like the owner's.
  Widget _memberBody(AppLocalizations l, String selfUserId) {
    final members = ref.watch(firmMembersListProvider);
    final avatarFile = ref.watch(profilePictureProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.edgeMargin,
        AppSpacing.md,
        AppSpacing.edgeMargin,
        AppSpacing.xl,
      ),
      children: [
        _FirmCard(name: _firmTitle(l), readOnly: true),
        const SizedBox(height: AppSpacing.gutter),
        _sectionTitle(l.manageAssociates_sectionMembers),
        const SizedBox(height: AppSpacing.sm),
        members.when(
          data: (rows) => _memberList(
            rows: rows,
            l: l,
            selfUserId: selfUserId,
            avatarFile: avatarFile,
            editable: false,
          ),
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          ),
          // A failed read says so rather than showing an empty chamber.
          error: (error, _) => AuthErrorBanner(
            text: failureText(l, error) ?? l.auth_errorUnknown,
          ),
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
      ],
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
    GeneratedInvite? created;
    await _run(() async {
      final repository = ref.read(firmRepositoryProvider);
      await repository.ensureFirm(name);
      // The cached profile and membership carry the new firm and the owner role;
      // without this the screen would still believe it is an individual and this
      // account would not count as firm mode until the next launch.
      await ref.read(accountRefreshProvider)();
      created = await _newInvite();
      if (!mounted) return;
      ref.invalidate(firmMembersListProvider);
    });
    final invite = created;
    if (invite == null || !mounted) return;
    // Shown after the call finishes, so no button keeps a spinner behind a
    // window the user may leave open.
    await _showInviteCode(invite);
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
  Future<void> _addAssociate() async {
    GeneratedInvite? created;
    await _run(() async {
      created = await _newInvite();
      if (!mounted) return;
      // The new code joins the outstanding list as soon as this sheet closes.
      ref.invalidate(firmInvitesListProvider);
    }, busyWith: _BusyAction.add);
    final invite = created;
    if (invite == null || !mounted) return;
    await _showInviteCode(invite);
  }

  /// Deletes an unused invite, after confirming it.
  ///
  /// The confirmation is not ceremony: a deleted code stops working instantly
  /// and its plaintext is unrecoverable, so the associate holding it cannot be
  /// re-told what it was — the owner has to send a fresh one.
  Future<void> _deleteInvite(String inviteId) async {
    final l = AppLocalizations.of(context);
    final confirmed = await _confirm(
      context: context,
      title: l.manageAssociates_deleteInviteTitle,
      body: l.manageAssociates_deleteInviteBody,
      confirmLabel: l.manageAssociates_deleteInvite,
      // The Invite Code window's corner and action size (user request).
      matchesInviteCodeWindow: true,
    );
    if (!confirmed) return;
    await _run(() async {
      await ref.read(firmRepositoryProvider).revokeInvite(inviteId);
      // A deleted code can never be redeemed, so this device stops remembering
      // it (no server copy exists to clean up — only the hash is stored).
      await ref.read(firmInviteCodeStoreProvider).forget(inviteId);
      if (!mounted) return;
      ref.invalidate(firmInvitesListProvider);
      _say(context, l.manageAssociates_inviteDeleted);
    });
  }

  /// Replaces an invite this device cannot show with a fresh one.
  ///
  /// The old code is still held by somebody — the server only has its hash — so
  /// the replacement is confirmed before it is retired. The new plaintext is
  /// remembered locally and shown in the same window a new invite uses.
  Future<void> _replaceInvite(String inviteId) async {
    final l = AppLocalizations.of(context);
    final confirmed = await _confirm(
      context: context,
      title: l.manageAssociates_newCodeTitle,
      body: l.manageAssociates_deleteInviteBody,
      confirmLabel: l.manageAssociates_newCode,
      matchesInviteCodeWindow: true,
    );
    if (!confirmed) return;
    GeneratedInvite? created;
    await _run(() async {
      final repository = ref.read(firmRepositoryProvider);
      await repository.revokeInvite(inviteId);
      await ref.read(firmInviteCodeStoreProvider).forget(inviteId);
      created = await _newInvite();
      if (!mounted) return;
      ref.invalidate(firmInvitesListProvider);
    });
    final invite = created;
    if (invite == null || !mounted) return;
    await _showInviteCode(invite);
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
    }, busyWith: _BusyAction.dissolve);
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
  /// no failure can be silently dropped. [busyWith] names the button that shows
  /// the spinner while the call runs; every other control is disabled by
  /// [_busy] but keeps its normal face.
  Future<void> _run(
    Future<void> Function() action, {
    _BusyAction busyWith = _BusyAction.other,
  }) async {
    final l = AppLocalizations.of(context);
    setState(() {
      _busyAction = busyWith;
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
      final text = failureText(l, error) ?? l.auth_errorUnknown;
      setState(() => _failure = error);
      // The banner at the top of the list can be scrolled past, so the same
      // sentence is shown where the user is looking (user request).
      _say(context, text);
    } finally {
      if (mounted) setState(() => _busyAction = null);
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
    required this.readOnly,
    this.onOpenPicture,
    this.onRename,
  });

  /// The firm's name, drawn bold and centred under the frame.
  final String name;

  /// A member's copy: the frame and the name are shown, but neither is a
  /// control and the name carries no pencil (0.0.666, user request).
  final bool readOnly;

  /// Opens the full-screen logo viewer.
  final VoidCallback? onOpenPicture;

  /// Opens the rename window (0.0.654, user request); null while a call runs.
  final VoidCallback? onRename;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final logo = ref.watch(firmLogoProvider);
    final frame = _firmLogoFrame(logo == null ? null : FileImage(logo));

    return Container(
      decoration: settingsCardDecoration(),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            // A member may look at the chamber's picture, not change it: the
            // frame is a plain picture for them and the viewer's Edit and Delete
            // therefore never open (0.0.666, user request).
            child: readOnly
                ? frame
                : GestureDetector(
                    key: const ValueKey('firm-logo-open'),
                    onTap: onOpenPicture,
                    child: frame,
                  ),
          ),
          // An empty frame is tappable, but nothing on it said so (user
          // request): the caption makes the control visible.
          if (!readOnly && logo == null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              l.manageAssociates_tapToAddLogo,
              textAlign: TextAlign.center,
              style: AppTypography.bodySm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
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
              if (!readOnly)
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

/// The chamber's logo frame: the picture when one is saved, the apartment
/// glyph until then. Extracted so the member's read-only card can draw the
/// very same frame as a plain picture (0.0.666).
Widget _firmLogoFrame(ImageProvider? logo) => Container(
  key: const ValueKey('firm-logo-frame'),
  width: _firmLogoFrameWidth,
  height: _firmLogoFrameHeight,
  decoration: BoxDecoration(
    color: AppColors.surfaceContainerLow,
    borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
    border: Border.all(color: AppColors.outlineVariant),
    image: logo == null
        ? null
        : DecorationImage(image: logo, fit: BoxFit.cover),
  ),
  // The fallback the round avatar used to draw: the chamber is a firm with no
  // picture yet, not a missing image.
  child: logo != null
      ? null
      : const Icon(
          Icons.apartment_outlined,
          color: AppColors.primary,
          size: 32,
        ),
);

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

  /// The visible circle is small, so the tap target is padded to 48 px around
  /// it and the same words are announced as the tooltip (user request).

  /// The glyph inside the circle.
  final IconData icon;

  /// The circle's fill.
  final Color color;

  /// Spoken label for screen readers; there is no visible text (user request).
  final String tooltip;

  /// Runs the action; null greys the circle out while a call is in flight.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    label: tooltip,
    child: Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Opacity(
              opacity: onTap == null ? 0.4 : 1,
              child: Container(
                // The Profile picture edit/delete buttons' own padding (user
                // request: the firm's logo and name actions match their size).
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
        ),
      ),
    ),
  );
}

/// The owner's shared-capacity card: slots used, a pending shrink, the states
/// that block a new join, and the chamber's device lists behind the numbers.
///
/// The lists live **inside** this card (user request): the arrow sits on the
/// card's own bottom edge, and opening it continues the same card rather than
/// starting a second one.
class _CapacityCard extends StatelessWidget {
  const _CapacityCard({
    required this.capacity,
    required this.l,
    required this.expanded,
    required this.onToggle,
  });

  final FirmCapacityView capacity;
  final AppLocalizations l;

  /// Whether the chamber's device lists are open under the same card edge.
  final bool expanded;

  /// Opens or folds the device lists.
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final shrinkDate = capacity.shrinkAt == null
        ? ''
        : AppDateUtils.formatDateDDMMYYYY(
            capacity.shrinkAt!.millisecondsSinceEpoch,
            locale: locale,
          );
    // Counts follow the active language's digits, as every other number in
    // the app does (user request for বাংলা: "২", never "2").
    String digits(int value) =>
        AppDateUtils.formatDigits(value, locale, grouping: false);

    return Container(
      decoration: settingsCardDecoration(),
      // No bottom inset: the toggle is the card's own bottom edge, not a
      // separate control under it (user request).
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The same meter Manage Plan draws, so the two screens can never
          // disagree about the shape of the same numbers (user request).
          UsageMeter(
            label: l.settingsSubscription_usageSeats,
            used: capacity.used,
            limit: capacity.slots,
          ),
          // The split is hidden while the lists are open, because the lists
          // themselves are the split (user request).
          if (!expanded) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              l.manageAssociates_capacityBreakdown(
                digits(capacity.associates),
                digits(capacity.ownerDevices),
              ),
              style: AppTypography.bodySm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
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
                digits(capacity.pendingSlots ?? 0),
                digits(capacity.associates),
                digits(capacity.ownerDevices),
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
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const ValueKey('manage-associates-manage-plan'),
                onPressed: () => context.push(AppRoutes.paywall),
                child: Text(l.settingsSubscription_managePlanTitle),
              ),
            ),
          ],
          // Open: the two lists continue the card, then the same arrow folds
          // them again.
          if (expanded) ...[
            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1, color: AppColors.outlineVariant),
            const SizedBox(height: AppSpacing.xs),
            _ChamberDevices(l: l),
          ],
          _DevicesToggle(
            expanded: expanded,
            label: expanded
                ? l.manageAssociates_hideDevices
                : l.manageAssociates_showDevices,
            onPressed: onToggle,
          ),
        ],
      ),
    );
  }
}

/// The arrow under the capacity card: opens the chamber's device lists.
class _DevicesToggle extends StatelessWidget {
  const _DevicesToggle({
    required this.expanded,
    required this.label,
    required this.onPressed,
  });

  /// Whether the lists below are open.
  final bool expanded;

  /// The button's own label, and its tooltip.
  final String label;

  /// Toggles the lists.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Center(
    child: IconButton(
      key: const ValueKey('manage-associates-devices-toggle'),
      onPressed: onPressed,
      tooltip: label,
      icon: Icon(
        expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
      ),
    ),
  );
}

/// The chamber's devices, read-only and split like the Devices screen: the
/// owner's own devices, then the associates'.
///
/// The two sections read the same answers the Devices screen does
/// (`deviceGateProvider` and `firm_device_list`); no removal is offered here,
/// because this page lists what the capacity number is made of.
class _ChamberDevices extends ConsumerWidget {
  const _ChamberDevices({required this.l});

  final AppLocalizations l;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = Localizations.localeOf(context).toString();
    String digits(int value) =>
        AppDateUtils.formatDigits(value, locale, grouping: false);

    // The capacity card is only built when the gate answered (the capacity
    // provider refuses a null one), so this is the list behind its count.
    final ownerDevices =
        ref.watch(deviceGateProvider).value?.devices ??
        const <RegisteredDevice>[];
    final firm = ref.watch(firmDeviceListProvider);
    final associates = firm.value?.associateDevices;

    // No card of its own: these lists are drawn inside the capacity card, so
    // the two read as one connected surface (user request).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ChamberDevicesHeading(
          l.devices_ownerSectionCount(digits(ownerDevices.length)),
        ),
        for (final device in ownerDevices) ...[
          _ChamberDeviceRow(
            title: device.isCurrent
                ? '${device.label} · ${l.devices_thisDevice}'
                : device.label,
            platform: device.platform,
            lastSeenAt: device.lastSeenAt,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        const Divider(height: 1, color: AppColors.outlineVariant),
        _ChamberDevicesHeading(
          associates == null
              ? l.devices_associateSection
              : l.devices_associateSectionCount(digits(associates.length)),
        ),
        if (firm.isLoading && associates == null)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.sm),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (firm.hasError && associates == null)
          Text(
            l.devices_firmUnavailable,
            style: AppTypography.bodyMd.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          )
        else if (associates == null || associates.isEmpty)
          Text(
            l.devices_noAssociateDevices,
            style: AppTypography.bodyMd.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          )
        else
          for (final device in associates) ...[
            _ChamberDeviceRow(
              title: device.memberName.isEmpty ? '—' : device.memberName,
              subtitle: device.label,
              platform: device.platform,
              lastSeenAt: device.lastSeenAt,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
      ],
    );
  }
}

/// One device in the expanded list, drawn like the Devices screen's rows.
class _ChamberDeviceRow extends StatelessWidget {
  const _ChamberDeviceRow({
    required this.title,
    required this.platform,
    this.subtitle,
    this.lastSeenAt,
  });

  final String title;
  final String? subtitle;
  final String platform;
  final DateTime? lastSeenAt;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final seen = lastSeenAt;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(
            platform == 'windows'
                ? Icons.desktop_windows_outlined
                : Icons.smartphone_outlined,
            color: AppColors.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.gutter),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.labelLg.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle!,
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
                if (seen != null)
                  Text(
                    l.devices_lastUsed(
                      AppDateUtils.formatDateTimeDDMMYYYY(
                        seen.millisecondsSinceEpoch,
                        locale: Localizations.localeOf(context).toString(),
                      ),
                    ),
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A section's label inside the expanded device list.
class _ChamberDevicesHeading extends StatelessWidget {
  const _ChamberDevicesHeading(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.xs,
      vertical: AppSpacing.sm,
    ),
    child: Text(
      title,
      style: AppTypography.labelLg.copyWith(
        color: AppColors.onSurfaceVariant,
        letterSpacing: 0.7,
      ),
    ),
  );
}

/// One member: picture or initials, name, what they may do, and their role.
class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.l,
    required this.selfUserId,
    required this.avatarFile,
    this.onTap,
  });

  final FirmMemberSummary member;
  final AppLocalizations l;

  /// The signed-in account, whose saved picture is the only one this device can
  /// read; every other row falls back to initials.
  final String selfUserId;

  /// The signed-in account's saved profile picture, when it has one.
  final File? avatarFile;

  /// Opens the permissions sheet; null for the owner's own row, which is not
  /// editable from the roster, and for every row in a member's read-only view.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final picture = member.userId == selfUserId ? avatarFile : null;
    final content = Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            key: ValueKey('manage-associates-avatar-${member.userId}'),
            width: 40,
            height: 40,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            ),
            child: picture == null
                ? Center(
                    child: Text(
                      _initials(member.fullName),
                      style: AppTypography.titleMd.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                : Image.file(picture, fit: BoxFit.cover),
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
                const SizedBox(height: 2),
                Text(
                  _permissionSummary(l, member),
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
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
/// it, and the copy and delete controls.
///
/// The server keeps only the code's SHA-256 hash, so the plaintext can only come
/// from the local store: an invite made on another phone says so and offers a
/// replacement instead of inventing one.
class _InviteRow extends StatelessWidget {
  const _InviteRow({
    required this.id,
    required this.createdLabel,
    required this.code,
    required this.unavailableLabel,
    required this.copyLabel,
    required this.newCodeLabel,
    required this.deleteLabel,
    required this.onCopy,
    required this.onNewCode,
    required this.onDelete,
  });

  final String id;
  final String createdLabel;

  /// The plaintext code, known only when this device generated the invite.
  final String? code;

  /// What the row says when this device never held the code.
  final String unavailableLabel;

  /// Spoken/screen-reader label for the copy button.
  final String copyLabel;

  /// The replacement action's label, shown only when the code is unknown.
  final String newCodeLabel;

  /// Spoken/screen-reader label for the delete button.
  final String deleteLabel;

  /// Copies the code; only called when [code] is non-null.
  final ValueChanged<String> onCopy;

  /// Replaces an invite this device cannot show; only called when [code] is null.
  final VoidCallback? onNewCode;

  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) => Container(
    decoration: settingsCardDecoration(),
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.xs,
      AppSpacing.xs,
      AppSpacing.xs,
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
              // The code is plain text with its own copy button, so a tap on
              // the words no longer has to guess (user request). A code this
              // device never saw says so and offers a replacement.
              if (code != null)
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        code!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySm.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    IconButton(
                      key: ValueKey('manage-associates-copy-$id'),
                      tooltip: copyLabel,
                      onPressed: () => onCopy(code!),
                      icon: const Icon(Icons.copy_outlined, size: 18),
                      color: AppColors.primary,
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                )
              else ...[
                Text(
                  unavailableLabel,
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                TextButton(
                  key: ValueKey('manage-associates-new-code-$id'),
                  onPressed: onNewCode,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(newCodeLabel),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        // A delete icon rather than a worded button (user request): the row's
        // only destructive action, in the app's error colour.
        IconButton(
          key: ValueKey('manage-associates-delete-$id'),
          tooltip: deleteLabel,
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline),
          color: AppColors.error,
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          padding: EdgeInsets.zero,
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
  late bool _canAdd = _role == AccountRole.viewer
      ? false
      : widget.member.canAdd;
  late bool _canEdit = _role == AccountRole.viewer
      ? false
      : widget.member.canEdit;
  late bool _canDelete = _role == AccountRole.viewer
      ? false
      : widget.member.canDelete;

  /// The last associate flags, so returning from Viewer restores them.
  late bool _lastAdd = widget.member.canAdd;
  late bool _lastEdit = widget.member.canEdit;
  late bool _lastDelete = widget.member.canDelete;

  bool _busy = false;
  Object? _failure;

  /// The role the sheet opened on, with Viewer's switches already off.
  String get _initialRole => widget.member.role == AccountRole.viewer
      ? AccountRole.viewer
      : AccountRole.associate;

  bool get _initialAdd =>
      _initialRole == AccountRole.viewer ? false : widget.member.canAdd;

  bool get _initialEdit =>
      _initialRole == AccountRole.viewer ? false : widget.member.canEdit;

  bool get _initialDelete =>
      _initialRole == AccountRole.viewer ? false : widget.member.canDelete;

  /// Whether closing now would throw away a choice the owner has not saved.
  bool get _dirty =>
      _role != _initialRole ||
      _canAdd != _initialAdd ||
      _canEdit != _initialEdit ||
      _canDelete != _initialDelete;

  /// Chooses a role, keeping Viewer and the three flags coherent.
  ///
  /// The server has no rule tying them together, so the sheet is where a viewer
  /// is kept read-only: choosing Viewer clears and disables the switches, and
  /// going back to Associate restores the last associate flags.
  void _selectRole(String role) {
    if (_busy || role == _role) return;
    setState(() {
      if (role == AccountRole.viewer) {
        _lastAdd = _canAdd;
        _lastEdit = _canEdit;
        _lastDelete = _canDelete;
        _canAdd = false;
        _canEdit = false;
        _canDelete = false;
      } else {
        _canAdd = _lastAdd;
        _canEdit = _lastEdit;
        _canDelete = _lastDelete;
      }
      _role = role;
    });
  }

  /// Asks before a dismiss throws away unsaved changes.
  Future<void> _confirmDiscard() async {
    final l = AppLocalizations.of(context);
    final discard = await _confirm(
      context: context,
      title: l.manageAssociates_discardChangesTitle,
      body: l.manageAssociates_discardChangesBody,
      confirmLabel: l.manageAssociates_discardChanges,
    );
    if (!discard || !mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final capacity = ref.watch(firmCapacityViewProvider);
    final flagged = widget.member.capacitySignedOutAt != null;
    final showSignOut =
        !flagged &&
        capacity != null &&
        (capacity.shrinkPending || capacity.overRoster || capacity.overDevices);
    final viewer = _role == AccountRole.viewer;

    return SafeArea(
      child: PopScope(
        canPop: !_dirty,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          _confirmDiscard();
        },
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
              // The sheet opens on the role, then on the permissions the role
              // governs (user request): the label that heads the switches sits
              // after the role rather than above it, and wears the same small
              // style as the role's own label so the two read as one pair.
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
                    onTap: () => _selectRole(AccountRole.associate),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  SettingsChoiceButton(
                    key: const ValueKey('member-role-viewer'),
                    label: l.settingsManageAccount_roleViewer,
                    selected: _role == AccountRole.viewer,
                    onTap: () => _selectRole(AccountRole.viewer),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                l.manageAssociates_permissionsTitle,
                style: AppTypography.labelMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              _PermissionToggle(
                label: l.manageAssociates_permissionAdd,
                value: _canAdd,
                enabled: !_busy && !viewer,
                onChanged: (value) => setState(() => _canAdd = value),
              ),
              _PermissionToggle(
                label: l.manageAssociates_permissionEdit,
                value: _canEdit,
                enabled: !_busy && !viewer,
                onChanged: (value) => setState(() => _canEdit = value),
              ),
              _PermissionToggle(
                label: l.manageAssociates_permissionDelete,
                value: _canDelete,
                enabled: !_busy && !viewer,
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
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              const Divider(height: 1, color: AppColors.outlineVariant),
              const SizedBox(height: AppSpacing.lg),
              // Removal is the destructive action of this sheet, so it wears the
              // app's red fill with white ink, at the Save button's own height and
              // shape (user request) — the same reading the Dissolve action
              // carries on the page behind this sheet.
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('member-remove'),
                  onPressed: _busy ? null : _remove,
                  icon: const Icon(
                    Icons.person_remove_alt_1_outlined,
                    size: 20,
                  ),
                  label: Text(l.manageAssociates_removeAssociate),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: AppColors.onError,
                    disabledBackgroundColor: AppColors.error.withValues(
                      alpha: 0.38,
                    ),
                    textStyle: AppTypography.titleMd,
                    minimumSize: const Size.fromHeight(
                      settingsPrimaryButtonHeight,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppSpacing.cardRadius,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Writes the role and the three flags, then closes on success.
  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final viewer = _role == AccountRole.viewer;
    await _run(() async {
      await ref
          .read(firmRepositoryProvider)
          .updateMemberPermissions(
            userId: widget.member.userId,
            role: _role,
            canAdd: viewer ? false : _canAdd,
            canEdit: viewer ? false : _canEdit,
            canDelete: viewer ? false : _canDelete,
          );
      if (!mounted) return;
      ref.invalidate(firmMembersListProvider);
      // A successful save is not a discard: pop directly, because the unsaved
      // changes guard would otherwise ask about changes that were just written.
      Navigator.of(context).pop();
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
      Navigator.of(context).pop();
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
      Navigator.of(context).pop();
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
      Navigator.of(context).pop();
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
/// [matchesInviteCodeWindow] keeps the revoke confirmation's **centred** title;
/// every window on this screen is otherwise on the shared pop-over frame.
Future<bool> _confirm({
  required String title,
  required String body,
  required String confirmLabel,
  required BuildContext context,
  bool matchesInviteCodeWindow = false,
}) async {
  final l = AppLocalizations.of(context);
  final answer = await showAppDialog<bool>(
    context,
    title: Text(
      title,
      textAlign: matchesInviteCodeWindow ? TextAlign.center : null,
    ),
    // The frame's 85 % height cap scrolls a long removal warning instead of
    // clipping it on a phone.
    content: Text(body),
    actions: (dialogContext) => [
      AppDialogAction(
        label: l.sharedActions_cancel,
        onPressed: () => Navigator.of(dialogContext).pop(false),
      ),
      AppDialogAction(
        label: confirmLabel,
        kind: AppDialogActionKind.destructive,
        onPressed: () => Navigator.of(dialogContext).pop(true),
      ),
    ],
  );
  return answer ?? false;
}

/// Sorts the roster for display: the owner first, then names A–Z, blank last.
List<FirmMemberSummary> _sortedMembers(List<FirmMemberSummary> rows) {
  final sorted = [...rows];
  sorted.sort((a, b) {
    final aOwner = a.role == AccountRole.owner;
    final bOwner = b.role == AccountRole.owner;
    if (aOwner != bOwner) return aOwner ? -1 : 1;
    final aName = a.fullName.trim().toLowerCase();
    final bName = b.fullName.trim().toLowerCase();
    if (aName.isEmpty != bName.isEmpty) return aName.isEmpty ? 1 : -1;
    return aName.compareTo(bName);
  });
  return sorted;
}

/// A member's initials: the first letter of their first and last words.
///
/// A leading advocate title (`Adv.`) is skipped, because every roster name in
/// the app tends to carry it and every avatar would otherwise read `A?`.
String _initials(String name) {
  var words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList(growable: false);
  if (words.length > 1 &&
      (words.first.toLowerCase() == 'adv.' ||
          words.first.toLowerCase() == 'adv')) {
    words = words.sublist(1);
  }
  if (words.isEmpty) return '?';
  final first = words.first.substring(0, 1);
  final last = words.length > 1 ? words.last.substring(0, 1) : '';
  return (first + last).toUpperCase();
}

/// A section title in the Notifications screen's own title style (user
/// request, 0.0.846): titleMd, bold, above the list or card it names.
Widget _sectionTitle(String text) => Text(
  text,
  style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.w700),
);

/// What a member may do, in one short line under their name.
///
/// The three permissions are listed in the order the member sheet shows them
/// (user request), so a row reads *Add, Edit*. A member with none of them is
/// read-only, and the owner's access is structural rather than a set of flags.
String _permissionSummary(AppLocalizations l, FirmMemberSummary member) {
  if (member.role == AccountRole.owner) {
    return l.manageAssociates_memberFullAccess;
  }
  final allowed = <String>[
    if (member.canAdd) l.sharedActions_add,
    if (member.canEdit) l.sharedActions_edit,
    if (member.canDelete) l.sharedActions_delete,
  ];
  if (allowed.isEmpty) return l.manageAssociates_memberReadOnly;
  return allowed.join(', ');
}

/// The action whose own button draws the progress spinner while it runs.
enum _BusyAction { add, dissolve, other }

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
    this.busy = false,
  });

  /// What dissolving does, in plain words.
  final String intro;

  /// Why the action is unavailable right now, or null when it is available.
  final String? note;

  /// The action's own label.
  final String actionLabel;

  /// Runs the dissolve; null disables the button.
  final VoidCallback? onPressed;

  /// Whether the dissolve itself is running, so the button shows a spinner.
  final bool busy;

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
            // A reason is not a refusal: muted, so red stays for the refusal
            // that actually came back from the server.
            Text(
              note,
              style: AppTypography.bodyMd.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
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
              icon: busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_forever_outlined),
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

/// The screen's primary action, at the shared Settings button height.
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  /// Whether this button's own call is running, so it shows a spinner.
  final bool busy;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: onPressed,
    icon: busy
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(icon, size: 20),
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

    return AppContentDialogFrame(
      // The Exit App window's white panel, with its side margins pulled in
      // from 40 to 16 (0.0.652, user request): the Exit-App-sized buttons are
      // wide, and at the old margins they could not share a row on any phone.
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.lg,
      ),
      backgroundColor: AppColors.surfaceContainerLowest,
      body: Column(
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
        ],
      ),
      // Three actions keep their Wrap grouping: Copy and Share on a row, Close
      // beneath.
      actionMode: AppDialogActionMode.wrap,
      actions: (dialogContext) => [
        AppDialogAction(
          key: const ValueKey('invite-code-copy'),
          label: l.manageAssociates_copyCode,
          kind: AppDialogActionKind.outlined,
          onPressed: _copy,
        ),
        AppDialogAction(
          key: const ValueKey('invite-code-share'),
          label: l.manageAssociates_shareCode,
          kind: AppDialogActionKind.outlined,
          onPressed: _share,
        ),
        AppDialogAction(
          key: const ValueKey('invite-code-close'),
          label: l.sharedActions_close,
          kind: AppDialogActionKind.primary,
          onPressed: () => Navigator.of(dialogContext).maybePop(),
        ),
      ],
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

    return AppContentDialogFrame(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.lg,
      ),
      backgroundColor: AppColors.surfaceContainerLowest,
      body: Column(
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
        ],
      ),
      actions: (dialogContext) => [
        AppDialogAction(
          key: const ValueKey('firm-name-cancel'),
          label: l.sharedActions_cancel,
          onPressed: () => Navigator.of(dialogContext).maybePop(),
        ),
        AppDialogAction(
          key: const ValueKey('firm-name-save'),
          label: l.sharedActions_save,
          kind: AppDialogActionKind.primary,
          onPressed: canSave
              ? () => Navigator.of(dialogContext).maybePop(_name.text.trim())
              : null,
        ),
      ],
    );
  }
}

/// Shows [message] over the current screen.
void _say(BuildContext context, String message) => ScaffoldMessenger.of(
  context,
).showSnackBar(SnackBar(content: Text(message)));
