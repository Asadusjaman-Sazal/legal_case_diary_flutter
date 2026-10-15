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
import '../../../sync/connectivity_monitor.dart';
import '../../auth/presentation/auth_viewmodel.dart';
import '../../auth/presentation/auth_widgets.dart';
import '../../settings/presentation/settings_controls.dart';
import '../../settings/presentation/settings_menu_card.dart';
import '../../settings/presentation/settings_sub_page_modal.dart';
import '../data/account_mode.dart';
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

class _ManageAssociatesScreenState extends ConsumerState<ManageAssociatesScreen> {
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
    final firmName = ref.watch(accountFirmProvider).value?.name ?? '';
    final members = ref.watch(firmMembersListProvider);
    final invites = ref.watch(firmInvitesListProvider);

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
        _FirmCard(label: l.settingsManageAccount_firm, name: firmName),
        const SizedBox(height: AppSpacing.gutter),
        _PrimaryButton(
          icon: Icons.person_add_alt_1_outlined,
          label: l.manageAssociates_addAssociate,
          onPressed: _busy ? null : _addAssociate,
        ),
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
      ],
    );
  }

  /// The individual's view: the firm has not been created yet.
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
        Text(
          l.manageAssociates_createFirmIntro,
          style: AppTypography.bodyMd.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
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
          icon: free ? Icons.workspace_premium_outlined : Icons.apartment_outlined,
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

  Future<void> _showInviteCode(GeneratedInvite invite) => showModalBottomSheet<void>(
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

/// The firm header card: what this account's firm is called.
class _FirmCard extends StatelessWidget {
  const _FirmCard({required this.label, required this.name});
  final String label;
  final String name;

  @override
  Widget build(BuildContext context) => Container(
    decoration: settingsCardDecoration(),
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
          child: const Icon(Icons.apartment_outlined, color: AppColors.primary),
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
  );
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
            child: Text(
              member.fullName.isEmpty
                  ? l.manageAssociates_unnamedMember
                  : member.fullName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyLg,
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
void _say(BuildContext context, String message) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
