/// Sign-up screen: a new account, alone or as an associate joining a firm.
///
/// Body mirrors `mockup_html_screens/settings_onlineSync_signup/code.html`: the
/// card with the app logo and its wordmark header, "Create Account" and its
/// subtitle, then
/// Full Name, Bar Association, Email Address and Password (with the mockup's
/// eight-character helper line), the Terms of Service / Privacy Policy
/// checkbox, the Sign Up button, the "Or" divider and the "Sign Up with
/// Google" button, and finally the "Already have an account?" strip.
///
/// Three deliberate additions the mockup could not show:
///
/// * **Language switch** — English / বাংলা in the top right corner (user
///   request), for a reader who cannot read the default language.
/// * **Account Type** — Individual or Join Existing Firm. Choosing the firm path
///   reveals the Invite Code field, which is the plan's single-use onboarding
///   code; the rest of the form is unchanged.
/// * **Check Your Email** — when the project has email confirmation on, the
///   account exists but has no session, so the screen says so instead of
///   pretending to be signed in. The typed invite code is kept until the
///   confirmation is done.
///
/// The confirmation state is four actions and one automatic check:
///
/// * **Open Mail** hands the user to the device's mail app — the chooser, when
///   there is more than one — because that mailbox is where the link is;
/// * **Resend Email** for a mail that never arrived, **Change Email Address**
///   for an address that was mistyped (the server removes the unconfirmed
///   account, which cannot sign in to correct itself, and the form comes back
///   with everything but the address still filled in), and **Back To Login** to
///   end the wait;
/// * coming back to the app asks the server whether the address is confirmed
///   now, and a "yes" turns the card green with a single **Use The App**, which
///   signs the user in and leaves them in the app;
/// * the waiting state is remembered on the device, so a restart in the middle
///   of the trip to the mailbox returns here instead of to an empty form.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/providers/contact_providers.dart';
import '../../../core/router/app_router.dart';
import '../../accounts_and_profile/data/firm_repository.dart';
import '../../accounts_and_profile/data/profile_name_store.dart';
import '../data/auth_repository.dart';
import '../data/local_auth_service.dart';
import 'auth_viewmodel.dart';
import 'auth_widgets.dart';

/// How the new account starts: on its own, or as a firm's associate.
enum SignupPath {
  /// Individual lawyer (or a future firm owner): the account starts solo.
  individual,

  /// Associate: the account redeems a firm's single-use invite code.
  joinFirm,
}

/// Registration & Join Firm via Invite Code.
class SignupScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _barAssociation = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _inviteCode = TextEditingController();

  /// Both password boxes, listened to together: the confirmation field's
  /// background answers every keystroke in either one, and listening here means
  /// only that field rebuilds while the form around it stays still.
  late final Listenable _passwordFields = Listenable.merge([
    _password,
    _confirmPassword,
  ]);

  /// The confirmation field's background.
  ///
  /// The theme's own pale fill while it is still empty — an untouched form must
  /// not look like a mistake — then light red for as long as what was typed
  /// differs from the password, and light green the moment the two agree (and
  /// back to red if the password box is edited afterwards).
  Color? get _confirmPasswordFill {
    if (_confirmPassword.text.isEmpty) return null;
    return _confirmPassword.text == _password.text
        ? AppColors.successContainer
        : AppColors.errorContainer;
  }

  SignupPath _path = SignupPath.individual;
  bool _hidePassword = true;
  bool _acceptedTerms = false;
  bool _termsError = false;
  bool _submitting = false;

  /// Set by the first refused submit. It is what turns the three required
  /// fields' silence into their mandatory sentence *inside* the field (user
  /// request) — before that, an untouched form must not look like a mistake.
  bool _submitted = false;

  /// Whether one of Sign Up's three required fields is still empty.
  ///
  /// Decided here rather than by the fields' own validators because their
  /// refusal is worded *inside* the field (user request), and a [FormField]
  /// validator's message can only ever land in the slot underneath it. The
  /// check runs before anything is sent, alongside the form's own validation.
  bool get _requiredFieldsMissing =>
      _fullName.text.trim().isEmpty ||
      _barAssociation.text.trim().isEmpty ||
      _email.text.trim().isEmpty;
  /// The failure the banner is showing, of whichever domain it came from.
