/// Sign-up screen: a new account, alone or as an associate joining a firm.
///
/// Body mirrors `mockup_html_screens/settings_onlineSync_signup/code.html`: the
/// card with the gavel/wordmark header, "Create Account" and its subtitle, then
/// Full Name, Bar Association, Email Address and Password (with the mockup's
/// eight-character helper line), the Terms of Service / Privacy Policy
/// checkbox, the Sign Up button, the "Or Continue With" divider and the Google
/// button, and finally the "Already have an account?" strip.
///
/// Two deliberate additions the mockup could not show:
///
/// * **Account Type** — Individual or Join Existing Firm. Choosing the firm path
///   reveals the Invite Code field, which is the plan's single-use onboarding
///   code; the rest of the form is unchanged.
/// * **Check Your Email** — when the project has email confirmation on, the
///   account exists but has no session, so the screen says so instead of
///   pretending to be signed in. The typed invite code is kept until the
///   confirmation is done.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/router/app_router.dart';
import '../../accounts_and_profile/data/firm_repository.dart';
import '../../accounts_and_profile/data/profile_name_store.dart';
import '../data/auth_repository.dart';
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

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _barAssociation = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _inviteCode = TextEditingController();

  SignupPath _path = SignupPath.individual;
  bool _hidePassword = true;
  bool _acceptedTerms = false;
  bool _termsError = false;
  bool _submitting = false;
  AuthFailureKind? _error;

  /// Set once the account exists but has no session yet: the Check Your Email
  /// state. It replaces the form rather than sitting under it, because there is
  /// nothing left for the user to do here.
  String? _confirmationEmail;

  @override
  void dispose() {
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
    setState(() => _termsError = !_acceptedTerms);
    if (!(_formKey.currentState?.validate() ?? false) || !_acceptedTerms) {
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
      setState(() => _error = failure.kind);
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
      setState(
        () => _error = failure.kind == AuthFailureKind.cancelled
            ? null
            : failure.kind,
      );
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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return AuthScaffold(
      child: AuthCard(
        padding: EdgeInsets.zero,
        clip: true,
        child: _confirmationEmail != null
            ? _CheckEmailBody(
                email: _confirmationEmail!,
                onBack: () => context.go(AppRoutes.login),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.xl,
                      AppSpacing.lg,
                      AppSpacing.md,
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
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.name],
                            validator: (value) => authRequiredError(
                              value,
                              l.auth_validationFullNameRequired,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AuthTextField(
                            controller: _barAssociation,
                            label: l.auth_barAssociationLabel,
                            hint: l.auth_barAssociationHint,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            validator: (value) => authRequiredError(
                              value,
                              l.auth_validationBarAssociationRequired,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AuthTextField(
                            controller: _email,
                            label: l.auth_emailAddressLabel,
                            hint: l.auth_emailAddressHint,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            validator: (value) => authEmailError(l, value),
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
                          AuthTextField(
                            controller: _confirmPassword,
                            label: l.auth_confirmPasswordLabel,
                            hint: l.auth_passwordHint,
                            obscureText: _hidePassword,
                            textInputAction: _path == SignupPath.joinFirm
                                ? TextInputAction.next
                                : TextInputAction.done,
                            autofillHints: const [AutofillHints.newPassword],
                            validator: (value) => authConfirmPasswordError(
                              l,
                              _password.text,
                              value,
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
                          AuthErrorBanner(text: authErrorText(l, _error)),
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

/// The Individual / Join Existing Firm choice above the form.
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
      SegmentedButton<SignupPath>(
        segments: [
          ButtonSegment<SignupPath>(
            value: SignupPath.individual,
            label: Text(individual),
          ),
          ButtonSegment<SignupPath>(
            value: SignupPath.joinFirm,
            label: Text(joinFirm),
          ),
        ],
        selected: {selected},
        showSelectedIcon: false,
        onSelectionChanged: (selection) => onChanged(selection.first),
        style: SegmentedButton.styleFrom(
          backgroundColor: AppColors.surfaceContainerLowest,
          foregroundColor: AppColors.onSurface,
          selectedBackgroundColor: AppColors.primary,
          selectedForegroundColor: AppColors.onPrimary,
          textStyle: AppTypography.labelLg,
          side: const BorderSide(color: AppColors.outlineVariant),
        ),
      ),
    ],
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
  const _CheckEmailBody({required this.email, required this.onBack});

  final String email;
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
          AuthPrimaryButton(label: l.auth_backToLogin, onPressed: onBack),
        ],
      ),
    );
  }
}
