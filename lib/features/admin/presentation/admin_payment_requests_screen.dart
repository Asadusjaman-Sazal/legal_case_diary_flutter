/// The Admin Panel's **Payment Requests** sub-page: submissions awaiting a
/// decision, and the record of the ones already decided.
///
/// Moved off the panel itself when the panel became a menu of sub-pages (user
/// request), so the screen no longer carries a "Payment Requests" heading — the
/// header names it. Three things were added on the way: each card is numbered
/// within its section, the header's search filters both sections, opening a
/// closed one when it holds a match, and each section's button sticks to the top
/// of the list while the admin scrolls that section's own cards.
///
/// The screen is deliberately thin — it renders what `adminPaymentRequestsProvider`
/// returns and calls two methods on `AdminActionViewModel`. It holds no admin
/// state of its own, because the one question that matters ("is this person an
/// admin at all?") is answered by the server through `adminStatusProvider`.
///
/// Pending starts open and Resolved starts closed, because a resolved submission
/// cannot be acted on and the admin opening this page has work to do.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/errors/error_log.dart';
import '../../../core/errors/error_log_provider.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/widgets/confirm_dialogs.dart';
import '../../../sync/sync_service.dart';
import '../../accounts_and_profile/data/account_mode.dart';
import '../../payments/data/payment_plans.dart';
import '../../payments/presentation/payment_plan_labels.dart';
import '../../settings/presentation/settings_controls.dart';
import '../../settings/presentation/settings_menu_card.dart';
import '../../settings/presentation/settings_sub_page_modal.dart';
import '../../settings/presentation/settings_viewmodel.dart';
import '../data/admin_repository.dart';
import 'admin_shared.dart';
import 'admin_viewmodel.dart';
import 'reject_message_templates.dart';

/// Payment requests: Pending and Resolved, each collapsible, each numbered.
class AdminPaymentRequestsScreen extends ConsumerStatefulWidget {
  const AdminPaymentRequestsScreen({super.key});

  @override
  ConsumerState<AdminPaymentRequestsScreen> createState() =>
      _AdminPaymentRequestsScreenState();
}

