/// Password reset screen: email → emailed recovery code → new password.
///
/// The login mockup links "Forgot Password?" to this flow, but no mockup exists
/// for the screen itself, so it reuses the same card language as the other two
/// auth screens (see [auth_widgets.dart]) rather than inventing a third style.
///
/// Two ways in, one screen:
///
/// * **The recovery code** is the default path, and the one that works on every
///   device without any deep-link setup. It requires the project's Reset
///   Password e-mail template to include the token.
/// * **The emailed link** is the other: opening it lands here with a session
///   already verified (see [passwordRecoveryPendingProvider]), so the email and
///   the code are skipped and only the new password is asked for.
///
/// **One flow, two presentations.** From Login this is an auth screen and keeps
/// the auth shell. From Settings > Accounts & Profile > Manage Account it is
/// reached as **Change Password**, which is a Settings sub-page: the same card
/// ([asSettingsSubPage]), under the standard sub-page header with its back
/// button, and without the "Back To Login" line — the user is already signed in,
/// so the auth sign-in route is not a place they may go. It is a separate route
/// from Login's `/forgot-password` for exactly that reason: the router sends a
/// signed-in user away from the auth routes, which is why pushing that one from
/// here only ever landed on the default landing page.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/router/app_router.dart';
import '../../settings/presentation/settings_sub_page_modal.dart';
import '../data/auth_repository.dart';
import 'auth_viewmodel.dart';
import 'auth_widgets.dart';

/// Which half of the reset the user is in.
enum _ResetStep { requestCode, enterCode }