///
/// The screen signs an account up **and** redeems an invite, so a failure can
/// be an auth one or a firm one; holding the failure rather than a kind is what
/// lets [failureText] word either.
Object? _error;

  /// Set once the account exists but has no session yet: the Check Your Email
  /// state. It replaces the form rather than sitting under it, because there is
  /// nothing left for the user to do here.
  String? _confirmationEmail;

  /// True once the server has answered that the address is confirmed, which
  /// swaps the card for its green state.
  bool _emailConfirmed = false;

  /// Guards the lifecycle check so two returns cannot ask twice at once.
  bool _checkingConfirmation = false;

  /// Whether the confirmation mail is being sent again.
  bool _resending = false;

  /// Whether the mistyped sign-up is being removed.
  bool _discarding = false;

  /// Whether the confirmed card's Use The App is signing in.
  bool _usingApp = false;

  @override
  void initState() {
    super.initState();
    // Coming back from the mail app is a lifecycle event, not a navigation one,
    // so the screen has to be told about it.
    WidgetsBinding.instance.addObserver(this);
    // A sign-up still waiting for its confirmation mail when the app was closed
    // comes back to this screen rather than to an empty form.
    final pending = ref.read(localAuthServiceProvider).pendingConfirmationEmail;
    if (pending != null) _confirmationEmail = pending;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkConfirmation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fullName.dispose();
    _barAssociation.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _inviteCode.dispose();
    super.dispose();
  }

  /// Creates the account, then joins the firm when that path was chosen.
  Future<void> _submit() async {
    if (_submitting) return;
    final l = AppLocalizations.of(context);
    setState(() {
      _termsError = !_acceptedTerms;
      _submitted = true;
    });
    if (!(_formKey.currentState?.validate() ?? false) ||
        !_acceptedTerms ||
        _requiredFieldsMissing) {
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final wantsFirm = _path == SignupPath.joinFirm;
    final code = _inviteCode.text.trim();

    try {
      final viewModel = ref.read(authViewModelProvider.notifier);
      final outcome = await viewModel.signUpIndividual(
        fullName: _fullName.text,
        email: _email.text,
        password: _password.text,
        barAssociation: _barAssociation.text.trim(),
        inviteCode: wantsFirm ? code : null,
      );

      // The name doubles as the display name everywhere else in the app (the
      // drawer header, the printed case sheets), so it is saved into the local
      // profile record as well as sent to the server. The Bar Association was
      // sent as sign-up metadata, which the trigger wrote onto the new
      // `profiles` row; it is kept here too because a confirmation-mail sign-up
      // has no session to read that row back with.
      await ref
          .read(profileFieldsProvider.notifier)
          .save(
            ref.read(profileFieldsProvider).copyWith(
              fullName: _fullName.text.trim(),
              barAssociation: _barAssociation.text.trim(),
            ),
          );

      if (outcome is SignUpConfirmationRequired) {
        if (!mounted) return;
        setState(() => _confirmationEmail = outcome.email);
        return;
      }

      if (wantsFirm) {
        final redemption = await viewModel.redeemPendingInvite();
        if (!mounted) return;
        _showJoinResult(l, redemption);
        return;
      }

      if (!mounted) return;
      _leaveForAuthenticatedApp();
    } on AuthFailure catch (failure) {
      if (!mounted) return;
      setState(() => _error = failure);
    } on FirmFailure catch (failure) {
      if (!mounted) return;
      setState(() => _error = failure);
    } on InviteRefusal catch (refusal) {
      // A seat refusal is not an error kind; the screen holds it as the failure
      // it words through [failureText], which is what keeps the count in the
      // sentence (§2.1).
      if (!mounted) return;
      setState(() => _error = refusal);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Signs up with Google instead, then joins the firm when that path was
  /// chosen (the invite field is required on that path, so it is already
  /// validated by the form).
  Future<void> _submitGoogle() async {
    if (_submitting) return;
    final l = AppLocalizations.of(context);
    setState(() => _termsError = !_acceptedTerms);
    if (!_acceptedTerms) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref.read(authViewModelProvider.notifier).signInWithGoogle();
      if (!mounted) return;
      if (_path == SignupPath.joinFirm) {
        final viewModel = ref.read(authViewModelProvider.notifier);
        await viewModel.rememberInviteCode(_inviteCode.text);
        final redemption = await viewModel.redeemPendingInvite();
        if (!mounted) return;
        _showJoinResult(l, redemption);
        return;
      }
      _leaveForAuthenticatedApp();
    } on AuthFailure catch (failure) {
      if (!mounted) return;
      // A closed Google sheet is the user declining, not an error to word.
      setState(
        () => _error = failure.kind == AuthFailureKind.cancelled
            ? null
            : failure,
      );
    } on FirmFailure catch (failure) {
      if (!mounted) return;
      setState(() => _error = failure);
    } on InviteRefusal catch (refusal) {
      if (!mounted) return;
      setState(() => _error = refusal);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Confirms a successful join and leaves onboarding.
  void _showJoinResult(AppLocalizations l, InviteRedemption redemption) {
    final message = redemption.status == InviteRedemptionStatus.alreadyMember
        ? l.auth_errorAlreadyMember
        : l.auth_joinedFirm;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    _leaveForAuthenticatedApp();
  }

  /// Leaves the auth routes; the router sends the user to their configured
  /// default landing page.
  void _leaveForAuthenticatedApp() {
    if (!mounted) return;
    context.go(AppRoutes.dailyCauseList);
  }

  /// Asks the server, on coming back to the app, whether the address is
  /// confirmed now.
  ///
  /// A return from the mail app is exactly this moment: the link was opened
  /// there, and this screen is what is still standing. Nothing is shown while
  /// the answer is no — the screen the user is already reading *is* the "not
  /// yet" state, and it has to stay exactly as it was.
  Future<void> _checkConfirmation() async {
    final email = _confirmationEmail;
    if (email == null || _emailConfirmed || _checkingConfirmation) return;
    // With no password there is nothing to check with, and an empty one would
    // only spend the server's sign-in rate limit. The password is held in
    // memory for the life of the sign-up that typed it and is never stored, so
    // after a restart this check simply cannot run — the restored screen still
    // offers Open Mail, Resend Email, Change Email Address and Back To Login.
    if (_password.text.isEmpty) return;

    _checkingConfirmation = true;
    try {
      final confirmed = await ref
          .read(authViewModelProvider.notifier)
          .isEmailConfirmed(email: email, password: _password.text);
      if (!mounted || !confirmed) return;
      setState(() => _emailConfirmed = true);
    } finally {
      _checkingConfirmation = false;
    }
  }

  /// Opens the device's mail app — the mailbox the confirmation went to, not an
  /// empty draft.
  ///
  /// The chooser is the OS's either way: the email-app intent raises its own when
  /// several apps qualify, and the launcher's `mailto:` fallback raises the
  /// ordinary one when nothing does.
  Future<void> _openMail() async {
    final opened = await ref.read(contactLauncherProvider).openMailApp();
    if (!mounted || opened) return;
    _say(AppLocalizations.of(context).auth_unableToOpenMail);
  }

  /// Sends the confirmation mail again, for the one that never arrived.
  Future<void> _resendConfirmation() async {
    final email = _confirmationEmail;
    if (email == null || _resending) return;
    final l = AppLocalizations.of(context);
    setState(() => _resending = true);
    try {
      await ref
          .read(authViewModelProvider.notifier)
          .resendConfirmationEmail(email);
      if (!mounted) return;
      _say(l.auth_resendSent);
    } on AuthFailure catch (failure) {
      // The server's own rate limit is the usual refusal and has its own
      // sentence; every other failure is the mapped text the sign-in banner
      // shows, so one wording serves both screens.
      final text = authErrorText(l, failure.kind);
      if (text != null) _say(text);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  /// Removes the mistyped sign-up and brings the form back, so the address can
  /// be corrected and submitted again.
  ///
  /// An unconfirmed account cannot sign in, so nothing on the client can
  /// correct its address; the server removes it instead, on the strength of the
  /// password, and refuses unless the account is unconfirmed and has done
  /// nothing at all.
  Future<void> _changeEmail() async {
    final email = _confirmationEmail;
    if (email == null || _discarding) return;
    final l = AppLocalizations.of(context);
    // The server identifies the caller by the account's own password. The
    // sign-up screen still holds the typed one; a restart does not, and then the
    // user is asked for it rather than left at a dead end.
    final password = _password.text.isNotEmpty
        ? _password.text
        : await _askForPassword();
    if (password == null || !mounted) return;

    setState(() => _discarding = true);
    try {
      final outcome = await ref
          .read(authViewModelProvider.notifier)
          .discardUnconfirmedSignup(email: email, password: password);
      if (!mounted) return;
      switch (outcome) {
        case DiscardSignupOutcome.removed:
          setState(() {
            _confirmationEmail = null;
            _emailConfirmed = false;
            // Only the address was wrong: every other field keeps what the
            // user typed, and the address itself is cleared for correcting.
            _email.clear();
          });
        case DiscardSignupOutcome.refusedConfirmed:
          _say(l.auth_changeEmailAlreadyConfirmed);
        case DiscardSignupOutcome.refusedUsed:
          _say(l.auth_changeEmailRefused);
        case DiscardSignupOutcome.rateLimited:
          _say(l.auth_errorRateLimited);
        case DiscardSignupOutcome.unavailable:
        case DiscardSignupOutcome.failed:
          _say(l.auth_errorUnknown);
      }
    } finally {
      if (mounted) setState(() => _discarding = false);
    }
  }

  /// Asks for the account's password, for a screen that no longer holds one.
  ///
  /// Answers null when the user backs out or leaves the field empty, which
  /// cancels the action — the password is what proves the request is the account
  /// owner's, so there is no continuing without it.
  Future<String?> _askForPassword() => showDialog<String>(
    context: context,
    builder: (_) => const _PasswordPromptDialog(),
  );

  /// Leaves for Login, ending the wait for a confirmation mail.
  Future<void> _backToLogin() async {
    await ref.read(authViewModelProvider.notifier).forgetPendingConfirmation();
    if (!mounted) return;
    context.go(AppRoutes.login);
  }

  /// Finishes the sign-up: signs in with the credentials the form is still
  /// holding, so the green card's button really does put the user in the app.
  ///
  /// The automatic check deliberately stops short of this — it only reads the
  /// server's answer and throws the session away, so nothing adopts the account
  /// behind the user's back. This tap is what spends the credentials, and from
  /// here it is an ordinary sign-in: the same call Login makes, with the same
  /// adoption, and the pending confirmation record cleared with it.
  Future<void> _useTheApp() async {
    final email = _confirmationEmail;
    if (email == null || _usingApp) return;
    final l = AppLocalizations.of(context);
    // A card restored after a restart holds no password — nothing is ever
    // stored — so there is nothing to sign in with and Login is the way in.
    if (_password.text.isEmpty) {
      await _backToLogin();
      return;
    }

    setState(() => _usingApp = true);
    try {
      final viewModel = ref.read(authViewModelProvider.notifier);
      await viewModel.signIn(email: email, password: _password.text);
      if (!mounted) return;
      // Parity with Login: a join-a-firm sign-up leaves its code pending, and
      // the first sign-in that has a session redeems it. Without this the green
      // card would quietly skip the firm the user asked to join.
      if (ref.read(localAuthServiceProvider).pendingInviteCode != null) {
        final redemption = await viewModel.redeemPendingInvite();
        if (!mounted) return;
        _showJoinResult(l, redemption);
        return;
      }
      _leaveForAuthenticatedApp();
    } on AuthFailure catch (failure) {
      // The card is the whole screen, so a refusal is said rather than bannered
      // — [failureText] words either domain, exactly as the form's banner does.
      final text = failureText(l, failure);
      if (text != null) _say(text);
    } on FirmFailure catch (failure) {
      final text = failureText(l, failure);
      if (text != null) _say(text);
    } finally {
      if (mounted) setState(() => _usingApp = false);
    }
  }

  /// Shows [message] at the foot of the screen.
  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // The three required fields read this once a submit has been refused, and
    // only while they are empty and nothing has been typed into them.
    final mandatory = _submitted ? l.auth_validationMandatory : null;

    return AuthScaffold(
      // The language choice sits above the card (user request).
      topRight: const AuthLanguageSwitch(),
      child: AuthCard(
        padding: EdgeInsets.zero,
        clip: true,
        child: _confirmationEmail != null
            ? (_emailConfirmed
                  ? _ConfirmedEmailBody(
                      email: _confirmationEmail!,
                      onUseTheApp: _useTheApp,
                      busy: _usingApp,
                    )
                  : _CheckEmailBody(
                      email: _confirmationEmail!,
                      onOpenMail: _openMail,
                      onResend: _resendConfirmation,
                      onChangeAddress: _changeEmail,
                      onBack: _backToLogin,
                    ))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.xl,
                      AppSpacing.lg,
                      // The header sits clear of the first field below it (user
                      // request): one step more than the card's own padding.
                      AppSpacing.lg,
                    ),
                    child: AuthSignupHeader(
                      title: l.auth_signupTitle,
                      subtitle: l.auth_signupSubtitle,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.xl,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _AccountTypeChoice(
                            label: l.auth_accountTypeLabel,
                            individual: l.auth_accountTypeIndividual,
                            joinFirm: l.auth_accountTypeJoinFirm,
                            selected: _path,
                            onChanged: (path) => setState(() => _path = path),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          AuthTextField(
                            controller: _fullName,
                            label: l.auth_fullNameLabel,
                            hint: l.auth_fullNameHint,
                            emptyMessage: mandatory,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.name],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AuthTextField(
                            controller: _barAssociation,
                            label: l.auth_barAssociationLabel,
                            hint: l.auth_barAssociationHint,
                            emptyMessage: mandatory,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          // The Email box carries the clear cross and the domain
                          // window (user request).
                          AuthEmailField(
                            controller: _email,
                            label: l.auth_emailAddressLabel,
                            hint: l.auth_emailAddressHint,
                            emptyMessage: mandatory,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            // Empty is the field's own mandatory sentence, so
                            // only a filled-in value is judged here: how it is
                            // shaped, before the round trip.
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? null
                                : authEmailError(l, value),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AuthTextField(
                            controller: _password,
                            label: l.auth_passwordLabel,
                            hint: l.auth_passwordHint,
                            helper: l.auth_passwordHelper,
                            obscureText: _hidePassword,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.newPassword],
                            trailing: IconButton(
                              onPressed: () => setState(
                                () => _hidePassword = !_hidePassword,
                              ),
                              tooltip: _hidePassword
                                  ? l.auth_showPassword
                                  : l.auth_hidePassword,
                              icon: Icon(
                                _hidePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 20,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                            validator: (value) => authPasswordLengthError(l, value),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          // The confirmation field carries no visibility toggle of
                          // its own: the password field above already reveals
                          // both, and two toggles for one state would be noise.
                          ListenableBuilder(
                            listenable: _passwordFields,
                            builder: (context, _) => AuthTextField(
                              controller: _confirmPassword,
                              label: l.auth_confirmPasswordLabel,
                              hint: l.auth_passwordHint,
                              obscureText: _hidePassword,
                              textInputAction: _path == SignupPath.joinFirm
                                  ? TextInputAction.next
                                  : TextInputAction.done,
                              autofillHints: const [AutofillHints.newPassword],
                              fillColor: _confirmPasswordFill,
                              validator: (value) => authConfirmPasswordError(
                                l,
                                _password.text,
                                value,
                              ),
                            ),
                          ),
                          if (_path == SignupPath.joinFirm) ...[
                            const SizedBox(height: AppSpacing.md),
                            AuthTextField(
                              controller: _inviteCode,
                              label: l.auth_inviteCodeLabel,
                              hint: l.auth_inviteCodeHint,
                              helper: l.auth_inviteCodeHelper,
                              textCapitalization: TextCapitalization.characters,
                              textInputAction: TextInputAction.done,
                              validator: (value) => authRequiredError(
                                value,
                                l.auth_validationInviteCodeRequired,
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.md),
                          _TermsCheckbox(
                            accepted: _acceptedTerms,
                            showError: _termsError,
                            onChanged: (value) => setState(() {
                              _acceptedTerms = value;
                              if (value) _termsError = false;
                            }),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AuthErrorBanner(text: failureText(l, _error)),
                          AuthPrimaryButton(
                            label: l.auth_signUpButton,
                            busy: _submitting,
                            onPressed: _submit,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AuthDivider(label: l.auth_orContinueWith),
                          const SizedBox(height: AppSpacing.md),
                          AuthGoogleButton(
                            label: l.auth_googleSignup,
                            enabled: !_submitting,
                            onPressed: _submitGoogle,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    color: AppColors.surfaceContainerLow,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                    child: AuthSwitchLine(
                      prompt: l.auth_haveAccount,
                      action: l.auth_loginLink,
                      onTap: () => context.go(AppRoutes.login),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Height of the account-type choice: the height the segmented button gave it.
const double _accountTypeHeight = 40.0;

/// Share of the account-type choice each segment takes: 2 : 3, which is
/// **40 % / 60 %** of the row (user request).
const int _individualFlex = 2;

/// The Join Existing Firm segment's share of the pair — see [_individualFlex].
const int _joinFirmFlex = 3;

/// The Individual / Join Existing Firm choice above the form.
///
/// Two segments inside one outlined control, drawn as `SegmentedButton` drew
/// them (a 40 px row, the same fills and the same hairline outline) with the one
/// difference this choice needs (user request): the segments are **not** the
/// same width. `SegmentedButton` lays every segment out at one size — a segment
/// is at most `maxWidth / segmentCount` wide, whichever label is in it — which
/// both left the short *ব্যক্তিগত* looking as wide as the long
/// *বিদ্যমান ফারমে যোগ দিন* and wrapped that longer label onto two lines.
///
/// Here the row is split **40 / 60** (user request): the Individual segment takes
/// `_individualFlex` of the five shares and Join Existing Firm the other three.
/// A share rather than the shrink-wrap that came first, which left the shorter
/// button looking too small beside a very wide one; the ratio holds at every
/// width, so the pair reads as one control however long either label is. The
/// longer label still scales down by the little its segment cannot hold instead
/// of wrapping, so it is always read on one line.
class _AccountTypeChoice extends StatelessWidget {
  const _AccountTypeChoice({
    required this.label,
    required this.individual,
    required this.joinFirm,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final String individual;
  final String joinFirm;
  final SignupPath selected;
  final ValueChanged<SignupPath> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: AppTypography.labelMd.copyWith(color: AppColors.onSurfaceVariant),
      ),
      const SizedBox(height: AppSpacing.xs),
      SizedBox(
        height: _accountTypeHeight,
        child: Material(
          // The control's own corners and outline, drawn once around both
          // segments: the stadium shape and hairline border the segmented
          // button carried.
          shape: const StadiumBorder(
            side: BorderSide(color: AppColors.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Two fifths of the row (user request).
              Expanded(
                flex: _individualFlex,
                child: _AccountTypeSegment(
                  label: individual,
                  selected: selected == SignupPath.individual,
                  onTap: () => onChanged(SignupPath.individual),
                ),
              ),
              // The hairline between the two, which each segment used to draw
              // for itself.
              const SizedBox(
                width: 1,
                child: ColoredBox(color: AppColors.outlineVariant),
              ),
              // The other three (user request).
              Expanded(
                flex: _joinFirmFlex,
                child: _AccountTypeSegment(
                  label: joinFirm,
                  selected: selected == SignupPath.joinFirm,
                  onTap: () => onChanged(SignupPath.joinFirm),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

/// One segment of the account-type choice: filled black while it is the chosen
/// path, white while it is not, and its label always on one line.
class _AccountTypeSegment extends StatelessWidget {
  const _AccountTypeSegment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  /// Segment label, already in its own language.
  final String label;

  /// Whether this is the chosen path.
  final bool selected;

  /// Chooses this path.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: Material(
      color: selected ? AppColors.primary : AppColors.surfaceContainerLowest,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
          child: Center(
            // Laid out whole and scaled down only by what the segment cannot
            // hold, so the label never wraps (user request).
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: AppTypography.labelLg.copyWith(
                  color: selected ? AppColors.onPrimary : AppColors.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// The Terms of Service / Privacy Policy checkbox, with its two links.
class _TermsCheckbox extends StatelessWidget {
  const _TermsCheckbox({
    required this.accepted,
    required this.showError,
    required this.onChanged,
  });

  final bool accepted;
  final bool showError;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final linkStyle = AppTypography.bodySm.copyWith(
      color: AppColors.secondary,
      fontWeight: FontWeight.w500,
      decoration: TextDecoration.underline,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: Checkbox(
                value: accepted,
                onChanged: (value) => onChanged(value ?? false),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text.rich(
                  TextSpan(
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                    children: [
                      TextSpan(text: '${l.auth_termsAgreePrefix} '),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: AuthDocumentLink(
                          label: l.auth_termsOfService,
                          style: linkStyle,
                          route: AppRoutes.settingsTermsOfService,
                        ),
                      ),
                      TextSpan(text: ' ${l.auth_termsAgreeJoin} '),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: AuthDocumentLink(
                          label: l.auth_privacyPolicy,
                          style: linkStyle,
                          route: AppRoutes.settingsPrivacyPolicy,
                        ),
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (showError) ...[
          const SizedBox(height: AppSpacing.xs),
          Padding(
            padding: const EdgeInsets.only(left: 40),
            child: Text(
              l.auth_validationTermsRequired,
              style: AppTypography.bodySm.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ],
    );
  }
}

/// The Check Your Email state, shown when sign-up returns no session.
class _CheckEmailBody extends StatelessWidget {
  const _CheckEmailBody({
    required this.email,
    required this.onOpenMail,
    required this.onResend,
    required this.onChangeAddress,
    required this.onBack,
  });

  final String email;

  /// Opens the device's mail app.
  final VoidCallback onOpenMail;

  /// Sends the confirmation mail again.
  final VoidCallback onResend;

  /// Removes the sign-up so a mistyped address can be corrected.
  final VoidCallback onChangeAddress;

  /// Leaves for Login.
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.mark_email_unread_outlined,
            size: 40,
            color: AppColors.primary,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            l.auth_checkEmailTitle,
            textAlign: TextAlign.center,
            style: AppTypography.titleLg.copyWith(color: AppColors.primary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l.auth_checkEmailMessage(email),
            textAlign: TextAlign.center,
            style: AppTypography.bodyMd.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // The forward action first: reading the mail is what finishes the
          // sign-up, and Back To Login is the way out of it rather than the way
          // through it. Two filled buttons stacked would have no hierarchy, so
          // the way out wears the app's outlined button.
          AuthPrimaryButton(label: l.auth_openMail, onPressed: onOpenMail),
          const SizedBox(height: AppSpacing.sm),
          AuthOutlinedButton(label: l.auth_backToLogin, onPressed: onBack),
          const SizedBox(height: AppSpacing.xs),
          // The two recoveries, quiet and last: neither is expected, and one of
          // them is only for a mistake. Each guards itself, so a second tap
          // while one is in flight does nothing.
          AuthTextLink(label: l.auth_resendEmail, onPressed: onResend),
          AuthTextLink(label: l.auth_changeEmail, onPressed: onChangeAddress),
        ],
      ),
    );
  }
}

/// Asks for the account's password.
///
/// A widget of its own rather than a controller built where the dialog is
/// opened: the field outlives `showDialog`'s return by the dialog's exit
/// animation, and a controller disposed as soon as that future completed was
/// still being built by the closing route.
class _PasswordPromptDialog extends StatefulWidget {
  const _PasswordPromptDialog();

  @override
  State<_PasswordPromptDialog> createState() => _PasswordPromptDialogState();
}

class _PasswordPromptDialogState extends State<_PasswordPromptDialog> {
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  /// Returns the typed password, or null for an empty field — the caller treats
  /// both the same way, as "no password, no action".
  void _submit() {
    final entered = _password.text;
    // Never trimmed: a space can be part of a password.
    Navigator.of(context).pop(entered.isEmpty ? null : entered);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.auth_changeEmailPasswordTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.auth_changeEmailPasswordPrompt, style: AppTypography.bodyMd),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _password,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            autofocus: true,
            decoration: InputDecoration(labelText: l.auth_passwordLabel),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.sharedActions_cancel),
        ),
        TextButton(onPressed: _submit, child: Text(l.sharedActions_save)),
      ],
    );
  }
}

/// The state the screen turns into once the address is confirmed.
///
/// One action only: the account exists and its address is verified, so there is
/// nothing left to offer here — no Open Mail, no resend, no address to correct.
/// The action signs the user in, because that is what the label promises and
/// what the user asked for: pressing it lands them in the app rather than on
/// Login.
class _ConfirmedEmailBody extends StatelessWidget {
  const _ConfirmedEmailBody({
    required this.email,
    required this.onUseTheApp,
    required this.busy,
  });

  final String email;

  /// Signs in with the credentials the form is still holding.
  final VoidCallback onUseTheApp;

  /// Whether that sign-in is in flight.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.mark_email_read_outlined,
            size: 40,
            color: AppColors.success,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            l.auth_emailConfirmedTitle,
            textAlign: TextAlign.center,
            style: AppTypography.titleLg.copyWith(color: AppColors.success),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l.auth_emailConfirmedMessage(email),
            textAlign: TextAlign.center,
            style: AppTypography.bodyMd.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AuthPrimaryButton(
            label: l.auth_useTheApp,
            onPressed: onUseTheApp,
            busy: busy,
          ),
        ],
      ),
    );
  }
}