class _AdminPaymentRequestsScreenState
    extends ConsumerState<AdminPaymentRequestsScreen> {
  /// Pending is the section that needs attention, so it starts open and
  /// Resolved — a history, not a to-do — starts closed.
  bool _pendingOpen = true;
  bool _resolvedOpen = false;

  /// Whether the header's search box is showing, and what is typed in it.
  bool _isSearching = false;
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    // A payment alert can open this page while the cached list is older than
    // the payment it announced. Re-read it on every open (user request), after
    // the first frame so the provider is not touched mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(adminPaymentRequestsProvider);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toggleSearch() => setState(() {
    _isSearching = !_isSearching;
    if (!_isSearching) {
      _search.clear();
      _query = '';
    }
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final requests = ref.watch(adminPaymentRequestsProvider);

    return PopScope(
      // The page can be the stack's only route — a payment-alert launch makes
      // it the router's initial location, and a tap while the app runs
      // *replaces* the stack — so the system back gesture must land on the
      // Admin Panel too, not leave the page stranded (or exit the app).
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _back();
      },
      child: SettingsSubPageModal(
        title: l.adminPanel_paymentRequests,
        // The page has its own pull that syncs and reloads the server list.
        pullToSync: false,
        onBack: _back,
        actions: [
          const AdminSyncButton(),
          IconButton(
            key: const ValueKey('admin-payments-search'),
            icon: const Icon(Icons.search),
            tooltip: l.adminPanel_search,
            onPressed: _toggleSearch,
          ),
        ],
        child: requests.when(
          loading: () => Center(child: CircularProgressIndicator()),
          error: (_, _) => _LoadFailed(
            onRetry: () => ref.invalidate(adminPaymentRequestsProvider),
          ),
          data: (all) {
            final searching = _query.trim().isNotEmpty;
            final pending = all
                .where((r) => r.isPending && _matches(r))
                .toList(growable: false);
            final resolved = all
                .where((r) => r.isResolved && _matches(r))
                .toList(growable: false);
            if (searching && pending.isEmpty && resolved.isEmpty) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_isSearching) _searchField(l),
                  AdminNoResults(message: l.adminPanel_noResults),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_isSearching) _searchField(l),
                Expanded(
                  // Pull to refresh does what the header button does — a forced
                  // drain with the delta pull — and then re-reads the
                  // submissions, so a payment that landed while the page was
                  // open appears without a second trip to Settings.
                  child: RefreshIndicator(
                    onRefresh: () async {
                      await ref.read(syncServiceProvider).retryNow();
                      ref.invalidate(adminPaymentRequestsProvider);
                      await ref.read(adminPaymentRequestsProvider.future);
                    },
                    // Slivers, not a ListView, because each section's button has to
                    // hold the top of the list while the admin scrolls its own
                    // cards: the header scrolls away with them otherwise, and after
                    // a few hundred cards there is nothing left saying which
                    // section is on screen.
                    child: CustomScrollView(
                      slivers: [
                        _RequestSection(
                          icon: Icons.pending_actions,
                          title: l.adminPanel_pending,
                          count: pending.length,
                          // A section holding a match is opened by the search, so a
                          // result is never hidden inside a closed section.
                          open: searching ? pending.isNotEmpty : _pendingOpen,
                          emptyText: searching
                              ? l.adminPanel_noResults
                              : l.adminPanel_emptyPending,
                          children: [
                            for (var i = 0; i < pending.length; i++)
                              _RequestCard(
                                key: ValueKey('admin-request-${pending[i].id}'),
                                request: pending[i],
                                serial: i + 1,
                              ),
                          ],
                          onToggle: () =>
                              setState(() => _pendingOpen = !_pendingOpen),
                        ),
                        // The two bands already contribute a `sm` each, so this
                        // brings the gap between the sections to the old `lg`.
                        const SliverToBoxAdapter(
                          child: SizedBox(height: AppSpacing.md),
                        ),
                        _RequestSection(
                          icon: Icons.task_alt,
                          title: l.adminPanel_resolved,
                          count: resolved.length,
                          open: searching ? resolved.isNotEmpty : _resolvedOpen,
                          emptyText: searching
                              ? l.adminPanel_noResults
                              : l.adminPanel_emptyResolved,
                          // Newest decision first: the admin wants the latest
                          // history, not the oldest, and the server's own order is
                          // by submission time rather than by when it was decided.
                          children: [
                            for (var i = 0; i < resolved.length; i++)
                              _RequestCard(
                                key: ValueKey(
                                  'admin-request-${_byDecisionTime(resolved)[i].id}',
                                ),
                                request: _byDecisionTime(resolved)[i],
                                serial: i + 1,
                              ),
                          ],
                          onToggle: () =>
                              setState(() => _resolvedOpen = !_resolvedOpen),
                        ),
                        // The list's own bottom padding, which a CustomScrollView
                        // has no padding for.
                        const SliverToBoxAdapter(
                          child: SizedBox(height: AppSpacing.xl),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// The one way out of this page.
  ///
  /// The header arrow and the Android back gesture both call this, so there is
  /// one answer either way. With history the page pops as usual (the panel
  /// pushes it on top of its menu); at the root — the two notification entries —
  /// it goes through the router to the Admin Panel, the screen this page belongs
  /// to, rather than doing nothing.
  void _back() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    // `maybeOf`, not `of`: a test harness can mount this page under a plain
    // Navigator with no GoRouter above it, and there is nothing to go to there.
    GoRouter.maybeOf(context)?.go(AppRoutes.adminPanel);
  }

  Widget _searchField(AppLocalizations l) => AdminSearchField(
    controller: _search,
    hint: l.adminPanel_searchHint,
    onChanged: (value) => setState(() => _query = value),
    onClose: _toggleSearch,
  );

  /// Whether one card matches the query on any text it shows.
  bool _matches(AdminPaymentRequest request) => adminTextMatches(_query, [
    request.fullName,
    request.email,
    request.transactionId,
    request.senderNumber,
    request.mobileNo,
    request.barAssociation,
    request.membershipNo,
    request.status,
  ]);

  /// Resolved submissions newest-decision-first; approvals before rejections
  /// within one instant, so a same-millisecond pair is still deterministic.
  static List<AdminPaymentRequest> _byDecisionTime(
    List<AdminPaymentRequest> resolved,
  ) {
    final ordered = [...resolved];
    ordered.sort((a, b) {
      final byTime = _decidedAt(b).compareTo(_decidedAt(a));
      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    });
    return ordered;
  }

  static DateTime _decidedAt(AdminPaymentRequest r) =>
      r.approvedAt ?? r.rejectedAt ?? r.submittedAt ?? DateTime(1970);
}

/// A collapsible Pending / Resolved section, headed by a Settings sub-menu
/// button that **sticks to the top of the list** for as long as the section's
/// own cards are on screen.
///
/// The button and its cards are wrapped in a single [SliverMainAxisGroup], which
/// is what scopes the stickiness to the section: the button holds the top of the
/// list while that section's cards are being read, then travels up and out as
/// the next section's button arrives in its place. (Pinned headers placed side
/// by side in a scroll view pile up at the top instead — they would all stay on
/// screen at once — so the group is what makes the handover work. The case
/// screens' court headings pin the same way.)
class _RequestSection extends StatelessWidget {
  /// Leading icon of the header button.
  final IconData icon;
  final String title;
  final int count;

  /// Whether the section is expanded; driven by the screen so the card is the
  /// single control that toggles it.
  final bool open;
  final String emptyText;
  final List<Widget> children;

  /// Called when the header button is tapped.
  final VoidCallback onToggle;

  const _RequestSection({
    required this.icon,
    required this.title,
    required this.count,
    required this.open,
    required this.emptyText,
    required this.children,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SliverMainAxisGroup(
      slivers: [
        PinnedHeaderSliver(
          // The band paints the page background across the list's full width,
          // which keeps the cards sliding underneath it out of sight while it is
          // pinned, and insets the button to the gutter the list uses. The `sm`
          // below it is the gap the cards had before the button was pinned.
          child: ColoredBox(
            color: AppColors.background,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.edgeMargin,
                vertical: AppSpacing.sm,
              ),
              child: SettingsMenuCard(
                icon: icon,
                title: title,
                onTap: onToggle,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l.adminPanel_sectionCount(
                        AppDateUtils.formatDigits(count, l.localeName),
                      ),
                      style: AppTypography.bodySm,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // A closed section contributes its button only, so the next section's
        // button comes straight up to the top behind it. The reveal animates so
        // the list below does not jump when a section opens under the reader's
        // thumb.
        SliverPadding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.edgeMargin,
          ),
          sliver: SliverToBoxAdapter(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: open ? _body(l) : const SizedBox(width: double.infinity),
            ),
          ),
        ),
      ],
    );
  }

  /// The revealed list: the empty note, or the requests separated by the same
  /// hairline the Settings lists use, inside a bordered surface that matches the
  /// header card's radius.
  Widget _body(AppLocalizations l) => Container(
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(settingsMenuCardRadius),
      border: Border.all(color: AppColors.outlineVariant),
    ),
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
    child: children.isEmpty
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Text(emptyText, style: AppTypography.bodySm),
          )
        : Column(
            children: [
              // Hairline between rows, exactly as the Settings main screen
              // separates its list tiles.
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: AppColors.outlineVariant,
                  ),
                children[i],
              ],
            ],
          ),
  );
}

/// One payment request: who paid, what they paid for, and — while it is pending
/// — the two decisions an admin may take. Numbered within its section.
class _RequestCard extends ConsumerWidget {
  final AdminPaymentRequest request;

  /// The card's position in its section, counting from 1.
  final int serial;

  const _RequestCard({required this.request, required this.serial, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final action = ref.watch(AdminActionViewModel.provider);
    final isThisOne = action.actedOn == request.id;
    final busy = isThisOne && action.isRunning;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // The number the admin reads down the list. A plain number, as
              // asked — the section's own header already carries the count.
              SizedBox(
                width: 28,
                child: Text(
                  AppDateUtils.formatDigits(
                    serial,
                    l.localeName,
                    grouping: false,
                  ),
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  request.fullName.isEmpty
                      ? l.adminPanel_noValue
                      : request.fullName,
                  style: AppTypography.titleMd,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _StatusChip(status: request.status),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            adminPaymentPlanAndAmount(l, request),
            style: AppTypography.bodySm.copyWith(
              color: AppColors.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          // The sender's number is a number, not an amount, so it carries no
          // `৳` — the plan line above is the only place an amount appears.
          Text(
            request.senderNumber.isEmpty
                ? l.adminPanel_noValue
                : request.senderNumber,
            style: AppTypography.bodySm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _DetailLine(
            label: l.adminPanel_detailLabelTrx,
            value: request.transactionId,
          ),
          _DetailLine(
            label: l.adminPanel_detailLabelMfs,
            value: adminPaymentMethodLabel(l, request.mfsProvider),
          ),
          _DetailLine(
            label: l.adminPanel_detailLabelName,
            value: request.fullName,
          ),
          _DetailLine(
            label: l.adminPanel_detailLabelEmail,
            value: request.email,
          ),
          _DetailLine(
            label: l.adminPanel_detailLabelBar,
            value: request.barAssociation,
          ),
          _DetailLine(
            label: l.adminPanel_detailLabelMembership,
            value: request.membershipNo,
          ),
          _DetailLine(
            label: l.adminPanel_detailLabelMobile,
            value: request.mobileNo,
          ),
          _DetailLine(
            label: l.adminPanel_detailLabelSubmitted,
            value: adminPanelDateTime(l, request.submittedAt),
          ),
          if (request.isResolved) ...[
            // When it was decided, under the outcome's own word: an approved
            // card reads "Approved: …", a rejected one "Rejected: …", so the
            // verdict and its moment are one line. The label is the same word
            // the status chip already carries.
            _DetailLine(
              label: request.status == 'approved'
                  ? l.adminPanel_statusApproved
                  : l.adminPanel_statusRejected,
              value: adminPanelDateTime(
                l,
                request.status == 'approved'
                    ? request.approvedAt
                    : request.rejectedAt,
              ),
            ),
            if (request.approvedAt != null)
              _DetailLine(
                label: l.adminPanel_approvedExpiry,
                value: adminPanelDate(l, request.approvedNewExpiry),
              ),
            if ((request.adminNotes ?? '').isNotEmpty)
              _DetailLine(
                label: l.adminPanel_detailLabelNote,
                value: request.adminNotes!,
              ),
          ],
          if (request.isPending) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  // Reject is the red decision (user request): a filled error
                  // button with a white label, so the two decisions read as the
                  // outcome they produce rather than as two equal choices.
                  child: FilledButton(
                    onPressed: busy ? null : () => _confirmReject(context, ref),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: AppColors.onError,
                      textStyle: AppTypography.labelLg,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.sheetRadius,
                        ),
                      ),
                    ),
                    child: Text(l.adminPanel_reject),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: busy
                        ? null
                        : () => ref
                              .read(AdminActionViewModel.provider.notifier)
                              .approve(request.id),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      textStyle: AppTypography.labelLg,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.sheetRadius,
                        ),
                      ),
                    ),
                    child: Text(l.adminPanel_approve),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Asks for the note and rejects. A rejection is a decision the payer may
  /// query, so it is confirmed rather than fired from one tap.
  Future<void> _confirmReject(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final note = await showDialog<String>(
      context: context,
      builder: (_) => _RejectNoteDialog(
        l: l,
        onSavedMessagesChanged: (messages) => _saveOwnMessages(ref, messages),
      ),
    );
    if (note == null) return;
    final trimmed = note.trim();
    await ref
        .read(AdminActionViewModel.provider.notifier)
        .reject(request.id, note: trimmed.isEmpty ? null : trimmed);
  }

  /// Writes the admin's own reject messages into the per-user preference row.
  ///
  /// Read-modify-write through the repository, not the settings view model: the
  /// view model applies a change to whatever settings it happens to hold, so a
  /// screen that has not loaded them yet would save its own defaults over the
  /// lawyer's stored row. The push is the same detached ask the Settings screens
  /// make after a preference write, and a failure is recorded rather than
  /// swallowed — the wording left the list, and nothing else would say why.
  Future<void> _saveOwnMessages(WidgetRef ref, List<String> messages) async {
    try {
      final repository = await ref.read(settingsRepositoryProvider.future);
      final current = await repository.getSettings();
      await repository.upsertSettings(
        current.copyWith(adminRejectMessages: messages),
      );
      ref.read(pushPreferencesProvider)();
      // The settings view model caches what it loaded, so the next time this
      // window opens it must read the row again rather than the stale list.
      ref.invalidate(settingsViewModelProvider);
    } on Object catch (error) {
      recordFailure(
        ref.read(errorLogProvider),
        'admin.saveRejectMessages',
        error,
      );
    }
  }
}

/// The rejection window: an optional note for the payer, the app's own pre-fill
/// messages beside the admin's saved ones, and a Cancel that does nothing at all.
class _RejectNoteDialog extends ConsumerStatefulWidget {
  /// Localizations, read by the card that opened the window.
  final AppLocalizations l;

  /// Called with the admin's own messages after one is added or removed, so the
  /// screen writes the per-user preference row rather than the window.
  final ValueChanged<List<String>> onSavedMessagesChanged;

  const _RejectNoteDialog({
    required this.l,
    required this.onSavedMessagesChanged,
  });

  @override
  ConsumerState<_RejectNoteDialog> createState() => _RejectNoteDialogState();
}

/// The rejection window's button size: the app's own 48 px control height, and a
/// minimum width that keeps the pair side by side inside a phone's dialog (a
/// wider minimum pushes the two onto separate lines).
const Size _dialogButtonSize = Size(96, 48);

/// The tallest the opened pre-fill list may grow before it scrolls itself.
///
/// The window already carries a title, a three-line note and two buttons, and it
/// can be open while the keyboard is up, so the list is given a ceiling of its
/// own instead of stretching the dialog to whatever the messages come to.
const double _prefillListMaxHeight = 208;

class _RejectNoteDialogState extends ConsumerState<_RejectNoteDialog> {
  final TextEditingController _controller = TextEditingController();

  /// The admin's own saved messages, read once when the window opens.
  List<String> _own = const <String>[];

  /// Whether the pre-fill list is showing under its row.
  bool _open = false;

  @override
  void initState() {
    super.initState();
    // A message's tick is derived from the note, so every keystroke redraws the
    // row it belongs to: a hand edit and a tap in the list can then never
    // disagree about what is in the box.
    _controller.addListener(_onNoteChanged);
    _loadOwnMessages();
  }

  @override
  void dispose() {
    _controller.removeListener(_onNoteChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onNoteChanged() => setState(() {});

  /// Reads the admin's own messages from the per-user preference row.
  ///
  /// A failed read costs this list and not the window — the rejection must still
  /// be possible — and the settings view model has already recorded it.
  Future<void> _loadOwnMessages() async {
    try {
      final settings = await ref.read(settingsViewModelProvider.future);
      if (!mounted) return;
      setState(() => _own = settings.adminRejectMessages);
    } on Object {
      // Deliberately left empty: the app's own messages still work.
    }
  }

  /// Every message the list offers: the app's own, then the admin's own.
  List<String> _messages(AppLocalizations l) => <String>[
    ...adminRejectTemplates(l),
    ..._own,
  ];

  /// Puts [message] in the note, or takes it back out when it is already there.
  void _toggle(String message) => _write(
    adminRejectNoteHas(_controller.text, message)
        ? adminRejectNoteRemove(_controller.text, message)
        : adminRejectNoteAdd(_controller.text, message),
  );

  /// Writes [text] into the note, leaving the caret at its end so the admin can
  /// carry straight on typing.
  void _write(String text) {
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  /// Types a message of the admin's own: it goes into the note, and into the
  /// list for next time.
  Future<void> _addOwn(AppLocalizations l) async {
    final typed = await showDialog<String>(
      context: context,
      builder: (_) => _OwnMessageDialog(l: l),
    );
    final message = typed?.trim() ?? '';
    if (message.isEmpty) return;
    if (!_own.contains(message)) {
      final next = <String>[..._own, message];
      setState(() => _own = next);
      widget.onSavedMessagesChanged(next);
    }
    _write(adminRejectNoteAdd(_controller.text, message));
  }

  /// Removes one of the admin's own messages, behind the app's own delete
  /// window.
  ///
  /// The note is left alone: the admin may be writing this rejection with that
  /// very wording, and deleting an entry from the list is not an edit to what the
  /// payer is about to read.
  Future<void> _removeOwn(String message) async {
    final confirmed = await confirmDeleteDialog(context);
    if (confirmed != true) return;
    final next = _own
        .where((entry) => entry != message)
        .toList(growable: false);
    setState(() => _own = next);
    widget.onSavedMessagesChanged(next);
  }

  /// The pre-fill "dropdown": the app's own 48 px picker row, opening the
  /// message list beneath it.
  ///
  /// A list rather than a `DropdownButton`, because several messages are picked
  /// *into* the note and the control must not close under the admin's thumb — the
  /// check-mark picker the Settings screens use, only inline: a second window
  /// opened from inside this one would hide the note being filled.
  Widget _prefill(AppLocalizations l) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SettingsPickerRow(
        text: l.adminPanel_rejectPickMessage,
        icon: _open ? Icons.expand_less : Icons.expand_more,
        onTap: () => setState(() => _open = !_open),
      ),
      if (_open)
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            constraints: const BoxConstraints(maxHeight: _prefillListMaxHeight),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final message in _messages(l)) _messageRow(l, message),
                  _addOwnRow(l),
                ],
              ),
            ),
          ),
        ),
    ],
  );

  /// One message: tapping it puts it in the note or takes it out, the tick shows
  /// which, and the admin's own messages also carry a way to delete them.
  Widget _messageRow(AppLocalizations l, String message) {
    final own = _own.contains(message);
    final picked = adminRejectNoteHas(_controller.text, message);
    return InkWell(
      key: ValueKey('admin-reject-message-$message'),
      onTap: () => _toggle(message),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                message,
                style: AppTypography.bodySm.copyWith(
                  color: picked ? AppColors.secondary : AppColors.onSurface,
                  fontWeight: picked ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
            if (own)
              IconButton(
                key: ValueKey('admin-reject-own-remove-$message'),
                icon: const Icon(Icons.close, size: 16),
                tooltip: l.sharedActions_delete,
                visualDensity: VisualDensity.compact,
                onPressed: () => _removeOwn(message),
              ),
            if (picked)
              const Icon(
                Icons.check_circle,
                size: 18,
                color: AppColors.secondary,
              ),
          ],
        ),
      ),
    );
  }

  /// The list's last row: the admin's own wording, typed by them.
  Widget _addOwnRow(AppLocalizations l) => InkWell(
    key: const ValueKey('admin-reject-add-own'),
    onTap: () => _addOwn(l),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          const Icon(Icons.add, size: 18, color: AppColors.secondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              l.adminPanel_rejectAddOwn,
              style: AppTypography.bodySm.copyWith(
                color: AppColors.secondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l = widget.l;
    return AlertDialog(
      title: Text(l.adminPanel_rejectTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: l.adminPanel_rejectNoteLabel,
              hintText: l.adminPanel_rejectNoteHint,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _prefill(l),
        ],
      ),
      // The window can be open while the keyboard is up — "Add Your Own" opens a
      // field that autofocuses, over this one — and the middle of the window is
      // the tallest part of it (the opened pre-fill list). Without this the note,
      // the list and the title are laid out in what the keyboard leaves and the
      // whole thing overflows off the top of its own box (reported on a phone).
      // Scrollable keeps the title, note and list in one scrollable column and
      // the two decisions pinned under it, which is what makes a rejection still
      // possible with the keyboard showing.
      scrollable: true,
      // The two decisions are the window's whole point, so they are centred and
      // given the app's own button height (user request) rather than the
      // platform's smaller, right-aligned defaults. The overflow alignment is the
      // same centre: a narrow phone wraps the pair into a column, and a wrapped
      // pair that fell back to the platform's `end` would be right-aligned again.
      actionsAlignment: MainAxisAlignment.center,
      actionsOverflowAlignment: OverflowBarAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            textStyle: AppTypography.labelLg,
            minimumSize: _dialogButtonSize,
          ),
          child: Text(l.sharedActions_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: AppColors.onError,
            textStyle: AppTypography.labelLg,
            minimumSize: _dialogButtonSize,
          ),
          child: Text(l.adminPanel_rejectConfirm),
        ),
      ],
    );
  }
}