/// Reset Password screen (Login) / Change Password sub-page (Settings).
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  ///
  /// [asSettingsSubPage] is the Manage Account presentation; it defaults to
  /// false so the Login screen's route is untouched.
  const ForgotPasswordScreen({this.asSettingsSubPage = false, super.key});

  /// Whether this is the Settings sub-page (Manage Account > Change Password)
  /// rather than the auth screen the Login page opens.
  ///
  /// It decides three things and nothing else: the shell the card is drawn in,
  /// whether the "Back To Login" line is offered, and where a successful change
  /// returns to.
  final bool asSettingsSubPage;

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailForm = GlobalKey<FormState>();
  final _codeForm = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();

  _ResetStep _step = _ResetStep.requestCode;
  bool _hidePassword = true;
  bool _submitting = false;
  AuthFailureKind? _error;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Requests the recovery code, then moves to the code step.
  Future<void> _sendCode() async {
    if (_submitting) return;
    if (!(_emailForm.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(authViewModelProvider.notifier)
          .sendPasswordRecoveryCode(_email.text);
      if (!mounted) return;
      setState(() => _step = _ResetStep.enterCode);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).auth_recoverySent)),
      );
    } on AuthFailure catch (failure) {
      if (!mounted) return;
      setState(() => _error = failure.kind);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Verifies the code and sets the new password.
  Future<void> _setPassword() async {
    if (_submitting) return;
    if (!(_codeForm.currentState?.validate() ?? false)) return;

    // Captured before the first await, because the widget may be gone by the
    // time the reset succeeds: a typed code signs the user in, and the router
    // moves them off this screen the moment it does. The messenger lives on
    // [MaterialApp], above the router, so a message raised through it outlives
    // the widget and is still shown.
    final messenger = ScaffoldMessenger.of(context);
    final successMessage = Text(
      AppLocalizations.of(context).auth_passwordUpdated,
    );

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final viewModel = ref.read(authViewModelProvider.notifier);
      // A recovery link came with its own verified session, so there is no code
      // to exchange — only the e-mailed-code path redeems one.
      if (!ref.read(passwordRecoveryPendingProvider)) {
        await viewModel.verifyRecoveryCode(
          email: _email.text,
          code: _code.text,
        );
      }
      await viewModel.updatePassword(_password.text);
      messenger.showSnackBar(SnackBar(content: successMessage));
      if (!mounted) return;
      // The Settings sub-page returns to where it was opened from — Manage
      // Account — because its user was already signed in and that is where a
      // password change belongs. The auth screen's user is now signed in too,
      // so the app opens on the screen sign-up lands a new account on, rather
      // than a reset screen the router will not let them stay on.
      if (widget.asSettingsSubPage) {
        Navigator.of(context).maybePop();
      } else {
        context.go(AppRoutes.dailyCauseList);
      }
    } on AuthFailure catch (failure) {
      if (!mounted) return;
      setState(() => _error = failure.kind);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // Arrived through the emailed link: the session it carried is proof enough,
    // so there is nothing to request and no code to type.
    final viaLink = ref.watch(passwordRecoveryPendingProvider);

    final card = AuthCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.auth_forgotTitle,
            textAlign: TextAlign.center,
            style: AppTypography.headlineMd,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            viaLink ? l.auth_recoveryLinkSubtitle : l.auth_forgotSubtitle,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMd.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_step == _ResetStep.requestCode && !viaLink)
            Form(
              key: _emailForm,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AuthTextField(
                    controller: _email,
                    label: l.auth_emailLabel,
                    hint: l.auth_emailHint,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _sendCode(),
                    validator: (value) => authEmailError(l, value),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AuthErrorBanner(text: authErrorText(l, _error)),
                  AuthPrimaryButton(
                    label: l.auth_sendCodeButton,
                    busy: _submitting,
                    onPressed: _sendCode,
                  ),
                ],
              ),
            )
          else
            Form(
              key: _codeForm,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // The code field is the signed-out path's own step; a
                  // recovery link already carries the verified session.
                  if (!viaLink) ...[
                    AuthTextField(
                      controller: _code,
                      label: l.auth_recoveryCodeLabel,
                      helper: l.auth_recoveryCodeHelper,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      validator: (value) => authRequiredError(
                        value,
                        l.auth_validationPasswordRequired,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  AuthTextField(
                    controller: _password,
                    label: l.auth_newPasswordLabel,
                    helper: l.auth_passwordHelper,
                    obscureText: _hidePassword,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _setPassword(),
                    trailing: IconButton(
                      onPressed: () =>
                          setState(() => _hidePassword = !_hidePassword),
                      tooltip: _hidePassword
                          ? l.auth_showPassword
                          : l.auth_hidePassword,
                      icon: Icon(
                        _hidePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 20,
                      ),
                    ),
                    validator: (value) => authPasswordLengthError(l, value),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AuthErrorBanner(text: authErrorText(l, _error)),
                  AuthPrimaryButton(
                    label: l.auth_setPasswordButton,
                    busy: _submitting,
                    onPressed: _setPassword,
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          // Plain bold underlined text, not the black button the shared theme
          // would draw: this is a way back, not the screen's primary action.
          // Hidden while a recovery link is in play, because the user is
          // already signed in — leaving for Login would strand them on a
          // screen with nothing left to do. Hidden in the Settings sub-page
          // for the same reason: that user is signed in too, and is backing
          // out to Manage Account rather than leaving for the sign-in route.
          if (!viaLink && !widget.asSettingsSubPage)
            Center(
              child: AuthTextLink(
                label: l.auth_backToLogin,
                underline: true,
                onPressed: () => context.go(AppRoutes.login),
              ),
            ),
        ],
      ),
    );

    // From Login: an auth screen, in the auth shell the other two use.
    if (!widget.asSettingsSubPage) return AuthScaffold(child: card);

    // From Settings: the same card as a Settings sub-page, under the header and
    // back button every other sub-page wears.
    return SettingsSubPageModal(
      title: l.settingsManageAccount_changePassword,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.edgeMargin,
          AppSpacing.md,
          AppSpacing.edgeMargin,
          AppSpacing.xl,
        ),
        child: card,
      ),
    );
  }
}