/// The window \"Add Your Own\" opens: one field, and an Add that saves the wording
/// for next time as well as putting it in the note.
class _OwnMessageDialog extends StatefulWidget {
  final AppLocalizations l;

  const _OwnMessageDialog({required this.l});

  @override
  State<_OwnMessageDialog> createState() => _OwnMessageDialogState();
}

class _OwnMessageDialogState extends State<_OwnMessageDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.l;
    return AlertDialog(
      title: Text(l.adminPanel_rejectOwnMessageTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: 2,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          hintText: l.adminPanel_rejectOwnMessageHint,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.sharedActions_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            textStyle: AppTypography.labelLg,
          ),
          child: Text(l.sharedActions_add),
        ),
      ],
    );
  }
}

/// One label/value line, rendered only when there is a value worth showing.
class _DetailLine extends StatelessWidget {
  final String label;
  final String value;

  const _DetailLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final shown = value.isEmpty ? l.adminPanel_noValue : value;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Text(
        l.adminPanel_detailLabel(label, shown),
        style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
      ),
    );
  }
}

/// Pending / Approved / Rejected, coloured by outcome.
class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final (label, color) = switch (status) {
      'approved' => (l.adminPanel_statusApproved, AppColors.success),
      'rejected' => (l.adminPanel_statusRejected, AppColors.error),
      _ => (l.adminPanel_statusPending, AppColors.onSurfaceVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.radiusSm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Text(label, style: AppTypography.labelMd.copyWith(color: color)),
    );
  }
}

/// Shown when the list could not be loaded, with the one thing that can help.
class _LoadFailed extends StatelessWidget {
  final VoidCallback onRetry;

  const _LoadFailed({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AdminLoadFailed(
      message: l.adminPanel_loadFailed,
      retryLabel: l.adminPanel_retry,
      onRetry: onRetry,
    );
  }
}

/// The localized brand of one MFS provider, so the admin reads "bKash" rather
/// than the stored `bkash` key.
///
/// Top-level rather than private to the card: the search matches on it too, so
/// the two cannot disagree about what a card says.
String adminPaymentMethodLabel(AppLocalizations l, String provider) =>
    switch (provider) {
      'bkash' => l.payments_methodBkash,
      'nagad' => l.payments_methodNagad,
      'rocket' => l.payments_methodRocket,
      _ => provider,
    };

/// "Pro · 1 Year · ৳1,200" — the plan's own name plus its bare amount, worded
/// by the same helpers the paywall uses so the two never disagree.
///
/// The amount is the row's own, because it is the row the server validates; the
/// name comes from the plan the key names. The four legacy keys still resolve to
/// the Starter names they became, so a waiting old submission is readable rather
/// than shown as a bare key. A key the client ladder cannot name at all is shown
/// **as the key itself**, never renamed to a plan that was not bought: the
/// mismatch is what tells the admin the row needs review, and the server refuses
/// it at approval anyway.
String adminPaymentPlanAndAmount(
  AppLocalizations l,
  AdminPaymentRequest request,
) {
  final known = planTier(request.planKey) != null;
  final name = known
      ? paymentPlanLabel(l, request.planKey)
      : (request.planKey.isEmpty
            ? l.payments_planSummaryTitle
            : request.planKey);
  final amount = l.payments_amountValue(
    AppDateUtils.formatDigits(request.amount, l.localeName),
  );
  return '$name · $amount';
}
